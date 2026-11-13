-- SakedXP · Guide window
-- One glance answers "where am I and what do I do now": guide, progress,
-- alerts with actions, the current step in large type, and what comes next.

local _, S = ...
local C, UI, B = S.C, S.UI, S.Bridge
local rgb = UI.rgb

local W = {}
S.GuideWindow = W

local PAD = 12
local frame, content, scroll
local pools = { lines = {}, alerts = {}, upcoming = {}, sticky = {} }

---------------------------------------------------------------------------
-- Small widgets
---------------------------------------------------------------------------
local function sectionLabel(parent, text)
    local fs = UI.Text(parent, 9, C.goldDim, { head = true })
    fs:SetText(text:upper())
    return fs
end

-- rounded vertical accent bar inside a card (SetVertexColor like a texture)
local function accentBar(parent)
    local host = CreateFrame("Frame", nil, parent)
    host:SetWidth(3)
    host:SetPoint("TOPLEFT", 7, -10)
    host:SetPoint("BOTTOMLEFT", 7, 10)
    local layer = UI.RoundLayer(host, "round", 1.5, "ARTWORK")
    function host:SetVertexColor(r, g, b, a) layer:SetColor(r, g, b, a) end
    return host
end

-- card colours: translucent surface, colour-tinted border + soft glow
local function tintCard(card, color)
    card:SetBackdropColor(rgb(C.bgAlt, 0.62))
    card:SetBackdropBorderColor(rgb(color, 0.55))
    if card.__glow then card.__glow:SetColor(rgb(color, 0.16)) end
end

local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local SKIP = "Interface\\RaidFrame\\ReadyCheck-NotReady"

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function savePosition(f)
    local p, _, rp, x, y = f:GetPoint(1)
    S.db.point = { p, "UIParent", rp, x, y }
end

