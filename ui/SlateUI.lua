-- Slate UI | standalone Roblox / Luau interface
-- No external assets or dependencies. Load this file as a ModuleScript or with loadstring.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local UI = {Version = "1.0.0", Windows = {}}
local palette = {
    Background = Color3.fromRGB(17, 21, 28), Sidebar = Color3.fromRGB(20, 26, 35),
    Card = Color3.fromRGB(27, 34, 45), Elevated = Color3.fromRGB(34, 43, 55),
    Accent = Color3.fromRGB(101, 212, 219), Text = Color3.fromRGB(234, 241, 248),
    Muted = Color3.fromRGB(139, 157, 177), Border = Color3.fromRGB(48, 61, 77),
    Success = Color3.fromRGB(114, 214, 163), Warning = Color3.fromRGB(240, 189, 104),
    Danger = Color3.fromRGB(255, 118, 108),
}
local themes = {Slate = table.clone(palette)}
local currentFont = Enum.Font.Gotham
local icons = {
    home = "⌂", house = "⌂", book = "▤", ["book-open"] = "▤", layers = "▱",
    eye = "◉", scan = "⌖", radar = "◎", target = "⊕", crosshair = "⊕",
    user = "♙", users = "♙", person = "♙", ["user-round"] = "♙",
    settings = "⚙", cog = "⚙", sliders = "☷", ["sliders-horizontal"] = "☷",
    zap = "ϟ", bolt = "ϟ", sword = "†", shield = "◇", flag = "⚑", map = "◇",
    gamepad = "✥", ["gamepad-2"] = "✥", globe = "◎", compass = "✥", star = "✧",
    info = "i", ["circle-help"] = "?", help = "?", check = "✓", x = "×",
    search = "⌕", bell = "♧", clock = "◷", activity = "⌁", chart = "▥",
    download = "↓", upload = "↑", refresh = "↻", ["refresh-cw"] = "↻",
    play = "▸", pause = "Ⅱ", trash = "×", copy = "▣", code = "‹›", terminal = "›_",
    ["chevron-right"] = "›", ["chevron-down"] = "⌄", ["external-link"] = "↗",
    sun = "☼", moon = "☾", wind = "≋", feather = "⌁", rocket = "↑", mouse = "⌘",
    keyboard = "⌨", palette = "◈", heart = "♡", lock = "▣", unlock = "◇",
    ["layout-dashboard"] = "▦", ["map-pinned"] = "⌖", ["scan-eye"] = "◉",
    ["person-standing"] = "♙", coins = "¥", smile = "◡", sparkles = "✧",
    square = "■", filter = "☷", focus = "⊕", scissors = "✂", save = "▣",
    power = "⏻", ghost = "♧", skull = "◇", ["circle-alert"] = "!", cpu = "▦",
    box = "▣", paintbrush = "╱", menu = "☰", ["circle-check"] = "✓",
}
local themed = {}
local textNodes = {}
local function new(class, props, parent)
    local item = Instance.new(class)
    for key, value in pairs(props or {}) do item[key] = value end
    item.Parent = parent
    return item
