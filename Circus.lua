--[[
    Nevoirs | Circus.lua | Nightmare Circus (The Mimic)
    Standalone NMCS port / diagnostics v2 (2026 rebuild compatibility probe)

    Gameplay / packet logic: 2294168059.lua (NMCSFunc + PackNMCS + NMCS@Main)
    UI / visual direction: B3C1.lua + NativeUI.lua (compact avatar + ESP)

    Target PlaceId: 11126398230
    Shared UI URL: https://raw.githubusercontent.com/eystearisdown/wyattrz/main/NativeUI.lua
    Notes:
      * Mini games must be started normally before some packets are accepted.
      * Statue puzzle: enable the watcher BEFORE starting/retrying; mirror signals
        are collected in their observed order (and only while the game is active).
      * This is client-side Luau for Roblox executors; no server-side guarantee.
      * No CC/B3C1 code or TTJY loader dependencies.
]]

local TARGET_PLACE = 11126398230
if game.PlaceId ~= TARGET_PLACE then
    warn("[Nevoirs | Nightmare Circus] Script này dành cho PlaceId " .. TARGET_PLACE .. "; hiện tại là " .. tostring(game.PlaceId))
    return
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__NevoirsNightmareCircusCleanup) == "function" then
    pcall(env.__NevoirsNightmareCircusCleanup)
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BRAND_ICON = "rbxassetid://98606201759935"
local SKY = Color3.fromRGB(94, 170, 255)
local WHITE = Color3.fromRGB(242, 245, 255)
local DIM = Color3.fromRGB(148, 163, 185)
local C_PLAYER = Color3.fromRGB(0, 240, 196)
local C_CLOWN = Color3.fromRGB(255, 120, 93)
local C_TASK = Color3.fromRGB(255, 217, 90)
local C_YEN = Color3.fromRGB(255, 220, 55)
local C_BOSS = Color3.fromRGB(255, 65, 100)
local SETTINGS_FILE = "Nevoirs_Nightmare_Circus.json"
local UI_NAME = "Nevoirs_NMCS_LeftToggle"

local life = { alive = true, conns = {}, window = nil, ui = nil, runtimeId = tostring(os.clock()) }
local States = {
    AutoClowns = false,
    AutoHammer = false,
    AutoStatues = false,
    AutoBoss = false,
    ESPPlayer = false,
    ESPClowns = false,
    ESPTasks = false,
    ESPBoss = false,
    TPWalk = false,
    Noclip = false,
    Moonwalk = false,
    VFly = false,
    AutoYenESP = false,
    AutoYenCollect = false,
    InfiniteJump = false,
    Fullbright = false,
    InstantE = false,
}
local Settings = { UIScale = UserInputService.TouchEnabled and 0.70 or 0.75,
                   ToggleScale = 1, TPWalkSpeed = 8, VFlySpeed = 0 }
local Controls = {}
local lastPacket = {}
local taskToken = 0
local activeTask = nil
local statueState = { eyes = nil, orders = {}, watched = nil, connections = {}, busy = false, event = nil, epoch = 0 }
local noclipParts = {}
local promptDurations = {}
local esp = { Player = {}, Clown = {}, Task = {}, Boss = {}, Yen = {} }
local lightingOriginal = {
    Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
}
local Window, WindUI
local moonwalkAutoRotate = setmetatable({}, { __mode = "k" })
local vflyBodyVelocity, vflyBodyGyro, vflyRenderConn, vflyStateConn
local vflyHumanoid, vflyOldWalkSpeed

local function track(conn)
    table.insert(life.conns, conn)
    return conn
end

local function aliveInstance(obj)
    return typeof(obj) == "Instance" and obj.Parent ~= nil
end

local function at(root, ...)
    local obj = root
    for i = 1, select("#", ...) do
        if not obj then return nil end
        obj = obj:FindFirstChild(select(i, ...))
    end
    return obj
end

local function anchorOf(obj)
    if not aliveInstance(obj) then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
    return obj:FindFirstChild("HumanoidRootPart", true)
        or obj:FindFirstChild("Head", true)
        or obj:FindFirstChild("Hitbox", true)
        or obj:FindFirstChild("Part", true)
        or obj:FindFirstChildWhichIsA("BasePart", true)
end

local function characterRoot()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return char, root, char and char:FindFirstChildOfClass("Humanoid")
end

local function notify(title, content, icon)
    if WindUI and type(WindUI.Notify) == "function" then
        pcall(function()
            WindUI:Notify({ Title = title, Content = tostring(content), Icon = icon or "info", Duration = 4 })
        end)
    end
    print("[Nevoirs | NMCS] " .. tostring(title) .. ": " .. tostring(content))
end

local function readSettings()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    local ok, exists = pcall(isfile, SETTINGS_FILE)
    if not ok or not exists then return end
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(SETTINGS_FILE))
    end)
    if success and type(data) == "table" then
        for key, value in pairs(Settings) do
            local num = tonumber(data[key])
            if type(value) == "number" and num and num == num and num ~= math.huge and num ~= -math.huge then
                Settings[key] = num
            end
        end
    end
    Settings.UIScale = math.clamp(Settings.UIScale, 0.58, 0.95)
    Settings.ToggleScale = math.clamp(Settings.ToggleScale, 0.6, 2)
    Settings.TPWalkSpeed = math.clamp(Settings.TPWalkSpeed, 0, 9999)
    Settings.VFlySpeed = math.clamp(Settings.VFlySpeed, 0, 99999)
end
local function saveSettings()
    if type(writefile) == "function" then
        pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings)) end)
    end
end
readSettings()

local function sleepCancelable(seconds, token)
    local elapsed = 0
    while life.alive and token == taskToken and elapsed < seconds do
        elapsed = elapsed + task.wait(math.min(0.1, seconds - elapsed))
    end
    return life.alive and token == taskToken
end

local function teleport(cf, token)
    if token and (token ~= taskToken or not life.alive) then return false end
    local char, root = characterRoot()
    if not char or not root then return false, "Nhân vật chưa sẵn sàng" end
    if typeof(cf) ~= "CFrame" then return false, "Thiếu tọa độ teleport" end
    local ok, err = pcall(function() root.CFrame = cf end)
    return ok, err
end

local function getPacket()
    -- The 229 source calls :FireServer() on this exact object. Do not assume
    -- the current build still uses precisely the same RemoteEvent class.
    local packet = at(ReplicatedStorage, "modules", "Packet", "Reliable")
    if packet and (packet:IsA("RemoteEvent") or packet:IsA("UnreliableRemoteEvent")) then
        return packet
    end
    return nil
end

local function fire(name, ...)
    local packet = getPacket()
    if not packet then return false, "Không tìm thấy ReplicatedStorage.modules.Packet.Reliable" end
    local args = table.pack(...)
    return pcall(function() packet:FireServer(name, table.unpack(args, 1, args.n)) end)
end

local function throttledFire(key, delay, ...)
    local now = os.clock()
    if now - (lastPacket[key] or -math.huge) < delay then return end
    local ok, err = fire(key, ...)
    if ok then lastPacket[key] = now else warn("[NMCS] " .. tostring(err)) end
