-- Grid: the dungeon's walkable floors, decoded from the generated data (Data/M<mapID>.lua).
-- Pure Lua 5.1, no game API, so it runs in the tests too.
local _, ns = ...
ns = ns or {}

local floor, abs, huge = math.floor, math.abs, math.huge
local byte = string.byte

local Grid = {}
Grid.__index = Grid
ns.Grid = Grid

-- base-64 alphabet used by tools/build.py
local DEC = {}
do
    local a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #a do DEC[byte(a, i)] = i - 1 end
end

local BUCKET = 32 -- yards per bucket of the room lookup index

function Grid.new(data)
    local g = setmetatable({}, Grid)
    g.data = data
    g.cell = data.cell
    g.zq = data.zq
    g.zmin = data.zmin
    g.gx0, g.gy0, g.gw, g.gh = data.gx0, data.gy0, data.gw, data.gh
    g.rows = {}       -- decoded rows: rows[gx][gy] = z (one floor) or { z1, z2, ... } (ascending)
    g.touched = {}    -- rows[gx] last used at (g.clock, set by the caller; nil = do not track)
    g.groups = data.groups
    g:indexGroups()
    return g
end

-- decode one row string: per cell either "A<run>" (empty cells) or "<n><z z>..." (n floors)
local function decodeRow(s, zmin, zq)
    local out = {}
    local i, gy, len = 1, 0, #s
    while i <= len do
        local n = DEC[byte(s, i)]
        if n == 0 then
            gy = gy + DEC[byte(s, i + 1)] + 1
            i = i + 2
        elseif n == 1 then
            -- most cells have one floor: keep the bare height (a table per cell costs far more memory)
            out[gy] = zmin + (DEC[byte(s, i + 1)] * 64 + DEC[byte(s, i + 2)]) * zq
            i = i + 3
            gy = gy + 1
        else
            local list = {}
            i = i + 1
            for k = 1, n do
                local q = DEC[byte(s, i)] * 64 + DEC[byte(s, i + 1)]
                list[k] = zmin + q * zq
                i = i + 2
            end
            out[gy] = list
            gy = gy + 1
        end
    end
    return out
end

function Grid:row(ix)
    local r = self.rows[ix]
    local clock = self.clock
    if clock then self.touched[ix] = clock end
    if r == nil then
        local s = self.data.rows[ix - self.gx0 + 1]
        if not s then
            r = false
        else
            local rel = decodeRow(s, self.zmin, self.zq)
            r = {}
            for gy, list in pairs(rel) do r[gy + self.gy0] = list end
        end
        self.rows[ix] = r
    end
    return r
end

function Grid:cellOf(x, y)
    return floor(x / self.cell), floor(y / self.cell)
end

-- all floor heights in the cell holding (x, y), or nil. The list may be a shared scratch table:
-- read it right away, do not keep it.
local scratch = {}
function Grid:floorsAt(x, y)
    local ix, iy = floor(x / self.cell), floor(y / self.cell)
    local r = self:row(ix)
    local v = r and r[iy]
    if type(v) == "number" then
        scratch[1] = v
        return scratch
    end
    return v
end

-- the floor a walker at height z ends up on after stepping to (x, y): the closest one in
-- [z - down, z + up]; nil when there is none (a wall, a gap, a drop too deep)
function Grid:stepTo(x, y, z, up, down)
    local ix, iy = floor(x / self.cell), floor(y / self.cell)
    local r = self:row(ix)
    local list = r and r[iy]
    if not list then return nil end
    if type(list) == "number" then
        local d = list - z
        if d <= up and d >= -down then return list end
        return nil
    end
    local best, bestd = nil, huge
    for k = 1, #list do
        local f = list[k]
        local d = f - z
        if d <= up and d >= -down then
            local ad = abs(d)
            if ad < bestd then best, bestd = f, ad end
        end
    end
    return best
end

-- nearest floor height to z in the cell (no limits), and its distance
function Grid:nearestFloor(x, y, z)
    local list = self:floorsAt(x, y)
    if not list then return nil end
    local best, bestd = nil, huge
    for k = 1, #list do
        local d = abs(list[k] - z)
        if d < bestd then best, bestd = list[k], d end
    end
    return best, bestd
end

-- search outward for the closest floor cell to (x, y, z); returns x, y, z of its centre
function Grid:snap(x, y, z, maxRadius)
    local c = self.cell
    local ix, iy = floor(x / c), floor(y / c)
    local maxR = floor((maxRadius or 20) / c)
    local bx, by, bz, bd
    for rad = 0, maxR do
        for dx = -rad, rad do
            for dy = -rad, rad do
                if dx == -rad or dx == rad or dy == -rad or dy == rad then
                    local r = self:row(ix + dx)
                    local list = r and r[iy + dy]
                    if type(list) == "number" then scratch[1] = list; list = scratch end
                    if list then
                        for k = 1, #list do
                            local cx, cy = (ix + dx + 0.5) * c, (iy + dy + 0.5) * c
                            local d = (cx - x) ^ 2 + (cy - y) ^ 2 + ((list[k] - z) * 2) ^ 2
                            if not bd or d < bd then bx, by, bz, bd = cx, cy, list[k], d end
                        end
                    end
                end
            end
        end
        if bd and rad * c > 3 then break end
    end
    return bx, by, bz
