-- Filter: where am I? A particle filter over the dungeon's walkable floors.
--
-- Each particle is a guess (x, y, z, heading offset, speed scale). Every tick it is moved by what the
-- game tells us about movement (speed, which keys are held, facing when available). Guesses that walk
-- into a wall or off a ledge lose weight; guesses standing in a room whose name does not match the
-- subzone text lose weight. What survives is where the player most likely is.
--
-- Pure Lua 5.1 (no game API), so tests/sim.lua can drive it with real dungeon data.
local _, ns = ...
ns = ns or {}

local cos, sin, sqrt, log, pi, abs, floor, atan2 = math.cos, math.sin, math.sqrt, math.log, math.pi, math.abs, math.floor, math.atan2
local TAU = 2 * pi

local Filter = {}
Filter.__index = Filter
ns.Filter = Filter

Filter.defaults = {
    n = 600,              -- particles while tracking
    nGlobal = 2500,       -- particles while lost (spread over every candidate floor)
    stepUp = 2.6,         -- yards a walker climbs per 2-yard cell (stairs, ramps)
    stepDown = 4.0,       -- yards it may drop per step while not falling
    fallDown = 60.0,      -- ... and while falling
    wallPenalty = 0.25,   -- weight kept by a guess that tried to walk through a wall
    slidePenalty = 0.85,  -- weight kept by a guess that slid along a wall (players do that all the time)
    inject = 0.02,        -- share of guesses re-drawn near the estimate at each resampling (recovery)
    injectRadius = 25,    -- yards
    speedNoise = 0.04,    -- per-particle speed scale spread (1 +/- this)
    headingNoise = 0.035, -- radians of heading jitter per second of movement, facing known
    biasNoise = 0.05,     -- spread of the per-particle facing bias, facing known
    turnNoise = 2.2,      -- radians per second of heading diffusion while turning, facing unknown
    driftNoise = 0.08,    -- radians per second of heading drift, facing unknown, not turning
    posJitter = 0.35,     -- yards of jitter added at resampling
    areaMismatch = 0.80,  -- weight kept per tick when the guess's room name differs from the subzone
    areaUnnamed = 0.97,   -- ... when the guess is in an unnamed room and the subzone has a name
    trackSpread = 25,     -- below this spread (yards) the filter counts as locked on
}

local function gauss(rng)
    local u1 = rng()
    if u1 < 1e-12 then u1 = 1e-12 end
    return sqrt(-2 * log(u1)) * cos(TAU * rng())
end

