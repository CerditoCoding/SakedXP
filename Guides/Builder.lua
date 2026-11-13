-- SakedXP · Guide builder
-- Turns compact Lua step tables into SakedXP engine guides.
--
-- Step fields:
--   at      = {x, y}         waypoint on the guide's map (map = n to use another map)
--   say     = "text"         instruction line
--   npc     = "Name"         who to talk to (shown next to accept / turn-in lines)
--   accept  = {id, ...}      or { {id, prereqId}, ... } to auto-skip when the prerequisite is missing
--   work    = id             tracks the quest objectives (done when the quest is complete)
--   turnin  = {id, ...}
--   manual  = "text"         a task you tick by clicking it
--   note    = "text"         extra tip
--   xp      = n              done on reaching level n
--   fp      = "Name"         flight path (click to tick, or auto when learned)
--   home    = "Name"         set hearthstone (auto on binding)
--   only    = "Alliance" | "Horde" | class/race tokens

local _, S = ...
local GB = {}
S.GuideBuilder = GB

-- colour tokens used in guide text: |cRXP_FRIENDLY_...|r etc.
local TOKENS = {
    FRIENDLY = "e3bb72", ENEMY = "d9735a", LOOT = "e3c26b", WARN = "e0954a",
    PICK = "d4a24c", BUY = "9fc06d", TIP = "6e98b8",
}
local function colour(text)
    if not text then return nil end
    return (text:gsub("|cRXP_(%u+)_", function(tok) return "|cff" .. (TOKENS[tok] or "e6e1d8") end))
end
GB.Colour = colour

local Builder = {}
Builder.__index = Builder

function GB.new(meta)
    return setmetatable({ meta = meta, steps = {} }, Builder)
end

function Builder:step(s)
    local map = s.map or self.meta.map
    local els = {}
    if s.say then els[#els + 1] = { tag = "text", text = colour(s.say) } end
    for _, a in ipairs(s.accept or {}) do
        if type(a) == "table" then
            els[#els + 1] = { tag = "accept", questId = a[1], requires = a[2], npc = s.npc }
        else
            els[#els + 1] = { tag = "accept", questId = a, npc = s.npc }
        end
    end
    if s.work then els[#els + 1] = { tag = "complete", questId = s.work } end
    for _, t in ipairs(s.turnin or {}) do els[#els + 1] = { tag = "turnin", questId = t, npc = s.npc } end
    if s.fp then els[#els + 1] = { tag = "fp", place = s.fp } end
    if s.home then els[#els + 1] = { tag = "home", place = s.home } end
    if s.manual then els[#els + 1] = { tag = "manual", text = colour(s.manual) } end
    if s.xp then els[#els + 1] = { tag = "xp", level = s.xp } end
    if s.note then els[#els + 1] = { tag = "text", text = "|cff6e98b8" .. colour(s.note) .. "|r" } end

    if s.at then
        local actionable = false
        for _, e in ipairs(els) do if e.tag ~= "text" then actionable = true end end
        -- a step that is only "go there" completes on arrival
        table.insert(els, 1, { tag = "goto", zone = map, x = s.at[1], y = s.at[2], travel = not actionable, radius = 25,
            text = not actionable and "Llegá al punto marcado" or nil })
    elseif #els == 1 and els[1].tag == "text" then
        -- plain text step: give it something to tick
        els[#els + 1] = { tag = "manual", text = "Listo" }
    end
    self.steps[#self.steps + 1] = { elements = els, only = s.only }
    return self
end

function Builder:talk(npc, where, at, t)
    t = t or {}
    t.say = t.say or ("Hablá con |cRXP_FRIENDLY_%s|r%s"):format(npc, where and (" (" .. where .. ")") or "")
    t.npc = npc
    t.at = t.at or at
    return self:step(t)
end

function Builder:work(id, text, t)
    t = t or {}
    t.work = id
    t.say = text
    return self:step(t)
end

function Builder:register()
    local m = self.meta
    local lo, hi = m.name:match("^(%d+)%-(%d+)")
    S.Engine.Register({
        id = "sxp:" .. (m.faction or "both") .. ":" .. m.name,
        name = m.name,
        group = m.group,
        subgroup = m.subgroup,
        faction = m.faction,
        map = m.map,
        next = m.next,
        minLevel = tonumber(lo),
        maxLevel = tonumber(hi),
        steps = self.steps,
    })
end
