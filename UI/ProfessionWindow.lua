-- SakedXP · Profession guide window
-- Detects your professions, shows the recipe to craft right now, the next
-- trainer rank, where to train, and a shopping list up to 300.

local _, S = ...
local C, UI = S.C, S.UI
local rgb = UI.rgb
local P = S.Professions

local PW = {}
S.ProfessionWindow = PW

local frame, listContent, detail
local rows, stepRows = {}, {}
local selectedKey

local function factionKey() return UnitFactionGroup("player") == "Horde" and "H" or "A" end

---------------------------------------------------------------------------
-- Summary used by the guide window
---------------------------------------------------------------------------
function PW.Summaries()
    local out = {}
    local skills = P.Detect()
    for _, p in ipairs(P) do
        local s = skills[p.key]
        local followed = S.cdb.professions[p.key]
        if s and (followed == nil and not p.secondary or followed) then
            local _, st = P.CurrentStep(p, s.rank)
            local tier, canTrain = P.NextTier(s.rank, s.max)
            local warn
            if s.rank >= s.max and s.max < 300 then
                warn = "¡Tope alcanzado! Entrená " .. (tier and tier.name or "el siguiente rango")
            elseif canTrain and tier and UnitLevel("player") >= tier.level then
                warn = "Ya podés entrenar " .. tier.name
            end
            out[#out + 1] = {
                prof = p, rank = s.rank, max = s.max,
                text = p.kind == "gather" and st[3] or (st[3] .. S.Color("textDim", ("  (%d-%d)"):format(st[1], st[2]))),
                warn = warn,
            }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function build()
    frame = UI.Window("SakedXPProfessions", nil, 700, 480, { strata = "HIGH", escClose = true,
        onMoved = function(f)
            local p, _, rp, x, y = f:GetPoint(1)
            S.db.profPoint = { p, "UIParent", rp, x, y }
        end })
    local pp = S.db.profPoint
    frame:SetPoint(pp[1], UIParent, pp[3], pp[4], pp[5])
    frame:Hide()
    frame.brand:SetText(S.Color("gold", "Profesiones"))
    frame.sub = UI.Text(frame.header, 11, C.textDim)
    frame.sub:SetPoint("LEFT", frame.brand, "RIGHT", 12, -1)
    frame.sub:SetText("Marcá con * las que querés seguir en la guía")

    local left = UI.Panel(frame, C.bgAlt, C.border, 0.55, 12)
    left:SetPoint("TOPLEFT", 10, -40)
    left:SetPoint("BOTTOMLEFT", 10, 10)
    left:SetWidth(220)
    local ls, lc = UI.Scroll(left)
    ls:SetPoint("TOPLEFT", 4, -4)
    ls:SetPoint("BOTTOMRIGHT", -4, 4)
    listContent = lc

    detail = UI.Panel(frame, C.bgAlt, C.border, 0.55, 12)
    detail:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    detail:SetPoint("BOTTOMRIGHT", -10, 10)
    detail.icon = UI.Icon(detail, 40)
    detail.icon:SetPoint("TOPLEFT", 14, -14)
    detail.name = UI.Text(detail, 18, C.goldSoft, { head = true })
    detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 12, -2)
    detail.skill = UI.Text(detail, 12, C.text)
    detail.skill:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
    detail.bar = UI.ProgressBar(detail, 5)
    detail.bar:SetPoint("TOPLEFT", detail.icon, "BOTTOMLEFT", 0, -10)
    detail.bar:SetPoint("RIGHT", -14, 0)
    detail.tier = UI.Text(detail, 11, C.textDim)
    detail.tier:SetPoint("TOPLEFT", detail.bar, "BOTTOMLEFT", 0, -6)
    detail.tier:SetPoint("RIGHT", -14, 0)
    detail.trainers = UI.Text(detail, 11, C.textDim, { justifyV = "TOP" })
    detail.trainers:SetPoint("TOPLEFT", detail.tier, "BOTTOMLEFT", 0, -4)
    detail.trainers:SetPoint("RIGHT", -14, 0)

    detail.tabs = UI.Tabs(detail, { "Ruta", "Lista de compras" }, function(i) PW.ShowTab(i) end)
    detail.tabs:SetPoint("TOPLEFT", 12, -132)
    detail.tabs:SetPoint("TOPRIGHT", -12, -132)

    local ds, dc = UI.Scroll(detail)
    ds:SetPoint("TOPLEFT", 12, -162)
    ds:SetPoint("BOTTOMRIGHT", -8, 8)
    detail.scroll, detail.content = ds, dc

    frame:HookScript("OnShow", function()
        PW.Render()
        C_Timer.After(0, PW.Render) -- re-layout once the scroll areas have a size
    end)
