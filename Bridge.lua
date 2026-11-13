-- SakedXP · Bridge
-- Thin facade the UI and Smart modules use to read and drive the SakedXP
-- engine (Engine/Engine.lua). No external guide addon is involved.

local _, S = ...
local C = S.C
local B = {}
S.Bridge = B

local function E() return S.Engine end

---------------------------------------------------------------------------
-- Step classification
---------------------------------------------------------------------------
local TYPE = {
    accept   = { icon = "Interface\\GossipFrame\\AvailableQuestIcon", label = "Aceptar misión", full = true, color = C.gold },
    turnin   = { icon = "Interface\\GossipFrame\\ActiveQuestIcon", label = "Entregar misión", full = true, color = C.goldSoft },
    complete = { icon = "Interface\\Icons\\INV_Sword_04", label = "Completar objetivos", color = C.amber },
    ["goto"] = { icon = "Interface\\Icons\\INV_Misc_Map02", label = "Desplazarse", color = C.info },
    fp       = { icon = "Interface\\Icons\\Ability_Hunter_EagleEye", label = "Ruta de vuelo", color = C.info },
    home     = { icon = "Interface\\Icons\\INV_Misc_Rune_01", label = "Fijar hogar", color = C.info },
    xp       = { icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight", label = "Subir de nivel", color = C.good },
    manual   = { icon = "Interface\\Icons\\INV_Misc_Note_01", label = "Tarea", color = C.textDim },
    default  = { icon = "Interface\\Icons\\INV_Misc_Note_01", label = "Paso", color = C.textDim },
}
B.TYPE = TYPE

local PRIORITY = { "turnin", "accept", "complete", "fp", "home", "xp", "manual", "goto" }

function B.ClassifyStep(step)
    if not step or not step.elements then return TYPE.default, "default" end
    local present = {}
    for _, e in ipairs(step.elements) do
        if e.tag and not e.completed then present[e.tag] = true end
    end
    if not next(present) then
        for _, e in ipairs(step.elements) do if e.tag then present[e.tag] = true end end
    end
    for _, t in ipairs(PRIORITY) do
        if present[t] then return TYPE[t], t end
    end
    return TYPE.default, "default"
end

function B.CleanText(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    return text
end

-- One entry per visible line of a step.
function B.StepLines(step)
    local lines = {}
    if not step or not step.elements then return lines end
    for _, e in ipairs(step.elements) do
        local text = B.CleanText(e.displayText or E().ElementText(e))
        if text and not (e.tag == "goto" and not e.travel) then
            lines[#lines + 1] = {
                text = text,
                done = e.completed and true or false,
                skipped = e.skip and true or false,
                textOnly = e.textOnly and true or false,
                questId = e.questId,
                tag = e.tag,
                element = e,
                clickable = e.tag == "manual" or e.tag == "home" or e.tag == "fp",
            }
        end
    end
    -- the waypoint label goes first, as a heading, when the step has one
    for _, e in ipairs(step.elements) do
        if e.tag == "goto" and not e.travel and e.text then
            table.insert(lines, 1, { text = e.text, textOnly = true, done = false, tag = "goto", element = e })
            break
        end
    end
    return lines
end

function B.StepSummary(step)
    local lines = B.StepLines(step)
    local pick = lines[1]
    for _, l in ipairs(lines) do
        if l.tag ~= "goto" then pick = l break end
    end
    if not pick then return "—" end
    local t = pick.text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n.*", "")
    return t
end

function B.StepWaypoint(step)
    local m, x, y = E().StepTarget(step)
    return m, x, y
end

function B.StepQuestIds(step)
    local ids = {}
    for _, e in ipairs(step and step.elements or {}) do
        if e.questId then ids[#ids + 1] = { id = e.questId, tag = e.tag, element = e } end
    end
    return ids
end

---------------------------------------------------------------------------
-- Guide access
---------------------------------------------------------------------------
function B.Ready() return true end
function B.Guide() return E().guide end
function B.CurrentIndex() return E().guide and E().current or 0 end
function B.NumSteps() local g = E().guide return g and #g.steps or 0 end
function B.Step(i) local g = E().guide return g and g.steps[i] end
function B.ActiveSteps() local st = B.Step(B.CurrentIndex()) return st and { st } or {} end

function B.GuideMeta(guide)
    guide = guide or B.Guide()
    if not guide then return end
    local name = guide.displayname or guide.name or "?"
    local lo, hi, zone = name:match("^(%d+)%-(%d+)%s+(.+)$")
    return {
        name = name,
        rawName = guide.name,
        group = guide.group,
        subgroup = guide.subgroup,
        minLevel = guide.minLevel or tonumber(lo),
        maxLevel = guide.maxLevel or tonumber(hi),
        zone = zone or name,
        next = guide.next,
        key = guide.id,
        map = guide.map,
        dynamic = guide.dynamic,
    }
end

function B.SetStep(n) E().SetStep(n) end
function B.Next() E().SetStep(B.CurrentIndex() + 1) end
function B.Prev() E().SetStep(B.CurrentIndex() - 1) end
function B.JumpTo(n) E().SetStep(n) end

-- value = { kind = "guide", id = ... } | { kind = "dynamic", map = ... }
function B.LoadGuide(value)
    if not value then return false end
    if value.kind == "dynamic" then
        return S.Generator.Start(value.map, false)
    end
    return E().Load(value.id)
end

function B.SearchGuides(needle, groupFilter)
    local out = {}
    needle = needle and needle:lower()
    for _, g in ipairs(E().List()) do
        if (not groupFilter or (g.group or ""):find(groupFilter, 1, true)) and
           (not needle or g.name:lower():find(needle, 1, true)) then
            out[#out + 1] = { group = g.group or "SakedXP", name = g.name, id = g.id, kind = "guide" }
        end
    end
    table.sort(out, function(a, b)
        local la = tonumber(a.name:match("^(%d+)")) or 999
        local lb = tonumber(b.name:match("^(%d+)")) or 999
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return out
end

-- Kept for callers from the RXP era; nothing to hide any more.
function B.ApplyRXPVisibility() end
