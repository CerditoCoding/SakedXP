-- Load the whole addon against tests/wowstub.lua and walk through a session:
-- login outdoors, /smap test, zone into Blackrock Spire, move, change rooms, map interaction, /reload.
package.path = "./tests/?.lua;" .. package.path
local S = require("wowstub")
S.install()
local ROOT = "."
local ns = S.loadAddon(ROOT)

local function check(cond, msg)
    if not cond then error("FAIL: " .. msg, 2) end
    io.stdout:write("ok  " .. msg .. "\n")
end

S.fire("ADDON_LOADED", "SakedMap")
check(type(SakedMapDB) == "table" and SakedMapDB.entrances, "saved variables initialised")
check(SakedMapFrame ~= nil, "map frame created")

-- outdoors: compass calibration (rotation = -facing) and the outdoor test
S.px, S.py, S.facing = 100, 200, 0.3
MinimapCompassTexture._rotation = -0.3
S.fire("PLAYER_ENTERING_WORLD", true, false)
check(ns.state.mapID == nil, "no dungeon outdoors")
SlashCmdList.SAKEDMAP("test")
check(S.printed[#S.printed]:find("aire libre") ~= nil, "outdoor test starts")
for i = 1, 40 do
    S.facing = (i * 0.15) % (2 * math.pi)
    MinimapCompassTexture._rotation = -S.facing
    S.speed = 7
    S.advance(0.25)
    S.px = S.px + math.cos(S.facing) * 7 * 0.25
    S.py = S.py + math.sin(S.facing) * 7 * 0.25
end
SlashCmdList.SAKEDMAP("test")
local cal = SakedMapDB.cal
check(cal.sign == -1 and math.abs(cal.offset) < 0.05, ("compass calibrated (sign %s offset %.3f)"):format(tostring(cal.sign), cal.offset))
local testLine
for _, p in ipairs(S.printed) do if p:find("Prueba: recorrido") then testLine = p end end
check(testLine ~= nil, "outdoor test reported: " .. tostring(testLine))

-- zone into Blackrock Spire at its entrance
S.instance = 229
S.speed = 0
S.subzone = ""
S.fire("PLAYER_ENTERING_WORLD", false, false)
check(ns.state.mapID == 229 and ns.state.filter ~= nil, "entered BRS with a filter")
check(SakedMapFrame:IsShown(), "map shown on entry")
check(ns.Motion:Facing() ~= nil, "facing from the compass inside the instance")

-- walk east-ish from the entrance with the compass giving facing
local facing = -math.pi / 2
for i = 1, 40 do
    MinimapCompassTexture._rotation = -facing
    S.speed = 7
    S.advance(0.1)
end
S.speed = 0
S.advance(0.5)
local est = ns.state.est
check(est and est.x and est.heading, ("estimate exists (%.1f, %.1f, %.1f ±%.1f)"):format(est.x, est.y, est.z, est.spread))

-- room name in Spanish is matched to the data's English name
S.subzone = "Sala Dracopico"
S.fire("ZONE_CHANGED_INDOORS")
check(ns.state.area == "Dragonspire Hall", "Spanish subzone mapped to Dragonspire Hall")
S.subzone = ""
S.fire("ZONE_CHANGED_INDOORS")

-- key hooks change the travel direction
StrafeLeftStart()
local m = ns.Motion:Sample()
check(math.abs(m.dir - math.pi / 2) < 1e-6, "strafe left = +90 degrees")
StrafeLeftStop()
MoveBackwardStart()
m = ns.Motion:Sample()
check(math.abs(math.abs(m.dir) - math.pi) < 1e-6, "backward = 180 degrees")
MoveBackwardStop()

-- secret speed falls back to the cached run speed while moving
S.secret = {}
local secretSpeed = 7.0000001
S.secret[secretSpeed] = true
local oldGUS = GetUnitSpeed
GetUnitSpeed = function() return secretSpeed, secretSpeed, 7, 4.7 end
S.speed = 1
check(ns.Motion:Speed() == 7, "secret speed -> cached run speed")
GetUnitSpeed = oldGUS
S.secret = nil

-- map interaction: wheel zoom, drag, middle click fit, shift+click I'm here
local vp
for _, f in ipairs(S.frames) do if f._scripts.OnMouseWheel then vp = f end end
check(vp ~= nil, "viewport found")
vp._scripts.OnMouseWheel(vp, 1)
vp._scripts.OnMouseDown(vp, "MiddleButton")
S.shift = true
S.cursor = { 520, 410 }
vp._scripts.OnMouseDown(vp, "LeftButton")
S.shift = false
check(ns.state.filter.n == ns.state.filter.o.n, "shift+click reseeds around the clicked point")
S.advance(1)
check(#(SakedMapDB.entrances[229] or {}) >= 1, "click right after zoning in is learned as an entrance")

-- diag / reset / level buttons don't error
SlashCmdList.SAKEDMAP("diag")
SlashCmdList.SAKEDMAP("reset")
S.advance(0.5)
SlashCmdList.SAKEDMAP("")
SlashCmdList.SAKEDMAP("")
check(SakedMapFrame:IsShown(), "toggle twice keeps it shown")

-- /reload inside: restore around the last estimate
local last = SakedMapDB.last
check(last and last.map == 229, "last position saved")
S.fire("PLAYER_ENTERING_WORLD", false, true)
check(ns.state.filter ~= nil and ns.state.zoneInAt == nil, "reload restores without learning an entrance")

-- leaving the dungeon
S.instance = nil
S.fire("ZONE_CHANGED_NEW_AREA")
check(ns.state.mapID == nil and not SakedMapFrame:IsShown(), "left the dungeon, map hidden")

-- every data file loads and its grid decodes
local n = 0
for id, d in pairs(ns.data) do
    local g = ns.Grid.new(d)
    local _, count = g:allFloors()
    check(count > 1000 and #d.tiles > 0 and #d.levels > 0, ("data %d %s: %d floors, %d tiles, %d levels"):format(id, d.name, count, #d.tiles, #d.levels))
    n = n + 1
end
io.stdout:write(("all good (%d dungeons)\n"):format(n))
