-- SakedXP · Theme
-- Rounded, translucent UI kit: slate surfaces, muted gold accents, smooth
-- hover animations and a user-selectable font system.

local _, S = ...
local C = S.C
local UI = {}
S.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8x8"
local MEDIA = "Interface\\AddOns\\SakedXP\\Media\\"
UI.WHITE = WHITE
UI.MEDIA = MEDIA

local function rgb(c, a) return c[1], c[2], c[3], a or 1 end
UI.rgb = rgb

---------------------------------------------------------------------------
-- Fonts (user selectable; LibSharedMedia fonts are added when present)
---------------------------------------------------------------------------
local locale = GetLocale()
local nonLatin = locale == "koKR" or locale == "zhCN" or locale == "zhTW" or locale == "ruRU"

UI.FONTS = {
    { key = "friz",     name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "arialn",   name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri",   name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
    { key = "default",  name = "Fuente del juego", path = STANDARD_TEXT_FONT },
}

function UI.CollectFonts()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return end
    local seen = {}
    for _, f in ipairs(UI.FONTS) do seen[f.path:lower()] = true end
    for _, name in ipairs(LSM:List("font") or {}) do
        local path = LSM:Fetch("font", name, true)
        if path and not seen[path:lower()] then
            seen[path:lower()] = true
            UI.FONTS[#UI.FONTS + 1] = { key = "lsm:" .. name, name = name, path = path }
        end
    end
end

local function fontPath(key, fallback)
    if nonLatin then return STANDARD_TEXT_FONT end
    for _, f in ipairs(UI.FONTS) do
        if f.key == key then return f.path end
    end
    return fallback
end

function UI.FontPath(head)
    local db = S.db or {}
    if head then return fontPath(db.fontHead or "friz", "Fonts\\FRIZQT__.TTF") end
    return fontPath(db.fontBody or "arialn", "Fonts\\ARIALN.TTF")
end

-- every font string we create is remembered so a font change applies live
local registry = setmetatable({}, { __mode = "k" })

function UI.SetFont(fs, size, head, flags)
    registry[fs] = { size = size, head = head, flags = flags or "" }
    local scale = (S.db and S.db.fontScale) or 1
    fs:SetFont(UI.FontPath(head), math.max(6, math.floor(size * scale + 0.5)), flags or "")
end

function UI.ApplyFonts()
    for fs, info in pairs(registry) do
        UI.SetFont(fs, info.size, info.head, info.flags)
    end
end

-- Back-compat names for code that reads the current paths.
setmetatable(UI, { __index = function(_, k)
    if k == "FONT_HEAD" then return UI.FontPath(true) end
    if k == "FONT_BODY" then return UI.FontPath(false) end
end })

---------------------------------------------------------------------------
-- Tweening (one driver for every animation)
---------------------------------------------------------------------------
local tweens = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
    local alive = false
    for key, t in pairs(tweens) do
        t.time = t.time + elapsed
        local p = math.min(1, t.time / t.duration)
        local e = 1 - (1 - p) * (1 - p) * (1 - p) -- ease-out cubic
        local v = {}
        for i = 1, #t.from do v[i] = t.from[i] + (t.to[i] - t.from[i]) * e end
        t.apply(v)
        if p >= 1 then tweens[key] = nil else alive = true end
    end
    if not alive then self:Hide() end
end)

-- UI.Tween(key, {from...}, {to...}, seconds, function(values) end)
function UI.Tween(key, from, to, duration, apply)
    local cur = tweens[key]
    if cur then from = cur.last or from end
    local t = { from = from, to = to, duration = duration or 0.15, time = 0 }
    t.apply = function(v) t.last = v; apply(v) end
    tweens[key] = t
    driver:Show()
end

---------------------------------------------------------------------------
-- Rounded 9-slice layers
---------------------------------------------------------------------------
local SLICES = {
    -- name, texcoords, anchor logic handled below
    { "TL", 0, 0.25, 0, 0.25 }, { "T", 0.25, 0.75, 0, 0.25 }, { "TR", 0.75, 1, 0, 0.25 },
    { "L", 0, 0.25, 0.25, 0.75 }, { "M", 0.25, 0.75, 0.25, 0.75 }, { "R", 0.75, 1, 0.25, 0.75 },
    { "BL", 0, 0.25, 0.75, 1 }, { "B", 0.25, 0.75, 0.75, 1 }, { "BR", 0.75, 1, 0.75, 1 },
}

local Layer = {}
Layer.__index = Layer

function Layer:SetColor(r, g, b, a)
    self.color = { r, g, b, a or 1 }
    for _, t in pairs(self.tex) do t:SetVertexColor(r, g, b, a or 1) end
end
function Layer:SetShown(v) for _, t in pairs(self.tex) do t:SetShown(v) end end
function Layer:Show() self:SetShown(true) end
function Layer:Hide() self:SetShown(false) end

function Layer:SetCorner(c)
    self.corner = c
    local t, f, o = self.tex, self.frame, self.outset or 0
    for _, k in ipairs({ "TL", "TR", "BL", "BR" }) do t[k]:SetSize(c, c) end
    t.TL:ClearAllPoints(); t.TL:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o)
    t.TR:ClearAllPoints(); t.TR:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o)
    t.BL:ClearAllPoints(); t.BL:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o)
    t.BR:ClearAllPoints(); t.BR:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o)
    t.T:ClearAllPoints(); t.T:SetPoint("TOPLEFT", t.TL, "TOPRIGHT"); t.T:SetPoint("BOTTOMRIGHT", t.TR, "BOTTOMLEFT")
    t.B:ClearAllPoints(); t.B:SetPoint("TOPLEFT", t.BL, "TOPRIGHT"); t.B:SetPoint("BOTTOMRIGHT", t.BR, "BOTTOMLEFT")
    t.L:ClearAllPoints(); t.L:SetPoint("TOPLEFT", t.TL, "BOTTOMLEFT"); t.L:SetPoint("BOTTOMRIGHT", t.BL, "TOPRIGHT")
    t.R:ClearAllPoints(); t.R:SetPoint("TOPLEFT", t.TR, "BOTTOMLEFT"); t.R:SetPoint("BOTTOMRIGHT", t.BR, "TOPRIGHT")
    t.M:ClearAllPoints(); t.M:SetPoint("TOPLEFT", t.TL, "BOTTOMRIGHT"); t.M:SetPoint("BOTTOMRIGHT", t.BR, "TOPLEFT")
