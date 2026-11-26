-- Map: the window. Draws the client's own minimap textures of each room (by FileDataID) north up, the
-- current room highlighted, other levels faint, and the estimated arrow with its uncertainty ring.
local ADDON, ns = ...
local L = ns.L

local Map = {}
ns.Map = Map

local floor, max, min = math.floor, math.max, math.min
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

local view = { x = 0, y = 0, s = 2 }  -- world point at the viewport centre, pixels per yard
local frame, viewport, canvas, arrow, ring, title, status, levelBar
local tiles, glows = {}, {}
local data, grid
local shownLevel, autoLevel = nil, true
local levelButtons = {}

-------------------------------------------------------------------- helpers

local function setFont(fs, size)
    fs:SetFontObject(size == "small" and GameFontHighlightSmall or GameFontNormal)
end

-- world (x, y) -> offset from the canvas origin (world 0,0), screen up = north (+x), right = east (-y)
local function toCanvas(x, y)
    return -y * view.s, x * view.s
end

local function placeCanvas()
    -- the canvas origin is world (0, 0); put the view centre in the middle of the viewport
    canvas:ClearAllPoints()
    local cx, cy = toCanvas(view.x, view.y)
    canvas:SetPoint("CENTER", viewport, "CENTER", -cx, -cy)
end

local count = 0 -- tiles in use for the current dungeon (the textures are reused between dungeons)

-- texcoords (UL, LL, UR, LR) for an image turned 0, 90, 180, 270 degrees counter-clockwise on screen
local QUARTER = {
    [0] = { 0, 0, 0, 1, 1, 0, 1, 1 },
    [1] = { 1, 0, 0, 0, 1, 1, 0, 1 },
    [2] = { 1, 1, 1, 0, 0, 1, 0, 0 },
    [3] = { 0, 1, 1, 1, 0, 0, 1, 0 },
}
local HALF_PI = math.pi / 2

-- how a tile lies on screen: quarter turns through texcoords (exact, any aspect ratio), other angles
-- through the texture's own rotation. Returns screen width, height (yards) and the rotation to apply.
local function tileShape(d)
    local w, h, rho = d[4], d[5], d[7] or 0
    local k = rho / HALF_PI
    local q = floor(k + 0.5)
    if math.abs(k - q) < 0.01 then
        q = q % 4
        if q == 1 or q == 3 then w, h = h, w end
        return w, h, nil, QUARTER[q]
    end
    return w, h, rho, QUARTER[0]
end
Map.tileShape = tileShape

local function styleTile(t, d)
    local _, _, rot, tc = tileShape(d)
    if t.SetRotation then t:SetRotation(0) end
    t:SetTexCoord(tc[1], tc[2], tc[3], tc[4], tc[5], tc[6], tc[7], tc[8])
    if rot and t.SetRotation then t:SetRotation(rot) end
end

local function layoutTiles()
    for i = 1, count do
        local t = tiles[i]
        local d = t.d -- { fdid, centre x, centre y, w, h, room (0 = terrain), screen rotation, level }
        local w, h = tileShape(d)
        local cx, cy = toCanvas(d[2], d[3])
        t:ClearAllPoints()
        t:SetPoint("CENTER", canvas, "CENTER", cx, cy)
        t:SetSize(max(1, w * view.s), max(1, h * view.s))
        local g = glows[i]
        g:ClearAllPoints()
        g:SetAllPoints(t)
    end
end

local function tileLevel(t)
    return t.d[8] or (data.groups[t.d[6]] and data.groups[t.d[6]].lvl) or 1
end

local function applyLevels(curGroup)
    local lvl = shownLevel or 1
    local faint = SakedMapDB.faint
    for i = 1, count do
        local t = tiles[i]
        local tl = tileLevel(t)
        if tl == lvl then
            t:SetAlpha(1)
            t:Show()
        elseif faint then
            t:SetAlpha(math.abs(tl - lvl) == 1 and 0.22 or 0.10)
            t:Show()
        else
            t:Hide()
        end
        local g = glows[i]
        if curGroup and t.d[6] ~= 0 and t.d[6] == curGroup then g:Show() else g:Hide() end
    end
    for i, b in ipairs(levelButtons) do
        if i == lvl then b:LockHighlight() else b:UnlockHighlight() end
    end
end

local function fit()
    if not data then return end
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, count do
        local t = tiles[i]
        local d = t.d
        if (not shownLevel or tileLevel(t) == shownLevel) and d[6] ~= 0 then
            local r = max(d[4], d[5]) / 2
            x0, y0, x1, y1 = min(x0, d[2] - r), min(y0, d[3] - r), max(x1, d[2] + r), max(y1, d[3] + r)
        end
    end
    if x0 > x1 then return end
    view.x, view.y = (x0 + x1) / 2, (y0 + y1) / 2
    local w, h = viewport:GetWidth(), viewport:GetHeight()
    view.s = max(0.3, min(8, min(w / max(1, y1 - y0), h / max(1, x1 - x0)) * 0.95))
    SakedMapDB.follow = false
    frame.follow:SetChecked(false)
    layoutTiles()
    placeCanvas()
