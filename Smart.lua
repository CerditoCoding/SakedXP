-- SakedXP · Smart
-- Works out where the player really is: finished steps, chains started
-- earlier, missing prerequisites, level gates. Produces alerts with
-- one-click actions (skip step, skip chain, jump ahead).

local _, S = ...
local B = S.Bridge
local Smart = {}
S.Smart = Smart

local guideIndex = {}   -- [questId] = { accept = stepIdx, turnin = stepIdx, complete = {stepIdx...} }

---------------------------------------------------------------------------
-- Quest knowledge (QuestieDB when present, Forever Dungeon Journal chains)
---------------------------------------------------------------------------
local function questInfo(id)
    return S.DB and S.DB.QuestInfo(id)
end

local function fdj()
    return _G.ForeverDungeonJournal_NS
end

function Smart.MissingPrereqs(id)
    local missing = {}
    local q = questInfo(id)
    if q then
        if q.preQuestSingle and #q.preQuestSingle > 0 then
            local any = false
            for _, pid in ipairs(q.preQuestSingle) do
                if S.IsQuestDone(pid) then any = true break end
            end
            if not any then
                missing[#missing + 1] = { id = q.preQuestSingle[1], name = S.QuestName(q.preQuestSingle[1]), oneOf = #q.preQuestSingle > 1 }
            end
        end
        for _, pid in ipairs(q.preQuestGroup or {}) do
            if not S.IsQuestDone(pid) then
                missing[#missing + 1] = { id = pid, name = S.QuestName(pid) }
            end
        end
    end
    local ns = fdj()
    local chain = ns and ns.QUEST_PREREQ_CHAINS and ns.QUEST_PREREQ_CHAINS[id]
    if chain and #missing == 0 then
        for _, link in ipairs(chain) do
            if link.id ~= id and not S.IsQuestDone(link.id) then
                missing[#missing + 1] = { id = link.id, name = link.name or S.QuestName(link.id) }
            end
        end
    end
    return missing
end

function Smart.RequiredLevel(id)
    local q = questInfo(id)
    return q and q.requiredLevel
end

-- Quests that follow `id` in its chain (Questie nextQuestInChain + guide prereqs).
function Smart.ForwardChain(id)
    local out, seen = {}, { [id] = true }
    local cur = id
    for _ = 1, 25 do
        local q = questInfo(cur)
        local nxt = q and q.nextQuestInChain
        if not nxt or nxt == 0 or seen[nxt] then break end
        seen[nxt] = true
        out[#out + 1] = nxt
        cur = nxt
    end
    -- anything in the current guide whose prerequisites hang off this chain
    local changed = true
    while changed do
        changed = false
        for qid in pairs(guideIndex) do
            if not seen[qid] then
                local q = questInfo(qid)
                if q then
                    local pre = {}
                    for _, p in ipairs(q.preQuestSingle or {}) do pre[#pre + 1] = p end
                    for _, p in ipairs(q.preQuestGroup or {}) do pre[#pre + 1] = p end
                    for _, p in ipairs(pre) do
                        if seen[p] then
                            seen[qid] = true
                            out[#out + 1] = qid
                            changed = true
                            break
                        end
                    end
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Guide index
---------------------------------------------------------------------------
function Smart.IndexGuide()
    wipe(guideIndex)
    local g = B.Guide()
    if not g or not g.steps then return end
    for i, step in ipairs(g.steps) do
        for _, e in ipairs(step.elements or {}) do
            local id, tag = e.questId, e.tag
            if id and tag then
                local entry = guideIndex[id] or {}
                guideIndex[id] = entry
                if tag == "accept" or tag == "daily" then
                    entry.accept = entry.accept or i
                elseif tag:find("turnin") then
                    entry.turnin = entry.turnin or i
                elseif tag == "complete" or tag == "isQuestNotComplete" then
                    entry.complete = entry.complete or {}
                    table.insert(entry.complete, i)
                end
            end
        end
    end
end

function Smart.StepForQuest(id, kind)
    local e = guideIndex[id]
    if not e then return end
    if kind then return type(e[kind]) == "table" and e[kind][1] or e[kind] end
    return e.accept or e.turnin or (e.complete and e.complete[1])
end

---------------------------------------------------------------------------
-- Skipping
---------------------------------------------------------------------------
local function applySkips()
    local g = B.Guide()
    if not g or not g.steps then return end
    local skipped = S.cdb.skippedQuests
    for _, step in ipairs(g.steps) do
        local touched, allQuestSkipped, hasQuest = false, true, false
        for _, e in ipairs(step.elements or {}) do
            if e.questId and e.tag then
                hasQuest = true
                if skipped[e.questId] then
                    e.skip = true
                    touched = true
                else
                    allQuestSkipped = false
                end
            end
        end
        if touched and hasQuest and allQuestSkipped then step.completed = true end
    end
end
Smart.ApplySkips = applySkips

function Smart.SkipQuests(ids, reason)
    for _, id in ipairs(ids) do S.cdb.skippedQuests[id] = true end
    applySkips()
    S.Engine.Advance()
    if reason then S.Print(reason) end
end

function Smart.SkipChain(id)
    local ids = { id }
    for _, q in ipairs(Smart.ForwardChain(id)) do ids[#ids + 1] = q end
    Smart.SkipQuests(ids, string.format("cadena saltada: %s (%d misiones).", S.Color("goldSoft", S.QuestName(id)), #ids))
end

function Smart.ClearSkips()
    wipe(S.cdb.skippedQuests)
    local g = B.Guide()
    if g and g.steps then
        for _, step in ipairs(g.steps) do
            for _, e in ipairs(step.elements or {}) do
                if e.questId then e.skip = nil end
            end
        end
    end
    S.Print("se restablecieron todas las misiones saltadas.")
    S:Fire("PROGRESS")
end

---------------------------------------------------------------------------
-- Where am I? (resync)
---------------------------------------------------------------------------
-- A step is "evidenced" when the real quest state proves the player got
-- at least that far in the guide.
local function stepEvidence(step)
    local log = S.GetQuestLogSet()
    for _, e in ipairs(step.elements or {}) do
        local id, tag = e.questId, e.tag
        if id and tag then
            if (tag == "accept" or tag == "daily") and (log[id] or S.IsQuestDone(id)) then return true end
            if tag:find("turnin") and S.IsQuestDone(id) then return true end
        end
    end
    return false
end

function Smart.FindSyncTarget()
    local g = B.Guide()
    if not g or not g.steps then return end
    local last
    for i, step in ipairs(g.steps) do
        if stepEvidence(step) then last = i end
    end
    if not last then return end
    local target = math.min(last + 1, #g.steps)
    return target, last
end

function Smart.Sync(silent)
    local cur = B.CurrentIndex()
    local target, last = Smart.FindSyncTarget()
    if not target then
        if not silent then S.Print("no encontré progreso de misiones de esta guía; seguís en el paso", cur) end
        return
    end
    if target <= cur then
        if not silent then S.Print("estás al día: paso", cur, "de", B.NumSteps()) end
        return
    end
    B.JumpTo(target)
    S.Print(string.format("sincronizado: salté del paso %d al %d (última misión detectada en el paso %d).", cur, target, last))
end
S:On("REQUEST_SYNC", function() Smart.Sync(false) end)

---------------------------------------------------------------------------
-- Alerts for the current step
---------------------------------------------------------------------------
-- Each alert: { kind, color, title, body, actions = { {label, kind, fn} } }
function Smart.Analyze()
    local alerts = {}
    -- inside a dungeon: checklist reminder comes first
    local dkey = S.Dungeon and S.Dungeon.Current()
    if dkey then
        local s = S.Dungeon.Summary(dkey)
        local parts = {}
        if s.active + s.inside > 0 then parts[#parts + 1] = ("%d misiones para hacer adentro"):format(s.active + s.inside) end
        if s.missing > 0 then parts[#parts + 1] = S.Color("bad", ("te faltan %d"):format(s.missing)) end
        if s.items > 0 then parts[#parts + 1] = S.Color("amber", ("faltan %d ítems"):format(s.items)) end
        alerts[#alerts + 1] = {
            kind = "dungeon", color = S.C.info,
            title = "Estás en " .. dkey,
            body = #parts > 0 and (table.concat(parts, " · ") .. ".") or "No tenés misiones pendientes acá.",
            actions = { { label = "Ver checklist", kind = "primary", fn = function() S.Dungeon.Open(dkey) end } },
        }
    end
    if not B.Ready() or not B.Guide() then return alerts end
    local idx = B.CurrentIndex()
    local step = B.Step(idx)
    if not step then return alerts end
    local log = S.GetQuestLogSet()
    local level = UnitLevel("player")
    local seen = {}

    for _, e in ipairs(step.elements or {}) do
        local id, tag = e.questId, e.tag
        if id and tag and not e.completed and not e.skip and not seen[id] then
            seen[id] = true
            local qname = S.QuestName(id)
            local isAccept = tag == "accept" or tag == "daily"
            local onQuest, done = log[id] ~= nil, S.IsQuestDone(id)

            if isAccept and not onQuest and not done then
                -- 1) chain already advanced past this quest?
                local ahead
                for _, nid in ipairs(Smart.ForwardChain(id)) do
                    if log[nid] or S.IsQuestDone(nid) then ahead = nid end
                end
                if ahead then
                    local target = Smart.StepForQuest(ahead, "turnin") or Smart.StepForQuest(ahead)
                    local acts = {}
                    if target and target > idx then
                        acts[#acts + 1] = { label = "Ir al paso " .. target, kind = "primary", fn = function() B.JumpTo(target) end }
                    end
                    acts[#acts + 1] = { label = "Saltar paso", kind = "ghost", fn = function() Smart.SkipQuests({ id }) end }
                    alerts[#alerts + 1] = {
                        kind = "chain", color = S.C.info,
                        title = "Ya avanzaste esta cadena",
                        body = string.format("Tenés %s, que viene después de %s.", S.Color("goldSoft", S.QuestName(ahead)), S.Color("goldSoft", qname)),
                        actions = acts,
                    }
                else
                    -- 2) prerequisites missing?
                    local missing = Smart.MissingPrereqs(id)
                    if #missing > 0 then
                        local names = {}
                        for i, m in ipairs(missing) do
                            if i > 3 then names[#names + 1] = "…" break end
                            names[#names + 1] = S.Color("goldSoft", m.name) .. (m.oneOf and " (o alternativa)" or "")
                        end
                        local acts = {}
                        local preStep = Smart.StepForQuest(missing[1].id, "accept")
                        if preStep and preStep ~= idx then
                            acts[#acts + 1] = { label = "Ir al prerrequisito (paso " .. preStep .. ")", kind = "ghost", fn = function() B.JumpTo(preStep) end }
                        end
                        acts[#acts + 1] = { label = "Saltar cadena", kind = "primary", fn = function() Smart.SkipChain(id) end }
                        acts[#acts + 1] = { label = "Saltar paso", kind = "ghost", fn = function() Smart.SkipQuests({ id }) end }
                        alerts[#alerts + 1] = {
                            kind = "prereq", color = S.C.bad,
                            title = "Falta un prerrequisito para " .. qname,
                            body = "Necesitás completar: " .. table.concat(names, ", ") .. ".",
                            actions = acts,
                        }
                    end
                    -- 3) level gate
                    local req = Smart.RequiredLevel(id)
                    if req and req > level then
                        alerts[#alerts + 1] = {
                            kind = "level", color = S.C.amber,
                            title = string.format("Nivel %d requerido", req),
                            body = string.format("%s pide nivel %d y sos %d. Matá bichos cercanos o saltá por ahora.", S.Color("goldSoft", qname), req, level),
                            actions = { { label = "Saltar por ahora", kind = "ghost", fn = function() B.Next() end } },
                        }
                    end
                end
            elseif (tag:find("turnin") or tag == "complete" or tag == "isQuestNotComplete") and not onQuest and not done then
                -- 4) asked to work on a quest you don't have
                local acceptAt = Smart.StepForQuest(id, "accept")
                local acts = {}
                if acceptAt and acceptAt < idx then
                    acts[#acts + 1] = { label = "Volver a tomarla (paso " .. acceptAt .. ")", kind = "ghost", fn = function() B.JumpTo(acceptAt) end }
                end
                acts[#acts + 1] = { label = "Saltar cadena", kind = "primary", fn = function() Smart.SkipChain(id) end }
                acts[#acts + 1] = { label = "Saltar paso", kind = "ghost", fn = function() Smart.SkipQuests({ id }) end }
                alerts[#alerts + 1] = {
                    kind = "missing", color = S.C.amber,
                    title = "No tenés esta misión",
                    body = string.format("%s no está en tu registro (¿no la tomaste o la abandonaste?).", S.Color("goldSoft", qname)),
                    actions = acts,
                }
            end
        end
    end

    -- 5) another step of the guide is right here: suggest doing it now
    local E = S.Engine
    local curMap, cx, cy = E.StepTarget(step)
    local curDist = E.TargetDistance(curMap, cx, cy)
    if curDist and curDist > 200 then
        local g = B.Guide()
        for i = idx + 1, math.min(#g.steps, idx + 10) do
            local st = g.steps[i]
            if not E.StepComplete(st) then
                local m, x, y = E.StepTarget(st)
                local d = E.TargetDistance(m, x, y)
                if d and d < 90 and d < curDist / 3 then
                    alerts[#alerts + 1] = {
                        kind = "near", color = S.C.good,
                        title = ("Tenés el paso %d acá cerca"):format(i),
                        body = ("%s  %s"):format(B.StepSummary(st), S.Color("textDim", ("(%d m · el paso actual está a %d m)"):format(d, curDist))),
                        actions = {
                            { label = "Hacerlo ahora", kind = "primary", fn = function() B.JumpTo(i) end },
                            { label = "Seguir en orden", kind = "subtle", fn = function() Smart.ignoreNear = i end },
                        },
                    }
                    if Smart.ignoreNear == i then table.remove(alerts) end
                    break
                end
            end
        end
    end

    -- 6) the guide is behind the real quest state
    local target, last = Smart.FindSyncTarget()
    if target and target > idx + 2 then
        table.insert(alerts, 1, {
            kind = "sync", color = S.C.gold,
            title = "Parece que vas más adelante",
            body = string.format("Tu registro de misiones coincide con el paso %d. Estás en el %d.", last, idx),
            actions = {
                { label = "Saltar al paso " .. target, kind = "primary", fn = function() B.JumpTo(target) end },
                { label = "Ignorar", kind = "subtle", fn = function() Smart.ignoreSyncUntil = target end },
            },
        })
        if Smart.ignoreSyncUntil and Smart.ignoreSyncUntil >= target then table.remove(alerts, 1) end
    end
    return alerts
end

S:On("GUIDE_LOADED", function()
    Smart.ignoreSyncUntil = nil
    Smart.ignoreNear = nil
    Smart.IndexGuide()
    applySkips()
end)
