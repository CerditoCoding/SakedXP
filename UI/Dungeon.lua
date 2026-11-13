-- SakedXP · Dungeon mode
-- Inside a dungeon: a checklist of its quests (have / missing / locked /
-- starts inside), required items, live objectives, bosses ticked as they
-- die, and what to turn in afterwards. Near an entrance: a reminder of the
-- quests you'd be missing. Data: Forever Dungeon Journal (optional).

local _, S = ...
local C, UI, DB, E = S.C, S.UI, S.DB, S.Engine
local rgb = UI.rgb

local D = {}
S.Dungeon = D

local frame, content, scroll
local pool = {}
local current        -- dungeon key (FDJ internal name)
local kills = {}     -- [dungeonKey] = { [bossName] = true, t = lastActivity }

local function FDJ() return _G.ForeverDungeonJournal_NS end

function D.Data(key)
    local ns = FDJ()
    return ns and ns.DB and ns.DB[key]
end

function D.Detect()
    local ns = FDJ()
    if not (ns and ns.CurrentDungeon) then return end
    local ok, key = pcall(ns.CurrentDungeon)
    if ok and key and D.Data(key) then return key end
end

---------------------------------------------------------------------------
-- Quest status
---------------------------------------------------------------------------
local function itemCount(id) return (id and id > 0 and GetItemCount(id, true)) or 0 end