local function build()
    frame = UI.Window("SakedXPFrame", nil, S.db.width, 200, { lockKey = "locked", onMoved = savePosition })
    frame:SetScale(S.db.scale)
    frame:ClearAllPoints()
    local p = S.db.point
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(280, 120, 640, 1200)
    elseif frame.SetMinResize then
        frame:SetMinResize(280, 120)
        frame:SetMaxResize(640, 1200)
    end
    frame.closeButton:SetScript("OnClick", function() W.Hide() end)

    -- header buttons
    local h = frame.header
    local collapse = UI.GlyphButton(h, "-", "Contraer / expandir")
    collapse:SetPoint("RIGHT", frame.closeButton, "LEFT", -2, 0)
    collapse:SetScript("OnClick", function()
        S.db.collapsed = not S.db.collapsed
        W.Refresh()
    end)
    frame.collapseButton = collapse

    local settings = UI.IconButton(h, "Interface\\Icons\\INV_Misc_Gear_01", "Opciones")
    settings:SetPoint("RIGHT", collapse, "LEFT", -6, 0)
    settings:SetScript("OnClick", function() S:Fire("OPEN_SETTINGS") end)

    local prof = UI.IconButton(h, "Interface\\Icons\\Trade_BlackSmithing", "Guía de profesiones")
    prof:SetPoint("RIGHT", settings, "LEFT", -6, 0)
    prof:SetScript("OnClick", function() S:Fire("OPEN_PROFESSIONS") end)

    local zones = UI.IconButton(h, "Interface\\Icons\\INV_Misc_Map_01", "Elegir próxima zona")
    zones:SetPoint("RIGHT", prof, "LEFT", -6, 0)
    zones:SetScript("OnClick", function() S:Fire("OPEN_ZONE_PICKER", "manual") end)

    -- body
    scroll, content = UI.Scroll(frame)
    scroll:SetPoint("TOPLEFT", 0, -34)
    scroll:SetPoint("BOTTOMRIGHT", 0, 26)

    -- guide title row
    content.guideTitle = CreateFrame("Button", nil, content)
    content.guideTitle:SetHeight(18)
    content.guideText = UI.Text(content.guideTitle, 14, C.goldSoft, { head = true, wrap = false })
    content.guideText:SetPoint("LEFT", 0, 0)
    content.guideText:SetPoint("RIGHT", 0, 0)
    content.guideTitle:SetScript("OnClick", function(self) W.OpenGuideMenu(self) end)
    UI.Tooltip(content.guideTitle, "Cambiar de guía", "Clic para ver las otras guías de este grupo.")

    content.levelPill = UI.Pill(content, "", C.goldDim)
    content.groupText = UI.Text(content, 10, C.textDim, { wrap = false })

    content.progress = UI.ProgressBar(content, 6)
    content.progressLeft = UI.Text(content, 10, C.text)
    content.progressRight = UI.Text(content, 10, C.textDim, { justify = "RIGHT" })

    -- current step card
    local card = UI.Panel(content, C.bgAlt, C.border, 0.62, 12)
    UI.Glow(card, C.gold, 12)
    content.card = card
    card.stripe = accentBar(card)
    card.label = sectionLabel(card, "Paso actual")
    card.label:SetPoint("TOPLEFT", 18, -10)
    card.typeText = UI.Text(card, 9, C.gold, { head = true, justify = "RIGHT" })
    card.typeText:SetPoint("TOPRIGHT", -12, -10)
    card.icon = UI.Icon(card, 34)
    card.icon:SetPoint("TOPLEFT", 18, -26)
    card.waypoint = CreateFrame("Button", nil, card)
    card.waypoint:SetHeight(16)
    card.waypointText = UI.Text(card.waypoint, 10, C.info)
    card.waypointText:SetPoint("LEFT", 0, 0)
    card.waypoint:SetScript("OnClick", function() W.OpenMapForStep() end)
    UI.Tooltip(card.waypoint, "Abrir mapa", "Muestra el mapa de la zona del objetivo.")

    -- controls
    content.prev = UI.Button(content, "< Anterior", "subtle", 80, 22)
    content.prev:SetScript("OnClick", function() B.Prev() end)
    content.skip = UI.Button(content, "Saltar paso >", "ghost", 100, 22)
    content.skip:SetScript("OnClick", function() B.Next() end)
    UI.Tooltip(content.skip, "Saltar paso", "Marca este paso como hecho y pasa al siguiente.")
    content.sync = UI.Button(content, "Sincronizar", "subtle", 84, 22)
    content.sync:SetScript("OnClick", function()
        local g = B.Guide()
        if g and g.dynamic then S:Fire("REGENERATE") else S.Smart.Sync(false) end
    end)
    UI.Tooltip(content.sync,
        function() local g = B.Guide() return g and g.dynamic and "Regenerar ruta" or "¿En qué paso estoy?" end,
        function() local g = B.Guide()
            return g and g.dynamic and "Vuelve a calcular la ruta con tu nivel, posición y registro de misiones actuales."
                or "Revisa tu registro de misiones y salta al paso que corresponde." end)

    content.stickyLabel = sectionLabel(content, "En paralelo")
    content.nextLabel = sectionLabel(content, "A continuación")

    -- empty state
    content.empty = UI.Text(content, 12, C.textDim, { justify = "CENTER" })
    content.emptyButton = UI.Button(content, "Elegir zona", "primary", 160, 24)
    content.emptyButton:SetScript("OnClick", function() S:Fire("OPEN_ZONE_PICKER", "manual") end)
    content.hereButton = UI.Button(content, "Ruta de esta zona", "ghost", 160, 24)
    content.hereButton:SetScript("OnClick", function() S:Fire("REGENERATE") end)

    -- footer: level / xp
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", PAD, 6)
    footer:SetPoint("BOTTOMRIGHT", -PAD - 10, 6)
    footer:SetHeight(16)
    frame.xpBar = UI.ProgressBar(footer, 3, C.goldDim, C.gold)
    frame.xpBar:SetPoint("TOPLEFT", 0, 0)
    frame.xpBar:SetPoint("TOPRIGHT", 0, 0)
    frame.xpText = UI.Text(footer, 10, C.textDim)
    frame.xpText:SetPoint("BOTTOMLEFT", 0, 0)
    frame.xpText:SetPoint("BOTTOMRIGHT", 0, 0)

    -- resize grip (width; height follows content up to the saved max)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    local gt = grip:CreateTexture(nil, "OVERLAY")
    gt:SetAllPoints()
    gt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gt:SetVertexColor(rgb(C.goldDim))
    grip:SetScript("OnMouseDown", function()
        if S.db.locked then return end
        frame:StartSizing("BOTTOMRIGHT")
        frame.sizing = true
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        frame.sizing = false
        S.db.width = math.floor(frame:GetWidth())
        S.db.height = math.floor(frame:GetHeight())
        savePosition(frame)
        W.Refresh()
    end)
    frame:SetScript("OnSizeChanged", function()
        if frame.sizing then W.Refresh(true) end
    end)

    frame:HookScript("OnShow", function() W.Refresh() end)
