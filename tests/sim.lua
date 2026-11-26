-- Simulated runs through a real dungeon: a "true" walker follows paths over the generated floor grid,
-- the filter only gets what the addon gets in game (speed, key direction, facing or not, subzone name),
-- and we measure how far the estimate is from the truth.
--
--   lua5.1 tests/sim.lua [mapID] [seed] [mode] [seconds] [pathcsv]
--   mode: facing (GetPlayerFacing works) | nofacing (it returns nil inside instances)
package.path = "./tests/?.lua;" .. package.path
local H = require("harness")
local ns = H.load()

local mapID = tonumber(arg[1]) or 229
local seed = tonumber(arg[2]) or 1
local mode = arg[3] or "facing"
local duration = tonumber(arg[4]) or 240
local pathOut = arg[5]
math.randomseed(seed)
local rng = math.random

local data = H.loadData(ns, mapID)
local grid = ns.Grid.new(data)
local floor, sqrt, atan2, cos, sin, pi, abs = math.floor, math.sqrt, math.atan2, math.cos, math.sin, math.pi, math.abs

-------------------------------------------------------------------- truth: paths over the floor graph
local c = grid.cell
local function key(ix, iy, z) return ix .. ":" .. iy .. ":" .. floor(z * 2) end

-- breadth-first search from (ix, iy, z) for up to maxNodes nodes; returns a path to a far random node
local function randomPath(sx, sy, sz, minLen)
    local ix0, iy0 = floor(sx / c), floor(sy / c)
    local start = { ix0, iy0, sz }
    local prev, order = { [key(ix0, iy0, sz)] = false }, { start }
    local head = 1
    while head <= #order and #order < 40000 do
        local n = order[head]; head = head + 1
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    local nx, ny = n[1] + dx, n[2] + dy
                    local nz = grid:stepTo((nx + 0.5) * c, (ny + 0.5) * c, n[3], 1.6, 2.5)
                    -- diagonal moves need both side cells walkable (no corner cutting through walls)
                    if nz and dx ~= 0 and dy ~= 0 then
                        if not grid:stepTo((n[1] + dx + 0.5) * c, (n[2] + 0.5) * c, n[3], 1.6, 2.5)
                            or not grid:stepTo((n[1] + 0.5) * c, (n[2] + dy + 0.5) * c, n[3], 1.6, 2.5) then nz = nil end
                    end
                    if nz then
                        local k = key(nx, ny, nz)
                        if prev[k] == nil then
                            prev[k] = n
                            order[#order + 1] = { nx, ny, nz }
                        end
                    end
                end
            end
        end
    end
    -- pick a target among the far half
    local lo = math.max(2, floor(#order * 0.5))
    local target = order[lo + floor(rng() * (#order - lo))]
    local path = {}
    local n = target
    while n do
        table.insert(path, 1, { (n[1] + 0.5) * c, (n[2] + 0.5) * c, n[3] })
        n = prev[key(n[1], n[2], n[3])]
    end
    if #path * c < (minLen or 0) then return nil end
    -- string pulling: walk straight to the farthest waypoint still reachable in a straight line
    local function clear(a, b)
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = sqrt(dx * dx + dy * dy)
        local steps = math.max(1, floor(len / 0.7))
        local z = a[3]
        for k = 1, steps do
            local px, py = a[1] + dx * k / steps, a[2] + dy * k / steps
            z = grid:stepTo(px, py, z, 1.6, 2.5)
            if not z then return false end
        end
        return math.abs(z - b[3]) < 2
    end
    local out, i = { path[1] }, 1
    while i < #path do
        local j = math.min(#path, i + 40)
        while j > i + 1 and not clear(path[i], path[j]) do j = j - 1 end
        out[#out + 1] = path[j]
        i = j
    end
    return out
end

-- start somewhere on a big floor patch: a random floor point with a long path from it
local all = grid:allFloors()
local startX, startY, startZ
local START = os.getenv("START") or "global"
if START == "entrance" and data.entrances and #data.entrances > 0 then
    local e = data.entrances[1 + floor(rng() * #data.entrances)]
    startX, startY, startZ = grid:snap(e[1], e[2], e[3], 6)
end
for _ = 1, (startX and 0 or 50) do
    local hint = data.hints[1 + floor(rng() * #data.hints)]
    if hint and rng() < 0.5 then
        startX, startY, startZ = grid:snap(hint[1], hint[2], hint[3], 30)
    else
        local k = floor(rng() * (#all / 3)) * 3
        startX, startY, startZ = all[k + 1], all[k + 2], all[k + 3]
    end
    if startX and randomPath(startX, startY, startZ, 150) then break end
end

-------------------------------------------------------------------- filter under test
local filter = ns.Filter.new(grid, nil, rng)
local function areaOf(x, y, z)
    local name = grid:areaName(x, y, z)
    if name == "" then return nil end -- the addon only uses non-empty subzone texts
    return name
end
filter.area = areaOf(startX, startY, startZ)
if START == "entrance" and data.entrances and #data.entrances > 0 then
    filter:seedEntrances(data.entrances, mode == "facing")
else
    filter:seedGlobal(mode == "facing")
end

local dt = 0.1
local tx, ty, tz = startX, startY, startZ
local tface = rng() * 2 * pi
local t = 0
local log = {}
local lockT
local errs = {}
local path, pi_ = nil, 1
local strafeUntil, strafeDir = 0, 0
local speed = 7
local out = pathOut and io.open(pathOut, "w")

while t < duration do
    if not path or pi_ > #path then
        path = randomPath(tx, ty, tz, 60)
        if os.getenv("SIMDEBUG") then print("path", path and #path, tx, ty, tz) end
        pi_ = 2
        if not path then break end
    end
    -- head for the next waypoint
    local wp = path[pi_]
    local dx, dy = wp[1] - tx, wp[2] - ty
    local dist = sqrt(dx * dx + dy * dy)
    local travel = atan2(dy, dx)
    local motion = { speed = speed, dir = 0, turning = false, turnRate = 0, falling = false }
    if t > strafeUntil and rng() < 0.01 then strafeUntil, strafeDir = t + 1.5, (rng() < 0.5 and 1 or -1) * pi / 4 end
    local rel = 0
    if t < strafeUntil then rel = strafeDir end
    local newFace = travel - rel
    local dTurn = (newFace - tface + pi) % (2 * pi) - pi
    if abs(dTurn) > 0.05 then motion.turning = true end
    tface = newFace
    motion.dir = rel
    if mode == "facing" then
        motion.facing = tface + (rng() - 0.5) * 0.01
    end
    local step = math.min(dist, speed * dt)
    if dist <= speed * dt then pi_ = pi_ + 1 end
    tx, ty = tx + cos(travel) * step, ty + sin(travel) * step
    tz = grid:stepTo(tx, ty, tz, 2, 3) or wp[3]
    if step < speed * dt * 0.99 then motion.speed = step / dt end
    filter.area = areaOf(tx, ty, tz)
    filter:predict(dt, motion)
    local e = filter:estimate(motion.facing)
    t = t + dt
    if e then
        local err = sqrt((e.x - tx) ^ 2 + (e.y - ty) ^ 2)
        local zerr = abs(e.z - tz)
        if not lockT and filter:isLocked() and err < 15 then lockT = t end
        if lockT then errs[#errs + 1] = err + (zerr > 8 and 50 or 0) end
        if out then out:write(string.format("%.2f,%.2f,%.2f,%.2f\n", tx, ty, e.x, e.y)) end
        if floor(t * 10 + 0.5) % 300 == 0 then
            log[#log + 1] = string.format("t=%5.1f err=%6.1f zerr=%5.1f spread=%6.1f n=%d", t, err, zerr, e.spread, filter.n)
        end
    end
end
if out then out:close() end
table.sort(errs)
local function pct(p) return errs[math.max(1, floor(#errs * p))] or -1 end
for _, l in ipairs(log) do print(l) end
print(string.format("RESULT start=" .. START .. " map=%d seed=%d mode=%s lock=%s median=%.1f p90=%.1f p99=%.1f",
    mapID, seed, mode, lockT and string.format("%.1fs", lockT) or "never", pct(0.5), pct(0.9), pct(0.99)))