function Filter.new(grid, opts, rng)
    local f = setmetatable({}, Filter)
    f.grid = grid
    f.o = {}
    for k, v in pairs(Filter.defaults) do f.o[k] = v end
    for k, v in pairs(opts or {}) do f.o[k] = v end
    f.rng = rng or math.random
    f.n = 0
    f.x, f.y, f.z, f.h, f.s, f.w = {}, {}, {}, {}, {}, {}
    f.ox, f.oy, f.oz = {}, {}, {} -- where each guess started: gives the entrance once locked on
    f.area = nil          -- current subzone name to match (already localized to the data's names)
    f.areaNames = nil     -- set of names that exist in this dungeon
    f.est = nil
    return f
end

-- fill with particles drawn from a flat { x, y, z, ... } list of candidate floor points
function Filter:seedFrom(points, count, headingKnown)
    local m = #points / 3
    if m == 0 then return false end
    local rng, c = self.rng, self.grid.cell
    count = count or self.o.nGlobal
    self.n = count
    for i = 1, count do
        local k = floor(rng() * m) * 3
        self.x[i] = points[k + 1] + (rng() - 0.5) * c
        self.y[i] = points[k + 2] + (rng() - 0.5) * c
        self.z[i] = points[k + 3]
        self.h[i] = headingKnown and gauss(rng) * self.o.biasNoise or rng() * TAU
        self.s[i] = 1 + gauss(rng) * self.o.speedNoise
        self.w[i] = 1 / count
        self.ox[i], self.oy[i], self.oz[i] = self.x[i], self.y[i], self.z[i]
    end
    for i = count + 1, #self.x do
        self.x[i], self.y[i], self.z[i], self.h[i], self.s[i], self.w[i] = nil, nil, nil, nil, nil, nil
        self.ox[i], self.oy[i], self.oz[i] = nil, nil, nil
    end
    self.est = nil
    return true
end

-- start everywhere the current subzone could be (or everywhere)
function Filter:seedGlobal(headingKnown)
    local grid, area = self.grid, self.area
    local filter
    if area then
        filter = function(x, y, z)
            return grid:areaName(x, y, z) == area
        end
    end
    local pts = grid:randomFloors(self.o.nGlobal, self.rng, filter)
    if #pts < 30 then pts = grid:randomFloors(self.o.nGlobal, self.rng) end
    return self:seedFrom(pts, self.o.nGlobal, headingKnown)
end

-- zoning in: most guesses at the known entrances (each a { x, y, z }), the rest anywhere, so a player
-- who appears somewhere else (summoned, resurrected inside) is still found
function Filter:seedEntrances(entrances, headingKnown, share)
    share = share or 0.7
    local grid = self.grid
    local near = {}
    for _, e in ipairs(entrances) do
        local x, y, z = e[1], e[2], e[3]
        for dx = -2, 2 do
            for dy = -2, 2 do
                local px, py = x + dx * grid.cell, y + dy * grid.cell
                local fz = grid:stepTo(px, py, z, 2, 2)
                if fz then
                    near[#near + 1] = (floor(px / grid.cell) + 0.5) * grid.cell
                    near[#near + 1] = (floor(py / grid.cell) + 0.5) * grid.cell
                    near[#near + 1] = fz
                end
            end
        end
    end
    if #near == 0 then return self:seedGlobal(headingKnown) end
    local total = self.o.nGlobal
    local all = grid:randomFloors(total, self.rng)
    local k = floor(total * share)
    local mixed = {}
    local rng = self.rng
    -- build a candidate list with the right proportions, then seed from it
    for i = 1, k do
        local j = floor(rng() * (#near / 3)) * 3
        mixed[#mixed + 1], mixed[#mixed + 2], mixed[#mixed + 3] = near[j + 1], near[j + 2], near[j + 3]
    end
    for i = k + 1, total do
        local j = floor(rng() * (#all / 3)) * 3
        mixed[#mixed + 1], mixed[#mixed + 2], mixed[#mixed + 3] = all[j + 1], all[j + 2], all[j + 3]
    end
    -- seedFrom draws randomly from the list; draw in order instead to keep the proportions exact
    local ok = self:seedFrom(mixed, total, headingKnown)
    for i = 1, total do
        local j = (i - 1) * 3
        self.x[i] = mixed[j + 1] + (rng() - 0.5) * grid.cell
        self.y[i] = mixed[j + 2] + (rng() - 0.5) * grid.cell
        self.z[i] = mixed[j + 3]
        self.ox[i], self.oy[i], self.oz[i] = self.x[i], self.y[i], self.z[i]
    end
    return ok
end

-- start around a known point (the user clicked "I'm here", or a learned entrance)
function Filter:seedAt(x, y, z, radius, headingKnown, count)
    local grid = self.grid
    radius = radius or 4
    local pts = {}
    local c = grid.cell
    local r = floor(radius / c) + 1
    for dx = -r, r do
        for dy = -r, r do
            local px, py = x + dx * c, y + dy * c
            if (px - x) ^ 2 + (py - y) ^ 2 <= radius * radius + c * c then
                local list = grid:floorsAt(px, py)
                if list then
                    for k = 1, #list do
                        if not z or abs(list[k] - z) < 6 then
                            pts[#pts + 1] = (floor(px / c) + 0.5) * c
                            pts[#pts + 1] = (floor(py / c) + 0.5) * c
                            pts[#pts + 1] = list[k]
                        end
                    end
                end
            end
        end
    end
    if #pts == 0 then
        local sx, sy, sz = grid:snap(x, y, z or 0, 40)
        if not sx then return false end
        pts = { sx, sy, sz }
    end
    return self:seedFrom(pts, count or self.o.n, headingKnown)
end

-- motion = { speed = yards/s, dir = angle of travel relative to facing (0 forward, pi back, +pi/2 strafe left),
--            facing = absolute facing in radians (0 = north/+x, counter-clockwise) or nil,
--            turning = true while the player may be turning (mouse look, turn keys), falling = bool }
function Filter:predict(dt, motion)
    local n = self.n
    if n == 0 or dt <= 0 then return end
    local o, rng, grid = self.o, self.rng, self.grid
    local X, Y, Z, H, S, W = self.x, self.y, self.z, self.h, self.s, self.w
    local facing = motion.facing
    local speed = motion.speed or 0
    local dir = motion.dir or 0
    local up = o.stepUp
    local down = motion.falling and o.fallDown or o.stepDown
    local sdt = sqrt(dt)
    local hn
    if facing then
        hn = o.headingNoise * sdt
    else
        hn = (motion.turning and o.turnNoise or o.driftNoise) * sdt
    end
    local moving = speed > 0.05
    local turn = (not facing and motion.turnRate or 0) * dt
    for i = 1, n do
        H[i] = H[i] + turn
        if facing then
            if moving then H[i] = H[i] + gauss(rng) * hn * 0.2 end -- the bias wanders slowly
        else
            H[i] = H[i] + gauss(rng) * hn
        end
        if moving then
            local head = (facing and (facing + H[i]) or H[i]) + dir
            local d = speed * S[i] * dt
            if facing then head = head + gauss(rng) * hn end
            local mx, my = cos(head) * d, sin(head) * d
            local nx, ny = X[i] + mx, Y[i] + my
            local nz = grid:stepTo(nx, ny, Z[i], up, down)
            if nz then
                X[i], Y[i], Z[i] = nx, ny, nz
            else
                -- slide along the wall: keep the part of the move the wall allows
                local ax, ay = abs(mx), abs(my)
                local sx, sy = (ax >= ay) and mx or 0, (ax >= ay) and 0 or my
                local sz = grid:stepTo(X[i] + sx, Y[i] + sy, Z[i], up, down)
                if not sz then
                    sx, sy = (ax >= ay) and 0 or mx, (ax >= ay) and my or 0
                    sz = grid:stepTo(X[i] + sx, Y[i] + sy, Z[i], up, down)
                end
                if sz and (sx ~= 0 or sy ~= 0) then
                    X[i], Y[i], Z[i] = X[i] + sx, Y[i] + sy, sz
                    W[i] = W[i] * o.slidePenalty
                else
                    W[i] = W[i] * o.wallPenalty
                end
            end
        end
    end
    self:observe()
    self:normalize()
end

-- subzone evidence: guesses in a room with another name lose weight
function Filter:observe()
    local area = self.area
    if not area then return end
    local o, grid = self.o, self.grid
    local X, Y, Z, W = self.x, self.y, self.z, self.w
    for i = 1, self.n do
        local name = grid:areaName(X[i], Y[i], Z[i])
        if name ~= area then
            W[i] = W[i] * (name == "" and o.areaUnnamed or o.areaMismatch)
        end
    end
end

function Filter:normalize()
    local W, n = self.w, self.n
    local sum = 0
    for i = 1, n do sum = sum + W[i] end
    self.lastMass = sum
    if sum <= 1e-300 then
        for i = 1, n do W[i] = 1 / n end
        self.collapsed = (self.collapsed or 0) + 1
        return
    end
    self.collapsed = 0
    local sq = 0
    for i = 1, n do
        local v = W[i] / sum
        W[i] = v
        sq = sq + v * v
    end
    self.neff = 1 / sq
    if self.neff < n * 0.5 then self:resample() end
end

-- low variance resampling; the particle count shrinks from nGlobal to n once locked on
function Filter:resample()
    local n, o, rng, grid = self.n, self.o, self.rng, self.grid
    local X, Y, Z, H, S, W = self.x, self.y, self.z, self.h, self.s, self.w
    local target = n
    if n > o.n and self.est and self.est.spread < o.trackSpread then target = o.n end
    local nx, ny, nz, nh, ns_ = {}, {}, {}, {}, {}
    local OX, OY, OZ = self.ox, self.oy, self.oz
    local nox, noy, noz = {}, {}, {}
    local step = 1 / target
    local r = rng() * step
    local c, i = W[1], 1
    for m = 1, target do
        local u = r + (m - 1) * step
        while u > c and i < n do
            i = i + 1
            c = c + W[i]
        end
        local x = X[i] + gauss(rng) * o.posJitter
        local y = Y[i] + gauss(rng) * o.posJitter
        local z = grid:stepTo(x, y, Z[i], 1.0, 1.0)
        if not z then x, y, z = X[i], Y[i], Z[i] end
        nx[m], ny[m], nz[m] = x, y, z
        nh[m] = H[i]
        ns_[m] = S[i] + gauss(rng) * o.speedNoise * 0.1
        nox[m], noy[m], noz[m] = OX[i], OY[i], OZ[i]
    end
    -- recovery: a few guesses restart around the current estimate, so a wrong lock can still let go
    local e = self.est
    if e and o.inject > 0 then
        local k = floor(target * o.inject)
        for m = 1, k do
            local j = 1 + floor(rng() * target)
            local x = e.x + (rng() * 2 - 1) * o.injectRadius
            local y = e.y + (rng() * 2 - 1) * o.injectRadius
            local list = grid:floorsAt(x, y)
            if list then
                local z = list[1 + floor(rng() * #list)]
                if abs(z - e.z) < 30 then
                    nx[j], ny[j], nz[j] = x, y, z
                    nh[j] = nh[1 + floor(rng() * target)]
                end
            end
        end
    end
    self.x, self.y, self.z, self.h, self.s = nx, ny, nz, nh, ns_
    self.ox, self.oy, self.oz = nox, noy, noz
    local nw = {}
    for m = 1, target do nw[m] = 1 / target end
    self.w = nw
    self.n = target
end

-- best guess: the heaviest particle's neighbourhood (a plain mean would land inside walls when the
-- guesses are split between two corridors)
function Filter:estimate(facing)
    local n = self.n
    if n == 0 then return nil end
    local X, Y, Z, H, W = self.x, self.y, self.z, self.h, self.w
    -- coarse vote on a 6-yard lattice to find the densest spot
    -- (keys are non-negative: x and y offset by 4096 cells of 6 yards, z in 12-yard slabs)
    local votes, vz, bestKey, bestV = {}, {}, nil, -1
    for i = 1, n do
        local key = ((floor(X[i] / 6) + 4096) * 8192 + (floor(Y[i] / 6) + 4096)) * 64 + floor(Z[i] / 12) % 64
        local v = (votes[key] or 0) + W[i]
        votes[key] = v
        vz[key] = (vz[key] or 0) + Z[i] * W[i]
        if v > bestV then bestKey, bestV = key, v end
    end
    local cx, cy, cz, sw = 0, 0, 0, 0
    local hx, hy = 0, 0
    local kxy = floor(bestKey / 64)
    local kx = floor(kxy / 8192) - 4096
    local ky = kxy % 8192 - 4096
    -- mean over particles near the winning cell, on its floor
    local x0, y0 = (kx + 0.5) * 6, (ky + 0.5) * 6
    local z0 = vz[bestKey] / bestV
    for i = 1, n do
        if abs(X[i] - x0) < 12 and abs(Y[i] - y0) < 12 and abs(Z[i] - z0) < 8 then
            local wi = W[i]
            cx, cy, cz, sw = cx + X[i] * wi, cy + Y[i] * wi, cz + Z[i] * wi, sw + wi
            local hh = facing and (facing + H[i]) or H[i]
            hx, hy = hx + cos(hh) * wi, hy + sin(hh) * wi
        end
    end
    if sw <= 0 then return nil end
    cx, cy, cz = cx / sw, cy / sw, cz / sw
    local spread = 0
    for i = 1, n do
        spread = spread + W[i] * ((X[i] - cx) ^ 2 + (Y[i] - cy) ^ 2)
    end
    spread = sqrt(spread)
    local est = self.est or {}
    est.x, est.y, est.z = cx, cy, cz
    est.spread = spread
    est.share = sw          -- weight of the winning cluster (1 = everybody agrees)
    est.heading = facing and facing or atan2(hy, hx)
    est.headingSure = facing ~= nil or sqrt(hx * hx + hy * hy) / sw > 0.8
    local sx, sy, sz = self.grid:snap(cx, cy, cz, 6)
    if sx and (sx - cx) ^ 2 + (sy - cy) ^ 2 > 2.5 then est.x, est.y, est.z = sx, sy, sz end
    est.group = self.grid:groupAt(est.x, est.y, est.z)
    self.est = est
    return est
end

-- where the surviving guesses started (weighted), with their spread: the entrance, once locked on
function Filter:origin()
    local W, OX, OY, OZ = self.w, self.ox, self.oy, self.oz
    local x, y, z, sw = 0, 0, 0, 0
    for i = 1, self.n do
        x, y, z, sw = x + OX[i] * W[i], y + OY[i] * W[i], z + OZ[i] * W[i], sw + W[i]
    end
    if sw <= 0 then return nil end
    x, y, z = x / sw, y / sw, z / sw
    local s = 0
    for i = 1, self.n do s = s + W[i] * ((OX[i] - x) ^ 2 + (OY[i] - y) ^ 2) end
    return x, y, z, sqrt(s / sw)
end

function Filter:isLocked()
    local e = self.est
    return e and e.spread < self.o.trackSpread and e.share > 0.5
end

return Filter
