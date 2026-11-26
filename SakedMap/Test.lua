-- Test: /smap test outdoors. Outside dungeons the game still gives the real position (UnitPosition),
-- so the same movement reading the dungeon arrow uses (speed, keys, facing) is integrated here and
-- compared with the truth every 10 seconds. It also checks which way UnitPosition's axes go, and it
-- calibrates the minimap compass while you turn (when Rotate Minimap is on).
local _, ns = ...
local L = ns.L
local Motion = ns.Motion

local Test = {}
ns.Test = Test

local cos, sin, sqrt, abs = math.cos, math.sin, math.sqrt, math.abs
local f = CreateFrame("Frame")
local on = false
local acc, report = 0, 0
local start, est, walked
-- candidate readings of UnitPosition's first two values as world (x, y): (a, b), (b, a), ...
local AXES = {
    { "a,b", function(a, b) return a, b end },
    { "b,a", function(a, b) return b, a end },
    { "-a,-b", function(a, b) return -a, -b end },
    { "-b,-a", function(a, b) return -b, -a end },
}
local errs

local function truePos()
    local ok, a, b = pcall(UnitPosition, "player")
    if not ok or a == nil or (issecretvalue and (issecretvalue(a) or issecretvalue(b))) then return nil end
    return a, b
end

local function reset()
    local a, b = truePos()
    start = { a, b }
    est = {}
    for i = 1, #AXES do est[i] = { AXES[i][2](a, b) } end
    walked = 0
    errs = {}
end

f:SetScript("OnUpdate", function(_, elapsed)
    if not on then return end
    acc = acc + elapsed
    if acc < 0.05 then return end
    local dt = acc
    acc = 0
    local m = Motion:Sample()
    if m.facing and m.speed > 0.05 then
        local head = m.facing + m.dir
        local d = m.speed * dt
        for i = 1, #AXES do
            est[i][1] = est[i][1] + cos(head) * d
            est[i][2] = est[i][2] + sin(head) * d
        end
        walked = walked + d
    end
    report = report + dt
    if report >= 10 then
        report = 0
        local a, b = truePos()
        if not a then return end
        local best, bestErr = 1, math.huge
        for i = 1, #AXES do
            local tx, ty = AXES[i][2](a, b)
            local e = sqrt((tx - est[i][1]) ^ 2 + (ty - est[i][2]) ^ 2)
            if e < bestErr then best, bestErr = i, e end
        end
        if walked > 5 then
            ns.print(L.TEST_LINE:format(walked, bestErr, 100 * bestErr / walked, m.facingSource or "-", AXES[best][1]))
        end
        reset()
    end
end)

function Test:Toggle()
    if on then
        on = false
        ns.print(L.TEST_OFF)
        return
    end
    if not truePos() then
        ns.print(L.TEST_INSTANCE)
        return
    end
    reset()
    acc, report = 0, 0
    on = true
    ns.print(L.TEST_ON)
end