-- The journal often lists the *last* quest of a chain; the dungeon quest is a
-- step inside it. Work out the chain and the step the player is on.
function D.Chain(q)
    local ns = FDJ()
    local steps = {}
    local chain = ns and ns.QUEST_PREREQ_CHAINS and ns.QUEST_PREREQ_CHAINS[q.id]
    for _, link in ipairs(chain or {}) do
        if link.id ~= q.id then steps[#steps + 1] = { id = link.id, name = link.name } end
    end
    steps[#steps + 1] = { id = q.id, name = q.name, entry = true }
    return steps
end

local function stepDetails(step, q)
    if step.entry then return q end
    local ns = FDJ()
    return (ns and ns.QUEST_PREREQ_DETAILS and ns.QUEST_PREREQ_DETAILS[step.id]) or {}
end

-- status: done | complete | active | inside | missing | locked
-- info = { step, index, total, details, why }
function D.QuestStatus(q)
    local steps = D.Chain(q)
    local log = S.GetQuestLogSet()
    -- a step already in the quest log wins (the furthest one)
    for i = #steps, 1, -1 do
        local st = steps[i]
        local state = log[st.id]
        if state then
            local info = { step = st, index = i, total = #steps, details = stepDetails(st, q) }
            return state == "complete" and "complete" or "active", info
        end
    end
    local cur
    for i, st in ipairs(steps) do
        if not S.IsQuestDone(st.id) then cur = i break end
    end
    if not cur then return "done", { index = #steps, total = #steps } end
    local st = steps[cur]
    local d = stepDetails(st, q)
    local info = { step = st, index = cur, total = #steps, details = d }
    local req = d.requires or (st.entry and q.requires) or 0
    if req > UnitLevel("player") then
        info.why = ("requiere nivel %d"):format(req)
        return "locked", info
    end
    if st.entry and q.startsInDungeon then return "inside", info end
    return "missing", info
end

function D.Quests(key)
    local data = D.Data(key)
    local out = {}
    if not data or not data.quests then return out end
    local faction = UnitFactionGroup("player")
    local _, class = UnitClass("player")
    for _, q in ipairs(data.quests) do
        local okFaction = not q.faction or q.faction == "Both" or q.faction == faction
        local okClass = not q.classOnly or q.classOnly == class
        if okFaction and okClass and not q.hideFromMainList and not q.unavailable and not q.repeatable then
            out[#out + 1] = q
        end
    end
    table.sort(out, function(a, b) return (a.level or 0) < (b.level or 0) end)
    return out
end

-- items the quests need (requiredItem / requiredItems), with what you're missing
function D.MissingItems(q)
    local out = {}
    local function check(it)
        if type(it) ~= "table" then return end
        local id, name, need, note = it[1], it[2], it[3] or 1, it[4] or it[5]
        if type(note) ~= "string" then note = nil end
        if id and itemCount(id) < need then out[#out + 1] = { id = id, name = name, need = need, note = note } end
    end
    -- requiredItem is collected *inside* for most quests: only flag it when the quest is active
    if q.requiredItems then for _, it in ipairs(q.requiredItems) do check(it) end end
    return out
end

function D.Summary(key)
    local s = { total = 0, missing = 0, active = 0, complete = 0, done = 0, locked = 0, inside = 0, items = 0 }
    for _, q in ipairs(D.Quests(key)) do
        local st = D.QuestStatus(q)
        s.total = s.total + 1
        s[st] = (s[st] or 0) + 1
        if st == "active" or st == "missing" then s.items = s.items + #D.MissingItems(q) end
    end
    return s
end

---------------------------------------------------------------------------
-- Boss kills
---------------------------------------------------------------------------
local function bossFor(key, npcID, name)
    local data = D.Data(key)
    if not data or not data.bosses then return end
    for _, b in ipairs(data.bosses) do
        if npcID and b.npcID == npcID then return b end
        if name then
            if b.name == name then return b end
            for _, a in ipairs(b.aliases or {}) do if a == name then return b end end
        end
    end
end

local function markKill(b)
    if not (current and b) then return end
    kills[current] = kills[current] or {}
    if kills[current][b.name] then return end
    kills[current][b.name] = true
    kills[current].t = GetTime()
    S.Print("|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " .. b.name)
    D.Refresh()
end

-- WoW Forever runs on the modern client, where addons can't read the combat
-- log; boss kills come from encounter events (and a click on the boss row).
local function toggleKill(b)
    if not (current and b) then return end
    kills[current] = kills[current] or {}
    kills[current][b.name] = not kills[current][b.name] or nil
    kills[current].t = GetTime()
    D.Refresh()
end
S:RegisterEvent("ENCOUNTER_END", function(_, _, name, _, _, success)
    if current and success == 1 then markKill(bossFor(current, nil, name)) end
end)
S:RegisterEvent("BOSS_KILL", function(_, _, name)
    if current then markKill(bossFor(current, nil, name)) end
end)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local STATUS = {
    done     = { "Entregada", C.textMute, "Interface\\RaidFrame\\ReadyCheck-Ready" },
    complete = { "Lista para entregar", C.good, "Interface\\GossipFrame\\ActiveQuestIcon" },
    active   = { "En tu registro", C.goldSoft, "Interface\\GossipFrame\\AvailableQuestIcon" },
    inside   = { "Empieza adentro", C.info, "Interface\\Icons\\INV_Misc_Note_01" },
    missing  = { "Te falta", C.bad, "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    locked   = { "Bloqueada", C.textDim, "Interface\\RaidFrame\\ReadyCheck-Waiting" },
}

local function build()
    frame = UI.Window("SakedXPDungeon", nil, 380, 520, { strata = "MEDIUM", escClose = false,
        onMoved = function(f)
            local p, _, rp, x, y = f:GetPoint(1)
            S.db.dungeonPoint = { p, "UIParent", rp, x, y }
        end })
    local p = S.db.dungeonPoint or { "LEFT", "UIParent", "LEFT", 40, 40 }
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    frame:Hide()
    frame:SetScale(S.db.scale or 1)

    frame.sub = UI.Text(frame.header, 11, C.textDim)
    frame.sub:SetPoint("LEFT", frame.brand, "RIGHT", 10, -1)

    local dj = UI.IconButton(frame.header, "Interface\\Icons\\INV_Misc_Book_09", "Abrir el Diario de Mazmorras")
    dj:SetPoint("RIGHT", frame.closeButton, "LEFT", -6, 0)
    dj:SetScript("OnClick", function()
        local fn = _G.ForeverDungeonJournal_OnAddonCompartmentClick
        if fn then pcall(fn, nil, "LeftButton") end
    end)

    scroll, content = UI.Scroll(frame)
    scroll:SetPoint("TOPLEFT", 0, -40)
    scroll:SetPoint("BOTTOMRIGHT", 0, 10)
end

local function widget(kind, i)
    pool[kind] = pool[kind] or {}
    local w = pool[kind][i]
    if w then return w end
    if kind == "card" then
        w = UI.Panel(content, C.bgAlt, C.border, 0.5, 12)
        w.head = UI.Section(w, "", "", 12)
        w.head:SetPoint("TOPLEFT", 12, -10)
        w.head:SetPoint("RIGHT", -12, 0)
    elseif kind == "row" then
        w = CreateFrame("Frame", nil, content)
        w.icon = w:CreateTexture(nil, "ARTWORK")
        w.icon:SetSize(14, 14)
        w.icon:SetPoint("TOPLEFT", 0, -1)
        w.title = UI.Text(w, 12, C.text, { justifyV = "TOP" })
        w.title:SetPoint("TOPLEFT", 20, 0)
        w.tag = UI.Text(w, 10, C.textDim, { justify = "RIGHT" })
        w.tag:SetPoint("TOPRIGHT", 0, 0)
        w.body = UI.Text(w, 11, C.textDim, { justifyV = "TOP" })
        w.body:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 0, -3)
        w.body:SetSpacing(2)
        w:EnableMouse(true)
        w:SetScript("OnMouseUp", function(self) if self.onClick then self.onClick() end end)
    elseif kind == "text" then
        w = UI.Text(content, 11, C.textDim, { justifyV = "TOP" })
        w:SetSpacing(2)
    end
    pool[kind][i] = w
    return w
end

local function hideAll()
    for _, list in pairs(pool) do for _, w in ipairs(list) do w:Hide() end end
end

local function qname(q) return q.name or ("#" .. q.id) end

function D.Current() return current end

function D.Refresh()
    if not (frame and frame:IsShown() and current) then return end
    hideAll()
    local data = D.Data(current)
    if not data then return end
    local W = frame:GetWidth() - 28
    local inner = W - 28
    frame.brand:SetText(current)
    frame.sub:SetText("Nv " .. (data.level or "?"))

    local used = { card = 0, row = 0, text = 0 }
    local function take(kind) used[kind] = used[kind] + 1; return widget(kind, used[kind]) end
    local y = 8

    local function card(title, subtitle, rowsFn)
        local c = take("card")
        c.head.title:SetText(title)
        c.head.sub:SetText(subtitle or "")
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -y)
        c:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -y)
        local cy = 34
        rowsFn(function(icon, title2, tag, tagColor, body, iconFull, onClick)
            local r = take("row")
            r.onClick = onClick
            r:SetParent(c)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -cy)
            r:SetWidth(inner)
            r.icon:SetTexture(icon)
            if iconFull then r.icon:SetTexCoord(0, 1, 0, 1) else r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            r.title:SetWidth(inner - 110)
            r.title:SetText(title2)
            r.tag:SetText(tag or "")
            r.tag:SetTextColor(rgb(tagColor or C.textDim))
            r.body:SetWidth(inner - 20)
            r.body:SetText(body or "")
            local h = r.title:GetStringHeight() + ((body and body ~= "") and (r.body:GetStringHeight() + 4) or 0)
            r:SetHeight(h)
            r:Show()
            cy = cy + h + 9
        end)
        c:SetHeight(cy + 4)
        c:Show()
        y = y + cy + 14
    end

    local quests = D.Quests(current)
    local groups = { missing = {}, inside = {}, active = {}, complete = {}, locked = {}, done = {} }
    for _, q in ipairs(quests) do
        local st, info = D.QuestStatus(q)
        table.insert(groups[st], { q = q, info = info or {} })
    end

    local function stepTag(info)
        if info.total and info.total > 1 then return ("paso %d de %d"):format(info.index, info.total) end
    end
    local function stepTitle(it)
        local st = it.info.step
        if st and not st.entry then
            return (st.name or ("#" .. st.id)) .. S.Color("textDim", "  ·  cadena: " .. qname(it.q))
        end
        return qname(it.q)
    end

    -- 1) what you're missing (take before going in)
    if #groups.missing > 0 or #groups.locked > 0 then
        card("Te faltan", ("%d misiones o pasos de cadena"):format(#groups.missing), function(add)
            for _, it in ipairs(groups.missing) do
                local q, d = it.q, it.info.details or it.q
                local body = S.Color("textDim", "Se toma: ") .. (d.pickup or q.pickup or "?")
                if d.objective and not it.info.step.entry then body = body .. "\n" .. d.objective end
                local warn = d.warning or q.warning
                if warn then body = body .. "\n" .. S.Color("amber", warn) end
                for _, m in ipairs(D.MissingItems(d)) do
                    body = body .. "\n" .. S.Color("bad", ("Necesitás %dx %s"):format(m.need, m.name or "?")) .. (m.note and (S.Color("textDim", " · " .. m.note)) or "")
                end
                add(STATUS.missing[3], stepTitle(it), stepTag(it.info) or ("nv " .. (q.level or "?")), C.bad, body, true)
            end
            for _, it in ipairs(groups.locked) do
                add(STATUS.locked[3], stepTitle(it), "bloqueada", C.textDim, S.Color("textDim", it.info.why or ""), true)
            end
        end)
    end

    -- 2) objectives inside
    local work = {}
    for _, it in ipairs(groups.active) do work[#work + 1] = it end
    for _, it in ipairs(groups.inside) do work[#work + 1] = it end
    if #work > 0 then
        card("Objetivos", "se actualizan solos", function(add)
            for _, it in ipairs(work) do
                local q = it.q
                local sid = it.info.step and it.info.step.id or q.id
                local lines = {}
                if S.IsOnQuest(sid) then
                    for _, o in ipairs(E.Objectives(sid)) do
                        lines[#lines + 1] = (o.finished and ("|TInterface\\RaidFrame\\ReadyCheck-Ready:11|t " .. S.Color("textMute", o.text or "")) or (o.text or ""))
                    end
                else
                    local where = q.startItem and q.startItem[4] or q.startObject and q.startObject[3]
                    lines[#lines + 1] = S.Color("info", "Empieza adentro" .. (where and (": " .. where) or ""))
                end
                if q.objective and #lines == 0 then lines[#lines + 1] = q.objective end
                if q.note then lines[#lines + 1] = S.Color("info", q.note) end
                for _, m in ipairs(D.MissingItems(q)) do
                    lines[#lines + 1] = S.Color("bad", ("Necesitás %dx %s"):format(m.need, m.name or "?"))
                end
                local st = S.IsOnQuest(sid) and STATUS.active or STATUS.inside
                add(st[3], stepTitle(it), stepTag(it.info) or st[1], st[2], table.concat(lines, "\n"), true)
            end
        end)
    end

    -- 3) bosses
    if data.bosses and #data.bosses > 0 then
        local levels = FDJ() and FDJ().BOSS_LEVELS and FDJ().BOSS_LEVELS[current] or {}
        local killed = kills[current] or {}
        local n = 0
        for _, b in ipairs(data.bosses) do if killed[b.name] then n = n + 1 end end
        card("Jefes", ("%d de %d · clic para marcar"):format(n, #data.bosses), function(add)
            for i, b in ipairs(data.bosses) do
                local done = killed[b.name]
                add(done and "Interface\\RaidFrame\\ReadyCheck-Ready" or (b.customIcon or "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"),
                    (done and S.Color("textMute", i .. ". " .. b.name) or (i .. ". " .. b.name)),
                    levels[b.name] and ("nv " .. levels[b.name]) or "", done and C.good or C.textDim, nil, true,
                    function() toggleKill(b) end)
            end
        end)
    end

    -- 4) after the run
    if #groups.complete > 0 then
        card("Al salir", "entregá estas misiones", function(add)
            for _, it in ipairs(groups.complete) do
                local d = it.info.details or it.q
                add(STATUS.complete[3], stepTitle(it), "lista", C.good,
                    S.Color("textDim", "Entregar: ") .. (d.turnin or it.q.turnin or "?"), true)
            end
        end)
    end

    if #quests == 0 and not data.bosses then
        local t = take("text")
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -y)
        t:SetWidth(W - 4)
        t:SetText("No hay datos de misiones para esta mazmorra.")
        t:Show()
        y = y + 30
    end

    content:SetHeight(y + 6)
    local maxH = 560
    frame:SetHeight(math.min(maxH, y + 56))
    scroll:UpdateThumb()
end


function D.Open(key)
    if not frame then build() end
    current = key or current
    if not current then return end
    frame:Show()
    D.Refresh()
end

function D.Close() if frame then frame:Hide() end end

---------------------------------------------------------------------------
-- Enter / leave / approach
---------------------------------------------------------------------------
local warned = {}

local function announce(key)
    local s = D.Summary(key)
    local msg = ("%s: %d misiones para vos"):format(S.Color("goldSoft", key), s.total)
    if s.missing > 0 then msg = msg .. S.Color("bad", (" · te faltan %d"):format(s.missing)) end
    if s.active + s.inside > 0 then msg = msg .. S.Color("good", (" · %d para hacer adentro"):format(s.active + s.inside)) end
    if s.items > 0 then msg = msg .. S.Color("amber", (" · faltan %d ítems"):format(s.items)) end
    S.Print(msg)
end

local function onZone()
    local inInstance, kind = IsInInstance()
    if inInstance and (kind == "party" or kind == "raid") then
        local key = D.Detect()
        if key then
            local k = kills[key]
            if k and k.t and GetTime() - k.t > 3600 then kills[key] = nil end -- a new run
            if key ~= current then announce(key) end
            current = key
            S:Fire("DUNGEON_ENTERED", key)
            if S.db.dungeonPanel then D.Open(key) end
        end
    elseif current then
        current = nil
        D.Close()
        S:Fire("DUNGEON_LEFT")
    end
end
S:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, onZone) end)
S:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, onZone) end)
for _, ev in ipairs({ "QUEST_LOG_UPDATE", "BAG_UPDATE_DELAYED" }) do
    S:RegisterEvent(ev, function() if current then S:Debounce("dungeon", 0.3, D.Refresh) end end)
end

-- reminder when you walk up to an entrance with quests still missing
C_Timer.NewTicker(5, function()
    if current or IsInInstance() then return end
    local ns = FDJ()
    if not (ns and ns.DB) then return end
    local map, px, py = DB.PlayerPos()
    if not (map and px) then return end
    for key, data in pairs(ns.DB) do
        local ent = data.entrance
        if ent and ent.mapID == map and not warned[key] then
            local dx, dy = ent.x * 100 - px, ent.y * 100 - py
            if dx * dx + dy * dy < 9 then -- about 3% of the map
                warned[key] = true
                local s = D.Summary(key)
                if s.missing > 0 or s.items > 0 then
                    S.Print(S.Color("amber", "Antes de entrar a ") .. S.Color("goldSoft", key) .. S.Color("amber", (": te faltan %d misiones y %d ítems."):format(s.missing, s.items)))
                    S:Fire("DUNGEON_NEAR", key, s)
                end
            end
        end
    end
end)

SLASH_SAKEDXPDUNGEON1 = "/sxpd"
SlashCmdList.SAKEDXPDUNGEON = function(msg)
    msg = msg and msg:gsub("^%s+", ""):gsub("%s+$", "")
    local key = (msg and msg ~= "" and msg) or current or D.Detect()
    if key and D.Data(key) then D.Open(key)
    else S.Print("no estás en una mazmorra conocida. Usá /sxpd <nombre en inglés>, por ejemplo /sxpd Krol'dok Stronghold") end
end