end

local function cursorWorld()
    local cx, cy = GetCursorPosition()
    local es = viewport:GetEffectiveScale()
    cx, cy = cx / es, cy / es
    local vx, vy = viewport:GetCenter()
    local dx, dy = cx - vx, cy - vy
    return view.x + dy / view.s, view.y - dx / view.s
end

-------------------------------------------------------------------- creation

function Map:Create()
    if frame then return end
    frame = CreateFrame("Frame", "SakedMapFrame", UIParent)
    frame:SetSize(SakedMapDB.w, SakedMapDB.h)
    if SakedMapDB.point then
        frame:SetPoint(unpack(SakedMapDB.point))
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -220, 40)
    end
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(240, 200, 1400, 1100) end
    frame:EnableMouse(true)
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.05, 0.92)
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.55, 0.45, 0.2, 0.9)
    border:SetDrawLayer("BACKGROUND", -1)

    -- title bar (drag to move)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(22)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local p, _, rp, x, y = frame:GetPoint()
        SakedMapDB.point = { p, "UIParent", rp, x, y }
    end)
    local barBg = bar:CreateTexture(nil, "ARTWORK")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.16, 0.12, 0.06, 0.95)
    title = bar:CreateFontString(nil, "OVERLAY")
    setFont(title)
    title:SetPoint("LEFT", 8, 0)
    title:SetPoint("RIGHT", -28, 0)
    title:SetJustifyH("LEFT")
    title:SetText(L.TITLE)
    local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 2, 0)
    close:SetSize(24, 24)
    close:SetScript("OnClick", function() Map:Hide() end)

    -- options row: level buttons, follow, faint
    levelBar = CreateFrame("Frame", nil, frame)
    levelBar:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 4, -2)
    levelBar:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -4, -2)
    levelBar:SetHeight(22)

    local follow = CreateFrame("CheckButton", nil, levelBar, "UICheckButtonTemplate")
    follow:SetSize(22, 22)
    follow:SetPoint("RIGHT", levelBar, "RIGHT", -70, 0)
    follow:SetChecked(SakedMapDB.follow)
    follow:SetScript("OnClick", function(b) SakedMapDB.follow = b:GetChecked() and true or false; autoLevel = SakedMapDB.follow end)
    local ft = follow:CreateFontString(nil, "OVERLAY")
    setFont(ft, "small")
    ft:SetPoint("LEFT", follow, "RIGHT", 0, 0)
    ft:SetText(L.FOLLOW)
    frame.follow = follow

    local faint = CreateFrame("CheckButton", nil, levelBar, "UICheckButtonTemplate")
    faint:SetSize(22, 22)
    faint:SetPoint("RIGHT", follow, "LEFT", -86, 0)
    faint:SetChecked(SakedMapDB.faint)
    faint:SetScript("OnClick", function(b) SakedMapDB.faint = b:GetChecked() and true or false; applyLevels(Map.curGroup) end)
    local fat = faint:CreateFontString(nil, "OVERLAY")
    setFont(fat, "small")
    fat:SetPoint("LEFT", faint, "RIGHT", 0, 0)
    fat:SetText(L.FAINT)

    -- map viewport (clips the canvas)
    viewport = CreateFrame("Frame", nil, frame)
    viewport:SetPoint("TOPLEFT", levelBar, "BOTTOMLEFT", 0, -2)
    viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 22)
    viewport:SetClipsChildren(true)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    canvas = CreateFrame("Frame", nil, viewport)
    canvas:SetSize(1, 1)
    canvas:SetPoint("CENTER")

    ring = canvas:CreateTexture(nil, "OVERLAY", nil, 1)
    ring:SetTexture(MEDIA .. "ring")
    ring:SetVertexColor(1, 0.85, 0.2, 0.7)
    ring:Hide()
    arrow = canvas:CreateTexture(nil, "OVERLAY", nil, 3)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetSize(28, 28)
    arrow:Hide()
    Map.dots = {}

    -- mouse: wheel zoom at the cursor, drag to pan, middle click to fit, shift+click "I'm here"
    viewport:SetScript("OnMouseWheel", function(_, delta)
        local wx, wy = cursorWorld()
        local old = view.s
        view.s = max(0.3, min(10, view.s * (delta > 0 and 1.25 or 0.8)))
        SakedMapDB.scale = view.s
        -- keep the point under the cursor in place
        view.x = wx - (wx - view.x) * old / view.s
        view.y = wy - (wy - view.y) * old / view.s
        layoutTiles()
        placeCanvas()
        Map:UpdatePlayer(ns.state.est, ns.state.motion)
    end)
    viewport:SetScript("OnMouseDown", function(_, button)
        if button == "MiddleButton" then return fit() end
        if button == "LeftButton" and IsShiftKeyDown() then
            local wx, wy = cursorWorld()
            Map:ImHere(wx, wy)
            return
        end
        if button == "LeftButton" then
            local cx, cy = GetCursorPosition()
            viewport.drag = { cx, cy, view.x, view.y }
            SakedMapDB.follow = false
            frame.follow:SetChecked(false)
        elseif button == "RightButton" then
            SakedMapDB.follow = true
            autoLevel = true
            frame.follow:SetChecked(true)
        end
    end)
    viewport:SetScript("OnMouseUp", function() viewport.drag = nil end)
    viewport:SetScript("OnUpdate", function()
        local d = viewport.drag
        if not d then return end
        local cx, cy = GetCursorPosition()
        local es = viewport:GetEffectiveScale()
        view.x = d[3] - (d[2] - cy) / es / view.s
        view.y = d[4] + (d[1] - cx) / es / view.s
        placeCanvas()
    end)

    -- status line and resize grip
    status = frame:CreateFontString(nil, "OVERLAY")
    setFont(status, "small")
    status:SetPoint("BOTTOMLEFT", 6, 5)
    status:SetPoint("BOTTOMRIGHT", -22, 5)
    status:SetJustifyH("LEFT")
    status:SetText(L.HINT)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SakedMapDB.w, SakedMapDB.h = frame:GetWidth(), frame:GetHeight()
        local p, _, rp, x, y = frame:GetPoint()
        SakedMapDB.point = { p, "UIParent", rp, x, y }
    end)

    view.s = SakedMapDB.scale or 2
    tinsert(UISpecialFrames, "SakedMapFrame") -- Escape closes it
