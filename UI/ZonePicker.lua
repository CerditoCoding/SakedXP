-- SakedXP · Zone picker
-- Opens when a zone guide is finished (or on demand): compare the zones that
-- fit your level, see dungeon / pros / cons / trainers / vendors / rares,
-- then load the guide you want.

local _, S = ...
local C, UI, B = S.C, S.UI, S.Bridge
local rgb = UI.rgb

local P = {}
S.ZonePicker = P

local frame, list, detail
local rows = {}
local selected, showAll = nil, false
local context = {}

---------------------------------------------------------------------------
-- Guides for a zone (filtered by faction / class)
---------------------------------------------------------------------------
-- Written guides first (sorted by level), then the automatic route.
function P.GuidesForZone(z)
    local out, seen = {}, {}
    for _, key in ipairs(z.guides) do
        for _, g in ipairs(B.SearchGuides(key)) do
            if not seen[g.id] then
                seen[g.id] = true
                out[#out + 1] = g
            end
        end
    end
    table.sort(out, function(a, b)
        local la = tonumber(a.name:match("^(%d+)")) or 999
        local lb = tonumber(b.name:match("^(%d+)")) or 999
        return la < lb
    end)
    if z.mapID and S.DB.Ready() then
        out[#out + 1] = { kind = "dynamic", map = z.mapID, name = "Ruta automática: " .. (z.nameES or z.name),
            group = "Todas las misiones disponibles para vos" }
    end
    return out
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function bulletList(parent, items, color, width)
    local fs = UI.Text(parent, 12, C.text, { justifyV = "TOP" })
    fs:SetWidth(width)
    fs:SetSpacing(3)
    local lines = {}
    for _, it in ipairs(items or {}) do
        lines[#lines + 1] = S.Color(color, "•") .. "  " .. it
    end
    fs:SetText(#lines > 0 and table.concat(lines, "\n") or S.Color("textMute", "Sin datos"))
    return fs
end

local function build()
    frame = UI.Window("SakedXPZonePicker", nil, 720, 470, { strata = "HIGH", escClose = true })
    frame:SetPoint("CENTER")
    frame:Hide()
    frame.brand:SetText(S.Color("gold", "Próxima zona"))

    frame.subtitle = UI.Text(frame.header, 11, C.textDim)
    frame.subtitle:SetPoint("LEFT", frame.brand, "RIGHT", 12, -1)

    -- left: zone list
    local left = UI.Panel(frame, C.bgAlt, C.border, 0.55, 12)
    left:SetPoint("TOPLEFT", 10, -40)
    left:SetPoint("BOTTOMLEFT", 10, 46)
    left:SetWidth(230)
    local ls, lc = UI.Scroll(left)
    ls:SetPoint("TOPLEFT", 4, -4)
    ls:SetPoint("BOTTOMRIGHT", -4, 30)
    list = lc
    local lsep = UI.Line(left, C.border, 1, 1)
    lsep:SetPoint("BOTTOMLEFT", 6, 28)
    lsep:SetPoint("BOTTOMRIGHT", -6, 28)

    -- right: detail
    detail = UI.Panel(frame, C.bgAlt, C.border, 0.55, 12)
    detail:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    detail:SetPoint("BOTTOMRIGHT", -10, 46)

    detail.name = UI.Text(detail, 18, C.goldSoft, { head = true })
    detail.name:SetPoint("TOPLEFT", 14, -12)
    detail.newPill = UI.Pill(detail, "NUEVA", C.amber)
    detail.newPill:SetPoint("LEFT", detail.name, "RIGHT", 8, 0)
    detail.levels = UI.Pill(detail, "", C.goldDim)
    detail.levels:SetPoint("TOPRIGHT", -12, -14)
    detail.sub = UI.Text(detail, 11, C.textDim)
    detail.sub:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
    detail.sub:SetPoint("RIGHT", -12, 0)
    detail.sub:SetWordWrap(true)

    detail.tabs = UI.Tabs(detail, { "Resumen", "Mazmorras", "Comercio", "Raros" }, function(i) P.ShowTab(i) end)
    detail.tabs:SetPoint("TOPLEFT", 12, -64)
    detail.tabs:SetPoint("TOPRIGHT", -12, -64)

    local ds, dc = UI.Scroll(detail)
    ds:SetPoint("TOPLEFT", 12, -94)
    ds:SetPoint("BOTTOMRIGHT", -8, 8)
    detail.scroll, detail.content = ds, dc
    detail.widgets = {}

    -- footer: guide selection
    local foot = CreateFrame("Frame", nil, frame)
    foot:SetPoint("BOTTOMLEFT", 10, 10)
    foot:SetPoint("BOTTOMRIGHT", -10, 10)
    foot:SetHeight(26)
    local gl = UI.Text(foot, 10, C.goldDim, { head = true })
    gl:SetPoint("LEFT", 0, 0)
    gl:SetText("GUÍA")
    frame.guideDD = UI.Dropdown(foot, 300, "Elegí una guía…")
    frame.guideDD:SetPoint("LEFT", gl, "RIGHT", 10, 0)
    frame.guideDD:SetOnSelect(function(value) frame.chosenGuide = value end)
    frame.load = UI.Button(foot, "Cargar guía", "primary", 120, 24)
    frame.load:SetPoint("RIGHT", 0, 0)
    frame.load:SetScript("OnClick", function()
        local g = frame.chosenGuide
        if g and B.LoadGuide(g) then
            frame:Hide()
            if S.GuideWindow then S.GuideWindow.Show() end
        end
    end)
    frame.keep = UI.Button(foot, "Seguir con la actual", "subtle", 140, 24)
    frame.keep:SetPoint("RIGHT", frame.load, "LEFT", -8, 0)
    frame.keep:SetScript("OnClick", function() frame:Hide() end)

    frame.showAll = UI.Checkbox(left, "Ver todas las zonas", function() return showAll end, function(v)
        showAll = v
        P.RenderList()
    end)
    frame.showAll:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 10, 5)
end

---------------------------------------------------------------------------
-- Zone list
---------------------------------------------------------------------------
local FIT = {
    ideal = { "Ideal", C.good },
    low   = { "Un poco alta", C.amber },
    high  = { "Para terminar", C.info },
    all   = { "", C.textMute },
}

local function getRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, list)
    r:SetHeight(48)
    UI.Backdrop(r, C.bgRaised, C.border, 0.35, 10)
    UI.HoverFX(r, { bg = C.bgRaised, bgA = 0.35, border = C.border, borderA = 0.6,
        bgHover = C.bgRaised, bgHoverA = 0.85, borderHover = C.goldDim, borderHoverA = 0.9,
        bgSel = C.gold, bgSelA = 0.1, borderSel = C.gold, borderSelA = 0.95, glow = true, glowA = 0.22 })
    r.IsSelectedFX = function(self) return selected == self.zone end
    r.name = UI.Text(r, 13, C.text, { head = true })
    r.name:SetPoint("TOPLEFT", 14, -9)
    r.name:SetPoint("RIGHT", -60, 0)
    r.name:SetWordWrap(false)
    r.levels = UI.Text(r, 11, C.textDim)
    r.levels:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.fit = UI.Text(r, 10, C.good, { justify = "RIGHT" })
    r.fit:SetPoint("TOPRIGHT", -10, -9)
    r.badge = UI.Text(r, 9, C.amber, { head = true, justify = "RIGHT" })
    r.badge:SetPoint("BOTTOMRIGHT", -10, 9)
    local sh = CreateFrame("Frame", nil, r)
    sh:SetWidth(3); sh:SetPoint("TOPLEFT", 4, -10); sh:SetPoint("BOTTOMLEFT", 4, 10)
    local sl = UI.RoundLayer(sh, "round", 1.5, "ARTWORK")
    r.stripe = { SetVertexColor = function(_, ...) sl:SetColor(...) end }
    r:SetScript("OnClick", function(self) P.Select(self.zone) end)
    rows[i] = r
    return r
end

-- quests in your log that are done / turned in in each zone
local function carriedByZone()
    local out = {}
    local DB = S.DB
    if not DB.Ready() then return out end
    for id in pairs(S.GetQuestLogSet()) do
        local seen = {}
        local zone = DB.Q(id, "zoneOrSort")
        local m = zone and zone > 0 and DB.AreaToMap(zone)
        if m then seen[m] = true end
        local _, fm = DB.GiverInfo(id, "finishedBy")
        if fm then seen[fm] = true end
        for map in pairs(seen) do out[map] = (out[map] or 0) + 1 end
    end
    return out
end

function P.RenderList()
    local level = UnitLevel("player")
    local carried = carriedByZone()
    local entries
    if showAll then
        entries = {}
        local f = UnitFactionGroup("player") == "Alliance" and "A" or "H"
        for _, z in ipairs(S.Zones) do
            if S.Zones.Allowed(z, f) then entries[#entries + 1] = { zone = z, fit = "all" } end
        end
        table.sort(entries, function(a, b) return a.zone.levels[1] < b.zone.levels[1] end)
    else
        entries = S.Zones.ForPlayer(level, UnitFactionGroup("player"))
        -- zones you already carry quests for go first (keeps the original order otherwise)
        for i, e in ipairs(entries) do e.order = i end
        table.sort(entries, function(a, b)
            local ca = a.zone.mapID and carried[a.zone.mapID] or 0
            local cb = b.zone.mapID and carried[b.zone.mapID] or 0
            if (ca > 0) ~= (cb > 0) then return ca > 0 end
            return a.order < b.order
        end)
    end
    local y = 0
    for i, e in ipairs(entries) do
        local r = getRow(i)
        r.zone = e.zone
        r.name:SetText(e.zone.nameES or e.zone.name)
        local n = e.zone.mapID and carried[e.zone.mapID] or 0
        r.levels:SetText(("Nivel %d-%d"):format(e.zone.levels[1], e.zone.levels[2]) ..
            (n > 0 and S.Color("info", ("  ·  %d %s tuya%s"):format(n, n == 1 and "misión" or "misiones", n == 1 and "" or "s")) or ""))
        local fit = FIT[e.fit]
        r.fit:SetText(fit[1])
        r.fit:SetTextColor(rgb(fit[2]))
        r.badge:SetText(e.zone.new and "NUEVA" or "")
        r.stripe:SetVertexColor(rgb(e.zone.new and C.amber or C.goldDim, selected == e.zone and 1 or 0.35))
        r:RestFX()

        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
        r:Show()
        y = y + 52
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, y))
    if not selected or not showAll and not (function()
        for _, e in ipairs(entries) do if e.zone == selected then return true end end
    end)() then
        if entries[1] then P.Select(entries[1].zone) end
    end
    return entries