end

-- texture: "round" | "ring" | "glow"; outset grows the layer beyond the frame
function UI.RoundLayer(frame, texture, corner, layer, sublevel, outset)
    local l = setmetatable({ frame = frame, tex = {}, outset = outset or 0 }, Layer)
    for _, s in ipairs(SLICES) do
        local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
        t:SetTexture(MEDIA .. texture)
        t:SetTexCoord(s[2], s[3], s[4], s[5])
        l.tex[s[1]] = t
    end
    l:SetCorner(corner or 8)
    return l
end

-- Rounded background + border. Keeps the classic Backdrop method names so
-- every widget can call SetBackdropColor / SetBackdropBorderColor.
function UI.Backdrop(frame, bg, border, bgAlpha, radius)
    radius = radius or frame.__radius or 8
    if not frame.__fill then
        frame.__fill = UI.RoundLayer(frame, "round", radius, "BACKGROUND", -6)
        frame.__border = UI.RoundLayer(frame, "ring", radius, "BACKGROUND", -5)
        frame.SetBackdropColor = function(self, r, g, b, a) self.__fill:SetColor(r, g, b, a) end
        frame.SetBackdropBorderColor = function(self, r, g, b, a) self.__border:SetColor(r, g, b, a) end
        frame.GetBackdropColor = function(self) return unpack(self.__fill.color) end
        frame.GetBackdropBorderColor = function(self) return unpack(self.__border.color) end
        frame.SetRadius = function(self, r) self.__radius = r; self.__fill:SetCorner(r); self.__border:SetCorner(r) end
    elseif radius ~= frame.__radius then
        frame:SetRadius(radius)
    end
    frame.__radius = radius
    frame:SetBackdropColor(rgb(bg or C.bg, bgAlpha or 0.9))
    frame:SetBackdropBorderColor(rgb(border or C.border, 1))
end

-- Animate a frame's backdrop to new colours.
function UI.FadeBackdrop(frame, bg, bgA, border, borderA, duration)
    local f0 = frame.__fill.color or { 0, 0, 0, 0 }
    local b0 = frame.__border.color or { 0, 0, 0, 0 }
    UI.Tween(frame, { f0[1], f0[2], f0[3], f0[4], b0[1], b0[2], b0[3], b0[4] },
        { bg[1], bg[2], bg[3], bgA, border[1], border[2], border[3], borderA }, duration or 0.16,
        function(v)
            frame.__fill:SetColor(v[1], v[2], v[3], v[4])
            frame.__border:SetColor(v[5], v[6], v[7], v[8])
        end)