end

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------
local function getLine(i)
    local l = pools.lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, content.card)
    l.mark = l:CreateTexture(nil, "ARTWORK")
    l.mark:SetSize(12, 12)
    l.mark:SetPoint("TOPLEFT", 0, -2)
    l.dot = l:CreateTexture(nil, "ARTWORK")
    l.dot:SetTexture(UI.WHITE)
    l.dot:SetSize(5, 5)
    l.dot:SetPoint("TOPLEFT", 4, -6)
    l.text = UI.Text(l, 13, C.text, { justifyV = "TOP" })
    l.text:SetPoint("TOPLEFT", 18, 0)
    l.text:SetPoint("TOPRIGHT", 0, 0)
    l.text:SetSpacing(2)
    -- manual tasks ("conseguí la ruta de vuelo", "fijá tu hogar"...) are ticked by clicking
    l:EnableMouse(true)
    l:SetScript("OnMouseUp", function(self)
        if self.ln and self.ln.clickable then S.Engine.ToggleManual(self.ln.element) end
    end)
    l:SetScript("OnEnter", function(self)
        if not (self.ln and self.ln.clickable) then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Clic para marcar como hecho / deshacer", rgb(C.goldSoft))
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pools.lines[i] = l
    return l
end

local function getAlert(i)
    local a = pools.alerts[i]
    if a then return a end
    a = UI.Panel(content, C.bgAlt, C.border, 0.62, 10)
    a.stripe = accentBar(a)
    a.title = UI.Text(a, 11, C.text, { head = true })
    a.title:SetPoint("TOPLEFT", 16, -9)
    a.body = UI.Text(a, 12, C.text, { justifyV = "TOP" })
    a.body:SetPoint("TOPLEFT", a.title, "BOTTOMLEFT", 0, -4)
    a.buttons = {}
    pools.alerts[i] = a
    return a
end

local function getUpcoming(i)
    local r = pools.upcoming[i]
    if r then return r end
    r = CreateFrame("Button", nil, content)
    r:SetHeight(24)
    UI.Backdrop(r, C.bgRaised, C.border, 0, 8)
    r:SetBackdropBorderColor(rgb(C.border, 0))
    UI.HoverFX(r, { bg = C.bgRaised, bgA = 0, border = C.border, borderA = 0,
        bgHover = C.bgRaised, bgHoverA = 0.75, borderHover = C.goldDim, borderHoverA = 0.7 })
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 6, 0)
    r.num = UI.Text(r, 10, C.textMute, { justify = "RIGHT" })
    r.num:SetPoint("RIGHT", -6, 0)
    r.num:SetWidth(30)
    r.text = UI.Text(r, 11, C.textDim, { wrap = false })
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", r.num, "LEFT", -4, 0)
    r:HookScript("OnEnter", function(self)
        self.text:SetTextColor(rgb(C.text))
        if not self.step then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Paso " .. (self.step.index or "?"), rgb(C.goldSoft))
        for _, l in ipairs(B.StepLines(self.step)) do
            GameTooltip:AddLine(l.text, C.text[1], C.text[2], C.text[3], true)
        end
        GameTooltip:AddLine("Clic para saltar a este paso", rgb(C.textDim))
        GameTooltip:Show()
    end)
    r:HookScript("OnLeave", function(self)
        self.text:SetTextColor(rgb(C.textDim))
        GameTooltip:Hide()
    end)
    r:SetScript("OnClick", function(self)
        if self.step and self.step.index then B.JumpTo(self.step.index) end
    end)
    pools.upcoming[i] = r
    return r
end

local function getSticky(i)
    local r = pools.sticky[i]
    if r then return r end
    r = CreateFrame("Frame", nil, content)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetTexture(UI.WHITE)
    r.bar:SetVertexColor(rgb(C.goldDim))
    r.bar:SetPoint("TOPLEFT", 0, 0)
    r.bar:SetPoint("BOTTOMLEFT", 0, 0)
    r.bar:SetWidth(2)
    r.text = UI.Text(r, 11, C.text, { justifyV = "TOP" })
    r.text:SetPoint("TOPLEFT", 8, 0)
    r.text:SetPoint("TOPRIGHT", 0, 0)
    pools.sticky[i] = r
    return r
end

local function hideFrom(pool, n)
    for i = n, #pool do pool[i]:Hide() end
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------
local function place(widget, y, height, indent)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + (indent or 0), -y)
    widget:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -y)
    if height then widget:SetHeight(height) end
    widget:Show()
    return y + (height or widget:GetHeight())
end

