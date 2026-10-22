-- NEVOIRS Native UI 0.1.0
-- Original Roblox GUI implementation for this project. No external Lua modules.
-- Dusk layout / Signal details / Frost palette. No per-panel blur dependency.
local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local Library = {Id = "nevoirs-native", Version = "0.1.0"}
local C = {
    Background = Color3.fromRGB(8, 16, 27), Surface = Color3.fromRGB(12, 25, 39),
    Card = Color3.fromRGB(18, 34, 50), Hover = Color3.fromRGB(24, 47, 66),
    Raised = Color3.fromRGB(24, 43, 60), Border = Color3.fromRGB(66, 95, 118),
    Accent = Color3.fromRGB(76, 196, 245), AccentDark = Color3.fromRGB(26, 79, 109),
    Text = Color3.fromRGB(226, 239, 249), Muted = Color3.fromRGB(144, 171, 192),
    Silver = Color3.fromRGB(185, 215, 236), Inactive = Color3.fromRGB(70, 89, 106),
    Ink = Color3.fromRGB(5, 24, 37), Error = Color3.fromRGB(245, 151, 137),
}
local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamMedium
local FOLD = {}
for plain, variants in pairs({a = "àáạảãâầấậẩẫăằắặẳẵÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ", e = "èéẹẻẽêềếệểễÈÉẸẺẼÊỀẾỆỂỄ",
    i = "ìíịỉĩÌÍỊỈĨ", o = "òóọỏõôồốộổỗơờớợởỡÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ", u = "ùúụủũưừứựửữÙÚỤỦŨƯỪỨỰỬỮ",
    y = "ỳýỵỷỹỲÝỴỶỸ", d = "đĐ"}) do
    for _, point in utf8.codes(variants) do FOLD[utf8.char(point)] = plain end
end
local function searchable(text)
    return tostring(text or ""):lower():gsub("[\194-\244][\128-\191]+", function(char) return FOLD[char] or char end)
end

local function create(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function corner(object, radius)
    return create("UICorner", object, {CornerRadius = UDim.new(0, radius or 10)})
end
local function stroke(object, color, transparency, thickness)
    return create("UIStroke", object, {Color = color or C.Border, Transparency = transparency or 0.3, Thickness = thickness or 1})
end
local function gradient(object, first, last, rotation)
    return create("UIGradient", object, {Color = ColorSequence.new(first, last), Rotation = rotation or 90})
end
local function label(parent, name, text, size, color, properties)
    local p = {Name = name, Text = tostring(text or ""), TextSize = size or 14, Font = FONT,
        TextColor3 = color or C.Text, BackgroundTransparency = 1, BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4}
    for key, value in pairs(properties or {}) do p[key] = value end
    return create("TextLabel", parent, p)
end
local function button(parent, name, text, properties)
    local p = {Name = name, Text = text or "", TextSize = 14, Font = FONT_BOLD,
        TextColor3 = C.Text, BackgroundColor3 = C.Card, BorderSizePixel = 0,
        AutoButtonColor = false, ZIndex = 6}
    for key, value in pairs(properties or {}) do p[key] = value end
    return create("TextButton", parent, p)
end

-- Small original line-icon set built from GUI geometry, not downloaded asset code.
local function icon(parent, name, position, size, color)
    local root = create("Frame", parent, {Name = "Icon_" .. tostring(name), BackgroundTransparency = 1,
        Position = position or UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(size or 24, size or 24), ZIndex = 4})
    local scale = (size or 24) / 24
    color = color or C.Silver
    local function line(x1, y1, x2, y2, thick)
        local dx, dy = x2 - x1, y2 - y1
        return create("Frame", root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) * .5 * scale, (y1 + y2) * .5 * scale),
            Size = UDim2.fromOffset(math.max(1, math.sqrt(dx * dx + dy * dy) * scale), (thick or 1.6) * scale),
            Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 4})
    end
    local function box(x, y, w, h, radius)
        local part = create("Frame", root, {Position = UDim2.fromOffset(x * scale, y * scale), Size = UDim2.fromOffset(w * scale, h * scale),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4})
        corner(part, (radius or 2) * scale); stroke(part, color, 0, 1.5 * scale)
        return part
    end
    local function circle(x, y, diameter)
        return box(x, y, diameter, diameter, diameter)
    end
    name = tostring(name or "grid"):lower()
    if name == "close" or name == "x" then line(6, 6, 18, 18); line(18, 6, 6, 18)
    elseif name == "minus" then line(5, 12, 19, 12)
    elseif name == "search" then circle(4, 4, 11); line(14, 14, 20, 20)
    elseif name == "chevron" then line(9, 5, 16, 12); line(16, 12, 9, 19)
    elseif name == "back" then line(15, 5, 8, 12); line(8, 12, 15, 19)
    elseif name == "pin" then line(8, 4, 16, 4); line(9, 4, 9, 10); line(15, 4, 15, 10); line(9, 10, 6, 14); line(15, 10, 18, 14); line(6, 14, 18, 14); line(12, 14, 12, 21)
    elseif name == "eye" or name == "esp" then
        line(2, 12, 7, 7); line(7, 7, 17, 7); line(17, 7, 22, 12); line(22, 12, 17, 17); line(17, 17, 7, 17); line(7, 17, 2, 12); circle(9, 9, 6)
    elseif name == "user" or name == "users" or name == "player" then circle(8, 3, 8); box(5, 14, 14, 7, 4)
    elseif name == "settings" or name == "settings-2" then
        circle(5, 5, 14); circle(10, 10, 4)
        for i = 0, 7 do local a = i * math.pi / 4; line(12 + math.cos(a) * 7, 12 + math.sin(a) * 7, 12 + math.cos(a) * 10, 12 + math.sin(a) * 10, 2) end
    elseif name == "laptop" or name == "terminal" then box(4, 4, 16, 12, 2); line(2, 20, 22, 20); line(9, 8, 12, 10); line(12, 10, 9, 12); line(14, 12, 17, 12)
    elseif name == "book" or name == "book-open" then box(3, 4, 18, 16, 2); line(12, 5, 12, 20)
    elseif name == "shield" or name == "main" then line(12, 3, 20, 7); line(20, 7, 19, 15); line(19, 15, 12, 21); line(12, 21, 5, 15); line(5, 15, 4, 7); line(4, 7, 12, 3)
    elseif name == "crosshair" or name == "combat" then circle(5, 5, 14); line(12, 1, 12, 7); line(12, 17, 12, 23); line(1, 12, 7, 12); line(17, 12, 23, 12)
    elseif name == "info" or name == "activity" then circle(3, 3, 18); line(12, 10, 12, 17); circle(11.5, 6.5, 1)
    elseif name == "check" then line(5, 12, 10, 17, 2); line(10, 17, 20, 6, 2)
    elseif name == "sun" then
        circle(7, 7, 10)
        for i = 0, 7 do local a = i * math.pi / 4; line(12 + math.cos(a) * 8, 12 + math.sin(a) * 8, 12 + math.cos(a) * 10, 12 + math.sin(a) * 10) end
    elseif name == "bolt" or name == "zap" then line(14, 2, 5, 13); line(5, 13, 12, 13); line(12, 13, 10, 22); line(10, 22, 20, 10); line(20, 10, 13, 10); line(13, 10, 14, 2)
    elseif name == "map-pin" or name == "map" then circle(6, 3, 12); line(7, 12, 12, 22); line(17, 12, 12, 22); circle(10, 7, 4)
    else box(4, 4, 6, 6, 2); box(14, 4, 6, 6, 2); box(4, 14, 6, 6, 2); box(14, 14, 6, 6, 2) end
    return root
