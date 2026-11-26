-- SakedMap: dungeon map with an estimated "you are here" arrow for WoW Forever.
-- Core: saved settings, entering/leaving dungeons, the 10 Hz update, slash commands.
local ADDON, ns = ...

local L = ns.L
local Motion = ns.Motion

local DEFAULTS = {
    shown = true,          -- open the map when entering a dungeon that has data
    follow = true,         -- keep the arrow centred
    faint = true,          -- draw other levels faintly (else hide them)
    scale = 2.0,           -- pixels per yard
    point = nil,           -- window position
    w = 460, h = 400,
    entrances = {},        -- [mapID] = { {x, y, z}, ... } learned zone-in spots
    last = nil,            -- { map, x, y, z, t } for /reload inside a dungeon
    cal = {},              -- compass calibration (Motion)
    debug = false,
}

local core = CreateFrame("Frame")
ns.core = core
local state = {
    mapID = nil, data = nil, grid = nil, filter = nil,
    acc = 0, zoneInAt = nil, learned = false, area = nil, areaRaw = nil,
}
ns.state = state

local function print_(...) print("|cff66ccffSakedMap|r", ...) end
ns.print = print_

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then dst[k] = {} ; copyDefaults(dst[k], v) else dst[k] = v end
        end
    end
end

-------------------------------------------------------------------- subzone -> room names of the data

local function englishArea(data, text)
    if not text or text == "" then return nil end
    local loc = GetLocale()
    local rev = data._rev
    if not rev then
        rev = {}
        for _, g in ipairs(data.groups) do
            if g.name ~= "" then rev[g.name] = g.name end
        end
        for _, a in ipairs(data.areas or {}) do
            if a ~= "" then rev[a] = a end
        end
        local names = data.names and data.names[loc]
        if names then
            for en, localName in pairs(names) do rev[localName] = en end
        end
        data._rev = rev
    end
    return rev[text]
end

function ns.LocalName(data, en)
    local names = data.names and data.names[GetLocale()]
    return names and names[en] or en
end

local function updateArea()
    if not state.data then return end
    local ok, text = pcall(GetSubZoneText)
    if not ok or (issecretvalue and issecretvalue(text)) then text = nil end
    -- (no fallback to GetMinimapZoneText: in a room without a name it shows the dungeon's name, which is
    -- also the name of one room, and would point the filter at the wrong place)
    state.areaRaw = text
    state.area = englishArea(state.data, text)
    if state.filter then state.filter.area = state.area end
end

-------------------------------------------------------------------- dungeon enter / leave

local function headingKnown()
    local f = Motion:Facing()
    return f ~= nil
end

