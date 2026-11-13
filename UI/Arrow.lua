-- SakedXP · Waypoint arrow + world map pins

local _, S = ...
local C, UI, E, DB = S.C, S.UI, S.Engine, S.DB
local rgb = UI.rgb

local MEDIA = "Interface\\AddOns\\SakedXP\\Media\\"
local AR = {}
S.Arrow = AR

local frame, target
local lastTargetUpdate = 0

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------
local function mapSize(map)
    if C_Map.GetMapWorldSize then
        local w, h = C_Map.GetMapWorldSize(map)
        if w and w > 0 then return w, h end
    end
    local _, a = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0, 0))
    local _, b = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(1, 1))
    if a and b then return math.abs(b.x - a.x), math.abs(b.y - a.y) end
    return 1000, 1000
end

-- target position expressed on the player's current map (0-100)
local function onPlayerMap(pmap, tmap, tx, ty)
    if pmap == tmap then return tx, ty end
    local cont, world = C_Map.GetWorldPosFromMapPos(tmap, CreateVector2D(tx / 100, ty / 100))
    if not world then return end
    local _, pos = C_Map.GetMapPosFromWorldPos(cont, world, pmap)
    if not pos then return end
    return pos.x * 100, pos.y * 100
end

---------------------------------------------------------------------------
-- Arrow frame
---------------------------------------------------------------------------
local function build()
    frame = CreateFrame("Button", "SakedXPArrow", UIParent)
    frame:SetSize(64, 84)
    local p = S.db.arrowPoint
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not S.db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local a, _, ra, x, y = self:GetPoint(1)
        S.db.arrowPoint = { a, "UIParent", ra, x, y }
    end)
    frame:SetScale(S.db.arrowScale or 1)

    frame.shadow = frame:CreateTexture(nil, "BACKGROUND")
    frame.shadow:SetTexture(MEDIA .. "arrow")
    frame.shadow:SetSize(50, 50)
    frame.shadow:SetPoint("TOP", 1, -3)
    frame.shadow:SetVertexColor(0, 0, 0, 0.5)

    frame.tex = frame:CreateTexture(nil, "ARTWORK")
    frame.tex:SetTexture(MEDIA .. "arrow")
    frame.tex:SetSize(48, 48)
    frame.tex:SetPoint("TOP", 0, -2)

    frame.check = frame:CreateTexture(nil, "ARTWORK")
    frame.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    frame.check:SetSize(34, 34)
    frame.check:SetPoint("TOP", 0, -8)
    frame.check:Hide()

    frame.dist = UI.Text(frame, 12, C.goldSoft, { head = true, justify = "CENTER" })
    frame.dist:SetPoint("TOP", frame.tex, "BOTTOM", 0, -2)
    frame.label = UI.Text(frame, 10, C.textDim, { justify = "CENTER", wrap = false })
    frame.label:SetPoint("TOP", frame.dist, "BOTTOM", 0, -2)
    frame.label:SetWidth(180)

    frame:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            S.db.arrow = false
            frame:Hide()
            S.Print("flecha oculta. Volvé a activarla en /sxp config.")
        else
            S:Fire("TOGGLE_WINDOW")
        end
    end)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    UI.Tooltip(frame, function() return target and target.label or "SakedXP" end,
        "Clic: mostrar la guía · Clic derecho: ocultar flecha · Arrastrá para mover")

    local acc = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.04 then return end
        acc = 0
        AR.Update()
    end)
end

function AR.RefreshTarget()
    local g = E.guide
    local st = g and g.steps[E.current]
    target = nil
    if st then
        local m, x, y, label = E.StepTarget(st)
        if m and x and y then target = { map = m, x = x, y = y, label = label } end
    end
    lastTargetUpdate = GetTime()
    AR.UpdatePins()
end