end

-- floors per row, counted straight from the encoded strings (no tables), cached
function Grid:rowCounts()
    if self.counts then return self.counts, self.total end
    local counts, total = {}, 0
    for r, s in ipairs(self.data.rows) do
        local i, len, n = 1, #s, 0
        while i <= len do
            local k = DEC[byte(s, i)]
            if k == 0 then
                i = i + 2
            else
                n = n + k
                i = i + 1 + 2 * k
            end
        end
        total = total + n
        counts[r] = total -- cumulative
    end
    self.counts, self.total = counts, total
    return counts, total
end

-- one floor picked uniformly at random, read from the encoded row (nothing decoded or kept)
function Grid:randomFloor(rng)
    local counts, total = self:rowCounts()
    if total == 0 then return nil end
    local want = floor(rng() * total) + 1
    local lo, hi = 1, #counts
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if counts[mid] < want then lo = mid + 1 else hi = mid end
    end
    local k = want - (counts[lo - 1] or 0) -- k-th floor inside row lo
    local s = self.data.rows[lo]
    local i, gy, len = 1, 0, #s
    while i <= len do
        local n = DEC[byte(s, i)]
        if n == 0 then
            gy = gy + DEC[byte(s, i + 1)] + 1
            i = i + 2
        else
            if k <= n then
                local p = i + 1 + 2 * (k - 1)
                local q = DEC[byte(s, p)] * 64 + DEC[byte(s, p + 1)]
                local c = self.cell
                return (lo - 1 + self.gx0 + 0.5) * c, (gy + self.gy0 + 0.5) * c, self.zmin + q * self.zq
            end
            k = k - n
            i = i + 1 + 2 * n
            gy = gy + 1
        end
    end
end

-- n random floors as a flat { x, y, z, ... } list; filter(x, y, z) may reject (tries a limited number of times)
function Grid:randomFloors(n, rng, filter)
    local out = {}
    local tries = filter and n * 40 or n
    for _ = 1, tries do
        local x, y, z = self:randomFloor(rng)
        if x and (not filter or filter(x, y, z)) then
            out[#out + 1], out[#out + 2], out[#out + 3] = x, y, z
            if #out >= n * 3 then break end
        end
    end
    return out
end

-- forget decoded rows nobody asked for since `before` (keeps memory small in big dungeons)
function Grid:sweep(now, before)
    self.touched = self.touched or {}
    for ix in pairs(self.rows) do
        local t = self.touched[ix]
        if not t or t < before then
            self.rows[ix] = nil
            self.touched[ix] = nil
        end
    end
end

-- every floor as a flat array { x1, y1, z1, x2, ... } (cell centres); filter(x, y, z) may reject.
-- Decodes every row: for tools and tests; the addon samples with randomFloors instead.
function Grid:allFloors(filter)
    local out, n = {}, 0
    local c = self.cell
    for ix = self.gx0, self.gx0 + self.gw - 1 do
        local r = self:row(ix)
        if r then
            for iy, list in pairs(r) do
                if type(list) == "number" then list = { list } end
                for k = 1, #list do
                    local x, y, z = (ix + 0.5) * c, (iy + 0.5) * c, list[k]
                    if not filter or filter(x, y, z) then
                        out[n + 1], out[n + 2], out[n + 3] = x, y, z
                        n = n + 3
                    end
                end
            end
        end
    end
    return out, n / 3
end

-- rooms: buckets of group indices by 32-yard squares, then "smallest box holding the point" (same rule
-- as tools/build.py, which reports how often it agrees with the geometry)
function Grid:indexGroups()
    self.buckets = {}
    for i, g in ipairs(self.groups) do
        local b = g.bb
        g.vol = (b[4] - b[1]) * (b[5] - b[2]) * (b[6] - b[3])
        for bx = floor(b[1] / BUCKET), floor(b[4] / BUCKET) do
            for by = floor(b[2] / BUCKET), floor(b[5] / BUCKET) do
                local key = bx * 65536 + by
                local l = self.buckets[key]
                if not l then l = {}; self.buckets[key] = l end
                l[#l + 1] = i
            end
        end
    end
end

function Grid:groupAt(x, y, z)
    local l = self.buckets[floor(x / BUCKET) * 65536 + floor(y / BUCKET)]
    if not l then return nil end
    local best, bestv
    for k = 1, #l do
        local i = l[k]
        local g = self.groups[i]
        local b = g.bb
        if x >= b[1] - 0.5 and x <= b[4] + 0.5 and y >= b[2] - 0.5 and y <= b[5] + 0.5
            and z + 1 >= b[3] - 1 and z + 1 <= b[6] + 2 then
            if not bestv or g.vol < bestv then best, bestv = i, g.vol end
        end
    end
    return best
end

-- display level for a height: the level whose [z0, z1] is nearest
function Grid:levelForZ(z)
    local best, bestd = 1, huge
    for i, lv in ipairs(self.data.levels) do
        local d = 0
        if z < lv.z0 then d = lv.z0 - z elseif z > lv.z1 then d = z - lv.z1 end
        if d < bestd then best, bestd = i, d end
    end
    return best
end

return Grid