end

-- Soft glow that fades in on hover.
function UI.Glow(frame, color, radius)
    local g = UI.RoundLayer(frame, "glow", (radius or 8) + 8, "BACKGROUND", -8, 8)
    g:SetColor(rgb(color or C.gold, 0))
    frame.__glow = g
    frame.__glowColor = color or C.gold
    return g
end

function UI.FadeGlow(frame, alpha, duration)
    local g = frame.__glow
    if not g then return end
    local col = frame.__glowColor
    local a0 = g.color and g.color[4] or 0
    UI.Tween(g, { a0 }, { alpha }, duration or 0.2, function(v) g:SetColor(col[1], col[2], col[3], v[1]) end)
end

-- Standard hover behaviour for cards and rows.
-- style = { bg, bgA, border, borderA, bgHover, bgHoverA, borderHover, borderHoverA, glow }
-- frame.IsSelectedFX (optional) keeps the selected look after leaving.
function UI.HoverFX(frame, style)
    frame.__style = style
    if style.glow then UI.Glow(frame, style.glowColor, frame.__radius) end
    local function rest(self)
        local st = self.__style
        if self.IsSelectedFX and self:IsSelectedFX() then
            UI.FadeBackdrop(self, st.bgSel or st.bgHover, st.bgSelA or st.bgHoverA, st.borderSel or C.gold, st.borderSelA or 0.9)
        else
            UI.FadeBackdrop(self, st.bg, st.bgA, st.border, st.borderA)
        end
        UI.FadeGlow(self, 0)
    end
    frame:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        local st = self.__style
        UI.FadeBackdrop(self, st.bgHover, st.bgHoverA, st.borderHover, st.borderHoverA, 0.12)
        UI.FadeGlow(self, st.glowA or 0.35, 0.18)
    end)
    frame:HookScript("OnLeave", rest)
    frame.RestFX = rest
    return frame
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
function UI.Gradient(tex, orientation, c1, a1, c2, a2)
    tex:SetTexture(WHITE)
    if CreateColor and tex.SetGradient then
        local ok = pcall(tex.SetGradient, tex, orientation,
            CreateColor(c1[1], c1[2], c1[3], a1), CreateColor(c2[1], c2[2], c2[3], a2))
        if ok then return end
    end
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orientation, c1[1], c1[2], c1[3], a1, c2[1], c2[2], c2[3], a2)
    else
        tex:SetVertexColor(c1[1], c1[2], c1[3], a1)
    end
end