end
local function tint(item, property, name)
    item[property] = palette[name] or name
    themed[#themed + 1] = {item, property, name}
    return item
end
local function round(item, amount)
    new("UICorner", {CornerRadius = UDim.new(0, amount or 9)}, item)
    return item
end
local function border(item, transparency)
    return tint(new("UIStroke", {Thickness = 1, Transparency = transparency or 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, item), "Color", "Border")
end
local function label(parent, value, size, color, props)
    local base = {BackgroundTransparency = 1, BorderSizePixel = 0, Text = tostring(value or ""), Font = currentFont,
        TextSize = size or 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd}
    for k, v in pairs(props or {}) do base[k] = v end
    local item = new("TextLabel", base, parent)
    tint(item, "TextColor3", color or "Text")
    textNodes[#textNodes + 1] = item
    return item
end
local function button(parent, text, props)
    local item = new("TextButton", {BackgroundTransparency = 1, BorderSizePixel = 0, Text = text or "", Font = currentFont,
        TextSize = 14, AutoButtonColor = false, Size = UDim2.fromOffset(30, 30)}, parent)
    for k, v in pairs(props or {}) do item[k] = v end
    tint(item, "TextColor3", "Muted")
    textNodes[#textNodes + 1] = item
    return item
end
local function animate(item, props, duration)
    if not item or not item.Parent then return end
    TweenService:Create(item, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function icon(name)
    if icons[name] then return icons[name] end
    if type(name) == "string" then
        local length = utf8.len(name)
        if length and length <= 2 then return name end
    end
    return "◇"
end
local function color(value, fallback)
    if typeof(value) == "Color3" then return value end
    if type(value) == "string" then
        local hex = value:gsub("#", "")
        if #hex == 6 and tonumber(hex, 16) then return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)) end
    end
    return fallback
end
local function connect(window, signal, fn, element)
    local c = signal:Connect(fn)
    window.Connections[#window.Connections + 1] = c
    if element then element.Connections[#element.Connections + 1] = c end
    return c
end
local function disconnect(list)
    for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
    table.clear(list)
end
local function callback(window, fn, ...)
    if type(fn) ~= "function" or window.Destroyed then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok and not window.Destroyed then
            UI:Notify({Title = "Action failed", Content = tostring(err), Icon = "info", Duration = 6, Type = "error", Window = window})
            warn("[Slate] " .. tostring(err))
        end
    end)
end
local function screenParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and typeof(result) == "Instance" then return result end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function UI:AddTheme(theme, values)
    if type(theme) == "table" then values = theme; theme = values.Name or values.name or "Custom" end
    if type(theme) ~= "string" or type(values) ~= "table" then return false end
    local out = table.clone(palette)
    local aliases = {WindowBackground = "Background", Dialog = "Card", TextDisabled = "Muted", Outline = "Border"}
    for k, v in pairs(values) do
        local key = aliases[k] or k
        if out[key] then out[key] = color(v, out[key]) end
    end
    themes[theme] = out
    return true
end
function UI:SetTheme(name)
    local nextTheme = type(name) == "table" and name or themes[name]
    if not nextTheme then return false end
    for k in pairs(palette) do palette[k] = color(nextTheme[k], palette[k]) end
    local keep = {}
    for _, entry in ipairs(themed) do
        if entry[1].Parent then
            entry[1][entry[2]] = palette[entry[3]] or entry[3]
            keep[#keep + 1] = entry
        end
    end
    themed = keep
    for _, window in ipairs(self.Windows) do if not window.Destroyed and window.Refresh then window:Refresh() end end
    return true
end
function UI:SetFont(font)
    if typeof(font) ~= "EnumItem" or font.EnumType ~= Enum.Font then return false end
    currentFont = font
    local keep = {}
    for _, item in ipairs(textNodes) do if item.Parent then item.Font = font; keep[#keep + 1] = item end end
    textNodes = keep
    return true
end

function UI:Notify(options)
    options = type(options) == "table" and options or {Content = tostring(options)}
    local window = options.Window
    if not window or window.Destroyed then
        for i = #self.Windows, 1, -1 do if not self.Windows[i].Destroyed then window = self.Windows[i]; break end end
    end
    if not window or window.Destroyed then warn("[Slate] " .. tostring(options.Title or "Notice") .. ": " .. tostring(options.Content or options.Desc or "")); return end
    local host = window.ToastHost
    local toast = round(tint(new("Frame", {Size = UDim2.new(1, 0, 0, 80), BorderSizePixel = 0, BackgroundTransparency = 0.04}, host), "BackgroundColor3", "Elevated"), 11)
    border(toast, 0.1)
    local tone = options.Type == "error" and "Danger" or options.Type == "success" and "Success" or "Accent"
    round(tint(new("Frame", {Size = UDim2.new(0, 3, 1, -24), Position = UDim2.fromOffset(0, 12), BorderSizePixel = 0}, toast), "BackgroundColor3", tone), 2)
    label(toast, icon(options.Icon or "info"), 20, tone, {Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(24, 24), TextXAlignment = Enum.TextXAlignment.Center})
    label(toast, options.Title or "Slate", 13, "Text", {Position = UDim2.fromOffset(48, 12), Size = UDim2.new(1, -76, 0, 18), Font = Enum.Font.GothamMedium})
    label(toast, options.Content or options.Desc or "", 11, "Muted", {Position = UDim2.fromOffset(48, 34), Size = UDim2.new(1, -65, 0, 32), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
    local close = button(toast, "×", {Position = UDim2.new(1, -29, 0, 4), Size = UDim2.fromOffset(24, 24)})
    local alive, closeConnection = true, nil
    local function dismiss()
        if not alive then return end
        alive = false
        if closeConnection then closeConnection:Disconnect() end
        toast:Destroy()
    end
    closeConnection = connect(window, close.Activated, dismiss)
    local duration = tonumber(options.Duration) or 4
    if duration > 0 then task.delay(duration, function() if alive then dismiss() end end) end
    local toasts = host:GetChildren()
    local count = 0
    for _, item in ipairs(toasts) do if item:IsA("Frame") then count = count + 1; if count > 4 then item:Destroy() end end end
    return {Destroy = dismiss, Close = dismiss}
end

function UI:CreateWindow(options)
    options = options or {}
    local window = {Tabs = {}, Connections = {}, DestroyCallbacks = {}, Destroyed = false, Elements = {},
        SelectedTab = nil, ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift, UserScale = 1, Search = "", Library = self}
    self.Windows[#self.Windows + 1] = window
    if options.Theme then self:SetTheme(options.Theme) end
    local gui = new("ScreenGui", {Name = "SlateUI", ResetOnSpawn = false, IgnoreGuiInset = false,
        DisplayOrder = tonumber(options.DisplayOrder) or 80, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, screenParent())
    window.Gui = gui
    local preferred = options.Size
    local width, height = 744, 548
    if typeof(preferred) == "Vector2" then width, height = preferred.X, preferred.Y
    elseif typeof(preferred) == "UDim2" then width, height = preferred.X.Offset > 0 and preferred.X.Offset or width, preferred.Y.Offset > 0 and preferred.Y.Offset or height end
    width, height = math.max(560, width), math.max(400, height)
    window.Width, window.Height = width, height
    local shell = new("Frame", {Name = "Window", Size = UDim2.fromOffset(width, height), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1}, gui)
    local scale = new("UIScale", {Scale = 1}, shell)
    local shadow = round(new("Frame", {Size = UDim2.new(1, 16, 1, 16), Position = UDim2.fromOffset(-8, -4), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.68, BorderSizePixel = 0, ZIndex = 0}, shell), 19)
    local root = round(tint(new("Frame", {Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ClipsDescendants = true}, shell), "BackgroundColor3", "Background"), 13)
    border(root, 0)
    local header = tint(new("Frame", {Size = UDim2.new(1, 0, 0, 65), BorderSizePixel = 0, Active = true}, root), "BackgroundColor3", "Sidebar")
    tint(new("Frame", {Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0}, header), "BackgroundColor3", "Border")
    local logo = round(tint(new("Frame", {Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(32, 32), BorderSizePixel = 0}, header), "BackgroundColor3", "Accent"), 9)
    label(logo, "S", 18, "Background", {Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center})
    local title = label(header, options.Title or "SLATE", 15, "Text", {Position = UDim2.fromOffset(62, 14), Size = UDim2.new(1, -290, 0, 20), Font = Enum.Font.GothamBold})
    label(header, options.Author or options.Subtitle or "MIMIC COLLECTION", 10, "Muted", {Position = UDim2.fromOffset(63, 36), Size = UDim2.new(1, -285, 0, 14)})
    local badge = round(tint(new("Frame", {Position = UDim2.new(1, -209, 0, 23), Size = UDim2.fromOffset(98, 22), BorderSizePixel = 0}, header), "BackgroundColor3", "Card"), 6)
    label(badge, "●  " .. tostring(options.Tag or "SLATE  /  01"), 9, "Accent", {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
    local minimize = button(header, "−", {Position = UDim2.new(1, -98, 0, 11), Size = UDim2.fromOffset(44, 44), TextSize = 21})
    local close = button(header, "×", {Position = UDim2.new(1, -50, 0, 11), Size = UDim2.fromOffset(44, 44), TextSize = 21})
    local sidebar = tint(new("Frame", {Position = UDim2.fromOffset(0, 65), Size = UDim2.new(0, 163, 1, -65), BorderSizePixel = 0}, root), "BackgroundColor3", "Sidebar")
    tint(new("Frame", {Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0}, sidebar), "BackgroundColor3", "Border")
    local navCaption = label(sidebar, "WORKSPACE", 9, "Muted", {Position = UDim2.fromOffset(18, 19), Size = UDim2.new(1, -30, 0, 14)})
    local tabHost = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 1, -101), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0}, sidebar)
    new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, tabHost)
    local sidebarFoot = label(sidebar, "●  CLIENT READY", 9, "Muted", {Position = UDim2.new(0, 18, 1, -37), Size = UDim2.new(1, -30, 0, 18)})
    local content = new("Frame", {Position = UDim2.fromOffset(163, 65), Size = UDim2.new(1, -163, 1, -65), BackgroundTransparency = 1}, root)
    local breadcrumb = label(content, "WORKSPACE  /  OVERVIEW", 9, "Muted", {Position = UDim2.fromOffset(24, 17), Size = UDim2.new(1, -235, 0, 16)})
    local searchBack = round(tint(new("Frame", {Position = UDim2.new(1, -199, 0, 13), Size = UDim2.fromOffset(177, 27), BorderSizePixel = 0}, content), "BackgroundColor3", "Card"), 7)
    border(searchBack, 0.6)
    label(searchBack, "⌕", 19, "Muted", {Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(18, 27)})
    local search = tint(new("TextBox", {Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -38, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Search this tab…", ClearTextOnFocus = false, Font = currentFont, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left}, searchBack), "TextColor3", "Text")
    tint(search, "PlaceholderColor3", "Muted"); textNodes[#textNodes + 1] = search
    local mobileSearch = button(content, "⌕", {Position = UDim2.new(1, -54, 0, 4), Size = UDim2.fromOffset(44, 44), TextSize = 23, Visible = false})
    local pageTitle = label(content, "Overview", 23, "Text", {Position = UDim2.fromOffset(24, 51), Size = UDim2.new(1, -48, 0, 29), Font = Enum.Font.GothamBold})
    local pageDesc = label(content, "Everything in one place.", 11, "Muted", {Position = UDim2.fromOffset(25, 85), Size = UDim2.new(1, -50, 0, 18)})
    local pages = new("Frame", {Position = UDim2.fromOffset(23, 120), Size = UDim2.new(1, -46, 1, -152), BackgroundTransparency = 1}, content)
    local footer = label(content, "SLATE  /  " .. tostring(options.Footer or "Designed for clarity"), 9, "Muted", {Position = UDim2.new(0, 25, 1, -24), Size = UDim2.new(1, -66, 0, 14)})
    local resize = button(content, "⋱", {Position = UDim2.new(1, -22, 1, -23), Size = UDim2.fromOffset(19, 19), TextSize = 18})
    local pill = round(tint(button(gui, "", {Position = UDim2.new(0, 18, 0.6, 0), Size = UDim2.fromOffset(124, 46), BackgroundTransparency = 0.02, Visible = false}), "BackgroundColor3", "Sidebar"), 12)
    border(pill, 0.05)
    label(pill, "S", 17, "Accent", {Position = UDim2.fromOffset(13, 0), Size = UDim2.fromOffset(23, 42), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center})
    label(pill, "OPEN SLATE", 9, "Text", {Position = UDim2.fromOffset(44, 0), Size = UDim2.fromOffset(69, 42)})
    local toastHost = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), Size = UDim2.fromOffset(332, 378), BackgroundTransparency = 1}, gui)
    new("UIListLayout", {Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom}, toastHost)
    window.ToastHost, window.Root, window.Shell = toastHost, root, shell
    window.Content, window.Pages, window.Sidebar = content, pages, sidebar
    window.Statuses, window.FloatingCards = {}, {}
    window.Compact = false
    local function resizeLayout()
        if window.Destroyed then return end
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local compact = viewport.X < 760 or UIS.TouchEnabled and viewport.X < 1000
        window.Compact = compact
        -- Reflow the window at native touch size instead of shrinking a desktop panel.
        local uiScale = compact and math.min(window.UserScale, 1.2) or window.UserScale
        local actualWidth = math.min(window.Width, (viewport.X - 20) / uiScale)
        local actualHeight = math.min(window.Height, (viewport.Y - 46) / uiScale)
        scale.Scale = uiScale
        window.LayoutWidth, window.LayoutHeight = actualWidth, actualHeight
        shell.Size = UDim2.fromOffset(actualWidth, actualHeight)
        local sw = compact and 54 or 163
        sidebar.Size = UDim2.new(0, sw, 1, -65)
        content.Position = UDim2.fromOffset(sw, 65); content.Size = UDim2.new(1, -sw, 1, -65)
        navCaption.Visible = not compact; sidebarFoot.Visible = not compact
        tabHost.Position = UDim2.fromOffset(10, compact and 15 or 44)
        tabHost.Size = UDim2.new(1, -20, 1, compact and -30 or -101)
        for _, tab in ipairs(window.Tabs) do
            tab.NavTitle.Visible = not compact
            tab.NavIcon.Position = UDim2.fromOffset(compact and 4 or 10, 0)
            tab.NavIcon.Size = UDim2.fromOffset(compact and 32 or 22, 40)
        end
        toastHost.Size = UDim2.fromOffset(math.min(332, viewport.X - 36), 378)
        badge.Visible = not compact
        title.Size = UDim2.new(1, compact and -167 or -290, 0, 20)
        breadcrumb.Size = UDim2.new(1, compact and -44 or -235, 0, 16)
        searchBack.Visible = not compact or window.SearchOpen == true
        mobileSearch.Visible = compact
        breadcrumb.Visible = not compact or window.SearchOpen ~= true
        searchBack.Position = compact and UDim2.fromOffset(22, 13) or UDim2.new(1, -199, 0, 13)
        searchBack.Size = compact and UDim2.new(1, -83, 0, 32) or UDim2.fromOffset(177, 27)
        for _, e in ipairs(window.Elements) do if not e.Destroyed and e.Layout then e:Layout() end end
        for _, card in ipairs(window.FloatingCards) do if not card.Destroyed then card:Layout() end end
    end
    window.ResizeLayout = resizeLayout
    function window:SetUIScale(value)
        self.UserScale = math.clamp(tonumber(value) or 1, 0.5, 1.6); resizeLayout(); return self
    end
    function window:SetToggleKey(key)
        if type(key) == "string" then key = Enum.KeyCode[key] end
        if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then self.ToggleKey = key end
        return self
    end
    function window:Open() if not self.Destroyed then shell.Visible = true; pill.Visible = false end; return self end
    function window:Close() if not self.Destroyed then shell.Visible = false; pill.Visible = true end; return self end
    function window:Toggle() if shell.Visible then self:Close() else self:Open() end; return self end
    function window:OnDestroy(fn) if type(fn) == "function" then self.DestroyCallbacks[#self.DestroyCallbacks + 1] = fn end; return self end
    function window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        disconnect(self.Connections)
        for _, fn in ipairs(self.DestroyCallbacks) do local ok, err = pcall(fn); if not ok then warn("[Slate unload] " .. tostring(err)) end end
        table.clear(self.DestroyCallbacks)
        gui:Destroy()
        for i = #UI.Windows, 1, -1 do if UI.Windows[i] == self then table.remove(UI.Windows, i) end end
        local keepThemes, keepText = {}, {}
        for _, item in ipairs(themed) do if item[1].Parent then keepThemes[#keepThemes + 1] = item end end
        for _, item in ipairs(textNodes) do if item.Parent then keepText[#keepText + 1] = item end end
        themed, textNodes = keepThemes, keepText
    end
    function window:Notify(opts) opts = opts or {}; opts.Window = self; return UI:Notify(opts) end
    function window:SetTitle(value) title.Text = tostring(value); return self end
    function window:SetTheme(value) return UI:SetTheme(value) end
    function window:SetFont(value) return UI:SetFont(value) end
    function window:Refresh()
        for _, tab in ipairs(self.Tabs) do tab:_Refresh() end
        for _, element in ipairs(self.Elements) do if element.Refresh and not element.Destroyed then element:Refresh() end end
        for _, card in ipairs(self.FloatingCards) do if not card.Destroyed then card:Update({}) end end
    end
    local function applySearch()
        window.Search = string.lower(search.Text)
        for _, tab in ipairs(window.Tabs) do
            for _, element in ipairs(tab.Elements) do
                if not element.Destroyed then element:_ApplyVisibility() end
            end
        end
    end
    connect(window, search:GetPropertyChangedSignal("Text"), applySearch)
    connect(window, mobileSearch.Activated, function()
        window.SearchOpen = not window.SearchOpen
        resizeLayout()
        if window.SearchOpen then search:CaptureFocus() else search:ReleaseFocus() end
    end)
    connect(window, minimize.Activated, function() window:Close() end)
    connect(window, close.Activated, function() window:Close() end)
    connect(window, pill.Activated, function() window:Open() end)
    connect(window, UIS.InputBegan, function(input, processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode == window.ToggleKey then window:Toggle()
        elseif input.KeyCode == Enum.KeyCode.K and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then window:Open(); search:CaptureFocus() end
    end)
    local drag, dragStart, dragPosition, resizeStart, resizeOrigin, resizing
    connect(window, header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local p = input.Position
            if p.X > minimize.AbsolutePosition.X then return end
            drag, dragStart, dragPosition = input, p, shell.Position
        end
    end)
    connect(window, resize.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing, resizeStart, resizeOrigin = input, input.Position, Vector2.new(window.Width, window.Height)
        end
    end)
    connect(window, UIS.InputChanged, function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input == drag) then
            local d = input.Position - dragStart
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
            local centerX = dragPosition.X.Scale * viewport.X + dragPosition.X.Offset + d.X
            local centerY = dragPosition.Y.Scale * viewport.Y + dragPosition.Y.Offset + d.Y
            local halfW, halfH = shell.AbsoluteSize.X / 2, shell.AbsoluteSize.Y / 2
            shell.Position = UDim2.fromOffset(math.clamp(centerX, math.min(halfW, viewport.X / 2), math.max(viewport.X - halfW, viewport.X / 2)), math.clamp(centerY, math.min(halfH, viewport.Y / 2), math.max(viewport.Y - halfH, viewport.Y / 2)))
        elseif resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input == resizing) then
            local d = (input.Position - resizeStart) / scale.Scale
            window.Width, window.Height = math.clamp(resizeOrigin.X + d.X, 560, 1100), math.clamp(resizeOrigin.Y + d.Y, 400, 850)
            resizeLayout()
        end
    end)
    connect(window, UIS.InputEnded, function(input) if input == drag then drag = nil end; if input == resizing then resizing = nil end end)
    local cameraConnection
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        if workspace.CurrentCamera then cameraConnection = connect(window, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resizeLayout) end
        resizeLayout()
    end
    connect(window, workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    bindCamera()

    local function buildElement(tab, opts, rightWidth, kind)
        opts = type(opts) == "table" and opts or {Title = tostring(opts or "")}
        local element = {Window = window, Tab = tab, Connections = {}, Value = opts.Value, Title = tostring(opts.Title or kind or "Control"),
            Desc = tostring(opts.Desc or opts.Description or ""), Locked = opts.Locked == true, UserVisible = opts.Visible ~= false, Destroyed = false, Kind = kind}
        local row = round(tint(new("Frame", {Name = kind or "Control", Size = UDim2.new(1, -2, 0, 59), BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = #tab.Elements + 1}, tab.Page), "BackgroundColor3", "Card"), 9)
        border(row, 0.7)
        local leftInset = opts.Icon and 44 or 15
        if opts.Icon then label(row, icon(opts.Icon), 19, "Accent", {Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(22, 26), TextXAlignment = Enum.TextXAlignment.Center}) end
        local heading = label(row, element.Title, 12, "Text", {Position = UDim2.fromOffset(leftInset, 12), Size = UDim2.new(1, -leftInset - rightWidth - 16, 0, 18), Font = Enum.Font.GothamMedium})
        local desc = label(row, element.Desc, 10, "Muted", {Position = UDim2.fromOffset(leftInset, 33), Size = UDim2.new(1, -leftInset - rightWidth - 16, 0, 15), TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextTruncate = Enum.TextTruncate.None})
        local controls = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -13, 0.5, 0), Size = UDim2.fromOffset(rightWidth, 32), BackgroundTransparency = 1}, row)
        element.Row, element.Control, element.TitleLabel, element.DescLabel = row, controls, heading, desc
        local function layout()
            if not row.Parent then return end
            if element.CustomLayout then element:CustomLayout(); return end
            local stacked = window.Compact and rightWidth > 80
            local available = math.max(40, row.AbsoluteSize.X - leftInset - (stacked and 0 or rightWidth) - 16)
            local bounds = element.Desc ~= "" and TextService:GetTextSize(element.Desc, 10, currentFont, Vector2.new(available, 10000)) or Vector2.new(0, 0)
            local tall = element.Desc ~= "" and math.max(59, 35 + bounds.Y + 12) or 49
            heading.Size = UDim2.new(1, -leftInset - (stacked and 0 or rightWidth) - 16, 0, 18)
            desc.Size = UDim2.new(1, -leftInset - (stacked and 0 or rightWidth) - 16, 0, bounds.Y + 2)
            desc.Visible = element.Desc ~= ""
            heading.Position = UDim2.fromOffset(leftInset, element.Desc ~= "" and 12 or 15)
            if stacked then
                controls.AnchorPoint = Vector2.new(0, 0)
                controls.Position = UDim2.fromOffset(14, tall - 4)
                controls.Size = UDim2.new(1, -28, 0, 44)
                tall = tall + 50
            else
                controls.AnchorPoint = Vector2.new(1, 0.5)
                controls.Position = UDim2.new(1, -13, 0.5, 0)
                controls.Size = UDim2.fromOffset(rightWidth, 44)
            end
            row.Size = UDim2.new(1, -2, 0, tall)
        end
        function element:Layout() layout(); return self end
        function element:_ApplyVisibility()
            if self.Destroyed then return end
            local query = window.Search
            row.Visible = self.UserVisible and (query == "" or string.find(string.lower(self.Title .. " " .. self.Desc), query, 1, true) ~= nil)
        end
        function element:SetTitle(value) self.Title = tostring(value); heading.Text = self.Title; layout(); self:_ApplyVisibility(); return self end
        function element:SetDesc(value) self.Desc = tostring(value or ""); desc.Text = self.Desc; layout(); self:_ApplyVisibility(); return self end
        function element:SetVisible(value) self.UserVisible = value == true; self:_ApplyVisibility(); return self end
        element.Visible = element.SetVisible
        function element:Lock() self.Locked = true; self:Refresh(); return self end
        function element:Unlock() self.Locked = false; self:Refresh(); return self end
        function element:Refresh() heading.TextTransparency = self.Locked and 0.5 or 0; if self.Render then self:Render() end end
        function element:Destroy() if self.Destroyed then return end; self.Destroyed = true; disconnect(self.Connections); if self.Popup then self.Popup:Destroy() end; row:Destroy() end
        function element:SetValue(value, silent)
            if self.Value == value then return self end
            self.Value = value
            if self.Render then self:Render() end
            if not silent then callback(window, opts.Callback, value) end
            return self
        end
        element.Set = element.SetValue
        local hoverToken, tooltip = 0, nil
        local function clearTooltip()
            hoverToken = hoverToken + 1
            if tooltip then tooltip:Destroy(); tooltip = nil end
        end
        connect(window, row.MouseEnter, function()
            if UIS.TouchEnabled or element.Desc == "" then return end
            hoverToken = hoverToken + 1
            local token = hoverToken
            task.delay(0.65, function()
                if token ~= hoverToken or element.Destroyed or window.Destroyed or not row.Visible or not shell.Visible then return end
                local bound = TextService:GetTextSize(element.Desc, 11, currentFont, Vector2.new(244, 10000))
                local h = math.min(bound.Y + 22, window.LayoutHeight - 30)
                tooltip = round(tint(new("Frame", {Size = UDim2.fromOffset(268, h), BorderSizePixel = 0, ZIndex = 35}, root), "BackgroundColor3", "Elevated"), 8)
                border(tooltip, 0.1)
                local relative = (row.AbsolutePosition - root.AbsolutePosition) / scale.Scale
                tooltip.Position = UDim2.fromOffset(math.clamp(relative.X, 10, math.max(10, window.LayoutWidth - 278)), math.clamp(relative.Y + row.AbsoluteSize.Y / scale.Scale + 5, 10, math.max(10, window.LayoutHeight - h - 10)))
                label(tooltip, element.Desc, 11, "Text", {Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 1, -20), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 36})
            end)
        end, element)
        connect(window, row.MouseLeave, clearTooltip, element)
        connect(window, row.Destroying, clearTooltip, element)
        connect(window, row:GetPropertyChangedSignal("AbsoluteSize"), layout, element)
        tab.Elements[#tab.Elements + 1] = element; window.Elements[#window.Elements + 1] = element
        layout(); element:_ApplyVisibility()
        return element, opts
    end

    local function overlay(element, overlayTitle, desiredHeight)
        if element.Popup and element.Popup.Parent then element.Popup:Destroy(); element.Popup = nil; return end
        element.Popup = nil
        local catcher = new("TextButton", {Name = "Popup", BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.5, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 40}, root)
        local panel = round(tint(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.min(360, window.LayoutWidth - 24), math.min(desiredHeight or 350, window.LayoutHeight - 26)), BorderSizePixel = 0, Active = true, ZIndex = 41}, catcher), "BackgroundColor3", "Sidebar"), 12)
        border(panel, 0)
        label(panel, overlayTitle, 16, "Text", {Position = UDim2.fromOffset(20, 17), Size = UDim2.new(1, -65, 0, 24), Font = Enum.Font.GothamBold, ZIndex = 42})
        local x = button(panel, "×", {Position = UDim2.new(1, -48, 0, 7), Size = UDim2.fromOffset(44, 44), ZIndex = 42})
        element.Popup = catcher
        local function closePopup() if catcher.Parent then catcher:Destroy() end; if element.Popup == catcher then element.Popup = nil end end
        local a = connect(window, catcher.Activated, closePopup, element)
        local b = connect(window, x.Activated, closePopup, element)
        connect(window, catcher.Destroying, function() a:Disconnect(); b:Disconnect() end, element)
        return panel, closePopup
    end

    function window:Tab(opts)
        opts = type(opts) == "table" and opts or {Title = tostring(opts or "Tab")}
        local tab = {Title = opts.Title or "Tab", Desc = opts.Desc or opts.Description or "", Elements = {}, Window = self, Index = #self.Tabs + 1}
            local nav = round(tint(button(tabHost, "", {Size = UDim2.new(1, 0, 0, 46), LayoutOrder = #self.Tabs * 2 + 1, BackgroundTransparency = 1}), "BackgroundColor3", "Elevated"), 8)
        local bar = round(tint(new("Frame", {Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(2, 16), BorderSizePixel = 0, Visible = false}, nav), "BackgroundColor3", "Accent"), 1)
        local navIcon = label(nav, icon(opts.Icon or "layers"), 18, "Muted", {Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(22, 40), TextXAlignment = Enum.TextXAlignment.Center})
        local navTitle = label(nav, tab.Title, 11, "Muted", {Position = UDim2.fromOffset(43, 0), Size = UDim2.new(1, -50, 1, 0)})
        local page = new("ScrollingFrame", {Name = tab.Title, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarImageTransparency = 0.45}, pages)
        tint(page, "ScrollBarImageColor3", "Accent")
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        new("UIPadding", {PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 12)}, page)
        tab.Page, tab.Nav, tab.NavTitle, tab.NavIcon = page, nav, navTitle, navIcon
        function tab:_Refresh()
            local selected = window.SelectedTab == self
            nav.BackgroundTransparency = selected and 0 or 1
            navTitle.TextColor3 = selected and palette.Text or palette.Muted
            navIcon.TextColor3 = selected and palette.Accent or palette.Muted
            bar.Visible = selected
        end
        function tab:Select()
            if window.Destroyed then return self end
            window.SelectedTab = self
            for _, other in ipairs(window.Tabs) do other.Page.Visible = other == self; other:_Refresh() end
            pageTitle.Text = self.Title; pageDesc.Text = self.Desc ~= "" and self.Desc or "Your controls, organized."
            breadcrumb.Text = "WORKSPACE  /  " .. string.upper(self.Title)
            return self
        end
        connect(window, nav.Activated, function() tab:Select() end)
        connect(window, nav.MouseEnter, function() if window.SelectedTab ~= tab then animate(nav, {BackgroundTransparency = 0.55}) end end)
        connect(window, nav.MouseLeave, function() if window.SelectedTab ~= tab then animate(nav, {BackgroundTransparency = 1}) end end)
        self.Tabs[#self.Tabs + 1] = tab

        function tab:Button(settings)
            local e, o = buildElement(self, settings, 38, "Button")
            local hit = button(e.Control, "↗", {Size = UDim2.fromScale(1, 1), TextSize = 20})
            tint(hit, "TextColor3", "Accent")
            local whole = button(e.Row, "", {Size = UDim2.fromScale(1, 1), ZIndex = 2})
            connect(window, whole.Activated, function() if not e.Locked then callback(window, o.Callback) end end, e)
            connect(window, whole.MouseEnter, function() if not e.Locked then animate(e.Row, {BackgroundColor3 = palette.Elevated}) end end, e)
            connect(window, whole.MouseLeave, function() animate(e.Row, {BackgroundColor3 = palette.Card}) end, e)
            function e:Fire() if not self.Locked then callback(window, o.Callback) end; return self end
            return e
        end
        function tab:Toggle(settings)
            local e, o = buildElement(self, settings, 42, "Toggle")
            e.Value = o.Value ~= nil and o.Value == true or o.Value == nil and o.Default == true
            local track = round(button(e.Control, "", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(38, 22), BackgroundTransparency = 0}), 12)
            local dot = round(new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0}, track), 8)
            function e:Render()
                animate(track, {BackgroundColor3 = self.Value and palette.Accent or palette.Elevated, BackgroundTransparency = self.Locked and 0.5 or 0})
                animate(dot, {Position = UDim2.new(0, self.Value and 19 or 3, 0.5, 0), BackgroundColor3 = self.Value and palette.Background or palette.Muted})
            end
            local baseSet = e.SetValue
            function e:SetValue(value, silent) return baseSet(self, value == true, silent) end
            e.Set = e.SetValue
            local hit = button(e.Row, "", {Size = UDim2.fromScale(1, 1), ZIndex = 2})
            connect(window, hit.Activated, function() if not e.Locked then e:SetValue(not e.Value) end end, e)
            e:Render(); return e
        end
        function tab:Slider(settings)
            local e, o = buildElement(self, settings, 164, "Slider")
            local spec = type(o.Value) == "table" and o.Value or {}
            local low, high = tonumber(spec.Min or o.Min) or 0, tonumber(spec.Max or o.Max) or 100
            if high <= low then high = low + 1 end
            local step = tonumber(o.Step) or (o.Precise and 0.1 or 1)
            if step <= 0 then step = 1 end
            local function normalize(value) return math.clamp(math.floor(((tonumber(value) or low) - low) / step + 0.5) * step + low, low, high) end
            e.Value = normalize(spec.Default or o.Default or (type(o.Value) == "number" and o.Value) or low)
            local rail = round(tint(new("Frame", {Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, -60, 0, 4), BorderSizePixel = 0}, e.Control), "BackgroundColor3", "Elevated"), 2)
            local fill = round(tint(new("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0}, rail), "BackgroundColor3", "Accent"), 2)
            local dot = round(tint(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0}, rail), "BackgroundColor3", "Accent"), 5)
            local field = round(tint(new("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(48, 44), Text = "", BackgroundTransparency = 0, BorderSizePixel = 0, ClearTextOnFocus = false, Font = currentFont, TextSize = 11}, e.Control), "BackgroundColor3", "Elevated"), 6)
            tint(field, "TextColor3", "Text"); textNodes[#textNodes + 1] = field
            local hit = button(e.Control, "", {Position = UDim2.fromOffset(-4, 0), Size = UDim2.new(1, -52, 1, 0)})
            function e:Render()
                local amount = (self.Value - low) / (high - low)
                fill.Size = UDim2.fromScale(amount, 1); dot.Position = UDim2.fromScale(amount, 0.5)
                field.Text = string.format("%.4f", self.Value):gsub("0+$", ""):gsub("%.$", "")
                field.TextEditable = not self.Locked; dot.Visible = not self.Locked
            end
            local baseSet = e.SetValue
            function e:SetValue(value, silent) return baseSet(self, normalize(value), silent) end
            e.Set = e.SetValue
            local dragging
            local function slide(x) if not e.Locked then e:SetValue(low + math.clamp((x - rail.AbsolutePosition.X) / math.max(1, rail.AbsoluteSize.X), 0, 1) * (high - low)) end end
            connect(window, hit.InputBegan, function(input)
                if e.Locked then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = input; slide(input.Position.X) end
            end, e)
            connect(window, UIS.InputChanged, function(input) if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then slide(input.Position.X) end end, e)
            connect(window, UIS.InputEnded, function(input) if input == dragging then dragging = nil end end, e)
            connect(window, field.FocusLost, function() if not e.Locked then e:SetValue(field.Text) end; e:Render() end, e)
            e:Render(); return e
        end
        function tab:Input(settings)
            local e, o = buildElement(self, settings, 165, "Input")
            e.Value = tostring(o.Value or o.Default or "")
            local field = round(tint(new("TextBox", {Size = UDim2.new(1, 0, 1, 0), Text = e.Value, PlaceholderText = o.Placeholder or "Enter value…", ClearTextOnFocus = false, Font = currentFont, TextSize = 12, BorderSizePixel = 0}, e.Control), "BackgroundColor3", "Elevated"), 6)
            tint(field, "TextColor3", "Text"); tint(field, "PlaceholderColor3", "Muted"); textNodes[#textNodes + 1] = field
            new("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)}, field)
            function e:Render() if not field:IsFocused() then field.Text = self.Value end; field.TextEditable = not self.Locked end
            local baseSet = e.SetValue
            function e:SetValue(value, silent) return baseSet(self, tostring(value or ""), silent) end
            e.Set = e.SetValue
            connect(window, field.FocusLost, function(enter) if not e.Locked and (o.Finished ~= true or enter) then e:SetValue(field.Text) end; field.Text = e.Value end, e)
            if o.Live == true then connect(window, field:GetPropertyChangedSignal("Text"), function() if field:IsFocused() and not e.Locked then e:SetValue(field.Text) end end, e) end
            e:Render(); return e
        end
        function tab:Dropdown(settings)
            local e, o = buildElement(self, settings, 160, "Dropdown")
            e.Values = table.clone(o.Values or {})
            e.Multi = o.Multi == true
            local initial = o.Value or o.Default
            e.Value = e.Multi and (type(initial) == "table" and table.clone(initial) or initial and {initial} or {}) or (type(initial) == "table" and initial[1] or initial)
            local pick = round(tint(button(e.Control, "", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0}), "BackgroundColor3", "Elevated"), 6)
            local selected = label(pick, "Select…", 10, "Text", {Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -34, 1, 0)})
            label(pick, "⌄", 15, "Muted", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 0), Size = UDim2.new(0, 17, 1, 0), TextXAlignment = Enum.TextXAlignment.Center})
            function e:Render()
                if self.Multi then
                    local texts = {}; for _, value in ipairs(self.Value) do texts[#texts + 1] = tostring(value) end
                    selected.Text = #texts == 0 and "Select…" or table.concat(texts, ", ")
                else selected.Text = self.Value == nil and "Select…" or tostring(self.Value) end
                selected.TextTransparency = self.Locked and 0.5 or 0
            end
            function e:SetValue(value, silent)
                if self.Multi then
                    local values = type(value) == "table" and table.clone(value) or value ~= nil and {value} or {}
                    local same = #values == #self.Value
                    if same then for i, v in ipairs(values) do if self.Value[i] ~= v then same = false; break end end end
                    if same then return self end
                    self.Value = values
                else
                    if type(value) == "table" then value = value[1] end
                    if self.Value == value then return self end
                    self.Value = value
                end
                self:Render(); if not silent then callback(window, o.Callback, self.Multi and table.clone(self.Value) or self.Value) end; return self
            end
            e.Set = e.SetValue
            function e:Refresh(values) if type(values) == "table" then self.Values = table.clone(values) end; self:Render(); return self end
            function e:SetValues(values) return self:Refresh(values) end
            connect(window, pick.Activated, function()
                if e.Locked then return end
                local panel, dismiss = overlay(e, e.Title, math.min(400, 112 + #e.Values * 49))
                if not panel then return end
                local list = new("ScrollingFrame", {Position = UDim2.fromOffset(16, 57), Size = UDim2.new(1, -32, 1, -76), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ZIndex = 42}, panel)
                new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, list)
                for index, value in ipairs(e.Values) do
                    local choice = round(tint(button(list, "", {Size = UDim2.new(1, -5, 0, 44), BackgroundTransparency = 0, LayoutOrder = index, ZIndex = 43}), "BackgroundColor3", "Card"), 6)
                    local function active() return e.Multi and table.find(e.Value, value) ~= nil or not e.Multi and e.Value == value end
                    local text = label(choice, tostring(value), 11, active() and "Accent" or "Text", {Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -40, 1, 0), ZIndex = 44})
                    local check = label(choice, active() and "✓" or "", 14, "Accent", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0, 22, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 44})
                    local c
                    c = connect(window, choice.Activated, function()
                        if e.Multi then
                            local values = table.clone(e.Value); local found = table.find(values, value)
                            if found then table.remove(values, found) else values[#values + 1] = value end
                            e:SetValue(values); check.Text = active() and "✓" or ""; text.TextColor3 = active() and palette.Accent or palette.Text
                        else e:SetValue(value); dismiss() end
                    end, e)
                    connect(window, choice.Destroying, function() c:Disconnect() end, e)
                end
            end, e)
            e:Render(); return e
        end
        function tab:Paragraph(settings)
            local e, o = buildElement(self, settings, 0, "Paragraph")
            e:SetDesc(o.Desc or o.Content or o.Description or "")
            function e:Set(value) if type(value) == "table" then if value.Title then self:SetTitle(value.Title) end; if value.Desc or value.Content then self:SetDesc(value.Desc or value.Content) end else self:SetDesc(value) end; return self end
            return e
        end
        function tab:Section(settings)
            local opts2 = type(settings) == "table" and settings or {Title = tostring(settings or "Section")}
            local e = buildElement(self, {Title = opts2.Title or "Section", Desc = opts2.Desc}, 0, "Section")
            e.Row.BackgroundTransparency = 1
            local stroke = e.Row:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Enabled = false end
            e.TitleLabel.TextColor3 = palette.Muted; e.TitleLabel.TextSize = 10; e.TitleLabel.Text = string.upper(e.Title)
            function e:Render() self.TitleLabel.TextColor3 = palette.Muted end
            return e
        end
        function tab:Divider()
            local e = buildElement(self, {Title = "", Desc = ""}, 0, "Divider")
            e.Row.Size = UDim2.new(1, -2, 0, 7); e.Row.BackgroundTransparency = 1
            local stroke = e.Row:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Enabled = false end
            tint(new("Frame", {Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0}, e.Row), "BackgroundColor3", "Border")
            disconnect(e.Connections)
            function e:Layout() end
            return e
        end
        function tab:Space(amount)
            local e = self:Divider()
            e.Row:ClearAllChildren(); e.Row.Size = UDim2.new(1, 0, 0, tonumber(amount) or 8)
            return e
        end
        function tab:Keybind(settings)
            local e, o = buildElement(self, settings, 104, "Keybind")
            local default = o.Value or o.Default or Enum.KeyCode.F
            if type(default) == "string" then default = Enum.KeyCode[default] or Enum.KeyCode.F end
            e.Value = default
            local key = round(tint(button(e.Control, "", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, TextSize = 11}), "BackgroundColor3", "Elevated"), 6)
            tint(key, "TextColor3", "Text")
            local listening = false
            function e:Render() key.Text = listening and "Press a key…" or (self.Value and self.Value.Name or "None") end
            function e:SetValue(value, silent)
                if type(value) == "string" then value = Enum.KeyCode[value] end
                if typeof(value) ~= "EnumItem" or value.EnumType ~= Enum.KeyCode then return self end
                if self.Value == value then return self end
                self.Value = value; self:Render(); if not silent then callback(window, o.ChangedCallback or o.OnChanged, value) end; return self
            end
            e.Set = e.SetValue
            connect(window, key.Activated, function() if not e.Locked then listening = true; e:Render() end end, e)
            connect(window, UIS.InputBegan, function(input, processed)
                if e.Locked or UIS:GetFocusedTextBox() then return end
                if listening and input.KeyCode ~= Enum.KeyCode.Unknown then
                    listening = false; if input.KeyCode ~= Enum.KeyCode.Escape then e:SetValue(input.KeyCode) end; e:Render()
                elseif not processed and input.KeyCode == e.Value then callback(window, o.Callback, e.Value) end
            end, e)
            e:Render(); return e
        end
        function tab:Colorpicker(settings)
            local e, o = buildElement(self, settings, 88, "Colorpicker")
            e.Value = color(o.Value or o.Default, palette.Accent)
            local swatch = round(button(e.Control, "", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 60, 1, 0), BackgroundTransparency = 0}), 6)
            border(swatch, 0.2)
            function e:Render() swatch.BackgroundColor3 = self.Value; swatch.BackgroundTransparency = self.Locked and 0.6 or 0 end
            local baseSet = e.SetValue
            function e:SetValue(value, silent) return baseSet(self, color(value, self.Value), silent) end
            e.Set = e.SetValue
            connect(window, swatch.Activated, function()
                if e.Locked then return end
                local panel = overlay(e, e.Title, 320)
                if not panel then return end
                local preview = round(new("Frame", {Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 0, 55), BackgroundColor3 = e.Value, BorderSizePixel = 0, ZIndex = 42}, panel), 9)
                local fields = {}
                local hex
                local function refreshFields()
                    local values = {math.round(e.Value.R * 255), math.round(e.Value.G * 255), math.round(e.Value.B * 255)}
                    preview.BackgroundColor3 = e.Value
                    for index, field in ipairs(fields) do field.Text = tostring(values[index]) end
                    if hex then hex.Text = "#" .. e.Value:ToHex():upper() end
                end
                for index, name in ipairs({"RED", "GREEN", "BLUE"}) do
                    local xScale = (index - 1) / 3
                    local xOffset = 20 - (index - 1) * 10
                    label(panel, name, 9, "Muted", {Position = UDim2.new(xScale, xOffset, 0, 130), Size = UDim2.new(1 / 3, -20, 0, 16), ZIndex = 42})
                    local field = round(tint(new("TextBox", {Position = UDim2.new(xScale, xOffset, 0, 152), Size = UDim2.new(1 / 3, -20, 0, 44), Text = "", ClearTextOnFocus = false, Font = currentFont, TextSize = 12, BorderSizePixel = 0, ZIndex = 42}, panel), "BackgroundColor3", "Card"), 6)
                    tint(field, "TextColor3", "Text"); textNodes[#textNodes + 1] = field; fields[index] = field
                    local c = connect(window, field.FocusLost, function()
                        local values = {e.Value.R * 255, e.Value.G * 255, e.Value.B * 255}; values[index] = math.clamp(tonumber(field.Text) or values[index], 0, 255)
                        e:SetValue(Color3.fromRGB(values[1], values[2], values[3])); refreshFields()
                    end, e)
                    connect(window, field.Destroying, function() c:Disconnect() end, e)
                end
                label(panel, "HEX COLOR", 9, "Muted", {Position = UDim2.fromOffset(20, 203), Size = UDim2.fromOffset(110, 16), ZIndex = 42})
                hex = round(tint(new("TextBox", {Position = UDim2.fromOffset(20, 226), Size = UDim2.new(1, -40, 0, 44), Text = "", ClearTextOnFocus = false, Font = currentFont, TextSize = 12, BorderSizePixel = 0, ZIndex = 42}, panel), "BackgroundColor3", "Card"), 6)
                tint(hex, "TextColor3", "Text"); textNodes[#textNodes + 1] = hex
                local hc = connect(window, hex.FocusLost, function() e:SetValue(hex.Text); refreshFields() end, e)
                connect(window, hex.Destroying, function() hc:Disconnect() end, e)
                label(panel, "Edit a channel or paste a six-digit hex color.", 10, "Muted", {Position = UDim2.fromOffset(20, 278), Size = UDim2.new(1, -40, 0, 16), ZIndex = 42})
                refreshFields()
            end, e)
            e:Render(); return e
        end
        tab.ColorPicker = tab.Colorpicker
        function tab:Status(settings)
            local e, o = buildElement(self, settings, 100, "Status")
            local stateBack = round(tint(new("Frame", {Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 0.35}, e.Control), "BackgroundColor3", "Elevated"), 6)
            local statusText = label(stateBack, "", 10, "Accent", {Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Center})
            e.Status = o.State or o.Status or o.Value or "Ready"
            e.Tone, e.FieldRows, e.FieldData = o.Tone, {}, {}
            local meter = round(tint(new("Frame", {Position = UDim2.new(0, 15, 1, -4), Size = UDim2.new(0, 0, 0, 2), BorderSizePixel = 0, Visible = false}, e.Row), "BackgroundColor3", "Accent"), 1)
            local function normalizeFields(fields)
                local result = {}
                if type(fields) ~= "table" then return result end
                if #fields > 0 then
                    for index, row in ipairs(fields) do
                        if type(row) == "table" then
                            result[#result + 1] = {Label = tostring(row.Label or row.Key or row.Title or row[1] or index), Value = tostring(row.Value or row[2] or "")}
                        else result[#result + 1] = {Label = tostring(index), Value = tostring(row)} end
                    end
                else
                    local keys = {}; for key in pairs(fields) do keys[#keys + 1] = key end
                    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
                    for _, key in ipairs(keys) do result[#result + 1] = {Label = tostring(key), Value = tostring(fields[key])} end
                end
                return result
            end
            function e:CustomLayout()
                local available = math.max(40, self.Row.AbsoluteSize.X - 30)
                local left = o.Icon and 44 or 15
                self.TitleLabel.Position = UDim2.fromOffset(left, 14)
                self.TitleLabel.Size = UDim2.new(1, -left - 125, 0, 19)
                self.TitleLabel.TextSize = 13
                self.Control.AnchorPoint = Vector2.new(1, 0)
                self.Control.Position = UDim2.new(1, -13, 0, 12)
                self.Control.Size = UDim2.fromOffset(100, 24)
                local bounds = self.Desc ~= "" and TextService:GetTextSize(self.Desc, 10, currentFont, Vector2.new(available, 10000)) or Vector2.new(0, 0)
                self.DescLabel.Position = UDim2.fromOffset(15, 46)
                self.DescLabel.Size = UDim2.new(1, -30, 0, bounds.Y + 2)
                self.DescLabel.Visible = self.Desc ~= ""
                local fieldsTop = self.Desc ~= "" and 53 + bounds.Y or 49
                local columns = self.Row.AbsoluteSize.X >= 410 and 2 or 1
                for index, field in ipairs(self.FieldRows) do
                    local column, rowIndex = (index - 1) % columns, math.floor((index - 1) / columns)
                    field.Frame.Position = UDim2.new(column / columns, 15 - column * 11, 0, fieldsTop + rowIndex * 34)
                    field.Frame.Size = UDim2.new(1 / columns, columns == 1 and -30 or -24, 0, 28)
                end
                local total = fieldsTop + math.ceil(#self.FieldRows / columns) * 34 + (#self.FieldRows > 0 and 10 or 1)
                self.Row.Size = UDim2.new(1, -2, 0, math.max(59, total))
            end
            function e:Update(fields)
                fields = type(fields) == "table" and fields or {Status = fields}
                if fields.Title then self:SetTitle(fields.Title) end
                if fields.Subtitle or fields.Desc or fields.Description or fields.Content then self:SetDesc(fields.Subtitle or fields.Desc or fields.Description or fields.Content) end
                if fields.State ~= nil or fields.Status ~= nil or fields.Value ~= nil then self.Status = fields.State or fields.Status or fields.Value end
                if fields.Tone then self.Tone = fields.Tone end
                local state = string.lower(tostring(self.Status))
                local tone = self.Tone or ((state == "error" or state == "failed") and "Danger") or ((state == "waiting" or state == "paused") and "Warning") or ((state == "success" or state == "running" or state == "active") and "Success") or "Accent"
                statusText.Text = "● " .. string.upper(tostring(self.Status))
                statusText.TextColor3 = palette[tone] or color(tone, palette.Accent)
                if fields.Fields or fields.Rows then
                    self.FieldData = normalizeFields(fields.Fields or fields.Rows)
                    while #self.FieldRows > #self.FieldData do self.FieldRows[#self.FieldRows].Frame:Destroy(); table.remove(self.FieldRows) end
                    for index, field in ipairs(self.FieldData) do
                        local row = self.FieldRows[index]
                        if not row then
                            local frame = round(tint(new("Frame", {Size = UDim2.new(1, -30, 0, 28), BorderSizePixel = 0, BackgroundTransparency = 0.45}, self.Row), "BackgroundColor3", "Elevated"), 5)
                            row = {Frame = frame, Label = label(frame, "", 9, "Muted", {Position = UDim2.fromOffset(9, 0), Size = UDim2.new(0.43, -9, 1, 0)}), Value = label(frame, "", 10, "Text", {Position = UDim2.new(0.43, 0, 0, 0), Size = UDim2.new(0.57, -9, 1, 0), TextXAlignment = Enum.TextXAlignment.Right})}
                            self.FieldRows[index] = row
                        end
                        row.Label.Text, row.Value.Text = string.upper(field.Label), field.Value
                    end
                end
                if fields.Progress ~= nil then
                    self.Progress = math.clamp(tonumber(fields.Progress) or 0, 0, 1)
                    meter.Visible = true; meter.Size = UDim2.new(self.Progress, -self.Progress * 30, 0, 2)
                end
                self:CustomLayout()
                return self
            end
            function e:Render() self:Update({}) end
            e.Set = e.Update
            e:Update(o); return e
        end
        tab.StatusCard = tab.Status
        if not self.SelectedTab then tab:Select() end
        resizeLayout()
        return tab
    end
    function window:SelectTab(index)
        local tab = type(index) == "number" and self.Tabs[index] or index
        if type(index) == "string" then for _, value in ipairs(self.Tabs) do if value.Title == index then tab = value; break end end end
        if type(tab) == "table" and tab.Select then tab:Select() end
        return self
    end
    function window:Divider()
        local line = tint(new("Frame", {Size = UDim2.new(1, -12, 0, 1), BackgroundTransparency = 0.5, BorderSizePixel = 0, LayoutOrder = #self.Tabs * 2}, tabHost), "BackgroundColor3", "Border")
        return {Destroy = function() line:Destroy() end}
    end
    function window:Status(settings)
        local tab = settings and settings.Tab or self.SelectedTab or self.Tabs[1]
        if not tab then tab = self:Tab({Title = "Overview", Icon = "home"}) end
        return tab:Status(settings)
    end
    function window:FloatingStatus(settings)
        settings = settings or {}
        local card = {Window = self, Connections = {}, Destroyed = false, Title = settings.Title or "Session status",
            Subtitle = settings.Subtitle or settings.Desc or settings.Description or "", State = settings.State or settings.Status or "idle",
            Tone = settings.Tone, Fields = {}, Rows = {}, UserVisible = settings.Visible ~= false}
        local frame = round(tint(new("Frame", {Name = "SlateFloatingStatus", Position = typeof(settings.Position) == "UDim2" and settings.Position or UDim2.fromOffset(18, 94),
            Size = UDim2.fromOffset(242, 134), BackgroundTransparency = 0.03, BorderSizePixel = 0, Active = true, Visible = card.UserVisible, ZIndex = 15}, gui), "BackgroundColor3", "Sidebar"), 11)
        border(frame, 0.05)
        round(tint(new("Frame", {Position = UDim2.fromOffset(0, 15), Size = UDim2.fromOffset(2, 18), BorderSizePixel = 0, ZIndex = 16}, frame), "BackgroundColor3", "Accent"), 1)
        local heading = label(frame, "", 12, "Text", {Position = UDim2.fromOffset(13, 12), Size = UDim2.new(1, -102, 0, 18), Font = Enum.Font.GothamMedium, ZIndex = 16})
        local state = label(frame, "", 8, "Accent", {Position = UDim2.new(1, -87, 0, 13), Size = UDim2.fromOffset(74, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 16})
        local detail = label(frame, "", 10, "Muted", {Position = UDim2.fromOffset(13, 37), Size = UDim2.new(1, -26, 0, 15), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 16})
        local line = tint(new("Frame", {Position = UDim2.fromOffset(13, 61), Size = UDim2.new(1, -26, 0, 1), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 16}, frame), "BackgroundColor3", "Border")
        card.Frame, card.Row = frame, frame
        function card:Layout()
            if self.Destroyed or window.Destroyed then return self end
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
            local w = math.min(tonumber(settings.Width) or 242, viewport.X - 24)
            local bounds = self.Subtitle ~= "" and TextService:GetTextSize(self.Subtitle, 10, currentFont, Vector2.new(w - 26, 10000)) or Vector2.new(0, 0)
            local descriptionHeight = self.Subtitle ~= "" and math.min(28, bounds.Y + 1) or 0
            local start = descriptionHeight > 0 and 46 + descriptionHeight or 40
            detail.Visible = descriptionHeight > 0
            detail.Size = UDim2.new(1, -26, 0, descriptionHeight)
            line.Position = UDim2.fromOffset(13, start - 7); line.Visible = #self.Rows > 0
            for index, row in ipairs(self.Rows) do row.Frame.Position = UDim2.fromOffset(13, start + (index - 1) * 21) end
            local h = math.max(58, start + #self.Rows * 21 + 11)
            frame.Size = UDim2.fromOffset(w, h)
            local x = frame.Position.X.Scale * viewport.X + frame.Position.X.Offset
            local y = frame.Position.Y.Scale * viewport.Y + frame.Position.Y.Offset
            frame.Position = UDim2.fromOffset(math.clamp(x, 8, math.max(8, viewport.X - w - 8)), math.clamp(y, 8, math.max(8, viewport.Y - h - 35)))
            return self
        end
        function card:Update(fields)
            if self.Destroyed or window.Destroyed then return self end
            fields = type(fields) == "table" and fields or {State = fields}
            if fields.Title then self.Title = tostring(fields.Title) end
            if fields.Subtitle or fields.Desc or fields.Description or fields.Content then self.Subtitle = tostring(fields.Subtitle or fields.Desc or fields.Description or fields.Content) end
            if fields.State ~= nil or fields.Status ~= nil then self.State = tostring(fields.State or fields.Status) end
            if fields.Tone then self.Tone = fields.Tone end
            if fields.Fields or fields.Rows then
                local source, data = fields.Fields or fields.Rows, {}
                if #source > 0 then
                    for index, row in ipairs(source) do
                        if index > 4 then break end
                        if type(row) == "table" then data[#data + 1] = {tostring(row.Label or row.Key or row.Title or row[1] or index), tostring(row.Value or row[2] or "")}
                        else data[#data + 1] = {tostring(index), tostring(row)} end
                    end
                else
                    local keys = {}; for key in pairs(source) do keys[#keys + 1] = key end
                    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
                    for index, key in ipairs(keys) do if index > 4 then break end; data[#data + 1] = {tostring(key), tostring(source[key])} end
                end
                self.Fields = data
                while #self.Rows > #data do self.Rows[#self.Rows].Frame:Destroy(); table.remove(self.Rows) end
                for index, entry in ipairs(data) do
                    local row = self.Rows[index]
                    if not row then
                        local body = new("Frame", {Size = UDim2.new(1, -26, 0, 19), BackgroundTransparency = 1, ZIndex = 16}, frame)
                        row = {Frame = body, Label = label(body, "", 9, "Muted", {Size = UDim2.new(0.43, 0, 1, 0), ZIndex = 17}), Value = label(body, "", 10, "Text", {Position = UDim2.fromScale(0.43, 0), Size = UDim2.new(0.57, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 17})}
                        self.Rows[index] = row
                    end
                    row.Label.Text, row.Value.Text = string.upper(entry[1]), entry[2]
                end
            end
            heading.Text = icon(settings.Icon or "activity") .. "  " .. self.Title
            detail.Text = self.Subtitle
            local stateName = string.lower(tostring(self.State))
            local tone = self.Tone or ((stateName == "error" or stateName == "failed") and "Danger") or ((stateName == "waiting" or stateName == "paused") and "Warning") or ((stateName == "active" or stateName == "running" or stateName == "success") and "Success") or "Accent"
            state.Text = "● " .. string.upper(tostring(self.State)); state.TextColor3 = palette[tone] or color(tone, palette.Accent)
            self:Layout(); return self
        end
        card.Set = card.Update
        function card:SetVisible(value) self.UserVisible = value == true; if not self.Destroyed then frame.Visible = self.UserVisible end; return self end
        function card:Destroy() if self.Destroyed then return end; self.Destroyed = true; disconnect(self.Connections); frame:Destroy() end
        local floatingDrag, startPosition, origin
        connect(window, frame.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                floatingDrag, startPosition, origin = input, input.Position, frame.Position
            end
        end, card)
        connect(window, UIS.InputChanged, function(input)
            if card.Destroyed or not floatingDrag then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input == floatingDrag then
                local delta = input.Position - startPosition
                frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
                card:Layout()
            end
        end, card)
        connect(window, UIS.InputEnded, function(input) if input == floatingDrag then floatingDrag = nil end end, card)
        self.FloatingCards[#self.FloatingCards + 1] = card
        card:Update(settings)
        return card
    end
    if options.UIScale then window:SetUIScale(options.UIScale) end
    if options.OnDestroy then window:OnDestroy(options.OnDestroy) end
    return window
end

return UI
