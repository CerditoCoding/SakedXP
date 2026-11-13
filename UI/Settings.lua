-- SakedXP · Settings (tabbed, card sections, live font preview)

local _, S = ...
local C, UI = S.C, S.UI
local rgb = UI.rgb

local frame
local pages = {}

local function changed() S:Fire("SETTINGS_CHANGED") end

-- A page lays widgets out top to bottom inside rounded cards.
local function newPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 14, -84)
    page:SetPoint("BOTTOMRIGHT", -14, 14)
    page:Hide()
    page.y = 0
    page.cards = {}

    function page:Card(title, subtitle)
        local card = UI.Panel(self, C.bgAlt, C.border, 0.5, 12)
        card:SetPoint("TOPLEFT", 0, -self.y)
        card:SetPoint("TOPRIGHT", 0, -self.y)
        local head = UI.Section(card, title, subtitle, 13)
        head:SetPoint("TOPLEFT", 12, -10)
        head:SetPoint("RIGHT", -12, 0)
        card.y = 36
        function card:Add(w, h, fullWidth)
            w:ClearAllPoints()
            w:SetPoint("TOPLEFT", 14, -self.y)
            if fullWidth ~= false then w:SetPoint("RIGHT", -14, 0) end
            self.y = self.y + (h or 26)
        end
        function card:Finish()
            self:SetHeight(self.y + 10)
            page.y = page.y + self:GetHeight() + 10
        end
        return card
    end
    return page
end

local function toggle(card, label, key, after)
    local cb = UI.Checkbox(card, label, function() return S.db[key] end, function(v)
        S.db[key] = v
        if after then after(v) end
        changed()
    end)
    card:Add(cb, 26, false)
    return cb
end

local function slider(card, ...)
    local s = UI.Slider(card, ...)
    card:Add(s, 44)
    return s
end

local function hint(card, text)
    local fs = UI.Text(card, 10, C.textDim, { justifyV = "TOP" })
    fs:SetText(text)
    card:Add(fs, 18)
    return fs
end

local function fontItems(selectedKey)
    local items = {}
    for _, f in ipairs(UI.FONTS) do
        items[#items + 1] = { text = f.name, value = f.key, font = f.path,
            color = f.key == selectedKey and C.goldSoft or nil }
    end
    return items
end

local function fontName(key)
    for _, f in ipairs(UI.FONTS) do if f.key == key then return f.name end end
    return key
end