function UI.Text(parent, size, color, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
    UI.SetFont(fs, size or 12, opts.head, opts.flags)
    fs:SetTextColor(rgb(color or C.text))
    fs:SetJustifyH(opts.justify or "LEFT")
    fs:SetJustifyV(opts.justifyV or "MIDDLE")
    if opts.shadow ~= false then
        fs:SetShadowColor(0, 0, 0, 0.7)
        fs:SetShadowOffset(1, -1)
    end
    if opts.wrap ~= nil then fs:SetWordWrap(opts.wrap) end
    return fs
end

function UI.Line(parent, color, alpha, height)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(rgb(color or C.border, alpha or 1))
    t:SetHeight(height or 1)
    return t
end

function UI.Panel(parent, bg, border, alpha, radius)
    local f = CreateFrame("Frame", nil, parent)
    UI.Backdrop(f, bg or C.bgAlt, border or C.border, alpha or 0.62, radius or 10)
    return f
end

-- Small gold bar + title (+ optional subtitle), like a section header.
function UI.Section(parent, title, subtitle, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight((size or 16) + 6)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(3, (size or 16))
    holder:SetPoint("LEFT", 0, 0)
    UI.RoundLayer(holder, "round", 1.5, "ARTWORK"):SetColor(rgb(C.gold))
    f.title = UI.Text(f, size or 16, C.text, { head = true })
    f.title:SetPoint("LEFT", holder, "RIGHT", 8, 0)
    f.title:SetText(title or "")
    f.sub = UI.Text(f, 11, C.textDim)
    f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, -1)
    f.sub:SetText(subtitle or "")
    return f
end

-- icon with rounded corners (mask) inside a thin rounded frame
function UI.Icon(parent, size, texture)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    UI.Backdrop(holder, C.bg, C.goldDim, 0.8, math.floor(size / 4))
    local t = holder:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 2, -2)
    t:SetPoint("BOTTOMRIGHT", -2, 2)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if holder.CreateMaskTexture then
        local ok, mask = pcall(holder.CreateMaskTexture, holder)
        if ok and mask then
            mask:SetTexture(MEDIA .. "round", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            pcall(t.AddMaskTexture, t, mask)
        end
    end
    if texture then t:SetTexture(texture) end
    holder.tex = t
    function holder:SetIcon(tx, full)
        t:SetTexture(tx)
        if full then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end
    return holder
end

function UI.Tooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        local t = type(title) == "function" and title(self) or title
        if not t then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(t, rgb(C.goldSoft))
        local b = type(body) == "function" and body(self) or body
        if b then GameTooltip:AddLine(b, C.text[1], C.text[2], C.text[3], true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local BUTTON = {
    primary = { bg = C.gold, bgA = 0.95, border = C.goldSoft, borderA = 0.0, bgHover = C.goldSoft, bgHoverA = 1,
                borderHover = C.goldSoft, borderHoverA = 0.0, text = C.bg, glow = true, glowA = 0.45 },
    ghost   = { bg = C.bgAlt, bgA = 0.35, border = C.goldDim, borderA = 0.85, bgHover = C.gold, bgHoverA = 0.14,
                borderHover = C.goldSoft, borderHoverA = 1, text = C.goldSoft, glow = true, glowA = 0.25 },
    subtle  = { bg = C.bgRaised, bgA = 0.55, border = C.border, borderA = 0.9, bgHover = C.bgRaised, bgHoverA = 0.95,
                borderHover = C.borderLight, borderHoverA = 1, text = C.text, glow = false },
    danger  = { bg = C.bgAlt, bgA = 0.35, border = C.bad, borderA = 0.8, bgHover = C.bad, bgHoverA = 0.16,
                borderHover = C.bad, borderHoverA = 1, text = C.bad, glow = true, glowColor = C.bad, glowA = 0.25 },
}

function UI.Button(parent, label, kind, width, height)
    local st = BUTTON[kind or "ghost"]
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 80, height or 24)
    UI.Backdrop(b, st.bg, st.border, st.bgA, math.floor((height or 24) / 3.2))
    b:SetBackdropBorderColor(rgb(st.border, st.borderA))
    UI.HoverFX(b, st)
    b.label = UI.Text(b, 11, st.text, { head = true, justify = "CENTER", shadow = kind ~= "primary" })
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(label or "")
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.label:SetPoint("CENTER", 0, -1) end end)
    b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
    b:HookScript("OnDisable", function(self) self:SetAlpha(0.4) end)
    b:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
    function b:SetLabel(t) self.label:SetText(t) end
    function b:FitWidth(pad) self:SetWidth(self.label:GetStringWidth() + (pad or 22)) end
    return b
end

function UI.GlyphButton(parent, glyph, tip, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 20, size or 20)
    UI.Backdrop(b, C.bgRaised, C.border, 0, math.floor((size or 20) / 2))
    b:SetBackdropBorderColor(rgb(C.border, 0))
    UI.HoverFX(b, { bg = C.bgRaised, bgA = 0, border = C.border, borderA = 0,
        bgHover = C.bgRaised, bgHoverA = 0.9, borderHover = C.borderLight, borderHoverA = 1 })
    b.label = UI.Text(b, 13, C.textDim, { head = true, justify = "CENTER" })
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(glyph)
    b:HookScript("OnEnter", function(self) self.label:SetTextColor(rgb(C.goldSoft)) end)
    b:HookScript("OnLeave", function(self) self.label:SetTextColor(rgb(C.textDim)) end)
    if tip then UI.Tooltip(b, tip) end
    return b
end

function UI.IconButton(parent, texture, tip, size)
    local s = size or 20
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(s, s)
    UI.Backdrop(b, C.bgRaised, C.border, 0.0, math.floor(s / 3))
    b:SetBackdropBorderColor(rgb(C.border, 0))
    UI.HoverFX(b, { bg = C.bgRaised, bgA = 0, border = C.border, borderA = 0,
        bgHover = C.bgRaised, bgHoverA = 0.95, borderHover = C.goldDim, borderHoverA = 1, glow = true, glowA = 0.25 })
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 3, -3)
    t:SetPoint("BOTTOMRIGHT", -3, 3)
    t:SetTexture(texture)
    t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    t:SetDesaturated(true)
    t:SetVertexColor(0.8, 0.76, 0.7)
    b.tex = t
    b:HookScript("OnEnter", function() t:SetDesaturated(false); t:SetVertexColor(1, 1, 1) end)
    b:HookScript("OnLeave", function() t:SetDesaturated(true); t:SetVertexColor(0.8, 0.76, 0.7) end)
    if tip then UI.Tooltip(b, tip) end
    return b
