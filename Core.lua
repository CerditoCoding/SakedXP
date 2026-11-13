-- SakedXP · Core
-- Namespace, saved variables, event bus and helpers shared by every module.

local ADDON, S = ...
_G.SakedXP = S

S.name = ADDON
S.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "dev"

---------------------------------------------------------------------------
-- Palette: muted golden-orange over a greyish black.
---------------------------------------------------------------------------
local function hex(h)
    local r, g, b = h:match("(%x%x)(%x%x)(%x%x)")
    return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, hex = h }
end

S.C = {
    bg          = hex("15171a"), -- window body (slate black)
    bgAlt       = hex("1f2226"), -- cards
    bgRaised    = hex("2a2e33"), -- hovered / raised
    border      = hex("33373d"), -- cool dark border
    borderLight = hex("474c54"),
    gold        = hex("d4a24c"), -- primary accent (muted gold-orange)
    goldDim     = hex("9c7536"),
    goldSoft    = hex("e3bb72"),
    amber       = hex("c9772f"), -- secondary accent
    text        = hex("e6e1d8"),
    textDim     = hex("9a948a"),
    textMute    = hex("6b665e"),
    good        = hex("5fb878"), -- toggles / positive numbers
    bad         = hex("c4583f"),
    info        = hex("6e98b8"),
    rare        = hex("b07fd0"),
}

function S.Color(key, text)
    local c = S.C[key]
    if not c then return text end
    return "|cff" .. c.hex .. tostring(text) .. "|r"
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local defaults = {
    scale = 1,
    alpha = 0.86,
    fontHead = "friz",
    fontBody = "arialn",
    fontScale = 1,
    width = 360,
    height = 470,
    point = { "RIGHT", "UIParent", "RIGHT", -60, 40 },
    locked = false,
    zonePopup = true,
    dungeonPanel = true,
    showProfessions = true,
    outboundOpen = false,
    autoAccept = true,
    autoTurnin = true,
    arrow = true,
    arrowScale = 1,
    arrowPoint = { "TOP", "UIParent", "TOP", 0, -120 },
    mapPins = true,
    includeElite = false,
    levelAhead = 3,
    greyRange = 6,
    smartAlerts = true,
    upcoming = 3,
    collapsed = false,
    profPoint = { "CENTER", "UIParent", "CENTER", 0, 0 },
}

local charDefaults = {
    skippedQuests = {},   -- [questId] = true, applied to every guide
    hiddenOutbound = {},  -- [questId] = true, cross-zone suggestions the player dismissed
    seenZonePopup = {},   -- [guideName] = true
    professions = {},     -- user-selected profession guides
    lastGuide = nil,
}

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(dst[k]) == "table" and not v[1] then
            applyDefaults(dst[k], v)
        end
    end
end

---------------------------------------------------------------------------
-- Error reporting: Lua errors are often hidden in-game, so the first time
-- each one happens SakedXP also prints it to chat (short, once).
---------------------------------------------------------------------------
local reported = {}
function S.Error(err)
    err = tostring(err)
    local short = err:gsub("^Interface[\\/]AddOns[\\/]", ""):sub(1, 220)
    if not reported[short] then
        reported[short] = true
        print("|cffd4a24cSaked|r|cffe6e1d8XP|r |cffc4583ferror:|r " .. short)
    end
    pcall(geterrorhandler(), err)
end

-- The modern client hides some values ("secret values") from addons.
function S.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) or false
end

---------------------------------------------------------------------------
-- Tiny event bus (internal messages) + WoW events
---------------------------------------------------------------------------
local listeners = {}
function S:On(msg, fn)
    listeners[msg] = listeners[msg] or {}
    table.insert(listeners[msg], fn)
end

function S:Fire(msg, ...)
    local list = listeners[msg]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then S.Error(err) end
    end
end

local ev = CreateFrame("Frame")
S.eventFrame = ev
local wowHandlers = {}
function S:RegisterEvent(event, fn)
    if not wowHandlers[event] then
        wowHandlers[event] = {}
        pcall(ev.RegisterEvent, ev, event)
    end
    table.insert(wowHandlers[event], fn)
end
ev:SetScript("OnEvent", function(_, event, ...)
    local list = wowHandlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then S.Error(err) end
    end
end)

-- If the game ever blocks something SakedXP does, say exactly what it was.
for _, e in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
    pcall(ev.RegisterEvent, ev, e)
    wowHandlers[e] = { function(_, addon, func)
        if addon == ADDON then
            print("|cffd4a24cSaked|r|cffe6e1d8XP|r |cffc4583fbloqueado por el juego:|r " .. tostring(func) ..
                " |cff9a948a(mandá este mensaje para corregirlo)|r")
        end
    end }
end

-- Coalesce bursts (QUEST_LOG_UPDATE fires a lot) into one call.
local pending = {}
function S:Debounce(key, delay, fn)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(delay, function()
        pending[key] = nil
        local ok, err = pcall(fn)
        if not ok then S.Error(err) end
    end)
end

---------------------------------------------------------------------------
-- Quest helpers (defensive: Forever mixes classic and modern APIs)
---------------------------------------------------------------------------
-- The completed flag can lag behind QUEST_TURNED_IN; remember turn-ins this session.
local turnedIn = {}
function S.MarkTurnedIn(id) if id then turnedIn[id] = true end end

