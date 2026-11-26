-- Unit checks for Grid and Filter on real data.
package.path = "./tests/?.lua;" .. package.path
local H = require("harness")
local ns = H.load()
local function check(c, m) if not c then error("FAIL: " .. m, 2) end io.stdout:write("ok  " .. m .. "\n") end

local d = H.loadData(ns, 429)
collectgarbage("collect")
local base = collectgarbage("count")
local g = ns.Grid.new(d)
math.randomseed(3)

-- every random floor exists in the decoded grid
local _, total = g:rowCounts()
local bad = 0
for _ = 1, 2000 do
    local x, y, z = g:randomFloor(math.random)
    local list = g:floorsAt(x, y)
    local found = false
    for _, fz in ipairs(list or {}) do if math.abs(fz - z) < 1e-6 then found = true end end
    if not found then bad = bad + 1 end
end
check(bad == 0, ("2000 random floors all exist (of %d)"):format(total))

-- counts agree with a full decode
local _, n = g:allFloors()
check(n == total, ("row counts %d = decoded floors %d"):format(total, n))

-- memory: a fresh grid seeded at the entrance, then a tracking session, stays small
g = ns.Grid.new(d)
collectgarbage("collect")
local f = ns.Filter.new(g, nil, math.random)
f:seedEntrances(d.entrances, true)
for i = 1, 300 do
    f:predict(0.1, { speed = 7, dir = 0, facing = (i * 0.01) % 6.28 })
    f:estimate((i * 0.01) % 6.28)
    g.clock = i * 0.1
    if i % 100 == 0 then g:sweep(i * 0.1, i * 0.1 - 5) end
end
collectgarbage("collect")
local kb = collectgarbage("count") - base
check(kb < 30000, ("Dire Maul session memory %.0f KB (worst dungeon, global guesses still alive)"):format(kb))

-- stepTo respects step limits; snap finds a floor
local x, y, z = g:randomFloor(math.random)
check(g:stepTo(x, y, z + 1, 2.6, 4) == z, "stepTo lands on the floor below a small drop")
check(g:stepTo(x, y, z - 10, 2.6, 4) == nil or g:stepTo(x, y, z - 10, 2.6, 4) ~= z, "stepTo refuses a 10 yd climb")
local sx, sy, sz = g:snap(x + 0.3, y - 0.3, z, 5)
check(sx and math.abs(sz - z) < 3, "snap finds the nearby floor")

-- seeding near a point keeps every guess within the radius
f:seedAt(x, y, z, 4, true)
local far = 0
for i = 1, f.n do if (f.x[i] - x) ^ 2 + (f.y[i] - y) ^ 2 > (4 + 3) ^ 2 then far = far + 1 end end
check(far == 0, "seedAt keeps guesses within the radius")
io.stdout:write("unit: all good\n")