end

---------------------------------------------------------------------------
-- Pill / badge
---------------------------------------------------------------------------
function UI.Pill(parent, text, color)
    local p = CreateFrame("Frame", nil, parent)
    UI.Backdrop(p, color or C.goldDim, color or C.goldDim, 0.14, 8)
    p.text = UI.Text(p, 10, color or C.goldSoft, { head = true, justify = "CENTER" })
    p.text:SetPoint("CENTER", 0, 0)
    function p:Set(t, col)
        self.text:SetText(t or "")
        if col then
            self.text:SetTextColor(rgb(col))
            self:SetBackdropColor(rgb(col, 0.14))
            self:SetBackdropBorderColor(rgb(col, 0.6))
        end
        self:SetSize(self.text:GetStringWidth() + 16, 18)
        self:SetRadius(9)
    end
    p:Set(text, color)
    return p
end

---------------------------------------------------------------------------
-- Progress bar (rounded track, gold gradient fill)
---------------------------------------------------------------------------
function UI.ProgressBar(parent, height, colorA, colorB)
    local h = height or 6
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(h)
    UI.Backdrop(bar, C.bg, C.border, 0.7, h / 2)
    bar:SetBackdropBorderColor(rgb(C.border, 0.5))
    local fillHost = CreateFrame("Frame", nil, bar)
    fillHost:SetPoint("TOPLEFT", 0, 0)
    fillHost:SetPoint("BOTTOMLEFT", 0, 0)
    local fill = UI.RoundLayer(fillHost, "round", h / 2, "ARTWORK")
    fill:SetColor(rgb(colorB or C.gold))
    local shine = fillHost:CreateTexture(nil, "OVERLAY")
    shine:SetPoint("TOPLEFT", h / 2, 0)
    shine:SetPoint("TOPRIGHT", -h / 2, 0)
    shine:SetHeight(math.max(1, math.floor(h / 2)))
    UI.Gradient(shine, "VERTICAL", C.text, 0, C.text, 0.15)
    bar.fill = fillHost
    function bar:SetProgress(p, animate)
        p = math.max(0, math.min(1, p or 0))
        local w = self:GetWidth()
        local target = p > 0 and math.max(h, w * p) or 0
        local function set(v) if v < 1 then fillHost:Hide() else fillHost:Show(); fillHost:SetWidth(v) end end
        if animate ~= false and self.progress and w > 0 then
            local from = fillHost:IsShown() and fillHost:GetWidth() or 0
            UI.Tween(fillHost, { from }, { target }, 0.35, function(v) set(v[1]) end)
        else
            set(target)
        end
        self.progress = p
    end
    bar:SetScript("OnSizeChanged", function(self) self:SetProgress(self.progress or 0, false) end)
    return bar
end