---------------------------------------------------------------------------
local function build()
    frame = UI.Window("SakedXPSettings", nil, 440, 600, { strata = "DIALOG", escClose = true })
    frame:SetPoint("CENTER")
    frame:Hide()
    frame.brand:SetText("Opciones")
    local ver = UI.Text(frame.header, 10, C.textMute)
    ver:SetPoint("LEFT", frame.brand, "RIGHT", 10, -1)
    ver:SetText("v" .. S.version)

    local tabs = UI.Tabs(frame, { "General", "Apariencia", "Ruta", "Progreso" }, function(i)
        for j, p in ipairs(pages) do p:SetShown(i == j) end
    end)
    tabs:SetPoint("TOPLEFT", 14, -46)

    -- General ---------------------------------------------------------------
    local p1 = newPage(frame); pages[1] = p1
    local c = p1:Card("Automatización", "Menos clics")
    toggle(c, "Aceptar misiones de la guía", "autoAccept")
    toggle(c, "Entregar misiones de la guía", "autoTurnin")
    hint(c, "Mantené Shift al hablar con un NPC para hacerlo a mano.")
    c:Finish()
    c = p1:Card("Navegación", "Flecha y mapa")
    toggle(c, "Flecha de navegación", "arrow")
    toggle(c, "Pines en el mapa del mundo", "mapPins")
    toggle(c, "Bloquear posición de las ventanas", "locked")
    c:Finish()
    c = p1:Card("Avisos")
    toggle(c, "Alertas inteligentes (cadenas y prerrequisitos)", "smartAlerts")
    toggle(c, "Pop-up al completar una zona", "zonePopup")
    toggle(c, "Checklist al entrar a una mazmorra", "dungeonPanel")
    c:Finish()

    -- Appearance -----------------------------------------------------------
    local p2 = newPage(frame); pages[2] = p2
    c = p2:Card("Fuentes", "Se aplican al instante")
    local lh = UI.Text(c, 11, C.textDim); lh:SetText("Títulos"); c:Add(lh, 18)
    local ddHead = UI.Dropdown(c, 200, fontName(S.db.fontHead))
    c:Add(ddHead, 32, false)
    local lb = UI.Text(c, 11, C.textDim); lb:SetText("Texto"); c:Add(lb, 18)
    local ddBody = UI.Dropdown(c, 200, fontName(S.db.fontBody))
    c:Add(ddBody, 32, false)
    slider(c, "Tamaño de letra", 0.8, 1.4, 0.05, function() return S.db.fontScale end,
        function(v) S.db.fontScale = v; changed() end, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
    local preview = UI.Panel(c, C.bg, C.border, 0.5, 10)
    preview:SetHeight(58)
    local pv1 = UI.Text(preview, 15, C.goldSoft, { head = true })
    pv1:SetPoint("TOPLEFT", 12, -10)
    pv1:SetText("Paso actual · Entregar misión")
    local pv2 = UI.Text(preview, 12, C.text)
    pv2:SetPoint("TOPLEFT", pv1, "BOTTOMLEFT", 0, -6)
    pv2:SetText("Hablá con Krom'rosh en Rog'mar  ·  8/10 lobos")
    c:Add(preview, 66)
    c:Finish()

    local function refreshFonts()
        ddHead:SetItems(fontItems(S.db.fontHead))
        ddBody:SetItems(fontItems(S.db.fontBody))
    end
    ddHead:SetOnSelect(function(key) S.db.fontHead = key; refreshFonts(); changed() end)
    ddBody:SetOnSelect(function(key) S.db.fontBody = key; refreshFonts(); changed() end)
    refreshFonts()

    c = p2:Card("Ventana")
    slider(c, "Escala", 0.6, 1.6, 0.05, function() return S.db.scale end,
        function(v) S.db.scale = v; changed() end, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
    slider(c, "Opacidad del fondo", 0.3, 1, 0.02, function() return S.db.alpha end,
        function(v) S.db.alpha = v; changed() end, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
    slider(c, "Tamaño de la flecha", 0.5, 2, 0.05, function() return S.db.arrowScale end,
        function(v) S.db.arrowScale = v; changed() end, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
    c:Finish()

    -- Route ------------------------------------------------------------------
    local p3 = newPage(frame); pages[3] = p3
    c = p3:Card("Ruta automática", "Cómo se arma")
    toggle(c, "Incluir misiones de élite / de grupo", "includeElite", function() S:Fire("REGENERATE") end)
    slider(c, "Misiones hasta X niveles por encima", 0, 5, 1, function() return S.db.levelAhead end,
        function(v) S.db.levelAhead = v end, function(v) return "+" .. v end)
    slider(c, "Ignorar misiones grises (X niveles por debajo)", 3, 10, 1, function() return S.db.greyRange end,
        function(v) S.db.greyRange = v end, function(v) return "-" .. v end)
    local regen = UI.Button(c, "Regenerar ruta ahora", "primary", 170, 28)
    regen:SetScript("OnClick", function() S:Fire("REGENERATE") end)
    c:Add(regen, 36, false)
    c:Finish()
    c = p3:Card("Ventana de guía")
    toggle(c, "Mostrar la guía de profesiones en la ventana", "showProfessions")
    slider(c, "Pasos siguientes visibles", 0, 6, 1, function() return S.db.upcoming end,
        function(v) S.db.upcoming = v; changed() end)
    slider(c, "Altura máxima", 200, 900, 10, function() return S.db.height end,
        function(v) S.db.height = v; changed() end, function(v) return v .. " px" end)
    c:Finish()

    -- Progress ---------------------------------------------------------------
    local p4 = newPage(frame); pages[4] = p4
    c = p4:Card("Progreso", "Si la guía se desfasa")
    local sync = UI.Button(c, "Sincronizar paso", "ghost", 150, 28)
    sync:SetScript("OnClick", function() S.Smart.Sync(false) end)
    c:Add(sync, 36, false)
    local clear = UI.Button(c, "Restablecer misiones saltadas", "danger", 220, 28)
    clear:SetScript("OnClick", function() S.Smart.ClearSkips() end)
    UI.Tooltip(clear, "Restablecer misiones saltadas", "Vuelve a mostrar todas las misiones que saltaste con 'Saltar cadena' o 'Saltar paso'.")
    c:Add(clear, 36, false)
    local reset = UI.Button(c, "Restablecer posición de ventanas", "subtle", 220, 28)
    reset:SetScript("OnClick", function() SlashCmdList.SAKEDXP("reset") end)
    c:Add(reset, 36, false)
    c:Finish()

    tabs:Select(1)
end

S:On("OPEN_SETTINGS", function()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end)