function AR.Update()
    if not S.db.arrow then frame:Hide() return end
    if GetTime() - lastTargetUpdate > 3 then AR.RefreshTarget() end
    if not target then frame:SetAlpha(0) return end
    local pmap, px, py = DB.PlayerPos()
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not pmap or not px or not facing or S.IsSecret(facing) or S.IsSecret(px) then frame:SetAlpha(0) return end
    local tx, ty = onPlayerMap(pmap, target.map, target.x, target.y)
    if not tx then frame:SetAlpha(0) return end
    frame:SetAlpha(1)
    local w, h = mapSize(pmap)
    local dx, dy = (tx - px) / 100 * w, (ty - py) / 100 * h
    local dist = math.sqrt(dx * dx + dy * dy)
    frame.label:SetText(target.label or "")
    if dist < 8 then
        frame.tex:Hide(); frame.shadow:Hide(); frame.check:Show()
        frame.dist:SetText("Llegaste")
        return
    end
    frame.check:Hide(); frame.tex:Show(); frame.shadow:Show()
    local bearing = math.atan2(-dx, -dy)
    local angle = bearing - facing
    frame.tex:SetRotation(angle)
    frame.shadow:SetRotation(angle)
    -- colour: gold when ahead, amber when you must turn around
    local off = math.abs(((angle + math.pi) % (2 * math.pi)) - math.pi)
    local t = off / math.pi
    frame.tex:SetVertexColor(1, 1 - 0.25 * t, 1 - 0.45 * t)
    frame.dist:SetText(dist >= 1000 and ("%.1f km"):format(dist / 1000) or ("%d m"):format(dist))
end

---------------------------------------------------------------------------
-- World map pins: current step (big) + next steps (small, numbered)
---------------------------------------------------------------------------
local pins = {}
local pinHost

local function getPin(i)
    local p = pins[i]
    if p then return p end
    p = CreateFrame("Frame", nil, pinHost)
    p:SetSize(20, 20)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p.tex:SetTexture(MEDIA .. "pin")
    p.num = UI.Text(p, 10, C.bg, { head = true, justify = "CENTER", shadow = false })
    p.num:SetPoint("CENTER", 0, 0)
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.title or "SakedXP", rgb(C.goldSoft))
        if self.body then GameTooltip:AddLine(self.body, C.text[1], C.text[2], C.text[3], true) end
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = p
    return p
end

function AR.UpdatePins()
    if not (WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetCanvas) then return end
    local canvas = WorldMapFrame:GetCanvas()
    if not pinHost then
        pinHost = CreateFrame("Frame", nil, canvas)
        pinHost:SetAllPoints(canvas)
        pinHost:SetFrameLevel(canvas:GetFrameLevel() + 2000)
    end
    local mapID = WorldMapFrame:GetMapID()
    local scale = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale() or 1
    local W, H = canvas:GetWidth(), canvas:GetHeight()
    local n = 0
    local g = E.guide
    if S.db.mapPins and g then
        for i = E.current, math.min(#g.steps, E.current + 5) do
            local st = g.steps[i]
            local m, x, y, label = E.StepTarget(st)
            if m and x then
                local mx, my = x, y
                if m ~= mapID then mx, my = onPlayerMap(mapID, m, x, y) end
                if mx and mx >= 0 and mx <= 100 and my >= 0 and my <= 100 then
                    n = n + 1
                    local p = getPin(n)
                    local size = (i == E.current and 26 or 18) / scale
                    p:SetSize(size, size)
                    p:ClearAllPoints()
                    p:SetPoint("CENTER", pinHost, "TOPLEFT", mx / 100 * W, -my / 100 * H)
                    p.num:SetFont(UI.FONT_HEAD, math.max(6, 9 / scale))
                    p.num:SetText(i == E.current and "" or (i - E.current))
                    p:SetAlpha(i == E.current and 1 or 0.75)
                    p.title = ("Paso %d"):format(i)
                    p.body = label or S.Bridge.StepSummary(st)
                    p:Show()
                end
            end
        end
    end
    for i = n + 1, #pins do pins[i]:Hide() end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
S:On("READY", function()
    if not frame then build() end
    frame:SetShown(S.db.arrow)
    AR.RefreshTarget()
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, AR.UpdatePins) end)
        if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() AR.UpdatePins() end) end
        local acc = 0
        WorldMapFrame:HookScript("OnUpdate", function(_, el)
            acc = acc + el
            if acc > 0.3 then acc = 0; AR.UpdatePins() end
        end)
    end
end)
for _, m in ipairs({ "STEP_CHANGED", "PROGRESS", "GUIDE_LOADED" }) do
    S:On(m, function() S:Debounce("arrowTarget", 0.1, AR.RefreshTarget) end)
end
S:On("SETTINGS_CHANGED", function()
    if not frame then return end
    frame:SetScale(S.db.arrowScale or 1)
    frame:SetShown(S.db.arrow)
    AR.UpdatePins()
end)