---------------------------------------------------------------------------
-- Scroll area: mouse wheel + slim rounded thumb
---------------------------------------------------------------------------
function UI.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf.content = content

    local thumb = CreateFrame("Frame", nil, sf)
    thumb:SetWidth(4)
    local tl = UI.RoundLayer(thumb, "round", 2, "OVERLAY")
    tl:SetColor(rgb(C.goldDim, 0.6))

    local function update()
        local max = sf:GetVerticalScrollRange()
        if max <= 1 then thumb:Hide(); return end
        thumb:Show()
        local h = sf:GetHeight()
        local th = math.max(18, h * h / (h + max))
        thumb:SetHeight(th)
        local pos = sf:GetVerticalScroll() / max
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -1, -(h - th) * pos)
    end
    sf.UpdateThumb = update

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange()
        local from = self:GetVerticalScroll()
        local to = math.max(0, math.min(max, from - delta * 48))
        UI.Tween(self, { from }, { to }, 0.18, function(v) self:SetVerticalScroll(v[1]); update() end)
    end)
    sf:SetScript("OnScrollRangeChanged", update)
    sf:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w - 8)
        update()
    end)
    return sf, content
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------
local openMenu
function UI.Dropdown(parent, width, placeholder)
    local dd = UI.Button(parent, placeholder or "", "subtle", width or 200, 26)
    dd.label:ClearAllPoints()
    dd.label:SetPoint("LEFT", 10, 0)
    dd.label:SetPoint("RIGHT", -24, 0)
    dd.label:SetJustifyH("LEFT")
    UI.SetFont(dd.label, 12, false)
    dd.label:SetTextColor(rgb(C.text))
    local arrow = UI.Text(dd, 11, C.gold, { head = true })
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")
    dd.items = {}

    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    UI.Backdrop(menu, C.bg, C.goldDim, 0.97, 10)
    menu:SetBackdropBorderColor(rgb(C.goldDim, 0.7))
    menu:Hide()
    menu:EnableMouse(true)
    dd.menu = menu
    local rows = {}

    function dd:SetItems(items) self.items = items or {} end
    function dd:SetOnSelect(fn) self.onSelect = fn end

    local function close() menu:Hide(); if openMenu == menu then openMenu = nil end end

    function dd:Open()
        if openMenu and openMenu ~= menu then openMenu:Hide() end
        openMenu = menu
        local w = self:GetWidth()
        local y = -6
        for i, item in ipairs(self.items) do
            local r = rows[i]
            if not r then
                r = CreateFrame("Button", nil, menu)
                r:SetHeight(22)
                UI.Backdrop(r, C.gold, C.gold, 0, 6)
                r:SetBackdropBorderColor(0, 0, 0, 0)
                UI.HoverFX(r, { bg = C.gold, bgA = 0, border = C.gold, borderA = 0,
                    bgHover = C.gold, bgHoverA = 0.16, borderHover = C.gold, borderHoverA = 0 })
                r.text = UI.Text(r, 12, C.text)
                r.text:SetPoint("LEFT", 8, 0)
                r.text:SetPoint("RIGHT", -8, 0)
                r.sub = UI.Text(r, 10, C.textDim, { justify = "RIGHT" })
                r.sub:SetPoint("RIGHT", -8, 0)
                r:HookScript("OnEnter", function(row)
                    if row.item and row.item.tooltip then
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(row.item.text, rgb(C.goldSoft))
                        GameTooltip:AddLine(row.item.tooltip, C.text[1], C.text[2], C.text[3], true)
                        GameTooltip:Show()
                    end
                end)
                r:HookScript("OnLeave", function() GameTooltip:Hide() end)
                r:SetScript("OnClick", function(row)
                    close()
                    if row.item.disabled then return end
                    dd.selected = row.item.value
                    dd:SetLabel(row.item.text)
                    if row.item.font then dd.label:SetFont(row.item.font, 12 * ((S.db and S.db.fontScale) or 1)) end
                    if dd.onSelect then dd.onSelect(row.item.value, row.item) end
                end)
                rows[i] = r
            end
            r.item = item
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 6, y)
            r:SetPoint("TOPRIGHT", -6, y)
            r.text:SetText(item.text)
            if item.font then r.text:SetFont(item.font, 13) else UI.SetFont(r.text, 12, false) end
            r.text:SetTextColor(rgb(item.color or (item.disabled and C.textMute) or C.text))
            r.sub:SetText(item.sub or "")
            r:Show()
            y = y - 22
        end
        for i = #self.items + 1, #rows do rows[i]:Hide() end
        menu:SetSize(math.max(w, 170), -y + 6)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
        menu:SetScale(self:GetEffectiveScale() / UIParent:GetEffectiveScale())
        menu:SetAlpha(0)
        menu:Show()
        UI.Tween(menu, { 0 }, { 1 }, 0.12, function(v) menu:SetAlpha(v[1]) end)
    end

    dd:SetScript("OnClick", function(self)
        if menu:IsShown() then close() else self:Open() end
    end)
    dd:HookScript("OnHide", close)
    return dd
end