function S.IsQuestDone(id)
    if not id then return false end
    if turnedIn[id] then return true end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false
    end
    return _G.IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id) or false
end

-- Is a quest in the log ready to turn in? The modern C_QuestLog.GetInfo has
-- no isComplete field, so ask the dedicated API and, failing that, check that
-- every objective is finished.
local function logQuestComplete(id, info)
    if C_QuestLog.IsComplete then
        local ok, v = pcall(C_QuestLog.IsComplete, id)
        if ok and v ~= nil and not S.IsSecret(v) then return v and true or false end
    end
    if info and info.isComplete ~= nil then return info.isComplete and true or false end
    if C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(C_QuestLog.GetQuestObjectives, id)
        if ok and type(objs) == "table" and #objs > 0 then
            for _, o in ipairs(objs) do
                if not o.finished then return false end
            end
            return true
        end
    end
    return false
end

local logCache, logCacheTime = {}, 0
function S.GetQuestLogSet()
    local now = GetTime()
    if now - logCacheTime < 0.25 then return logCache end
    wipe(logCache)
    logCacheTime = now
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and info.questID > 0 then
                logCache[info.questID] = logQuestComplete(info.questID, info) and "complete" or "active"
            end
        end
    elseif GetNumQuestLogEntries then
        for i = 1, GetNumQuestLogEntries() do
            local _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if not isHeader and questID then
                logCache[questID] = (isComplete == 1 or isComplete == true) and "complete" or "active"
            end
        end
    end
    return logCache
end

function S.IsOnQuest(id)
    return id and S.GetQuestLogSet()[id] ~= nil
end

function S.InvalidateQuestLog() logCacheTime = 0 end

function S.QuestName(id)
    if not id then return "?" end
    local name
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        name = C_QuestLog.GetTitleForQuestID(id)
    end
    if (not name or name == "") and S.DB then name = S.DB.Q(id, "name") end
    return name or ("#" .. id)
end

function S.Print(...)
    print("|cffd4a24cSaked|r|cffe6e1d8XP|r:", ...)
end

function S.FormatNumber(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end

---------------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------------
S:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    SakedXPDB = SakedXPDB or {}
    SakedXPCharDB = SakedXPCharDB or {}
    applyDefaults(SakedXPDB, defaults)
    applyDefaults(SakedXPCharDB, charDefaults)
    S.db = SakedXPDB
    S.cdb = SakedXPCharDB
    if not S.db.styleV2 then -- translucent redesign: lower the old opaque default once
        S.db.styleV2 = true
        if (S.db.alpha or 1) > 0.9 then S.db.alpha = 0.86 end
    end
    S:Fire("DB_READY")
end)

S:RegisterEvent("PLAYER_LOGIN", function()
    S.player = {
        class = select(2, UnitClass("player")),
        race = select(2, UnitRace("player")),
        faction = UnitFactionGroup("player"),
        level = UnitLevel("player"),
    }
    S:Fire("LOGIN")
    C_Timer.After(1.5, function() S:Fire("READY") end)
end)

S:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
    if S.player then S.player.level = level end
    S:Fire("LEVEL_UP", level)
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_SAKEDXP1 = "/sxp"
SLASH_SAKEDXP2 = "/saked"
SLASH_SAKEDXP3 = "/sakedxp"
SlashCmdList.SAKEDXP = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "zonas" or msg == "zones" or msg == "z" then
        S:Fire("OPEN_ZONE_PICKER", "manual")
    elseif msg == "prof" or msg == "profesiones" or msg == "p" then
        S:Fire("OPEN_PROFESSIONS")
    elseif msg == "config" or msg == "opciones" or msg == "c" then
        S:Fire("OPEN_SETTINGS")
    elseif msg == "sync" or msg == "sincronizar" then
        S:Fire("REQUEST_SYNC")
    elseif msg == "reset" then
        S.db.point = CopyTable(defaults.point)
        S.db.scale = 1
        S:Fire("LAYOUT_RESET")
        S.Print("posición y escala restablecidas.")
    elseif msg == "ruta" or msg == "route" or msg == "aqui" or msg == "aquí" then
        S:Fire("REGENERATE")
    elseif msg == "flecha" or msg == "arrow" then
        S.db.arrow = not S.db.arrow
        S:Fire("SETTINGS_CHANGED")
        S.Print("flecha " .. (S.db.arrow and "activada" or "oculta") .. ".")
    elseif msg == "help" or msg == "ayuda" then
        S.Print("comandos:")
        print("  /sxp — mostrar/ocultar la guía")
        print("  /sxp zonas — elegir la próxima zona")
        print("  /sxp prof — guía de profesiones")
        print("  /sxp sync — detectar en qué paso estás")
        print("  /sxp config — opciones")
        print("  /sxp ruta — generar la ruta de la zona donde estás")
        print("  /sxp flecha — mostrar/ocultar la flecha")
        print("  /sxp reset — restablecer posición")
    else
        S:Fire("TOGGLE_WINDOW")
    end
end

function SakedXP_OnCompartmentClick(_, button)
    if button == "RightButton" then
        S:Fire("OPEN_SETTINGS")
    else
        S:Fire("TOGGLE_WINDOW")
    end
end