end

---------------------------------------------------------------------------
-- Detail
---------------------------------------------------------------------------
local function clearDetail()
    for _, w in ipairs(detail.widgets) do w:Hide() end
    wipe(detail.widgets)
end

local function add(w) detail.widgets[#detail.widgets + 1] = w; return w end

local function section(y, title, items, color, width)
    local h = add(UI.Text(detail.content, 10, C.goldDim, { head = true }))
    h:SetPoint("TOPLEFT", 0, -y)
    h:SetText(title:upper())
    y = y + 16
    local body = add(bulletList(detail.content, items, color or "gold", width))
    body:SetPoint("TOPLEFT", 0, -y)
    return y + body:GetStringHeight() + 14
end

function P.ShowTab(i)
    if not selected then return end
    clearDetail()
    local z = selected
    local width = detail.content:GetWidth() - 6
    if width < 50 then width = 420 end
    local y = 0

    if i == 1 then
        y = section(y, "Ventajas", z.pros, "good", width)
        y = section(y, "Desventajas", z.cons, "bad", width)
        local d = {}
        for _, dg in ipairs(z.dungeons or {}) do d[#d + 1] = S.Color("goldSoft", dg.name) .. S.Color("textDim", "  (" .. dg.levels .. ")") end
        y = section(y, "Mazmorra", #d > 0 and d or { S.Color("textDim", "Ninguna en la zona") }, "gold", width)
        if context.nextGuide then
            y = section(y, "Lo que sugiere la guía", { S.Color("goldSoft", context.nextGuide) }, "gold", width)
        end
    elseif i == 2 then
        if #(z.dungeons or {}) == 0 then
            y = section(y, "Mazmorras", { S.Color("textDim", "Esta zona no tiene mazmorra propia.") }, "gold", width)
        end
        for _, dg in ipairs(z.dungeons or {}) do
            local lines = { S.Color("textDim", "Niveles ") .. dg.levels }
            if dg.note then lines[#lines + 1] = dg.note end
            local fdj = _G.ForeverDungeonJournal_NS
            local data = fdj and fdj.DB and fdj.DB[(dg.name:gsub(" %(nuev[oa]%)", ""))]
            if data and data.quests then
                lines[#lines + 1] = ("%d misiones en el Diario de Mazmorras (/dj)"):format(#data.quests)
            end
            y = section(y, dg.name, lines, "gold", width)
        end
    elseif i == 3 then
        y = section(y, "Entrenadores de profesión", z.professions, "gold", width)
        y = section(y, "Comerciantes", z.vendors, "gold", width)
        y = section(y, "Recolección", { z.gathering or S.Color("textMute", "Sin datos") }, "gold", width)
    elseif i == 4 then
        local h = add(UI.Text(detail.content, 10, C.goldDim, { head = true }))
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetText("POSIBLES RAROS (" .. #(z.rares or {}) .. ")")
        y = y + 18
        local dd = detail.rareDD
        if not dd then
            dd = UI.Dropdown(detail.content, 260, "Elegí un raro…")
            detail.rareDD = dd
            detail.rareInfo = UI.Text(detail.content, 12, C.text, { justifyV = "TOP" })
            detail.rareTarget = UI.Button(detail.content, "Crear macro /tar", "ghost", 130, 22)
            dd:SetOnSelect(function(_, item)
                detail.rareInfo:SetText(S.Color("rare", item.text) .. "\n" .. (item.note or S.Color("textDim", "Sin notas")))
                detail.rareTarget.name = item.text
                detail.rareTarget:Show()
            end)
            detail.rareTarget:SetScript("OnClick", function(self)
                if not self.name then return end
                S.Print("para buscarlo usá:", S.Color("goldSoft", "/tar " .. self.name), "(o RareScanner si lo tenés activo).")
                if ChatFrame1EditBox then
                    ChatFrame_OpenChat("/tar " .. self.name)
                end
            end)
        end
        local items = {}
        for _, r in ipairs(z.rares or {}) do
            items[#items + 1] = { text = r[1], value = r[1], note = r[2], color = C.rare, sub = r[2] and r[2]:match("nv %d+") }
        end
        dd:SetItems(items)
        dd:SetLabel(#items > 0 and "Elegí un raro…" or "Sin raros registrados")
        dd:ClearAllPoints()
        dd:SetPoint("TOPLEFT", 0, -y)
        dd:Show()
        add(dd)
        y = y + 32
        detail.rareInfo:ClearAllPoints()
        detail.rareInfo:SetPoint("TOPLEFT", 0, -y)
        detail.rareInfo:SetWidth(width)
        detail.rareInfo:SetText(S.Color("textDim", "Seleccioná un raro de la lista para ver detalles."))
        detail.rareInfo:Show()
        add(detail.rareInfo)
        y = y + 44
        detail.rareTarget:ClearAllPoints()
        detail.rareTarget:SetPoint("TOPLEFT", 0, -y)
        detail.rareTarget:Hide()
        add(detail.rareTarget)
        y = y + 30
    end
    detail.content:SetHeight(y + 10)
    detail.scroll:SetVerticalScroll(0)
    detail.scroll:UpdateThumb()
end

function P.Select(z)
    selected = z
    detail.name:SetText(z.nameES or z.name)
    detail.newPill:SetShown(z.new and true or false)
    detail.levels:Set(("Nv %d-%d"):format(z.levels[1], z.levels[2]))
    local fac = z.faction == "A" and S.Color("info", "Alianza") or z.faction == "H" and S.Color("bad", "Horda") or S.Color("goldSoft", "Contestada")
    local sub = fac .. S.Color("textDim", "  ·  " .. (z.hub or ""))
    if z.access then sub = sub .. "\n" .. S.Color("textDim", "Cómo llegar: " .. z.access) end
    detail.sub:SetText(sub)

    -- guides
    local guides = P.GuidesForZone(z)
    local items = {}
    local preferred
    for _, g in ipairs(guides) do
        local item = { text = g.name, value = g,
            tooltip = g.kind == "dynamic" and "Arma la ruta con QuestieDB: sólo misiones que podés tomar ya, respetando cadenas y prerrequisitos." or g.group,
            color = g.kind == "dynamic" and C.info or nil }
        if context.nextGuide and g.name == context.nextGuide then
            item.color = C.goldSoft
            preferred = preferred or g
        end
        items[#items + 1] = item
    end
    frame.guideDD:SetItems(items)
    -- default: the guide RXP-style #next suggests, else the automatic route, else the first written guide
    local pick = preferred or guides[#guides] and guides[#guides].kind == "dynamic" and guides[#guides] or guides[1]
    frame.chosenGuide = pick
    frame.guideDD:SetLabel(pick and pick.name or "No hay guía para esta zona")
    frame.load:SetEnabled(pick ~= nil)

    P.RenderListHighlight()
    detail.tabs:Select(1)
end

function P.RenderListHighlight()
    for _, r in ipairs(rows) do
        if r:IsShown() then
            local sel = r.zone == selected
            r:RestFX()
            r.stripe:SetVertexColor(rgb(r.zone.new and C.amber or C.goldDim, sel and 1 or 0.35))
        end
    end
end

---------------------------------------------------------------------------
-- Open
---------------------------------------------------------------------------
function P.Open(reason, prevMeta, nextMeta)
    if not frame then build() end
    context = { reason = reason, prev = prevMeta, nextGuide = nextMeta and nextMeta.rawName }
    if reason == "finished" and prevMeta then
        frame.brand:SetText(S.Color("gold", "¡Zona completada!"))
        frame.subtitle:SetText("Terminaste " .. S.Color("goldSoft", prevMeta.name) .. ". Elegí cómo seguir.")
    else
        frame.brand:SetText(S.Color("gold", "Próxima zona"))
        frame.subtitle:SetText("Zonas recomendadas para nivel " .. UnitLevel("player"))
    end
    selected = nil
    -- preselect the zone of the guide RXP suggests next
    local suggested = nextMeta and S.Zones.ByName(nextMeta.name)
    frame:Show()
    P.RenderList()
    if suggested then P.Select(suggested) end
    PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878)
end

S:On("OPEN_ZONE_PICKER", function(reason) P.Open(reason) end)
S:On("ZONE_FINISHED", function(prevMeta, nextMeta)
    if not S.db.zonePopup then return end
    P.Open("finished", prevMeta, nextMeta)
end)