---------------------------------------------------------------------------
-- Tabs: segmented pill control with a sliding highlight
---------------------------------------------------------------------------
function UI.Tabs(parent, labels, onSelect)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(28)
    UI.Backdrop(bar, C.bg, C.border, 0.55, 9)
    bar:SetBackdropBorderColor(rgb(C.border, 0.6))
    bar.buttons = {}
    local slider = CreateFrame("Frame", nil, bar)
    UI.Backdrop(slider, C.gold, C.goldDim, 0.16, 7)
    slider:SetBackdropBorderColor(rgb(C.goldDim, 0.8))
    slider:SetHeight(22)
    local x = 3
    for i, text in ipairs(labels) do
        local b = CreateFrame("Button", nil, bar)
        b.label = UI.Text(b, 11, C.textDim, { head = true, justify = "CENTER" })
        b.label:SetPoint("CENTER", 0, 0)
        b.label:SetText(text)
        b:SetSize(b.label:GetStringWidth() + 22, 22)
        b:SetPoint("LEFT", bar, "LEFT", x, 0)
        b.__x = x
        x = x + b:GetWidth() + 2
        b:SetScript("OnClick", function() bar:Select(i) end)
        b:SetScript("OnEnter", function(self) if bar.selected ~= i then self.label:SetTextColor(rgb(C.text)) end end)
        b:SetScript("OnLeave", function(self) if bar.selected ~= i then self.label:SetTextColor(rgb(C.textDim)) end end)
        bar.buttons[i] = b
    end
    bar:SetWidth(x + 1)
    function bar:Select(i)
        local prev = self.selected
        self.selected = i
        for j, b in ipairs(self.buttons) do b.label:SetTextColor(rgb(j == i and C.goldSoft or C.textDim)) end
        local b = self.buttons[i]
        local toX, toW = b.__x, b:GetWidth()
        local function place(v)
            slider:ClearAllPoints()
            slider:SetPoint("LEFT", self, "LEFT", v[1], 0)
            slider:SetWidth(v[2])
        end
        if prev and slider.cur then
            UI.Tween(slider, slider.cur, { toX, toW }, 0.2, function(v) slider.cur = v; place(v) end)
        else
            slider.cur = { toX, toW }
            place(slider.cur)
        end
        if onSelect then onSelect(i) end
    end
    return bar
end

---------------------------------------------------------------------------
-- Toggle switch (replaces the old checkbox, same API)
---------------------------------------------------------------------------
function UI.Checkbox(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    local track = CreateFrame("Frame", nil, b)
    track:SetSize(34, 18)
    track:SetPoint("LEFT", 0, 0)
    UI.Backdrop(track, C.bgRaised, C.border, 0.9, 9)
    local knob = CreateFrame("Frame", nil, track)
    knob:SetSize(14, 14)
    UI.Backdrop(knob, C.text, C.text, 1, 7)
    knob:SetBackdropBorderColor(0, 0, 0, 0)
    local text = UI.Text(b, 12, C.text)
    text:SetPoint("LEFT", track, "RIGHT", 10, 0)
    text:SetText(label)
    b:SetWidth(text:GetStringWidth() + 48)
    b.label = text

    local state = { 0 } -- 0 off .. 1 on
    local function render(v)
        local p = v[1]
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", track, "LEFT", 2 + 16 * p, 0)
        local on, off = C.good, C.bgRaised
        track:SetBackdropColor(off[1] + (on[1] - off[1]) * p, off[2] + (on[2] - off[2]) * p, off[3] + (on[3] - off[3]) * p, 0.95)
        track:SetBackdropBorderColor(rgb(C.border, 1 - p))
        knob:SetBackdropColor(0.62 + 0.38 * p, 0.6 + 0.4 * p, 0.56 + 0.44 * p, 1)
        state = v
    end
    function b:Refresh(animate)
        local target = get() and 1 or 0
        if animate then
            UI.Tween(track, state, { target }, 0.16, render)
        else
            render({ target })
        end
    end
    b:SetScript("OnClick", function(self) set(not get()); self:Refresh(true) end)
    b:SetScript("OnEnter", function() text:SetTextColor(rgb(C.goldSoft)) end)
    b:SetScript("OnLeave", function() text:SetTextColor(rgb(C.text)) end)
    b:Refresh(false)
    return b
end
UI.Toggle = UI.Checkbox

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------
function UI.Slider(parent, label, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(38)
    local text = UI.Text(f, 12, C.text)
    text:SetPoint("TOPLEFT", 0, 0)
    local value = UI.Text(f, 12, C.goldSoft, { justify = "RIGHT" })
    value:SetPoint("TOPRIGHT", 0, 0)
    text:SetText(label)
    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPLEFT", 0, -22)
    track:SetPoint("TOPRIGHT", 0, -22)
    track:SetHeight(6)
    UI.Backdrop(track, C.bg, C.border, 0.8, 3)
    local fillHost = CreateFrame("Frame", nil, track)
    fillHost:SetPoint("TOPLEFT"); fillHost:SetPoint("BOTTOMLEFT")
    local fill = UI.RoundLayer(fillHost, "round", 3, "ARTWORK")
    fill:SetColor(rgb(C.gold))
    local knob = CreateFrame("Frame", nil, track)
    knob:SetSize(14, 14)
    UI.Backdrop(knob, C.goldSoft, C.bg, 1, 7)
    knob:SetBackdropBorderColor(rgb(C.bg, 0.9))
    knob:SetFrameLevel(track:GetFrameLevel() + 3)

    local function render()
        local v = get()
        local p = (v - minV) / (maxV - minV)
        local w = track:GetWidth() * p
        fillHost:SetWidth(math.max(6, w))
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", track, "LEFT", w, 0)
        value:SetText(fmt and fmt(v) or tostring(v))
    end
    local function fromCursor()
        local x = GetCursorPosition() / track:GetEffectiveScale()
        local p = (x - track:GetLeft()) / track:GetWidth()
        p = math.max(0, math.min(1, p))
        local v = minV + (maxV - minV) * p
        v = math.floor(v / step + 0.5) * step
        set(v)
        render()
    end
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self)
        fromCursor()
        self:SetScript("OnUpdate", fromCursor)
    end)
    track:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    track:SetScript("OnSizeChanged", render)
    f.Refresh = render
    C_Timer.After(0, render)
    return f