end

---------------------------------------------------------------------------
-- Left list
---------------------------------------------------------------------------
local function getRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, listContent)
    r:SetHeight(46)
    UI.Backdrop(r, C.bgRaised, C.border, 0.35, 10)
    UI.HoverFX(r, { bg = C.bgRaised, bgA = 0.35, border = C.border, borderA = 0.6,
        bgHover = C.bgRaised, bgHoverA = 0.85, borderHover = C.goldDim, borderHoverA = 0.9,
        bgSel = C.gold, bgSelA = 0.1, borderSel = C.gold, borderSelA = 0.95, glow = true, glowA = 0.22 })
    r.IsSelectedFX = function(self) return selectedKey == self.key end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(26, 26)
    r.icon:SetPoint("LEFT", 10, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = UI.Text(r, 12, C.text, { head = true })
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.rank = UI.Text(r, 10, C.textDim)
    r.rank:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
    r.bar = UI.ProgressBar(r, 3)
    r.bar:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 60, 3)
    r.bar:SetPoint("RIGHT", -30, 0)
    r.star = UI.GlyphButton(r, "*", "Seguir en la guía", 18)
    r.star:SetPoint("RIGHT", -6, 0)
    UI.SetFont(r.star.label, 18, true)
    r.star:SetScript("OnClick", function(self)
        local key = self:GetParent().key
        local cur = S.cdb.professions[key]
        local p = P.Get(key)
        local default = not p.secondary
        if cur == nil then cur = default end
        S.cdb.professions[key] = not cur
        PW.Render()
        S:Fire("PROGRESS")
    end)
    r:SetScript("OnClick", function(self) selectedKey = self.key; PW.Render() end)
    rows[i] = r
    return r
end

local function renderList(skills)
    local ordered = {}
    for _, p in ipairs(P) do if skills[p.key] then ordered[#ordered + 1] = p end end
    for _, p in ipairs(P) do if not skills[p.key] then ordered[#ordered + 1] = p end end
    if not selectedKey then selectedKey = ordered[1] and ordered[1].key end

    local y = 0
    for i, p in ipairs(ordered) do
        local r = getRow(i)
        r.key = p.key
        r.icon:SetTexture(p.icon)
        local s = skills[p.key]
        r.name:SetText(p.name)
        r.name:SetTextColor(rgb(s and C.text or C.textMute))
        r.icon:SetDesaturated(not s)
        if s then
            r.rank:SetText(("%d/%d"):format(s.rank, s.max))
            r.bar:Show()
            r.bar:SetProgress(s.rank / 300)
        else
            r.rank:SetText(p.secondary and "Secundaria" or "No aprendida")
            r.bar:Hide()
        end
        local followed = S.cdb.professions[p.key]
        if followed == nil then followed = s and not p.secondary end
        r.star.label:SetTextColor(rgb(followed and C.gold or C.textMute))
        local sel = selectedKey == p.key
        if sel ~= nil then r:RestFX() end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -y)
        r:Show()
        y = y + 50
    end
    for i = #ordered + 1, #rows do rows[i]:Hide() end
    listContent:SetHeight(y)
end

---------------------------------------------------------------------------
-- Detail
---------------------------------------------------------------------------
local function getStepRow(i)
    local r = stepRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, detail.content)
    UI.Backdrop(r, C.bgRaised, C.border, 0.35, 9)
    r.range = UI.Text(r, 11, C.goldSoft, { head = true })
    r.range:SetPoint("TOPLEFT", 10, -7)
    r.range:SetWidth(64)
    r.recipe = UI.Text(r, 12, C.text, { justifyV = "TOP" })
    r.recipe:SetPoint("TOPLEFT", 80, -7)
    r.recipe:SetPoint("RIGHT", -8, 0)
    r.mats = UI.Text(r, 11, C.textDim, { justifyV = "TOP" })
    r.mats:SetPoint("TOPLEFT", r.recipe, "BOTTOMLEFT", 0, -3)
    r.mats:SetPoint("RIGHT", -8, 0)
    stepRows[i] = r
    return r
end