end

local function buildLevelButtons()
    for _, b in ipairs(levelButtons) do b:Hide() end
    if not data then return end
    for i, lv in ipairs(data.levels) do
        local b = levelButtons[i]
        if not b then
            b = CreateFrame("Button", nil, levelBar, "UIPanelButtonTemplate")
            b:SetSize(22, 20)
            levelButtons[i] = b
        end
        b:SetText(tostring(i))
        b:ClearAllPoints()
        b:SetPoint("LEFT", levelBar, "LEFT", (i - 1) * 24, 0)
        b:SetScript("OnClick", function()
            shownLevel = i
            autoLevel = false
            applyLevels(Map.curGroup)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L.LEVEL .. " " .. i .. ": " .. ns.LocalName(data, lv.name))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:Show()
    end
end

-------------------------------------------------------------------- dungeon data

function Map:SetDungeon(d, g)
    if not frame then return end
    for _, t in ipairs(tiles) do t:Hide() end
    for _, t in ipairs(glows) do t:Hide() end
    data, grid = d, g
    Map.curGroup = nil
    if not d then
        arrow:Hide(); ring:Hide()
        frame:Hide()
        return
    end
    -- lower levels first so upper floors draw on top
    local order = {}
    for i, td in ipairs(d.tiles) do order[i] = td end
    -- terrain first, then rooms by level
    table.sort(order, function(a, b)
        if (a[6] == 0) ~= (b[6] == 0) then return a[6] == 0 end
        return (a[8] or 0) < (b[8] or 0)
    end)
    for i, td in ipairs(order) do
        local t = tiles[i]
        if not t then
            t = canvas:CreateTexture(nil, "ARTWORK")
            tiles[i] = t
            local g2 = canvas:CreateTexture(nil, "ARTWORK", nil, 7)
            g2:SetBlendMode("ADD")
            glows[i] = g2
        end
        t.d = td
        local sub = td[6] == 0 and -8 or max(-7, min(6, (td[8] or 1) - 8))
        t:SetDrawLayer("ARTWORK", sub)
        t:SetTexture(td[1])
        styleTile(t, td)
        local g2 = glows[i]
        g2:SetTexture(td[1])
        styleTile(g2, td)
        g2:SetVertexColor(0.25, 1, 0.3, 0.55)
        g2:Hide()
    end
    count = #order
    for i = count + 1, #tiles do tiles[i]:Hide(); glows[i]:Hide() end
    shownLevel, autoLevel = 1, true
    buildLevelButtons()
    view.s = SakedMapDB.scale or 2
    layoutTiles()
    placeCanvas()
    applyLevels(nil)
    self:UpdateTitle()
end