end

---------------------------------------------------------------------------
-- Window shell
---------------------------------------------------------------------------
function UI.Window(name, title, width, height, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetFrameStrata(opts.strata or "MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    UI.Backdrop(f, C.bg, C.border, S.db and S.db.alpha or 0.86, 14)
    -- visible frame: soft dark shadow outside + a gold rim + a faint inner line
    local shadow = UI.RoundLayer(f, "glow", 22, "BACKGROUND", -8, 8)
    shadow:SetColor(0, 0, 0, 0.6)
    f.__border:SetCorner(14)
    f:SetBackdropBorderColor(rgb(C.goldDim, 0.85))
    local innerHost = CreateFrame("Frame", nil, f)
    innerHost:SetPoint("TOPLEFT", 1, -1)
    innerHost:SetPoint("BOTTOMRIGHT", -1, 1)
    innerHost:SetFrameLevel(f:GetFrameLevel())
    local inner = UI.RoundLayer(innerHost, "ring", 13, "BACKGROUND", -4)
    inner:SetColor(rgb(C.text, 0.05))
    f.SetBorderColor = function(self, col, a) self:SetBackdropBorderColor(rgb(col, a or 0.85)) end

    -- warm glow at the top, kept inside the rounded corners
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    glow:SetPoint("TOPLEFT", 10, -1)
    glow:SetPoint("TOPRIGHT", -10, -1)
    glow:SetHeight(80)
    UI.Gradient(glow, "VERTICAL", C.gold, 0, C.gold, 0.06)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(36)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if opts.lockKey and S.db[opts.lockKey] then return end
        f:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        if opts.onMoved then opts.onMoved(f) end
    end)
    f.header = header

    local barHost = CreateFrame("Frame", nil, header)
    barHost:SetSize(3, 16)
    barHost:SetPoint("LEFT", 14, 0)
    UI.RoundLayer(barHost, "round", 1.5, "ARTWORK"):SetColor(rgb(C.gold))

    local brand = UI.Text(header, 15, C.text, { head = true })
    brand:SetPoint("LEFT", barHost, "RIGHT", 8, 0)
    brand:SetText(title or "|cffd4a24cSaked|r|cffe6e1d8XP|r")
    f.brand = brand

    local close = UI.GlyphButton(header, "x", "Cerrar")
    close:SetPoint("RIGHT", -10, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeButton = close

    local sep = UI.Line(f, C.border, 0.7, 1)
    sep:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 14, 0)
    sep:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -14, 0)

    -- fade in when opened
    f:HookScript("OnShow", function(self)
        self:SetAlpha(0)
        UI.Tween(self, { 0 }, { 1 }, 0.18, function(v) self:SetAlpha(v[1]) end)
    end)

    if opts.escClose then tinsert(UISpecialFrames, name) end
    return f
end

S:On("SETTINGS_CHANGED", function() UI.ApplyFonts() end)
S:On("LOGIN", function() UI.CollectFonts() end)