local function matsText(mats)
    if not mats then return nil end
    local t = {}
    for _, m in ipairs(mats) do t[#t + 1] = m[2] .. "x " .. m[1] end
    return table.concat(t, ", ")
end

local currentTab = 1
function PW.ShowTab(i)
    currentTab = i
    local p = P.Get(selectedKey)
    if not p then return end
    local s = P.Detect()[p.key]
    local rank = s and s.rank or 0
    for _, r in ipairs(stepRows) do r:Hide() end
    if detail.shop then detail.shop:Hide() end
    local width = detail.content:GetWidth()
    if width < 100 then width = 420 end
    local y = 0

    if i == 1 then
        local curIdx = P.CurrentStep(p, rank)
        for n, st in ipairs(p.steps) do
            local r = getStepRow(n)
            r.range:SetText(("%d-%d"):format(st[1], st[2]))
            r.recipe:SetText(st[3])
            local m = matsText(st[4])
            local lines = {}
            if m then lines[#lines + 1] = m end
            if st[5] then lines[#lines + 1] = S.Color("info", st[5]) end
            r.mats:SetText(table.concat(lines, "\n"))
            local done = s and rank >= st[2]
            local current = s and n == curIdx
            r:SetBackdropColor(rgb(current and C.gold or C.bgRaised, current and 0.1 or 0.35))
            r:SetBackdropBorderColor(rgb(current and C.gold or C.border, current and 0.95 or 0.5))
            r.range:SetTextColor(rgb(done and C.textMute or current and C.gold or C.goldSoft))
            r.recipe:SetTextColor(rgb(done and C.textMute or C.text))
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", detail.content, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", detail.content, "TOPRIGHT", -2, -y)
            r.recipe:SetWidth(width - 90)
            r.mats:SetWidth(width - 90)
            local hasMats = (r.mats:GetText() or "") ~= ""
            local h = 6 + r.recipe:GetStringHeight() + 3 + (hasMats and r.mats:GetStringHeight() or 0) + 8
            r:SetHeight(math.max(26, h))
            r:Show()
            y = y + r:GetHeight() + 4
        end
    else
        if not detail.shop then
            detail.shop = UI.Text(detail.content, 12, C.text, { justifyV = "TOP" })
            detail.shop:SetPoint("TOPLEFT", 0, 0)
            detail.shop:SetSpacing(3)
        end
        detail.shop:SetWidth(width - 8)
        if p.kind == "gather" then
            detail.shop:SetText(S.Color("textDim", "Profesión de recolección: no necesita materiales. Seguí la ruta de zonas."))
        else
            local list = P.ShoppingList(p, rank)
            local lines = { S.Color("textDim", ("Materiales estimados desde %d hasta 300 (incluye ~15%% de margen):"):format(rank)), "" }
            for _, it in ipairs(list) do
                lines[#lines + 1] = S.Color("gold", "•") .. "  " .. S.Color("goldSoft", S.FormatNumber(it[2])) .. "  " .. it[1]
            end
            if #list == 0 then lines[#lines + 1] = S.Color("good", "¡Nada más que comprar!") end
            detail.shop:SetText(table.concat(lines, "\n"))
        end
        detail.shop:Show()
        y = detail.shop:GetStringHeight() + 10
    end
    detail.content:SetHeight(y + 6)
    detail.scroll:UpdateThumb()
end

function PW.Render()
    if not frame or not frame:IsShown() then return end
    local skills = P.Detect()
    renderList(skills)
    local p = P.Get(selectedKey)
    if not p then return end
    local s = skills[p.key]
    detail.icon:SetIcon(p.icon)
    detail.name:SetText(p.name)
    if s then
        detail.skill:SetText(("Habilidad %s / %d"):format(S.Color("goldSoft", s.rank), s.max))
        detail.bar:SetProgress(s.rank / 300)
        local tier, canTrain = P.NextTier(s.rank, s.max)
        if not tier then
            detail.tier:SetText(S.Color("good", "Rango máximo (Artesano) aprendido."))
        elseif UnitLevel("player") < tier.level then
            detail.tier:SetText(("Próximo rango: %s — requiere nivel %d y habilidad %d."):format(S.Color("goldSoft", tier.name), tier.level, tier.from or 0))
        elseif canTrain then
            detail.tier:SetText(S.Color("good", "¡Ya podés entrenar " .. tier.name .. "!") .. S.Color("textDim", "  Visitá a tu instructor."))
        else
            detail.tier:SetText(("Próximo rango: %s a partir de %d de habilidad."):format(S.Color("goldSoft", tier.name), tier.from or 0))
        end
    else
        detail.skill:SetText(S.Color("textDim", "No la tenés aprendida."))
        detail.bar:SetProgress(0)
        detail.tier:SetText("Combina bien con: " .. S.Color("goldSoft", p.pair or "—"))
    end
    detail.trainers:SetText(S.Color("goldDim", "Instructores: ") .. (p.trainers[factionKey()] or "—"))
    detail.tabs:Select(currentTab)
end

S:On("OPEN_PROFESSIONS", function()
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end)

for _, e in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do
    S:RegisterEvent(e, function()
        S:Debounce("skills", 0.5, function()
            PW.Render()
            S:Fire("PROGRESS")
        end)
    end)
end
