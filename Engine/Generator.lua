-- SakedXP · Dynamic route generator
-- Builds a route for any zone from QuestieDB data and the character's real
-- state: only quests you can take right now (level, race, class, finished
-- prerequisites, chains already advanced), grouped by giver, objectives
-- clustered by location and ordered by proximity. When a round is finished
-- the next round (follow-ups that just unlocked) is generated automatically.

local _, S = ...
local DB, E = S.DB, S.Engine
local G = {}
S.Generator = G

local function hasFlag(mask, bitValue)
    return mask and math.floor(mask / bitValue) % 2 == 1
end

local function anyDone(list)
    if type(list) ~= "table" or #list == 0 then return true end
    for _, id in ipairs(list) do if S.IsQuestDone(id) then return true end end
    return false
end

local function allDone(list)
    if type(list) ~= "table" then return true end
    for _, id in ipairs(list) do if not S.IsQuestDone(id) then return false end end
    return true
end

local function noneTaken(list)
    if type(list) ~= "table" then return true end
    for _, id in ipairs(list) do
        if S.IsQuestDone(id) or S.IsOnQuest(id) then return false end
    end
    return true
end

-- Can the player pick this quest up right now?
function G.Available(id, level)
    if S.IsQuestDone(id) or S.IsOnQuest(id) then return false end
    if S.cdb.skippedQuests[id] then return false end
    if not DB.FitsPlayer(id) then return false end
    local req = DB.Q(id, "requiredLevel") or 1
    if req > level then return false, "level", req end
    local maxLvl = DB.Q(id, "requiredMaxLevel")
    if maxLvl and maxLvl > 0 and level > maxLvl then return false end
    local flags = DB.Q(id, "specialFlags")
    if hasFlag(flags, 1) or hasFlag(flags, 2) then return false end -- repeatable / event
    -- profession, reputation and specialization gated quests are left out
    if DB.Q(id, "requiredSkill") or DB.Q(id, "requiredMinRep") or DB.Q(id, "requiredRanks") then return false end
    local spec = DB.Q(id, "requiredSpecialization")
    if spec and spec ~= 0 then return false end
    local spell = DB.Q(id, "requiredSpell")
    if spell and spell ~= 0 then
        local known = IsPlayerSpell and IsPlayerSpell(math.abs(spell))
        if (spell > 0 and not known) or (spell < 0 and known) then return false end
    end
    if not anyDone(DB.Q(id, "preQuestSingle")) then return false, "prereq" end
    if not allDone(DB.Q(id, "preQuestGroup")) then return false, "prereq" end
    local parent = DB.Q(id, "parentQuest")
    if parent and parent > 0 and not S.IsOnQuest(parent) then return false end
    local startWith = DB.Q(id, "availableStartingWith")
    if startWith and startWith > 0 and not (S.IsOnQuest(startWith) or S.IsQuestDone(startWith)) then return false end
    local untilDone = DB.Q(id, "availableUntilCompleted")
    if untilDone and untilDone > 0 and S.IsQuestDone(untilDone) then return false end
    local disabledBy = DB.Q(id, "disabledByQuest")
    if disabledBy and disabledBy > 0 and S.IsOnQuest(disabledBy) then return false end
    if not noneTaken(DB.Q(id, "exclusiveTo")) then return false end
    local nextQ = DB.Q(id, "nextQuestInChain")
    if nextQ and nextQ > 0 and (S.IsQuestDone(nextQ) or S.IsOnQuest(nextQ)) then return false, "chain" end
    local crumb = DB.Q(id, "breadcrumbForQuestId")
    if crumb and crumb > 0 and (S.IsQuestDone(crumb) or S.IsOnQuest(crumb)) then return false end
    return true
end

