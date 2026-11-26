-- Motion: what the game tells an addon about the player's own movement, without any position.
--   * speed            GetUnitSpeed("player") (cached run speed when the value is secret)
--   * which keys       hooks on MoveForwardStart, StrafeLeftStart, ToggleAutoRun... (the key bindings call
--                      these Lua globals, so hooksecurefunc sees them; it does not block or change them)
--   * facing           GetPlayerFacing() when the client gives it, else nil
--   * turning/looking  PLAYER_STARTED_TURNING / PLAYER_STARTED_LOOKING events, turn keys
--   * falling          IsFalling()
local _, ns = ...

local atan2, pi = math.atan2, math.pi

local Motion = {}
ns.Motion = Motion

local keys = { fwd = false, back = false, left = false, right = false, auto = false, steer = false, tl = false, tr = false }
Motion.keys = keys
local looking, turningEv = false, false
local moving = false
local runSpeed = 7.0
local stats = { facingOk = 0, facingNil = 0, facingSecret = 0, speedOk = 0, speedSecret = 0 }
Motion.stats = stats

local function secret(v)
    return issecretvalue and issecretvalue(v)
end

local function hook(name, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end

function Motion:Init()
    hook("MoveForwardStart", function() keys.fwd = true; keys.auto = false end)
    hook("MoveForwardStop", function() keys.fwd = false end)
    hook("MoveBackwardStart", function() keys.back = true; keys.auto = false end)
    hook("MoveBackwardStop", function() keys.back = false end)
    hook("StrafeLeftStart", function() keys.left = true end)
    hook("StrafeLeftStop", function() keys.left = false end)
    hook("StrafeRightStart", function() keys.right = true end)
    hook("StrafeRightStop", function() keys.right = false end)
    hook("TurnLeftStart", function() keys.tl = true end)
    hook("TurnLeftStop", function() keys.tl = false end)
    hook("TurnRightStart", function() keys.tr = true end)
    hook("TurnRightStop", function() keys.tr = false end)
    hook("MoveAndSteerStart", function() keys.steer = true end)
    hook("MoveAndSteerStop", function() keys.steer = false end)
    hook("ToggleAutoRun", function() keys.auto = not keys.auto end)
    hook("StartAutoRun", function() keys.auto = true end)
    hook("StopAutoRun", function() keys.auto = false end)
end

function Motion:OnEvent(event)
    if event == "PLAYER_STARTED_MOVING" then moving = true
    elseif event == "PLAYER_STOPPED_MOVING" then moving = false
    elseif event == "PLAYER_STARTED_LOOKING" then looking = true
    elseif event == "PLAYER_STOPPED_LOOKING" then looking = false
    elseif event == "PLAYER_STARTED_TURNING" then turningEv = true
    elseif event == "PLAYER_STOPPED_TURNING" then turningEv = false
    end
end

-- direction of travel relative to facing, from the held keys (0 = forward, counter-clockwise)
local function keyDirection()
    local f = (keys.fwd or keys.auto or keys.steer) and 1 or 0
    if keys.back then f = f - 1 end
    local s = 0
    if keys.left then s = s + 1 end
    if keys.right then s = s - 1 end
    if f == 0 and s == 0 then return 0, false end -- mouse run, click to move...: assume forward
    return atan2(s, f), true
end

local TAU = 2 * pi
local function wrap(a) return (a + pi) % TAU - pi end

-- Facing from the game API. Inside instances it is nil (restricted since patch 7.1, also on Forever).
function Motion:ApiFacing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    if not ok or f == nil then stats.facingNil = stats.facingNil + 1; return nil end
    if secret(f) then stats.facingSecret = stats.facingSecret + 1; return nil end
    stats.facingOk = stats.facingOk + 1
    return f
end

-- Facing from the minimap's compass ring. With "Rotate Minimap" on, the client turns
-- MinimapCompassTexture with the player, in instances too, and an addon can read that rotation
-- (encounter addons use the same reading). It only turns while the minimap is drawn.
function Motion:CompassRotation()
    local t = MinimapCompassTexture
    if not t or not t.GetRotation then return nil, "nocompass" end
    if GetCVar and GetCVar("rotateMinimap") ~= "1" then return nil, "norotate" end
    if t.IsVisible and not t:IsVisible() then return nil, "hidden" end
    local ok, r = pcall(t.GetRotation, t)
    if not ok or r == nil then return nil, "error" end
    if secret(r) then return nil, "secret" end
    return r, "ok"
end

-- calibration: facing = sign * rotation + offset. Learned outdoors where both readings exist,
-- kept in SakedMapDB. The default (sign -1, offset 0) is how a rotating map turns: the world
-- turns the other way round from the player.
local cal
function Motion:SetCalibration(t)
    cal = t
    cal.sign = cal.sign or -1
    cal.offset = cal.offset or 0
    cal.n = cal.n or 0
    cal.sum = cal.sum or { 0, 0, 0, 0 } -- running cos/sin sums for sign -1 and +1
end

local function calibrate(f, r)
    local s = cal.sum
    local a, b = wrap(f + r), wrap(f - r) -- offsets for sign -1 and +1
    s[1], s[2] = s[1] * 0.995 + math.cos(a), s[2] * 0.995 + math.sin(a)
    s[3], s[4] = s[3] * 0.995 + math.cos(b), s[4] * 0.995 + math.sin(b)
    cal.n = cal.n + 1
    -- the right sign is the one whose offset stays put while the player turns
    local rm = math.sqrt(s[1] ^ 2 + s[2] ^ 2)
    local rp = math.sqrt(s[3] ^ 2 + s[4] ^ 2)
    if rm >= rp then
        cal.sign, cal.offset = -1, atan2(s[2], s[1])
    else
        cal.sign, cal.offset = 1, atan2(s[4], s[3])
    end
    cal.quality = math.max(rm, rp) / (1 / (1 - 0.995)) -- 1 = perfectly consistent
end

-- facing in radians (0 = north, counter-clockwise) and where it came from: "api", "compass" or nil
function Motion:Facing()
    local f = self:ApiFacing()
    local r = self:CompassRotation()
    if f and r and cal then
        calibrate(f, r)
    end
    if f then return f, "api" end
    if r and cal then return wrap(cal.sign * r + cal.offset), "compass" end
    return nil, nil
end

function Motion:Speed()
    local ok, cur, run, _, swim = pcall(GetUnitSpeed, "player")
    if ok and cur ~= nil and not secret(cur) then
        stats.speedOk = stats.speedOk + 1
        if run and not secret(run) and run > 0 then runSpeed = run end
        return cur
    end
    stats.speedSecret = stats.speedSecret + 1
    -- secret (combat restrictions): assume the last known run speed while the game says we move
    local m = moving
    if IsPlayerMoving then
        local ok2, v = pcall(IsPlayerMoving)
        if ok2 and v ~= nil and not secret(v) then m = v end
    end
    if not m then return 0 end
    local s = runSpeed
    if keys.back and not keys.fwd then s = s * 4.5 / 7 end
    return s
end

local function bool(fn)
    if not fn then return false end
    local ok, v = pcall(fn)
    if not ok or secret(v) then return false end
    return v and true or false
end

-- one sample for the filter (see Filter:predict)
local sample = {}
function Motion:Sample()
    sample.speed = self:Speed()
    local dir, fromKeys = keyDirection()
    sample.dir = dir
    sample.fromKeys = fromKeys
    sample.facing, sample.facingSource = self:Facing()
    sample.turning = looking or turningEv or keys.tl or keys.tr
    -- keyboard turning is a known rate (180 degrees per second): use it when facing is unknown
    local tr = 0
    if keys.tl then tr = tr + pi end
    if keys.tr then tr = tr - pi end
    sample.turnRate = tr
    sample.falling = bool(IsFalling)
    sample.swimming = bool(IsSwimming)
    return sample
end

return Motion
