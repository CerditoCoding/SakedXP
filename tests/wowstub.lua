-- A small stand-in for the WoW client API, enough to load SakedMap and drive it outside the game.
-- Widgets accept any method call; the ones the addon reads back return plausible values.
local S = { frames = {}, events = {}, cvars = { rotateMinimap = "1" }, now = 0, printed = {} }

local function widget(kind, name)
    local w = { _kind = kind, _shown = kind ~= "Frame", _scripts = {}, _w = 100, _h = 100, _children = {},
        _points = {}, _rotation = 0, _alpha = 1, _checked = false }
    local mt = {}
    mt.__index = function(t, k)
        local v = rawget(mt, k)
        if v then return v end
        if type(k) == "string" and k:match("^%u") then
            return function() return nil end -- any other method: accept and ignore
        end
        return nil -- plain fields the addon stores on widgets
    end
    function mt.SetScript(self, ev, fn) self._scripts[ev] = fn end
    function mt.GetScript(self, ev) return self._scripts[ev] end
    function mt.Show(self) self._shown = true end
    function mt.Hide(self) self._shown = false end
    function mt.SetShown(self, v) self._shown = v and true or false end
    function mt.IsShown(self) return self._shown end
    function mt.IsVisible(self) return self._shown end
    function mt.SetSize(self, w_, h_) self._w, self._h = w_, h_ end
    function mt.SetWidth(self, v) self._w = v end
    function mt.SetHeight(self, v) self._h = v end
    function mt.GetWidth(self) return self._w end
    function mt.GetHeight(self) return self._h end
    function mt.GetCenter(self) return 500, 400 end
    function mt.GetEffectiveScale() return 1 end
    function mt.SetPoint(self, ...) self._points[#self._points + 1] = { ... } end
    function mt.ClearAllPoints(self) self._points = {} end
    function mt.GetPoint(self) return "CENTER", nil, "CENTER", 0, 0 end
    function mt.SetRotation(self, r) assert(type(r) == "number", "SetRotation needs a number"); self._rotation = r end
    function mt.GetRotation(self) return self._rotation end
    function mt.SetAlpha(self, a) self._alpha = a end
    function mt.GetAlpha(self) return self._alpha end
    function mt.SetChecked(self, v) self._checked = v and true or false end
    function mt.GetChecked(self) return self._checked end
    function mt.SetText(self, t) self._text = t end
    function mt.GetText(self) return self._text end
    function mt.SetTexture(self, t) self._texture = t end
    function mt.SetTexCoord(self, ...) local n = select("#", ...); assert(n == 4 or n == 8, "texcoord args"); self._tc = { ... } end
    function mt.CreateTexture(self) local t = widget("Texture"); self._children[#self._children + 1] = t; return t end
    function mt.CreateFontString(self) local t = widget("FontString"); self._children[#self._children + 1] = t; return t end
    function mt.RegisterEvent(self, ev) S.events[ev] = S.events[ev] or {}; S.events[ev][self] = true end
    function mt.UnregisterEvent(self, ev) if S.events[ev] then S.events[ev][self] = nil end end
    function mt.GetObjectType(self) return self._kind end
    setmetatable(w, mt)
    if name then _G[name] = w end
    S.frames[#S.frames + 1] = w
    return w
end
S.widget = widget

function S.install()
    _G.CreateFrame = function(kind, name, parent, template)
        local f = widget(kind, name)
        if template == "UIPanelCloseButton" or template == "UIPanelButtonTemplate" then f._shown = true end
        return f
    end
    _G.UIParent = widget("Frame", "UIParent")
    _G.UISpecialFrames = {}
    _G.tinsert = table.insert
    _G.GameFontNormal, _G.GameFontHighlightSmall = {}, {}
    _G.GameTooltip = widget("GameTooltip", "GameTooltip")
    _G.GameTooltip_Hide = function() end
    _G.MinimapCompassTexture = widget("Texture", "MinimapCompassTexture")
    MinimapCompassTexture._shown = true
    _G.GetLocale = function() return S.locale or "esMX" end
    _G.GetTime = function() return S.now end
    _G.time = function() return math.floor(S.now) + 1700000000 end
    _G.GetCVar = function(k) return S.cvars[k] end
    _G.SetCVar = function(k, v) S.cvars[k] = tostring(v) end
    _G.GetCursorPosition = function() return S.cursor and S.cursor[1] or 500, S.cursor and S.cursor[2] or 400 end
    _G.IsShiftKeyDown = function() return S.shift end
    _G.GetInstanceInfo = function()
        if S.instance then return "Dungeon", "party", 1, "", 5, 0, false, S.instance end
        return "World", "none", 0, "", 0, 0, false, 0
    end
    _G.GetSubZoneText = function() return S.subzone or "" end
    _G.GetMinimapZoneText = function() return S.subzone or "" end
    _G.GetPlayerFacing = function() if S.instance then return nil end return S.facing end
    _G.UnitPosition = function() if S.instance then return nil end return S.px, S.py, 0, 0 end
    _G.GetUnitSpeed = function() return S.speed or 0, 7, 7, 4.72 end
    _G.IsPlayerMoving = function() return (S.speed or 0) > 0 end
    _G.IsFalling = function() return false end
    _G.IsSwimming = function() return false end
    _G.issecretvalue = function(v) return S.secret and S.secret[v] or false end
    _G.hooksecurefunc = function(name, fn)
        local orig = _G[name]
        _G[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
    end
    for _, n in ipairs({ "MoveForwardStart", "MoveForwardStop", "MoveBackwardStart", "MoveBackwardStop",
        "StrafeLeftStart", "StrafeLeftStop", "StrafeRightStart", "StrafeRightStop", "TurnLeftStart",
        "TurnLeftStop", "TurnRightStart", "TurnRightStop", "MoveAndSteerStart", "MoveAndSteerStop",
        "ToggleAutoRun", "StartAutoRun", "StopAutoRun" }) do
        _G[n] = function() end
    end
    _G.SlashCmdList = {}
    _G.print = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
        S.printed[#S.printed + 1] = table.concat(t, " ")
    end
    _G.unpack = unpack
end

function S.fire(event, ...)
    for f in pairs(S.events[event] or {}) do
        local fn = f._scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

-- advance time, running every OnUpdate script
function S.advance(seconds, step)
    step = step or 0.05
    local t = 0
    while t < seconds do
        S.now = S.now + step
        t = t + step
        for _, f in ipairs(S.frames) do
            local fn = f._scripts.OnUpdate
            if fn then fn(f, step) end
        end
    end
end

-- load the addon's files in .toc order (Data.xml expanded to its Script lines)
function S.loadAddon(root, ns)
    ns = ns or {}
    local toc = assert(io.open(root .. "/SakedMap/SakedMap.toc")):read("*a")
    for line in toc:gmatch("[^\r\n]+") do
        if not line:match("^##") and line:match("%S") then
            local path = line:gsub("\\", "/")
            if path:match("%.xml$") then
                local xml = assert(io.open(root .. "/SakedMap/" .. path)):read("*a")
                local dir = path:match("^(.*)/") or ""
                for file in xml:gmatch('<Script file="([^"]+)"') do
                    assert(loadfile(root .. "/SakedMap/" .. dir .. "/" .. file))("SakedMap", ns)
                end
            else
                assert(loadfile(root .. "/SakedMap/" .. path))("SakedMap", ns)
            end
        end
    end
    return ns
end

return S