---------------------------------------------------------------------------
-- Ordering helpers
---------------------------------------------------------------------------
local function nearestNeighbour(stops, from)
    local out, left = {}, {}
    for i, s in ipairs(stops) do left[i] = s end
    local cur = from
    while #left > 0 do
        local bi, bd = 1, nil
        for i, s in ipairs(left) do
            local d = cur and DB.Dist(s, cur) or 0
            if not bd or d < bd then bi, bd = i, d end
        end
        cur = table.remove(left, bi)
        out[#out + 1] = cur
    end
    return out, cur
end

-- Merge items that share a location (same giver or nearby objective areas).
local function cluster(items, radius, sameLabel)
    local stops = {}
    for _, it in ipairs(items) do
        local merged
        for _, s in ipairs(stops) do
            if DB.Dist(s, it) <= radius and (not sameLabel or s.label == it.label) then
                merged = s
                break
            end
        end
        if merged then
            table.insert(merged.quests, it.quest)
        else
            stops[#stops + 1] = { x = it.x, y = it.y, label = it.label, quests = { it.quest } }
        end
    end
    return stops
end

---------------------------------------------------------------------------
-- Round builder
---------------------------------------------------------------------------
local function mapName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Mapa " .. mapID)
end

function G.BuildRound(mapID)
    local level = UnitLevel("player")
    local log = S.GetQuestLogSet()
    local logCount = 0
    for _ in pairs(log) do logCount = logCount + 1 end
    local maxLog = (C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20
    local free = math.max(0, maxLog - logCount)

    local pmap, px, py = DB.PlayerPos()
    local here = (pmap == mapID and px) and { x = px, y = py } or nil

    -- 1) quests to pick up
    local candidates = {}
    for _, id in ipairs(DB.QuestsOnMap(mapID)) do
        if G.Available(id, level) then
            local qLvl = DB.Q(id, "questLevel")
            if not qLvl or qLvl <= 0 then qLvl = DB.Q(id, "requiredLevel") or level end -- -1 = scales with you
            local tooHigh = qLvl > level + (S.db.levelAhead or 3)
            local grey = qLvl < level - (S.db.greyRange or 6)
            local groupQ = not S.db.includeElite and DB.IsGroupQuest(id)
            if not tooHigh and not grey and not groupQ then
                local p = DB.Nearest(DB.StarterPoints(id, mapID), here)
                -- keep the route inside this zone: the quest must be finished here and,
                -- if it has objectives, they must happen here too
                local endsHere = #DB.FinisherPoints(id, mapID) > 0
                local worksHere = not DB.HasObjectives(id) or #DB.ObjectivePoints(id, mapID) > 0
                if p and endsHere and worksHere then
                    candidates[#candidates + 1] = { quest = id, x = p.x, y = p.y, label = p.label, level = qLvl }
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.level < b.level end)
    while #candidates > free do table.remove(candidates) end

    local planned = {}
    for _, c in ipairs(candidates) do planned[c.quest] = true end

    -- quests already in the log that belong here
    local working = {}
    for id, state in pairs(log) do
        if not S.cdb.skippedQuests[id] then
            local zone = DB.Q(id, "zoneOrSort")
            local onMap = zone and zone > 0 and DB.AreaToMap(zone) == mapID
            if onMap or #DB.ObjectivePoints(id, mapID) > 0 or #DB.FinisherPoints(id, mapID) > 0 then
                working[id] = state
            end
        end
    end
    for id in pairs(planned) do working[id] = "planned" end

    -- 2) objectives
    local objItems = {}
    for id, state in pairs(working) do
        if state ~= "complete" then
            local pts = DB.ObjectivePoints(id, mapID)
            local hot = DB.Hotspot(pts)
            if hot then objItems[#objItems + 1] = { quest = id, x = hot.x, y = hot.y, label = hot.label } end
        end
    end

    -- 3) turn-ins: only quests that can actually be finished on this round
    -- (already complete, objectives on this map, or nothing to do but talk)
    local turnItems = {}
    for id, state in pairs(working) do
        local ready = state == "complete" or not DB.HasObjectives(id) or #DB.ObjectivePoints(id, mapID) > 0
        if ready then
            local p = DB.Nearest(DB.FinisherPoints(id, mapID), here)
            if p then turnItems[#turnItems + 1] = { quest = id, x = p.x, y = p.y, label = p.label } end
        end
    end

    if #candidates == 0 and #objItems == 0 and #turnItems == 0 then return nil end

    -- Order: always the nearest stop that can be done right now.
    --   accept     : always possible
    --   objectives : once every quest of the stop is accepted
    --   turn-in    : once every quest of the stop has its objectives done
    -- so if you're standing where your objectives are, they come first, and a
    -- finished quest is handed in when the route passes its NPC.
    local acceptStops = cluster(candidates, 1.5, true)
    local objStops = cluster(objItems, 7, false)
    local turnStops = cluster(turnItems, 1.5, true)
    for _, s in ipairs(acceptStops) do s.kind = "accept" end
    for _, s in ipairs(objStops) do s.kind = "obj" end
    for _, s in ipairs(turnStops) do s.kind = "turn" end

    local accepted, objDone, hasObjStop = {}, {}, {}
    for id, state in pairs(working) do
        if state ~= "planned" then accepted[id] = true end
        if state == "complete" then objDone[id] = true end
    end
    for _, s in ipairs(objStops) do for _, q in ipairs(s.quests) do hasObjStop[q] = true end end

    local function ready(s)
        for _, q in ipairs(s.quests) do
            if s.kind == "obj" and not accepted[q] then return false end
            if s.kind == "turn" then
                if not accepted[q] then return false end
                if hasObjStop[q] and not objDone[q] then return false end
            end
        end
        return true
    end

    local pending = {}
    for _, list in ipairs({ acceptStops, objStops, turnStops }) do
        for _, s in ipairs(list) do pending[#pending + 1] = s end
    end
    local ordered, cur = {}, here
    while #pending > 0 do
        local bi, bd
        for i, s in ipairs(pending) do
            if ready(s) then
                local d = cur and DB.Dist(s, cur) or 0
                if not bd or d < bd then bi, bd = i, d end
            end
        end
        if not bi then
            -- nothing unlocks (data gap): keep the rest in proximity order
            local rest = nearestNeighbour(pending, cur)
            for _, s in ipairs(rest) do ordered[#ordered + 1] = s end
            break
        end
        local s = table.remove(pending, bi)
        ordered[#ordered + 1] = s
        cur = s
        for _, q in ipairs(s.quests) do
            if s.kind == "accept" then accepted[q] = true end
            if s.kind == "obj" then objDone[q] = true end
        end
    end

    local steps = {}
    for _, s in ipairs(ordered) do
        local els
        if s.kind == "accept" then
            els = { { tag = "goto", zone = mapID, x = s.x, y = s.y, text = s.label and ("Hablá con |cffe3bb72" .. s.label .. "|r") } }
            for _, q in ipairs(s.quests) do els[#els + 1] = { tag = "accept", questId = q, npc = s.label } end
        elseif s.kind == "obj" then
            els = { { tag = "goto", zone = mapID, x = s.x, y = s.y, text = s.label and ("Zona de |cffd9735a" .. s.label .. "|r") } }
            for _, q in ipairs(s.quests) do els[#els + 1] = { tag = "complete", questId = q } end
        else
            els = { { tag = "goto", zone = mapID, x = s.x, y = s.y, text = s.label and ("Volvé con |cffe3bb72" .. s.label .. "|r") } }
            for _, q in ipairs(s.quests) do els[#els + 1] = { tag = "turnin", questId = q, npc = s.label } end
        end
        steps[#steps + 1] = { elements = els }
    end

    local zone = S.Zones and S.Zones.ByMap and S.Zones.ByMap(mapID)
    return {
        id = "dyn:" .. mapID,
        name = mapName(mapID),
        group = "SakedXP · Ruta dinámica",
        subgroup = ("%d aceptar · %d objetivos · %d entregas"):format(#acceptStops, #objStops, #turnStops),
        map = mapID,
        dynamic = true,
        minLevel = zone and zone.levels[1],
        maxLevel = zone and zone.levels[2],
        steps = steps,
    }
end

---------------------------------------------------------------------------
-- Quests that start here but send you to another zone
---------------------------------------------------------------------------
-- XP of the quest plus the follow-ups of its chain (what the trip is worth).
local function chainXP(id)
    local total, n, seen, cur = 0, 0, {}, id
    while cur and cur > 0 and not seen[cur] and n < 8 do
        seen[cur] = true
        if DB.FitsPlayer(cur) and not S.IsQuestDone(cur) then
            total = total + DB.QuestXP(cur)
            n = n + 1
        end
        local nxt = DB.Q(cur, "nextQuestInChain")
        if not nxt or nxt == 0 then
            local kids = DB.Q(cur, "childQuests")
            nxt = type(kids) == "table" and kids[1] or nil
        end
        cur = nxt
    end
    return total, n
end

-- best reward: quality (from the client cache) and item level (QuestieDB)
local function bestReward(id)
    local best, bq, bil
    for _, item in ipairs(DB.QuestRewards(id)) do
        local _, link, quality = GetItemInfo(item)
        if not quality and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, item)
        end
        local il = DB.I(item, "itemLevel") or 0
        local q = quality or 1
        if not bq or q > bq or (q == bq and il > (bil or 0)) then best, bq, bil = link or item, q, il end
    end
    return best, bq, bil
end

local outCache = {}
function G.Outbound(mapID)
    if not (mapID and DB.Ready() and DB.IndexReady()) then return {} end
    local level = UnitLevel("player")
    local key = mapID .. ":" .. level
    local c = outCache[key]
    if c and GetTime() - c.t < 20 then return c.list end

    local maxXP = UnitXPMax("player")
    local suggested = {}
    for _, e in ipairs(S.Zones.ForPlayer(level, UnitFactionGroup("player"))) do
        if e.zone.mapID and e.fit ~= "high" then suggested[e.zone.mapID] = true end
    end
    local pmap, px, py = DB.PlayerPos()
    local here = (pmap == mapID and px) and { x = px, y = py } or nil

    local list = {}
    for _, id in ipairs(DB.QuestsStartedOnMap(mapID)) do
        if not S.cdb.hiddenOutbound[id] and G.Available(id, level) then
            local qLvl = DB.Q(id, "questLevel")
            if not qLvl or qLvl <= 0 then qLvl = DB.Q(id, "requiredLevel") or level end
            local inRange = qLvl <= level + (S.db.levelAhead or 3) and qLvl >= level - (S.db.greyRange or 6)
            local endsHere = #DB.FinisherPoints(id, mapID) > 0
            local worksHere = not DB.HasObjectives(id) or #DB.ObjectivePoints(id, mapID) > 0
            local dest = (not (endsHere and worksHere)) and DB.QuestDestination(id, mapID)
            local giver = dest and DB.Nearest(DB.StarterPoints(id, mapID), here)
            if inRange and giver and not (not S.db.includeElite and DB.IsGroupQuest(id)) then
                local xp = DB.QuestXP(id)
                local total, links = chainXP(id)
                local item, quality, ilvl = bestReward(id)
                local info = C_Map.GetMapInfo(dest)
                local zone = S.Zones.ByMap(dest)
                list[#list + 1] = {
                    quest = id, name = E.QuestName(id), level = qLvl,
                    x = giver.x, y = giver.y, giver = giver.label, map = mapID,
                    dest = dest, destName = zone and (zone.nameES or zone.name) or (info and info.name) or "?",
                    nextZone = suggested[dest] or false,
                    breadcrumb = (DB.Q(id, "breadcrumbForQuestId") or 0) > 0,
                    xp = xp, chainXP = total, chainLen = links,
                    pct = maxXP > 0 and total / maxXP or 0,
                    reward = item, quality = quality, ilvl = ilvl,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.nextZone ~= b.nextZone then return a.nextZone end
        return a.chainXP > b.chainXP
    end)
    outCache[key] = { t = GetTime(), list = list }
    return list
end

function G.InvalidateOutbound() wipe(outCache) end
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do
    S:RegisterEvent(ev, function() wipe(outCache) end)
end

-- Opt-in: put "go accept this" right after the current step.
function G.AddOutboundToRoute(o)
    local raw = {
        { tag = "goto", zone = o.map, x = o.x, y = o.y, text = "Hablá con |cffe3bb72" .. (o.giver or "?") .. "|r" },
        { tag = "accept", questId = o.quest, npc = o.giver },
        { tag = "text", text = "|cff6e98b8Te lleva a " .. o.destName .. "|r" },
    }
    E.InsertStep(E.current + 1, raw)
    S.Print("agregada a la ruta:", S.Color("goldSoft", o.name), "→", o.destName)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function G.Start(mapID, silent)
    if not DB.Ready() then
        S.Print(S.Color("bad", "Para las rutas dinámicas necesitás el addon QuestieDB activado."))
        S:Fire("GUIDE_LOADED", nil, nil)
        return false
    end
    DB.BuildIndex(function()
        local raw = G.BuildRound(mapID)
        if not raw then
            S.cdb.active = { kind = "dynamic", map = mapID }
            if silent then
                S:Fire("GUIDE_LOADED", nil, nil)
            else
                S.Print("no quedan misiones disponibles para tu nivel en", S.Color("goldSoft", mapName(mapID)) .. ".")
                S:Fire("ZONE_FINISHED", { name = mapName(mapID), zone = mapName(mapID) }, nil)
            end
            return
        end
        S.cdb.progress = S.cdb.progress or {}
        S.cdb.progress[raw.id] = nil -- every round starts fresh
        E.Load(raw, silent)
    end)
    return true
end

-- Called by the engine when the current round is done.
local continuing = false
function G.ContinueRoute(g)
    -- a round that is already complete when built would recurse; treat it as handled
    if continuing then return true end
    continuing = true
    local raw = G.BuildRound(g.map)
    if raw then
        S.cdb.progress[raw.id] = nil
        E.Load(raw, true)
        S.Print("nueva tanda de misiones en", S.Color("goldSoft", raw.name) .. ".")
    end
    continuing = false
    return raw ~= nil
end

function G.Regenerate()
    local g = E.guide
    if g and g.dynamic then G.Start(g.map, false)
    else
        local map = DB.PlayerPos()
        if map then G.Start(map, false) end
    end
end
S:On("REGENERATE", G.Regenerate)