local function entranceList(mapID, data)
    local list = {}
    for _, e in ipairs(data.entrances or {}) do list[#list + 1] = e end
    for _, e in ipairs(SakedMapDB.entrances[mapID] or {}) do list[#list + 1] = e end
    return list
end

function ns.Enter(mapID, how)
    local data = ns.data and ns.data[mapID]
    if not data then return ns.Leave() end
    if state.mapID ~= mapID or not state.grid then
        state.grid = ns.Grid.new(data)
    end
    state.mapID, state.data = mapID, data
    state.filter = ns.Filter.new(state.grid)
    state.learned = false
    updateArea()
    local known = headingKnown()
    local last = SakedMapDB.last
    if how == "reload" and last and last.map == mapID and time() - (last.t or 0) < 900 then
        -- /reload inside: start where we were
        state.filter:seedEntrances({ { last.x, last.y, last.z } }, known, 0.85)
        state.zoneInAt = nil
    else
        local list = entranceList(mapID, data)
        if #list > 0 then
            state.filter:seedEntrances(list, known, 0.7)
        else
            state.filter:seedGlobal(known)
        end
        state.zoneInAt = GetTime()
    end
    ns.Map:SetDungeon(data, state.grid)
    if SakedMapDB.shown then ns.Map:Show() end
end

function ns.Leave()
    state.mapID, state.data, state.filter = nil, nil, nil
    if ns.Map then ns.Map:SetDungeon(nil) end
end

local function currentInstance()
    local _, itype, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    if itype == "none" then return nil end
    return instanceMapID
end

-- remember where this dungeon really starts once the filter is sure (its guesses' starting points)
local function learnEntrance()
    local f = state.filter
    if state.learned or not state.zoneInAt or not f:isLocked() then return end
    if GetTime() - state.zoneInAt > 600 then state.learned = true; return end
    local x, y, z, spread = f:origin()
    if not x or spread > 6 then return end
    state.learned = true
    local list = SakedMapDB.entrances[state.mapID] or {}
    for _, e in ipairs(entranceList(state.mapID, state.data)) do
        if (e[1] - x) ^ 2 + (e[2] - y) ^ 2 < 100 and math.abs(e[3] - z) < 6 then return end
    end
    if #list >= 6 then table.remove(list, 1) end
    list[#list + 1] = { math.floor(x * 10) / 10, math.floor(y * 10) / 10, math.floor(z * 10) / 10 }
    SakedMapDB.entrances[state.mapID] = list
    if SakedMapDB.debug then print_(L.LEARNED_ENTRANCE) end
end

-------------------------------------------------------------------- the 10 Hz tick

local TICK = 0.1
local outdoorAcc, sweepAt = 0, 0
core:SetScript("OnUpdate", function(_, elapsed)
    if not state.filter then
        -- outdoors: keep reading facing so the compass calibration learns while you play
        outdoorAcc = outdoorAcc + elapsed
        if outdoorAcc > 0.5 then
            outdoorAcc = 0
            Motion:Facing()
        end
        return
    end
    state.acc = state.acc + elapsed
    if state.acc < TICK then return end
    local dt = state.acc
    state.acc = 0
    local now = GetTime()
    state.grid.clock = now
    if now > sweepAt then
        sweepAt = now + 15
        state.grid:sweep(now, now - 30) -- drop floor rows unused for 30 s
    end
    if dt > 1 then dt = 1 end -- loading hitches: do not teleport the guesses
    local m = Motion:Sample()
    state.motion = m
    state.filter:predict(dt, m)
    local est = state.filter:estimate(m.facing)
    state.est = est
    if est then
        local last = SakedMapDB.last or {}
        last.map, last.x, last.y, last.z, last.t = state.mapID, est.x, est.y, est.z, time()
        SakedMapDB.last = last
        learnEntrance()
    end
    ns.Map:UpdatePlayer(est, m)
end)

-------------------------------------------------------------------- events

core:RegisterEvent("ADDON_LOADED")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("ZONE_CHANGED_NEW_AREA")
core:RegisterEvent("ZONE_CHANGED")
core:RegisterEvent("ZONE_CHANGED_INDOORS")
for _, e in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_STARTED_LOOKING",
    "PLAYER_STOPPED_LOOKING", "PLAYER_STARTED_TURNING", "PLAYER_STOPPED_TURNING" }) do
    pcall(core.RegisterEvent, core, e)
end

core:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        SakedMapDB = SakedMapDB or {}
        copyDefaults(SakedMapDB, DEFAULTS)
        Motion:SetCalibration(SakedMapDB.cal)
        Motion:Init()
        ns.Map:Create()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = a1, a2
        local id = currentInstance()
        if id and ns.data and ns.data[id] then
            ns.Enter(id, (isReload or isLogin) and "reload" or "zonein")
        else
            ns.Leave()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local id = currentInstance()
        if id and ns.data and ns.data[id] then
            if id ~= state.mapID then ns.Enter(id, "zonein") end
        elseif state.mapID then
            ns.Leave()
        end
        updateArea()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        updateArea()
        if ns.Map then ns.Map:UpdateTitle() end
    else
        Motion:OnEvent(event)
    end
end)

-------------------------------------------------------------------- slash commands

local function diag()
    local f, src = Motion:Facing()
    local r, why = Motion:CompassRotation()
    local ok, cur = pcall(GetUnitSpeed, "player")
    local secretSpeed = ok and issecretvalue and issecretvalue(cur)
    print_(L.DIAG_HEADER)
    print_(("  GetPlayerFacing: %s"):format(tostring(Motion:ApiFacing())))
    print_(("  %s: %s (%s), rotateMinimap=%s"):format(L.COMPASS, r and ("%.3f"):format(r) or "-", why, tostring(GetCVar("rotateMinimap"))))
    print_(("  %s: %s (%s)"):format(L.FACING, f and ("%.1f°"):format(math.deg(f) % 360) or L.NONE, src or "-"))
    local cal = SakedMapDB.cal
    print_(("  %s: sign %s, offset %.2f, %d samples"):format(L.CALIBRATION, tostring(cal.sign), cal.offset or 0, cal.n or 0))
    print_(("  GetUnitSpeed: %s"):format(secretSpeed and "secret" or tostring(cur)))
    print_(("  %s: '%s' -> %s"):format(L.SUBZONE, tostring(state.areaRaw), tostring(state.area)))
    local id = currentInstance()
    print_(("  instance: %s, %s: %s"):format(tostring(id), L.DATA, (id and ns.data and ns.data[id]) and L.YES or L.NO))
    if state.est then
        print_(("  %s: %.1f, %.1f, %.1f  ±%.0f yd"):format(L.ESTIMATE, state.est.x, state.est.y, state.est.z, state.est.spread))
    end
end

SLASH_SAKEDMAP1 = "/smap"
SLASH_SAKEDMAP2 = "/sakedmap"
SlashCmdList.SAKEDMAP = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" or msg == "show" or msg == "mapa" then
        ns.Map:Toggle()
    elseif msg == "diag" then
        diag()
    elseif msg == "reset" or msg == "perdido" then
        if state.filter then
            state.filter:seedGlobal(headingKnown())
            print_(L.RESEEDED)
        end
    elseif msg == "brujula" or msg == "compass" then
        SetCVar("rotateMinimap", "1")
        print_(L.COMPASS_ON)
    elseif msg == "test" then
        ns.Test:Toggle()
    elseif msg == "debug" then
        SakedMapDB.debug = not SakedMapDB.debug
        print_("debug", SakedMapDB.debug)
    elseif msg == "olvidar" or msg == "forget" then
        if state.mapID then SakedMapDB.entrances[state.mapID] = nil end
        print_(L.FORGOT)
    else
        print_(L.HELP)
    end
end