local function renderAlerts(y, width)
    local alerts = S.db.smartAlerts and S.Smart.Analyze() or {}
    for i, al in ipairs(alerts) do
        local a = getAlert(i)
        a.stripe:SetVertexColor(rgb(al.color or C.gold))
        tintCard(a, al.color or C.gold)
        a.title:SetWidth(width - 20)
        a.title:SetText(al.title)
        a.title:SetTextColor(rgb(al.color or C.goldSoft))
        a.body:SetWidth(width - 20)
        a.body:SetText(al.body or "")
        local h = 9 + a.title:GetStringHeight() + 4 + a.body:GetStringHeight() + 10
        -- buttons (wrap to rows)
        for _, b in pairs(a.buttons) do b:Hide() end
        local bx, by, rowH = 16, h, 22
        for j, act in ipairs(al.actions or {}) do
            local key = j .. (act.kind or "ghost")
            local b = a.buttons[key]
            if not b then
                b = UI.Button(a, "", act.kind or "ghost", 60, 20)
                a.buttons[key] = b
            end
            b:SetLabel(act.label)
            b:FitWidth(16)
            if bx + b:GetWidth() > width - 8 then bx = 16; by = by + rowH + 4 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", a, "TOPLEFT", bx, -by)
            b:SetScript("OnClick", function() act.fn(); W.Refresh() end)
            b:Show()
            bx = bx + b:GetWidth() + 6
        end
        if al.actions and #al.actions > 0 then h = by + rowH + 8 end
        y = place(a, y, h) + 6
    end
    hideFrom(pools.alerts, #alerts + 1)
    return y
end

local function renderCard(y, width, step)
    local card = content.card
    local info, kind = B.ClassifyStep(step)
    card.stripe:SetVertexColor(rgb(info.color or C.gold))
    tintCard(card, info.color or C.gold)
    card.typeText:SetText(info.label:upper())
    card.typeText:SetTextColor(rgb(info.color or C.gold))
    card.icon:SetIcon(info.icon, info.full)
    card.icon:SetBackdropBorderColor(rgb(info.color or C.goldDim, 0.9))
    card.label:SetText(("Paso actual · %d"):format(step.index or B.CurrentIndex()))

    local lines = B.StepLines(step)
    local textLeft = 18 + 34 + 10
    local ly = 24
    local textWidth = width - textLeft - 10
    for i, ln in ipairs(lines) do
        local row = getLine(i)
        row.ln = ln
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card, "TOPLEFT", textLeft, -ly)
        row:SetWidth(textWidth)
        row.text:SetWidth(textWidth - 18)
        row.text:SetText(ln.text)
        if ln.done then
            row.mark:SetTexture(CHECK); row.mark:Show(); row.dot:Hide()
            row.text:SetTextColor(rgb(C.textMute))
        elseif ln.skipped then
            row.mark:SetTexture(SKIP); row.mark:Show(); row.dot:Hide()
            row.text:SetTextColor(rgb(C.textMute))
        else
            row.mark:Hide(); row.dot:Show()
            row.dot:SetVertexColor(rgb(ln.clickable and C.info or ln.textOnly and C.textDim or C.gold))
            row.text:SetTextColor(rgb(ln.tag == "goto" and C.goldSoft or C.text))
        end
        local h = math.max(16, row.text:GetStringHeight() + 2)
        row:SetHeight(h)
        row:Show()
        ly = ly + h + 6
    end
    hideFrom(pools.lines, #lines + 1)

    local zone, x, wy = B.StepWaypoint(step)
    if zone then
        local mi = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(zone)
        card.waypointText:SetText(("> %s  %.1f, %.1f"):format(mi and mi.name or "Mapa", x, wy))
        card.waypoint:ClearAllPoints()
        card.waypoint:SetPoint("TOPLEFT", card, "TOPLEFT", textLeft, -ly)
        card.waypoint:SetWidth(textWidth)
        card.waypoint:Show()
        card.waypoint.zone = zone
        ly = ly + 18
    else
        card.waypoint:Hide()
    end
    local h = math.max(ly + 6, 24 + 34 + 12)
    return place(card, y, h) + 8
end

local function renderSticky(y, width, current)
    local n = 0
    for _, st in ipairs(B.ActiveSteps()) do
        if st ~= current and not st.tip and st.index then
            local lines = B.StepLines(st)
            local pending = {}
            for _, l in ipairs(lines) do
                if not l.done and not l.skipped then pending[#pending + 1] = l.text end
            end
            if #pending > 0 then
                n = n + 1
                if n == 1 then
                    y = place(content.stickyLabel, y, 12) + 4
                end
                local r = getSticky(n)
                r.text:SetWidth(width - 8)
                r.text:SetText(table.concat(pending, "\n"))
                y = place(r, y, r.text:GetStringHeight() + 2) + 6
            end
        end
    end
    if n == 0 then content.stickyLabel:Hide() end
    hideFrom(pools.sticky, n + 1)
    return y + (n > 0 and 4 or 0)
end

local function renderUpcoming(y, idx, count)
    count = count or S.db.upcoming or 3
    local g = B.Guide()
    local shown = 0
    if count > 0 and g and g.steps then
        local i = idx + 1
        while shown < count and i <= #g.steps do
            local st = g.steps[i]
            if st and not st.completed and not st.sticky then
                shown = shown + 1
                if shown == 1 then y = place(content.nextLabel, y, 12) + 2 end
                local r = getUpcoming(shown)
                r.step = st
                local info = B.ClassifyStep(st)
                r.icon:SetTexture(info.icon)
                if info.full then r.icon:SetTexCoord(0, 1, 0, 1) else r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                r.text:SetText(B.StepSummary(st))
                r.num:SetText(i)
                y = place(r, y, 22)
            end
            i = i + 1
        end
    end
    if shown == 0 then content.nextLabel:Hide() end
    hideFrom(pools.upcoming, shown + 1)
    return y
end

---------------------------------------------------------------------------
-- Quests that lead to other zones (optional, folded by default)
---------------------------------------------------------------------------
pools.out = {}
local function xpColor(pct)
    if pct >= 0.08 then return C.good elseif pct >= 0.04 then return C.goldSoft end
    return C.textDim
end

local function outRow(i)
    local r = pools.out[i]
    if r then return r end
    r = CreateFrame("Button", nil, content)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    UI.Backdrop(r, C.bgRaised, C.border, 0, 8)
    r:SetBackdropBorderColor(rgb(C.border, 0))
    UI.HoverFX(r, { bg = C.bgRaised, bgA = 0, border = C.border, borderA = 0,
        bgHover = C.bgRaised, bgHoverA = 0.8, borderHover = C.info, borderHoverA = 0.7, glow = true, glowColor = C.info, glowA = 0.2 })
    r.name = UI.Text(r, 12, C.text, { wrap = false })
    r.name:SetPoint("TOPLEFT", 8, -5)
    r.xp = UI.Text(r, 11, C.good, { head = true, justify = "RIGHT" })
    r.xp:SetPoint("TOPRIGHT", -8, -5)
    r.name:SetPoint("RIGHT", r.xp, "LEFT", -6, 0)
    r.sub = UI.Text(r, 10, C.textDim, { wrap = false })
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.sub:SetPoint("RIGHT", -8, 0)
    r:SetScript("OnClick", function(self, btn)
        if not self.o then return end
        if btn == "RightButton" then
            S.cdb.hiddenOutbound[self.o.quest] = true
            S.Generator.InvalidateOutbound()
            S.Print("oculta:", S.Color("goldSoft", self.o.name))
        else
            S.Generator.AddOutboundToRoute(self.o)
        end
        W.Refresh()
    end)
    r:HookScript("OnEnter", function(self)
        local o = self.o
        if not o then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(o.name, rgb(C.goldSoft))
        GameTooltip:AddLine(("Se toma acá con %s y te lleva a %s."):format(o.giver or "?", o.destName), C.text[1], C.text[2], C.text[3], true)
        if o.nextZone then GameTooltip:AddLine("Esa zona es una de tus próximas recomendadas: sirve para encadenar.", rgb(C.good)) end
        if o.breadcrumb then GameTooltip:AddLine("Es una misión de traslado: abre una cadena en el destino.", rgb(C.info)) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Esta misión", S.FormatNumber(o.xp) .. " XP", C.textDim[1], C.textDim[2], C.textDim[3], 1, 1, 1)
        if o.chainLen > 1 then
            GameTooltip:AddDoubleLine(("Cadena completa (%d misiones)"):format(o.chainLen), S.FormatNumber(o.chainXP) .. " XP",
                C.textDim[1], C.textDim[2], C.textDim[3], 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("De tu nivel actual", ("%d%%"):format(o.pct * 100 + 0.5), C.textDim[1], C.textDim[2], C.textDim[3], rgb(xpColor(o.pct)))
        if o.reward then
            GameTooltip:AddDoubleLine("Mejor recompensa", type(o.reward) == "string" and o.reward or ("ítem #" .. o.reward),
                C.textDim[1], C.textDim[2], C.textDim[3], 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Clic: agregar a la ruta  ·  Clic derecho: ocultar", rgb(C.textDim))
        GameTooltip:Show()
    end)
    r:HookScript("OnLeave", function() GameTooltip:Hide() end)
    pools.out[i] = r
    return r
end

local function renderOutbound(y, width)
    if not content.outHead then
        local h = CreateFrame("Button", nil, content)
        h:SetHeight(20)
        h.label = UI.Text(h, 9, C.info, { head = true })
        h.label:SetPoint("LEFT", 0, 0)
        h.best = UI.Text(h, 10, C.textDim, { justify = "RIGHT" })
        h.best:SetPoint("RIGHT", 0, 0)
        h:SetScript("OnClick", function()
            S.db.outboundOpen = not S.db.outboundOpen
            W.Refresh()
        end)
        UI.Tooltip(h, "Misiones que te llevan a otra zona",
            "Se toman acá pero se hacen en otra zona. Sirven para encadenar zonas: elegí las que te convengan.")
        content.outHead = h
    end
    local h = content.outHead
    local g = B.Guide()
    local map = (g and g.map) or S.DB.PlayerPos()
    local list = (S.Generator and map) and S.Generator.Outbound(map) or {}
    if #list == 0 then h:Hide(); hideFrom(pools.out, 1); return y end

    local open = S.db.outboundOpen
    h.label:SetText(((open and "v  " or ">  ") .. "OTRAS ZONAS · %d %s"):format(#list, #list == 1 and "misión" or "misiones"))
    local top = list[1]
    h.best:SetText(open and "" or (S.Color("textDim", "mejor ") .. S.Color(top.pct >= 0.08 and "good" or "goldSoft",
        "+" .. S.FormatNumber(top.chainXP) .. " XP") .. S.Color("textDim", " · " .. top.destName)))
    y = place(h, y + 4, 20) + 2
    if not open then hideFrom(pools.out, 1); return y end

    local shown = math.min(#list, 6)
    for i = 1, shown do
        local o = list[i]
        local r = outRow(i)
        r.o = o
        r.name:SetText(o.name)
        r.xp:SetText("+" .. S.FormatNumber(o.chainXP) .. " XP")
        r.xp:SetTextColor(rgb(xpColor(o.pct)))
        local parts = { S.Color("info", "> " .. o.destName) }
        if o.nextZone then parts[#parts + 1] = S.Color("good", "siguiente zona") end
        if o.chainLen > 1 then parts[#parts + 1] = ("cadena de %d"):format(o.chainLen) end
        parts[#parts + 1] = ("%d%% de nivel"):format(o.pct * 100 + 0.5)
        if o.reward then
            parts[#parts + 1] = type(o.reward) == "string" and o.reward or "recompensa de equipo"
        end
        r.sub:SetText(table.concat(parts, S.Color("textMute", "  ·  ")))
        y = place(r, y, 38) + 3
    end
    hideFrom(pools.out, shown + 1)
    return y
end

pools.profs = {}
local function renderProfessions(y, width)
    local list = (S.db.showProfessions ~= false and S.ProfessionWindow) and S.ProfessionWindow.Summaries() or {}
    if not content.profLabel then content.profLabel = sectionLabel(content, "Profesiones") end
    if #list == 0 then content.profLabel:Hide(); hideFrom(pools.profs, 1); return y end
    y = place(content.profLabel, y + 6, 12) + 2
    for i, s in ipairs(list) do
        local r = pools.profs[i]
        if not r then
            r = CreateFrame("Button", nil, content)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(14, 14)
            r.icon:SetPoint("TOPLEFT", 2, -2)
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.text = UI.Text(r, 11, C.text, { justifyV = "TOP" })
            r.text:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 1)
            r:SetScript("OnClick", function() S:Fire("OPEN_PROFESSIONS") end)
            pools.profs[i] = r
        end
        r.icon:SetTexture(s.prof.icon)
        r.text:SetWidth(width - 24)
        local t = S.Color("goldSoft", s.prof.name) .. S.Color("textDim", (" %d/%d  "):format(s.rank, s.max)) .. s.text
        if s.warn then t = t .. "\n" .. S.Color("amber", s.warn) end
        r.text:SetText(t)
        y = place(r, y, math.max(18, r.text:GetStringHeight() + 4)) + 2
    end
    hideFrom(pools.profs, #list + 1)
    return y
end

local function renderXP()
    local level = UnitLevel("player")
    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    if level >= maxLevel then
        frame.xpBar:SetProgress(1)
        frame.xpText:SetText(S.Color("goldSoft", "Nivel " .. level) .. S.Color("textDim", " · nivel máximo"))
        return
    end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    frame.xpBar:SetProgress(max > 0 and cur / max or 0)
    local txt = S.Color("goldSoft", "Nivel " .. level) ..
        S.Color("textDim", ("  ·  %d%%  ·  %s XP para %d"):format(max > 0 and cur / max * 100 or 0, S.FormatNumber(max - cur), level + 1))
    if rested and rested > 0 then txt = txt .. S.Color("info", "  ·  descansado " .. S.FormatNumber(rested)) end
    frame.xpText:SetText(txt)
end

-- one failing section must not blank the whole window
local function safe(fn, fallback, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res or fallback end
    S.Error(res)
    return fallback
end

local function hideBody()
    for _, k in ipairs({ "card", "prev", "skip", "sync", "stickyLabel", "nextLabel", "empty", "emptyButton", "hereButton", "guideTitle", "levelPill", "groupText", "progress", "progressLeft", "progressRight" }) do
        content[k]:Hide()
    end
    hideFrom(pools.alerts, 1); hideFrom(pools.upcoming, 1); hideFrom(pools.sticky, 1); hideFrom(pools.profs, 1)
    if content.profLabel then content.profLabel:Hide() end
    if content.outHead then content.outHead:Hide() end
    hideFrom(pools.out, 1)
end

function W.Refresh(immediate)
    if not frame or not frame:IsShown() then return end
    if not immediate then
        return S:Debounce("render", 0.03, function() W.Refresh(true) end)
    end
    frame:SetAlpha(1)
    frame:SetBackdropColor(rgb(C.bg, S.db.alpha))
    local width = frame:GetWidth() - PAD * 2 - 8
    content:SetWidth(frame:GetWidth() - 8)
    hideBody()
    safe(renderXP, 0)
    frame.collapseButton.label:SetText(S.db.collapsed and "+" or "-")

    local guide = B.Ready() and B.Guide()
    local y = 8
    if not guide or not guide.steps or #guide.steps == 0 then
        content.empty:SetWidth(width)
        local hasDB = S.DB.Ready()
        content.empty:SetText("No hay ninguna guía cargada." ..
            (hasDB and "\nGenerá la ruta de esta zona o elegí otra." or
             "\n" .. S.Color("amber", "Activá el addon QuestieDB para las rutas automáticas.") .. "\nMientras tanto podés usar las guías escritas."))
        y = place(content.empty, y + 10, content.empty:GetStringHeight() + 4) + 12
        content.emptyButton:ClearAllPoints()
        content.emptyButton:SetPoint("TOP", content, "TOP", 0, -y)
        content.emptyButton:Show()
        y = y + 30
        if hasDB then
            content.hereButton:ClearAllPoints()
            content.hereButton:SetPoint("TOP", content, "TOP", 0, -y)
            content.hereButton:Show()
            y = y + 30
        end
        W.FitHeight(y + 4)
        return
    end

    local meta = B.GuideMeta(guide)
    local idx = B.CurrentIndex()
    local total = #guide.steps
    local step = guide.steps[idx]

    -- guide title + level pill
    content.guideText:SetText(meta.name .. S.Color("goldDim", "  v"))
    content.levelPill:Set("Nv " .. UnitLevel("player"),
        (meta.minLevel and UnitLevel("player") < meta.minLevel) and C.bad or
        (meta.maxLevel and UnitLevel("player") > meta.maxLevel + 1) and C.info or C.goldDim)
    content.levelPill:ClearAllPoints()
    content.levelPill:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -y - 1)
    content.levelPill:Show()
    content.guideTitle:ClearAllPoints()
    content.guideTitle:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
    content.guideTitle:SetPoint("TOPRIGHT", content.levelPill, "TOPLEFT", -8, 1)
    content.guideTitle:Show()
    y = y + 20
    local groupLine = (meta.group or "") .. (meta.subgroup and ("  ·  " .. meta.subgroup) or "")
    content.groupText:SetText(groupLine)
    y = place(content.groupText, y, 12) + 8

    -- progress
    local pct = total > 0 and (idx - 1) / total or 0
    content.progress:SetProgress(pct)
    y = place(content.progress, y, 6) + 4
    content.progressLeft:SetText(("Paso %s de %d"):format(S.Color("goldSoft", idx), total))
    content.progressRight:SetText(("%d%%  ·  faltan %d"):format(pct * 100, math.max(0, total - idx)))
    place(content.progressLeft, y, 12)
    y = place(content.progressRight, y, 12) + 10

    if S.db.collapsed then
        if step then
            content.empty:SetWidth(width)
            content.empty:SetJustifyH("LEFT")
            content.empty:SetTextColor(rgb(C.text))
            content.empty:SetText(B.StepSummary(step))
            y = place(content.empty, y, content.empty:GetStringHeight() + 2) + 8
        end
        W.FitHeight(y)
        return
    end
    content.empty:SetJustifyH("CENTER")
    content.empty:SetTextColor(rgb(C.textDim))

    y = safe(renderAlerts, y, y, width)
    if step then y = safe(renderCard, y, y, width, step) end

    -- controls
    content.prev:ClearAllPoints()
    content.prev:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
    content.prev:Show()
    content.prev:SetEnabled(idx > 1)
    content.sync:ClearAllPoints()
    content.sync:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -y)
    content.sync:SetLabel(guide.dynamic and "Regenerar" or "Sincronizar")
    content.sync:Show()
    content.skip:ClearAllPoints()
    content.skip:SetPoint("TOPRIGHT", content.sync, "TOPLEFT", -6, 0)
    content.skip:Show()
    content.skip:SetEnabled(idx < total)
    y = y + 22 + 12

    y = safe(renderSticky, y, y, width, step)
    local beforeUpcoming = y
    local base = S.db.upcoming or 3
    y = safe(renderUpcoming, y, y, idx, base)
    y = safe(renderOutbound, y, y, width)
    y = safe(renderProfessions, y, y, width)

    -- a taller window shows more upcoming steps: fill the spare height
    local avail = frame.sizing and frame:GetHeight() or math.max(160, S.db.height or 470)
    local spare = avail - (y + 6 + 34 + 28)
    local extra = math.floor(spare / 22) - (base == 0 and 1 or 0) -- the section title takes a row
    if extra > 0 then
        y = safe(renderUpcoming, beforeUpcoming, beforeUpcoming, idx, base + extra)
        y = safe(renderOutbound, y, y, width)
        y = safe(renderProfessions, y, y, width)
    end
    W.FitHeight(y + 6)
end

function W.FitHeight(contentHeight)
    content:SetHeight(contentHeight)
    if frame.sizing then return end
    local maxH = math.max(160, S.db.height or 470)
    local h = math.min(maxH, contentHeight + 34 + 28)
    frame:SetHeight(h)
    scroll:UpdateThumb()
end

---------------------------------------------------------------------------
-- Guide menu & map
---------------------------------------------------------------------------
local guideMenu
function W.OpenGuideMenu(anchor)
    local meta = B.GuideMeta()
    if not meta then return end
    if guideMenu and guideMenu.menu:IsShown() then guideMenu.menu:Hide() return end
    if not guideMenu then
        guideMenu = UI.Dropdown(frame, 200)
        guideMenu:Hide()
        guideMenu:SetOnSelect(function(value)
            if value == "zones" then S:Fire("OPEN_ZONE_PICKER", "manual") return end
            if value == "here" then S:Fire("REGENERATE") return end
            B.LoadGuide(value)
        end)
    end
    local items = {}
    for _, g in ipairs(B.SearchGuides(nil, meta.group)) do
        if g.group == meta.group then
            items[#items + 1] = {
                text = g.name, value = g,
                color = g.name == meta.rawName and C.goldSoft or nil,
            }
        end
    end
    if S.DB.Ready() then
        items[#items + 1] = { text = "Ruta automática de esta zona", value = "here", color = C.info }
    end
    items[#items + 1] = { text = "Elegir otra zona…", value = "zones", color = C.info }
    guideMenu:SetItems(items)
    guideMenu:ClearAllPoints()
    guideMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 2)
    guideMenu:SetWidth(math.max(220, anchor:GetWidth()))
    guideMenu:Open()
end

function W.OpenMapForStep()
    local zone = content.card.waypoint.zone
    if not zone then return end
    if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(zone) end
end

---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------
function W.Show()
    if not frame then build() end
    S.windowEnabled = true
    S.db.hidden = false
    frame:Show()
end

function W.Hide()
    if frame then frame:Hide() end
    S.db.hidden = true
end

S:On("TOGGLE_WINDOW", function()
    if frame and frame:IsShown() then W.Hide() else W.Show() end
end)
S:On("LAYOUT_RESET", function()
    if not frame then return end
    frame:SetScale(S.db.scale)
    frame:ClearAllPoints()
    local p = S.db.point
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end)
S:On("SETTINGS_CHANGED", function()
    if not frame then return end
    frame:SetScale(S.db.scale)
    W.Refresh()
end)

for _, msg in ipairs({ "STEP_CHANGED", "PROGRESS", "GUIDE_LOADED", "LEVEL_UP", "DUNGEON_ENTERED", "DUNGEON_LEFT" }) do
    S:On(msg, function() W.Refresh() end)
end
S:RegisterEvent("PLAYER_XP_UPDATE", function() if frame and frame:IsShown() then renderXP() end end)
-- distances change while you move: re-check suggestions every few seconds
C_Timer.NewTicker(4, function()
    if frame and frame:IsShown() and S.db.smartAlerts and not S.db.collapsed then W.Refresh() end
end)
S:RegisterEvent("UPDATE_EXHAUSTION", function() if frame and frame:IsShown() then renderXP() end end)

S:On("READY", function()
    if not S.db.hidden then W.Show() end
end)