end

local function triggerPrompt(prompt, token)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false, "Thiếu ProximityPrompt" end
    if not prompt.Enabled then return false, "Prompt đang tắt" end
    local good, err = pcall(function()
        if type(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            local duration = math.min(prompt.HoldDuration, 5)
            if duration > 0 then
                if token then sleepCancelable(duration, token) else task.wait(duration) end
            end
            prompt:InputHoldEnd()
        end
    end)
    return good, err
end

local function runOnce(label, fn)
    if activeTask then
        notify("Đang thực hiện", "Hoàn thành hoặc hủy '" .. activeTask .. "' trước.", "clock")
        return
    end
    taskToken = taskToken + 1
    local token = taskToken
    activeTask = label
    task.spawn(function()
        local ok, result, err = pcall(fn, token)
        if token == taskToken then activeTask = nil end
        if not life.alive or token ~= taskToken then return end
        if not ok then
            notify(label .. " • lỗi", result, "circle-alert")
        elseif result == false then
            notify(label, err or "Chưa thể thực hiện. Hãy kiểm tra minigame và F9.", "circle-alert")
        else
            notify(label, "Đã thực hiện lệnh local / gửi packet 229; CHƯA xác nhận server chấp nhận. Xem mục Chẩn đoán.", "info")
        end
    end)
end

local function cancelOnce()
    taskToken = taskToken + 1
    activeTask = nil
    notify("Đã hủy", "Dừng các thao tác một lần chưa kết thúc; packet đã gửi không thể thu hồi.", "info")
end

-- ==========================================================================
-- Section 1 / Clown: exact packet sequence and coordinates from source 229.
-- ==========================================================================
local DART_COORDS = {
    {-0.88143342681816828, 0.87117157036754522},
    {-0.40142137418766055, 0.91716707364216832},
    { 0.041346730334789528,0.87692103847450520},
    { 0.39722330242307746, 0.87692111900152425},
    { 0.91447760427951508, 0.93441523638199131},
    { 0.88964793123131491, 0.17548872773929206},
    { 0.46343281770698325, 0.07199846286804935},
    {-0.07451625921624357, 0.06624932190210424},
    {-0.35176052119367995, 0.04900119942579082},
    {-0.89798600124604222, 0.16398952981256001},
    {-0.90212515911099733,-0.84791254881688827},
    {-0.41797322414554394,-0.84791254881688827},
    { 0.08687026923994082,-0.84791287092496448},
    { 0.38480924832656710,-0.84791279039794543},
    { 0.85654341990915883,-0.85941100186869390},
}
local RING_COORDS = {
    { 0.02500001449758789, 0.07585209032351320},
    {-0.48124999568487214, 0.09021171961318363},
    { 0.43541668060546079, 0.08978304368528452},
    { 0.00833334447815971, 0.40833256630734960},
    {-0.35625002564241487, 0.43911111371761014},
    { 0.45416664673636364, 0.39147921583869238},
}

local function throwSequence(packetName, coords, delay, token)
    if not getPacket() then return false, "Remote Reliable chưa sẵn sàng" end
    for _, xy in ipairs(coords) do
        if not life.alive or token ~= taskToken then return false, "Đã hủy" end
        local ok, err = fire(packetName, xy[1], xy[2])
        if not ok then return false, err end
        if not sleepCancelable(delay, token) then return false, "Đã hủy" end
    end
    return true
end

local function doBasketball(token)
    local ok, err = fire("Section1/BasketballHold")
    if not ok then return false, err end
    if not sleepCancelable(0.997, token) then return false, "Đã hủy" end
    return fire("Section1/BasketballRelease", 0.997)
end

local function doGolf()
    local ball = at(Workspace, "Section1", "Games", "MiniGolf", "GolfBall")
    local hole = at(Workspace, "Section1", "Games", "MiniGolf", "Hole")
    if not (ball and hole and ball:IsA("BasePart") and hole:IsA("BasePart")) then
        return false, "Không tìm thấy GolfBall hoặc Hole (hãy vào minigame trước)"
    end
    return pcall(function() ball.CFrame = hole.CFrame end)
end

local function listClowns()
    local container = at(Workspace, "Section1", "Games", "WhackAClown", "Clowns")
    if not container then return {} end
    local result, unique = {}, {}
    -- First prefer the source's QueryDescendants(">#Clown") when available.
    local ok, query = pcall(function() return container:QueryDescendants(">#Clown") end)
    if ok and type(query) == "table" then
        for _, inst in ipairs(query) do
            if aliveInstance(inst) and inst:IsDescendantOf(container) and not unique[inst] then
                unique[inst] = true
                table.insert(result, inst)
            end
        end
    end
    -- Standard Roblox fallback: tag lookup, no guessed object-name packets.
    if #result == 0 then
        for _, inst in ipairs(CollectionService:GetTagged("Clown")) do
            if aliveInstance(inst) and inst:IsDescendantOf(container) and not unique[inst] then
                unique[inst] = true
                table.insert(result, inst)
            end
        end
    end
    return result
end

local clownLastHit = setmetatable({}, { __mode = "k" })
local function handleClowns()
    for _, inst in ipairs(listClowns()) do
        if inst:GetAttribute("Active") == true then
            local now = os.clock()
            if now - (clownLastHit[inst] or -math.huge) > 0.2 then
                local ok = fire("Section1/Whack", inst)
                if ok then clownLastHit[inst] = now end
            end
        end
    end
end

-- ==========================================================================
-- Section 2 / Dimitra: mirror order, statues, moon, star and tarot.
-- ==========================================================================
local PUZZLES = {
    Moon = {
        number = "Puzzle3", count = 8, waitAfterPrompt = 0,
        progress = "Section2/MoonPuzzleProgress", complete = "Section2/MoonPuzzleComplete",
    },
    Star = {
        number = "Puzzle1", count = 5, waitAfterPrompt = 0,
        progress = "Section2/StarPuzzleProgress", complete = "Section2/StarPuzzleComplete",
    },
    Tarot = {
        number = "Puzzle4", count = 5, waitAfterPrompt = 0.3,
        progress = "Section2/TarotPuzzleProgress", complete = "Section2/TarotPuzzleComplete",
    },
}
local function completePuzzle(which, token)
    local meta = PUZZLES[which]
    local puzzle = at(Workspace, "Section2", "MainObjective", meta.number)
    if not puzzle then return false, "Không tìm thấy " .. meta.number end
    if puzzle:GetAttribute("Complete") then return true end
    local pp = at(puzzle, "PromptPart", "ProximityPrompt")
    if not pp then return false, "Hãy vào minigame " .. which .. " ít nhất một lần" end
    local target = anchorOf(pp.Parent)
    if not target then return false, "Thiếu phần tương tác của " .. which end
    local ok, err = teleport(target.CFrame, token)
    if not ok then return false, err end
    if not sleepCancelable(0.3, token) then return false, "Đã hủy" end
    ok, err = triggerPrompt(pp, token)
    if not ok then return false, err end
    if not sleepCancelable(meta.waitAfterPrompt, token) then return false, "Đã hủy" end
    for i = 1, meta.count do
        if token ~= taskToken or not life.alive then return false, "Đã hủy" end
        ok, err = fire(meta.progress, i)
        if not ok then return false, err end
    end
    return fire(meta.complete)
end

local function clearEyeWatch()
    for _, conn in ipairs(statueState.connections) do pcall(function() conn:Disconnect() end) end
    statueState.connections = {}
    statueState.epoch = statueState.epoch + 1
    statueState.eyes = nil
    statueState.watched = nil
    statueState.event = nil
    statueState.orders = {}
end

local function registerEyeWatcher()
    local puzzle = at(Workspace, "Section2", "MainObjective", "Puzzle2")
    if not puzzle then clearEyeWatch(); return false end
    local statues = puzzle:FindFirstChild("EyeStatues")
    local mirrors = puzzle:FindFirstChild("Mirrors")
    if not statues or not mirrors then clearEyeWatch(); return false end
    local event = Workspace:GetAttribute("MimicEvent")
    if statueState.watched == puzzle and statueState.event == event and statueState.eyes then return true end
    clearEyeWatch()
    local eyes = {}
    for i = 1, 4 do
        local statueN = event == "TheHollow" and i or (5 - i)
        local mirrorN = event == "TheHollow" and (5 - i) or i
        local statue = statues:FindFirstChild("Eye" .. tostring(statueN))
        local mirror = at(mirrors, "Mirror" .. tostring(mirrorN), "Eye", "Part")
        local prompt = statue and at(statue, "Prompt", "ProximityPrompt")
        local part = statue and statue:FindFirstChild("Part")
        if not (mirror and mirror:IsA("BasePart") and prompt and part) then
            clearEyeWatch()
            return false
        end
        eyes[i] = { statue = statue, part = part, mirror = mirror, prompt = prompt }
    end
    statueState.watched = puzzle
    statueState.event = event
    statueState.eyes = eyes
    local function enqueue(i)
        local eye = statueState.eyes and statueState.eyes[i]
        if not (States.AutoStatues and eye and eye.mirror.Parent) then return end
        if eye.mirror.Transparency >= 0.99 then return end
        for _, queued in ipairs(statueState.orders) do
            if queued == i then return end
        end
        table.insert(statueState.orders, i)
    end
    for i, eye in ipairs(eyes) do
        local eyeIndex = i
        table.insert(statueState.connections, eye.mirror:GetPropertyChangedSignal("Transparency"):Connect(function()
            enqueue(eyeIndex)
        end))
        -- Also cover enabling while a round is already displaying its pattern.
        enqueue(i)
    end
    return true
end

local function processStatueOrders()
    if statueState.busy or not States.AutoStatues or activeTask then return end
    if not statueState.eyes or #statueState.orders == 0 then return end
    local firstEye = statueState.eyes[1]
    if not (firstEye and firstEye.prompt and firstEye.prompt.Enabled) then return end
    statueState.busy = true
    local captured = statueState.orders
    local epoch = statueState.epoch
    statueState.orders = {}
    task.spawn(function()
        local ok, err = pcall(function()
            for _, i in ipairs(captured) do
                if not life.alive or not States.AutoStatues or epoch ~= statueState.epoch then break end
                local eye = statueState.eyes and statueState.eyes[i]
                if eye and aliveInstance(eye.part) and eye.prompt.Enabled then
                    teleport(eye.part.CFrame)
                    task.wait(0.3)
                    triggerPrompt(eye.prompt)
                    task.wait(0.1)
                end
            end
            -- Original source waits 2 seconds after consuming one statue order.
            task.wait(2)
        end)
        if not ok then warn("[NMCS] Statue worker: ", err) end
        statueState.busy = false
    end)
end

-- ==========================================================================
-- Section 3 / Dimitra boss.
-- ==========================================================================
local function handleBoss()
    local hitbox = at(Workspace, "Section3", "DimitraBOSS", "PlayerHitbox")
    if not hitbox or not hitbox:IsA("BasePart") then return end
    local ok = teleport(hitbox.CFrame)
    if ok then throttledFire("MagicAxe/SwingHit", 0.13) end
end

local function mainAutoLoop()
    while life.alive do
        local s1 = Workspace:FindFirstChild("Section1")
        local s2 = Workspace:FindFirstChild("Section2")
        local s3 = Workspace:FindFirstChild("Section3")
        if s1 then
            if States.AutoClowns then
                local ok, err = pcall(handleClowns)
                if not ok then warn("[NMCS] Auto Clowns: " .. tostring(err)) end
            end
            if States.AutoHammer then throttledFire("Section1/HighStrikerClick", 0.12) end
        end
        if States.AutoStatues then
            if s2 then
                local ok, err = pcall(registerEyeWatcher)
                if not ok then warn("[NMCS] Eye watcher: " .. tostring(err)) end
                processStatueOrders()
            else
                clearEyeWatch()
            end
        elseif statueState.watched then
            clearEyeWatch()
        end
        if s3 and States.AutoBoss and not activeTask and not statueState.busy then
            local ok, err = pcall(handleBoss)
            if not ok then warn("[NMCS] Auto Dimitra: " .. tostring(err)) end
        end
        task.wait(0.12)
    end
end

-- ==========================================================================
-- CC-styled ESP: entire-model Highlight, colored labels and distances.
-- One shared updater; per-entry Heartbeat connections are intentionally avoided.
-- ==========================================================================
local function destroyESP(entry)
    if not entry then return end
    pcall(function() entry.hl:Destroy() end)
    pcall(function() entry.bb:Destroy() end)
end

local function clearESP(category)
    for obj, entry in pairs(esp[category]) do
        destroyESP(entry)
        esp[category][obj] = nil
    end
end

local function makeESP(category, adornee, anchor, label, color)
    if not aliveInstance(adornee) or not aliveInstance(anchor) or not anchor:IsA("BasePart") then return end
    if not (adornee:IsA("Model") or adornee:IsA("BasePart")) then return end
    local pool = esp[category]
    local entry = pool[adornee]
    if entry and entry.anchor == anchor then
        entry.label.Text = label
        return
    end
    if entry then destroyESP(entry) end
    local highlight = Instance.new("Highlight")
    highlight.Name = "Nevoirs_NMCS_Highlight"
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.OutlineColor = WHITE
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0.05
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = adornee

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Nevoirs_NMCS_Label"
    billboard.Adornee = anchor
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(164, 38)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.Parent = anchor

    local nameText = Instance.new("TextLabel")
    nameText.Name = "Label"
    nameText.BackgroundTransparency = 1
    nameText.Size = UDim2.new(1, 0, 0.55, 0)
    nameText.Font = Enum.Font.GothamBold
    nameText.TextSize = 12
    nameText.TextStrokeTransparency = 0.12
    nameText.TextColor3 = color
    nameText.Text = label
    nameText.Parent = billboard

    local distanceText = Instance.new("TextLabel")
    distanceText.Name = "Distance"
    distanceText.BackgroundTransparency = 1
    distanceText.Position = UDim2.fromScale(0, 0.55)
    distanceText.Size = UDim2.new(1, 0, 0.45, 0)
    distanceText.Font = Enum.Font.Gotham
    distanceText.TextSize = 10
    distanceText.TextStrokeTransparency = 0.35
    distanceText.TextColor3 = DIM
    distanceText.Parent = billboard
    pool[adornee] = { hl = highlight, bb = billboard, anchor = anchor,
                      label = nameText, dist = distanceText }
end

-- Yen support imported/adapted from B3C1.lua: scan only known currency folders.
local YEN_COLLECT_RANGE = 10
local function yenFolders()
    local list, seen = {}, {}
    local function add(folder)
        if aliveInstance(folder) and not seen[folder] then
            seen[folder] = true
            table.insert(list, folder)
        end
    end
    local original = Workspace:FindFirstChild("MimicCurrencySpawns")
    add(original and original:FindFirstChild("Yen"))
    add(Workspace:FindFirstChild("Yen"))
    add(Workspace:FindFirstChild("YenSpawns"))
    add(Workspace:FindFirstChild("CurrencyYen"))
    return list
end

local function yenPrompt(coin)
    if not aliveInstance(coin) then return nil end
    if coin:IsA("ProximityPrompt") then return coin end
    return coin:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function yenAnchor(coin)
    if not aliveInstance(coin) then return nil end
    if coin:IsA("BasePart") then return coin end
    local prompt = yenPrompt(coin)
    local parent = prompt and prompt.Parent
    if parent and parent:IsA("BasePart") then return parent end
    if parent and parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
        return parent.Parent
    end
    return anchorOf(coin)
end

local function collectNearbyYen()
    if not States.AutoYenCollect then return end
    local _, root = characterRoot()
    if not root then return end
    for _, folder in ipairs(yenFolders()) do
        for _, coin in ipairs(folder:GetChildren()) do
            local anchor = yenAnchor(coin)
            if anchor and (anchor.Position - root.Position).Magnitude <= YEN_COLLECT_RANGE then
                local prompt = yenPrompt(coin)
                local triggered = false
                if prompt and prompt.Enabled and type(fireproximityprompt) == "function" then
                    triggered = pcall(function() fireproximityprompt(prompt, 1, true) end)
                    if not triggered then triggered = pcall(function() fireproximityprompt(prompt) end) end
                end
                if not triggered and type(firetouchinterest) == "function" then
                    pcall(function() firetouchinterest(root, anchor, 0) end)
                    pcall(function() firetouchinterest(root, anchor, 1) end)
                end
            end
        end
    end
end

local function scanESP()
    local wanted = { Player = {}, Clown = {}, Task = {}, Boss = {}, Yen = {} }
    local function put(cat, obj, display, color, anchor)
        anchor = anchor or anchorOf(obj)
        if not anchor or not aliveInstance(anchor) then return end
        wanted[cat][obj] = true
        makeESP(cat, obj, anchor, display, color)
    end

    if States.ESPPlayer then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character.Parent then
                local char = player.Character
                put("Player", char, player.DisplayName, C_PLAYER, char:FindFirstChild("Head") or anchorOf(char))
            end
        end
    end
    if States.ESPClowns then
        for _, inst in ipairs(listClowns()) do
            put("Clown", inst, "Clown" .. (inst:GetAttribute("Active") and " [ACTIVE]" or ""), C_CLOWN)
        end
    end
    if States.ESPTasks then
        local objective = at(Workspace, "Section2", "MainObjective")
        if objective then
            for _, item in ipairs({ { "Puzzle3", "Moon Puzzle" },
                                    { "Puzzle1", "Star Puzzle" },
                                    { "Puzzle4", "Tarot Puzzle" },
                                    { "Puzzle2", "Eye Statues" } }) do
                local obj = objective:FindFirstChild(item[1])
                if obj and not obj:GetAttribute("Complete") then
                    put("Task", obj, item[2], C_TASK)
                end
            end
            local statues = at(objective, "Puzzle2", "EyeStatues")
            if statues then
                for i = 1, 4 do
                    local eye = statues:FindFirstChild("Eye" .. i)
                    if eye then put("Task", eye, "Statue #" .. i, C_TASK) end
                end
            end
        end
        local golf = at(Workspace, "Section1", "Games", "MiniGolf")
        if golf then
            local hole = golf:FindFirstChild("Hole")
            local ball = golf:FindFirstChild("GolfBall")
            if hole then put("Task", hole, "Golf Hole", C_TASK) end
            if ball then put("Task", ball, "Golf Ball", C_TASK) end
        end
    end
    if States.AutoYenESP then
        for _, folder in ipairs(yenFolders()) do
            for _, coin in ipairs(folder:GetChildren()) do
                local anchor = yenAnchor(coin)
                if anchor then
                    local model = (coin:IsA("Model") or coin:IsA("BasePart")) and coin or anchor
                    put("Yen", model, "Yen", C_YEN, anchor)
                end
            end
        end
    end
    if States.ESPBoss then
        local boss = at(Workspace, "Section3", "DimitraBOSS")
        if boss then
            local hitbox = boss:FindFirstChild("PlayerHitbox")
            if hitbox then
                put("Boss", boss, "Dimitra", C_BOSS, hitbox)
            end
        end
    end

    for cat, pool in pairs(esp) do
        for obj, entry in pairs(pool) do
            if not wanted[cat][obj] or not aliveInstance(obj)
                or not aliveInstance(entry.anchor) or not entry.bb.Parent then
                destroyESP(entry)
                pool[obj] = nil
            end
        end
    end
end

local function updateESPDistances()
    local _, root = characterRoot()
    if not root then return end
    for _, pool in pairs(esp) do
        for _, entry in pairs(pool) do
            if aliveInstance(entry.anchor) then
                local length = (root.Position - entry.anchor.Position).Magnitude
                entry.dist.Text = string.format("%.0f studs", length)
            end
        end
    end
end

-- ==========================================================================
-- CC-like client utility helpers. All local modifications can be reverted.
-- ==========================================================================
local function setFullbright(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.FogEnd = 1e9
    else
        for property, value in pairs(lightingOriginal) do
            pcall(function() Lighting[property] = value end)
        end
    end
end

local function restoreNoclip()
    for part, old in pairs(noclipParts) do
        if aliveInstance(part) then pcall(function() part.CanCollide = old end) end
        noclipParts[part] = nil
    end
end

local function patchPrompt(obj)
    if obj and obj:IsA("ProximityPrompt") and promptDurations[obj] == nil then
        promptDurations[obj] = obj.HoldDuration
        obj.HoldDuration = 0
    end
end
local function setInstantE(state)
    States.InstantE = state
    if state then
        for _, obj in ipairs(Workspace:GetDescendants()) do patchPrompt(obj) end
    else
        for prompt, previous in pairs(promptDurations) do
            if aliveInstance(prompt) then pcall(function() prompt.HoldDuration = previous end) end
            promptDurations[prompt] = nil
        end
    end
end

-- Moonwalk: same reverse-camera behavior as B3C1, restore AutoRotate on OFF.
local function restoreMoonwalk()
    for humanoid, original in pairs(moonwalkAutoRotate) do
        if aliveInstance(humanoid) then pcall(function() humanoid.AutoRotate = original end) end
    end
    moonwalkAutoRotate = setmetatable({}, { __mode = "k" })
end

local function updateMoonwalk()
    if not States.Moonwalk then return end
    local _, root, humanoid = characterRoot()
    local camera = Workspace.CurrentCamera
    if not (root and humanoid and camera and humanoid.Health > 0) then return end
    if moonwalkAutoRotate[humanoid] == nil then
        moonwalkAutoRotate[humanoid] = humanoid.AutoRotate
    end
    humanoid.AutoRotate = false
    local direction = camera.CFrame.LookVector
    local horizontal = Vector3.new(-direction.X, 0, -direction.Z)
    if horizontal.Magnitude > 0.05 then
        root.CFrame = CFrame.lookAt(root.Position, root.Position + horizontal.Unit)
    end
end

-- VFly: camera-direction flight, mobile joystick + PC WASD, matching B3C1 controls.
local function clearVFlyBodies()
    if vflyRenderConn then vflyRenderConn:Disconnect(); vflyRenderConn = nil end
    if vflyStateConn then vflyStateConn:Disconnect(); vflyStateConn = nil end
    if vflyBodyVelocity then pcall(function() vflyBodyVelocity:Destroy() end) end
    if vflyBodyGyro then pcall(function() vflyBodyGyro:Destroy() end) end
    vflyBodyVelocity, vflyBodyGyro = nil, nil
end

local function stopVFly()
    clearVFlyBodies()
    local humanoid = vflyHumanoid
    if humanoid and humanoid.Parent then
        pcall(function()
            if vflyOldWalkSpeed ~= nil then humanoid.WalkSpeed = vflyOldWalkSpeed end
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
    vflyHumanoid, vflyOldWalkSpeed = nil, nil
end

local function startVFly()
    stopVFly()
    if not States.VFly or not life.alive then return end
    local _, root, humanoid = characterRoot()
    if not (root and humanoid) then return end

    local gyroscope = Instance.new("BodyGyro")
    gyroscope.Name = "Nevoirs_Circus_FlyGyro"
    gyroscope.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    gyroscope.P = 9e4
    gyroscope.D = 1e3
    gyroscope.CFrame = root.CFrame
    gyroscope.Parent = root

    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "Nevoirs_Circus_FlyVelocity"
    velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    velocity.P = 1e4
    velocity.Velocity = Vector3.zero
    velocity.Parent = root

    vflyBodyVelocity, vflyBodyGyro = velocity, gyroscope
    vflyHumanoid, vflyOldWalkSpeed = humanoid, humanoid.WalkSpeed
    humanoid.WalkSpeed = 0
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    vflyStateConn = humanoid.StateChanged:Connect(function(_, nextState)
        if States.VFly and life.alive and nextState ~= Enum.HumanoidStateType.Physics then
            task.defer(function()
                if States.VFly and aliveInstance(humanoid) then
                    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                end
            end)
        end
    end)

    vflyRenderConn = RunService.RenderStepped:Connect(function()
        if not life.alive or not States.VFly then return end
        if not aliveInstance(root) or not aliveInstance(velocity) then return end
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local look, right = camera.CFrame.LookVector, camera.CFrame.RightVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        local flatRight = Vector3.new(right.X, 0, right.Z)
        if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
        if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

        local move = Vector3.zero
        local md = humanoid.MoveDirection
        if md.Magnitude > 0.16 and flatLook.Magnitude > 0 and flatRight.Magnitude > 0 then
            local forward = math.clamp(md:Dot(flatLook), -1, 1)
            local strafe = math.clamp(md:Dot(flatRight), -1, 1)
            if math.abs(forward) < 0.18 then forward = 0 end
            if math.abs(strafe) < 0.18 then strafe = 0 end
            move = look * forward + right * strafe
        else
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
            move += Vector3.yAxis
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            move -= Vector3.yAxis
        end
        if move.Magnitude > 0.08 then
            velocity.Velocity = move.Unit * Settings.VFlySpeed
            gyroscope.CFrame = CFrame.new(root.Position, root.Position + look)
        else
            velocity.Velocity = Vector3.zero
            gyroscope.CFrame = root.CFrame
        end
    end)
end

local function stepLocal(dt)
    if States.TPWalk then
        local _, root, humanoid = characterRoot()
        if root and humanoid and humanoid.MoveDirection.Magnitude > 0 then
            root.CFrame = root.CFrame + humanoid.MoveDirection * Settings.TPWalkSpeed * math.min(dt, 0.1)
        end
    end
    if States.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if noclipParts[obj] == nil then noclipParts[obj] = obj.CanCollide end
                    obj.CanCollide = false
                end
            end
        end
    elseif next(noclipParts) then
        restoreNoclip()
    end
end

local function uiScale(scale)
    Settings.UIScale = math.clamp(tonumber(scale) or 0.7, 0.58, 0.95)
    if Window and Window.SetUIScale then
        pcall(function() Window:SetUIScale(Settings.UIScale) end)
    end
    saveSettings()
end

local function setToggleSize()
    local gui = PlayerGui:FindFirstChild(UI_NAME)
    local button = gui and gui:FindFirstChild("Toggle")
    local img = button and button:FindFirstChild("Avatar")
    if not button or not img then return end
    local factor = Settings.ToggleScale
    button.Size = UDim2.fromOffset(math.floor(46 * factor), math.floor(46 * factor))
    img.Size = UDim2.fromOffset(math.floor(30 * factor), math.floor(30 * factor))
end

local function makeLeftToggle()
    local previous = PlayerGui:FindFirstChild(UI_NAME)
    if previous then previous:Destroy() end
    local gui = Instance.new("ScreenGui")
    gui.Name = UI_NAME
    gui.DisplayOrder = 999998
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = PlayerGui
    local button = Instance.new("ImageButton")
    button.Name = "Toggle"
    button.AnchorPoint = Vector2.new(0, 0.5)
    button.Position = UDim2.new(0, 12, 0.5, -70)
    button.BackgroundTransparency = 1
    button.Image = ""
    button.Parent = gui
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.AnchorPoint = Vector2.new(0.5, 0.5)
    avatar.Position = UDim2.fromScale(0.5, 0.5)
    avatar.Image = BRAND_ICON
    avatar.BackgroundColor3 = Color3.fromRGB(13, 18, 28)
    avatar.ImageColor3 = WHITE
    avatar.ScaleType = Enum.ScaleType.Crop
    avatar.Parent = button
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = avatar
    local stroke = Instance.new("UIStroke")
    stroke.Color = SKY
    stroke.Transparency = 0.15
    stroke.Thickness = 1.2
    stroke.Parent = avatar
    track(button.MouseButton1Click:Connect(function()
        if Window and Window.Toggle then pcall(function() Window:Toggle() end) end
    end))
    setToggleSize()
    return gui
end

local function cleanup()
    if not life.alive then return end
    life.alive = false
    taskToken = taskToken + 1
    activeTask = nil
    for key in pairs(States) do States[key] = false end
    stopVFly()
    restoreMoonwalk()
    clearEyeWatch()
    restoreNoclip()
    setInstantE(false)
    setFullbright(false)
    for category in pairs(esp) do clearESP(category) end
    for _, conn in ipairs(life.conns) do pcall(function() conn:Disconnect() end) end
    life.conns = {}
    local toggle = PlayerGui:FindFirstChild(UI_NAME)
    if toggle then pcall(function() toggle:Destroy() end) end
    if Window and Window.Destroy then pcall(function() Window:Destroy() end) end
    if env.__NevoirsNightmareCircusCleanup == cleanup then
        env.__NevoirsNightmareCircusCleanup = nil
    end
end
env.__NevoirsNightmareCircusCleanup = cleanup

-- Background workers are alive from the first load; all features are OFF.
track(RunService.RenderStepped:Connect(function()
    if life.alive and States.Moonwalk then
        local ok, err = pcall(updateMoonwalk)
        if not ok then warn("[NMCS] Moonwalk: " .. tostring(err)) end
    end
end))
track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.7)
    if life.alive and States.VFly then pcall(startVFly) end
end))
task.spawn(function()
    while life.alive do
        local ok, err = pcall(collectNearbyYen)
        if not ok then warn("[NMCS] Yen Aura: " .. tostring(err)) end
        task.wait(0.20)
    end
end)
track(RunService.Heartbeat:Connect(function(dt)
    if life.alive then
        local ok, err = pcall(stepLocal, dt)
        if not ok then warn("[NMCS] Player step: " .. tostring(err)) end
    end
end))
track(UserInputService.JumpRequest:Connect(function()
    if States.InfiniteJump then
        local _, _, hum = characterRoot()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))
