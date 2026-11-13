-- SakedXP · Data adapter over LibQuestieDB (the QuestieDB addon's public API)
-- QuestieDB is optional: without it curated guides still work, but the
-- dynamic route generator and automatic waypoints need it.

local _, S = ...
local DB = {}
S.DB = DB

local QDB, NDB, ODB, IDB

function DB.Ready()
    if QDB then return true end
    local lib = _G.LibQuestieDB
    if not lib or not lib.Quest then return false end
    QDB, NDB, ODB, IDB = lib.Quest, lib.Npc, lib.Object, lib.Item
    return QDB ~= nil
end

local function get(entity, id, key)
    if not entity or not id then return nil end
    local ok, v = pcall(entity.Get, id, key)
    if ok then return v end
end

function DB.Q(id, key) DB.Ready(); return get(QDB, id, key) end
function DB.N(id, key) DB.Ready(); return get(NDB, id, key) end
function DB.O(id, key) DB.Ready(); return get(ODB, id, key) end
function DB.I(id, key) DB.Ready(); return get(IDB, id, key) end

function DB.QuestExists(id)
    if not DB.Ready() then return false end
    local ok, v = pcall(QDB.Exists, id)
    return ok and v
end

---------------------------------------------------------------------------
-- Zones: AreaTable ID <-> UiMap ID (QuestieDB support tables)
---------------------------------------------------------------------------
local areaToMap, mapToAreas

local function loadMapping()
    if areaToMap then return areaToMap end
    areaToMap = {}
    local lib = _G.LibQuestieDB
    local zdb = lib and lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
    local priv = zdb and zdb.private
    local function merge(src)
        if type(src) == "string" then
            local fn = loadstring(src)
            local ok, t = pcall(fn or function() end)
            src = ok and t or nil
        end
        if type(src) == "table" then
            for a, m in pairs(src) do
                if m and m ~= 0 then areaToMap[a] = m end
            end
        end
    end
    if priv then
        merge(priv.areaIdToUiMapId)
        merge(priv.areaIdToUiMapIdOverride)
    end
    mapToAreas = {}
    for a, m in pairs(areaToMap) do
        mapToAreas[m] = mapToAreas[m] or {}
        table.insert(mapToAreas[m], a)
    end
    return areaToMap
end

function DB.AreaToMap(area)
    return loadMapping()[area]
end

function DB.MapAreas(mapID)
    loadMapping()
    return mapToAreas[mapID] or {}
end

---------------------------------------------------------------------------
-- Player filters
---------------------------------------------------------------------------
-- masks can exceed 32 bits (Skyborne uses bits 32/33), so test with division
local function hasMask(mask, value)
    if not mask or mask == 0 then return true end
    if not value then return true end
    return math.floor(mask / value) % 2 == 1
end

function DB.PlayerRaceMask()
    local _, _, raceID = UnitRace("player")
    local lib = _G.LibQuestieDB
    local byId = lib and lib.Enum and lib.Enum.raceMaskById
    return (byId and byId[raceID]) or (raceID and raceID <= 30 and 2 ^ (raceID - 1)) or nil
end

function DB.FitsPlayer(id)
    local races = DB.Q(id, "requiredRaces")
    local classes = DB.Q(id, "requiredClasses")
    local _, _, classID = UnitClass("player")
    return hasMask(races, DB.PlayerRaceMask()) and hasMask(classes, classID and 2 ^ (classID - 1))
end

-- NPC friendly to the player's faction? (unknown counts as friendly)
function DB.NpcFriendly(npcId)
    local f = DB.N(npcId, "friendlyToFaction")
    if not f or f == "" then return true end
    local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
    return f:find(mine, 1, true) ~= nil
end

-- Does the quest have objectives that need a location (kills, items, areas)?
function DB.HasObjectives(qid)
    local obj = DB.Q(qid, "objectives")
    if type(obj) == "table" then
        for i = 1, 6 do
            if type(obj[i]) == "table" and next(obj[i]) then return true end
        end
    end
    return DB.Q(qid, "triggerEnd") ~= nil
end

-- Fields Smart.lua needs, cached per session.
local infoCache = {}
function DB.QuestInfo(id)
    if not id or not DB.Ready() then return end
    local c = infoCache[id]
    if c ~= nil then return c or nil end
    if not DB.QuestExists(id) then infoCache[id] = false return end
    c = {
        name = DB.Q(id, "name"),
        preQuestSingle = DB.Q(id, "preQuestSingle"),
        preQuestGroup = DB.Q(id, "preQuestGroup"),
        nextQuestInChain = DB.Q(id, "nextQuestInChain"),
        requiredLevel = DB.Q(id, "requiredLevel"),
        questLevel = DB.Q(id, "questLevel"),
        childQuests = DB.Q(id, "childQuests"),
    }
    infoCache[id] = c
    return c
end

---------------------------------------------------------------------------
-- Locations
---------------------------------------------------------------------------
-- spawns = {[areaId] = {{x, y}, ...}} -> points on mapID (0-100 coords)
local function spawnsOnMap(spawns, mapID, out, label)
    if type(spawns) ~= "table" then return out end
    for area, list in pairs(spawns) do
        if DB.AreaToMap(area) == mapID and type(list) == "table" then
            for _, p in ipairs(list) do
                if p[1] and p[1] > 0 and p[2] and p[2] > 0 then
                    out[#out + 1] = { x = p[1], y = p[2], label = label }
                end
            end
        end
    end
    return out
end

-- Every map an entity spawns on (for "where is this NPC?").
local function firstSpawn(spawns)
    if type(spawns) ~= "table" then return end
    for area, list in pairs(spawns) do
        local m = DB.AreaToMap(area)
        if m and type(list) == "table" and list[1] and list[1][1] and list[1][1] > 0 then
            return m, list[1][1], list[1][2]
        end
    end
end

function DB.NpcPoints(npcId, mapID)
    return spawnsOnMap(DB.N(npcId, "spawns"), mapID, {}, DB.N(npcId, "name"))
end

function DB.NpcAnywhere(npcId)
    local m, x, y = firstSpawn(DB.N(npcId, "spawns"))
    return m, x, y, DB.N(npcId, "name")
end

function DB.ObjectAnywhere(objId)
    local m, x, y = firstSpawn(DB.O(objId, "spawns"))
    return m, x, y, DB.O(objId, "name")
end

-- givers = {npcIds?, objectIds?, itemIds?}; hostile NPCs are skipped
local function giverPoints(givers, mapID)
    local out = {}
    if type(givers) ~= "table" then return out end
    for _, id in ipairs(givers[1] or {}) do
        if DB.NpcFriendly(id) then spawnsOnMap(DB.N(id, "spawns"), mapID, out, DB.N(id, "name")) end
    end
    for _, id in ipairs(givers[2] or {}) do spawnsOnMap(DB.O(id, "spawns"), mapID, out, DB.O(id, "name")) end
    return out
end

function DB.StarterPoints(qid, mapID) return giverPoints(DB.Q(qid, "startedBy"), mapID) end
function DB.FinisherPoints(qid, mapID) return giverPoints(DB.Q(qid, "finishedBy"), mapID) end

-- Name + first location of a quest giver/finisher, any map.
function DB.GiverInfo(qid, key)
    local g = DB.Q(qid, key)
    if type(g) ~= "table" then return end
    for _, id in ipairs(g[1] or {}) do
        local m, x, y, name = DB.NpcAnywhere(id)
        if name then return name, m, x, y, "npc", id end
    end
    for _, id in ipairs(g[2] or {}) do
        local m, x, y, name = DB.ObjectAnywhere(id)
        if name then return name, m, x, y, "object", id end
    end
    if key == "startedBy" then
        for _, id in ipairs(g[3] or {}) do
            return DB.I(id, "name"), nil, nil, nil, "item", id
        end
    end
end

-- Points where the quest objectives happen on mapID.
function DB.ObjectivePoints(qid, mapID)
    local out = {}
    local obj = DB.Q(qid, "objectives")
    if type(obj) == "table" then
        for _, c in ipairs(obj[1] or {}) do spawnsOnMap(DB.N(c[1], "spawns"), mapID, out, DB.N(c[1], "name")) end
        for _, o in ipairs(obj[2] or {}) do spawnsOnMap(DB.O(o[1], "spawns"), mapID, out, DB.O(o[1], "name")) end
        for _, it in ipairs(obj[3] or {}) do
            local itemId = it[1]
            local label = DB.I(itemId, "name")
            for _, n in ipairs(DB.I(itemId, "npcDrops") or {}) do spawnsOnMap(DB.N(n, "spawns"), mapID, out, label) end
            for _, o in ipairs(DB.I(itemId, "objectDrops") or {}) do spawnsOnMap(DB.O(o, "spawns"), mapID, out, label) end
        end
        for _, kc in ipairs(obj[5] or {}) do
            for _, n in ipairs(type(kc[1]) == "table" and kc[1] or {}) do spawnsOnMap(DB.N(n, "spawns"), mapID, out, DB.N(n, "name")) end
        end
    end
    local trig = DB.Q(qid, "triggerEnd")
    if type(trig) == "table" then spawnsOnMap(trig[2], mapID, out, trig[1]) end
    return out
end

-- Elite objective creatures (rank >= 1) mean the quest likely needs a group.
function DB.IsGroupQuest(qid)
    local obj = DB.Q(qid, "objectives")
    if type(obj) ~= "table" then return false end
    for _, c in ipairs(obj[1] or {}) do
        local rank = DB.N(c[1], "rank")
        if rank and rank >= 1 and rank ~= 4 then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- XP and rewards
---------------------------------------------------------------------------
local xpTable
local function questXPTable()
    if xpTable ~= nil then return xpTable or nil end
    local lib = _G.LibQuestieDB
    local mod = lib and lib.Support and lib.Support.Get and lib.Support.Get("QuestXP")
    xpTable = (mod and type(mod.db) == "table") and mod.db or false
    return xpTable or nil
end

-- XP the player would get now (same rounding as the server / Questie).
function DB.QuestXP(qid)
    local t = questXPTable()
    local row = t and t[qid]
    if not row then return 0 end
    local qLevel, xp = row[1], row[2]
    if not (qLevel and xp) or qLevel <= 0 or xp <= 0 then return 0 end
    local level = UnitLevel("player")
    if GetMaxPlayerLevel and level >= GetMaxPlayerLevel() then return 0 end
    local mult = math.max(1, math.min(10, 2 * (qLevel - level) + 20))
    xp = xp * mult / 10
    if xp <= 100 then xp = 5 * math.floor((xp + 2) / 5)
    elseif xp <= 500 then xp = 10 * math.floor((xp + 5) / 10)
    elseif xp <= 1000 then xp = 25 * math.floor((xp + 12) / 25)
    else xp = 50 * math.floor((xp + 25) / 50) end
    return xp
end

-- Item IDs a quest can reward (from the reverse index built with the quest index).
function DB.QuestRewards(qid)
    local idx = S.db and S.db.questIndex
    return (idx and idx.rewards and idx.rewards[qid]) or {}
end

-- Where a quest is really done: the objectives' zone, else where it ends.
function DB.QuestDestination(qid, fromMap)
    local zone = DB.Q(qid, "zoneOrSort")
    local m = zone and zone > 0 and DB.AreaToMap(zone)
    if m and m ~= fromMap then return m end
    local _, fm = DB.GiverInfo(qid, "finishedBy")
    if fm and fm ~= fromMap then return fm end
    return nil
end

---------------------------------------------------------------------------
-- Geometry helpers (map percent coordinates)
---------------------------------------------------------------------------
function DB.Dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function DB.Nearest(points, from)
    local best, bd
    for _, p in ipairs(points) do
        local d = from and DB.Dist(p, from) or 0
        if not bd or d < bd then best, bd = p, d end
    end
    return best, bd
end

-- The spawn closest to the densest part of a point cloud (good farming spot).
function DB.Hotspot(points)
    if #points == 0 then return end
    if #points <= 2 then return points[1] end
    local best, bestCount
    local step = math.max(1, math.floor(#points / 40)) -- sample for speed
    for i = 1, #points, step do
        local p, count = points[i], 0
        for j = 1, #points, step do
            if DB.Dist(p, points[j]) < 6 then count = count + 1 end
        end
        if not bestCount or count > bestCount then best, bestCount = p, count end
    end
    return best
end

function DB.PlayerPos()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos or S.IsSecret(pos.x) then return map end
    return map, pos.x * 100, pos.y * 100
end

---------------------------------------------------------------------------
-- Quest index by map (built once, asynchronously, cached in SavedVariables)
---------------------------------------------------------------------------
local building, waiters = false, {}

local function indexVersion()
    local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return "v2/" .. tostring(meta("QuestieDB", "Version")) .. "/" .. tostring((select(2, GetBuildInfo())))
end

function DB.IndexReady()
    local idx = S.db and S.db.questIndex
    return idx and idx.version == indexVersion() and idx.byMap ~= nil
end

-- quests done in this zone
function DB.QuestsOnMap(mapID)
    local idx = S.db.questIndex
    return (idx and idx.byMap and idx.byMap[mapID]) or {}
end

-- quests *picked up* in this zone (may be done elsewhere)
function DB.QuestsStartedOnMap(mapID)
    local idx = S.db.questIndex
    return (idx and idx.byStart and idx.byStart[mapID]) or {}
end

local function startMaps(id, out)
    local g = DB.Q(id, "startedBy")
    if type(g) ~= "table" then return end
    local function add(spawns)
        if type(spawns) ~= "table" then return end
        for area in pairs(spawns) do
            local m = DB.AreaToMap(area)
            if m then out[m] = true end
        end
    end
    for _, npc in ipairs(g[1] or {}) do add(DB.N(npc, "spawns")) end
    for _, obj in ipairs(g[2] or {}) do add(DB.O(obj, "spawns")) end
end

-- Calls `done()` once the index is available.
function DB.BuildIndex(done)
    if done then waiters[#waiters + 1] = done end
    if DB.IndexReady() then
        local list = waiters; waiters = {}
        for _, fn in ipairs(list) do local ok, err = pcall(fn); if not ok then S.Error(err) end end
        return
    end
    if building or not DB.Ready() then return end
    building = true
    local ids = QDB.GetAllIds()
    local items = IDB and IDB.GetAllIds and IDB.GetAllIds() or {}
    local byMap, byStart, rewards = {}, {}, {}
    local i, n = 1, #ids
    local phase = 1
    S.Print("preparando la base de datos de misiones (sólo la primera vez)…")
    local ticker
    ticker = C_Timer.NewTicker(0, function()
        if phase == 1 then
            local stop = math.min(n, i + 200)
            for k = i, stop do
                local id = ids[k]
                local zone = DB.Q(id, "zoneOrSort")
                local maps = {}
                startMaps(id, maps)
                local map = zone and zone > 0 and DB.AreaToMap(zone)
                if not map then map = next(maps) end -- fall back to where it starts
                if map then
                    byMap[map] = byMap[map] or {}
                    table.insert(byMap[map], id)
                end
                for m in pairs(maps) do
                    byStart[m] = byStart[m] or {}
                    table.insert(byStart[m], id)
                end
            end
            i = stop + 1
            if i > n then phase, i, n = 2, 1, #items end
            return
        end
        -- phase 2: which items each quest rewards
        local stop = math.min(n, i + 400)
        for k = i, stop do
            local item = items[k]
            local qs = DB.I(item, "questRewards")
            if type(qs) == "table" then
                for _, q in ipairs(qs) do
                    rewards[q] = rewards[q] or {}
                    table.insert(rewards[q], item)
                end
            end
        end
        i = stop + 1
        if i > n then
            ticker:Cancel()
            S.db.questIndex = { version = indexVersion(), byMap = byMap, byStart = byStart, rewards = rewards }
            building = false
            S.Print("base de datos lista.")
            local list = waiters; waiters = {}
            for _, fn in ipairs(list) do local ok, err = pcall(fn); if not ok then S.Error(err) end end
        end
    end)
end