function Map:UpdateTitle()
    if not frame or not data then return end
    local name = ns.LocalName(data, data.name)
    local st = ns.state
    local room = st.areaRaw and st.areaRaw ~= "" and st.areaRaw or nil
    if not room and Map.curGroup then
        local g = data.groups[Map.curGroup]
        if g and g.name ~= "" then room = ns.LocalName(data, g.name) end
    end
    title:SetText(room and (name .. "  ·  |cffffffff" .. room .. "|r") or name)
end

-------------------------------------------------------------------- live updates

local lastStatus
function Map:UpdatePlayer(est, motion)
    if not frame or not frame:IsShown() or not data then return end
    if not est then arrow:Hide(); ring:Hide(); return end
    local locked = ns.state.filter and ns.state.filter:isLocked()
    -- follow: centre on the estimate and show its level
    if SakedMapDB.follow and not viewport.drag then
        view.x, view.y = est.x, est.y
        placeCanvas()
    end
    local lvl = grid:levelForZ(est.z)
    local g = est.group
    if g and data.groups[g] then
        lvl = data.groups[g].lvl
    elseif data.terrainLevel and data.terrainLevel > 0 then
        lvl = data.terrainLevel -- out in the open
    end
    if autoLevel or SakedMapDB.follow then shownLevel = lvl end
    local hg = locked and g or nil -- highlight the room only when the estimate is trusted
    if hg ~= Map.curGroup or Map.lastLevel ~= shownLevel then
        Map.curGroup = hg
        Map.lastLevel = shownLevel
        applyLevels(Map.curGroup)
        self:UpdateTitle()
    end
    local ax, ay = toCanvas(est.x, est.y)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", canvas, "CENTER", ax, ay)
    arrow:SetRotation(est.heading or 0)
    arrow:SetAlpha(locked and 1 or 0.55)
    arrow:Show()
    local r = est.spread or 0
    if r > 3 then
        local px = max(24, r * 2 * view.s)
        ring:SetSize(px, px)
        ring:ClearAllPoints()
        ring:SetPoint("CENTER", canvas, "CENTER", ax, ay)
        ring:Show()
    else
        ring:Hide()
    end
    -- status line
    local s
    if not motion or not motion.facing then
        s = "|cffff6060" .. L.NO_FACING .. "|r"
    else
        s = (motion.facingSource == "compass" and L.FACING_COMPASS or L.FACING_API) .. "  ·  " ..
            (locked and L.LOCKED:format(max(1, floor(r + 0.5))) or L.SEARCHING)
    end
    if s ~= lastStatus then status:SetText(s); lastStatus = s end
    if SakedMapDB.debug then self:DrawDebug() end
end

-- debug: the filter's guesses as dots
function Map:DrawDebug()
    local f = ns.state.filter
    if not f then return end
    local dots = self.dots
    local step = max(1, floor(f.n / 200))
    local k = 0
    for i = 1, f.n, step do
        k = k + 1
        local d = dots[k]
        if not d then
            d = canvas:CreateTexture(nil, "OVERLAY", nil, 2)
            d:SetColorTexture(1, 0.2, 0.9, 0.8)
            d:SetSize(3, 3)
            dots[k] = d
        end
        local x, y = toCanvas(f.x[i], f.y[i])
        d:ClearAllPoints()
        d:SetPoint("CENTER", canvas, "CENTER", x, y)
        d:Show()
    end
    for i = k + 1, #dots do dots[i]:Hide() end
end

function Map:ImHere(x, y)
    local st = ns.state
    if not st.filter or not grid then return end
    -- the floor on the level being shown, nearest the click
    local lv = data.levels[shownLevel or 1]
    local zc = lv and (lv.z0 + lv.z1) / 2 or 0
    local sx, sy, sz = grid:snap(x, y, zc, 12)
    if not sx then return end
    local known = st.motion and st.motion.facing ~= nil
    st.filter:seedAt(sx, sy, sz, 3, known)
    SakedMapDB.follow = true
    frame.follow:SetChecked(true)
    autoLevel = true
    -- right after zoning in, this is also where the dungeon starts
    if st.zoneInAt and GetTime() - st.zoneInAt < 20 then
        local list = SakedMapDB.entrances[st.mapID] or {}
        list[#list + 1] = { floor(sx * 10) / 10, floor(sy * 10) / 10, floor(sz * 10) / 10 }
        if #list > 6 then table.remove(list, 1) end
        SakedMapDB.entrances[st.mapID] = list
        st.learned = true
    end
end

function Map:Show()
    if not frame then return end
    if not data then ns.print(L.NO_DATA); return end
    frame:Show()
    SakedMapDB.shown = true
    self:UpdatePlayer(ns.state.est, ns.state.motion)
end

function Map:Hide()
    if not frame then return end
    frame:Hide()
    SakedMapDB.shown = false
end

function Map:Toggle()
    if frame and frame:IsShown() then self:Hide() else self:Show() end
end

-- keybinding (Bindings.xml)
function SakedMap_Toggle() Map:Toggle() end