end

function Library:CreateWindow(options)
    options = options or {}
    if self._window and not self._window.Destroyed then self._window:Destroy() end
    local window = {Destroyed = false, Tabs = {}, Controls = {}, Connections = {}, Tweens = {}, Pins = {}, Notifications = {}}
    self._window = window
    local state = {Visible = true, Search = "", GroupFilter = "All", SelectedTab = nil,
        Width = 800, Height = 500, Scale = 1, Narrow = false, DrawerOpen = false, Dragged = false}
    local guiParent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = create("ScreenGui", guiParent, {Name = "Nevoirs_Native_UI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999990})
    -- One viewport coordinate system. Safe GUI insets are applied explicitly below.
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
    local root = create("Frame", gui, {Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
        Size = UDim2.fromOffset(800, 500), BackgroundColor3 = C.Background, BorderSizePixel = 0, ClipsDescendants = true})
    corner(root, 18); stroke(root, C.Border, .05, 1.2); gradient(root, C.Surface, C.Background, 105)
    local rim = create("Frame", root, {Name = "TopRim", BackgroundColor3 = C.Accent, BackgroundTransparency = .15,
        Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 0, 1), BorderSizePixel = 0, ZIndex = 8})
    gradient(rim, C.AccentDark, C.Silver, 0)
    local header = create("Frame", root, {Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 62), Active = true})
    local monogram = label(header, "Monogram", "N", 31, C.Accent, {Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(34, 38)})
    local title = label(header, "Brand", options.Title or "NEVOIRS", 15, C.Text, {Font = FONT_BOLD, Position = UDim2.fromOffset(60, 10), Size = UDim2.fromOffset(170, 20)})
    local subtitle = label(header, "Subtitle", options.Subtitle or "B3C1 / FIELD INTERFACE", 10, C.Muted,
        {Position = UDim2.fromOffset(60, 31), Size = UDim2.fromOffset(210, 16)})
    local minimize = button(header, "Minimize", "", {BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 8)})
    icon(minimize, "minus", UDim2.fromOffset(11, 11), 24, C.Silver)
    local close = button(header, "Close", "", {BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 8)})
    icon(close, "close", UDim2.fromOffset(11, 11), 24, C.Silver)
    local searchFrame = create("Frame", root, {Name = "SearchField", BackgroundColor3 = C.Background, BorderSizePixel = 0,
        Position = UDim2.fromOffset(240, 12), Size = UDim2.fromOffset(250, 38), ZIndex = 8})
    corner(searchFrame, 9); stroke(searchFrame, C.Border, .4)
    icon(searchFrame, "search", UDim2.fromOffset(10, 9), 20, C.Muted)
    local search = create("TextBox", searchFrame, {Name = "Search", Text = "", PlaceholderText = "Tìm chức năng…", ClearTextOnFocus = false,
        Font = FONT, TextSize = 13, TextColor3 = C.Text, PlaceholderColor3 = C.Muted, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -76, 1, 0), ZIndex = 9})
    local clearSearch = button(searchFrame, "ClearSearch", "", {Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -38, 0, 0), BackgroundTransparency = 1, ZIndex = 10, Visible = false})
    icon(clearSearch, "close", UDim2.fromOffset(9, 9), 18, C.Muted)
    local groups = create("ScrollingFrame", root, {Name = "Groups", BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -32, 0, 46), Position = UDim2.fromOffset(16, 62), ClipsDescendants = true})
    local content = create("Frame", root, {Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 110), Size = UDim2.new(1, -32, 1, -180), ClipsDescendants = true})
    local pinned = create("Frame", content, {Name = "Pinned", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 92), Visible = false})
    local pinnedHeading = label(pinned, "Heading", "GHIM NHANH", 10, C.Accent, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 18), Font = FONT_BOLD})
    local pinCards = create("Frame", pinned, {Name = "Cards", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 23), Size = UDim2.new(1, 0, 1, -23)})
    local pages = create("Frame", content, {Name = "Pages", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true})
    local empty = label(content, "Empty", "Chưa có mục phù hợp.\nThử đổi khu hoặc từ khóa.", 14, C.Muted,
        {TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(.05, .15), Size = UDim2.fromScale(.9, .6), Visible = false})
    local nav = create("Frame", root, {Name = "BottomNav", BackgroundColor3 = C.Background, BackgroundTransparency = .08,
        BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 64), ZIndex = 12})
    stroke(nav, C.Border, .55)
    local overlay = button(root, "DetailShade", "", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = .45,
        Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 1, -126), ZIndex = 18, Visible = false})
    local drawer = create("Frame", root, {Name = "Inspector", BackgroundColor3 = C.Surface, BorderSizePixel = 0,
        Position = UDim2.new(1, -300, 0, 110), Size = UDim2.new(0, 284, 1, -190), ZIndex = 20, Visible = false, ClipsDescendants = true})
    corner(drawer, 13); stroke(drawer, C.Border, .15); gradient(drawer, C.Raised, C.Surface, 115)
    local drawerClose = button(drawer, "Back", "", {BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -48, 0, 4), ZIndex = 25})
    icon(drawerClose, "close", UDim2.fromOffset(12, 12), 22, C.Silver)
    local drawerTag = label(drawer, "Tag", "THÔNG TIN", 10, C.Accent, {Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -70, 0, 18), Font = FONT_BOLD, ZIndex = 22})
    local drawerTitle = label(drawer, "Title", "", 18, C.Text, {Position = UDim2.fromOffset(18, 52), Size = UDim2.new(1, -36, 0, 58), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Font = FONT_BOLD, ZIndex = 22})
    local drawerBody = create("ScrollingFrame", drawer, {Name = "DetailsScroll", BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.AccentDark, Position = UDim2.fromOffset(18, 120), Size = UDim2.new(1, -36, 1, -194), CanvasSize = UDim2.fromOffset(0, 0), ZIndex = 22})
    local drawerDesc = label(drawerBody, "Description", "", 13, C.Silver, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -4, 0, 180), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None, ZIndex = 22})
    local drawerAction = button(drawer, "PrimaryAction", "Thực hiện", {Position = UDim2.new(0, 18, 1, -62), Size = UDim2.new(1, -36, 0, 46), BackgroundColor3 = C.Accent, TextColor3 = C.Ink, ZIndex = 24})
    corner(drawerAction, 9); gradient(drawerAction, C.Silver, C.Accent, 90)
    local floating = button(gui, "FloatingToggle", "N", {Position = UDim2.new(0, 12, .25, 0), Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = C.Surface, TextColor3 = C.Accent, TextSize = 25, Font = Enum.Font.GothamBold, ZIndex = 50})
    corner(floating, 15); stroke(floating, C.Accent, .25); gradient(floating, C.Raised, C.Background, 110)
    local toastRoot = create("Frame", gui, {Name = "Notifications", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -14), Size = UDim2.fromOffset(310, 300), ZIndex = 60})
    local groupChips, groupConnections, pinViews, toastViews, drawerControl = {}, {}, {}, {}, nil
    local owner = self
    local function connect(signal, callback)
        local connection = signal:Connect(function(...)
            if not window.Destroyed then callback(...) end
        end)
        table.insert(window.Connections, connection)
        return connection
    end
    local function animate(object, properties, duration)
        if window.Destroyed or not object.Parent then return end
        local old = window.Tweens[object]
        if old then pcall(function() old:Cancel() end) end
        local ok, tween = pcall(function() return TweenService:Create(object, TweenInfo.new(duration or .14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties) end)
        if ok then window.Tweens[object] = tween; tween:Play() else for k, v in pairs(properties) do object[k] = v end end
    end
    local function measure(text, width, size)
        local ok, bounds = pcall(function() return TextService:GetTextSize(text, size or 13, FONT, Vector2.new(math.max(40, width), 10000)) end)
        if ok and bounds then return math.max(size or 13, bounds.Y) end
        return math.max(16, math.ceil(#text / math.max(8, width / 7)) * 17)
    end
    local function refreshDrawer()
        if not drawerControl then return end
        drawerTag.Text = string.upper(drawerControl.Group or drawerControl.Tab.Title or "THÔNG TIN")
        drawerTitle.Text = drawerControl.Title
        local description = drawerControl.Desc ~= "" and drawerControl.Desc or "Dùng nút hành động để gọi đúng chức năng này. Điều kiện nhiệm vụ vẫn do game quyết định."
        if drawerControl.Kind == "Toggle" then description ..= "\n\nTrạng thái: " .. (drawerControl.Value and "Đang bật" or "Đang tắt") end
        if drawerControl.Kind == "Input" then description ..= "\n\nGiá trị hiện tại: " .. tostring(drawerControl.Value) .. "\nChỉnh trực tiếp tại ô nhập của chức năng." end
        drawerDesc.Text = description
        local height = measure(description, (state.DrawerWidth or 284) - 40, 13) + 14
        drawerDesc.Size = UDim2.new(1, -4, 0, height)
        drawerBody.CanvasSize = UDim2.fromOffset(0, height)
        drawerAction.Visible = drawerControl.Kind == "Button" or drawerControl.Kind == "Toggle"
        drawerAction.Text = drawerControl.Kind == "Toggle" and (drawerControl.Value and "Tắt chức năng" or "Bật chức năng") or "Thực hiện"
        drawerAction.BackgroundColor3 = drawerControl.Disabled and C.Inactive or C.Accent
    end
    local function refreshPins()
        local tab = state.SelectedTab
        local list = {}
        for _, control in ipairs(window.Pins) do
            if control.Tab == tab and not control.Destroyed then table.insert(list, control) end
        end
        local show = #list > 0 and state.Search == "" and tab and (tab.Filter == "Quick" or tab.Filter == "All" or tab.Title ~= "Main")
        pinned.Visible = show and true or false
        local compact = state.Height < 410
        local pinHeight = show and (compact and 64 or 104) or 0
        pinned.Size = UDim2.new(1, 0, 0, pinHeight)
        pinnedHeading.Visible = not compact
        pinCards.Position = UDim2.fromOffset(0, compact and 0 or 23)
        pinCards.Size = UDim2.new(1, 0, 1, compact and -7 or -30)
        pages.Position = UDim2.fromOffset(0, pinHeight)
        pages.Size = UDim2.new(1, 0, 1, -pinHeight)
        if not show then return end
        local cardWidth = (state.ContentWidth - (#list - 1) * 8) / #list
        local same = #pinViews == #list
        for i, view in ipairs(pinViews) do if view.Control ~= list[i] then same = false end end
        if same then
            for i, view in ipairs(pinViews) do
                view.Frame.Position = UDim2.fromOffset((i - 1) * (cardWidth + 8), 0)
                view.Frame.Size = UDim2.new(0, cardWidth, 1, 0)
                view.Title.Text = view.Control.Title
                view.Title.TextSize = compact and 11 or 12
                view.Title.Position = UDim2.fromOffset(12, compact and 5 or 8)
                view.Title.Size = UDim2.new(1, -24, 1, compact and -10 or -26)
                view.Title.TextWrapped = not compact
                view.Hint.Visible = not compact
            end
            return
        end
        for _, view in ipairs(pinViews) do
            view.Connection:Disconnect()
            local index = table.find(window.Connections, view.Connection)
            if index then table.remove(window.Connections, index) end
            view.Frame:Destroy()
        end
        table.clear(pinViews)
        for i, control in ipairs(list) do
            local card = button(pinCards, "Pin_" .. i, "", {Position = UDim2.fromOffset((i - 1) * (cardWidth + 8), 0), Size = UDim2.new(0, cardWidth, 1, 0), BackgroundColor3 = C.AccentDark})
            corner(card, 11); stroke(card, C.Border, .05); gradient(card, C.Raised, C.AccentDark, 90)
            local name = label(card, "Title", control.Title, compact and 11 or 12, C.Text, {Position = UDim2.fromOffset(12, compact and 5 or 8), Size = UDim2.new(1, -24, 1, compact and -10 or -26), Font = FONT_BOLD, TextWrapped = not compact, ZIndex = 7})
            local hint = label(card, "Hint", control.Group .. "  /  CHẠM ĐỂ CHẠY", 9, C.Muted, {Position = UDim2.new(0, 12, 1, -21), Size = UDim2.new(1, -24, 0, 15), ZIndex = 7, Visible = not compact})
            local connection = connect(card.Activated, function() control:Activate() end)
            table.insert(pinViews, {Frame = card, Control = control, Title = name, Hint = hint, Connection = connection})
        end
    end
    function window:_Refresh()
        if self.Destroyed then return end
        local tab = state.SelectedTab
        if not tab then return end
        local query = searchable(state.Search)
        local count = 0
        for _, control in ipairs(tab.Controls) do
            local groupMatch = tab.Filter == "All" or control.Group == tab.Filter
            if query ~= "" then groupMatch = true end
            local haystack = searchable(control.Title .. " " .. control.Desc .. " " .. control.Group)
            local match = query == "" or haystack:find(query, 1, true) ~= nil
            local visible = groupMatch and match and control.UserVisible and not control.Destroyed
            control.ElementFrame.Visible = visible
            if visible and control.Kind ~= "Divider" and control.Kind ~= "Paragraph" then count += 1 end
        end
        empty.Visible = count == 0 and #tab.Controls > 0 and query ~= ""
        for name, chip in pairs(groupChips) do
            local selected = name == tab.Filter and query == ""
            chip.BackgroundColor3 = selected and C.AccentDark or C.Card
            chip.TextColor3 = selected and C.Accent or C.Muted
        end
        clearSearch.Visible = query ~= ""
        state.GroupFilter = tab.Filter
        refreshPins()
    end
    function window:_BuildGroups()
        for name, chip in pairs(groupChips) do
            local connection = groupConnections[name]
            if connection then
                connection:Disconnect()
                local index = table.find(self.Connections, connection)
                if index then table.remove(self.Connections, index) end
            end
            chip:Destroy()
        end
        table.clear(groupChips)
        table.clear(groupConnections)
        local tab = state.SelectedTab
        if not tab then return end
        local names = {"All"}
        for _, name in ipairs(tab.Groups) do if name ~= "All" then table.insert(names, name) end end
        local x = 0
        for _, name in ipairs(names) do
            local text = name == "All" and "Tất cả" or (name == "Quick" and "Ghim nhanh" or name)
            local width = math.max(66, math.min(140, #text * 7 + 26))
            local chip = button(groups, "Group_" .. name, text, {Position = UDim2.fromOffset(x, 2), Size = UDim2.fromOffset(width, 38), TextSize = 12})
            corner(chip, 8); stroke(chip, C.Border, .45)
            groupConnections[name] = connect(chip.Activated, function() tab:SetGroupFilter(name) end)
            groupChips[name] = chip
            x += width + 7
        end
        groups.CanvasSize = UDim2.fromOffset(x, 0)
    end
    function window:_Layout()
        if self.Destroyed then return end
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(900, 600)
        local safeTopLeft, safeBottomRight = Vector2.zero, Vector2.zero
        local insetOk, topInset, bottomInset = pcall(function() return GuiService:GetGuiInset() end)
        if insetOk and topInset and bottomInset then safeTopLeft, safeBottomRight = topInset, bottomInset end
        local usableWidth = math.max(220, viewport.X - safeTopLeft.X - safeBottomRight.X)
        local usableHeight = math.max(210, viewport.Y - safeTopLeft.Y - safeBottomRight.Y)
        local actualWidth = math.max(200, math.min(920, usableWidth - 24))
        local actualHeight = math.max(190, math.min(600, usableHeight - 28))
        local width, height = math.floor(actualWidth / state.Scale), math.floor(actualHeight / state.Scale)
        state.Width, state.Height, state.Narrow = width, height, width < 790
        state.DrawerModal = state.Narrow or height < 410
        root.Size = UDim2.fromOffset(width, height)
        if not state.Dragged then root.Position = UDim2.fromOffset(safeTopLeft.X + usableWidth * .5, safeTopLeft.Y + usableHeight * .5) end
        local small = width < 540
        local topHeight = small and 104 or 62
        header.Size = UDim2.new(1, 0, 0, 62)
        title.Size = UDim2.fromOffset(small and math.max(50, width - 170) or 170, 20)
        subtitle.Size = UDim2.fromOffset(small and width - 170 or 210, 16)
        if small then
            searchFrame.Position = UDim2.fromOffset(16, 62)
            searchFrame.Size = UDim2.new(1, -32, 0, 36)
        else
            searchFrame.Position = UDim2.fromOffset(math.min(250, width * .34), 12)
            searchFrame.Size = UDim2.new(1, -math.min(250, width * .34) - 110, 0, 38)
        end
        groups.Position = UDim2.fromOffset(16, topHeight)
        groups.Size = UDim2.new(1, -32, 0, 46)
        local bodyTop = topHeight + 48
        local drawerWidth = 284
        local contentWidth = width - 32 - (state.DrawerOpen and not state.DrawerModal and drawerWidth + 12 or 0)
        state.ContentWidth = contentWidth
        content.Position = UDim2.fromOffset(16, bodyTop)
        content.Size = UDim2.new(0, contentWidth, 1, -bodyTop - 76)
        overlay.Position = UDim2.fromOffset(0, 0)
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Visible = state.DrawerOpen and state.DrawerModal
        state.DrawerWidth = state.DrawerModal and math.min(width - 24, 420) or drawerWidth
        local drawerHeight = state.DrawerModal and height - 24 or height - bodyTop - 76
        drawer.Position = state.DrawerModal and UDim2.new(.5, -state.DrawerWidth / 2, 0, 12) or UDim2.new(1, -300, 0, bodyTop)
        drawer.Size = UDim2.fromOffset(state.DrawerWidth, drawerHeight)
        local compactDrawer = drawerHeight < 330
        drawerTitle.Position = UDim2.fromOffset(18, compactDrawer and 42 or 52)
        drawerTitle.Size = UDim2.new(1, -36, 0, compactDrawer and 26 or 58)
        drawerTitle.TextSize = compactDrawer and 15 or 18
        drawerTitle.TextWrapped = not compactDrawer
        local descriptionTop = compactDrawer and 78 or 120
        drawerBody.Position = UDim2.fromOffset(18, descriptionTop)
        drawerBody.Size = UDim2.new(1, -36, 0, math.max(40, drawerHeight - descriptionTop - 76))
        for _, tab in ipairs(self.Tabs) do
            local n = math.max(1, #self.Tabs)
            tab.Nav.Size = UDim2.new(1 / n, -8, 1, -10)
            tab.Nav.Position = UDim2.new((tab.Index - 1) / n, 4, 0, 5)
            if tab.NavIcon then tab.NavIcon.Position = UDim2.new(.5, -10, 0, 5) end
            for _, control in ipairs(tab.Controls) do
                if control.Kind == "Paragraph" then control:_Measure(contentWidth) end
            end
        end
        toastRoot.Size = UDim2.fromOffset(math.min(320, math.max(210, viewport.X - 24)), 300)
        toastRoot.Position = UDim2.fromOffset(viewport.X - safeBottomRight.X - 12, viewport.Y - safeBottomRight.Y - 14)
        floating.Position = UDim2.fromOffset(safeTopLeft.X + 12, safeTopLeft.Y + usableHeight * .25)
        refreshPins(); refreshDrawer()
        if state.Dragged then
            local cx = root.Position.X.Offset
            local cy = root.Position.Y.Offset
            local halfW, halfH = actualWidth * .5, actualHeight * .5
            root.Position = UDim2.fromOffset(math.clamp(cx, safeTopLeft.X + halfW + 8, math.max(safeTopLeft.X + halfW + 8, viewport.X - safeBottomRight.X - halfW - 8)), math.clamp(cy, safeTopLeft.Y + halfH + 8, math.max(safeTopLeft.Y + halfH + 8, viewport.Y - safeBottomRight.Y - halfH - 8)))
        end
    end
    function window:SetSearch(text)
        if self.Destroyed then return end
        text = tostring(text or "")
        state.Search = text
        if search.Text ~= text then search.Text = text end
        self:_Refresh()
    end
    function window:Pin(control, desired)
        if self.Destroyed or not control or control.Destroyed or control.Kind ~= "Button" then return false end
        local index = table.find(self.Pins, control)
        local pin = desired == nil and index == nil or desired == true
        if pin and not index then
            if #self.Pins >= 3 then owner:Notify({Title = "Ghim nhanh", Content = "Tối đa 3 hành động. Bỏ ghim một mục để chọn mục khác."}); return false end
            table.insert(self.Pins, control)
        elseif not pin and index then table.remove(self.Pins, index) end
        control.Pinned = pin
        if control.__Debug.Pin then control.__Debug.Pin.BackgroundColor3 = pin and C.AccentDark or C.Card end
        self:_Refresh()
        return true
    end
    function window:OpenDetails(control)
        if self.Destroyed or not control or control.Destroyed then return end
        drawerControl = control
        state.DrawerOpen = true
        drawer.Visible = true
        drawerBody.CanvasPosition = Vector2.zero
        refreshDrawer(); self:_Layout()
    end
    function window:CloseDetails()
        if self.Destroyed then return end
        state.DrawerOpen = false; drawer.Visible = false; overlay.Visible = false; drawerControl = nil
        self:_Layout()
    end
    function window:SetUIScale(value)
        if self.Destroyed then return end
        value = tonumber(value) or 1
        if value ~= value then value = 1 end
        state.Scale = math.clamp(value, .8, 1.2)
        if not self.ScaleObject then self.ScaleObject = create("UIScale", root, {Scale = state.Scale}) else self.ScaleObject.Scale = state.Scale end
        self:_Layout()
    end
    function window:SetToggleSize(value)
        if self.Destroyed then return end
        local n = math.clamp(tonumber(value) or 1, .75, 1.8)
        floating.Size = UDim2.fromOffset(48 * n, 48 * n)
        floating.TextSize = 25 * n
    end
    function window:SetVisible(visible)
        if self.Destroyed then return end
        state.Visible = visible and true or false
        root.Visible = state.Visible
        if not state.Visible then search:ReleaseFocus(); self:CloseDetails() end
    end
    function window:Toggle() self:SetVisible(not state.Visible) end
    function window:Open() self:SetVisible(true) end
    function window:Close() self:SetVisible(false) end
    window.Show, window.Hide = window.Open, window.Close
    function window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for _, control in ipairs(self.Controls) do control.Destroyed = true end
        for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        table.clear(self.Connections)
        for _, tween in pairs(self.Tweens) do pcall(function() tween:Cancel() end) end
        table.clear(self.Tweens)
        table.clear(self.Pins)
        gui:Destroy()
        if owner._window == self then owner._window = nil end
    end
    local function invoke(control, value)
        if window.Destroyed or control.Destroyed or control.Disabled or type(control.Callback) ~= "function" then return end
        if control.Busy then
            if control.Kind ~= "Button" then control.PendingValue = value; control.HasPending = true end
            return
        end
        control.Busy = true
        task.spawn(function()
            local nextValue = value
            while not window.Destroyed and not control.Destroyed and not control.Disabled do
                local ok, err = pcall(control.Callback, nextValue)
                if not ok and not window.Destroyed then
                    warn("[Nevoirs UI] " .. control.Title .. ": " .. tostring(err))
                    owner:Notify({Title = "Chức năng gặp lỗi", Content = control.Title .. ": " .. tostring(err), Duration = 5})
                end
                if not control.HasPending then break end
                local pending = control.PendingValue
                control.HasPending, control.PendingValue = false, nil
                if pending == nextValue then break end
                nextValue = pending
            end
            control.Busy = false
            control.HasPending, control.PendingValue = false, nil
        end)
    end
    local function controlIcon(titleText)
        local t = titleText:lower()
        if t:find("laptop", 1, true) or t:find("terminal", 1, true) then return "laptop" end
        if t:find("hideo", 1, true) or t:find("người", 1, true) then return "user" end
        if t:find("diary", 1, true) then return "book" end
        if t:find("tp", 1, true) then return "map-pin" end
        if t:find("nearby", 1, true) then return "crosshair" end
        return "grid"
    end
    local function addControl(tab, kind, parameters)
        local p = parameters or {}
        local groupName = p.Group or tab.CurrentGroup
        if not table.find(tab.Groups, groupName) then table.insert(tab.Groups, groupName) end
        local control = {Kind = kind, Tab = tab, Title = tostring(p.Title or ""), Desc = tostring(p.Desc or ""),
            Group = groupName, Callback = p.Callback, Value = p.Value, Disabled = p.Disabled == true, Destroyed = false,
            UserVisible = true, Pinned = false, Busy = false, __Debug = {}}
        local frame = create("Frame", tab.Page, {Name = kind .. "_" .. control.Title, BackgroundColor3 = C.Card,
            BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, kind == "Divider" and 12 or 64), LayoutOrder = #tab.Controls + 1, ClipsDescendants = true})
        control.ElementFrame = frame
        if kind ~= "Paragraph" and kind ~= "Divider" then corner(frame, 11); control.Stroke = stroke(frame, C.Border, .48); gradient(frame, C.Card, C.Surface, 110) end
        function control:SetVisible(value)
            if self.Destroyed or window.Destroyed then return end
            self.UserVisible = value and true or false
            window:_Refresh()
        end
        function control:SetDisabled(value)
            if self.Destroyed or window.Destroyed then return end
            self.Disabled = value and true or false
            if self.Disabled then self.HasPending, self.PendingValue = false, nil end
            if self.TitleLabel then self.TitleLabel.TextColor3 = self.Disabled and C.Inactive or C.Text end
            if self.__Debug.Button then self.__Debug.Button.Active = not self.Disabled end
            if self.__Debug.Input then self.__Debug.Input.TextEditable = not self.Disabled end
            refreshDrawer()
        end
        function control:SetTitle(value)
            if self.Destroyed or window.Destroyed then return end
            self.Title = tostring(value or "")
            if self.TitleLabel then self.TitleLabel.Text = self.Title end
            window:_Refresh(); refreshDrawer()
        end
        function control:SetDesc(value)
            if self.Destroyed or window.Destroyed then return end
            self.Desc = tostring(value or "")
            if self.DescLabel then self.DescLabel.Text = self.Desc end
            if self.Kind == "Paragraph" then self:_Measure(state.ContentWidth or state.Width - 32) end
            window:_Refresh(); refreshDrawer()
        end
        function control:Pin(value) return window:Pin(self, value) end
        function control:Activate()
            if window.Destroyed or self.Destroyed or self.Disabled then return end
            if self.Kind == "Toggle" then self:Set(not self.Value)
            elseif self.Kind == "Button" then invoke(self)
            elseif self.Kind == "Input" and self.__Debug.Input then self.__Debug.Input:CaptureFocus() end
        end
        function control:Set(value, fireCallback)
            if window.Destroyed or self.Destroyed then return end
            if self.Kind == "Toggle" then
                local on = value and true or false
                local changed = self.Value ~= on
                self.Value = on
                if self.__Debug.Switch then
                    animate(self.__Debug.Switch, {BackgroundColor3 = on and C.AccentDark or C.Inactive}, .12)
                    animate(self.__Debug.Knob, {Position = UDim2.fromOffset(on and 28 or 4, 4), BackgroundColor3 = on and C.Accent or C.Silver}, .12)
                end
                if changed and fireCallback ~= false then invoke(self, on) end
            elseif self.Kind == "Input" or self.Kind == "Dropdown" then
                local text = tostring(value or "")
                local changed = self.Value ~= text
                self.Value = text
                if self.__Debug.Input then self.__Debug.Input.Text = text end
                if self.__Debug.Button and self.Kind == "Dropdown" then self.__Debug.Button.Text = text end
                if changed and fireCallback ~= false then invoke(self, text) end
            end
            refreshDrawer()
        end
        control.SetValue = control.Set
        if kind == "Divider" then
            frame.BackgroundTransparency = 1
            create("Frame", frame, {Name = "Rule", Position = UDim2.fromOffset(4, 5), Size = UDim2.new(1, -8, 0, 1), BorderSizePixel = 0, BackgroundColor3 = C.Border, BackgroundTransparency = .65})
        elseif kind == "Paragraph" then
            frame.BackgroundTransparency = 1
            control.TitleLabel = label(frame, "Title", control.Title, 15, C.Text, {Position = UDim2.fromOffset(2, 9), Size = UDim2.new(1, -8, 0, 22), Font = FONT_BOLD})
            control.DescLabel = label(frame, "Description", control.Desc, 12, C.Muted, {Position = UDim2.fromOffset(2, 35), Size = UDim2.new(1, -8, 0, 32), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None})
            function control:_Measure(width)
                local h = self.Desc ~= "" and measure(self.Desc, width - 20, 12) or 0
                self.DescLabel.Size = UDim2.new(1, -8, 0, h)
                self.ElementFrame.Size = UDim2.new(1, -6, 0, 38 + (h > 0 and h + 10 or 0))
            end
            control:_Measure(state.ContentWidth or state.Width - 32)
        else
            local rowIcon = icon(frame, p.Icon or controlIcon(control.Title), UDim2.fromOffset(13, 19), 25, C.Silver)
            control.TitleLabel = label(frame, "Title", control.Title, 13, C.Text, {Position = UDim2.fromOffset(50, control.Desc ~= "" and 10 or 17), Size = UDim2.new(1, -176, 0, control.Desc ~= "" and 22 or 30), Font = FONT_BOLD})
            control.DescLabel = label(frame, "Description", control.Desc, 10, C.Muted, {Position = UDim2.fromOffset(50, 35), Size = UDim2.new(1, -176, 0, 18)})
            local info = button(frame, "Info", "", {BackgroundTransparency = 1, Position = UDim2.new(1, -44, 0, 8), Size = UDim2.fromOffset(40, 48), ZIndex = 9})
            icon(info, "chevron", UDim2.fromOffset(9, 12), 22, C.Muted)
            control.__Debug.Info = info
            connect(info.Activated, function() window:OpenDetails(control) end)
            if kind == "Button" then
                local activate = button(frame, "Action", "", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -92, 1, 0), ZIndex = 7})
                local pin = button(frame, "Pin", "", {BackgroundTransparency = .4, Position = UDim2.new(1, -88, 0, 8), Size = UDim2.fromOffset(40, 48), ZIndex = 9})
                corner(pin, 8); icon(pin, "pin", UDim2.fromOffset(10, 12), 21, C.Muted)
                control.__Debug.Button, control.__Debug.Pin = activate, pin
                connect(activate.Activated, function() control:Activate() end)
                connect(pin.Activated, function() window:Pin(control) end)
                connect(activate.MouseEnter, function() animate(frame, {BackgroundColor3 = C.Hover}) end)
                connect(activate.MouseLeave, function() animate(frame, {BackgroundColor3 = C.Card}) end)
            elseif kind == "Toggle" then
                control.Value = p.Value and true or false
                local switch = create("Frame", frame, {Name = "Switch", Position = UDim2.new(1, -111, 0, 17), Size = UDim2.fromOffset(56, 30), BackgroundColor3 = C.Inactive, BorderSizePixel = 0, ZIndex = 5})
                corner(switch, 15)
                local knob = create("Frame", switch, {Name = "Knob", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = C.Silver, BorderSizePixel = 0, ZIndex = 5})
                corner(knob, 11)
                local activate = button(frame, "ToggleAction", "", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -46, 1, 0), ZIndex = 7})
                control.__Debug.Button, control.__Debug.Switch, control.__Debug.Knob = activate, switch, knob
                control:Set(control.Value, false)
                connect(activate.Activated, function() control:Activate() end)
            elseif kind == "Input" then
                control.Value = tostring(p.Value or "")
                control.TitleLabel.Size = UDim2.new(1, -206, 0, control.Desc ~= "" and 22 or 30)
                control.DescLabel.Size = UDim2.new(1, -206, 0, 18)
                local input = create("TextBox", frame, {Name = "Input", Text = control.Value, PlaceholderText = tostring(p.Placeholder or ""),
                    ClearTextOnFocus = false, Font = FONT_BOLD, TextSize = 13, TextColor3 = C.Accent, PlaceholderColor3 = C.Muted,
                    BackgroundColor3 = C.Background, BorderSizePixel = 0, Position = UDim2.new(1, -145, 0, 10), Size = UDim2.fromOffset(94, 44), ZIndex = 8})
                corner(input, 8); stroke(input, C.Border, .35)
                control.__Debug.Input = input
                connect(input.FocusLost, function() control:Set(input.Text, true) end)
            elseif kind == "Dropdown" then
                local values = p.Values or {}
                control.Value = tostring(p.Value or values[1] or "")
                local cycle = button(frame, "Select", control.Value, {Position = UDim2.new(1, -160, 0, 10), Size = UDim2.fromOffset(108, 44), BackgroundColor3 = C.Background, TextSize = 11, ZIndex = 8})
                corner(cycle, 8); stroke(cycle, C.Border, .35)
                control.__Debug.Button = cycle
                connect(cycle.Activated, function()
                    if control.Disabled or #values == 0 then return end
                    local index = table.find(values, control.Value) or 0
                    control:Set(values[index % #values + 1], true)
                end)
            end
        end
        table.insert(tab.Controls, control); table.insert(window.Controls, control)
        control:SetDisabled(control.Disabled)
        if p.Pinned and kind == "Button" then window:Pin(control, true) end
        window:_Refresh()
        return control
    end
    function window:Tab(tabOptions)
        if self.Destroyed then return nil end
        tabOptions = tabOptions or {}
        local tab = {Title = tostring(tabOptions.Title or "Tab"), Index = #self.Tabs + 1, Controls = {}, Groups = {}, CurrentGroup = "General", Filter = "All"}
        local page = create("ScrollingFrame", pages, {Name = "Page_" .. tab.Title, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1), ScrollBarThickness = 3, ScrollBarImageColor3 = C.AccentDark, CanvasSize = UDim2.fromOffset(0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false})
        local list = create("UIListLayout", page, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
        tab.Page, tab.Layout = page, list
        local navButton = button(nav, "Nav_" .. tab.Title, "", {BackgroundTransparency = 1, ZIndex = 14})
        corner(navButton, 11)
        tab.Nav, tab.NavIcon = navButton, icon(navButton, tabOptions.Icon or "grid", UDim2.new(.5, -10, 0, 5), 20, C.Silver)
        tab.NavLabel = label(navButton, "Title", tab.Title, 10, C.Muted, {TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 2, 1, -23), Size = UDim2.new(1, -4, 0, 18), ZIndex = 15})
        function tab:SetGroup(name)
            if window.Destroyed then return end
            name = tostring(name or "General")
            self.CurrentGroup = name
            if not table.find(self.Groups, name) then table.insert(self.Groups, name) end
            if #self.Groups == 1 and self.Title == "Main" then self.Filter = name end
            if state.SelectedTab == self then window:_BuildGroups(); window:_Refresh() end
        end
        function tab:SetGroupFilter(name)
            if window.Destroyed then return end
            name = tostring(name or "All")
            if name ~= "All" and not table.find(self.Groups, name) then return end
            self.Filter = name
            page.CanvasPosition = Vector2.zero
            state.Search = ""; search.Text = ""
            if state.SelectedTab == self then window:_Refresh() end
        end
        function tab:Select()
            if window.Destroyed then return end
            state.SelectedTab = self
            state.Search = ""; search.Text = ""
            for _, other in ipairs(window.Tabs) do
                local selected = other == self
                other.Page.Visible = selected
                other.Nav.BackgroundTransparency = selected and .15 or 1
                other.Nav.BackgroundColor3 = C.AccentDark
                other.NavLabel.TextColor3 = selected and C.Accent or C.Muted
            end
            window:CloseDetails(); window:_BuildGroups(); window:_Refresh(); window:_Layout()
        end
        function tab:Paragraph(p) return addControl(self, "Paragraph", p) end
        function tab:Divider() return addControl(self, "Divider", {}) end
        function tab:Button(p) return addControl(self, "Button", p) end
        function tab:Toggle(p) return addControl(self, "Toggle", p) end
        function tab:Input(p) return addControl(self, "Input", p) end
        function tab:Dropdown(p) return addControl(self, "Dropdown", p) end
        connect(list:GetPropertyChangedSignal("AbsoluteContentSize"), function() page.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 8) end)
        connect(navButton.Activated, function() tab:Select() end)
        table.insert(self.Tabs, tab)
        self:_Layout()
        if not state.SelectedTab then tab:Select() end
        return tab
    end
    function window:_Notify(payload)
        if self.Destroyed then return end
        payload = payload or {}
        if #toastViews >= 3 then
            local old = table.remove(toastViews, 1)
            old.Alive = false; old.Frame:Destroy()
        end
        local frame = create("Frame", toastRoot, {Name = "Toast", AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Surface,
            Size = UDim2.new(1, 0, 0, 82), BorderSizePixel = 0, ZIndex = 61})
        corner(frame, 12); stroke(frame, C.Border, .12); gradient(frame, C.Raised, C.Surface, 90)
        create("Frame", frame, {Name = "Accent", Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(3, 58), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 62})
        label(frame, "Title", payload.Title or "Nevoirs", 12, C.Accent, {Font = FONT_BOLD, Position = UDim2.fromOffset(15, 9), Size = UDim2.new(1, -28, 0, 20), ZIndex = 63})
        label(frame, "Content", payload.Content or payload.Text or "", 11, C.Text, {Position = UDim2.fromOffset(15, 32), Size = UDim2.new(1, -28, 0, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 63})
        local record = {Frame = frame, Alive = true}; table.insert(toastViews, record)
        local function reflow()
            for i, toast in ipairs(toastViews) do toast.Frame.Position = UDim2.new(1, 0, 1, -(#toastViews - i) * 90) end
        end
        reflow()
        task.delay(math.clamp(tonumber(payload.Duration) or 4, 1, 12), function()
            if self.Destroyed or not record.Alive then return end
            record.Alive = false
            local index = table.find(toastViews, record)
            if index then table.remove(toastViews, index) end
            frame:Destroy(); reflow()
        end)
    end
    local drag = nil
    connect(header.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if InputService:GetFocusedTextBox() then return end
        local point = input.Position
        local left = root.AbsolutePosition.X
        -- Only the brand portion is draggable; search/close/minimize never drag.
        if point.X > left + math.min(230 * state.Scale, root.AbsoluteSize.X - 120 * state.Scale) then return end
        local center = root.AbsolutePosition + root.AbsoluteSize / 2
        drag = {Input = input, Origin = point, Center = center}
    end)
    connect(InputService.InputChanged, function(input)
        if not drag then return end
        if input.UserInputType == Enum.UserInputType.Touch and input ~= drag.Input then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - drag.Origin
        state.Dragged = true
        root.Position = UDim2.fromOffset(drag.Center.X + delta.X, drag.Center.Y + delta.Y)
        window:_Layout()
    end)
    connect(InputService.InputEnded, function(input)
        if drag and (input == drag.Input or input.UserInputType == Enum.UserInputType.MouseButton1) then drag = nil end
    end)
    connect(InputService.InputBegan, function(input, processed)
        if processed or InputService:GetFocusedTextBox() then return end
        if input.KeyCode == (options.ToggleKey or Enum.KeyCode.RightControl) then window:Toggle() end
    end)
    connect(search:GetPropertyChangedSignal("Text"), function() state.Search = search.Text; window:_Refresh() end)
    connect(clearSearch.Activated, function() window:SetSearch("") end)
    connect(close.Activated, function() window:SetVisible(false) end)
    connect(minimize.Activated, function() window:SetVisible(false) end)
    connect(floating.Activated, function() window:Toggle() end)
    connect(drawerClose.Activated, function() window:CloseDetails() end)
    connect(overlay.Activated, function() window:CloseDetails() end)
    connect(drawerAction.Activated, function() if drawerControl then drawerControl:Activate(); refreshDrawer() end end)
    local cameraConnection
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        local camera = Workspace.CurrentCamera
        if camera then cameraConnection = connect(camera:GetPropertyChangedSignal("ViewportSize"), function() window:_Layout() end) end
        window:_Layout()
    end
    connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    connect(gui.Destroying, function() if not window.Destroyed then window:Destroy() end end)
    window.__Debug = {Controls = window.Controls, Tabs = window.Tabs, Gui = gui, Root = root, Header = header, Nav = nav, Search = search,
        GroupChips = groupChips, Content = content, Drawer = drawer, Pinned = pinned, PinViews = pinViews, Toggle = floating, State = state,
        Notifications = toastViews, Close = close, Minimize = minimize, DrawerAction = drawerAction, ClearSearch = clearSearch, Overlay = overlay}
    bindCamera()
    window:SetUIScale(options.Scale or 1)
    window:SetToggleSize(options.ToggleSize or 1)
    return window
end

function Library:Notify(payload)
    local window = self._window
    if window and not window.Destroyed then window:_Notify(payload) end
end
function Library:SetTheme(_) end -- The original palette is intentionally fixed for this release.
return Library
