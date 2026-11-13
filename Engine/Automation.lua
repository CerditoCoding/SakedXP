-- SakedXP · Quest automation
-- Auto-accepts and auto-turns-in the quests of the current step (and of the
-- next few steps). Hold Shift while talking to an NPC to do it manually.
-- Quest rewards with a choice are always left to the player.

local _, S = ...
local E = S.Engine
local A = {}
S.Automation = A

local LOOKAHEAD = 6

-- quests the guide wants accepted / turned in soon
local function wanted(tag)
    local set = {}
    local g = E.guide
    if not g then return set end
    for i = E.current, math.min(#g.steps, E.current + LOOKAHEAD) do
        for _, e in ipairs(g.steps[i].elements) do
            if e.questId and not e.skip and (e.tag == tag) then set[e.questId] = true end
        end
    end
    return set
end

local function wantedByName(tag)
    local set = {}
    for id in pairs(wanted(tag)) do set[E.QuestName(id)] = id end
    return set
end

local function enabled(kind)
    if IsShiftKeyDown() then return false end
    return kind == "accept" and S.db.autoAccept or kind == "turnin" and S.db.autoTurnin
end

---------------------------------------------------------------------------
-- Gossip / greeting: pick the right quest from the NPC's list
---------------------------------------------------------------------------
local function handleGossip()
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        if enabled("turnin") then
            local want = wanted("turnin")
            for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
                if q.isComplete and want[q.questID] then
                    C_GossipInfo.SelectActiveQuest(q.questID)
                    return
                end
            end
        end
        if enabled("accept") then
            local want = wanted("accept")
            for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
                if want[q.questID] then
                    C_GossipInfo.SelectAvailableQuest(q.questID)
                    return
                end
            end
        end
    end
end

local function handleGreeting()
    if enabled("turnin") and GetNumActiveQuests then
        local want = wantedByName("turnin")
        for i = 1, GetNumActiveQuests() do
            local title, complete = GetActiveTitle(i)
            if want[title] and complete ~= false then SelectActiveQuest(i) return end
        end
    end
    if enabled("accept") and GetNumAvailableQuests then
        local want = wantedByName("accept")
        for i = 1, GetNumAvailableQuests() do
            if want[GetAvailableTitle(i)] then SelectAvailableQuest(i) return end
        end
    end
end

S:RegisterEvent("GOSSIP_SHOW", handleGossip)
S:RegisterEvent("QUEST_GREETING", handleGreeting)

---------------------------------------------------------------------------
-- Quest frames
---------------------------------------------------------------------------
S:RegisterEvent("QUEST_DETAIL", function()
    if not enabled("accept") then return end
    local id = GetQuestID and GetQuestID()
    if id and wanted("accept")[id] then AcceptQuest() end
end)

S:RegisterEvent("QUEST_PROGRESS", function()
    if not enabled("turnin") then return end
    local id = GetQuestID and GetQuestID()
    if id and wanted("turnin")[id] and IsQuestCompletable() then CompleteQuest() end
end)

S:RegisterEvent("QUEST_COMPLETE", function()
    if not enabled("turnin") then return end
    local id = GetQuestID and GetQuestID()
    if not (id and wanted("turnin")[id]) then return end
    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if choices <= 1 then
        GetQuestReward(choices == 1 and 1 or 0)
    else
        S.Print("elegí tu recompensa:", S.Color("goldSoft", E.QuestName(id)))
    end
end)