track(Workspace.DescendantAdded:Connect(function(obj)
    if States.InstantE and obj:IsA("ProximityPrompt") then
        pcall(patchPrompt, obj)
    end
end))
task.spawn(mainAutoLoop)
task.spawn(function()
    while life.alive do
        local ok, err = pcall(function() scanESP(); updateESPDistances() end)
        if not ok then warn("[NMCS] ESP scan: " .. tostring(err)) end
        task.wait(0.85)
    end
end)

-- ==========================================================================
-- Live diagnostic for October 2026 rebuilt Nightmare Circus.
-- 229 is a historical packet map: a successful FireServer does NOT mean a
-- new server accepted an old minigame command. This only reads local instances.
-- It deliberately avoids guessing or firing unknown packets.
-- ==========================================================================
local function buildRuntimeReport()
    local lines = {}
    local function line(value) table.insert(lines, tostring(value)) end
    local function describe(obj)
        if not obj then return "MISSING" end
        return "OK (" .. obj.ClassName .. ")"
    end
    local function listChildren(label, obj, maxN)
        if not obj then
            line(label .. ": MISSING")
            return
        end
        local children = obj:GetChildren()
        local n = math.min(#children, maxN or 30)
        local parts = {}
        for i = 1, n do
            local child = children[i]
            table.insert(parts, child.Name .. "<" .. child.ClassName .. ">")
        end
        line(label .. " [" .. #children .. "]: " .. table.concat(parts, ", ") .. (#children > n and " ...[truncated]" or ""))
    end
    local event = Workspace:GetAttribute("MimicEvent")
    local s1 = Workspace:FindFirstChild("Section1")
    local games = s1 and s1:FindFirstChild("Games")
    local packets = at(ReplicatedStorage, "modules", "Packet")
    local remote = packets and packets:FindFirstChild("Reliable")
    line("=== NEVOIRS NMCS LIVE REPORT v2 (READ ONLY) ===")
    line("GamePlaceId: " .. tostring(game.PlaceId))
    line("MimicEvent: " .. tostring(event))
    line("229 NMCS PlaceId match: " .. tostring(game.PlaceId == TARGET_PLACE))
    line("TheHollow statue mapping: " .. (event == "TheHollow" and "Eye1-4 -> Mirror4-1" or "Eye4-1 -> Mirror4-1 (legacy other event)"))
    line("Reliable packet (229): " .. describe(remote))
    line("Packet supports :FireServer: " .. tostring(getPacket() ~= nil))
    listChildren("ReplicatedStorage.modules", ReplicatedStorage:FindFirstChild("modules"), 32)
    listChildren("ReplicatedStorage.modules.Packet", packets, 32)
    listChildren("Workspace.Section1", s1, 32)
    listChildren("Workspace.Section1.Games", games, 48)
    listChildren("PlayerGui", PlayerGui, 32)
    local checks = {
        { "WhackAClown.Clowns", at(games, "WhackAClown", "Clowns") },
        { "MiniGolf.GolfBall", at(games, "MiniGolf", "GolfBall") },
        { "MiniGolf.Hole", at(games, "MiniGolf", "Hole") },
        { "Puzzle2 EyeStatues", at(Workspace, "Section2", "MainObjective", "Puzzle2", "EyeStatues") },
        { "Puzzle2 Mirrors", at(Workspace, "Section2", "MainObjective", "Puzzle2", "Mirrors") },
        { "Dimitra Hitbox", at(Workspace, "Section3", "DimitraBOSS", "PlayerHitbox") },
    }
    for _, entry in ipairs(checks) do
        line(entry[1] .. ": " .. describe(entry[2]))
    end
    line("Clown tag hits inside old folder: " .. tostring(#listClowns()))
    local active, inactive = 0, 0
    for _, obj in ipairs(listClowns()) do
        if obj:GetAttribute("Active") == true then active = active + 1 else inactive = inactive + 1 end
    end
    line("Clowns Active/other: " .. active .. "/" .. inactive)
    -- Limit the inspection to Section1 rather than enumerating the full world.
    if s1 then
        local candidates = {}
        local seen = 0
        for _, obj in ipairs(s1:GetDescendants()) do
            local name = obj.Name:lower()
            if name:find("dart", 1, true) or name:find("ring", 1, true)
                or name:find("dunk", 1, true) or name:find("basket", 1, true)
                or name:find("golf", 1, true) or name:find("clown", 1, true)
                or name:find("striker", 1, true) or name:find("hammer", 1, true) then
                seen = seen + 1
                if #candidates < 50 then
                    table.insert(candidates, obj:GetFullName() .. "<" .. obj.ClassName .. ">")
                end
            end
        end
        line("Section1 minigame-name hits: " .. seen)
        for _, obj in ipairs(candidates) do line("  " .. obj) end
        if seen > #candidates then line("  [truncated]") end
    end
    line("Caution: packet sent != server accepted. Current event can change paths/arguments.")
    return table.concat(lines, "\n")
end

local function printRuntimeReport(copyIt)
    local report = buildRuntimeReport()
    print(report)
    if type(writefile) == "function" then
        local okSave, saveErr = pcall(writefile, "Circus_Diagnostic.txt", report)
        if not okSave then warn("[NMCS] writefile: " .. tostring(saveErr)) end
    end
    if copyIt and type(setclipboard) == "function" then
        local ok, err = pcall(setclipboard, report)
        if ok then
            notify("Đã sao chép báo cáo", "Dán nội dung báo cáo NMCS vào cuộc trò chuyện để xác định đường dẫn game mới.", "check")
            return
        end
        warn("[NMCS] setclipboard: " .. tostring(err))
    end
    notify("Báo cáo runtime", "Đã in F9 và thử lưu Circus_Diagnostic.txt; gửi báo cáo để đối chiếu source 229.", "info")
end

-- ==========================================================================
-- NativeUI: both games load the same library from GitHub; windows remain independent.
-- ==========================================================================
local function loadWindUI()
    local base = "https://raw.githubusercontent.com/eystearisdown/wyattrz/main/"
    local errors = {}
    for _, filename in ipairs({ "NativeUI.lua", "ui.lua" }) do
        local ok, result = pcall(function()
            local code = game:HttpGet(base .. filename, true)
            if type(code) ~= "string" or #code < 1024 or code:lower():find("<!doctype", 1, true) then
                error("Nội dung UI không phải Lua hợp lệ")
            end
            local fn, loadErr = loadstring(code)
            if not fn then error(loadErr) end
            return fn()
        end)
        if ok and result and type(result.CreateWindow) == "function" then
            if filename ~= "NativeUI.lua" then
                warn("[NMCS] Repo chưa có NativeUI.lua, đang dùng ui.lua cũ. Hãy đổi tên khi upload.")
            end
            return result
        end
        table.insert(errors, filename .. ": " .. tostring(result))
    end
    warn("[NMCS] Không thể nạp NativeUI: " .. table.concat(errors, " | "))
    return nil
end

WindUI = loadWindUI()
if not WindUI then
    cleanup()
    return
end
pcall(function() WindUI:SetTheme("Dark") end)

local screen = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(900, 600)
local mobile = UserInputService.TouchEnabled or screen.X < 760
local h = mobile and math.clamp(math.floor(screen.Y * 0.78), 300, 430) or 420
local w = mobile and math.clamp(math.floor(screen.X * 0.9), 350, 650) or 650
local side = mobile and 118 or 122
local ok, result = pcall(function()
    return WindUI:CreateWindow({
        Title = "Nevoirs - Nightmare Circus",
        Author = "Nevoirs",
        Icon = BRAND_ICON,
        Folder = "Nevoirs_NMCS",
        Size = UDim2.fromOffset(w, h),
        MinSize = Vector2.new(w, h),
        MaxSize = Vector2.new(w, h),
        ToggleKey = Enum.KeyCode.RightControl,
        Transparent = true,
        Theme = "Dark",
        Resizable = false,
        SideBarWidth = side,
        HideSearchBar = true,
        ScrollBarEnabled = true,
        Topbar = { Height = mobile and 64 or 58, ButtonsType = "Default" },
        OpenButton = { Enabled = false },
    })
end)
if not ok or not result then
    warn("[NMCS] Không tạo được window: " .. tostring(result))
    cleanup()
    return
end
Window = result
uiScale(Settings.UIScale)
makeLeftToggle()

local function paragraph(tab, title, desc, icon)
    pcall(function()
        tab:Paragraph({ Title = title, Desc = desc, Image = icon or "info", ImageSize = 26, Color = SKY })
    end)
end
local function divider(tab)
    pcall(function() tab:Divider() end)
end
local function addButton(tab, title, description, fn)
    local okAdd, err = pcall(function()
        return tab:Button({ Title = title, Callback = function() runOnce(title, fn) end })
    end)
    if not okAdd then warn("[NMCS] Button: " .. tostring(err)) end
end
local function addUtilityButton(tab, title, fn)
    local okAdd, err = pcall(function()
        return tab:Button({ Title = title, Callback = function()
            local good, fail = pcall(fn)
            if not good then notify(title, fail, "circle-alert") end
        end })
    end)
    if not okAdd then warn("[NMCS] Button: " .. tostring(err)) end
end
local function addToggle(tab, key, title, description, onChanged)
    local okAdd, control = pcall(function()
        return tab:Toggle({
            Title = title,
            Value = States[key] == true,
            Callback = function(value)
                if not life.alive then return end
                States[key] = value == true
                if onChanged then
                    local success, err = pcall(onChanged, States[key])
                    if not success then notify(title, err, "circle-alert") end
                end
            end,
        })
    end)
    if okAdd then Controls[key] = control
    else warn("[NMCS] Toggle: " .. tostring(control)) end
end
local function addNumber(tab, title, field, min, max, onSet)
    pcall(function()
        tab:Input({
            Title = title,
            Value = tostring(Settings[field]),
            Type = "Input",
            Placeholder = tostring(Settings[field]),
            Callback = function(value)
                local n = tonumber(value)
                if not n or n ~= n or n == math.huge or n == -math.huge then return end
                Settings[field] = math.clamp(n, min, max)
                saveSettings()
                if onSet then onSet(Settings[field]) end
            end,
        })
    end)
end

local ClownTab = Window:Tab({ Title = "Clown", Icon = "target" })
local DimitraTab = Window:Tab({ Title = "Dimitra", Icon = "skull" })
local ESPTab = Window:Tab({ Title = "ESP", Icon = "eye" })
local PlayerTab = Window:Tab({ Title = "Cá nhân", Icon = "user" })
local SettingTab = Window:Tab({ Title = "Cài đặt", Icon = "settings" })

local currentEvent = Workspace:GetAttribute("MimicEvent")
paragraph(ClownTab, "Nightmare Circus 2026 • Bản rebuild", "Các lệnh bên dưới giữ nguyên packet từ source 229 (chưa xác nhận tương thích bản mới). MimicEvent: " .. tostring(currentEvent), "info")
paragraph(ClownTab, "Section 1 • Clown", "Đã vào minigame vẫn có thể không hoạt động nếu server thay packet/arguments. Mở Cài đặt → Sao chép báo cáo để chẩn đoán.", "target")
addButton(ClownTab, "Auto Darts • 15 điểm", "", function(token)
    return throwSequence("Section1/DartsThrow", DART_COORDS, 0.3, token)
end)
addButton(ClownTab, "Auto Ring • 6 điểm", "", function(token)
    return throwSequence("Section1/RingThrow", RING_COORDS, 1, token)
end)
addButton(ClownTab, "Auto Dunk", "", function()
    return fire("Section1/DunkThrow", 0.27402551854143786, -0.0085155691596274265)
end)
addButton(ClownTab, "Auto Basketball", "", doBasketball)
addButton(ClownTab, "Auto Golf", "", doGolf)
divider(ClownTab)
paragraph(ClownTab, "Nhiệm vụ tự động", "Bật khi minigame tương ứng đang chạy. Có thể tắt độc lập.", "zap")
addToggle(ClownTab, "AutoClowns", "Auto Clowns • Whack", "")
addToggle(ClownTab, "AutoHammer", "Auto Hammer • High Striker", "")

paragraph(DimitraTab, "Section 2 • Dimitra Puzzles", "Moon, Star, Tarot: vào minigame ít nhất một lần trước khi hoàn thành tự động.", "moon")
addButton(DimitraTab, "Auto Moon Puzzle", "", function(token) return completePuzzle("Moon", token) end)
addButton(DimitraTab, "Auto Star Puzzle", "", function(token) return completePuzzle("Star", token) end)
addButton(DimitraTab, "Auto Tarot Puzzle", "", function(token) return completePuzzle("Tarot", token) end)
divider(DimitraTab)
paragraph(DimitraTab, "Eye Statues • TheHollow", "MimicEvent=" .. tostring(currentEvent) .. ". Source 229 chỉ thay thứ tự ghép tượng–gương khi bằng TheHollow; không có logic Clown riêng cho The Hollow. Bật trước khi minigame chạy.", "eye")
addToggle(DimitraTab, "AutoStatues", "Auto Statues • Theo thứ tự gương", "", function(v)
    if not v then clearEyeWatch() else registerEyeWatcher() end
end)
divider(DimitraTab)
paragraph(DimitraTab, "Section 3 • Boss", "Teleport đến PlayerHitbox + MagicAxe/SwingHit theo source 229.", "swords")
addToggle(DimitraTab, "AutoBoss", "Auto Kill Dimitra", "")

paragraph(ESPTab, "ESP người chơi", "Highlight toàn model + tên + khoảng cách, giống CC.", "users")
addToggle(ESPTab, "ESPPlayer", "ESP Player", "", function(v) if not v then clearESP("Player") end end)
divider(ESPTab)
paragraph(ESPTab, "ESP Nightmare Circus", "Quét đúng đối tượng trong 229; không suy đoán tên quái hay path ngoài source.", "eye")
addToggle(ESPTab, "ESPClowns", "ESP Clowns • Đỏ cam", "", function(v) if not v then clearESP("Clown") end end)
addToggle(ESPTab, "ESPTasks", "ESP Puzzles & Statues • Vàng", "", function(v) if not v then clearESP("Task") end end)
addToggle(ESPTab, "ESPBoss", "ESP Dimitra Boss • Đỏ", "", function(v) if not v then clearESP("Boss") end end)

paragraph(PlayerTab, "Di chuyển", "Các tiện ích client theo phong cách CC, không phụ thuộc 229.", "user")
addToggle(PlayerTab, "TPWalk", "TPWalk", "")
addNumber(PlayerTab, "TPWalk • Tốc độ", "TPWalkSpeed", 0, 9999)
addToggle(PlayerTab, "Noclip", "Noclip", "", function(v) if not v then restoreNoclip() end end)
addToggle(PlayerTab, "Moonwalk", "Moonwalk • Ngược hướng camera", "", function(v)
    if not v then restoreMoonwalk() end
end)
addToggle(PlayerTab, "InfiniteJump", "Nhảy vô hạn", "")
addToggle(PlayerTab, "Fullbright", "Sáng map (Fullbright)", "", setFullbright)
addToggle(PlayerTab, "VFly", "VFly • Bay theo camera", "", function(v)
    if v then startVFly() else stopVFly() end
end)
addNumber(PlayerTab, "VFly • Tốc độ", "VFlySpeed", 0, 99999)
divider(PlayerTab)
paragraph(PlayerTab, "Tương tác & Yen", "Dùng chung logic Local Player từ B3C1.", "hand")
addToggle(PlayerTab, "InstantE", "Instant E • Giữ prompt = 0", "", setInstantE)
addToggle(PlayerTab, "AutoYenESP", "ESP Yen", "", function(v)
    if not v then clearESP("Yen") end
end)
addToggle(PlayerTab, "AutoYenCollect", "Yen Aura • Nhặt trong 10 studs", "")

paragraph(SettingTab, "Giao diện", "NativeUI + avatar tròn bên trái, riêng biệt với B3C1.", "settings")
addNumber(SettingTab, "UI Scale", "UIScale", 0.58, 0.95, uiScale)
addNumber(SettingTab, "Kích cỡ nút avatar", "ToggleScale", 0.6, 2, setToggleSize)
divider(SettingTab)
paragraph(SettingTab, "Công cụ kiểm tra", "F9 hiển thị trạng thái đường dẫn và packet; không gửi packet khi kiểm tra.", "list-check")
addUtilityButton(SettingTab, "Kiểm tra Section / Packet • F9", function()
    local paths = {
        {"Packet Reliable", getPacket()},
        {"Section1 Games", at(Workspace, "Section1", "Games")},
        {"Clown objects", at(Workspace, "Section1", "Games", "WhackAClown", "Clowns")},
        {"Golf", at(Workspace, "Section1", "Games", "MiniGolf")},
        {"Moon", at(Workspace, "Section2", "MainObjective", "Puzzle3")},
        {"Star", at(Workspace, "Section2", "MainObjective", "Puzzle1")},
        {"Tarot", at(Workspace, "Section2", "MainObjective", "Puzzle4")},
        {"Statues", at(Workspace, "Section2", "MainObjective", "Puzzle2")},
        {"Dimitra hitbox", at(Workspace, "Section3", "DimitraBOSS", "PlayerHitbox")},
    }
    print("===== Nevoirs NMCS diagnostics =====")
    for _, entry in ipairs(paths) do
        print(string.format("%-23s %s", entry[1], entry[2] and "OK" or "CHƯA CÓ"))
    end
    print("Clown tags visible: " .. #listClowns())
    print("Statue orders queued: " .. #statueState.orders)
    print("Known Yen folders: " .. #yenFolders())
    notify("Kiểm tra NMCS", "Đã ghi chi tiết vào console F9. Đối tượng theo Section có thể chưa tải.", "info")
end)
addUtilityButton(SettingTab, "Sao chép báo cáo Clown / TheHollow (không tương tác server)", function()
    printRuntimeReport(true)
end)
addUtilityButton(SettingTab, "In báo cáo runtime mới vào F9", function()
    printRuntimeReport(false)
end)
addUtilityButton(SettingTab, "Hủy thao tác đang chạy", cancelOnce)
addUtilityButton(SettingTab, "Tắt tất cả Auto", function()
    for _, key in ipairs({ "AutoClowns", "AutoHammer", "AutoStatues", "AutoBoss" }) do
        States[key] = false
        local control = Controls[key]
        if control and control.SetValue then pcall(function() control:SetValue(false) end) end
    end
    clearEyeWatch()
    cancelOnce()
end)
addUtilityButton(SettingTab, "Unload Nightmare Circus", cleanup)

pcall(function() ClownTab:Select() end)
notify("Nevoirs - Nightmare Circus", "Circus v2 • Logic 229 cũ, server event 2026 có thể đã đổi. Vào Cài đặt để xuất báo cáo Clown/TheHollow.", "info")
