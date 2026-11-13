-- SakedXP · Guide engine
-- Registry of guides, per-step completion, automatic advancing and saved
-- progress. Fully standalone: quest state comes from the game client, extra
-- knowledge (names, givers, locations) from QuestieDB when installed.
--
-- guide   = { id, name, group, subgroup, faction?, map?, minLevel?, maxLevel?, next?, steps = {...} }
-- step    = { elements = {...}, only = "Alliance"|"Horde"|"Warrior"|... , note? }
-- element = { tag = "accept"|"turnin"|"complete"|"goto"|"xp"|"manual"|"home"|"fp"|"text",
--             questId?, obj?, text?, zone? (uiMapID), x?, y? (0-100), radius?, level?, npc? }

local _, S = ...
local DB = S.DB
local E = {}
S.Engine = E

E.guides = {}       -- id -> guide (raw)
E.order = {}        -- registration order
E.guide = nil       -- active processed guide
E.current = 1

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------
function E.Register(guide)
    assert(guide.id and guide.name and guide.steps, "SakedXP guide needs id, name and steps")
    if not E.guides[guide.id] then E.order[#E.order + 1] = guide.id end
    E.guides[guide.id] = guide
end

-- "Alliance", "Horde", class tokens ("Warrior") and race tokens ("NightElf"),
-- separated by "/"; a leading "!" excludes. Positive tokens are OR-ed.
local function applies(only)
    if not only then return true end
    local faction = UnitFactionGroup("player")
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local hasPositive, positiveHit = false, false
    for token in tostring(only):gmatch("[^/,%s]+") do
        local neg = token:sub(1, 1) == "!"
        local t = neg and token:sub(2) or token
        local hit = t == faction or t:upper() == class or t == race
        if neg then
            if hit then return false end
        else
            hasPositive = true
            if hit then positiveHit = true end
        end
    end
    return not hasPositive or positiveHit
end
E.Applies = applies

function E.GuideAvailable(g)
    if g.faction and g.faction ~= UnitFactionGroup("player") then return false end
    return applies(g.only)
end

function E.List(filter)
    local out = {}
    for _, id in ipairs(E.order) do
        local g = E.guides[id]
        if E.GuideAvailable(g) and (not filter or filter(g)) then out[#out + 1] = g end
    end
    return out
end

function E.FindByName(name)
    for _, g in ipairs(E.List()) do
        if g.name == name then return g end
    end
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
local GOLD = "|cffe3bb72"

function E.QuestName(id)
    if not id then return "?" end
    local n = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if not n or n == "" then n = DB.Q(id, "name") end
    return n or ("misión #" .. id)
end

local function logIndexFor(id)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        return C_QuestLog.GetLogIndexForQuestID(id)
    end
    if GetNumQuestLogEntries then
        for i = 1, GetNumQuestLogEntries() do
            local _, _, _, isHeader, _, _, _, qid = GetQuestLogTitle(i)
            if not isHeader and qid == id then return i end
        end
    end
end

-- { {text, finished}, ... } for a quest in the log
function E.Objectives(id)
    local out = {}
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, list = pcall(C_QuestLog.GetQuestObjectives, id)
        if ok and type(list) == "table" and #list > 0 then
            for _, o in ipairs(list) do out[#out + 1] = { text = o.text, finished = o.finished } end
            return out
        end
    end
    local idx = logIndexFor(id)
    if idx and GetNumQuestLeaderBoards then
        for i = 1, GetNumQuestLeaderBoards(idx) do
            local text, _, finished = GetQuestLogLeaderBoard(i, idx)
            out[#out + 1] = { text = text, finished = finished }
        end
    end
    return out
end

local function giverName(qid, key)
    local name = DB.GiverInfo(qid, key)
    return name
end

function E.ElementText(e)
    local tag = e.tag
    if tag == "accept" then
        local giver = e.npc or giverName(e.questId, "startedBy")
        return "Aceptá " .. GOLD .. E.QuestName(e.questId) .. "|r" .. (giver and ("  |cff9a948a(" .. giver .. ")|r") or "")
    elseif tag == "turnin" then
        local giver = e.npc or giverName(e.questId, "finishedBy")
        return "Entregá " .. GOLD .. E.QuestName(e.questId) .. "|r" .. (giver and ("  |cff9a948a(" .. giver .. ")|r") or "")
    elseif tag == "complete" then
        local id = e.questId
        local name = GOLD .. E.QuestName(id) .. "|r"
        if S.IsQuestDone(id) then return name .. ": entregada" end
        local state = S.GetQuestLogSet()[id]
        if not state then
            local txt = DB.Q(id, "objectivesText")
            return name .. (txt and txt[1] and ("\n|cff9a948a" .. txt[1] .. "|r") or "")
        end
        if state == "complete" then return name .. ": |cff8fae5a¡completa!|r" end
        local objs = E.Objectives(id)
        local lines = { name }
        for i, o in ipairs(objs) do
            if not e.obj or e.obj == i then
                lines[#lines + 1] = (o.finished and "|cff6b665e" or "|cffe6e1d8") .. "  " .. (o.text or "?") .. "|r"
            end
        end
        return table.concat(lines, "\n")
    elseif tag == "xp" then
        return e.text or ("Llegá a nivel " .. e.level)
    elseif tag == "home" then
        return e.text or ("Fijá tu piedra de hogar en " .. (e.place or "la posada"))
    elseif tag == "fp" then
        return e.text or ("Conseguí la ruta de vuelo de " .. (e.place or "esta zona"))
    elseif tag == "goto" then
        return e.text
    end
    return e.text
end

---------------------------------------------------------------------------
-- Completion
---------------------------------------------------------------------------
local events = {}  -- transient flags set by game events (home bound, new FP)

local function playerDistance(e)
    local map, px, py = DB.PlayerPos()
    if not map or not px or not e.zone then return end
    local tx, ty = e.x, e.y
    if map ~= e.zone then
        local cont, world = C_Map.GetWorldPosFromMapPos(e.zone, CreateVector2D(e.x / 100, e.y / 100))
        if not world then return end
        local _, pos = C_Map.GetMapPosFromWorldPos(cont, world, map)
        if not pos then return end
        tx, ty = pos.x * 100, pos.y * 100
    end
    local w, h = 1000, 1000
    if C_Map.GetMapWorldSize then w, h = C_Map.GetMapWorldSize(map) end
    local dx, dy = (tx - px) / 100 * w, (ty - py) / 100 * h
    return math.sqrt(dx * dx + dy * dy)
end
E.Distance = playerDistance

-- Yards from the player to a map point (nil when unknown).
function E.TargetDistance(map, x, y)
    if not (map and x and y) then return end
    return playerDistance({ zone = map, x = x, y = y })
end

function E.EvaluateElement(e, step)
    local tag, id = e.tag, e.questId
    local done
    -- accept lines whose prerequisite isn't done are skipped automatically
    if e.requires and tag == "accept" then
        local missing = not S.IsQuestDone(e.requires) and not S.IsOnQuest(id) and not S.IsQuestDone(id)
        e.skip = missing or S.cdb.skippedQuests[id] or nil
    end
    if e.skip then
        done = false
    elseif tag == "accept" then
        done = S.IsOnQuest(id) or S.IsQuestDone(id)
    elseif tag == "turnin" then
        done = S.IsQuestDone(id)
    elseif tag == "complete" then
        if S.IsQuestDone(id) then
            done = true
        else
            local state = S.GetQuestLogSet()[id]
            if state == "complete" then
                done = true
            elseif state and e.obj then
                local o = E.Objectives(id)[e.obj]
                done = o and o.finished or false
            else
                done = false
            end
        end
    elseif tag == "xp" then
        done = UnitLevel("player") >= (e.level or 0)
    elseif tag == "manual" then
        done = step.manualDone and step.manualDone[e] or false
    elseif tag == "home" then
        done = (step.manualDone and step.manualDone[e]) or (events.home and step.active) or false
    elseif tag == "fp" then
        done = (step.manualDone and step.manualDone[e]) or (events.fp and step.active) or false
    elseif tag == "goto" then
        if e.travel then
            local d = playerDistance(e)
            done = (d and d <= (e.radius or 20)) or e.completed or false
        else
            done = false
        end
    end
    e.completed = done and true or false
    if tag ~= "goto" or e.text then e.displayText = E.ElementText(e) end
    return e.completed
end

-- A step is complete when every actionable element is done.
function E.StepComplete(step)
    if step.forced then return true end
    local actionable = 0
    for _, e in ipairs(step.elements) do
        E.EvaluateElement(e, step)
        if not e.textOnly then
            actionable = actionable + 1
            if not (e.completed or e.skip) then return false end
        end
    end
    return actionable > 0
end

---------------------------------------------------------------------------
-- Processing / loading
---------------------------------------------------------------------------
local function process(raw)
    local g = { raw = raw, id = raw.id, name = raw.name, displayname = raw.name, group = raw.group or "SakedXP",
        subgroup = raw.subgroup, next = raw.next, map = raw.map, dynamic = raw.dynamic,
        minLevel = raw.minLevel, maxLevel = raw.maxLevel, steps = {} }
    for _, rs in ipairs(raw.steps) do
        if applies(rs.only) then
            local st = { elements = {}, note = rs.note, raw = rs }
            for _, re in ipairs(rs.elements or {}) do
                if applies(re.only) then
                    local e = {}
                    for k, v in pairs(re) do e[k] = v end
                    e.step = st
                    if e.tag == "goto" then
                        e.arrow = true
                        e.zone = e.zone or raw.map
                        e.textOnly = not e.travel
                    elseif e.tag == "text" then
                        e.textOnly = true
                    end
                    st.elements[#st.elements + 1] = e
                end
            end
            if #st.elements > 0 then
                st.index = #g.steps + 1
                g.steps[#g.steps + 1] = st
            end
        end
    end
    return g
end

local function progress(g)
    S.cdb.progress = S.cdb.progress or {}
    local p = S.cdb.progress[g.id]
    if not p then p = { step = 1, manual = {} }; S.cdb.progress[g.id] = p end
    return p
end

local function restoreManual(g)
    local p = progress(g)
    for si, st in ipairs(g.steps) do
        for ei, e in ipairs(st.elements) do
            if p.manual[si .. ":" .. ei] then
                st.manualDone = st.manualDone or {}
                st.manualDone[e] = true
            end
        end
    end
end

function E.Load(raw, silent)
    if type(raw) == "string" then raw = E.guides[raw] end
    if not raw then return false end
    local g = process(raw)
    E.guide = g
    restoreManual(g)
    local p = progress(g)
    E.current = math.max(1, math.min(p.step or 1, #g.steps))
    S.cdb.active = raw.dynamic and { kind = "dynamic", map = raw.map } or { kind = "guide", id = raw.id }
    E.Advance(true)
    S:Fire("GUIDE_LOADED", g, S.Bridge.GuideMeta(g))
    if not silent then S.Print("guía cargada:", S.Color("goldSoft", g.name)) end
    return true
end

-- Insert an extra step (raw element list) into the active guide.
function E.InsertStep(at, rawElements)
    local g = E.guide
    if not g then return end
    local st = { elements = {}, inserted = true }
    for _, re in ipairs(rawElements) do
        local e = {}
        for k, v in pairs(re) do e[k] = v end
        e.step = st
        if e.tag == "goto" then
            e.arrow = true
            e.zone = e.zone or g.map
            e.textOnly = not e.travel
        elseif e.tag == "text" then
            e.textOnly = true
        end
        st.elements[#st.elements + 1] = e
    end
    at = math.max(1, math.min(at, #g.steps + 1))
    table.insert(g.steps, at, st)
    for i, s in ipairs(g.steps) do s.index = i end
    S:Fire("PROGRESS")
end

function E.Unload()
    E.guide = nil
    S.cdb.active = nil
    S:Fire("GUIDE_LOADED", nil, nil)
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------
local function save()
    if E.guide then progress(E.guide).step = E.current end
end

function E.SetStep(n)
    local g = E.guide
    if not g then return end
    n = math.max(1, math.min(n, #g.steps))
    for _, st in ipairs(g.steps) do st.active = nil end
    E.current = n
    g.steps[n].active = true
    events.home, events.fp = nil, nil
    save()
    S:Fire("STEP_CHANGED")
end

-- Move forward past completed steps; called on every relevant game event.
function E.Advance(quiet)
    local g = E.guide
    if not g or #g.steps == 0 then return end
    local n = E.current
    local moved = false
    while n <= #g.steps and E.StepComplete(g.steps[n]) do
        n = n + 1
        moved = true
    end
    if n > #g.steps then
        E.current = #g.steps
        save()
        E.Finished()
        return
    end
    if moved or quiet then
        E.SetStep(n)
    else
        g.steps[n].active = true
        S:Fire("PROGRESS")
    end
end

function E.Finished()
    local g = E.guide
    if not g then return end
    if g.dynamic and S.Generator then
        -- dynamic routes continue with the next round of quests
        if S.Generator.ContinueRoute(g) then return end
    end
    local meta = S.Bridge.GuideMeta(g)
    local nextRaw = g.next and (E.guides[g.next] or E.FindByName(g.next))
    if nextRaw and E.GuideAvailable(nextRaw) then
        E.Load(nextRaw)
        S:Fire("ZONE_FINISHED", meta, S.Bridge.GuideMeta(E.guide))
    elseif not g.finishedNotified then
        g.finishedNotified = true
        S:Fire("ZONE_FINISHED", meta, nil)
    end
end

function E.ToggleManual(e)
    local st = e.step
    if not st then return end
    st.manualDone = st.manualDone or {}
    st.manualDone[e] = not st.manualDone[e]
    local p = progress(E.guide)
    for ei, x in ipairs(st.elements) do
        if x == e then p.manual[st.index .. ":" .. ei] = st.manualDone[e] or nil end
    end
    E.Advance()
end

---------------------------------------------------------------------------
-- Where to go for a step
---------------------------------------------------------------------------
-- returns mapID, x, y, label
function E.StepTarget(step)
    if not step then return end
    for _, e in ipairs(step.elements) do
        if e.tag == "goto" and e.zone and not e.completed then
            return e.zone, e.x, e.y, e.text
        end
    end
    if not DB.Ready() then return end
    local pmap, px, py = DB.PlayerPos()
    local here = px and { x = px, y = py }
    for _, e in ipairs(step.elements) do
        if e.questId and not e.completed and not e.skip then
            local map = step.map or (E.guide and E.guide.map) or pmap
            local pts
            if e.tag == "accept" then
                pts = DB.StarterPoints(e.questId, map)
            elseif e.tag == "turnin" then
                pts = DB.FinisherPoints(e.questId, map)
            elseif e.tag == "complete" then
                pts = DB.ObjectivePoints(e.questId, map)
                if #pts == 0 and pmap and pmap ~= map then
                    map = pmap
                    pts = DB.ObjectivePoints(e.questId, map)
                end
            end
            if pts and #pts > 0 then
                local p = (e.tag == "complete") and (DB.Nearest(pts, here) or DB.Hotspot(pts)) or DB.Nearest(pts, here)
                if p then return map, p.x, p.y, p.label end
            end
            -- giver somewhere else
            local key = e.tag == "accept" and "startedBy" or e.tag == "turnin" and "finishedBy"
            if key then
                local name, m, x, y = DB.GiverInfo(e.questId, key)
                if m then return m, x, y, name end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function bump() S:Debounce("engine", 0.15, function() E.Advance() end) end

for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED", "PLAYER_LEVEL_UP" }) do
    S:RegisterEvent(ev, function() S.InvalidateQuestLog(); bump() end)
end
S:RegisterEvent("QUEST_TURNED_IN", function(_, qid)
    S.MarkTurnedIn(qid)
    S.InvalidateQuestLog()
    bump()
end)
S:RegisterEvent("HEARTHSTONE_BOUND", function() events.home = true; bump() end)
S:RegisterEvent("UI_INFO_MESSAGE", function(_, _, msg)
    if msg and _G.ERR_NEWTAXIPATH and msg == _G.ERR_NEWTAXIPATH then events.fp = true; bump() end
end)

-- travel steps complete on arrival
C_Timer.NewTicker(0.5, function()
    local g = E.guide
    local st = g and g.steps[E.current]
    if not st then return end
    for _, e in ipairs(st.elements) do
        if e.tag == "goto" and e.travel and not e.completed then
            bump()
            return
        end
    end
end)

S:On("READY", function()
    local a = S.cdb.active
    if a and a.kind == "guide" and E.guides[a.id] then
        E.Load(a.id, true)
    elseif a and a.kind == "dynamic" and S.Generator then
        S.Generator.Start(a.map, true)
    elseif S.Generator and S.DB.Ready() then
        -- first run: start where the player is
        local map = DB.PlayerPos()
        if map then S.Generator.Start(map, false) end
    else
        S:Fire("GUIDE_LOADED", nil, nil)
    end
end)
