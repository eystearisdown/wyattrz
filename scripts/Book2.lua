-- Mimic CC UI 1.1.0 / Book2
-- Loads the original cc WindUI from your shared GitHub UI file.
-- Book2 includes all supplied Paintings coordinates; no painting download is needed.
local PAYLOAD = [====[
-- Generated from the maintained source modules. No GG loader is required.
local Modules = {}

Modules.VisualsPlayer = function()
-- Slate: a shared ESP renderer and reversible local-player controller.
-- The module deliberately uses no remote UI, Drawing API, or per-label loops.
return function(ctx)
    local S = ctx.Services
    local Players, Run, Input = S.Players, S.RunService, S.UserInputService
    local Lighting, World, Prompts = S.Lighting, S.Workspace, S.ProximityPromptService
    local player = ctx.Player
    ctx.Config.Client = ctx.Config.Client or {}
    ctx.Config.Client.Client = ctx.Config.Client.Client or {}
    ctx.Config.SlateESP = ctx.Config.SlateESP or {}
    local client, settings = ctx.Config.Client.Client, ctx.Config.SlateESP
    local function default(t, key, value) if t[key] == nil then t[key] = value end end
    default(client, "VFly", false)
    default(client, "VFlySpeed", 60)
    default(client, "TPWalkSpeed", 35)
    default(client, "Enable TeleportWalk", false)
    default(client, "Noclip", false)
    default(client, "Moonwalk", false)
    default(client, "Full Bright", false)
    default(client, "InstantPrompt", false)
    default(client, "FlyKeyEnabled", true)
    default(settings, "Enabled", true)
    default(settings, "Distance", 1800)
    default(settings, "Labels", true)
    default(settings, "Outlines", true)
    default(settings, "Players", false)
    default(settings, "Threats", true)
    default(settings, "Objectives", true)
    default(settings, "Currency", true)
    default(settings, "AvoidOverlap", true)
    default(settings, "LabelBudget", 60)
    local function number(value, fallback, low, high)
        local n = tonumber(value)
        if not n or n ~= n or n == math.huge or n == -math.huge then n = fallback end
        return math.clamp(n, low, high)
    end
    settings.Distance = number(settings.Distance, 1800, 100, 6000)
    settings.LabelBudget = number(settings.LabelBudget, 60, 10, 80)
    client.VFlySpeed = number(client.VFlySpeed, 60, 5, 250)
    client.TPWalkSpeed = number(client.TPWalkSpeed, 35, 1, 200)
    local live, connections, registry, categories = true, {}, {}, {}
    local palette = {
        Players = Color3.fromRGB(104, 226, 193),
        Threats = Color3.fromRGB(255, 126, 119),
        Objectives = Color3.fromRGB(116, 184, 255),
        Currency = Color3.fromRGB(246, 203, 108),
        Complete = Color3.fromRGB(104, 226, 193),
        Pending = Color3.fromRGB(246, 203, 108),
    }
    local symbols = { Players = "●", Threats = "◆", Objectives = "◇", Currency = "¥" }
    local overlay = Instance.new("Folder")
    overlay.Name = "Slate_Visuals"
    overlay.Parent = World
    local function connect(signal, fn)
        local c = signal:Connect(fn)
        connections[#connections + 1] = c
        return c
    end
    local function save() if ctx.Save then ctx.Save() end end
    local function notify(title, content) if ctx.Notify then ctx.Notify(title, content) end end
    local function new(class, props, parent)
        local object = Instance.new(class)
        for key, value in pairs(props or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function isInWorld(object)
        return object and object.Parent and object:IsDescendantOf(World)
    end
    local function anchorOf(object)
        if not object or not object.Parent then return nil end
        if object:IsA("BasePart") then return object end
        if object:IsA("Attachment") then return object.Parent:IsA("BasePart") and object.Parent or nil end
        if object:IsA("ProximityPrompt") then return anchorOf(object.Parent) end
        if object:IsA("Model") then
            return object.PrimaryPart or object:FindFirstChild("HumanoidRootPart")
                or object:FindFirstChild("Head") or object:FindFirstChildWhichIsA("BasePart", true)
        end
        return object:FindFirstChildWhichIsA("BasePart", true)
    end
    local function semantic(category, color)
        local name = string.lower(tostring(category))
        if name:find("player", 1, true) then return "Players" end
        if name:find("yen", 1, true) or name:find("currency", 1, true) then return "Currency" end
        for _, word in ipairs({ "monster", "gata", "akari", "mizuno", "hogo", "baigai", "shinigami", "ashina", "futakuchi", "kurobozu", "ohaguro", "mother", "grindemon", "soldier", "boogey", "senzai", "enzukai", "followers" }) do
            if name:find(word, 1, true) then return "Threats" end
        end
        if typeof(color) == "Color3" and color.R > 0.65 and color.G < 0.43 and color.B < 0.55 then return "Threats" end
        return "Objectives"
    end
    local function statusColor(group, color)
        if group == "Objectives" and typeof(color) == "Color3" then
            if color.G > 0.55 and color.R < 0.42 and color.B < 0.6 then return palette.Complete end
            if color.R > 0.65 and color.G > 0.55 and color.B < 0.45 then return palette.Pending end
        end
        return palette[group]
    end
    local function destroyGraphics(entry)
        if entry.highlight then entry.highlight:Destroy(); entry.highlight = nil end
        if entry.billboard then entry.billboard:Destroy(); entry.billboard = nil end
        entry.label, entry.dot, entry.stroke = nil, nil, nil
    end
    local function hide(entry)
        destroyGraphics(entry)
    end
    local function makeOutline(entry)
        if entry.highlight then return end
        local adornee = entry.object
        if not adornee:IsA("Model") and not adornee:IsA("BasePart") then adornee = entry.anchor end
        entry.highlight = new("Highlight", {
            Name = "Slate_Outline", Adornee = adornee, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            FillColor = entry.color, OutlineColor = entry.color, FillTransparency = 0.94,
            OutlineTransparency = 0.18, Enabled = false,
        }, overlay)
    end
    local function labelOffset(entry)
        if entry.offset then return entry.offset end
        local sizeY = entry.anchor.Size.Y
        if entry.object:IsA("Model") then
            local ok, extents = pcall(entry.object.GetExtentsSize, entry.object)
            if ok then sizeY = extents.Y end
        end
        entry.offset = Vector3.new(0, math.clamp(sizeY * 0.5 + 0.8, 1.3, 8), 0)
        return entry.offset
    end
    local function makeLabel(entry)
        if entry.billboard then return end
        local billboard = new("BillboardGui", {
            Name = "Slate_Label", Adornee = entry.anchor, AlwaysOnTop = true,
            LightInfluence = 0, MaxDistance = settings.Distance,
            Size = UDim2.fromOffset(190, 24), StudsOffsetWorldSpace = labelOffset(entry),
            Enabled = false,
        }, overlay)
        local capsule = new("Frame", {
            Name = "Capsule", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 20, 27),
            BackgroundTransparency = 0.12, BorderSizePixel = 0,
        }, billboard)
        new("UICorner", { CornerRadius = UDim.new(0, 7) }, capsule)
        entry.stroke = new("UIStroke", { Color = entry.color, Transparency = 0.55, Thickness = 1 }, capsule)
        entry.dot = new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 0), Size = UDim2.fromOffset(17, 24),
            Font = Enum.Font.GothamBold, TextSize = 11, Text = symbols[entry.group], TextColor3 = entry.color,
        }, capsule)
        entry.label = new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(27, 0), Size = UDim2.new(1, -35, 1, 0),
            Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(229, 237, 246),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, RichText = false,
            Text = entry.text,
        }, capsule)
        entry.billboard = billboard
    end
    local ESPF = {}
    local nullHandle = { UpdateColor = function() end, UpdateText = function() end, Destroy = function() end, Visualize = function() end }
    function ESPF.ESP(category, object, opts)
        if not live or typeof(object) ~= "Instance" then return nullHandle end
        opts = opts or {}
        category = tostring(category or "Objectives")
        local bucket = categories[category]
        if not bucket then bucket = { enabled = true, objects = {} }; categories[category] = bucket end
        local old = bucket.objects[object]
        if old and not old.dead then
            if opts.Text ~= nil then old.handle.UpdateText(opts.Text) end
            if opts.Color then old.handle.UpdateColor(opts.Color) end
            return old.handle
        end
        -- Registrations are cheap; GPU objects are allocated only for the active budget.
        local group = semantic(category, opts.Color)
        local entry = {
            category = category, object = object, anchor = anchorOf(object), group = group,
            text = tostring(opts.Text or object.Name), color = statusColor(group, opts.Color), dead = false,
        }
        local handle = {}
        entry.handle = handle
        function handle.UpdateColor(first, second)
            local color = second or first
            if entry.dead then return end
            entry.color = statusColor(entry.group, color)
            if entry.highlight then entry.highlight.FillColor = entry.color; entry.highlight.OutlineColor = entry.color end
            if entry.dot then entry.dot.TextColor3 = entry.color end
            if entry.stroke then entry.stroke.Color = entry.color end
        end
        function handle.UpdateText(first, second)
            if not entry.dead then entry.text = tostring(second or first or "") end
        end
        function handle.Destroy()
            if entry.dead then return end
            entry.dead = true
            bucket.objects[object] = nil
            registry[entry] = nil
            destroyGraphics(entry)
            -- Some original game handlers attach their own one-shot property connection.
            for _, key in ipairs({ "PropChange", "ChangeSignal" }) do
                if handle[key] then pcall(handle[key].Disconnect, handle[key]); handle[key] = nil end
            end
        end
        function handle.Visualize() end -- renderer is shared, legacy 2D callbacks are harmless.
        bucket.objects[object], registry[entry] = entry, true
        return handle
    end
    function ESPF.Visible(category, value)
        category = tostring(category)
        local bucket = categories[category]
        if not bucket then bucket = { enabled = value == true, objects = {} }; categories[category] = bucket end
        bucket.enabled = value == true
        if not bucket.enabled then
            for _, entry in pairs(bucket.objects) do hide(entry) end
        end
    end
    function ESPF.Method() return "Slate" end
    local lastPlayerScan, candidates = 0, {}
    local function scanPlayers()
        if not settings.Players then return end
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= player and target.Character and target.Character.Parent then
                local name = target.DisplayName ~= target.Name and (target.DisplayName .. " @" .. target.Name) or target.Name
                ESPF.ESP("Players", target.Character, { Text = name, Color = palette.Players })
            end
        end
    end
    local function updateESP()
        local camera = World.CurrentCamera
        if not camera then return end
        local origin = camera.CFrame.Position
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then origin = root.Position end
        table.clear(candidates)
        local now = os.clock()
        if now - lastPlayerScan >= 1 then lastPlayerScan = now; scanPlayers() end
        for entry in pairs(registry) do
            if entry.dead or not isInWorld(entry.object) then
                entry.handle.Destroy()
            else
                if not entry.anchor or not isInWorld(entry.anchor) then entry.anchor = anchorOf(entry.object); entry.offset = nil; destroyGraphics(entry) end
                local bucket = categories[entry.category]
                if entry.anchor and settings.Enabled and bucket.enabled and settings[entry.group] then
                    local distance = (entry.anchor.Position - origin).Magnitude
                    if distance <= settings.Distance then
                        entry.distance = distance
                        entry.screen, entry.onScreen = camera:WorldToViewportPoint(entry.anchor.Position)
                        entry.labelScreen, entry.labelOnScreen = camera:WorldToViewportPoint(entry.anchor.Position + labelOffset(entry))
                        candidates[#candidates + 1] = entry
                    else hide(entry) end
                else hide(entry) end
            end
        end
        table.sort(candidates, function(a, b)
            local aWeight = a.distance + (a.group == "Threats" and -35 or 0)
            local bWeight = b.distance + (b.group == "Threats" and -35 or 0)
            return aWeight < bWeight
        end)
        local outlineCount, labelCount, rectangles = 0, 0, {}
        for _, entry in ipairs(candidates) do
            local showOutline = settings.Outlines and outlineCount < 28 and entry.onScreen
            if showOutline then
                makeOutline(entry)
                entry.highlight.Enabled = true
                outlineCount = outlineCount + 1
            elseif entry.highlight then
                -- Disabled Highlights can still consume engine slots, so release them.
                entry.highlight:Destroy(); entry.highlight = nil
            end
            local showLabel = settings.Labels and labelCount < settings.LabelBudget and entry.labelOnScreen and entry.labelScreen.Z > 0
            local width = math.clamp(58 + #entry.text * 5.7, 108, 238)
            local rect = { entry.labelScreen.X - width / 2, entry.labelScreen.Y - 12, entry.labelScreen.X + width / 2, entry.labelScreen.Y + 12 }
            if showLabel and settings.AvoidOverlap then
                for _, other in ipairs(rectangles) do
                    if rect[1] < other[3] + 4 and rect[3] + 4 > other[1] and rect[2] < other[4] + 3 and rect[4] + 3 > other[2] then showLabel = false; break end
                end
            end
            if showLabel then
                makeLabel(entry)
                entry.billboard.Adornee = entry.anchor
                entry.billboard.MaxDistance = settings.Distance
                entry.billboard.Size = UDim2.fromOffset(width, 24)
                entry.billboard.Enabled = true
                entry.label.Text = entry.text .. " · " .. tostring(math.floor(entry.distance + 0.5)) .. " st"
                entry.label.TextTransparency = entry.distance > settings.Distance * 0.85 and 0.25 or 0
                rectangles[#rectangles + 1] = rect
                labelCount = labelCount + 1
            elseif entry.billboard then
                -- Do not retain hundreds of UI instances after visiting a dense area.
                entry.billboard:Destroy(); entry.billboard, entry.label, entry.dot, entry.stroke = nil, nil, nil, nil
            end
        end
    end

    -- Player controls share lifecycle/priority; cc flight keeps its RenderStepped update.
    local character, humanoid, root = nil, nil, nil
    local collisionCache = setmetatable({}, { __mode = "k" })
    local rotationCache, flyRecord, floatRecord = nil, nil, nil
    local forcedFloat = "None"
    local promptCache = setmetatable({}, { __mode = "k" })
    local instantWas, lightingRecord, lightApplying = false, nil, false
    local environmentOwners, lightDesired = {}, {}
    local atmosphereCache = setmetatable({}, { __mode = "k" })
    local windowFocused = true
    local brightness = {
        Brightness = 2, ClockTime = 14, FogEnd = 1000000, GlobalShadows = false,
        Ambient = Color3.fromRGB(178, 184, 193), OutdoorAmbient = Color3.fromRGB(178, 184, 193), ExposureCompensation = 0.25,
    }
    local function restoreCollision()
        for part, value in pairs(collisionCache) do
            if part.Parent then pcall(function() part.CanCollide = value end) end
            collisionCache[part] = nil
        end
    end
    local function restoreRotation()
        if rotationCache then
            if rotationCache.hum.Parent then rotationCache.hum.AutoRotate = rotationCache.value end
            rotationCache = nil
        end
    end
    local function stopFly()
        if not flyRecord then return end
        local record = flyRecord
        flyRecord = nil
        if record.stateConnection then record.stateConnection:Disconnect() end
        if record.velocity then record.velocity:Destroy() end
        if record.orientation then record.orientation:Destroy() end
        if record.hum and record.hum.Parent then
            record.hum.WalkSpeed = record.walkSpeed
            if record.hum.Health > 0 then record.hum:ChangeState(Enum.HumanoidStateType.Running) end
        end
        if record.root and record.root.Parent then
            record.root.AssemblyLinearVelocity = Vector3.zero
            record.root.AssemblyAngularVelocity = Vector3.zero
        end
        if not client.Moonwalk then restoreRotation() end
    end
    local function stopFloat()
        if floatRecord then
            if floatRecord.force then floatRecord.force:Destroy() end
            if floatRecord.attachment then floatRecord.attachment:Destroy() end
            floatRecord = nil
        end
    end
    local function onCharacter(char)
        if character == char then return end
        stopFly(); stopFloat(); restoreCollision(); restoreRotation()
        character, humanoid, root = char, nil, nil
        forcedFloat = "None"
    end
    local function suppressRotation()
        if not humanoid then return end
        if not rotationCache or rotationCache.hum ~= humanoid then
            restoreRotation()
            rotationCache = { hum = humanoid, value = humanoid.AutoRotate }
        end
        humanoid.AutoRotate = false
    end
    local function beginFly()
        if flyRecord or not root or not humanoid then return end
        stopFloat()
        -- Keep cc's original force constants and camera/joystick feel.
        local orientation = new("BodyGyro", {
            Name = "Slate_FlightOrientation", MaxTorque = Vector3.new(9e9, 9e9, 9e9),
            P = 9e4, D = 1e3, CFrame = root.CFrame,
        }, root)
        local velocity = new("BodyVelocity", {
            Name = "Slate_FlightVelocity", MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero, P = 1e4,
        }, root)
        local record = { velocity = velocity, orientation = orientation, root = root, hum = humanoid, walkSpeed = humanoid.WalkSpeed }
        flyRecord = record
        humanoid.WalkSpeed = 0
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        record.stateConnection = humanoid.StateChanged:Connect(function(_, nextState)
            if live and client.VFly and flyRecord == record and nextState ~= Enum.HumanoidStateType.Physics then
                task.defer(function()
                    if live and client.VFly and flyRecord == record and record.hum.Parent and record.hum.Health > 0 then
                        record.hum:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                end)
            end
        end)
    end
    local function flyVector(camera)
        if not windowFocused or Input:GetFocusedTextBox() then return Vector3.zero end
        local look, right = camera.CFrame.LookVector, camera.CFrame.RightVector
        local flatL, flatR = Vector3.new(look.X, 0, look.Z), Vector3.new(right.X, 0, right.Z)
        if flatL.Magnitude > 0 then flatL = flatL.Unit end
        if flatR.Magnitude > 0 then flatR = flatR.Unit end
        local move, md = Vector3.zero, humanoid.MoveDirection
        if md.Magnitude > 0.16 and flatL.Magnitude > 0 and flatR.Magnitude > 0 then
            -- cc's tuned mobile input: project the joystick on horizontal axes,
            -- then reconstruct it using the camera's full 3D pitch and right axis.
            local forward = math.clamp(md:Dot(flatL), -1, 1)
            local strafe = math.clamp(md:Dot(flatR), -1, 1)
            if math.abs(forward) < 0.18 then forward = 0 end
            if math.abs(strafe) < 0.18 then strafe = 0 end
            if forward ~= 0 or strafe ~= 0 then move = move + look * forward + right * strafe end
        else
            if Input:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if Input:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if Input:IsKeyDown(Enum.KeyCode.A) then move = move - right end
            if Input:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        end
        if Input:IsKeyDown(Enum.KeyCode.Space) or Input:IsKeyDown(Enum.KeyCode.E) then move = move + Vector3.new(0, 1, 0) end
        if Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.Q) then move = move - Vector3.new(0, 1, 0) end
        return move.Magnitude > 0.08 and move.Unit or Vector3.zero
    end
    local function updateMovement(dt)
        if player.Character ~= character then onCharacter(player.Character) end
        if not character or not character.Parent then return end
        humanoid = character:FindFirstChildOfClass("Humanoid")
        root = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then
            stopFly(); stopFloat(); restoreCollision(); restoreRotation()
            return
        end
        if flyRecord and (flyRecord.root ~= root or flyRecord.hum ~= humanoid or not flyRecord.velocity.Parent or not flyRecord.orientation.Parent) then stopFly() end
        if floatRecord and floatRecord.root ~= root then stopFloat() end
        if client.Noclip then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if collisionCache[part] == nil then collisionCache[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
        elseif next(collisionCache) then restoreCollision() end
        local camera = World.CurrentCamera
        if client.VFly and camera then
            suppressRotation(); beginFly()
        else
            stopFly()
            local wantsFloat = forcedFloat == true or (forcedFloat ~= false and client.Float == true)
            if wantsFloat then
                if not floatRecord then
                    local attachment = new("Attachment", { Name = "Slate_Float" }, root)
                    local force = new("VectorForce", { Name = "Slate_FloatForce", Attachment0 = attachment, ApplyAtCenterOfMass = true, RelativeTo = Enum.ActuatorRelativeTo.World }, root)
                    floatRecord = { attachment = attachment, force = force, root = root }
                end
                floatRecord.force.Force = Vector3.new(0, root.AssemblyMass * World.Gravity, 0)
                local velocity = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            else stopFloat() end
            if client["Enable TeleportWalk"] and windowFocused and not Input:GetFocusedTextBox() and humanoid.MoveDirection.Magnitude > 0 then
                character:TranslateBy(humanoid.MoveDirection * number(client.TPWalkSpeed, 35, 1, 200) * math.min(dt, 0.1))
            end
            if client.Moonwalk and camera then
                suppressRotation()
                local flat = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
                if flat.Magnitude > 0.01 then root.CFrame = CFrame.lookAt(root.Position, root.Position - flat.Unit) end
            else restoreRotation() end
        end
    end
    local function restoreAtmospheres()
        for atmosphere, values in pairs(atmosphereCache) do
            if atmosphere.Parent then
                atmosphere.Density = values.Density
                atmosphere.Haze = values.Haze
            end
            atmosphereCache[atmosphere] = nil
        end
    end
    local function restoreLighting()
        if not lightingRecord then return end
        lightApplying = true
        for property, value in pairs(lightingRecord) do Lighting[property] = value end
        lightApplying, lightingRecord = false, nil
        table.clear(lightDesired)
        restoreAtmospheres()
    end
    local function updateLighting()
        local fullbright, noFog = client["Full Bright"] == true, false
        for _, effects in pairs(environmentOwners) do
            fullbright = fullbright or effects.FullBright == true or effects.Fullbright == true
            noFog = noFog or effects.NoFog == true
        end
        local desired = {}
        if fullbright then for property, value in pairs(brightness) do desired[property] = value end end
        if noFog then desired.FogStart = 0; desired.FogEnd = 1000000 end
        if not next(desired) then restoreLighting(); restoreAtmospheres(); return end
        lightingRecord = lightingRecord or {}
        lightApplying = true
        for property, value in pairs(lightingRecord) do
            if desired[property] == nil then Lighting[property] = value; lightingRecord[property] = nil end
        end
        for property, value in pairs(desired) do
            if lightingRecord[property] == nil then lightingRecord[property] = Lighting[property] end
            if Lighting[property] ~= value then Lighting[property] = value end
        end
        lightDesired, lightApplying = desired, false
        if noFog then
            for _, object in ipairs(Lighting:GetChildren()) do
                if object:IsA("Atmosphere") then
                    if not atmosphereCache[object] then atmosphereCache[object] = { Density = object.Density, Haze = object.Haze } end
                    object.Density, object.Haze = 0, 0
                end
            end
        else restoreAtmospheres() end
    end
    local lightingProperties = {}
    for property in pairs(brightness) do lightingProperties[#lightingProperties + 1] = property end
    lightingProperties[#lightingProperties + 1] = "FogStart"
    for _, property in ipairs(lightingProperties) do
        connect(Lighting:GetPropertyChangedSignal(property), function()
            if live and lightingRecord and lightingRecord[property] ~= nil and not lightApplying and Lighting[property] ~= lightDesired[property] then lightingRecord[property] = Lighting[property] end
        end)
    end
    local function recordPrompt(prompt)
        if not live or not client.InstantPrompt or not prompt:IsA("ProximityPrompt") then return end
        if promptCache[prompt] == nil then promptCache[prompt] = prompt.HoldDuration end
        prompt.HoldDuration = 0
    end
    local function restorePrompts()
        for prompt, duration in pairs(promptCache) do
            if prompt.Parent then prompt.HoldDuration = duration end
            promptCache[prompt] = nil
        end
    end
    local function updatePrompts()
        if client.InstantPrompt and not instantWas then
            instantWas = true
            for _, object in ipairs(World:GetDescendants()) do if object:IsA("ProximityPrompt") then recordPrompt(object) end end
        elseif not client.InstantPrompt and instantWas then instantWas = false; restorePrompts() end
    end
    connect(Prompts.PromptShown, recordPrompt)
    connect(World.DescendantAdded, function(object) if object:IsA("ProximityPrompt") then recordPrompt(object) end end)

    local flyControl
    connect(Input.InputBegan, function(input, processed)
        if processed or Input:GetFocusedTextBox() or not live then return end
        if input.KeyCode == Enum.KeyCode.V and client.FlyKeyEnabled then
            client.VFly = not client.VFly
            if flyControl and flyControl.SetValue then flyControl:SetValue(client.VFly) end
            save()
            notify("VFly", client.VFly and "Flight enabled · xoay camera + cần di chuyển" or "Flight disabled")
        end
    end)
    connect(Input.WindowFocusReleased, function()
        windowFocused = false
        if flyRecord then flyRecord.velocity.Velocity = Vector3.zero end
    end)
    connect(Input.WindowFocused, function() windowFocused = true end)
    connect(player.CharacterAdded, onCharacter)
    onCharacter(player.Character)
    -- cc updates flight in RenderStepped so camera rotation affects this frame.
    connect(Run.RenderStepped, function()
        if not live or ctx.Alive == false or not client.VFly or not flyRecord then return end
        local camera = World.CurrentCamera
        local record = flyRecord
        if not camera or not record.velocity.Parent or not record.orientation.Parent or not record.root.Parent then return end
        local move = flyVector(camera)
        if move.Magnitude > 0 then
            record.velocity.Velocity = move * number(client.VFlySpeed, 60, 5, 250)
            local look = camera.CFrame.LookVector
            if look.Magnitude > 0 then record.orientation.CFrame = CFrame.new(record.root.Position, record.root.Position + look) end
        else
            record.velocity.Velocity = Vector3.zero
            record.orientation.CFrame = record.root.CFrame
        end
    end)
    local espTime, environmentTime = 0, 0
    connect(Run.Heartbeat, function(dt)
        if not live or ctx.Alive == false then return end
        updateMovement(dt)
        espTime, environmentTime = espTime + dt, environmentTime + dt
        if espTime >= 0.1 then espTime = 0; updateESP() end
        if environmentTime >= 0.15 then environmentTime = 0; updateLighting(); updatePrompts() end
    end)
    local ClientPackage = {}
    function ClientPackage.UpdatePosition(float, force)
        if float ~= nil then client.Float = float == true end
        if force == true then forcedFloat = true
        elseif force == false then forcedFloat = false
        else forcedFloat = "None" end
    end
    function ClientPackage.Noclip(value) if value ~= nil then client.Noclip = value == true end end
    function ClientPackage.Brightness(value) if value ~= nil then client["Full Bright"] = value == true end end
    function ClientPackage.SetJumpPower() end
    function ClientPackage.SetWalkSpeed() end
    function ClientPackage.RunWalkSpeed() end
    function ClientPackage.WalkSpeedC() end
    local built = false
    local function buildTabs(window)
        if built or not window then return end
        built = true
        local visuals = window:Tab({ Title = "Visuals", Icon = "scan-eye" })
        visuals:Section({ Title = "Slate ESP", Desc = "One-line labels, soft outlines, semantic colors. Chapter target switches stay in each chapter tab." })
        local playerToggles = {}
        local function toggle(tab, title, desc, storage, key, onChange)
            local control = tab:Toggle({ Title = title, Desc = desc, Value = storage[key] == true, Callback = function(value)
                if not live then return end
                storage[key] = value == true
                if onChange then onChange(value == true) end
                save()
            end })
            if storage == client then playerToggles[key] = control end
            return control
        end
        toggle(visuals, "Enable overlays", "Master visibility for every Slate ESP category.", settings, "Enabled")
        toggle(visuals, "Players", "Mint · account identity and distance; excludes you.", settings, "Players", scanPlayers)
        toggle(visuals, "Threats", "Coral · monsters and bosses registered by chapter controls.", settings, "Threats")
        toggle(visuals, "Objectives", "Blue · tasks and items. Amber/green retain their original progress meaning.", settings, "Objectives")
        toggle(visuals, "Yen", "Amber · currency targets registered by the Yen controls.", settings, "Currency")
        visuals:Section({ Title = "Presentation", Desc = "Nearest targets win the display budget; streaming targets are released automatically." })
        toggle(visuals, "Compact labels", "Name · distance in studs, with a category symbol.", settings, "Labels")
        toggle(visuals, "Soft outlines", "Up to 28 nearby silhouettes, with 94% transparent fill.", settings, "Outlines")
        toggle(visuals, "Reduce label overlap", "Suppress overlapping labels while keeping nearer targets.", settings, "AvoidOverlap")
        visuals:Slider({ Title = "Maximum distance", Desc = "Studs from your character, or camera while no character exists.", Step = 50,
            Value = { Min = 100, Max = 6000, Default = settings.Distance }, Callback = function(value) settings.Distance = number(value, 1800, 100, 6000); save() end })
        visuals:Slider({ Title = "Label budget", Desc = "Lower budgets keep crowded scenes quieter.", Step = 1,
            Value = { Min = 10, Max = 80, Default = settings.LabelBudget }, Callback = function(value) settings.LabelBudget = number(value, 60, 10, 80); save() end })
        local tab = window:Tab({ Title = "Local Player", Icon = "person-standing" })
        tab:Section({ Title = "Movement", Desc = "VFly temporarily pauses TPWalk and Moonwalk, then resumes your selected modes." })
        flyControl = toggle(tab, "VFly", "Mobile: xoay camera + cần di chuyển. PC: WASD · Space/E lên · Shift/Q xuống.", client, "VFly", function(value) if not value then stopFly() end end)
        tab:Slider({ Title = "Flight speed", Desc = "Studs per second; diagonal movement is normalized.", Step = 1,
            Value = { Min = 5, Max = 250, Default = client.VFlySpeed }, Callback = function(value) client.VFlySpeed = number(value, 60, 5, 250); save() end })
        toggle(tab, "V shortcut", "Press V to switch flight while no text field is focused.", client, "FlyKeyEnabled")
        toggle(tab, "TPWalk", "Adds displacement in your movement direction; does not change Humanoid WalkSpeed.", client, "Enable TeleportWalk")
        tab:Slider({ Title = "TPWalk boost", Desc = "Additional studs per second above the game's normal movement.", Step = 1,
            Value = { Min = 1, Max = 200, Default = client.TPWalkSpeed }, Callback = function(value) client.TPWalkSpeed = number(value, 35, 1, 200); save() end })
        toggle(tab, "Noclip", "Temporarily disables character collisions and restores each original value when disabled.", client, "Noclip", function(value) if not value then restoreCollision() end end)
        toggle(tab, "Moonwalk", "Faces away from the camera. This changes facing direction, not animations.", client, "Moonwalk", function(value) if not value and not client.VFly then restoreRotation() end end)
        tab:Section({ Title = "Environment & interaction", Desc = "Restores lighting, prompt holds, collisions and character state on unload." })
        toggle(tab, "Fullbright", "Clear daytime lighting; the latest game lighting values are restored when disabled.", client, "Full Bright", updateLighting)
        toggle(tab, "Instant E", "Removes local proximity-prompt hold time. Server checks and distance restrictions still apply.", client, "InstantPrompt", updatePrompts)
        tab:Button({ Title = "Reset local controls", Desc = "Stops movement modes and restores all temporary local changes.", Callback = function()
            client.VFly, client.Noclip, client.Moonwalk, client["Enable TeleportWalk"] = false, false, false, false
            client["Full Bright"], client.InstantPrompt, client.Float = false, false, false
            forcedFloat = "None"
            stopFly(); stopFloat(); restoreCollision(); restoreRotation(); restoreLighting(); restorePrompts()
            instantWas = false
            for key, control in pairs(playerToggles) do if control.SetValue then control:SetValue(client[key] == true, true) end end
            save(); notify("Local Player", "Temporary local changes restored.")
        end })
    end
    local function destroy()
        if not live then return end
        live = false
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
        stopFly(); stopFloat(); restoreCollision(); restoreRotation(); restoreLighting(); restorePrompts()
        for entry in pairs(registry) do entry.handle.Destroy() end
        overlay:Destroy()
    end
    local api = { ESPF = ESPF, ClientPackage = ClientPackage, BuildTabs = buildTabs, OnCharacter = onCharacter, Destroy = destroy, Palette = palette }
    function api.SetEnvironment(first, second, third)
        local owner, effects = first, second
        if first == api then owner, effects = second, third end
        if not live or owner == nil then return end
        if type(effects) == "table" then environmentOwners[owner] = effects else environmentOwners[owner] = nil end
        updateLighting()
    end
    if ctx.addCleanup then ctx.addCleanup(destroy) end
    return api
end

end

Modules.Paintings = function()
local Vec2 = Vector2.new;
local CFr = CFrame.new;
local PlaceId = game.PlaceId;

local PaintingDatas = if PlaceId == 96354063422506 then
    {[84409295758845] = {
        { [1] = Vec2(37,123), [2] = 0},
        { [1] = Vec2(37,123), [2] = 1},
        { [1] = Vec2(37,123), [2] = 1},
        { [1] = Vec2(37,122), [2] = 1},
        { [1] = Vec2(37,122), [2] = 1},
        { [1] = Vec2(37,122), [2] = 1},
        { [1] = Vec2(37,122), [2] = 1},
        { [1] = Vec2(37,121), [2] = 1},
        { [1] = Vec2(37,121), [2] = 1},
        { [1] = Vec2(37,121), [2] = 1},
        { [1] = Vec2(37,121), [2] = 1},
        { [1] = Vec2(37,120), [2] = 1},
        { [1] = Vec2(37,120), [2] = 1},
        { [1] = Vec2(37,119), [2] = 1},
        { [1] = Vec2(37,119), [2] = 1},
        { [1] = Vec2(37,118), [2] = 1},
        { [1] = Vec2(37,118), [2] = 1},
        { [1] = Vec2(37,117), [2] = 1},
        { [1] = Vec2(37,117), [2] = 1},
        { [1] = Vec2(37,117), [2] = 1},
        { [1] = Vec2(37,117), [2] = 1},
        { [1] = Vec2(37,116), [2] = 1},
        { [1] = Vec2(37,116), [2] = 1},
        { [1] = Vec2(38,115), [2] = 1},
        { [1] = Vec2(38,115), [2] = 1},
        { [1] = Vec2(38,114), [2] = 1},
        { [1] = Vec2(38,114), [2] = 1},
        { [1] = Vec2(38,114), [2] = 1},
        { [1] = Vec2(38,114), [2] = 1},
        { [1] = Vec2(38,113), [2] = 1},
        { [1] = Vec2(38,113), [2] = 1},
        { [1] = Vec2(38,113), [2] = 1},
        { [1] = Vec2(38,113), [2] = 1},
        { [1] = Vec2(38,113), [2] = 1},
        { [1] = Vec2(38,113), [2] = 1},
        { [1] = Vec2(38,112), [2] = 1},
        { [1] = Vec2(38,112), [2] = 1},
        { [1] = Vec2(38,111), [2] = 1},
        { [1] = Vec2(38,111), [2] = 1},
        { [1] = Vec2(39,111), [2] = 1},
        { [1] = Vec2(39,111), [2] = 1},
        { [1] = Vec2(39,111), [2] = 1},
        { [1] = Vec2(39,111), [2] = 1},
        { [1] = Vec2(38,111), [2] = 1},
        { [1] = Vec2(38,111), [2] = 1},
        { [1] = Vec2(38,110), [2] = 1},
        { [1] = Vec2(38,110), [2] = 1},
        { [1] = Vec2(38,110), [2] = 1},
        { [1] = Vec2(38,110), [2] = 1},
        { [1] = Vec2(37,110), [2] = 1},
        { [1] = Vec2(37,110), [2] = 1},
        { [1] = Vec2(36,110), [2] = 1},
        { [1] = Vec2(36,110), [2] = 1},
        { [1] = Vec2(36,110), [2] = 1},
        { [1] = Vec2(36,110), [2] = 1},
        { [1] = Vec2(35,110), [2] = 1},
        { [1] = Vec2(35,110), [2] = 1},
        { [1] = Vec2(34,110), [2] = 1},
        { [1] = Vec2(34,110), [2] = 1},
        { [1] = Vec2(33,110), [2] = 1},
        { [1] = Vec2(33,110), [2] = 1},
        { [1] = Vec2(32,110), [2] = 1},
        { [1] = Vec2(32,110), [2] = 1},
        { [1] = Vec2(32,109), [2] = 1},
        { [1] = Vec2(32,109), [2] = 1},
        { [1] = Vec2(33,108), [2] = 1},
        { [1] = Vec2(33,108), [2] = 1},
        { [1] = Vec2(34,107), [2] = 1},
        { [1] = Vec2(34,107), [2] = 1},
        { [1] = Vec2(35,105), [2] = 1},
        { [1] = Vec2(35,105), [2] = 1},
        { [1] = Vec2(36,103), [2] = 1},
        { [1] = Vec2(36,103), [2] = 1},
        { [1] = Vec2(37,102), [2] = 1},
        { [1] = Vec2(37,102), [2] = 1},
        { [1] = Vec2(38,100), [2] = 1},
        { [1] = Vec2(38,100), [2] = 1},
        { [1] = Vec2(38,100), [2] = 1},
        { [1] = Vec2(38,100), [2] = 1},
        { [1] = Vec2(38,100), [2] = 1},
        { [1] = Vec2(38,100), [2] = 1},
        { [1] = Vec2(37,100), [2] = 1},
        { [1] = Vec2(37,100), [2] = 1},
        { [1] = Vec2(37,101), [2] = 1},
        { [1] = Vec2(37,101), [2] = 1},
        { [1] = Vec2(35,103), [2] = 1},
        { [1] = Vec2(35,103), [2] = 1},
        { [1] = Vec2(35,103), [2] = 1},
        { [1] = Vec2(35,103), [2] = 1},
        { [1] = Vec2(36,101), [2] = 1},
        { [1] = Vec2(36,101), [2] = 1},
        { [1] = Vec2(37,100), [2] = 1},
        { [1] = Vec2(37,100), [2] = 1},
        { [1] = Vec2(38,98), [2] = 1},
        { [1] = Vec2(38,98), [2] = 1},
        { [1] = Vec2(39,95), [2] = 1},
        { [1] = Vec2(39,95), [2] = 1},
        { [1] = Vec2(40,93), [2] = 1},
        { [1] = Vec2(40,93), [2] = 1},
        { [1] = Vec2(41,91), [2] = 1},
        { [1] = Vec2(41,91), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(61,92), [2] = 0},
        { [1] = Vec2(61,92), [2] = 1},
        { [1] = Vec2(61,92), [2] = 1},
        { [1] = Vec2(61,92), [2] = 1},
        { [1] = Vec2(61,92), [2] = 1},
        { [1] = Vec2(62,92), [2] = 1},
        { [1] = Vec2(62,92), [2] = 1},
        { [1] = Vec2(62,92), [2] = 1},
        { [1] = Vec2(62,92), [2] = 1},
        { [1] = Vec2(62,93), [2] = 1},
        { [1] = Vec2(62,93), [2] = 1},
        { [1] = Vec2(62,94), [2] = 1},
        { [1] = Vec2(62,94), [2] = 1},
        { [1] = Vec2(62,94), [2] = 1},
        { [1] = Vec2(62,94), [2] = 1},
        { [1] = Vec2(62,95), [2] = 1},
        { [1] = Vec2(62,95), [2] = 1},
        { [1] = Vec2(62,96), [2] = 1},
        { [1] = Vec2(62,96), [2] = 1},
        { [1] = Vec2(62,96), [2] = 1},
        { [1] = Vec2(62,96), [2] = 1},
        { [1] = Vec2(62,97), [2] = 1},
        { [1] = Vec2(62,97), [2] = 1},
        { [1] = Vec2(62,98), [2] = 1},
        { [1] = Vec2(62,98), [2] = 1},
        { [1] = Vec2(62,99), [2] = 1},
        { [1] = Vec2(62,99), [2] = 1},
        { [1] = Vec2(62,99), [2] = 1},
        { [1] = Vec2(62,99), [2] = 1},
        { [1] = Vec2(62,100), [2] = 1},
        { [1] = Vec2(62,100), [2] = 1},
        { [1] = Vec2(62,101), [2] = 1},
        { [1] = Vec2(62,101), [2] = 1},
        { [1] = Vec2(62,102), [2] = 1},
        { [1] = Vec2(62,102), [2] = 1},
        { [1] = Vec2(62,103), [2] = 1},
        { [1] = Vec2(62,103), [2] = 1},
        { [1] = Vec2(62,104), [2] = 1},
        { [1] = Vec2(62,104), [2] = 1},
        { [1] = Vec2(62,105), [2] = 1},
        { [1] = Vec2(62,105), [2] = 1},
        { [1] = Vec2(62,105), [2] = 1},
        { [1] = Vec2(62,105), [2] = 1},
        { [1] = Vec2(62,106), [2] = 1},
        { [1] = Vec2(62,106), [2] = 1},
        { [1] = Vec2(61,107), [2] = 1},
        { [1] = Vec2(61,107), [2] = 1},
        { [1] = Vec2(61,108), [2] = 1},
        { [1] = Vec2(61,108), [2] = 1},
        { [1] = Vec2(61,109), [2] = 1},
        { [1] = Vec2(61,109), [2] = 1},
        { [1] = Vec2(61,109), [2] = 1},
        { [1] = Vec2(61,109), [2] = 1},
        { [1] = Vec2(61,112), [2] = 1},
        { [1] = Vec2(61,112), [2] = 1},
        { [1] = Vec2(61,112), [2] = 1},
        { [1] = Vec2(61,112), [2] = 1},
        { [1] = Vec2(61,114), [2] = 1},
        { [1] = Vec2(61,114), [2] = 1},
        { [1] = Vec2(61,114), [2] = 1},
        { [1] = Vec2(61,114), [2] = 1},
        { [1] = Vec2(62,115), [2] = 1},
        { [1] = Vec2(62,115), [2] = 1},
        { [1] = Vec2(62,115), [2] = 1},
        { [1] = Vec2(62,115), [2] = 1},
        { [1] = Vec2(62,116), [2] = 1},
        { [1] = Vec2(62,116), [2] = 1},
        { [1] = Vec2(61,118), [2] = 1},
        { [1] = Vec2(61,118), [2] = 1},
        { [1] = Vec2(61,119), [2] = 1},
        { [1] = Vec2(61,119), [2] = 1},
        { [1] = Vec2(61,120), [2] = 1},
        { [1] = Vec2(61,120), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,121), [2] = 1},
        { [1] = Vec2(61,122), [2] = 1},
        { [1] = Vec2(61,122), [2] = 1},
        { [1] = Vec2(61,122), [2] = 1},
        { [1] = Vec2(61,122), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(61,123), [2] = 1},
        { [1] = Vec2(62,124), [2] = 1},
        { [1] = Vec2(62,124), [2] = 1},
        { [1] = Vec2(62,124), [2] = 1},
        { [1] = Vec2(62,124), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,125), [2] = 1},
        { [1] = Vec2(62,126), [2] = 1},
        { [1] = Vec2(62,126), [2] = 1},
        { [1] = Vec2(62,126), [2] = 1},
        { [1] = Vec2(62,126), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(67,107), [2] = 0},
        { [1] = Vec2(67,107), [2] = 1},
        { [1] = Vec2(67,107), [2] = 1},
        { [1] = Vec2(68,107), [2] = 1},
        { [1] = Vec2(68,107), [2] = 1},
        { [1] = Vec2(70,107), [2] = 1},
        { [1] = Vec2(70,107), [2] = 1},
        { [1] = Vec2(70,107), [2] = 1},
        { [1] = Vec2(70,107), [2] = 1},
        { [1] = Vec2(71,107), [2] = 1},
        { [1] = Vec2(71,107), [2] = 1},
        { [1] = Vec2(72,107), [2] = 1},
        { [1] = Vec2(72,107), [2] = 1},
        { [1] = Vec2(73,107), [2] = 1},
        { [1] = Vec2(73,107), [2] = 1},
        { [1] = Vec2(73,107), [2] = 1},
        { [1] = Vec2(73,107), [2] = 1},
        { [1] = Vec2(74,107), [2] = 1},
        { [1] = Vec2(74,107), [2] = 1},
        { [1] = Vec2(75,107), [2] = 1},
        { [1] = Vec2(75,107), [2] = 1},
        { [1] = Vec2(75,107), [2] = 1},
        { [1] = Vec2(75,107), [2] = 1},
        { [1] = Vec2(76,107), [2] = 1},
        { [1] = Vec2(76,107), [2] = 1},
        { [1] = Vec2(76,107), [2] = 1},
        { [1] = Vec2(76,107), [2] = 1},
        { [1] = Vec2(77,107), [2] = 1},
        { [1] = Vec2(77,107), [2] = 1},
        { [1] = Vec2(77,107), [2] = 1},
        { [1] = Vec2(77,107), [2] = 1},
        { [1] = Vec2(78,107), [2] = 1},
        { [1] = Vec2(78,107), [2] = 1},
        { [1] = Vec2(79,107), [2] = 1},
        { [1] = Vec2(79,107), [2] = 1},
        { [1] = Vec2(80,107), [2] = 1},
        { [1] = Vec2(80,107), [2] = 1},
        { [1] = Vec2(81,107), [2] = 1},
        { [1] = Vec2(81,107), [2] = 1},
        { [1] = Vec2(81,107), [2] = 1},
        { [1] = Vec2(81,107), [2] = 1},
        { [1] = Vec2(82,107), [2] = 1},
        { [1] = Vec2(82,107), [2] = 1},
        { [1] = Vec2(82,107), [2] = 1},
        { [1] = Vec2(82,107), [2] = 1},
        { [1] = Vec2(83,107), [2] = 1},
        { [1] = Vec2(83,107), [2] = 1},
        { [1] = Vec2(83,107), [2] = 1},
        { [1] = Vec2(83,107), [2] = 1},
        { [1] = Vec2(83,107), [2] = 1},
        { [1] = Vec2(83,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(85,107), [2] = 1},
        { [1] = Vec2(85,107), [2] = 1},
        { [1] = Vec2(86,107), [2] = 1},
        { [1] = Vec2(86,107), [2] = 1},
        { [1] = Vec2(86,107), [2] = 1},
        { [1] = Vec2(86,107), [2] = 1},
        { [1] = Vec2(87,107), [2] = 1},
        { [1] = Vec2(87,107), [2] = 1},
        { [1] = Vec2(88,107), [2] = 1},
        { [1] = Vec2(88,107), [2] = 1},
        { [1] = Vec2(88,107), [2] = 1},
        { [1] = Vec2(88,107), [2] = 1},
        { [1] = Vec2(89,107), [2] = 1},
        { [1] = Vec2(89,107), [2] = 1},
        { [1] = Vec2(90,107), [2] = 1},
        { [1] = Vec2(90,107), [2] = 1},
        { [1] = Vec2(90,107), [2] = 1},
        { [1] = Vec2(90,107), [2] = 1},
        { [1] = Vec2(91,107), [2] = 1},
        { [1] = Vec2(91,107), [2] = 1},
        { [1] = Vec2(91,107), [2] = 1},
        { [1] = Vec2(91,107), [2] = 1},
        { [1] = Vec2(92,107), [2] = 1},
        { [1] = Vec2(92,107), [2] = 1},
        { [1] = Vec2(92,107), [2] = 1},
        { [1] = Vec2(92,107), [2] = 1},
        { [1] = Vec2(93,107), [2] = 1},
        { [1] = Vec2(93,107), [2] = 1},
        { [1] = Vec2(93,107), [2] = 1},
        { [1] = Vec2(93,107), [2] = 1},
        { [1] = Vec2(94,107), [2] = 1},
        { [1] = Vec2(94,107), [2] = 1},
        { [1] = Vec2(94,107), [2] = 1},
        { [1] = Vec2(94,107), [2] = 1},
        { [1] = Vec2(95,107), [2] = 1},
        { [1] = Vec2(95,107), [2] = 1},
        { [1] = Vec2(96,107), [2] = 1},
        { [1] = Vec2(96,107), [2] = 1},
        { [1] = Vec2(97,107), [2] = 1},
        { [1] = Vec2(97,107), [2] = 1},
        { [1] = Vec2(98,107), [2] = 1},
        { [1] = Vec2(98,107), [2] = 1},
        { [1] = Vec2(99,108), [2] = 1},
        { [1] = Vec2(99,108), [2] = 1},
        { [1] = Vec2(100,108), [2] = 1},
        { [1] = Vec2(100,108), [2] = 1},
        { [1] = Vec2(101,108), [2] = 1},
        { [1] = Vec2(101,108), [2] = 1},
        { [1] = Vec2(102,108), [2] = 1},
        { [1] = Vec2(102,108), [2] = 1},
        { [1] = Vec2(102,108), [2] = 1},
        { [1] = Vec2(102,108), [2] = 1},
        { [1] = Vec2(103,108), [2] = 1},
        { [1] = Vec2(103,108), [2] = 1},
        { [1] = Vec2(103,108), [2] = 1},
        { [1] = Vec2(103,108), [2] = 1},
        { [1] = Vec2(103,108), [2] = 1},
        { [1] = Vec2(103,108), [2] = 1},
        { [1] = Vec2(104,108), [2] = 1},
        { [1] = Vec2(104,108), [2] = 1},
        { [1] = Vec2(104,108), [2] = 1},
        { [1] = Vec2(104,108), [2] = 1},
        { [1] = Vec2(105,108), [2] = 1},
        { [1] = Vec2(105,108), [2] = 1},
        { [1] = Vec2(106,108), [2] = 1},
        { [1] = Vec2(106,108), [2] = 1},
        { [1] = Vec2(106,108), [2] = 1},
        { [1] = Vec2(106,108), [2] = 1},
        { [1] = Vec2(107,108), [2] = 1},
        { [1] = Vec2(107,108), [2] = 1},
        { [1] = Vec2(107,108), [2] = 1},
        { [1] = Vec2(107,108), [2] = 1},
        { [1] = Vec2(108,108), [2] = 1},
        { [1] = Vec2(108,108), [2] = 1},
        { [1] = Vec2(108,108), [2] = 1},
        { [1] = Vec2(108,108), [2] = 1},
        { [1] = Vec2(109,108), [2] = 1},
        { [1] = Vec2(109,108), [2] = 1},
        { [1] = Vec2(110,108), [2] = 1},
        { [1] = Vec2(110,108), [2] = 1},
        { [1] = Vec2(111,108), [2] = 1},
        { [1] = Vec2(111,108), [2] = 1},
        { [1] = Vec2(112,108), [2] = 1},
        { [1] = Vec2(112,108), [2] = 1},
        { [1] = Vec2(112,108), [2] = 1},
        { [1] = Vec2(112,108), [2] = 1},
        { [1] = Vec2(113,108), [2] = 1},
        { [1] = Vec2(113,108), [2] = 1},
        { [1] = Vec2(114,108), [2] = 1},
        { [1] = Vec2(114,108), [2] = 1},
        { [1] = Vec2(114,108), [2] = 1},
        { [1] = Vec2(114,108), [2] = 1},
        { [1] = Vec2(115,108), [2] = 1},
        { [1] = Vec2(115,108), [2] = 1},
        { [1] = Vec2(116,108), [2] = 1},
        { [1] = Vec2(116,108), [2] = 1},
        { [1] = Vec2(116,108), [2] = 1},
        { [1] = Vec2(116,108), [2] = 1},
        { [1] = Vec2(117,108), [2] = 1},
        { [1] = Vec2(117,108), [2] = 1},
        { [1] = Vec2(118,108), [2] = 1},
        { [1] = Vec2(118,108), [2] = 1},
        { [1] = Vec2(119,108), [2] = 1},
        { [1] = Vec2(119,108), [2] = 1},
        { [1] = Vec2(120,108), [2] = 1},
        { [1] = Vec2(120,108), [2] = 1},
        { [1] = Vec2(121,108), [2] = 1},
        { [1] = Vec2(121,108), [2] = 1},
        { [1] = Vec2(122,108), [2] = 1},
        { [1] = Vec2(122,108), [2] = 1},
        { [1] = Vec2(123,108), [2] = 1},
        { [1] = Vec2(123,108), [2] = 1},
        { [1] = Vec2(125,108), [2] = 1},
        { [1] = Vec2(125,108), [2] = 1},
        { [1] = Vec2(126,107), [2] = 1},
        { [1] = Vec2(126,107), [2] = 1},
        { [1] = Vec2(126,108), [2] = 1},
        { [1] = Vec2(126,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(127,108), [2] = 1},
        { [1] = Vec2(128,108), [2] = 1},
        { [1] = Vec2(128,108), [2] = 1},
        { [1] = Vec2(128,108), [2] = 1},
        { [1] = Vec2(128,108), [2] = 1},
        { [1] = Vec2(129,108), [2] = 1},
        { [1] = Vec2(129,108), [2] = 1},
        { [1] = Vec2(130,108), [2] = 1},
        { [1] = Vec2(130,108), [2] = 1},
        { [1] = Vec2(131,108), [2] = 1},
        { [1] = Vec2(131,108), [2] = 1},
        { [1] = Vec2(132,108), [2] = 1},
        { [1] = Vec2(132,108), [2] = 1},
        { [1] = Vec2(133,108), [2] = 1},
        { [1] = Vec2(133,108), [2] = 1},
        { [1] = Vec2(133,108), [2] = 1},
        { [1] = Vec2(133,108), [2] = 1},
        { [1] = Vec2(133,108), [2] = 1},
        { [1] = Vec2(133,108), [2] = 1},
        { [1] = Vec2(134,108), [2] = 1},
        { [1] = Vec2(134,108), [2] = 1},
        { [1] = Vec2(134,108), [2] = 1},
        { [1] = Vec2(134,108), [2] = 1},
        { [1] = Vec2(135,108), [2] = 1},
        { [1] = Vec2(135,108), [2] = 1},
        { [1] = Vec2(136,108), [2] = 1},
        { [1] = Vec2(136,108), [2] = 1},
        { [1] = Vec2(136,108), [2] = 1},
        { [1] = Vec2(136,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(137,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(138,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(139,108), [2] = 1},
        { [1] = Vec2(140,108), [2] = 1},
        { [1] = Vec2(140,108), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(81,122), [2] = 0},
        { [1] = Vec2(81,122), [2] = 1},
        { [1] = Vec2(81,122), [2] = 1},
        { [1] = Vec2(81,122), [2] = 1},
        { [1] = Vec2(81,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(83,122), [2] = 1},
        { [1] = Vec2(83,122), [2] = 1},
        { [1] = Vec2(84,122), [2] = 1},
        { [1] = Vec2(84,122), [2] = 1},
        { [1] = Vec2(84,122), [2] = 1},
        { [1] = Vec2(84,122), [2] = 1},
        { [1] = Vec2(85,122), [2] = 1},
        { [1] = Vec2(85,122), [2] = 1},
        { [1] = Vec2(86,122), [2] = 1},
        { [1] = Vec2(86,122), [2] = 1},
        { [1] = Vec2(87,122), [2] = 1},
        { [1] = Vec2(87,122), [2] = 1},
        { [1] = Vec2(87,122), [2] = 1},
        { [1] = Vec2(87,122), [2] = 1},
        { [1] = Vec2(88,122), [2] = 1},
        { [1] = Vec2(88,122), [2] = 1},
        { [1] = Vec2(89,122), [2] = 1},
        { [1] = Vec2(89,122), [2] = 1},
        { [1] = Vec2(90,122), [2] = 1},
        { [1] = Vec2(90,122), [2] = 1},
        { [1] = Vec2(91,122), [2] = 1},
        { [1] = Vec2(91,122), [2] = 1},
        { [1] = Vec2(92,122), [2] = 1},
        { [1] = Vec2(92,122), [2] = 1},
        { [1] = Vec2(93,122), [2] = 1},
        { [1] = Vec2(93,122), [2] = 1},
        { [1] = Vec2(94,122), [2] = 1},
        { [1] = Vec2(94,122), [2] = 1},
        { [1] = Vec2(96,123), [2] = 1},
        { [1] = Vec2(96,123), [2] = 1},
        { [1] = Vec2(98,123), [2] = 1},
        { [1] = Vec2(98,123), [2] = 1},
        { [1] = Vec2(99,123), [2] = 1},
        { [1] = Vec2(99,123), [2] = 1},
        { [1] = Vec2(100,123), [2] = 1},
        { [1] = Vec2(100,123), [2] = 1},
        { [1] = Vec2(100,123), [2] = 1},
        { [1] = Vec2(100,123), [2] = 1},
        { [1] = Vec2(102,123), [2] = 1},
        { [1] = Vec2(102,123), [2] = 1},
        { [1] = Vec2(102,123), [2] = 1},
        { [1] = Vec2(102,123), [2] = 1},
        { [1] = Vec2(103,123), [2] = 1},
        { [1] = Vec2(103,123), [2] = 1},
        { [1] = Vec2(104,123), [2] = 1},
        { [1] = Vec2(104,123), [2] = 1},
        { [1] = Vec2(105,123), [2] = 1},
        { [1] = Vec2(105,123), [2] = 1},
        { [1] = Vec2(106,123), [2] = 1},
        { [1] = Vec2(106,123), [2] = 1},
        { [1] = Vec2(107,123), [2] = 1},
        { [1] = Vec2(107,123), [2] = 1},
        { [1] = Vec2(107,123), [2] = 1},
        { [1] = Vec2(107,123), [2] = 1},
        { [1] = Vec2(108,123), [2] = 1},
        { [1] = Vec2(108,123), [2] = 1},
        { [1] = Vec2(109,123), [2] = 1},
        { [1] = Vec2(109,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(113,124), [2] = 1},
        { [1] = Vec2(113,124), [2] = 1},
        { [1] = Vec2(115,124), [2] = 1},
        { [1] = Vec2(115,124), [2] = 1},
        { [1] = Vec2(117,125), [2] = 1},
        { [1] = Vec2(117,125), [2] = 1},
        { [1] = Vec2(118,125), [2] = 1},
        { [1] = Vec2(118,125), [2] = 1},
        { [1] = Vec2(119,125), [2] = 1},
        { [1] = Vec2(119,125), [2] = 1},
        { [1] = Vec2(119,125), [2] = 1},
        { [1] = Vec2(119,125), [2] = 1},
        { [1] = Vec2(120,125), [2] = 1},
        { [1] = Vec2(120,125), [2] = 1},
        { [1] = Vec2(120,125), [2] = 1},
        { [1] = Vec2(120,125), [2] = 1},
        { [1] = Vec2(120,125), [2] = 1},
        { [1] = Vec2(120,125), [2] = 1},
        { [1] = Vec2(121,126), [2] = 1},
        { [1] = Vec2(121,126), [2] = 1},
        { [1] = Vec2(121,126), [2] = 1},
        { [1] = Vec2(121,126), [2] = 1},
        { [1] = Vec2(121,126), [2] = 1},
        { [1] = Vec2(121,126), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(81,93), [2] = 0},
        { [1] = Vec2(81,93), [2] = 1},
        { [1] = Vec2(81,93), [2] = 1},
        { [1] = Vec2(82,94), [2] = 1},
        { [1] = Vec2(82,94), [2] = 1},
        { [1] = Vec2(83,94), [2] = 1},
        { [1] = Vec2(83,94), [2] = 1},
        { [1] = Vec2(84,94), [2] = 1},
        { [1] = Vec2(84,94), [2] = 1},
        { [1] = Vec2(85,94), [2] = 1},
        { [1] = Vec2(85,94), [2] = 1},
        { [1] = Vec2(87,94), [2] = 1},
        { [1] = Vec2(87,94), [2] = 1},
        { [1] = Vec2(88,94), [2] = 1},
        { [1] = Vec2(88,94), [2] = 1},
        { [1] = Vec2(89,94), [2] = 1},
        { [1] = Vec2(89,94), [2] = 1},
        { [1] = Vec2(91,94), [2] = 1},
        { [1] = Vec2(91,94), [2] = 1},
        { [1] = Vec2(92,94), [2] = 1},
        { [1] = Vec2(92,94), [2] = 1},
        { [1] = Vec2(93,94), [2] = 1},
        { [1] = Vec2(93,94), [2] = 1},
        { [1] = Vec2(94,94), [2] = 1},
        { [1] = Vec2(94,94), [2] = 1},
        { [1] = Vec2(95,94), [2] = 1},
        { [1] = Vec2(95,94), [2] = 1},
        { [1] = Vec2(97,94), [2] = 1},
        { [1] = Vec2(97,94), [2] = 1},
        { [1] = Vec2(98,94), [2] = 1},
        { [1] = Vec2(98,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(101,94), [2] = 1},
        { [1] = Vec2(101,94), [2] = 1},
        { [1] = Vec2(102,94), [2] = 1},
        { [1] = Vec2(102,94), [2] = 1},
        { [1] = Vec2(103,94), [2] = 1},
        { [1] = Vec2(103,94), [2] = 1},
        { [1] = Vec2(104,94), [2] = 1},
        { [1] = Vec2(104,94), [2] = 1},
        { [1] = Vec2(105,94), [2] = 1},
        { [1] = Vec2(105,94), [2] = 1},
        { [1] = Vec2(106,94), [2] = 1},
        { [1] = Vec2(106,94), [2] = 1},
        { [1] = Vec2(107,94), [2] = 1},
        { [1] = Vec2(107,94), [2] = 1},
        { [1] = Vec2(107,94), [2] = 1},
        { [1] = Vec2(107,94), [2] = 1},
        { [1] = Vec2(108,94), [2] = 1},
        { [1] = Vec2(108,94), [2] = 1},
        { [1] = Vec2(109,94), [2] = 1},
        { [1] = Vec2(109,94), [2] = 1},
        { [1] = Vec2(109,94), [2] = 1},
        { [1] = Vec2(109,94), [2] = 1},
        { [1] = Vec2(110,94), [2] = 1},
        { [1] = Vec2(110,94), [2] = 1},
        { [1] = Vec2(110,94), [2] = 1},
        { [1] = Vec2(110,94), [2] = 1},
        { [1] = Vec2(111,93), [2] = 1},
        { [1] = Vec2(111,93), [2] = 1},
        { [1] = Vec2(111,93), [2] = 1},
        { [1] = Vec2(111,93), [2] = 1},
        { [1] = Vec2(112,93), [2] = 1},
        { [1] = Vec2(112,93), [2] = 1},
        { [1] = Vec2(112,93), [2] = 1},
        { [1] = Vec2(112,93), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(32,47), [2] = 0},
        { [1] = Vec2(31,48), [2] = 1},
        { [1] = Vec2(31,48), [2] = 1},
        { [1] = Vec2(33,47), [2] = 1},
        { [1] = Vec2(33,47), [2] = 1},
        { [1] = Vec2(35,45), [2] = 1},
        { [1] = Vec2(35,45), [2] = 1},
        { [1] = Vec2(37,43), [2] = 1},
        { [1] = Vec2(37,43), [2] = 1},
        { [1] = Vec2(40,41), [2] = 1},
        { [1] = Vec2(40,41), [2] = 1},
        { [1] = Vec2(42,41), [2] = 1},
        { [1] = Vec2(42,41), [2] = 1},
        { [1] = Vec2(42,43), [2] = 1},
        { [1] = Vec2(42,43), [2] = 1},
        { [1] = Vec2(42,43), [2] = 1},
        { [1] = Vec2(42,43), [2] = 1},
        { [1] = Vec2(41,41), [2] = 1},
        { [1] = Vec2(41,41), [2] = 1},
        { [1] = Vec2(42,38), [2] = 1},
        { [1] = Vec2(42,38), [2] = 1},
        { [1] = Vec2(45,34), [2] = 1},
        { [1] = Vec2(45,34), [2] = 1},
        { [1] = Vec2(47,30), [2] = 1},
        { [1] = Vec2(47,30), [2] = 1},
        { [1] = Vec2(47,30), [2] = 1},
        { [1] = Vec2(47,30), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(57,80), [2] = 0},
        { [1] = Vec2(57,79), [2] = 1},
        { [1] = Vec2(57,79), [2] = 1},
        { [1] = Vec2(57,77), [2] = 1},
        { [1] = Vec2(57,77), [2] = 1},
        { [1] = Vec2(57,73), [2] = 1},
        { [1] = Vec2(57,73), [2] = 1},
        { [1] = Vec2(57,72), [2] = 1},
        { [1] = Vec2(57,72), [2] = 1},
        { [1] = Vec2(57,70), [2] = 1},
        { [1] = Vec2(57,70), [2] = 1},
        { [1] = Vec2(57,68), [2] = 1},
        { [1] = Vec2(57,68), [2] = 1},
        { [1] = Vec2(57,65), [2] = 1},
        { [1] = Vec2(57,65), [2] = 1},
        { [1] = Vec2(57,61), [2] = 1},
        { [1] = Vec2(57,61), [2] = 1},
        { [1] = Vec2(57,56), [2] = 1},
        { [1] = Vec2(57,56), [2] = 1},
        { [1] = Vec2(58,50), [2] = 1},
        { [1] = Vec2(58,50), [2] = 1},
        { [1] = Vec2(58,46), [2] = 1},
        { [1] = Vec2(58,46), [2] = 1},
        { [1] = Vec2(58,40), [2] = 1},
        { [1] = Vec2(58,40), [2] = 1},
        { [1] = Vec2(58,36), [2] = 1},
        { [1] = Vec2(58,36), [2] = 1},
        { [1] = Vec2(58,34), [2] = 1},
        { [1] = Vec2(58,34), [2] = 1},
        { [1] = Vec2(58,32), [2] = 1},
        { [1] = Vec2(58,32), [2] = 1},
        { [1] = Vec2(57,32), [2] = 1},
        { [1] = Vec2(57,32), [2] = 1},
        { [1] = Vec2(58,32), [2] = 1},
        { [1] = Vec2(58,32), [2] = 1},
        { [1] = Vec2(58,31), [2] = 1},
        { [1] = Vec2(58,31), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(31,67), [2] = 0},
        { [1] = Vec2(31,67), [2] = 1},
        { [1] = Vec2(31,67), [2] = 1},
        { [1] = Vec2(32,67), [2] = 1},
        { [1] = Vec2(32,67), [2] = 1},
        { [1] = Vec2(35,68), [2] = 1},
        { [1] = Vec2(35,68), [2] = 1},
        { [1] = Vec2(40,68), [2] = 1},
        { [1] = Vec2(40,68), [2] = 1},
        { [1] = Vec2(43,68), [2] = 1},
        { [1] = Vec2(43,68), [2] = 1},
        { [1] = Vec2(44,68), [2] = 1},
        { [1] = Vec2(44,68), [2] = 1},
        { [1] = Vec2(46,69), [2] = 1},
        { [1] = Vec2(46,69), [2] = 1},
        { [1] = Vec2(47,69), [2] = 1},
        { [1] = Vec2(47,69), [2] = 1},
        { [1] = Vec2(48,69), [2] = 1},
        { [1] = Vec2(48,69), [2] = 1},
        { [1] = Vec2(50,68), [2] = 1},
        { [1] = Vec2(50,68), [2] = 1},
        { [1] = Vec2(53,68), [2] = 1},
        { [1] = Vec2(53,68), [2] = 1},
        { [1] = Vec2(55,68), [2] = 1},
        { [1] = Vec2(55,68), [2] = 1},
        { [1] = Vec2(57,67), [2] = 1},
        { [1] = Vec2(57,67), [2] = 1},
        { [1] = Vec2(58,67), [2] = 1},
        { [1] = Vec2(58,67), [2] = 1},
        { [1] = Vec2(60,67), [2] = 1},
        { [1] = Vec2(60,67), [2] = 1},
        { [1] = Vec2(62,67), [2] = 1},
        { [1] = Vec2(62,67), [2] = 1},
        { [1] = Vec2(63,67), [2] = 1},
        { [1] = Vec2(63,67), [2] = 1},
        { [1] = Vec2(65,67), [2] = 1},
        { [1] = Vec2(65,67), [2] = 1},
        { [1] = Vec2(67,67), [2] = 1},
        { [1] = Vec2(67,67), [2] = 1},
        { [1] = Vec2(70,67), [2] = 1},
        { [1] = Vec2(70,67), [2] = 1},
        { [1] = Vec2(72,67), [2] = 1},
        { [1] = Vec2(72,67), [2] = 1},
        { [1] = Vec2(75,67), [2] = 1},
        { [1] = Vec2(75,67), [2] = 1},
        { [1] = Vec2(77,68), [2] = 1},
        { [1] = Vec2(77,68), [2] = 1},
        { [1] = Vec2(78,68), [2] = 1},
        { [1] = Vec2(78,68), [2] = 1},
        { [1] = Vec2(79,68), [2] = 1},
        { [1] = Vec2(79,68), [2] = 1},
        { [1] = Vec2(81,68), [2] = 1},
        { [1] = Vec2(81,68), [2] = 1},
        { [1] = Vec2(82,69), [2] = 1},
        { [1] = Vec2(82,69), [2] = 1},
        { [1] = Vec2(85,69), [2] = 1},
        { [1] = Vec2(85,69), [2] = 1},
        { [1] = Vec2(86,69), [2] = 1},
        { [1] = Vec2(86,69), [2] = 1},
        { [1] = Vec2(87,69), [2] = 1},
        { [1] = Vec2(87,69), [2] = 1},
        { [1] = Vec2(88,69), [2] = 1},
        { [1] = Vec2(88,69), [2] = 1},
        { [1] = Vec2(90,70), [2] = 1},
        { [1] = Vec2(90,70), [2] = 1},
        { [1] = Vec2(91,70), [2] = 1},
        { [1] = Vec2(91,70), [2] = 1},
        { [1] = Vec2(91,70), [2] = 1},
        { [1] = Vec2(91,70), [2] = 1},
        { [1] = Vec2(92,70), [2] = 1},
        { [1] = Vec2(92,70), [2] = 1},
        { [1] = Vec2(93,71), [2] = 1},
        { [1] = Vec2(93,71), [2] = 1},
        { [1] = Vec2(95,71), [2] = 1},
        { [1] = Vec2(95,71), [2] = 1},
        { [1] = Vec2(96,72), [2] = 1},
        { [1] = Vec2(96,72), [2] = 1},
        { [1] = Vec2(98,72), [2] = 1},
        { [1] = Vec2(98,72), [2] = 1},
        { [1] = Vec2(99,72), [2] = 1},
        { [1] = Vec2(99,72), [2] = 1},
        { [1] = Vec2(100,73), [2] = 1},
        { [1] = Vec2(100,73), [2] = 1},
        { [1] = Vec2(101,73), [2] = 1},
        { [1] = Vec2(101,73), [2] = 1},
        { [1] = Vec2(102,74), [2] = 1},
        { [1] = Vec2(102,74), [2] = 1},
        { [1] = Vec2(104,74), [2] = 1},
        { [1] = Vec2(104,74), [2] = 1},
        { [1] = Vec2(106,75), [2] = 1},
        { [1] = Vec2(106,75), [2] = 1},
        { [1] = Vec2(107,75), [2] = 1},
        { [1] = Vec2(107,75), [2] = 1},
        { [1] = Vec2(108,76), [2] = 1},
        { [1] = Vec2(108,76), [2] = 1},
        { [1] = Vec2(109,76), [2] = 1},
        { [1] = Vec2(109,76), [2] = 1},
        { [1] = Vec2(110,76), [2] = 1},
        { [1] = Vec2(110,76), [2] = 1},
        { [1] = Vec2(112,77), [2] = 1},
        { [1] = Vec2(112,77), [2] = 1},
        { [1] = Vec2(113,77), [2] = 1},
        { [1] = Vec2(113,77), [2] = 1},
        { [1] = Vec2(114,78), [2] = 1},
        { [1] = Vec2(114,78), [2] = 1},
        { [1] = Vec2(116,79), [2] = 1},
        { [1] = Vec2(116,79), [2] = 1},
        { [1] = Vec2(116,79), [2] = 1},
        { [1] = Vec2(116,79), [2] = 1},
        { [1] = Vec2(117,79), [2] = 1},
        { [1] = Vec2(117,79), [2] = 1},
        { [1] = Vec2(119,80), [2] = 1},
        { [1] = Vec2(119,80), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(124,82), [2] = 1},
        { [1] = Vec2(124,82), [2] = 1},
        { [1] = Vec2(125,83), [2] = 1},
        { [1] = Vec2(125,83), [2] = 1},
        { [1] = Vec2(126,83), [2] = 1},
        { [1] = Vec2(126,83), [2] = 1},
        { [1] = Vec2(127,84), [2] = 1},
        { [1] = Vec2(127,84), [2] = 1},
        { [1] = Vec2(127,84), [2] = 1},
        { [1] = Vec2(127,84), [2] = 1},
        { [1] = Vec2(128,84), [2] = 1},
        { [1] = Vec2(128,84), [2] = 1},
        { [1] = Vec2(129,85), [2] = 1},
        { [1] = Vec2(129,85), [2] = 1},
        { [1] = Vec2(130,85), [2] = 1},
        { [1] = Vec2(130,85), [2] = 1},
        { [1] = Vec2(131,85), [2] = 1},
        { [1] = Vec2(131,85), [2] = 1},
        { [1] = Vec2(132,86), [2] = 1},
        { [1] = Vec2(132,86), [2] = 1},
        { [1] = Vec2(132,86), [2] = 1},
        { [1] = Vec2(132,86), [2] = 1},
        { [1] = Vec2(133,86), [2] = 1},
        { [1] = Vec2(133,86), [2] = 1},
        { [1] = Vec2(133,86), [2] = 1},
        { [1] = Vec2(133,86), [2] = 1},
        { [1] = Vec2(134,86), [2] = 1},
        { [1] = Vec2(134,86), [2] = 1},
        { [1] = Vec2(134,87), [2] = 1},
        { [1] = Vec2(134,87), [2] = 1},
        { [1] = Vec2(134,87), [2] = 1},
        { [1] = Vec2(134,87), [2] = 1},
        { [1] = Vec2(135,88), [2] = 1},
        { [1] = Vec2(135,88), [2] = 1},
        { [1] = Vec2(134,88), [2] = 1},
        { [1] = Vec2(134,88), [2] = 1},
        { [1] = Vec2(134,88), [2] = 1},
        { [1] = Vec2(134,88), [2] = 1},
        { [1] = Vec2(134,88), [2] = 1},
        { [1] = Vec2(134,88), [2] = 1},
        { [1] = Vec2(134,89), [2] = 1},
        { [1] = Vec2(134,89), [2] = 1},
        { [1] = Vec2(134,89), [2] = 1},
        { [1] = Vec2(134,89), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(84,62), [2] = 0},
        { [1] = Vec2(84,62), [2] = 1},
        { [1] = Vec2(84,62), [2] = 1},
        { [1] = Vec2(86,63), [2] = 1},
        { [1] = Vec2(86,63), [2] = 1},
        { [1] = Vec2(89,62), [2] = 1},
        { [1] = Vec2(89,62), [2] = 1},
        { [1] = Vec2(92,62), [2] = 1},
        { [1] = Vec2(92,62), [2] = 1},
        { [1] = Vec2(93,61), [2] = 1},
        { [1] = Vec2(93,61), [2] = 1},
        { [1] = Vec2(94,61), [2] = 1},
        { [1] = Vec2(94,61), [2] = 1},
        { [1] = Vec2(95,61), [2] = 1},
        { [1] = Vec2(95,61), [2] = 1},
        { [1] = Vec2(96,60), [2] = 1},
        { [1] = Vec2(96,60), [2] = 1},
        { [1] = Vec2(98,60), [2] = 1},
        { [1] = Vec2(98,60), [2] = 1},
        { [1] = Vec2(99,59), [2] = 1},
        { [1] = Vec2(99,59), [2] = 1},
        { [1] = Vec2(100,59), [2] = 1},
        { [1] = Vec2(100,59), [2] = 1},
        { [1] = Vec2(101,59), [2] = 1},
        { [1] = Vec2(101,59), [2] = 1},
        { [1] = Vec2(102,58), [2] = 1},
        { [1] = Vec2(102,58), [2] = 1},
        { [1] = Vec2(103,57), [2] = 1},
        { [1] = Vec2(103,57), [2] = 1},
        { [1] = Vec2(103,56), [2] = 1},
        { [1] = Vec2(103,56), [2] = 1},
        { [1] = Vec2(104,56), [2] = 1},
        { [1] = Vec2(104,56), [2] = 1},
        { [1] = Vec2(104,55), [2] = 1},
        { [1] = Vec2(104,55), [2] = 1},
        { [1] = Vec2(105,55), [2] = 1},
        { [1] = Vec2(105,55), [2] = 1},
        { [1] = Vec2(106,53), [2] = 1},
        { [1] = Vec2(106,53), [2] = 1},
        { [1] = Vec2(107,53), [2] = 1},
        { [1] = Vec2(107,53), [2] = 1},
        { [1] = Vec2(108,52), [2] = 1},
        { [1] = Vec2(108,52), [2] = 1},
        { [1] = Vec2(110,51), [2] = 1},
        { [1] = Vec2(110,51), [2] = 1},
        { [1] = Vec2(112,50), [2] = 1},
        { [1] = Vec2(112,50), [2] = 1},
        { [1] = Vec2(113,49), [2] = 1},
        { [1] = Vec2(113,49), [2] = 1},
        { [1] = Vec2(114,49), [2] = 1},
        { [1] = Vec2(114,49), [2] = 1},
        { [1] = Vec2(114,49), [2] = 1},
        { [1] = Vec2(114,49), [2] = 1},
        { [1] = Vec2(114,48), [2] = 1},
        { [1] = Vec2(114,48), [2] = 1},
        { [1] = Vec2(115,47), [2] = 1},
        { [1] = Vec2(115,47), [2] = 1},
        { [1] = Vec2(117,46), [2] = 1},
        { [1] = Vec2(117,46), [2] = 1},
        { [1] = Vec2(118,45), [2] = 1},
        { [1] = Vec2(118,45), [2] = 1},
        { [1] = Vec2(119,44), [2] = 1},
        { [1] = Vec2(119,44), [2] = 1},
        { [1] = Vec2(119,44), [2] = 1},
        { [1] = Vec2(119,44), [2] = 1},
        { [1] = Vec2(121,43), [2] = 1},
        { [1] = Vec2(121,43), [2] = 1},
        { [1] = Vec2(123,41), [2] = 1},
        { [1] = Vec2(123,41), [2] = 1},
        { [1] = Vec2(124,40), [2] = 1},
        { [1] = Vec2(124,40), [2] = 1},
        { [1] = Vec2(125,40), [2] = 1},
        { [1] = Vec2(125,40), [2] = 1},
        { [1] = Vec2(126,39), [2] = 1},
        { [1] = Vec2(126,39), [2] = 1},
        { [1] = Vec2(128,37), [2] = 1},
        { [1] = Vec2(128,37), [2] = 1},
        { [1] = Vec2(128,37), [2] = 1},
        { [1] = Vec2(128,37), [2] = 1},
        { [1] = Vec2(129,36), [2] = 1},
        { [1] = Vec2(129,36), [2] = 1},
        { [1] = Vec2(129,35), [2] = 1},
        { [1] = Vec2(129,35), [2] = 1},
        { [1] = Vec2(130,34), [2] = 1},
        { [1] = Vec2(130,34), [2] = 1},
        { [1] = Vec2(131,33), [2] = 1},
        { [1] = Vec2(131,33), [2] = 1},
        { [1] = Vec2(132,32), [2] = 1},
        { [1] = Vec2(132,32), [2] = 1},
        { [1] = Vec2(132,32), [2] = 1},
        { [1] = Vec2(132,32), [2] = 1},
        { [1] = Vec2(132,31), [2] = 1},
        { [1] = Vec2(132,31), [2] = 1},
        { [1] = Vec2(133,31), [2] = 1},
        { [1] = Vec2(133,31), [2] = 1},
        { [1] = Vec2(133,30), [2] = 1},
        { [1] = Vec2(133,30), [2] = 1},
        { [1] = Vec2(134,29), [2] = 1},
        { [1] = Vec2(134,29), [2] = 1},
        { [1] = Vec2(134,28), [2] = 1},
        { [1] = Vec2(134,28), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(74,38), [2] = 0},
        { [1] = Vec2(74,38), [2] = 1},
        { [1] = Vec2(74,38), [2] = 1},
        { [1] = Vec2(78,38), [2] = 1},
        { [1] = Vec2(78,38), [2] = 1},
        { [1] = Vec2(83,38), [2] = 1},
        { [1] = Vec2(83,38), [2] = 1},
        { [1] = Vec2(86,39), [2] = 1},
        { [1] = Vec2(86,39), [2] = 1},
        { [1] = Vec2(89,40), [2] = 1},
        { [1] = Vec2(89,40), [2] = 1},
        { [1] = Vec2(92,41), [2] = 1},
        { [1] = Vec2(92,41), [2] = 1},
        { [1] = Vec2(94,41), [2] = 1},
        { [1] = Vec2(94,41), [2] = 1},
        { [1] = Vec2(97,42), [2] = 1},
        { [1] = Vec2(97,42), [2] = 1},
        { [1] = Vec2(99,43), [2] = 1},
        { [1] = Vec2(99,43), [2] = 1},
        { [1] = Vec2(101,43), [2] = 1},
        { [1] = Vec2(101,43), [2] = 1},
        { [1] = Vec2(103,44), [2] = 1},
        { [1] = Vec2(103,44), [2] = 1},
        { [1] = Vec2(108,46), [2] = 1},
        { [1] = Vec2(108,46), [2] = 1},
        { [1] = Vec2(109,46), [2] = 1},
        { [1] = Vec2(109,46), [2] = 1},
        { [1] = Vec2(110,47), [2] = 1},
        { [1] = Vec2(110,47), [2] = 1},
        { [1] = Vec2(112,48), [2] = 1},
        { [1] = Vec2(112,48), [2] = 1},
        { [1] = Vec2(114,49), [2] = 1},
        { [1] = Vec2(114,49), [2] = 1},
        { [1] = Vec2(115,50), [2] = 1},
        { [1] = Vec2(115,50), [2] = 1},
        { [1] = Vec2(118,51), [2] = 1},
        { [1] = Vec2(118,51), [2] = 1},
        { [1] = Vec2(119,51), [2] = 1},
        { [1] = Vec2(119,51), [2] = 1},
        { [1] = Vec2(121,52), [2] = 1},
        { [1] = Vec2(121,52), [2] = 1},
        { [1] = Vec2(123,53), [2] = 1},
        { [1] = Vec2(123,53), [2] = 1},
        { [1] = Vec2(124,54), [2] = 1},
        { [1] = Vec2(124,54), [2] = 1},
        { [1] = Vec2(126,55), [2] = 1},
        { [1] = Vec2(126,55), [2] = 1},
        { [1] = Vec2(126,56), [2] = 1},
        { [1] = Vec2(126,56), [2] = 1},
        { [1] = Vec2(127,57), [2] = 1},
        { [1] = Vec2(127,57), [2] = 1},
        { [1] = Vec2(130,60), [2] = 1},
        { [1] = Vec2(130,60), [2] = 1},
        { [1] = Vec2(131,62), [2] = 1},
        { [1] = Vec2(131,62), [2] = 1},
        { [1] = Vec2(132,65), [2] = 1},
        { [1] = Vec2(132,65), [2] = 1},
        { [1] = Vec2(132,66), [2] = 1},
        { [1] = Vec2(132,66), [2] = 1},
        { [1] = Vec2(133,67), [2] = 1},
        { [1] = Vec2(133,67), [2] = 1},
        { [1] = Vec2(133,68), [2] = 1},
        { [1] = Vec2(133,68), [2] = 1},
        { [1] = Vec2(134,69), [2] = 1},
        { [1] = Vec2(134,69), [2] = 1},
        { [1] = Vec2(134,69), [2] = 1},
        { [1] = Vec2(134,69), [2] = 1},
        { [1] = Vec2(135,70), [2] = 1},
        { [1] = Vec2(135,70), [2] = 1},
        { [1] = Vec2(135,70), [2] = 1},
        { [1] = Vec2(135,70), [2] = 1},
        { [1] = nil, [2] = 2}
    },
    [93963747744009] = {
        { [1] = Vec2(28,109), [2] = 0},
        { [1] = Vec2(28,109), [2] = 1},
        { [1] = Vec2(28,109), [2] = 1},
        { [1] = Vec2(29,109), [2] = 1},
        { [1] = Vec2(29,109), [2] = 1},
        { [1] = Vec2(29,109), [2] = 1},
        { [1] = Vec2(29,109), [2] = 1},
        { [1] = Vec2(29,109), [2] = 1},
        { [1] = Vec2(29,109), [2] = 1},
        { [1] = Vec2(31,109), [2] = 1},
        { [1] = Vec2(31,109), [2] = 1},
        { [1] = Vec2(31,109), [2] = 1},
        { [1] = Vec2(31,109), [2] = 1},
        { [1] = Vec2(32,109), [2] = 1},
        { [1] = Vec2(32,109), [2] = 1},
        { [1] = Vec2(33,110), [2] = 1},
        { [1] = Vec2(33,110), [2] = 1},
        { [1] = Vec2(34,110), [2] = 1},
        { [1] = Vec2(34,110), [2] = 1},
        { [1] = Vec2(34,110), [2] = 1},
        { [1] = Vec2(34,110), [2] = 1},
        { [1] = Vec2(35,111), [2] = 1},
        { [1] = Vec2(35,111), [2] = 1},
        { [1] = Vec2(36,111), [2] = 1},
        { [1] = Vec2(36,111), [2] = 1},
        { [1] = Vec2(37,112), [2] = 1},
        { [1] = Vec2(37,112), [2] = 1},
        { [1] = Vec2(37,112), [2] = 1},
        { [1] = Vec2(37,112), [2] = 1},
        { [1] = Vec2(39,112), [2] = 1},
        { [1] = Vec2(39,112), [2] = 1},
        { [1] = Vec2(39,112), [2] = 1},
        { [1] = Vec2(39,112), [2] = 1},
        { [1] = Vec2(40,113), [2] = 1},
        { [1] = Vec2(40,113), [2] = 1},
        { [1] = Vec2(42,113), [2] = 1},
        { [1] = Vec2(42,113), [2] = 1},
        { [1] = Vec2(42,114), [2] = 1},
        { [1] = Vec2(42,114), [2] = 1},
        { [1] = Vec2(43,115), [2] = 1},
        { [1] = Vec2(43,115), [2] = 1},
        { [1] = Vec2(43,115), [2] = 1},
        { [1] = Vec2(43,115), [2] = 1},
        { [1] = Vec2(44,116), [2] = 1},
        { [1] = Vec2(44,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(46,117), [2] = 1},
        { [1] = Vec2(46,117), [2] = 1},
        { [1] = Vec2(47,118), [2] = 1},
        { [1] = Vec2(47,118), [2] = 1},
        { [1] = Vec2(47,118), [2] = 1},
        { [1] = Vec2(47,118), [2] = 1},
        { [1] = Vec2(48,119), [2] = 1},
        { [1] = Vec2(48,119), [2] = 1},
        { [1] = Vec2(48,119), [2] = 1},
        { [1] = Vec2(48,119), [2] = 1},
        { [1] = Vec2(49,120), [2] = 1},
        { [1] = Vec2(49,120), [2] = 1},
        { [1] = Vec2(49,121), [2] = 1},
        { [1] = Vec2(49,121), [2] = 1},
        { [1] = Vec2(49,121), [2] = 1},
        { [1] = Vec2(49,121), [2] = 1},
        { [1] = Vec2(50,121), [2] = 1},
        { [1] = Vec2(50,121), [2] = 1},
        { [1] = Vec2(50,121), [2] = 1},
        { [1] = Vec2(50,121), [2] = 1},
        { [1] = Vec2(50,122), [2] = 1},
        { [1] = Vec2(50,122), [2] = 1},
        { [1] = Vec2(51,122), [2] = 1},
        { [1] = Vec2(51,122), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(51,123), [2] = 1},
        { [1] = Vec2(52,123), [2] = 1},
        { [1] = Vec2(52,123), [2] = 1},
        { [1] = Vec2(52,123), [2] = 1},
        { [1] = Vec2(52,123), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,124), [2] = 1},
        { [1] = Vec2(52,125), [2] = 1},
        { [1] = Vec2(52,125), [2] = 1},
        { [1] = Vec2(53,125), [2] = 1},
        { [1] = Vec2(53,125), [2] = 1},
        { [1] = Vec2(53,125), [2] = 1},
        { [1] = Vec2(53,125), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,126), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(53,127), [2] = 1},
        { [1] = Vec2(54,127), [2] = 1},
        { [1] = Vec2(54,127), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,128), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(54,129), [2] = 1},
        { [1] = Vec2(55,129), [2] = 1},
        { [1] = Vec2(55,129), [2] = 1},
        { [1] = Vec2(55,129), [2] = 1},
        { [1] = Vec2(55,129), [2] = 1},
        { [1] = Vec2(55,129), [2] = 1},
        { [1] = Vec2(55,129), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(33,107), [2] = 0},
        { [1] = Vec2(34,106), [2] = 1},
        { [1] = Vec2(34,106), [2] = 1},
        { [1] = Vec2(35,105), [2] = 1},
        { [1] = Vec2(35,105), [2] = 1},
        { [1] = Vec2(36,104), [2] = 1},
        { [1] = Vec2(36,104), [2] = 1},
        { [1] = Vec2(37,103), [2] = 1},
        { [1] = Vec2(37,103), [2] = 1},
        { [1] = Vec2(39,102), [2] = 1},
        { [1] = Vec2(39,102), [2] = 1},
        { [1] = Vec2(39,102), [2] = 1},
        { [1] = Vec2(39,102), [2] = 1},
        { [1] = Vec2(40,100), [2] = 1},
        { [1] = Vec2(40,100), [2] = 1},
        { [1] = Vec2(41,99), [2] = 1},
        { [1] = Vec2(41,99), [2] = 1},
        { [1] = Vec2(42,99), [2] = 1},
        { [1] = Vec2(42,99), [2] = 1},
        { [1] = Vec2(42,98), [2] = 1},
        { [1] = Vec2(42,98), [2] = 1},
        { [1] = Vec2(44,97), [2] = 1},
        { [1] = Vec2(44,97), [2] = 1},
        { [1] = Vec2(44,97), [2] = 1},
        { [1] = Vec2(44,97), [2] = 1},
        { [1] = Vec2(45,97), [2] = 1},
        { [1] = Vec2(45,97), [2] = 1},
        { [1] = Vec2(45,96), [2] = 1},
        { [1] = Vec2(45,96), [2] = 1},
        { [1] = Vec2(46,96), [2] = 1},
        { [1] = Vec2(46,96), [2] = 1},
        { [1] = Vec2(46,96), [2] = 1},
        { [1] = Vec2(46,96), [2] = 1},
        { [1] = Vec2(47,96), [2] = 1},
        { [1] = Vec2(47,96), [2] = 1},
        { [1] = Vec2(47,96), [2] = 1},
        { [1] = Vec2(47,96), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(48,95), [2] = 1},
        { [1] = Vec2(49,94), [2] = 1},
        { [1] = Vec2(49,94), [2] = 1},
        { [1] = Vec2(49,94), [2] = 1},
        { [1] = Vec2(49,94), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(64,119), [2] = 0},
        { [1] = Vec2(64,120), [2] = 1},
        { [1] = Vec2(64,120), [2] = 1},
        { [1] = Vec2(64,119), [2] = 1},
        { [1] = Vec2(64,119), [2] = 1},
        { [1] = Vec2(64,119), [2] = 1},
        { [1] = Vec2(64,119), [2] = 1},
        { [1] = Vec2(64,118), [2] = 1},
        { [1] = Vec2(64,118), [2] = 1},
        { [1] = Vec2(64,117), [2] = 1},
        { [1] = Vec2(64,117), [2] = 1},
        { [1] = Vec2(64,115), [2] = 1},
        { [1] = Vec2(64,115), [2] = 1},
        { [1] = Vec2(64,115), [2] = 1},
        { [1] = Vec2(64,115), [2] = 1},
        { [1] = Vec2(64,113), [2] = 1},
        { [1] = Vec2(64,113), [2] = 1},
        { [1] = Vec2(63,112), [2] = 1},
        { [1] = Vec2(63,112), [2] = 1},
        { [1] = Vec2(63,111), [2] = 1},
        { [1] = Vec2(63,111), [2] = 1},
        { [1] = Vec2(64,110), [2] = 1},
        { [1] = Vec2(64,110), [2] = 1},
        { [1] = Vec2(64,109), [2] = 1},
        { [1] = Vec2(64,109), [2] = 1},
        { [1] = Vec2(64,109), [2] = 1},
        { [1] = Vec2(64,109), [2] = 1},
        { [1] = Vec2(63,108), [2] = 1},
        { [1] = Vec2(63,108), [2] = 1},
        { [1] = Vec2(63,107), [2] = 1},
        { [1] = Vec2(63,107), [2] = 1},
        { [1] = Vec2(63,107), [2] = 1},
        { [1] = Vec2(63,107), [2] = 1},
        { [1] = Vec2(63,106), [2] = 1},
        { [1] = Vec2(63,106), [2] = 1},
        { [1] = Vec2(63,106), [2] = 1},
        { [1] = Vec2(63,106), [2] = 1},
        { [1] = Vec2(63,105), [2] = 1},
        { [1] = Vec2(63,105), [2] = 1},
        { [1] = Vec2(63,105), [2] = 1},
        { [1] = Vec2(63,105), [2] = 1},
        { [1] = Vec2(63,105), [2] = 1},
        { [1] = Vec2(63,105), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,103), [2] = 1},
        { [1] = Vec2(63,103), [2] = 1},
        { [1] = Vec2(63,103), [2] = 1},
        { [1] = Vec2(63,103), [2] = 1},
        { [1] = Vec2(63,103), [2] = 1},
        { [1] = Vec2(63,103), [2] = 1},
        { [1] = Vec2(63,102), [2] = 1},
        { [1] = Vec2(63,102), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,101), [2] = 1},
        { [1] = Vec2(63,100), [2] = 1},
        { [1] = Vec2(63,100), [2] = 1},
        { [1] = Vec2(63,100), [2] = 1},
        { [1] = Vec2(63,100), [2] = 1},
        { [1] = Vec2(63,100), [2] = 1},
        { [1] = Vec2(63,100), [2] = 1},
        { [1] = Vec2(63,99), [2] = 1},
        { [1] = Vec2(63,99), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(68,110), [2] = 0},
        { [1] = Vec2(68,110), [2] = 1},
        { [1] = Vec2(68,110), [2] = 1},
        { [1] = Vec2(68,110), [2] = 1},
        { [1] = Vec2(68,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(69,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(70,110), [2] = 1},
        { [1] = Vec2(71,110), [2] = 1},
        { [1] = Vec2(71,110), [2] = 1},
        { [1] = Vec2(71,110), [2] = 1},
        { [1] = Vec2(71,110), [2] = 1},
        { [1] = Vec2(72,110), [2] = 1},
        { [1] = Vec2(72,110), [2] = 1},
        { [1] = Vec2(72,110), [2] = 1},
        { [1] = Vec2(72,110), [2] = 1},
        { [1] = Vec2(72,110), [2] = 1},
        { [1] = Vec2(72,110), [2] = 1},
        { [1] = Vec2(73,110), [2] = 1},
        { [1] = Vec2(73,110), [2] = 1},
        { [1] = Vec2(73,110), [2] = 1},
        { [1] = Vec2(73,110), [2] = 1},
        { [1] = Vec2(73,110), [2] = 1},
        { [1] = Vec2(73,110), [2] = 1},
        { [1] = Vec2(74,110), [2] = 1},
        { [1] = Vec2(74,110), [2] = 1},
        { [1] = Vec2(75,110), [2] = 1},
        { [1] = Vec2(75,110), [2] = 1},
        { [1] = Vec2(75,110), [2] = 1},
        { [1] = Vec2(75,110), [2] = 1},
        { [1] = Vec2(76,110), [2] = 1},
        { [1] = Vec2(76,110), [2] = 1},
        { [1] = Vec2(77,110), [2] = 1},
        { [1] = Vec2(77,110), [2] = 1},
        { [1] = Vec2(78,110), [2] = 1},
        { [1] = Vec2(78,110), [2] = 1},
        { [1] = Vec2(78,110), [2] = 1},
        { [1] = Vec2(78,110), [2] = 1},
        { [1] = Vec2(78,110), [2] = 1},
        { [1] = Vec2(78,110), [2] = 1},
        { [1] = Vec2(79,110), [2] = 1},
        { [1] = Vec2(79,110), [2] = 1},
        { [1] = Vec2(79,110), [2] = 1},
        { [1] = Vec2(79,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(80,110), [2] = 1},
        { [1] = Vec2(81,110), [2] = 1},
        { [1] = Vec2(81,110), [2] = 1},
        { [1] = Vec2(81,110), [2] = 1},
        { [1] = Vec2(81,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(83,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = Vec2(85,110), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(82,110), [2] = 0},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,110), [2] = 1},
        { [1] = Vec2(82,111), [2] = 1},
        { [1] = Vec2(82,111), [2] = 1},
        { [1] = Vec2(82,112), [2] = 1},
        { [1] = Vec2(82,112), [2] = 1},
        { [1] = Vec2(82,114), [2] = 1},
        { [1] = Vec2(82,114), [2] = 1},
        { [1] = Vec2(82,115), [2] = 1},
        { [1] = Vec2(82,115), [2] = 1},
        { [1] = Vec2(82,115), [2] = 1},
        { [1] = Vec2(82,115), [2] = 1},
        { [1] = Vec2(82,117), [2] = 1},
        { [1] = Vec2(82,117), [2] = 1},
        { [1] = Vec2(82,118), [2] = 1},
        { [1] = Vec2(82,118), [2] = 1},
        { [1] = Vec2(82,118), [2] = 1},
        { [1] = Vec2(82,118), [2] = 1},
        { [1] = Vec2(82,120), [2] = 1},
        { [1] = Vec2(82,120), [2] = 1},
        { [1] = Vec2(82,120), [2] = 1},
        { [1] = Vec2(82,120), [2] = 1},
        { [1] = Vec2(82,121), [2] = 1},
        { [1] = Vec2(82,121), [2] = 1},
        { [1] = Vec2(82,121), [2] = 1},
        { [1] = Vec2(82,121), [2] = 1},
        { [1] = Vec2(82,121), [2] = 1},
        { [1] = Vec2(82,121), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,122), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,123), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(82,124), [2] = 1},
        { [1] = Vec2(83,124), [2] = 1},
        { [1] = Vec2(83,124), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,125), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,126), [2] = 1},
        { [1] = Vec2(83,127), [2] = 1},
        { [1] = Vec2(83,127), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(84,111), [2] = 0},
        { [1] = Vec2(84,111), [2] = 1},
        { [1] = Vec2(84,111), [2] = 1},
        { [1] = Vec2(84,111), [2] = 1},
        { [1] = Vec2(84,111), [2] = 1},
        { [1] = Vec2(84,111), [2] = 1},
        { [1] = Vec2(84,111), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,110), [2] = 1},
        { [1] = Vec2(84,109), [2] = 1},
        { [1] = Vec2(84,109), [2] = 1},
        { [1] = Vec2(84,108), [2] = 1},
        { [1] = Vec2(84,108), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,107), [2] = 1},
        { [1] = Vec2(84,105), [2] = 1},
        { [1] = Vec2(84,105), [2] = 1},
        { [1] = Vec2(84,105), [2] = 1},
        { [1] = Vec2(84,105), [2] = 1},
        { [1] = Vec2(83,104), [2] = 1},
        { [1] = Vec2(83,104), [2] = 1},
        { [1] = Vec2(83,101), [2] = 1},
        { [1] = Vec2(83,101), [2] = 1},
        { [1] = Vec2(83,100), [2] = 1},
        { [1] = Vec2(83,100), [2] = 1},
        { [1] = Vec2(83,99), [2] = 1},
        { [1] = Vec2(83,99), [2] = 1},
        { [1] = Vec2(83,99), [2] = 1},
        { [1] = Vec2(83,99), [2] = 1},
        { [1] = Vec2(83,99), [2] = 1},
        { [1] = Vec2(83,99), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,98), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,97), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,96), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = Vec2(83,95), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(99,125), [2] = 0},
        { [1] = Vec2(99,125), [2] = 1},
        { [1] = Vec2(99,125), [2] = 1},
        { [1] = Vec2(99,125), [2] = 1},
        { [1] = Vec2(99,125), [2] = 1},
        { [1] = Vec2(99,125), [2] = 1},
        { [1] = Vec2(99,125), [2] = 1},
        { [1] = Vec2(100,125), [2] = 1},
        { [1] = Vec2(100,125), [2] = 1},
        { [1] = Vec2(101,125), [2] = 1},
        { [1] = Vec2(101,125), [2] = 1},
        { [1] = Vec2(102,125), [2] = 1},
        { [1] = Vec2(102,125), [2] = 1},
        { [1] = Vec2(103,125), [2] = 1},
        { [1] = Vec2(103,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(105,125), [2] = 1},
        { [1] = Vec2(106,125), [2] = 1},
        { [1] = Vec2(106,125), [2] = 1},
        { [1] = Vec2(106,125), [2] = 1},
        { [1] = Vec2(106,125), [2] = 1},
        { [1] = Vec2(106,125), [2] = 1},
        { [1] = Vec2(106,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(107,125), [2] = 1},
        { [1] = Vec2(108,125), [2] = 1},
        { [1] = Vec2(108,125), [2] = 1},
        { [1] = Vec2(108,125), [2] = 1},
        { [1] = Vec2(108,125), [2] = 1},
        { [1] = Vec2(108,125), [2] = 1},
        { [1] = Vec2(108,125), [2] = 1},
        { [1] = Vec2(108,124), [2] = 1},
        { [1] = Vec2(108,124), [2] = 1},
        { [1] = Vec2(108,124), [2] = 1},
        { [1] = Vec2(108,124), [2] = 1},
        { [1] = Vec2(109,124), [2] = 1},
        { [1] = Vec2(109,124), [2] = 1},
        { [1] = Vec2(109,124), [2] = 1},
        { [1] = Vec2(109,124), [2] = 1},
        { [1] = Vec2(110,124), [2] = 1},
        { [1] = Vec2(110,124), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(110,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,123), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(111,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(112,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(113,122), [2] = 1},
        { [1] = Vec2(114,122), [2] = 1},
        { [1] = Vec2(114,122), [2] = 1},
        { [1] = Vec2(114,122), [2] = 1},
        { [1] = Vec2(114,122), [2] = 1},
        { [1] = Vec2(114,122), [2] = 1},
        { [1] = Vec2(114,122), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(90,109), [2] = 0},
        { [1] = Vec2(90,109), [2] = 1},
        { [1] = Vec2(90,109), [2] = 1},
        { [1] = Vec2(90,109), [2] = 1},
        { [1] = Vec2(90,109), [2] = 1},
        { [1] = Vec2(91,109), [2] = 1},
        { [1] = Vec2(91,109), [2] = 1},
        { [1] = Vec2(92,109), [2] = 1},
        { [1] = Vec2(92,109), [2] = 1},
        { [1] = Vec2(93,109), [2] = 1},
        { [1] = Vec2(93,109), [2] = 1},
        { [1] = Vec2(93,109), [2] = 1},
        { [1] = Vec2(93,109), [2] = 1},
        { [1] = Vec2(93,109), [2] = 1},
        { [1] = Vec2(93,109), [2] = 1},
        { [1] = Vec2(94,109), [2] = 1},
        { [1] = Vec2(94,109), [2] = 1},
        { [1] = Vec2(94,109), [2] = 1},
        { [1] = Vec2(94,109), [2] = 1},
        { [1] = Vec2(94,109), [2] = 1},
        { [1] = Vec2(94,109), [2] = 1},
        { [1] = Vec2(95,109), [2] = 1},
        { [1] = Vec2(95,109), [2] = 1},
        { [1] = Vec2(95,109), [2] = 1},
        { [1] = Vec2(95,109), [2] = 1},
        { [1] = Vec2(95,109), [2] = 1},
        { [1] = Vec2(95,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(96,109), [2] = 1},
        { [1] = Vec2(97,109), [2] = 1},
        { [1] = Vec2(97,109), [2] = 1},
        { [1] = Vec2(97,109), [2] = 1},
        { [1] = Vec2(97,109), [2] = 1},
        { [1] = Vec2(98,109), [2] = 1},
        { [1] = Vec2(98,109), [2] = 1},
        { [1] = Vec2(98,109), [2] = 1},
        { [1] = Vec2(98,109), [2] = 1},
        { [1] = Vec2(99,109), [2] = 1},
        { [1] = Vec2(99,109), [2] = 1},
        { [1] = Vec2(99,109), [2] = 1},
        { [1] = Vec2(99,109), [2] = 1},
        { [1] = Vec2(99,109), [2] = 1},
        { [1] = Vec2(99,109), [2] = 1},
        { [1] = Vec2(100,109), [2] = 1},
        { [1] = Vec2(100,109), [2] = 1},
        { [1] = Vec2(100,109), [2] = 1},
        { [1] = Vec2(100,109), [2] = 1},
        { [1] = Vec2(101,109), [2] = 1},
        { [1] = Vec2(101,109), [2] = 1},
        { [1] = Vec2(101,109), [2] = 1},
        { [1] = Vec2(101,109), [2] = 1},
        { [1] = Vec2(102,109), [2] = 1},
        { [1] = Vec2(102,109), [2] = 1},
        { [1] = Vec2(102,109), [2] = 1},
        { [1] = Vec2(102,109), [2] = 1},
        { [1] = Vec2(103,109), [2] = 1},
        { [1] = Vec2(103,109), [2] = 1},
        { [1] = Vec2(103,109), [2] = 1},
        { [1] = Vec2(103,109), [2] = 1},
        { [1] = Vec2(104,109), [2] = 1},
        { [1] = Vec2(104,109), [2] = 1},
        { [1] = Vec2(104,109), [2] = 1},
        { [1] = Vec2(104,109), [2] = 1},
        { [1] = Vec2(104,109), [2] = 1},
        { [1] = Vec2(104,109), [2] = 1},
        { [1] = Vec2(105,109), [2] = 1},
        { [1] = Vec2(105,109), [2] = 1},
        { [1] = Vec2(106,109), [2] = 1},
        { [1] = Vec2(106,109), [2] = 1},
        { [1] = Vec2(107,109), [2] = 1},
        { [1] = Vec2(107,109), [2] = 1},
        { [1] = Vec2(107,109), [2] = 1},
        { [1] = Vec2(107,109), [2] = 1},
        { [1] = Vec2(108,109), [2] = 1},
        { [1] = Vec2(108,109), [2] = 1},
        { [1] = Vec2(108,109), [2] = 1},
        { [1] = Vec2(108,109), [2] = 1},
        { [1] = Vec2(110,109), [2] = 1},
        { [1] = Vec2(110,109), [2] = 1},
        { [1] = Vec2(110,109), [2] = 1},
        { [1] = Vec2(110,109), [2] = 1},
        { [1] = Vec2(111,109), [2] = 1},
        { [1] = Vec2(111,109), [2] = 1},
        { [1] = Vec2(112,109), [2] = 1},
        { [1] = Vec2(112,109), [2] = 1},
        { [1] = Vec2(112,109), [2] = 1},
        { [1] = Vec2(112,109), [2] = 1},
        { [1] = Vec2(113,109), [2] = 1},
        { [1] = Vec2(113,109), [2] = 1},
        { [1] = Vec2(114,109), [2] = 1},
        { [1] = Vec2(114,109), [2] = 1},
        { [1] = Vec2(114,109), [2] = 1},
        { [1] = Vec2(114,109), [2] = 1},
        { [1] = Vec2(115,109), [2] = 1},
        { [1] = Vec2(115,109), [2] = 1},
        { [1] = Vec2(116,109), [2] = 1},
        { [1] = Vec2(116,109), [2] = 1},
        { [1] = Vec2(116,109), [2] = 1},
        { [1] = Vec2(116,109), [2] = 1},
        { [1] = Vec2(116,109), [2] = 1},
        { [1] = Vec2(116,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(117,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(118,109), [2] = 1},
        { [1] = Vec2(119,109), [2] = 1},
        { [1] = Vec2(119,109), [2] = 1},
        { [1] = Vec2(119,109), [2] = 1},
        { [1] = Vec2(119,109), [2] = 1},
        { [1] = Vec2(119,109), [2] = 1},
        { [1] = Vec2(119,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(120,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(121,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(122,109), [2] = 1},
        { [1] = Vec2(123,109), [2] = 1},
        { [1] = Vec2(123,109), [2] = 1},
        { [1] = Vec2(124,109), [2] = 1},
        { [1] = Vec2(124,109), [2] = 1},
        { [1] = Vec2(125,109), [2] = 1},
        { [1] = Vec2(125,109), [2] = 1},
        { [1] = Vec2(125,109), [2] = 1},
        { [1] = Vec2(125,109), [2] = 1},
        { [1] = Vec2(125,109), [2] = 1},
        { [1] = Vec2(125,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(127,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(128,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(131,109), [2] = 1},
        { [1] = Vec2(132,109), [2] = 1},
        { [1] = Vec2(132,109), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(129,109), [2] = 0},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,109), [2] = 1},
        { [1] = Vec2(129,110), [2] = 1},
        { [1] = Vec2(129,110), [2] = 1},
        { [1] = Vec2(129,111), [2] = 1},
        { [1] = Vec2(129,111), [2] = 1},
        { [1] = Vec2(129,111), [2] = 1},
        { [1] = Vec2(129,111), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,114), [2] = 1},
        { [1] = Vec2(130,114), [2] = 1},
        { [1] = Vec2(130,114), [2] = 1},
        { [1] = Vec2(130,114), [2] = 1},
        { [1] = Vec2(130,114), [2] = 1},
        { [1] = Vec2(130,114), [2] = 1},
        { [1] = Vec2(131,114), [2] = 1},
        { [1] = Vec2(131,114), [2] = 1},
        { [1] = Vec2(131,115), [2] = 1},
        { [1] = Vec2(131,115), [2] = 1},
        { [1] = Vec2(131,117), [2] = 1},
        { [1] = Vec2(131,117), [2] = 1},
        { [1] = Vec2(132,119), [2] = 1},
        { [1] = Vec2(132,119), [2] = 1},
        { [1] = Vec2(132,119), [2] = 1},
        { [1] = Vec2(132,119), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(132,120), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,121), [2] = 1},
        { [1] = Vec2(133,123), [2] = 1},
        { [1] = Vec2(133,123), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,124), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = Vec2(133,125), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(130,109), [2] = 0},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,108), [2] = 1},
        { [1] = Vec2(130,108), [2] = 1},
        { [1] = Vec2(130,107), [2] = 1},
        { [1] = Vec2(130,107), [2] = 1},
        { [1] = Vec2(129,105), [2] = 1},
        { [1] = Vec2(129,105), [2] = 1},
        { [1] = Vec2(129,105), [2] = 1},
        { [1] = Vec2(129,105), [2] = 1},
        { [1] = Vec2(129,104), [2] = 1},
        { [1] = Vec2(129,104), [2] = 1},
        { [1] = Vec2(129,103), [2] = 1},
        { [1] = Vec2(129,103), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,99), [2] = 1},
        { [1] = Vec2(128,99), [2] = 1},
        { [1] = Vec2(127,98), [2] = 1},
        { [1] = Vec2(127,98), [2] = 1},
        { [1] = Vec2(127,96), [2] = 1},
        { [1] = Vec2(127,96), [2] = 1},
        { [1] = Vec2(127,96), [2] = 1},
        { [1] = Vec2(127,96), [2] = 1},
        { [1] = Vec2(126,94), [2] = 1},
        { [1] = Vec2(126,94), [2] = 1},
        { [1] = Vec2(126,94), [2] = 1},
        { [1] = Vec2(126,94), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(125,93), [2] = 1},
        { [1] = Vec2(125,93), [2] = 1},
        { [1] = Vec2(125,93), [2] = 1},
        { [1] = Vec2(125,93), [2] = 1},
        { [1] = Vec2(125,93), [2] = 1},
        { [1] = Vec2(125,93), [2] = 1},
        { [1] = Vec2(125,92), [2] = 1},
        { [1] = Vec2(125,92), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(113,98), [2] = 0},
        { [1] = Vec2(113,98), [2] = 1},
        { [1] = Vec2(113,98), [2] = 1},
        { [1] = Vec2(113,98), [2] = 1},
        { [1] = Vec2(113,98), [2] = 1},
        { [1] = Vec2(113,98), [2] = 1},
        { [1] = Vec2(113,98), [2] = 1},
        { [1] = Vec2(112,98), [2] = 1},
        { [1] = Vec2(112,98), [2] = 1},
        { [1] = Vec2(112,98), [2] = 1},
        { [1] = Vec2(112,98), [2] = 1},
        { [1] = Vec2(111,97), [2] = 1},
        { [1] = Vec2(111,97), [2] = 1},
        { [1] = Vec2(110,97), [2] = 1},
        { [1] = Vec2(110,97), [2] = 1},
        { [1] = Vec2(110,97), [2] = 1},
        { [1] = Vec2(110,97), [2] = 1},
        { [1] = Vec2(109,96), [2] = 1},
        { [1] = Vec2(109,96), [2] = 1},
        { [1] = Vec2(108,96), [2] = 1},
        { [1] = Vec2(108,96), [2] = 1},
        { [1] = Vec2(107,96), [2] = 1},
        { [1] = Vec2(107,96), [2] = 1},
        { [1] = Vec2(107,96), [2] = 1},
        { [1] = Vec2(107,96), [2] = 1},
        { [1] = Vec2(106,96), [2] = 1},
        { [1] = Vec2(106,96), [2] = 1},
        { [1] = Vec2(106,96), [2] = 1},
        { [1] = Vec2(106,96), [2] = 1},
        { [1] = Vec2(105,96), [2] = 1},
        { [1] = Vec2(105,96), [2] = 1},
        { [1] = Vec2(105,96), [2] = 1},
        { [1] = Vec2(105,96), [2] = 1},
        { [1] = Vec2(104,96), [2] = 1},
        { [1] = Vec2(104,96), [2] = 1},
        { [1] = Vec2(104,96), [2] = 1},
        { [1] = Vec2(104,96), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(103,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(102,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(101,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(99,94), [2] = 1},
        { [1] = Vec2(99,94), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(138,90), [2] = 0},
        { [1] = Vec2(137,90), [2] = 1},
        { [1] = Vec2(137,90), [2] = 1},
        { [1] = Vec2(137,89), [2] = 1},
        { [1] = Vec2(137,89), [2] = 1},
        { [1] = Vec2(137,89), [2] = 1},
        { [1] = Vec2(137,89), [2] = 1},
        { [1] = Vec2(137,88), [2] = 1},
        { [1] = Vec2(137,88), [2] = 1},
        { [1] = Vec2(136,88), [2] = 1},
        { [1] = Vec2(136,88), [2] = 1},
        { [1] = Vec2(136,87), [2] = 1},
        { [1] = Vec2(136,87), [2] = 1},
        { [1] = Vec2(136,86), [2] = 1},
        { [1] = Vec2(136,86), [2] = 1},
        { [1] = Vec2(136,85), [2] = 1},
        { [1] = Vec2(136,85), [2] = 1},
        { [1] = Vec2(135,84), [2] = 1},
        { [1] = Vec2(135,84), [2] = 1},
        { [1] = Vec2(135,83), [2] = 1},
        { [1] = Vec2(135,83), [2] = 1},
        { [1] = Vec2(134,82), [2] = 1},
        { [1] = Vec2(134,82), [2] = 1},
        { [1] = Vec2(134,81), [2] = 1},
        { [1] = Vec2(134,81), [2] = 1},
        { [1] = Vec2(133,81), [2] = 1},
        { [1] = Vec2(133,81), [2] = 1},
        { [1] = Vec2(133,79), [2] = 1},
        { [1] = Vec2(133,79), [2] = 1},
        { [1] = Vec2(133,79), [2] = 1},
        { [1] = Vec2(133,79), [2] = 1},
        { [1] = Vec2(133,79), [2] = 1},
        { [1] = Vec2(133,79), [2] = 1},
        { [1] = Vec2(132,78), [2] = 1},
        { [1] = Vec2(132,78), [2] = 1},
        { [1] = Vec2(132,77), [2] = 1},
        { [1] = Vec2(132,77), [2] = 1},
        { [1] = Vec2(132,77), [2] = 1},
        { [1] = Vec2(132,77), [2] = 1},
        { [1] = Vec2(131,76), [2] = 1},
        { [1] = Vec2(131,76), [2] = 1},
        { [1] = Vec2(131,76), [2] = 1},
        { [1] = Vec2(131,76), [2] = 1},
        { [1] = Vec2(131,75), [2] = 1},
        { [1] = Vec2(131,75), [2] = 1},
        { [1] = Vec2(131,75), [2] = 1},
        { [1] = Vec2(131,75), [2] = 1},
        { [1] = Vec2(131,74), [2] = 1},
        { [1] = Vec2(131,74), [2] = 1},
        { [1] = Vec2(130,74), [2] = 1},
        { [1] = Vec2(130,74), [2] = 1},
        { [1] = Vec2(130,73), [2] = 1},
        { [1] = Vec2(130,73), [2] = 1},
        { [1] = Vec2(130,73), [2] = 1},
        { [1] = Vec2(130,73), [2] = 1},
        { [1] = Vec2(130,72), [2] = 1},
        { [1] = Vec2(130,72), [2] = 1},
        { [1] = Vec2(130,72), [2] = 1},
        { [1] = Vec2(130,72), [2] = 1},
        { [1] = Vec2(130,72), [2] = 1},
        { [1] = Vec2(130,72), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(130,71), [2] = 1},
        { [1] = Vec2(129,71), [2] = 1},
        { [1] = Vec2(129,71), [2] = 1},
        { [1] = Vec2(129,71), [2] = 1},
        { [1] = Vec2(129,71), [2] = 1},
        { [1] = Vec2(129,70), [2] = 1},
        { [1] = Vec2(129,70), [2] = 1},
        { [1] = Vec2(129,70), [2] = 1},
        { [1] = Vec2(129,70), [2] = 1},
        { [1] = Vec2(129,70), [2] = 1},
        { [1] = Vec2(129,70), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(126,49), [2] = 0},
        { [1] = Vec2(126,49), [2] = 1},
        { [1] = Vec2(126,49), [2] = 1},
        { [1] = Vec2(126,49), [2] = 1},
        { [1] = Vec2(126,49), [2] = 1},
        { [1] = Vec2(127,48), [2] = 1},
        { [1] = Vec2(127,48), [2] = 1},
        { [1] = Vec2(127,47), [2] = 1},
        { [1] = Vec2(127,47), [2] = 1},
        { [1] = Vec2(127,47), [2] = 1},
        { [1] = Vec2(127,47), [2] = 1},
        { [1] = Vec2(127,46), [2] = 1},
        { [1] = Vec2(127,46), [2] = 1},
        { [1] = Vec2(128,46), [2] = 1},
        { [1] = Vec2(128,46), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,44), [2] = 1},
        { [1] = Vec2(128,44), [2] = 1},
        { [1] = Vec2(128,44), [2] = 1},
        { [1] = Vec2(128,44), [2] = 1},
        { [1] = Vec2(129,43), [2] = 1},
        { [1] = Vec2(129,43), [2] = 1},
        { [1] = Vec2(129,43), [2] = 1},
        { [1] = Vec2(129,43), [2] = 1},
        { [1] = Vec2(129,42), [2] = 1},
        { [1] = Vec2(129,42), [2] = 1},
        { [1] = Vec2(130,42), [2] = 1},
        { [1] = Vec2(130,42), [2] = 1},
        { [1] = Vec2(130,42), [2] = 1},
        { [1] = Vec2(130,42), [2] = 1},
        { [1] = Vec2(130,41), [2] = 1},
        { [1] = Vec2(130,41), [2] = 1},
        { [1] = Vec2(130,40), [2] = 1},
        { [1] = Vec2(130,40), [2] = 1},
        { [1] = Vec2(130,40), [2] = 1},
        { [1] = Vec2(130,40), [2] = 1},
        { [1] = Vec2(130,40), [2] = 1},
        { [1] = Vec2(130,40), [2] = 1},
        { [1] = Vec2(131,40), [2] = 1},
        { [1] = Vec2(131,40), [2] = 1},
        { [1] = Vec2(131,40), [2] = 1},
        { [1] = Vec2(131,40), [2] = 1},
        { [1] = Vec2(131,39), [2] = 1},
        { [1] = Vec2(131,39), [2] = 1},
        { [1] = Vec2(131,39), [2] = 1},
        { [1] = Vec2(131,39), [2] = 1},
        { [1] = Vec2(131,38), [2] = 1},
        { [1] = Vec2(131,38), [2] = 1},
        { [1] = Vec2(131,38), [2] = 1},
        { [1] = Vec2(131,38), [2] = 1},
        { [1] = Vec2(131,38), [2] = 1},
        { [1] = Vec2(131,38), [2] = 1},
        { [1] = Vec2(131,36), [2] = 1},
        { [1] = Vec2(131,36), [2] = 1},
        { [1] = Vec2(132,35), [2] = 1},
        { [1] = Vec2(132,35), [2] = 1},
        { [1] = Vec2(132,34), [2] = 1},
        { [1] = Vec2(132,34), [2] = 1},
        { [1] = Vec2(133,33), [2] = 1},
        { [1] = Vec2(133,33), [2] = 1},
        { [1] = Vec2(133,32), [2] = 1},
        { [1] = Vec2(133,32), [2] = 1},
        { [1] = Vec2(134,31), [2] = 1},
        { [1] = Vec2(134,31), [2] = 1},
        { [1] = Vec2(134,32), [2] = 1},
        { [1] = Vec2(134,32), [2] = 1},
        { [1] = Vec2(134,32), [2] = 1},
        { [1] = Vec2(134,32), [2] = 1},
        { [1] = Vec2(134,32), [2] = 1},
        { [1] = Vec2(134,32), [2] = 1},
        { [1] = Vec2(134,33), [2] = 1},
        { [1] = Vec2(134,33), [2] = 1},
        { [1] = Vec2(134,33), [2] = 1},
        { [1] = Vec2(134,33), [2] = 1},
        { [1] = Vec2(133,34), [2] = 1},
        { [1] = Vec2(133,34), [2] = 1},
        { [1] = Vec2(133,35), [2] = 1},
        { [1] = Vec2(133,35), [2] = 1},
        { [1] = Vec2(133,35), [2] = 1},
        { [1] = Vec2(133,35), [2] = 1},
        { [1] = Vec2(133,36), [2] = 1},
        { [1] = Vec2(133,36), [2] = 1},
        { [1] = Vec2(134,37), [2] = 1},
        { [1] = Vec2(134,37), [2] = 1},
        { [1] = Vec2(134,37), [2] = 1},
        { [1] = Vec2(134,37), [2] = 1},
        { [1] = Vec2(134,38), [2] = 1},
        { [1] = Vec2(134,38), [2] = 1},
        { [1] = Vec2(135,38), [2] = 1},
        { [1] = Vec2(135,38), [2] = 1},
        { [1] = Vec2(136,38), [2] = 1},
        { [1] = Vec2(136,38), [2] = 1},
        { [1] = Vec2(136,38), [2] = 1},
        { [1] = Vec2(136,38), [2] = 1},
        { [1] = Vec2(137,37), [2] = 1},
        { [1] = Vec2(137,37), [2] = 1},
        { [1] = Vec2(137,36), [2] = 1},
        { [1] = Vec2(137,36), [2] = 1},
        { [1] = Vec2(137,34), [2] = 1},
        { [1] = Vec2(137,34), [2] = 1},
        { [1] = Vec2(136,33), [2] = 1},
        { [1] = Vec2(136,33), [2] = 1},
        { [1] = Vec2(135,31), [2] = 1},
        { [1] = Vec2(135,31), [2] = 1},
        { [1] = Vec2(134,30), [2] = 1},
        { [1] = Vec2(134,30), [2] = 1},
        { [1] = Vec2(134,29), [2] = 1},
        { [1] = Vec2(134,29), [2] = 1},
        { [1] = Vec2(133,27), [2] = 1},
        { [1] = Vec2(133,27), [2] = 1},
        { [1] = Vec2(133,26), [2] = 1},
        { [1] = Vec2(133,26), [2] = 1},
        { [1] = Vec2(133,25), [2] = 1},
        { [1] = Vec2(133,25), [2] = 1},
        { [1] = Vec2(133,24), [2] = 1},
        { [1] = Vec2(133,24), [2] = 1},
        { [1] = Vec2(133,24), [2] = 1},
        { [1] = Vec2(133,24), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(26,59), [2] = 0},
        { [1] = Vec2(26,59), [2] = 1},
        { [1] = Vec2(26,59), [2] = 1},
        { [1] = Vec2(26,59), [2] = 1},
        { [1] = Vec2(26,59), [2] = 1},
        { [1] = Vec2(27,59), [2] = 1},
        { [1] = Vec2(27,59), [2] = 1},
        { [1] = Vec2(28,59), [2] = 1},
        { [1] = Vec2(28,59), [2] = 1},
        { [1] = Vec2(30,59), [2] = 1},
        { [1] = Vec2(30,59), [2] = 1},
        { [1] = Vec2(31,59), [2] = 1},
        { [1] = Vec2(31,59), [2] = 1},
        { [1] = Vec2(31,59), [2] = 1},
        { [1] = Vec2(31,59), [2] = 1},
        { [1] = Vec2(33,59), [2] = 1},
        { [1] = Vec2(33,59), [2] = 1},
        { [1] = Vec2(33,59), [2] = 1},
        { [1] = Vec2(33,59), [2] = 1},
        { [1] = Vec2(35,59), [2] = 1},
        { [1] = Vec2(35,59), [2] = 1},
        { [1] = Vec2(35,59), [2] = 1},
        { [1] = Vec2(35,59), [2] = 1},
        { [1] = Vec2(37,59), [2] = 1},
        { [1] = Vec2(37,59), [2] = 1},
        { [1] = Vec2(38,59), [2] = 1},
        { [1] = Vec2(38,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = Vec2(41,59), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(40,59), [2] = 0},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,59), [2] = 1},
        { [1] = Vec2(40,60), [2] = 1},
        { [1] = Vec2(40,60), [2] = 1},
        { [1] = Vec2(40,62), [2] = 1},
        { [1] = Vec2(40,62), [2] = 1},
        { [1] = Vec2(40,64), [2] = 1},
        { [1] = Vec2(40,64), [2] = 1},
        { [1] = Vec2(40,65), [2] = 1},
        { [1] = Vec2(40,65), [2] = 1},
        { [1] = Vec2(40,67), [2] = 1},
        { [1] = Vec2(40,67), [2] = 1},
        { [1] = Vec2(39,70), [2] = 1},
        { [1] = Vec2(39,70), [2] = 1},
        { [1] = Vec2(39,72), [2] = 1},
        { [1] = Vec2(39,72), [2] = 1},
        { [1] = Vec2(38,73), [2] = 1},
        { [1] = Vec2(38,73), [2] = 1},
        { [1] = Vec2(38,74), [2] = 1},
        { [1] = Vec2(38,74), [2] = 1},
        { [1] = Vec2(38,75), [2] = 1},
        { [1] = Vec2(38,75), [2] = 1},
        { [1] = Vec2(38,75), [2] = 1},
        { [1] = Vec2(38,75), [2] = 1},
        { [1] = Vec2(38,76), [2] = 1},
        { [1] = Vec2(38,76), [2] = 1},
        { [1] = Vec2(38,77), [2] = 1},
        { [1] = Vec2(38,77), [2] = 1},
        { [1] = Vec2(38,78), [2] = 1},
        { [1] = Vec2(38,78), [2] = 1},
        { [1] = Vec2(39,79), [2] = 1},
        { [1] = Vec2(39,79), [2] = 1},
        { [1] = Vec2(39,79), [2] = 1},
        { [1] = Vec2(39,79), [2] = 1},
        { [1] = Vec2(40,79), [2] = 1},
        { [1] = Vec2(40,79), [2] = 1},
        { [1] = Vec2(43,80), [2] = 1},
        { [1] = Vec2(43,80), [2] = 1},
        { [1] = Vec2(44,81), [2] = 1},
        { [1] = Vec2(44,81), [2] = 1},
        { [1] = Vec2(45,81), [2] = 1},
        { [1] = Vec2(45,81), [2] = 1},
        { [1] = Vec2(46,82), [2] = 1},
        { [1] = Vec2(46,82), [2] = 1},
        { [1] = Vec2(46,83), [2] = 1},
        { [1] = Vec2(46,83), [2] = 1},
        { [1] = Vec2(46,84), [2] = 1},
        { [1] = Vec2(46,84), [2] = 1},
        { [1] = Vec2(45,84), [2] = 1},
        { [1] = Vec2(45,84), [2] = 1},
        { [1] = Vec2(44,84), [2] = 1},
        { [1] = Vec2(44,84), [2] = 1},
        { [1] = Vec2(42,84), [2] = 1},
        { [1] = Vec2(42,84), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(38,56), [2] = 0},
        { [1] = Vec2(38,56), [2] = 1},
        { [1] = Vec2(38,56), [2] = 1},
        { [1] = Vec2(38,56), [2] = 1},
        { [1] = Vec2(38,56), [2] = 1},
        { [1] = Vec2(38,55), [2] = 1},
        { [1] = Vec2(38,55), [2] = 1},
        { [1] = Vec2(38,53), [2] = 1},
        { [1] = Vec2(38,53), [2] = 1},
        { [1] = Vec2(38,52), [2] = 1},
        { [1] = Vec2(38,52), [2] = 1},
        { [1] = Vec2(38,49), [2] = 1},
        { [1] = Vec2(38,49), [2] = 1},
        { [1] = Vec2(37,48), [2] = 1},
        { [1] = Vec2(37,48), [2] = 1},
        { [1] = Vec2(37,46), [2] = 1},
        { [1] = Vec2(37,46), [2] = 1},
        { [1] = Vec2(37,45), [2] = 1},
        { [1] = Vec2(37,45), [2] = 1},
        { [1] = Vec2(36,44), [2] = 1},
        { [1] = Vec2(36,44), [2] = 1},
        { [1] = Vec2(36,42), [2] = 1},
        { [1] = Vec2(36,42), [2] = 1},
        { [1] = Vec2(36,40), [2] = 1},
        { [1] = Vec2(36,40), [2] = 1},
        { [1] = Vec2(36,38), [2] = 1},
        { [1] = Vec2(36,38), [2] = 1},
        { [1] = Vec2(36,37), [2] = 1},
        { [1] = Vec2(36,37), [2] = 1},
        { [1] = Vec2(36,36), [2] = 1},
        { [1] = Vec2(36,36), [2] = 1},
        { [1] = Vec2(36,35), [2] = 1},
        { [1] = Vec2(36,35), [2] = 1},
        { [1] = Vec2(36,35), [2] = 1},
        { [1] = Vec2(36,35), [2] = 1},
        { [1] = Vec2(37,34), [2] = 1},
        { [1] = Vec2(37,34), [2] = 1},
        { [1] = Vec2(37,35), [2] = 1},
        { [1] = Vec2(37,35), [2] = 1},
        { [1] = Vec2(38,35), [2] = 1},
        { [1] = Vec2(38,35), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(49,59), [2] = 0},
        { [1] = Vec2(49,59), [2] = 1},
        { [1] = Vec2(49,59), [2] = 1},
        { [1] = Vec2(49,59), [2] = 1},
        { [1] = Vec2(49,59), [2] = 1},
        { [1] = Vec2(50,59), [2] = 1},
        { [1] = Vec2(50,59), [2] = 1},
        { [1] = Vec2(50,59), [2] = 1},
        { [1] = Vec2(50,59), [2] = 1},
        { [1] = Vec2(51,59), [2] = 1},
        { [1] = Vec2(51,59), [2] = 1},
        { [1] = Vec2(52,59), [2] = 1},
        { [1] = Vec2(52,59), [2] = 1},
        { [1] = Vec2(53,59), [2] = 1},
        { [1] = Vec2(53,59), [2] = 1},
        { [1] = Vec2(54,59), [2] = 1},
        { [1] = Vec2(54,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(55,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(56,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(57,59), [2] = 0},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,59), [2] = 1},
        { [1] = Vec2(57,60), [2] = 1},
        { [1] = Vec2(57,60), [2] = 1},
        { [1] = Vec2(57,61), [2] = 1},
        { [1] = Vec2(57,61), [2] = 1},
        { [1] = Vec2(57,62), [2] = 1},
        { [1] = Vec2(57,62), [2] = 1},
        { [1] = Vec2(57,62), [2] = 1},
        { [1] = Vec2(57,62), [2] = 1},
        { [1] = Vec2(57,63), [2] = 1},
        { [1] = Vec2(57,63), [2] = 1},
        { [1] = Vec2(57,64), [2] = 1},
        { [1] = Vec2(57,64), [2] = 1},
        { [1] = Vec2(57,64), [2] = 1},
        { [1] = Vec2(57,64), [2] = 1},
        { [1] = Vec2(57,65), [2] = 1},
        { [1] = Vec2(57,65), [2] = 1},
        { [1] = Vec2(57,65), [2] = 1},
        { [1] = Vec2(57,65), [2] = 1},
        { [1] = Vec2(57,66), [2] = 1},
        { [1] = Vec2(57,66), [2] = 1},
        { [1] = Vec2(57,66), [2] = 1},
        { [1] = Vec2(57,66), [2] = 1},
        { [1] = Vec2(57,66), [2] = 1},
        { [1] = Vec2(57,66), [2] = 1},
        { [1] = Vec2(57,67), [2] = 1},
        { [1] = Vec2(57,67), [2] = 1},
        { [1] = Vec2(57,67), [2] = 1},
        { [1] = Vec2(57,67), [2] = 1},
        { [1] = Vec2(57,68), [2] = 1},
        { [1] = Vec2(57,68), [2] = 1},
        { [1] = Vec2(57,69), [2] = 1},
        { [1] = Vec2(57,69), [2] = 1},
        { [1] = Vec2(56,70), [2] = 1},
        { [1] = Vec2(56,70), [2] = 1},
        { [1] = Vec2(56,70), [2] = 1},
        { [1] = Vec2(56,70), [2] = 1},
        { [1] = Vec2(56,71), [2] = 1},
        { [1] = Vec2(56,71), [2] = 1},
        { [1] = Vec2(56,71), [2] = 1},
        { [1] = Vec2(56,71), [2] = 1},
        { [1] = Vec2(56,72), [2] = 1},
        { [1] = Vec2(56,72), [2] = 1},
        { [1] = Vec2(56,73), [2] = 1},
        { [1] = Vec2(56,73), [2] = 1},
        { [1] = Vec2(56,73), [2] = 1},
        { [1] = Vec2(56,73), [2] = 1},
        { [1] = Vec2(56,74), [2] = 1},
        { [1] = Vec2(56,74), [2] = 1},
        { [1] = Vec2(56,74), [2] = 1},
        { [1] = Vec2(56,74), [2] = 1},
        { [1] = Vec2(56,75), [2] = 1},
        { [1] = Vec2(56,75), [2] = 1},
        { [1] = Vec2(56,75), [2] = 1},
        { [1] = Vec2(56,75), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = Vec2(56,76), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(58,76), [2] = 0},
        { [1] = Vec2(58,76), [2] = 1},
        { [1] = Vec2(58,76), [2] = 1},
        { [1] = Vec2(58,76), [2] = 1},
        { [1] = Vec2(58,76), [2] = 1},
        { [1] = Vec2(58,76), [2] = 1},
        { [1] = Vec2(58,76), [2] = 1},
        { [1] = Vec2(59,76), [2] = 1},
        { [1] = Vec2(59,76), [2] = 1},
        { [1] = Vec2(59,76), [2] = 1},
        { [1] = Vec2(59,76), [2] = 1},
        { [1] = Vec2(60,76), [2] = 1},
        { [1] = Vec2(60,76), [2] = 1},
        { [1] = Vec2(60,77), [2] = 1},
        { [1] = Vec2(60,77), [2] = 1},
        { [1] = Vec2(61,77), [2] = 1},
        { [1] = Vec2(61,77), [2] = 1},
        { [1] = Vec2(62,77), [2] = 1},
        { [1] = Vec2(62,77), [2] = 1},
        { [1] = Vec2(62,77), [2] = 1},
        { [1] = Vec2(62,77), [2] = 1},
        { [1] = Vec2(63,77), [2] = 1},
        { [1] = Vec2(63,77), [2] = 1},
        { [1] = Vec2(63,77), [2] = 1},
        { [1] = Vec2(63,77), [2] = 1},
        { [1] = Vec2(63,77), [2] = 1},
        { [1] = Vec2(63,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(64,77), [2] = 1},
        { [1] = Vec2(65,77), [2] = 1},
        { [1] = Vec2(65,77), [2] = 1},
        { [1] = Vec2(65,77), [2] = 1},
        { [1] = Vec2(65,77), [2] = 1},
        { [1] = Vec2(66,77), [2] = 1},
        { [1] = Vec2(66,77), [2] = 1},
        { [1] = Vec2(66,77), [2] = 1},
        { [1] = Vec2(66,77), [2] = 1},
        { [1] = Vec2(67,77), [2] = 1},
        { [1] = Vec2(67,77), [2] = 1},
        { [1] = Vec2(68,77), [2] = 1},
        { [1] = Vec2(68,77), [2] = 1},
        { [1] = Vec2(68,77), [2] = 1},
        { [1] = Vec2(68,77), [2] = 1},
        { [1] = Vec2(69,77), [2] = 1},
        { [1] = Vec2(69,77), [2] = 1},
        { [1] = Vec2(70,77), [2] = 1},
        { [1] = Vec2(70,77), [2] = 1},
        { [1] = Vec2(71,77), [2] = 1},
        { [1] = Vec2(71,77), [2] = 1},
        { [1] = Vec2(72,77), [2] = 1},
        { [1] = Vec2(72,77), [2] = 1},
        { [1] = Vec2(72,77), [2] = 1},
        { [1] = Vec2(72,77), [2] = 1},
        { [1] = Vec2(72,77), [2] = 1},
        { [1] = Vec2(72,77), [2] = 1},
        { [1] = Vec2(74,77), [2] = 1},
        { [1] = Vec2(74,77), [2] = 1},
        { [1] = Vec2(75,77), [2] = 1},
        { [1] = Vec2(75,77), [2] = 1},
        { [1] = Vec2(75,77), [2] = 1},
        { [1] = Vec2(75,77), [2] = 1},
        { [1] = Vec2(76,78), [2] = 1},
        { [1] = Vec2(76,78), [2] = 1},
        { [1] = Vec2(76,78), [2] = 1},
        { [1] = Vec2(76,78), [2] = 1},
        { [1] = Vec2(77,78), [2] = 1},
        { [1] = Vec2(77,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(78,78), [2] = 1},
        { [1] = Vec2(79,78), [2] = 1},
        { [1] = Vec2(79,78), [2] = 1},
        { [1] = Vec2(79,78), [2] = 1},
        { [1] = Vec2(79,78), [2] = 1},
        { [1] = Vec2(80,78), [2] = 1},
        { [1] = Vec2(80,78), [2] = 1},
        { [1] = Vec2(81,78), [2] = 1},
        { [1] = Vec2(81,78), [2] = 1},
        { [1] = Vec2(81,78), [2] = 1},
        { [1] = Vec2(81,78), [2] = 1},
        { [1] = Vec2(82,78), [2] = 1},
        { [1] = Vec2(82,78), [2] = 1},
        { [1] = Vec2(83,79), [2] = 1},
        { [1] = Vec2(83,79), [2] = 1},
        { [1] = Vec2(83,79), [2] = 1},
        { [1] = Vec2(83,79), [2] = 1},
        { [1] = Vec2(85,79), [2] = 1},
        { [1] = Vec2(85,79), [2] = 1},
        { [1] = Vec2(85,79), [2] = 1},
        { [1] = Vec2(85,79), [2] = 1},
        { [1] = Vec2(86,79), [2] = 1},
        { [1] = Vec2(86,79), [2] = 1},
        { [1] = Vec2(87,79), [2] = 1},
        { [1] = Vec2(87,79), [2] = 1},
        { [1] = Vec2(87,79), [2] = 1},
        { [1] = Vec2(87,79), [2] = 1},
        { [1] = Vec2(88,79), [2] = 1},
        { [1] = Vec2(88,79), [2] = 1},
        { [1] = Vec2(88,79), [2] = 1},
        { [1] = Vec2(88,79), [2] = 1},
        { [1] = Vec2(89,79), [2] = 1},
        { [1] = Vec2(89,79), [2] = 1},
        { [1] = Vec2(90,79), [2] = 1},
        { [1] = Vec2(90,79), [2] = 1},
        { [1] = Vec2(90,79), [2] = 1},
        { [1] = Vec2(90,79), [2] = 1},
        { [1] = Vec2(90,79), [2] = 1},
        { [1] = Vec2(90,79), [2] = 1},
        { [1] = Vec2(91,79), [2] = 1},
        { [1] = Vec2(91,79), [2] = 1},
        { [1] = Vec2(91,79), [2] = 1},
        { [1] = Vec2(91,79), [2] = 1},
        { [1] = Vec2(91,79), [2] = 1},
        { [1] = Vec2(91,79), [2] = 1},
        { [1] = Vec2(92,79), [2] = 1},
        { [1] = Vec2(92,79), [2] = 1},
        { [1] = Vec2(92,79), [2] = 1},
        { [1] = Vec2(92,79), [2] = 1},
        { [1] = Vec2(93,79), [2] = 1},
        { [1] = Vec2(93,79), [2] = 1},
        { [1] = Vec2(93,79), [2] = 1},
        { [1] = Vec2(93,79), [2] = 1},
        { [1] = Vec2(94,79), [2] = 1},
        { [1] = Vec2(94,79), [2] = 1},
        { [1] = Vec2(94,79), [2] = 1},
        { [1] = Vec2(94,79), [2] = 1},
        { [1] = Vec2(94,79), [2] = 1},
        { [1] = Vec2(94,79), [2] = 1},
        { [1] = Vec2(95,79), [2] = 1},
        { [1] = Vec2(95,79), [2] = 1},
        { [1] = Vec2(95,79), [2] = 1},
        { [1] = Vec2(95,79), [2] = 1},
        { [1] = Vec2(95,79), [2] = 1},
        { [1] = Vec2(95,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(96,79), [2] = 1},
        { [1] = Vec2(97,79), [2] = 1},
        { [1] = Vec2(97,79), [2] = 1},
        { [1] = Vec2(97,79), [2] = 1},
        { [1] = Vec2(97,79), [2] = 1},
        { [1] = Vec2(97,79), [2] = 1},
        { [1] = Vec2(97,79), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(100,78), [2] = 0},
        { [1] = Vec2(100,78), [2] = 1},
        { [1] = Vec2(100,78), [2] = 1},
        { [1] = Vec2(100,77), [2] = 1},
        { [1] = Vec2(100,77), [2] = 1},
        { [1] = Vec2(100,77), [2] = 1},
        { [1] = Vec2(100,77), [2] = 1},
        { [1] = Vec2(100,77), [2] = 1},
        { [1] = Vec2(100,77), [2] = 1},
        { [1] = Vec2(100,76), [2] = 1},
        { [1] = Vec2(100,76), [2] = 1},
        { [1] = Vec2(100,75), [2] = 1},
        { [1] = Vec2(100,75), [2] = 1},
        { [1] = Vec2(99,72), [2] = 1},
        { [1] = Vec2(99,72), [2] = 1},
        { [1] = Vec2(99,71), [2] = 1},
        { [1] = Vec2(99,71), [2] = 1},
        { [1] = Vec2(99,69), [2] = 1},
        { [1] = Vec2(99,69), [2] = 1},
        { [1] = Vec2(99,67), [2] = 1},
        { [1] = Vec2(99,67), [2] = 1},
        { [1] = Vec2(99,66), [2] = 1},
        { [1] = Vec2(99,66), [2] = 1},
        { [1] = Vec2(99,65), [2] = 1},
        { [1] = Vec2(99,65), [2] = 1},
        { [1] = Vec2(99,65), [2] = 1},
        { [1] = Vec2(99,65), [2] = 1},
        { [1] = Vec2(99,64), [2] = 1},
        { [1] = Vec2(99,64), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,63), [2] = 1},
        { [1] = Vec2(99,62), [2] = 1},
        { [1] = Vec2(99,62), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(100,60), [2] = 1},
        { [1] = Vec2(100,60), [2] = 1},
        { [1] = Vec2(100,58), [2] = 1},
        { [1] = Vec2(100,58), [2] = 1},
        { [1] = Vec2(100,57), [2] = 1},
        { [1] = Vec2(100,57), [2] = 1},
        { [1] = Vec2(100,57), [2] = 1},
        { [1] = Vec2(100,57), [2] = 1},
        { [1] = Vec2(100,57), [2] = 1},
        { [1] = Vec2(100,57), [2] = 1},
        { [1] = Vec2(100,55), [2] = 1},
        { [1] = Vec2(100,55), [2] = 1},
        { [1] = Vec2(100,55), [2] = 1},
        { [1] = Vec2(100,55), [2] = 1},
        { [1] = Vec2(100,54), [2] = 1},
        { [1] = Vec2(100,54), [2] = 1},
        { [1] = Vec2(100,53), [2] = 1},
        { [1] = Vec2(100,53), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,52), [2] = 1},
        { [1] = Vec2(100,51), [2] = 1},
        { [1] = Vec2(100,51), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,50), [2] = 1},
        { [1] = Vec2(100,49), [2] = 1},
        { [1] = Vec2(100,49), [2] = 1},
        { [1] = Vec2(100,49), [2] = 1},
        { [1] = Vec2(100,49), [2] = 1},
        { [1] = Vec2(100,49), [2] = 1},
        { [1] = Vec2(100,49), [2] = 1},
        { [1] = Vec2(100,48), [2] = 1},
        { [1] = Vec2(100,48), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,47), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,46), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,45), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(100,43), [2] = 1},
        { [1] = Vec2(99,43), [2] = 1},
        { [1] = Vec2(99,43), [2] = 1},
        { [1] = Vec2(99,43), [2] = 1},
        { [1] = Vec2(99,43), [2] = 1},
        { [1] = Vec2(99,42), [2] = 1},
        { [1] = Vec2(99,42), [2] = 1},
        { [1] = Vec2(99,42), [2] = 1},
        { [1] = Vec2(99,42), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(98,39), [2] = 0},
        { [1] = Vec2(98,39), [2] = 1},
        { [1] = Vec2(98,39), [2] = 1},
        { [1] = Vec2(97,39), [2] = 1},
        { [1] = Vec2(97,39), [2] = 1},
        { [1] = Vec2(96,39), [2] = 1},
        { [1] = Vec2(96,39), [2] = 1},
        { [1] = Vec2(96,39), [2] = 1},
        { [1] = Vec2(96,39), [2] = 1},
        { [1] = Vec2(95,39), [2] = 1},
        { [1] = Vec2(95,39), [2] = 1},
        { [1] = Vec2(94,39), [2] = 1},
        { [1] = Vec2(94,39), [2] = 1},
        { [1] = Vec2(94,38), [2] = 1},
        { [1] = Vec2(94,38), [2] = 1},
        { [1] = Vec2(91,38), [2] = 1},
        { [1] = Vec2(91,38), [2] = 1},
        { [1] = Vec2(91,38), [2] = 1},
        { [1] = Vec2(91,38), [2] = 1},
        { [1] = Vec2(90,38), [2] = 1},
        { [1] = Vec2(90,38), [2] = 1},
        { [1] = Vec2(89,38), [2] = 1},
        { [1] = Vec2(89,38), [2] = 1},
        { [1] = Vec2(87,38), [2] = 1},
        { [1] = Vec2(87,38), [2] = 1},
        { [1] = Vec2(87,38), [2] = 1},
        { [1] = Vec2(87,38), [2] = 1},
        { [1] = Vec2(87,38), [2] = 1},
        { [1] = Vec2(87,38), [2] = 1},
        { [1] = Vec2(85,38), [2] = 1},
        { [1] = Vec2(85,38), [2] = 1},
        { [1] = Vec2(85,38), [2] = 1},
        { [1] = Vec2(85,38), [2] = 1},
        { [1] = Vec2(85,38), [2] = 1},
        { [1] = Vec2(85,38), [2] = 1},
        { [1] = Vec2(84,38), [2] = 1},
        { [1] = Vec2(84,38), [2] = 1},
        { [1] = Vec2(83,38), [2] = 1},
        { [1] = Vec2(83,38), [2] = 1},
        { [1] = Vec2(82,38), [2] = 1},
        { [1] = Vec2(82,38), [2] = 1},
        { [1] = Vec2(82,38), [2] = 1},
        { [1] = Vec2(82,38), [2] = 1},
        { [1] = Vec2(80,38), [2] = 1},
        { [1] = Vec2(80,38), [2] = 1},
        { [1] = Vec2(80,39), [2] = 1},
        { [1] = Vec2(80,39), [2] = 1},
        { [1] = Vec2(80,39), [2] = 1},
        { [1] = Vec2(80,39), [2] = 1},
        { [1] = Vec2(79,39), [2] = 1},
        { [1] = Vec2(79,39), [2] = 1},
        { [1] = Vec2(79,39), [2] = 1},
        { [1] = Vec2(79,39), [2] = 1},
        { [1] = Vec2(78,39), [2] = 1},
        { [1] = Vec2(78,39), [2] = 1},
        { [1] = Vec2(78,39), [2] = 1},
        { [1] = Vec2(78,39), [2] = 1},
        { [1] = Vec2(77,39), [2] = 1},
        { [1] = Vec2(77,39), [2] = 1},
        { [1] = Vec2(77,39), [2] = 1},
        { [1] = Vec2(77,39), [2] = 1},
        { [1] = Vec2(76,39), [2] = 1},
        { [1] = Vec2(76,39), [2] = 1},
        { [1] = Vec2(75,39), [2] = 1},
        { [1] = Vec2(75,39), [2] = 1},
        { [1] = Vec2(75,39), [2] = 1},
        { [1] = Vec2(75,39), [2] = 1},
        { [1] = Vec2(73,39), [2] = 1},
        { [1] = Vec2(73,39), [2] = 1},
        { [1] = Vec2(73,39), [2] = 1},
        { [1] = Vec2(73,39), [2] = 1},
        { [1] = Vec2(73,39), [2] = 1},
        { [1] = Vec2(73,39), [2] = 1},
        { [1] = Vec2(72,39), [2] = 1},
        { [1] = Vec2(72,39), [2] = 1},
        { [1] = Vec2(72,39), [2] = 1},
        { [1] = Vec2(72,39), [2] = 1},
        { [1] = Vec2(71,39), [2] = 1},
        { [1] = Vec2(71,39), [2] = 1},
        { [1] = Vec2(71,39), [2] = 1},
        { [1] = Vec2(71,39), [2] = 1},
        { [1] = Vec2(70,40), [2] = 1},
        { [1] = Vec2(70,40), [2] = 1},
        { [1] = Vec2(70,40), [2] = 1},
        { [1] = Vec2(70,40), [2] = 1},
        { [1] = Vec2(69,40), [2] = 1},
        { [1] = Vec2(69,40), [2] = 1},
        { [1] = Vec2(69,40), [2] = 1},
        { [1] = Vec2(69,40), [2] = 1},
        { [1] = Vec2(68,40), [2] = 1},
        { [1] = Vec2(68,40), [2] = 1},
        { [1] = Vec2(67,40), [2] = 1},
        { [1] = Vec2(67,40), [2] = 1},
        { [1] = Vec2(67,40), [2] = 1},
        { [1] = Vec2(67,40), [2] = 1},
        { [1] = Vec2(66,40), [2] = 1},
        { [1] = Vec2(66,40), [2] = 1},
        { [1] = Vec2(66,40), [2] = 1},
        { [1] = Vec2(66,40), [2] = 1},
        { [1] = Vec2(65,40), [2] = 1},
        { [1] = Vec2(65,40), [2] = 1},
        { [1] = Vec2(65,40), [2] = 1},
        { [1] = Vec2(65,40), [2] = 1},
        { [1] = Vec2(65,40), [2] = 1},
        { [1] = Vec2(65,40), [2] = 1},
        { [1] = Vec2(64,40), [2] = 1},
        { [1] = Vec2(64,40), [2] = 1},
        { [1] = Vec2(64,40), [2] = 1},
        { [1] = Vec2(64,40), [2] = 1},
        { [1] = Vec2(64,40), [2] = 1},
        { [1] = Vec2(64,40), [2] = 1},
        { [1] = Vec2(64,41), [2] = 1},
        { [1] = Vec2(64,41), [2] = 1},
        { [1] = Vec2(64,41), [2] = 1},
        { [1] = Vec2(64,41), [2] = 1},
        { [1] = Vec2(64,41), [2] = 1},
        { [1] = Vec2(64,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(63,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(62,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(61,41), [2] = 1},
        { [1] = Vec2(60,41), [2] = 1},
        { [1] = Vec2(60,41), [2] = 1},
        { [1] = Vec2(60,41), [2] = 1},
        { [1] = Vec2(60,41), [2] = 1},
        { [1] = Vec2(60,41), [2] = 1},
        { [1] = Vec2(60,41), [2] = 1},
        { [1] = Vec2(60,42), [2] = 1},
        { [1] = Vec2(60,42), [2] = 1},
        { [1] = Vec2(60,42), [2] = 1},
        { [1] = Vec2(60,42), [2] = 1},
        { [1] = Vec2(60,43), [2] = 1},
        { [1] = Vec2(60,43), [2] = 1},
        { [1] = Vec2(60,44), [2] = 1},
        { [1] = Vec2(60,44), [2] = 1},
        { [1] = Vec2(60,44), [2] = 1},
        { [1] = Vec2(60,44), [2] = 1},
        { [1] = Vec2(60,44), [2] = 1},
        { [1] = Vec2(60,44), [2] = 1},
        { [1] = Vec2(59,45), [2] = 1},
        { [1] = Vec2(59,45), [2] = 1},
        { [1] = Vec2(59,47), [2] = 1},
        { [1] = Vec2(59,47), [2] = 1},
        { [1] = Vec2(59,47), [2] = 1},
        { [1] = Vec2(59,47), [2] = 1},
        { [1] = Vec2(59,48), [2] = 1},
        { [1] = Vec2(59,48), [2] = 1},
        { [1] = Vec2(59,48), [2] = 1},
        { [1] = Vec2(59,48), [2] = 1},
        { [1] = Vec2(59,48), [2] = 1},
        { [1] = Vec2(59,48), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,50), [2] = 1},
        { [1] = Vec2(59,51), [2] = 1},
        { [1] = Vec2(59,51), [2] = 1},
        { [1] = Vec2(59,51), [2] = 1},
        { [1] = Vec2(59,51), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(71,70), [2] = 0},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,70), [2] = 1},
        { [1] = Vec2(71,69), [2] = 1},
        { [1] = Vec2(71,69), [2] = 1},
        { [1] = Vec2(71,69), [2] = 1},
        { [1] = Vec2(71,69), [2] = 1},
        { [1] = Vec2(70,68), [2] = 1},
        { [1] = Vec2(70,68), [2] = 1},
        { [1] = Vec2(70,66), [2] = 1},
        { [1] = Vec2(70,66), [2] = 1},
        { [1] = Vec2(70,65), [2] = 1},
        { [1] = Vec2(70,65), [2] = 1},
        { [1] = Vec2(71,63), [2] = 1},
        { [1] = Vec2(71,63), [2] = 1},
        { [1] = Vec2(71,62), [2] = 1},
        { [1] = Vec2(71,62), [2] = 1},
        { [1] = Vec2(71,61), [2] = 1},
        { [1] = Vec2(71,61), [2] = 1},
        { [1] = Vec2(71,60), [2] = 1},
        { [1] = Vec2(71,60), [2] = 1},
        { [1] = Vec2(70,59), [2] = 1},
        { [1] = Vec2(70,59), [2] = 1},
        { [1] = Vec2(70,57), [2] = 1},
        { [1] = Vec2(70,57), [2] = 1},
        { [1] = Vec2(70,53), [2] = 1},
        { [1] = Vec2(70,53), [2] = 1},
        { [1] = Vec2(70,52), [2] = 1},
        { [1] = Vec2(70,52), [2] = 1},
        { [1] = Vec2(70,51), [2] = 1},
        { [1] = Vec2(70,51), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,50), [2] = 1},
        { [1] = Vec2(70,49), [2] = 1},
        { [1] = Vec2(70,49), [2] = 1},
        { [1] = Vec2(70,48), [2] = 1},
        { [1] = Vec2(70,48), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = Vec2(70,47), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(84,72), [2] = 0},
        { [1] = Vec2(84,72), [2] = 1},
        { [1] = Vec2(84,72), [2] = 1},
        { [1] = Vec2(84,72), [2] = 1},
        { [1] = Vec2(84,72), [2] = 1},
        { [1] = Vec2(84,72), [2] = 1},
        { [1] = Vec2(84,72), [2] = 1},
        { [1] = Vec2(84,71), [2] = 1},
        { [1] = Vec2(84,71), [2] = 1},
        { [1] = Vec2(84,69), [2] = 1},
        { [1] = Vec2(84,69), [2] = 1},
        { [1] = Vec2(84,67), [2] = 1},
        { [1] = Vec2(84,67), [2] = 1},
        { [1] = Vec2(84,67), [2] = 1},
        { [1] = Vec2(84,67), [2] = 1},
        { [1] = Vec2(84,64), [2] = 1},
        { [1] = Vec2(84,64), [2] = 1},
        { [1] = Vec2(84,64), [2] = 1},
        { [1] = Vec2(84,64), [2] = 1},
        { [1] = Vec2(84,64), [2] = 1},
        { [1] = Vec2(84,64), [2] = 1},
        { [1] = Vec2(84,63), [2] = 1},
        { [1] = Vec2(84,63), [2] = 1},
        { [1] = Vec2(84,62), [2] = 1},
        { [1] = Vec2(84,62), [2] = 1},
        { [1] = Vec2(84,60), [2] = 1},
        { [1] = Vec2(84,60), [2] = 1},
        { [1] = Vec2(84,60), [2] = 1},
        { [1] = Vec2(84,60), [2] = 1},
        { [1] = Vec2(84,55), [2] = 1},
        { [1] = Vec2(84,55), [2] = 1},
        { [1] = Vec2(84,55), [2] = 1},
        { [1] = Vec2(84,55), [2] = 1},
        { [1] = Vec2(84,54), [2] = 1},
        { [1] = Vec2(84,54), [2] = 1},
        { [1] = Vec2(84,53), [2] = 1},
        { [1] = Vec2(84,53), [2] = 1},
        { [1] = Vec2(84,53), [2] = 1},
        { [1] = Vec2(84,53), [2] = 1},
        { [1] = Vec2(84,53), [2] = 1},
        { [1] = Vec2(84,53), [2] = 1},
        { [1] = Vec2(84,52), [2] = 1},
        { [1] = Vec2(84,52), [2] = 1},
        { [1] = Vec2(84,51), [2] = 1},
        { [1] = Vec2(84,51), [2] = 1},
        { [1] = Vec2(85,51), [2] = 1},
        { [1] = Vec2(85,51), [2] = 1},
        { [1] = Vec2(85,50), [2] = 1},
        { [1] = Vec2(85,50), [2] = 1},
        { [1] = Vec2(85,49), [2] = 1},
        { [1] = Vec2(85,49), [2] = 1},
        { [1] = Vec2(85,49), [2] = 1},
        { [1] = Vec2(85,49), [2] = 1},
        { [1] = Vec2(85,49), [2] = 1},
        { [1] = Vec2(85,49), [2] = 1},
        { [1] = Vec2(85,48), [2] = 1},
        { [1] = Vec2(85,48), [2] = 1},
        { [1] = Vec2(85,48), [2] = 1},
        { [1] = Vec2(85,48), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = Vec2(85,47), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(114,86), [2] = 0},
        { [1] = Vec2(114,86), [2] = 1},
        { [1] = Vec2(114,86), [2] = 1},
        { [1] = Vec2(114,84), [2] = 1},
        { [1] = Vec2(114,84), [2] = 1},
        { [1] = Vec2(114,82), [2] = 1},
        { [1] = Vec2(114,82), [2] = 1},
        { [1] = Vec2(115,77), [2] = 1},
        { [1] = Vec2(115,77), [2] = 1},
        { [1] = Vec2(115,76), [2] = 1},
        { [1] = Vec2(115,76), [2] = 1},
        { [1] = Vec2(115,73), [2] = 1},
        { [1] = Vec2(115,73), [2] = 1},
        { [1] = Vec2(115,70), [2] = 1},
        { [1] = Vec2(115,70), [2] = 1},
        { [1] = Vec2(115,68), [2] = 1},
        { [1] = Vec2(115,68), [2] = 1},
        { [1] = Vec2(115,66), [2] = 1},
        { [1] = Vec2(115,66), [2] = 1},
        { [1] = Vec2(115,65), [2] = 1},
        { [1] = Vec2(115,65), [2] = 1},
        { [1] = Vec2(115,62), [2] = 1},
        { [1] = Vec2(115,62), [2] = 1},
        { [1] = Vec2(115,61), [2] = 1},
        { [1] = Vec2(115,61), [2] = 1},
        { [1] = Vec2(115,60), [2] = 1},
        { [1] = Vec2(115,60), [2] = 1},
        { [1] = Vec2(115,59), [2] = 1},
        { [1] = Vec2(115,59), [2] = 1},
        { [1] = Vec2(115,58), [2] = 1},
        { [1] = Vec2(115,58), [2] = 1},
        { [1] = Vec2(115,57), [2] = 1},
        { [1] = Vec2(115,57), [2] = 1},
        { [1] = Vec2(115,57), [2] = 1},
        { [1] = Vec2(115,57), [2] = 1},
        { [1] = Vec2(115,54), [2] = 1},
        { [1] = Vec2(115,54), [2] = 1},
        { [1] = Vec2(115,53), [2] = 1},
        { [1] = Vec2(115,53), [2] = 1},
        { [1] = Vec2(115,51), [2] = 1},
        { [1] = Vec2(115,51), [2] = 1},
        { [1] = Vec2(115,50), [2] = 1},
        { [1] = Vec2(115,50), [2] = 1},
        { [1] = Vec2(115,50), [2] = 1},
        { [1] = Vec2(115,50), [2] = 1},
        { [1] = Vec2(115,48), [2] = 1},
        { [1] = Vec2(115,48), [2] = 1},
        { [1] = Vec2(115,47), [2] = 1},
        { [1] = Vec2(115,47), [2] = 1},
        { [1] = Vec2(115,47), [2] = 1},
        { [1] = Vec2(115,47), [2] = 1},
        { [1] = Vec2(115,46), [2] = 1},
        { [1] = Vec2(115,46), [2] = 1},
        { [1] = Vec2(115,45), [2] = 1},
        { [1] = Vec2(115,45), [2] = 1},
        { [1] = Vec2(116,44), [2] = 1},
        { [1] = Vec2(116,44), [2] = 1},
        { [1] = Vec2(116,43), [2] = 1},
        { [1] = Vec2(116,43), [2] = 1},
        { [1] = Vec2(116,43), [2] = 1},
        { [1] = Vec2(116,43), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(116,42), [2] = 1},
        { [1] = Vec2(115,41), [2] = 1},
        { [1] = Vec2(115,41), [2] = 1},
        { [1] = Vec2(115,41), [2] = 1},
        { [1] = Vec2(115,41), [2] = 1},
        { [1] = Vec2(115,41), [2] = 1},
        { [1] = Vec2(115,41), [2] = 1},
        { [1] = Vec2(115,40), [2] = 1},
        { [1] = Vec2(115,40), [2] = 1},
        { [1] = Vec2(115,40), [2] = 1},
        { [1] = Vec2(115,40), [2] = 1},
        { [1] = Vec2(115,40), [2] = 1},
        { [1] = Vec2(115,40), [2] = 1},
        { [1] = Vec2(115,39), [2] = 1},
        { [1] = Vec2(115,39), [2] = 1},
        { [1] = Vec2(115,39), [2] = 1},
        { [1] = Vec2(115,39), [2] = 1},
        { [1] = Vec2(115,38), [2] = 1},
        { [1] = Vec2(115,38), [2] = 1},
        { [1] = Vec2(115,38), [2] = 1},
        { [1] = Vec2(115,38), [2] = 1},
        { [1] = Vec2(118,35), [2] = 1},
        { [1] = Vec2(118,35), [2] = 1},
        { [1] = Vec2(118,35), [2] = 1},
        { [1] = Vec2(118,35), [2] = 1},
        { [1] = Vec2(118,34), [2] = 1},
        { [1] = Vec2(118,34), [2] = 1},
        { [1] = Vec2(118,34), [2] = 1},
        { [1] = Vec2(118,34), [2] = 1},
        { [1] = Vec2(118,34), [2] = 1},
        { [1] = Vec2(118,34), [2] = 1},
        { [1] = Vec2(117,34), [2] = 1},
        { [1] = Vec2(117,34), [2] = 1},
        { [1] = Vec2(117,34), [2] = 1},
        { [1] = Vec2(117,34), [2] = 1},
        { [1] = Vec2(117,35), [2] = 1},
        { [1] = Vec2(117,35), [2] = 1},
        { [1] = Vec2(116,36), [2] = 1},
        { [1] = Vec2(116,36), [2] = 1},
        { [1] = Vec2(115,36), [2] = 1},
        { [1] = Vec2(115,36), [2] = 1},
        { [1] = Vec2(115,37), [2] = 1},
        { [1] = Vec2(115,37), [2] = 1},
        { [1] = Vec2(114,37), [2] = 1},
        { [1] = Vec2(114,37), [2] = 1},
        { [1] = nil, [2] = 2}
    },
    [122150789929023] = {
        { [1] = Vec2(29,44), [2] = 0},
        { [1] = Vec2(29,44), [2] = 1},
        { [1] = Vec2(29,44), [2] = 1},
        { [1] = Vec2(30,44), [2] = 1},
        { [1] = Vec2(30,44), [2] = 1},
        { [1] = Vec2(31,44), [2] = 1},
        { [1] = Vec2(31,44), [2] = 1},
        { [1] = Vec2(32,44), [2] = 1},
        { [1] = Vec2(32,44), [2] = 1},
        { [1] = Vec2(34,44), [2] = 1},
        { [1] = Vec2(34,44), [2] = 1},
        { [1] = Vec2(35,45), [2] = 1},
        { [1] = Vec2(35,45), [2] = 1},
        { [1] = Vec2(36,45), [2] = 1},
        { [1] = Vec2(36,45), [2] = 1},
        { [1] = Vec2(39,45), [2] = 1},
        { [1] = Vec2(39,45), [2] = 1},
        { [1] = Vec2(40,46), [2] = 1},
        { [1] = Vec2(40,46), [2] = 1},
        { [1] = Vec2(41,46), [2] = 1},
        { [1] = Vec2(41,46), [2] = 1},
        { [1] = Vec2(43,46), [2] = 1},
        { [1] = Vec2(43,46), [2] = 1},
        { [1] = Vec2(45,46), [2] = 1},
        { [1] = Vec2(45,46), [2] = 1},
        { [1] = Vec2(47,46), [2] = 1},
        { [1] = Vec2(47,46), [2] = 1},
        { [1] = Vec2(49,46), [2] = 1},
        { [1] = Vec2(49,46), [2] = 1},
        { [1] = Vec2(49,46), [2] = 1},
        { [1] = Vec2(49,46), [2] = 1},
        { [1] = Vec2(50,46), [2] = 1},
        { [1] = Vec2(50,46), [2] = 1},
        { [1] = Vec2(51,46), [2] = 1},
        { [1] = Vec2(51,46), [2] = 1},
        { [1] = Vec2(52,46), [2] = 1},
        { [1] = Vec2(52,46), [2] = 1},
        { [1] = Vec2(52,46), [2] = 1},
        { [1] = Vec2(52,46), [2] = 1},
        { [1] = Vec2(52,45), [2] = 1},
        { [1] = Vec2(52,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(53,45), [2] = 1},
        { [1] = Vec2(52,45), [2] = 1},
        { [1] = Vec2(52,45), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(56,46), [2] = 0},
        { [1] = Vec2(56,45), [2] = 1},
        { [1] = Vec2(56,45), [2] = 1},
        { [1] = Vec2(56,46), [2] = 1},
        { [1] = Vec2(56,46), [2] = 1},
        { [1] = Vec2(57,46), [2] = 1},
        { [1] = Vec2(57,46), [2] = 1},
        { [1] = Vec2(58,46), [2] = 1},
        { [1] = Vec2(58,46), [2] = 1},
        { [1] = Vec2(61,45), [2] = 1},
        { [1] = Vec2(61,45), [2] = 1},
        { [1] = Vec2(61,45), [2] = 1},
        { [1] = Vec2(61,45), [2] = 1},
        { [1] = Vec2(63,45), [2] = 1},
        { [1] = Vec2(63,45), [2] = 1},
        { [1] = Vec2(63,45), [2] = 1},
        { [1] = Vec2(63,45), [2] = 1},
        { [1] = Vec2(64,45), [2] = 1},
        { [1] = Vec2(64,45), [2] = 1},
        { [1] = Vec2(64,45), [2] = 1},
        { [1] = Vec2(64,45), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(66,44), [2] = 1},
        { [1] = Vec2(67,44), [2] = 1},
        { [1] = Vec2(67,44), [2] = 1},
        { [1] = Vec2(68,44), [2] = 1},
        { [1] = Vec2(68,44), [2] = 1},
        { [1] = Vec2(69,44), [2] = 1},
        { [1] = Vec2(69,44), [2] = 1},
        { [1] = Vec2(69,44), [2] = 1},
        { [1] = Vec2(69,44), [2] = 1},
        { [1] = Vec2(69,44), [2] = 1},
        { [1] = Vec2(69,44), [2] = 1},
        { [1] = Vec2(71,44), [2] = 1},
        { [1] = Vec2(71,44), [2] = 1},
        { [1] = Vec2(71,44), [2] = 1},
        { [1] = Vec2(71,44), [2] = 1},
        { [1] = Vec2(72,44), [2] = 1},
        { [1] = Vec2(72,44), [2] = 1},
        { [1] = Vec2(73,44), [2] = 1},
        { [1] = Vec2(73,44), [2] = 1},
        { [1] = Vec2(73,44), [2] = 1},
        { [1] = Vec2(73,44), [2] = 1},
        { [1] = Vec2(74,44), [2] = 1},
        { [1] = Vec2(74,44), [2] = 1},
        { [1] = Vec2(74,44), [2] = 1},
        { [1] = Vec2(74,44), [2] = 1},
        { [1] = Vec2(75,44), [2] = 1},
        { [1] = Vec2(75,44), [2] = 1},
        { [1] = Vec2(76,44), [2] = 1},
        { [1] = Vec2(76,44), [2] = 1},
        { [1] = Vec2(76,43), [2] = 1},
        { [1] = Vec2(76,43), [2] = 1},
        { [1] = Vec2(78,43), [2] = 1},
        { [1] = Vec2(78,43), [2] = 1},
        { [1] = Vec2(78,44), [2] = 1},
        { [1] = Vec2(78,44), [2] = 1},
        { [1] = Vec2(79,43), [2] = 1},
        { [1] = Vec2(79,43), [2] = 1},
        { [1] = Vec2(80,43), [2] = 1},
        { [1] = Vec2(80,43), [2] = 1},
        { [1] = Vec2(81,43), [2] = 1},
        { [1] = Vec2(81,43), [2] = 1},
        { [1] = Vec2(81,43), [2] = 1},
        { [1] = Vec2(81,43), [2] = 1},
        { [1] = Vec2(82,43), [2] = 1},
        { [1] = Vec2(82,43), [2] = 1},
        { [1] = Vec2(83,43), [2] = 1},
        { [1] = Vec2(83,43), [2] = 1},
        { [1] = Vec2(84,43), [2] = 1},
        { [1] = Vec2(84,43), [2] = 1},
        { [1] = Vec2(85,43), [2] = 1},
        { [1] = Vec2(85,43), [2] = 1},
        { [1] = Vec2(86,43), [2] = 1},
        { [1] = Vec2(86,43), [2] = 1},
        { [1] = Vec2(86,43), [2] = 1},
        { [1] = Vec2(86,43), [2] = 1},
        { [1] = Vec2(87,43), [2] = 1},
        { [1] = Vec2(87,43), [2] = 1},
        { [1] = Vec2(89,43), [2] = 1},
        { [1] = Vec2(89,43), [2] = 1},
        { [1] = Vec2(89,43), [2] = 1},
        { [1] = Vec2(89,43), [2] = 1},
        { [1] = Vec2(91,43), [2] = 1},
        { [1] = Vec2(91,43), [2] = 1},
        { [1] = Vec2(92,43), [2] = 1},
        { [1] = Vec2(92,43), [2] = 1},
        { [1] = Vec2(93,43), [2] = 1},
        { [1] = Vec2(93,43), [2] = 1},
        { [1] = Vec2(93,43), [2] = 1},
        { [1] = Vec2(93,43), [2] = 1},
        { [1] = Vec2(95,43), [2] = 1},
        { [1] = Vec2(95,43), [2] = 1},
        { [1] = Vec2(97,44), [2] = 1},
        { [1] = Vec2(97,44), [2] = 1},
        { [1] = Vec2(97,44), [2] = 1},
        { [1] = Vec2(97,44), [2] = 1},
        { [1] = Vec2(98,44), [2] = 1},
        { [1] = Vec2(98,44), [2] = 1},
        { [1] = Vec2(98,44), [2] = 1},
        { [1] = Vec2(98,44), [2] = 1},
        { [1] = Vec2(99,44), [2] = 1},
        { [1] = Vec2(99,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(100,44), [2] = 1},
        { [1] = Vec2(101,44), [2] = 1},
        { [1] = Vec2(101,44), [2] = 1},
        { [1] = Vec2(102,44), [2] = 1},
        { [1] = Vec2(102,44), [2] = 1},
        { [1] = Vec2(104,44), [2] = 1},
        { [1] = Vec2(104,44), [2] = 1},
        { [1] = Vec2(105,44), [2] = 1},
        { [1] = Vec2(105,44), [2] = 1},
        { [1] = Vec2(105,44), [2] = 1},
        { [1] = Vec2(105,44), [2] = 1},
        { [1] = Vec2(106,44), [2] = 1},
        { [1] = Vec2(106,44), [2] = 1},
        { [1] = Vec2(108,44), [2] = 1},
        { [1] = Vec2(108,44), [2] = 1},
        { [1] = Vec2(108,44), [2] = 1},
        { [1] = Vec2(108,44), [2] = 1},
        { [1] = Vec2(109,44), [2] = 1},
        { [1] = Vec2(109,44), [2] = 1},
        { [1] = Vec2(109,44), [2] = 1},
        { [1] = Vec2(109,44), [2] = 1},
        { [1] = Vec2(110,44), [2] = 1},
        { [1] = Vec2(110,44), [2] = 1},
        { [1] = Vec2(111,44), [2] = 1},
        { [1] = Vec2(111,44), [2] = 1},
        { [1] = Vec2(112,44), [2] = 1},
        { [1] = Vec2(112,44), [2] = 1},
        { [1] = Vec2(112,44), [2] = 1},
        { [1] = Vec2(112,44), [2] = 1},
        { [1] = Vec2(113,44), [2] = 1},
        { [1] = Vec2(113,44), [2] = 1},
        { [1] = Vec2(114,44), [2] = 1},
        { [1] = Vec2(114,44), [2] = 1},
        { [1] = Vec2(114,44), [2] = 1},
        { [1] = Vec2(114,44), [2] = 1},
        { [1] = Vec2(115,44), [2] = 1},
        { [1] = Vec2(115,44), [2] = 1},
        { [1] = Vec2(115,44), [2] = 1},
        { [1] = Vec2(115,44), [2] = 1},
        { [1] = Vec2(116,44), [2] = 1},
        { [1] = Vec2(116,44), [2] = 1},
        { [1] = Vec2(116,44), [2] = 1},
        { [1] = Vec2(116,44), [2] = 1},
        { [1] = Vec2(117,44), [2] = 1},
        { [1] = Vec2(117,44), [2] = 1},
        { [1] = Vec2(117,44), [2] = 1},
        { [1] = Vec2(117,44), [2] = 1},
        { [1] = Vec2(118,44), [2] = 1},
        { [1] = Vec2(118,44), [2] = 1},
        { [1] = Vec2(118,44), [2] = 1},
        { [1] = Vec2(118,44), [2] = 1},
        { [1] = Vec2(120,44), [2] = 1},
        { [1] = Vec2(120,44), [2] = 1},
        { [1] = Vec2(120,44), [2] = 1},
        { [1] = Vec2(120,44), [2] = 1},
        { [1] = Vec2(120,44), [2] = 1},
        { [1] = Vec2(120,44), [2] = 1},
        { [1] = Vec2(121,44), [2] = 1},
        { [1] = Vec2(121,44), [2] = 1},
        { [1] = Vec2(121,44), [2] = 1},
        { [1] = Vec2(121,44), [2] = 1},
        { [1] = Vec2(122,45), [2] = 1},
        { [1] = Vec2(122,45), [2] = 1},
        { [1] = Vec2(123,45), [2] = 1},
        { [1] = Vec2(123,45), [2] = 1},
        { [1] = Vec2(123,45), [2] = 1},
        { [1] = Vec2(123,45), [2] = 1},
        { [1] = Vec2(124,45), [2] = 1},
        { [1] = Vec2(124,45), [2] = 1},
        { [1] = Vec2(124,45), [2] = 1},
        { [1] = Vec2(124,45), [2] = 1},
        { [1] = Vec2(125,45), [2] = 1},
        { [1] = Vec2(125,45), [2] = 1},
        { [1] = Vec2(125,45), [2] = 1},
        { [1] = Vec2(125,45), [2] = 1},
        { [1] = Vec2(126,45), [2] = 1},
        { [1] = Vec2(126,45), [2] = 1},
        { [1] = Vec2(126,45), [2] = 1},
        { [1] = Vec2(126,45), [2] = 1},
        { [1] = Vec2(127,45), [2] = 1},
        { [1] = Vec2(127,45), [2] = 1},
        { [1] = Vec2(127,45), [2] = 1},
        { [1] = Vec2(127,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(128,45), [2] = 1},
        { [1] = Vec2(129,45), [2] = 1},
        { [1] = Vec2(129,45), [2] = 1},
        { [1] = Vec2(129,45), [2] = 1},
        { [1] = Vec2(129,45), [2] = 1},
        { [1] = Vec2(129,45), [2] = 1},
        { [1] = Vec2(129,45), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(130,46), [2] = 1},
        { [1] = Vec2(131,47), [2] = 1},
        { [1] = Vec2(131,47), [2] = 1},
        { [1] = Vec2(131,47), [2] = 1},
        { [1] = Vec2(131,47), [2] = 1},
        { [1] = Vec2(131,47), [2] = 1},
        { [1] = Vec2(131,47), [2] = 1},
        { [1] = Vec2(131,48), [2] = 1},
        { [1] = Vec2(131,48), [2] = 1},
        { [1] = Vec2(131,48), [2] = 1},
        { [1] = Vec2(131,48), [2] = 1},
        { [1] = Vec2(131,48), [2] = 1},
        { [1] = Vec2(131,48), [2] = 1},
        { [1] = Vec2(131,49), [2] = 1},
        { [1] = Vec2(131,49), [2] = 1},
        { [1] = Vec2(131,49), [2] = 1},
        { [1] = Vec2(131,49), [2] = 1},
        { [1] = Vec2(131,49), [2] = 1},
        { [1] = Vec2(131,49), [2] = 1},
        { [1] = Vec2(132,50), [2] = 1},
        { [1] = Vec2(132,50), [2] = 1},
        { [1] = Vec2(132,51), [2] = 1},
        { [1] = Vec2(132,51), [2] = 1},
        { [1] = Vec2(132,51), [2] = 1},
        { [1] = Vec2(132,51), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(132,52), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(133,53), [2] = 1},
        { [1] = Vec2(134,54), [2] = 1},
        { [1] = Vec2(134,54), [2] = 1},
        { [1] = Vec2(134,54), [2] = 1},
        { [1] = Vec2(134,54), [2] = 1},
        { [1] = Vec2(133,54), [2] = 1},
        { [1] = Vec2(133,54), [2] = 1},
        { [1] = Vec2(133,54), [2] = 1},
        { [1] = Vec2(133,54), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,55), [2] = 1},
        { [1] = Vec2(134,56), [2] = 1},
        { [1] = Vec2(134,56), [2] = 1},
        { [1] = Vec2(134,56), [2] = 1},
        { [1] = Vec2(134,56), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,57), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,58), [2] = 1},
        { [1] = Vec2(134,59), [2] = 1},
        { [1] = Vec2(134,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,59), [2] = 1},
        { [1] = Vec2(135,60), [2] = 1},
        { [1] = Vec2(135,60), [2] = 1},
        { [1] = Vec2(135,60), [2] = 1},
        { [1] = Vec2(135,60), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(58,72), [2] = 0},
        { [1] = Vec2(58,73), [2] = 1},
        { [1] = Vec2(58,73), [2] = 1},
        { [1] = Vec2(58,73), [2] = 1},
        { [1] = Vec2(58,73), [2] = 1},
        { [1] = Vec2(58,72), [2] = 1},
        { [1] = Vec2(58,72), [2] = 1},
        { [1] = Vec2(58,70), [2] = 1},
        { [1] = Vec2(58,70), [2] = 1},
        { [1] = Vec2(58,70), [2] = 1},
        { [1] = Vec2(58,70), [2] = 1},
        { [1] = Vec2(58,68), [2] = 1},
        { [1] = Vec2(58,68), [2] = 1},
        { [1] = Vec2(58,66), [2] = 1},
        { [1] = Vec2(58,66), [2] = 1},
        { [1] = Vec2(58,64), [2] = 1},
        { [1] = Vec2(58,64), [2] = 1},
        { [1] = Vec2(58,63), [2] = 1},
        { [1] = Vec2(58,63), [2] = 1},
        { [1] = Vec2(58,61), [2] = 1},
        { [1] = Vec2(58,61), [2] = 1},
        { [1] = Vec2(59,59), [2] = 1},
        { [1] = Vec2(59,59), [2] = 1},
        { [1] = Vec2(59,56), [2] = 1},
        { [1] = Vec2(59,56), [2] = 1},
        { [1] = Vec2(59,55), [2] = 1},
        { [1] = Vec2(59,55), [2] = 1},
        { [1] = Vec2(59,52), [2] = 1},
        { [1] = Vec2(59,52), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,49), [2] = 1},
        { [1] = Vec2(59,46), [2] = 1},
        { [1] = Vec2(59,46), [2] = 1},
        { [1] = Vec2(59,46), [2] = 1},
        { [1] = Vec2(59,46), [2] = 1},
        { [1] = Vec2(59,42), [2] = 1},
        { [1] = Vec2(59,42), [2] = 1},
        { [1] = Vec2(59,39), [2] = 1},
        { [1] = Vec2(59,39), [2] = 1},
        { [1] = Vec2(59,39), [2] = 1},
        { [1] = Vec2(59,39), [2] = 1},
        { [1] = Vec2(60,37), [2] = 1},
        { [1] = Vec2(60,37), [2] = 1},
        { [1] = Vec2(60,37), [2] = 1},
        { [1] = Vec2(60,37), [2] = 1},
        { [1] = Vec2(59,36), [2] = 1},
        { [1] = Vec2(59,36), [2] = 1},
        { [1] = Vec2(60,34), [2] = 1},
        { [1] = Vec2(60,34), [2] = 1},
        { [1] = Vec2(60,33), [2] = 1},
        { [1] = Vec2(60,33), [2] = 1},
        { [1] = Vec2(60,32), [2] = 1},
        { [1] = Vec2(60,32), [2] = 1},
        { [1] = Vec2(60,32), [2] = 1},
        { [1] = Vec2(60,32), [2] = 1},
        { [1] = Vec2(60,32), [2] = 1},
        { [1] = Vec2(60,32), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(31,104), [2] = 0},
        { [1] = Vec2(31,104), [2] = 1},
        { [1] = Vec2(31,104), [2] = 1},
        { [1] = Vec2(31,104), [2] = 1},
        { [1] = Vec2(31,104), [2] = 1},
        { [1] = Vec2(32,104), [2] = 1},
        { [1] = Vec2(32,104), [2] = 1},
        { [1] = Vec2(33,104), [2] = 1},
        { [1] = Vec2(33,104), [2] = 1},
        { [1] = Vec2(33,104), [2] = 1},
        { [1] = Vec2(33,104), [2] = 1},
        { [1] = Vec2(35,104), [2] = 1},
        { [1] = Vec2(35,104), [2] = 1},
        { [1] = Vec2(35,104), [2] = 1},
        { [1] = Vec2(35,104), [2] = 1},
        { [1] = Vec2(36,104), [2] = 1},
        { [1] = Vec2(36,104), [2] = 1},
        { [1] = Vec2(37,104), [2] = 1},
        { [1] = Vec2(37,104), [2] = 1},
        { [1] = Vec2(38,104), [2] = 1},
        { [1] = Vec2(38,104), [2] = 1},
        { [1] = Vec2(39,104), [2] = 1},
        { [1] = Vec2(39,104), [2] = 1},
        { [1] = Vec2(39,104), [2] = 1},
        { [1] = Vec2(39,104), [2] = 1},
        { [1] = Vec2(40,104), [2] = 1},
        { [1] = Vec2(40,104), [2] = 1},
        { [1] = Vec2(41,104), [2] = 1},
        { [1] = Vec2(41,104), [2] = 1},
        { [1] = Vec2(42,104), [2] = 1},
        { [1] = Vec2(42,104), [2] = 1},
        { [1] = Vec2(44,104), [2] = 1},
        { [1] = Vec2(44,104), [2] = 1},
        { [1] = Vec2(46,104), [2] = 1},
        { [1] = Vec2(46,104), [2] = 1},
        { [1] = Vec2(47,104), [2] = 1},
        { [1] = Vec2(47,104), [2] = 1},
        { [1] = Vec2(49,104), [2] = 1},
        { [1] = Vec2(49,104), [2] = 1},
        { [1] = Vec2(51,104), [2] = 1},
        { [1] = Vec2(51,104), [2] = 1},
        { [1] = Vec2(52,104), [2] = 1},
        { [1] = Vec2(52,104), [2] = 1},
        { [1] = Vec2(52,104), [2] = 1},
        { [1] = Vec2(52,104), [2] = 1},
        { [1] = Vec2(53,104), [2] = 1},
        { [1] = Vec2(53,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(54,104), [2] = 1},
        { [1] = Vec2(55,104), [2] = 1},
        { [1] = Vec2(55,104), [2] = 1},
        { [1] = Vec2(55,104), [2] = 1},
        { [1] = Vec2(55,104), [2] = 1},
        { [1] = Vec2(56,104), [2] = 1},
        { [1] = Vec2(56,104), [2] = 1},
        { [1] = Vec2(57,104), [2] = 1},
        { [1] = Vec2(57,104), [2] = 1},
        { [1] = Vec2(57,104), [2] = 1},
        { [1] = Vec2(57,104), [2] = 1},
        { [1] = Vec2(58,104), [2] = 1},
        { [1] = Vec2(58,104), [2] = 1},
        { [1] = Vec2(58,104), [2] = 1},
        { [1] = Vec2(58,104), [2] = 1},
        { [1] = Vec2(58,104), [2] = 1},
        { [1] = Vec2(58,104), [2] = 1},
        { [1] = Vec2(59,104), [2] = 1},
        { [1] = Vec2(59,104), [2] = 1},
        { [1] = Vec2(59,104), [2] = 1},
        { [1] = Vec2(59,104), [2] = 1},
        { [1] = Vec2(59,104), [2] = 1},
        { [1] = Vec2(59,104), [2] = 1},
        { [1] = Vec2(61,104), [2] = 1},
        { [1] = Vec2(61,104), [2] = 1},
        { [1] = Vec2(61,104), [2] = 1},
        { [1] = Vec2(61,104), [2] = 1},
        { [1] = Vec2(62,104), [2] = 1},
        { [1] = Vec2(62,104), [2] = 1},
        { [1] = Vec2(62,104), [2] = 1},
        { [1] = Vec2(62,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(63,104), [2] = 1},
        { [1] = Vec2(64,104), [2] = 1},
        { [1] = Vec2(64,104), [2] = 1},
        { [1] = Vec2(64,104), [2] = 1},
        { [1] = Vec2(64,104), [2] = 1},
        { [1] = Vec2(65,104), [2] = 1},
        { [1] = Vec2(65,104), [2] = 1},
        { [1] = Vec2(65,104), [2] = 1},
        { [1] = Vec2(65,104), [2] = 1},
        { [1] = Vec2(65,104), [2] = 1},
        { [1] = Vec2(65,104), [2] = 1},
        { [1] = Vec2(66,104), [2] = 1},
        { [1] = Vec2(66,104), [2] = 1},
        { [1] = Vec2(66,104), [2] = 1},
        { [1] = Vec2(66,104), [2] = 1},
        { [1] = Vec2(67,104), [2] = 1},
        { [1] = Vec2(67,104), [2] = 1},
        { [1] = Vec2(67,104), [2] = 1},
        { [1] = Vec2(67,104), [2] = 1},
        { [1] = Vec2(68,104), [2] = 1},
        { [1] = Vec2(68,104), [2] = 1},
        { [1] = Vec2(68,104), [2] = 1},
        { [1] = Vec2(68,104), [2] = 1},
        { [1] = Vec2(69,104), [2] = 1},
        { [1] = Vec2(69,104), [2] = 1},
        { [1] = Vec2(69,104), [2] = 1},
        { [1] = Vec2(69,104), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(70,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(71,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(72,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,105), [2] = 1},
        { [1] = Vec2(74,106), [2] = 1},
        { [1] = Vec2(74,106), [2] = 1},
        { [1] = Vec2(74,107), [2] = 1},
        { [1] = Vec2(74,107), [2] = 1},
        { [1] = Vec2(74,107), [2] = 1},
        { [1] = Vec2(74,107), [2] = 1},
        { [1] = Vec2(74,108), [2] = 1},
        { [1] = Vec2(74,108), [2] = 1},
        { [1] = Vec2(74,108), [2] = 1},
        { [1] = Vec2(74,108), [2] = 1},
        { [1] = Vec2(74,109), [2] = 1},
        { [1] = Vec2(74,109), [2] = 1},
        { [1] = Vec2(74,109), [2] = 1},
        { [1] = Vec2(74,109), [2] = 1},
        { [1] = Vec2(74,109), [2] = 1},
        { [1] = Vec2(74,109), [2] = 1},
        { [1] = Vec2(74,110), [2] = 1},
        { [1] = Vec2(74,110), [2] = 1},
        { [1] = Vec2(73,111), [2] = 1},
        { [1] = Vec2(73,111), [2] = 1},
        { [1] = Vec2(73,112), [2] = 1},
        { [1] = Vec2(73,112), [2] = 1},
        { [1] = Vec2(73,112), [2] = 1},
        { [1] = Vec2(73,112), [2] = 1},
        { [1] = Vec2(73,113), [2] = 1},
        { [1] = Vec2(73,113), [2] = 1},
        { [1] = Vec2(73,113), [2] = 1},
        { [1] = Vec2(73,113), [2] = 1},
        { [1] = Vec2(73,113), [2] = 1},
        { [1] = Vec2(73,113), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,116), [2] = 1},
        { [1] = Vec2(73,116), [2] = 1},
        { [1] = Vec2(73,116), [2] = 1},
        { [1] = Vec2(73,116), [2] = 1},
        { [1] = Vec2(73,117), [2] = 1},
        { [1] = Vec2(73,117), [2] = 1},
        { [1] = Vec2(73,117), [2] = 1},
        { [1] = Vec2(73,117), [2] = 1},
        { [1] = Vec2(73,118), [2] = 1},
        { [1] = Vec2(73,118), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,121), [2] = 1},
        { [1] = Vec2(73,121), [2] = 1},
        { [1] = Vec2(73,121), [2] = 1},
        { [1] = Vec2(73,121), [2] = 1},
        { [1] = Vec2(73,122), [2] = 1},
        { [1] = Vec2(73,122), [2] = 1},
        { [1] = Vec2(73,122), [2] = 1},
        { [1] = Vec2(73,122), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,124), [2] = 1},
        { [1] = Vec2(73,124), [2] = 1},
        { [1] = Vec2(73,124), [2] = 1},
        { [1] = Vec2(73,124), [2] = 1},
        { [1] = Vec2(73,125), [2] = 1},
        { [1] = Vec2(73,125), [2] = 1},
        { [1] = Vec2(73,125), [2] = 1},
        { [1] = Vec2(73,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,126), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,125), [2] = 1},
        { [1] = Vec2(72,124), [2] = 1},
        { [1] = Vec2(72,124), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,123), [2] = 1},
        { [1] = Vec2(73,122), [2] = 1},
        { [1] = Vec2(73,122), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,120), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,119), [2] = 1},
        { [1] = Vec2(73,117), [2] = 1},
        { [1] = Vec2(73,117), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,114), [2] = 1},
        { [1] = Vec2(73,112), [2] = 1},
        { [1] = Vec2(73,112), [2] = 1},
        { [1] = Vec2(73,111), [2] = 1},
        { [1] = Vec2(73,111), [2] = 1},
        { [1] = Vec2(73,108), [2] = 1},
        { [1] = Vec2(73,108), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,105), [2] = 1},
        { [1] = Vec2(73,102), [2] = 1},
        { [1] = Vec2(73,102), [2] = 1},
        { [1] = Vec2(73,100), [2] = 1},
        { [1] = Vec2(73,100), [2] = 1},
        { [1] = Vec2(73,100), [2] = 1},
        { [1] = Vec2(73,100), [2] = 1},
        { [1] = Vec2(73,98), [2] = 1},
        { [1] = Vec2(73,98), [2] = 1},
        { [1] = Vec2(73,97), [2] = 1},
        { [1] = Vec2(73,97), [2] = 1},
        { [1] = Vec2(73,96), [2] = 1},
        { [1] = Vec2(73,96), [2] = 1},
        { [1] = Vec2(74,95), [2] = 1},
        { [1] = Vec2(74,95), [2] = 1},
        { [1] = Vec2(74,94), [2] = 1},
        { [1] = Vec2(74,94), [2] = 1},
        { [1] = Vec2(74,94), [2] = 1},
        { [1] = Vec2(74,94), [2] = 1},
        { [1] = Vec2(74,93), [2] = 1},
        { [1] = Vec2(74,93), [2] = 1},
        { [1] = Vec2(74,92), [2] = 1},
        { [1] = Vec2(74,92), [2] = 1},
        { [1] = Vec2(74,92), [2] = 1},
        { [1] = Vec2(74,92), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,91), [2] = 1},
        { [1] = Vec2(74,90), [2] = 1},
        { [1] = Vec2(74,90), [2] = 1},
        { [1] = Vec2(74,89), [2] = 1},
        { [1] = Vec2(74,89), [2] = 1},
        { [1] = Vec2(74,89), [2] = 1},
        { [1] = Vec2(74,89), [2] = 1},
        { [1] = Vec2(74,89), [2] = 1},
        { [1] = Vec2(74,89), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,88), [2] = 1},
        { [1] = Vec2(74,87), [2] = 1},
        { [1] = Vec2(74,87), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,86), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,85), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,84), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,83), [2] = 1},
        { [1] = Vec2(74,82), [2] = 1},
        { [1] = Vec2(74,82), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(45,86), [2] = 0},
        { [1] = Vec2(45,86), [2] = 1},
        { [1] = Vec2(45,86), [2] = 1},
        { [1] = Vec2(45,86), [2] = 1},
        { [1] = Vec2(45,86), [2] = 1},
        { [1] = Vec2(45,87), [2] = 1},
        { [1] = Vec2(45,87), [2] = 1},
        { [1] = Vec2(45,87), [2] = 1},
        { [1] = Vec2(45,87), [2] = 1},
        { [1] = Vec2(45,89), [2] = 1},
        { [1] = Vec2(45,89), [2] = 1},
        { [1] = Vec2(45,90), [2] = 1},
        { [1] = Vec2(45,90), [2] = 1},
        { [1] = Vec2(46,92), [2] = 1},
        { [1] = Vec2(46,92), [2] = 1},
        { [1] = Vec2(46,92), [2] = 1},
        { [1] = Vec2(46,92), [2] = 1},
        { [1] = Vec2(46,93), [2] = 1},
        { [1] = Vec2(46,93), [2] = 1},
        { [1] = Vec2(46,95), [2] = 1},
        { [1] = Vec2(46,95), [2] = 1},
        { [1] = Vec2(45,96), [2] = 1},
        { [1] = Vec2(45,96), [2] = 1},
        { [1] = Vec2(45,97), [2] = 1},
        { [1] = Vec2(45,97), [2] = 1},
        { [1] = Vec2(45,99), [2] = 1},
        { [1] = Vec2(45,99), [2] = 1},
        { [1] = Vec2(45,100), [2] = 1},
        { [1] = Vec2(45,100), [2] = 1},
        { [1] = Vec2(45,101), [2] = 1},
        { [1] = Vec2(45,101), [2] = 1},
        { [1] = Vec2(45,101), [2] = 1},
        { [1] = Vec2(45,101), [2] = 1},
        { [1] = Vec2(45,103), [2] = 1},
        { [1] = Vec2(45,103), [2] = 1},
        { [1] = Vec2(45,104), [2] = 1},
        { [1] = Vec2(45,104), [2] = 1},
        { [1] = Vec2(45,107), [2] = 1},
        { [1] = Vec2(45,107), [2] = 1},
        { [1] = Vec2(45,109), [2] = 1},
        { [1] = Vec2(45,109), [2] = 1},
        { [1] = Vec2(45,109), [2] = 1},
        { [1] = Vec2(45,109), [2] = 1},
        { [1] = Vec2(46,111), [2] = 1},
        { [1] = Vec2(46,111), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,112), [2] = 1},
        { [1] = Vec2(46,113), [2] = 1},
        { [1] = Vec2(46,113), [2] = 1},
        { [1] = Vec2(46,113), [2] = 1},
        { [1] = Vec2(46,113), [2] = 1},
        { [1] = Vec2(46,114), [2] = 1},
        { [1] = Vec2(46,114), [2] = 1},
        { [1] = Vec2(46,114), [2] = 1},
        { [1] = Vec2(46,114), [2] = 1},
        { [1] = Vec2(45,115), [2] = 1},
        { [1] = Vec2(45,115), [2] = 1},
        { [1] = Vec2(45,115), [2] = 1},
        { [1] = Vec2(45,115), [2] = 1},
        { [1] = Vec2(45,115), [2] = 1},
        { [1] = Vec2(45,115), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,116), [2] = 1},
        { [1] = Vec2(45,117), [2] = 1},
        { [1] = Vec2(45,117), [2] = 1},
        { [1] = Vec2(45,117), [2] = 1},
        { [1] = Vec2(45,117), [2] = 1},
        { [1] = Vec2(45,118), [2] = 1},
        { [1] = Vec2(45,118), [2] = 1},
        { [1] = Vec2(45,119), [2] = 1},
        { [1] = Vec2(45,119), [2] = 1},
        { [1] = Vec2(45,119), [2] = 1},
        { [1] = Vec2(45,119), [2] = 1},
        { [1] = Vec2(45,120), [2] = 1},
        { [1] = Vec2(45,120), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,121), [2] = 1},
        { [1] = Vec2(45,122), [2] = 1},
        { [1] = Vec2(45,122), [2] = 1},
        { [1] = Vec2(45,122), [2] = 1},
        { [1] = Vec2(45,122), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(82,70), [2] = 0},
        { [1] = Vec2(82,70), [2] = 1},
        { [1] = Vec2(82,70), [2] = 1},
        { [1] = Vec2(82,70), [2] = 1},
        { [1] = Vec2(82,70), [2] = 1},
        { [1] = Vec2(83,70), [2] = 1},
        { [1] = Vec2(83,70), [2] = 1},
        { [1] = Vec2(84,69), [2] = 1},
        { [1] = Vec2(84,69), [2] = 1},
        { [1] = Vec2(85,68), [2] = 1},
        { [1] = Vec2(85,68), [2] = 1},
        { [1] = Vec2(85,68), [2] = 1},
        { [1] = Vec2(85,68), [2] = 1},
        { [1] = Vec2(86,67), [2] = 1},
        { [1] = Vec2(86,67), [2] = 1},
        { [1] = Vec2(86,67), [2] = 1},
        { [1] = Vec2(86,67), [2] = 1},
        { [1] = Vec2(88,66), [2] = 1},
        { [1] = Vec2(88,66), [2] = 1},
        { [1] = Vec2(88,66), [2] = 1},
        { [1] = Vec2(88,66), [2] = 1},
        { [1] = Vec2(89,65), [2] = 1},
        { [1] = Vec2(89,65), [2] = 1},
        { [1] = Vec2(89,65), [2] = 1},
        { [1] = Vec2(89,65), [2] = 1},
        { [1] = Vec2(90,64), [2] = 1},
        { [1] = Vec2(90,64), [2] = 1},
        { [1] = Vec2(91,64), [2] = 1},
        { [1] = Vec2(91,64), [2] = 1},
        { [1] = Vec2(91,63), [2] = 1},
        { [1] = Vec2(91,63), [2] = 1},
        { [1] = Vec2(91,63), [2] = 1},
        { [1] = Vec2(91,63), [2] = 1},
        { [1] = Vec2(92,63), [2] = 1},
        { [1] = Vec2(92,63), [2] = 1},
        { [1] = Vec2(92,63), [2] = 1},
        { [1] = Vec2(92,63), [2] = 1},
        { [1] = Vec2(93,63), [2] = 1},
        { [1] = Vec2(93,63), [2] = 1},
        { [1] = Vec2(93,63), [2] = 1},
        { [1] = Vec2(93,63), [2] = 1},
        { [1] = Vec2(93,62), [2] = 1},
        { [1] = Vec2(93,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(94,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(95,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(96,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(97,62), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(98,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = Vec2(99,61), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(81,104), [2] = 0},
        { [1] = Vec2(81,104), [2] = 1},
        { [1] = Vec2(81,104), [2] = 1},
        { [1] = Vec2(81,104), [2] = 1},
        { [1] = Vec2(81,104), [2] = 1},
        { [1] = Vec2(82,104), [2] = 1},
        { [1] = Vec2(82,104), [2] = 1},
        { [1] = Vec2(83,104), [2] = 1},
        { [1] = Vec2(83,104), [2] = 1},
        { [1] = Vec2(84,104), [2] = 1},
        { [1] = Vec2(84,104), [2] = 1},
        { [1] = Vec2(86,103), [2] = 1},
        { [1] = Vec2(86,103), [2] = 1},
        { [1] = Vec2(87,103), [2] = 1},
        { [1] = Vec2(87,103), [2] = 1},
        { [1] = Vec2(88,103), [2] = 1},
        { [1] = Vec2(88,103), [2] = 1},
        { [1] = Vec2(88,103), [2] = 1},
        { [1] = Vec2(88,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(89,103), [2] = 1},
        { [1] = Vec2(90,103), [2] = 1},
        { [1] = Vec2(90,103), [2] = 1},
        { [1] = Vec2(90,103), [2] = 1},
        { [1] = Vec2(90,103), [2] = 1},
        { [1] = Vec2(90,103), [2] = 1},
        { [1] = Vec2(90,103), [2] = 1},
        { [1] = Vec2(91,103), [2] = 1},
        { [1] = Vec2(91,103), [2] = 1},
        { [1] = Vec2(91,103), [2] = 1},
        { [1] = Vec2(91,103), [2] = 1},
        { [1] = Vec2(91,103), [2] = 1},
        { [1] = Vec2(91,103), [2] = 1},
        { [1] = Vec2(92,103), [2] = 1},
        { [1] = Vec2(92,103), [2] = 1},
        { [1] = Vec2(92,103), [2] = 1},
        { [1] = Vec2(92,103), [2] = 1},
        { [1] = Vec2(93,103), [2] = 1},
        { [1] = Vec2(93,103), [2] = 1},
        { [1] = Vec2(93,103), [2] = 1},
        { [1] = Vec2(93,103), [2] = 1},
        { [1] = Vec2(93,103), [2] = 1},
        { [1] = Vec2(93,103), [2] = 1},
        { [1] = Vec2(94,103), [2] = 1},
        { [1] = Vec2(94,103), [2] = 1},
        { [1] = Vec2(94,103), [2] = 1},
        { [1] = Vec2(94,103), [2] = 1},
        { [1] = Vec2(94,103), [2] = 1},
        { [1] = Vec2(94,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(95,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(96,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(97,103), [2] = 1},
        { [1] = Vec2(98,103), [2] = 1},
        { [1] = Vec2(98,103), [2] = 1},
        { [1] = Vec2(98,103), [2] = 1},
        { [1] = Vec2(98,103), [2] = 1},
        { [1] = Vec2(98,103), [2] = 1},
        { [1] = Vec2(98,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(99,103), [2] = 1},
        { [1] = Vec2(100,103), [2] = 1},
        { [1] = Vec2(100,103), [2] = 1},
        { [1] = Vec2(100,103), [2] = 1},
        { [1] = Vec2(100,103), [2] = 1},
        { [1] = Vec2(100,102), [2] = 1},
        { [1] = Vec2(100,102), [2] = 1},
        { [1] = Vec2(101,102), [2] = 1},
        { [1] = Vec2(101,102), [2] = 1},
        { [1] = Vec2(101,102), [2] = 1},
        { [1] = Vec2(101,102), [2] = 1},
        { [1] = Vec2(101,102), [2] = 1},
        { [1] = Vec2(101,102), [2] = 1},
        { [1] = Vec2(102,102), [2] = 1},
        { [1] = Vec2(102,102), [2] = 1},
        { [1] = Vec2(102,102), [2] = 1},
        { [1] = Vec2(102,102), [2] = 1},
        { [1] = Vec2(102,102), [2] = 1},
        { [1] = Vec2(102,102), [2] = 1},
        { [1] = Vec2(103,102), [2] = 1},
        { [1] = Vec2(103,102), [2] = 1},
        { [1] = Vec2(103,102), [2] = 1},
        { [1] = Vec2(103,102), [2] = 1},
        { [1] = Vec2(104,102), [2] = 1},
        { [1] = Vec2(104,102), [2] = 1},
        { [1] = Vec2(104,102), [2] = 1},
        { [1] = Vec2(104,102), [2] = 1},
        { [1] = Vec2(105,103), [2] = 1},
        { [1] = Vec2(105,103), [2] = 1},
        { [1] = Vec2(105,103), [2] = 1},
        { [1] = Vec2(105,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(106,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(107,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(108,103), [2] = 1},
        { [1] = Vec2(109,103), [2] = 1},
        { [1] = Vec2(109,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(110,103), [2] = 1},
        { [1] = Vec2(111,103), [2] = 1},
        { [1] = Vec2(111,103), [2] = 1},
        { [1] = Vec2(111,103), [2] = 1},
        { [1] = Vec2(111,103), [2] = 1},
        { [1] = Vec2(112,103), [2] = 1},
        { [1] = Vec2(112,103), [2] = 1},
        { [1] = Vec2(112,103), [2] = 1},
        { [1] = Vec2(112,103), [2] = 1},
        { [1] = Vec2(113,103), [2] = 1},
        { [1] = Vec2(113,103), [2] = 1},
        { [1] = Vec2(113,103), [2] = 1},
        { [1] = Vec2(113,103), [2] = 1},
        { [1] = Vec2(113,103), [2] = 1},
        { [1] = Vec2(113,103), [2] = 1},
        { [1] = Vec2(114,103), [2] = 1},
        { [1] = Vec2(114,103), [2] = 1},
        { [1] = Vec2(114,103), [2] = 1},
        { [1] = Vec2(114,103), [2] = 1},
        { [1] = Vec2(115,103), [2] = 1},
        { [1] = Vec2(115,103), [2] = 1},
        { [1] = Vec2(115,103), [2] = 1},
        { [1] = Vec2(115,103), [2] = 1},
        { [1] = Vec2(115,103), [2] = 1},
        { [1] = Vec2(115,103), [2] = 1},
        { [1] = Vec2(116,103), [2] = 1},
        { [1] = Vec2(116,103), [2] = 1},
        { [1] = Vec2(116,103), [2] = 1},
        { [1] = Vec2(116,103), [2] = 1},
        { [1] = Vec2(116,103), [2] = 1},
        { [1] = Vec2(116,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(117,103), [2] = 1},
        { [1] = Vec2(118,103), [2] = 1},
        { [1] = Vec2(118,103), [2] = 1},
        { [1] = Vec2(118,103), [2] = 1},
        { [1] = Vec2(118,103), [2] = 1},
        { [1] = Vec2(119,103), [2] = 1},
        { [1] = Vec2(119,103), [2] = 1},
        { [1] = Vec2(119,103), [2] = 1},
        { [1] = Vec2(119,103), [2] = 1},
        { [1] = Vec2(120,103), [2] = 1},
        { [1] = Vec2(120,103), [2] = 1},
        { [1] = Vec2(120,103), [2] = 1},
        { [1] = Vec2(120,103), [2] = 1},
        { [1] = Vec2(120,103), [2] = 1},
        { [1] = Vec2(120,103), [2] = 1},
        { [1] = Vec2(121,103), [2] = 1},
        { [1] = Vec2(121,103), [2] = 1},
        { [1] = Vec2(121,103), [2] = 1},
        { [1] = Vec2(121,103), [2] = 1},
        { [1] = Vec2(121,103), [2] = 1},
        { [1] = Vec2(121,103), [2] = 1},
        { [1] = Vec2(122,103), [2] = 1},
        { [1] = Vec2(122,103), [2] = 1},
        { [1] = Vec2(122,103), [2] = 1},
        { [1] = Vec2(122,103), [2] = 1},
        { [1] = Vec2(122,103), [2] = 1},
        { [1] = Vec2(122,103), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(123,104), [2] = 1},
        { [1] = Vec2(124,104), [2] = 1},
        { [1] = Vec2(124,104), [2] = 1},
        { [1] = Vec2(124,105), [2] = 1},
        { [1] = Vec2(124,105), [2] = 1},
        { [1] = Vec2(124,105), [2] = 1},
        { [1] = Vec2(124,105), [2] = 1},
        { [1] = Vec2(125,106), [2] = 1},
        { [1] = Vec2(125,106), [2] = 1},
        { [1] = Vec2(125,106), [2] = 1},
        { [1] = Vec2(125,106), [2] = 1},
        { [1] = Vec2(125,107), [2] = 1},
        { [1] = Vec2(125,107), [2] = 1},
        { [1] = Vec2(125,107), [2] = 1},
        { [1] = Vec2(125,107), [2] = 1},
        { [1] = Vec2(125,107), [2] = 1},
        { [1] = Vec2(125,107), [2] = 1},
        { [1] = Vec2(126,108), [2] = 1},
        { [1] = Vec2(126,108), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,109), [2] = 1},
        { [1] = Vec2(126,110), [2] = 1},
        { [1] = Vec2(126,110), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,111), [2] = 1},
        { [1] = Vec2(126,112), [2] = 1},
        { [1] = Vec2(126,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,112), [2] = 1},
        { [1] = Vec2(127,113), [2] = 1},
        { [1] = Vec2(127,113), [2] = 1},
        { [1] = Vec2(127,113), [2] = 1},
        { [1] = Vec2(127,113), [2] = 1},
        { [1] = Vec2(127,114), [2] = 1},
        { [1] = Vec2(127,114), [2] = 1},
        { [1] = Vec2(128,114), [2] = 1},
        { [1] = Vec2(128,114), [2] = 1},
        { [1] = Vec2(128,114), [2] = 1},
        { [1] = Vec2(128,114), [2] = 1},
        { [1] = Vec2(128,116), [2] = 1},
        { [1] = Vec2(128,116), [2] = 1},
        { [1] = Vec2(128,116), [2] = 1},
        { [1] = Vec2(128,116), [2] = 1},
        { [1] = Vec2(129,117), [2] = 1},
        { [1] = Vec2(129,117), [2] = 1},
        { [1] = Vec2(129,118), [2] = 1},
        { [1] = Vec2(129,118), [2] = 1},
        { [1] = Vec2(129,118), [2] = 1},
        { [1] = Vec2(129,118), [2] = 1},
        { [1] = Vec2(129,119), [2] = 1},
        { [1] = Vec2(129,119), [2] = 1},
        { [1] = Vec2(129,119), [2] = 1},
        { [1] = Vec2(129,119), [2] = 1},
        { [1] = Vec2(129,120), [2] = 1},
        { [1] = Vec2(129,120), [2] = 1},
        { [1] = Vec2(130,120), [2] = 1},
        { [1] = Vec2(130,120), [2] = 1},
        { [1] = Vec2(130,121), [2] = 1},
        { [1] = Vec2(130,121), [2] = 1},
        { [1] = Vec2(130,122), [2] = 1},
        { [1] = Vec2(130,122), [2] = 1},
        { [1] = Vec2(130,123), [2] = 1},
        { [1] = Vec2(130,123), [2] = 1},
        { [1] = Vec2(130,124), [2] = 1},
        { [1] = Vec2(130,124), [2] = 1},
        { [1] = Vec2(130,124), [2] = 1},
        { [1] = Vec2(130,124), [2] = 1},
        { [1] = Vec2(130,125), [2] = 1},
        { [1] = Vec2(130,125), [2] = 1},
        { [1] = Vec2(130,125), [2] = 1},
        { [1] = Vec2(130,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,126), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,125), [2] = 1},
        { [1] = Vec2(131,122), [2] = 1},
        { [1] = Vec2(131,122), [2] = 1},
        { [1] = Vec2(131,121), [2] = 1},
        { [1] = Vec2(131,121), [2] = 1},
        { [1] = Vec2(131,121), [2] = 1},
        { [1] = Vec2(131,121), [2] = 1},
        { [1] = Vec2(131,120), [2] = 1},
        { [1] = Vec2(131,120), [2] = 1},
        { [1] = Vec2(131,119), [2] = 1},
        { [1] = Vec2(131,119), [2] = 1},
        { [1] = Vec2(131,119), [2] = 1},
        { [1] = Vec2(131,119), [2] = 1},
        { [1] = Vec2(131,118), [2] = 1},
        { [1] = Vec2(131,118), [2] = 1},
        { [1] = Vec2(131,117), [2] = 1},
        { [1] = Vec2(131,117), [2] = 1},
        { [1] = Vec2(131,116), [2] = 1},
        { [1] = Vec2(131,116), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,113), [2] = 1},
        { [1] = Vec2(130,112), [2] = 1},
        { [1] = Vec2(130,112), [2] = 1},
        { [1] = Vec2(130,111), [2] = 1},
        { [1] = Vec2(130,111), [2] = 1},
        { [1] = Vec2(130,110), [2] = 1},
        { [1] = Vec2(130,110), [2] = 1},
        { [1] = Vec2(130,110), [2] = 1},
        { [1] = Vec2(130,110), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(130,109), [2] = 1},
        { [1] = Vec2(129,108), [2] = 1},
        { [1] = Vec2(129,108), [2] = 1},
        { [1] = Vec2(129,108), [2] = 1},
        { [1] = Vec2(129,108), [2] = 1},
        { [1] = Vec2(129,106), [2] = 1},
        { [1] = Vec2(129,106), [2] = 1},
        { [1] = Vec2(129,105), [2] = 1},
        { [1] = Vec2(129,105), [2] = 1},
        { [1] = Vec2(129,104), [2] = 1},
        { [1] = Vec2(129,104), [2] = 1},
        { [1] = Vec2(129,103), [2] = 1},
        { [1] = Vec2(129,103), [2] = 1},
        { [1] = Vec2(129,102), [2] = 1},
        { [1] = Vec2(129,102), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(128,100), [2] = 1},
        { [1] = Vec2(127,97), [2] = 1},
        { [1] = Vec2(127,97), [2] = 1},
        { [1] = Vec2(127,97), [2] = 1},
        { [1] = Vec2(127,97), [2] = 1},
        { [1] = Vec2(127,95), [2] = 1},
        { [1] = Vec2(127,95), [2] = 1},
        { [1] = Vec2(127,95), [2] = 1},
        { [1] = Vec2(127,95), [2] = 1},
        { [1] = Vec2(127,94), [2] = 1},
        { [1] = Vec2(127,94), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,93), [2] = 1},
        { [1] = Vec2(126,92), [2] = 1},
        { [1] = Vec2(126,92), [2] = 1},
        { [1] = Vec2(126,92), [2] = 1},
        { [1] = Vec2(126,92), [2] = 1},
        { [1] = Vec2(126,91), [2] = 1},
        { [1] = Vec2(126,91), [2] = 1},
        { [1] = Vec2(125,90), [2] = 1},
        { [1] = Vec2(125,90), [2] = 1},
        { [1] = Vec2(125,90), [2] = 1},
        { [1] = Vec2(125,90), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(125,89), [2] = 1},
        { [1] = Vec2(124,88), [2] = 1},
        { [1] = Vec2(124,88), [2] = 1},
        { [1] = Vec2(124,88), [2] = 1},
        { [1] = Vec2(124,88), [2] = 1},
        { [1] = Vec2(124,88), [2] = 1},
        { [1] = Vec2(124,88), [2] = 1},
        { [1] = Vec2(124,87), [2] = 1},
        { [1] = Vec2(124,87), [2] = 1},
        { [1] = Vec2(124,87), [2] = 1},
        { [1] = Vec2(124,87), [2] = 1},
        { [1] = Vec2(123,87), [2] = 1},
        { [1] = Vec2(123,87), [2] = 1},
        { [1] = Vec2(123,87), [2] = 1},
        { [1] = Vec2(123,87), [2] = 1},
        { [1] = Vec2(123,87), [2] = 1},
        { [1] = Vec2(123,87), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,86), [2] = 1},
        { [1] = Vec2(123,85), [2] = 1},
        { [1] = Vec2(123,85), [2] = 1},
        { [1] = Vec2(123,85), [2] = 1},
        { [1] = Vec2(123,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,85), [2] = 1},
        { [1] = Vec2(122,84), [2] = 1},
        { [1] = Vec2(122,84), [2] = 1},
        { [1] = Vec2(122,84), [2] = 1},
        { [1] = Vec2(122,84), [2] = 1},
        { [1] = Vec2(122,84), [2] = 1},
        { [1] = Vec2(122,84), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,83), [2] = 1},
        { [1] = Vec2(121,82), [2] = 1},
        { [1] = Vec2(121,82), [2] = 1},
        { [1] = Vec2(121,82), [2] = 1},
        { [1] = Vec2(121,82), [2] = 1},
        { [1] = Vec2(121,82), [2] = 1},
        { [1] = Vec2(121,82), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(121,81), [2] = 1},
        { [1] = Vec2(120,81), [2] = 1},
        { [1] = Vec2(120,81), [2] = 1},
        { [1] = Vec2(120,81), [2] = 1},
        { [1] = Vec2(120,81), [2] = 1},
        { [1] = Vec2(120,81), [2] = 1},
        { [1] = Vec2(120,81), [2] = 1},
        { [1] = nil, [2] = 2},
        { [1] = Vec2(100,88), [2] = 0},
        { [1] = Vec2(100,88), [2] = 1},
        { [1] = Vec2(100,88), [2] = 1},
        { [1] = Vec2(100,89), [2] = 1},
        { [1] = Vec2(100,89), [2] = 1},
        { [1] = Vec2(100,89), [2] = 1},
        { [1] = Vec2(100,89), [2] = 1},
        { [1] = Vec2(100,90), [2] = 1},
        { [1] = Vec2(100,90), [2] = 1},
        { [1] = Vec2(100,91), [2] = 1},
        { [1] = Vec2(100,91), [2] = 1},
        { [1] = Vec2(100,92), [2] = 1},
        { [1] = Vec2(100,92), [2] = 1},
        { [1] = Vec2(100,93), [2] = 1},
        { [1] = Vec2(100,93), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,94), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,95), [2] = 1},
        { [1] = Vec2(100,97), [2] = 1},
        { [1] = Vec2(100,97), [2] = 1},
        { [1] = Vec2(100,98), [2] = 1},
        { [1] = Vec2(100,98), [2] = 1},
        { [1] = Vec2(100,99), [2] = 1},
        { [1] = Vec2(100,99), [2] = 1},
        { [1] = Vec2(100,101), [2] = 1},
        { [1] = Vec2(100,101), [2] = 1},
        { [1] = Vec2(99,102), [2] = 1},
        { [1] = Vec2(99,102), [2] = 1},
        { [1] = Vec2(99,104), [2] = 1},
        { [1] = Vec2(99,104), [2] = 1},
        { [1] = Vec2(99,105), [2] = 1},
        { [1] = Vec2(99,105), [2] = 1},
        { [1] = Vec2(99,106), [2] = 1},
        { [1] = Vec2(99,106), [2] = 1},
        { [1] = Vec2(98,107), [2] = 1},
        { [1] = Vec2(98,107), [2] = 1},
        { [1] = Vec2(98,108), [2] = 1},
        { [1] = Vec2(98,108), [2] = 1},
        { [1] = Vec2(98,109), [2] = 1},
        { [1] = Vec2(98,109), [2] = 1},
        { [1] = Vec2(97,110), [2] = 1},
        { [1] = Vec2(97,110), [2] = 1},
        { [1] = Vec2(97,112), [2] = 1},
        { [1] = Vec2(97,112), [2] = 1},
        { [1] = Vec2(96,112), [2] = 1},
        { [1] = Vec2(96,112), [2] = 1},
        { [1] = Vec2(96,113), [2] = 1},
        { [1] = Vec2(96,113), [2] = 1},
        { [1] = Vec2(96,114), [2] = 1},
        { [1] = Vec2(96,114), [2] = 1},
        { [1] = Vec2(96,114), [2] = 1},
        { [1] = Vec2(96,114), [2] = 1},
        { [1] = Vec2(96,115), [2] = 1},
        { [1] = Vec2(96,115), [2] = 1},
        { [1] = Vec2(96,114), [2] = 1},
        { [1] = Vec2(96,114), [2] = 1},
        { [1] = Vec2(96,115), [2] = 1},
        { [1] = Vec2(96,115), [2] = 1},
        { [1] = Vec2(96,115), [2] = 1},
        { [1] = Vec2(96,115), [2] = 1},
        { [1] = Vec2(97,115), [2] = 1},
        { [1] = Vec2(97,115), [2] = 1},
        { [1] = Vec2(97,116), [2] = 1},
        { [1] = Vec2(97,116), [2] = 1},
        { [1] = Vec2(99,116), [2] = 1},
        { [1] = Vec2(99,116), [2] = 1},
        { [1] = Vec2(99,116), [2] = 1},
        { [1] = Vec2(99,116), [2] = 1},
        { [1] = Vec2(100,117), [2] = 1},
        { [1] = Vec2(100,117), [2] = 1},
        { [1] = Vec2(101,118), [2] = 1},
        { [1] = Vec2(101,118), [2] = 1},
        { [1] = Vec2(101,118), [2] = 1},
        { [1] = Vec2(101,118), [2] = 1},
        { [1] = Vec2(101,119), [2] = 1},
        { [1] = Vec2(101,119), [2] = 1},
        { [1] = Vec2(101,120), [2] = 1},
        { [1] = Vec2(101,120), [2] = 1},
        { [1] = Vec2(101,120), [2] = 1},
        { [1] = Vec2(101,120), [2] = 1},
        { [1] = nil, [2] = 2}
    },
    [122395053342077] = {
        { [1] = Vec2(97, 65), [2] = 0},
        { [1] = Vec2(97, 65), [2] = 1},
        { [1] = Vec2(97, 65), [2] = 1},
        { [1] = Vec2(97, 65), [2] = 1},
        { [1] = Vec2(97, 65), [2] = 1},
        { [1] = Vec2(100, 71), [2] = 1},
        { [1] = Vec2(100, 71), [2] = 1},
        { [1] = Vec2(104, 79), [2] = 1},
        { [1] = Vec2(104, 79), [2] = 1},
        { [1] = Vec2(108, 85), [2] = 1},
        { [1] = Vec2(108, 85), [2] = 1},
        { [1] = Vec2(112, 88), [2] = 1},
        { [1] = Vec2(112, 88), [2] = 1},
        { [1] = Vec2(112, 87), [2] = 1},
        { [1] = Vec2(112, 87), [2] = 1},
        { [1] = Vec2(109, 80), [2] = 1},
        { [1] = Vec2(109, 80), [2] = 1},
        { [1] = Vec2(103, 67), [2] = 1},
        { [1] = Vec2(103, 67), [2] = 1},
        { [1] = Vec2(98, 53), [2] = 1},
        { [1] = Vec2(98, 53), [2] = 1},
        { [1] = Vec2(94, 47), [2] = 1},
        { [1] = Vec2(94, 47), [2] = 1},
        { [1] = Vec2(93, 45), [2] = 1},
        { [1] = Vec2(93, 45), [2] = 1},
        { [1] = Vec2(92, 44), [2] = 1},
        { [1] = Vec2(92, 44), [2] = 1},
        { [1] = Vec2(93, 44), [2] = 1},
        { [1] = Vec2(93, 44), [2] = 1},
        { [1] = Vec2(95, 45), [2] = 1},
        { [1] = Vec2(95, 45), [2] = 1},
        { [1] = Vec2(98, 47), [2] = 1},
        { [1] = Vec2(98, 47), [2] = 1},
        { [1] = Vec2(100, 50), [2] = 1},
        { [1] = Vec2(100, 50), [2] = 1},
        { [1] = Vec2(103, 53), [2] = 1},
        { [1] = Vec2(103, 53), [2] = 1},
        { [1] = Vec2(103, 54), [2] = 1},
        { [1] = Vec2(103, 54), [2] = 1},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [1] = Vec2(101, 123), [2] = 0},
        { [1] = Vec2(103, 123), [2] = 1},
        { [1] = Vec2(103, 123), [2] = 1},
        { [1] = Vec2(105, 123), [2] = 1},
        { [1] = Vec2(105, 123), [2] = 1},
        { [1] = Vec2(107, 123), [2] = 1},
        { [1] = Vec2(107, 123), [2] = 1},
        { [1] = Vec2(109, 123), [2] = 1},
        { [1] = Vec2(109, 123), [2] = 1},
        { [1] = Vec2(112, 123), [2] = 1},
        { [1] = Vec2(112, 123), [2] = 1},
        { [1] = Vec2(112, 123), [2] = 1},
        { [1] = Vec2(112, 123), [2] = 1},
        { [1] = Vec2(114, 123), [2] = 1},
        { [1] = Vec2(114, 123), [2] = 1},
        { [1] = Vec2(115, 123), [2] = 1},
        { [1] = Vec2(115, 123), [2] = 1},
        { [1] = Vec2(116, 123), [2] = 1},
        { [1] = Vec2(116, 123), [2] = 1},
        { [1] = Vec2(117, 123), [2] = 1},
        { [1] = Vec2(117, 123), [2] = 1},
        { [1] = Vec2(117, 123), [2] = 1},
        { [1] = Vec2(117, 123), [2] = 1},
        { [1] = Vec2(118, 123), [2] = 1},
        { [1] = Vec2(118, 123), [2] = 1},
        { [1] = Vec2(119, 123), [2] = 1},
        { [1] = Vec2(119, 123), [2] = 1},
        { [1] = Vec2(120, 123), [2] = 1},
        { [1] = Vec2(120, 123), [2] = 1},
        { [1] = Vec2(122, 123), [2] = 1},
        { [1] = Vec2(122, 123), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [1] = Vec2(122, 124), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(101, 94), [2] = 0},
        { [1] = Vec2(104, 94), [2] = 1},
        { [1] = Vec2(104, 94), [2] = 1},
        { [1] = Vec2(107, 92), [2] = 1},
        { [1] = Vec2(107, 92), [2] = 1},
        { [1] = Vec2(108, 92), [2] = 1},
        { [1] = Vec2(108, 92), [2] = 1},
        { [1] = Vec2(110, 92), [2] = 1},
        { [1] = Vec2(110, 92), [2] = 1},
        { [1] = Vec2(111, 93), [2] = 1},
        { [1] = Vec2(111, 93), [2] = 1},
        { [1] = Vec2(112, 93), [2] = 1},
        { [1] = Vec2(112, 93), [2] = 1},
        { [1] = Vec2(113, 92), [2] = 1},
        { [1] = Vec2(113, 92), [2] = 1},
        { [1] = Vec2(115, 91), [2] = 1},
        { [1] = Vec2(115, 91), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(82, 127), [2] = 0},
        { [1] = Vec2(82, 127), [2] = 1},
        { [1] = Vec2(82, 127), [2] = 1},
        { [1] = Vec2(81, 125), [2] = 1},
        { [1] = Vec2(81, 125), [2] = 1},
        { [1] = Vec2(80, 124), [2] = 1},
        { [1] = Vec2(80, 124), [2] = 1},
        { [1] = Vec2(80, 120), [2] = 1},
        { [1] = Vec2(80, 120), [2] = 1},
        { [1] = Vec2(80, 118), [2] = 1},
        { [1] = Vec2(80, 118), [2] = 1},
        { [1] = Vec2(81, 115), [2] = 1},
        { [1] = Vec2(81, 115), [2] = 1},
        { [1] = Vec2(81, 113), [2] = 1},
        { [1] = Vec2(81, 113), [2] = 1},
        { [1] = Vec2(81, 111), [2] = 1},
        { [1] = Vec2(81, 111), [2] = 1},
        { [1] = Vec2(81, 109), [2] = 1},
        { [1] = Vec2(81, 109), [2] = 1},
        { [1] = Vec2(81, 108), [2] = 1},
        { [1] = Vec2(81, 108), [2] = 1},
        { [1] = Vec2(81, 106), [2] = 1},
        { [1] = Vec2(81, 106), [2] = 1},
        { [1] = Vec2(81, 106), [2] = 1},
        { [1] = Vec2(81, 106), [2] = 1},
        { [1] = Vec2(81, 105), [2] = 1},
        { [1] = Vec2(81, 105), [2] = 1},
        { [1] = Vec2(80, 103), [2] = 1},
        { [1] = Vec2(80, 103), [2] = 1},
        { [1] = Vec2(80, 103), [2] = 1},
        { [1] = Vec2(80, 103), [2] = 1},
        { [1] = Vec2(79, 103), [2] = 1},
        { [1] = Vec2(79, 103), [2] = 1},
        { [1] = Vec2(79, 101), [2] = 1},
        { [1] = Vec2(79, 101), [2] = 1},
        { [1] = Vec2(79, 99), [2] = 1},
        { [1] = Vec2(79, 99), [2] = 1},
        { [1] = Vec2(79, 99), [2] = 1},
        { [1] = Vec2(79, 99), [2] = 1},
        { [1] = Vec2(79, 98), [2] = 1},
        { [1] = Vec2(79, 98), [2] = 1},
        { [1] = Vec2(79, 97), [2] = 1},
        { [1] = Vec2(79, 97), [2] = 1},
        { [1] = Vec2(80, 96), [2] = 1},
        { [1] = Vec2(80, 96), [2] = 1},
        { [1] = Vec2(80, 94), [2] = 1},
        { [1] = Vec2(80, 94), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(66, 93), [2] = 0},
        { [1] = Vec2(66, 93), [2] = 1},
        { [1] = Vec2(66, 93), [2] = 1},
        { [1] = Vec2(66, 93), [2] = 1},
        { [1] = Vec2(66, 93), [2] = 1},
        { [1] = Vec2(70, 92), [2] = 1},
        { [1] = Vec2(70, 92), [2] = 1},
        { [1] = Vec2(74, 92), [2] = 1},
        { [1] = Vec2(74, 92), [2] = 1},
        { [1] = Vec2(78, 90), [2] = 1},
        { [1] = Vec2(78, 90), [2] = 1},
        { [1] = Vec2(80, 90), [2] = 1},
        { [1] = Vec2(80, 90), [2] = 1},
        { [1] = Vec2(80, 90), [2] = 1},
        { [1] = Vec2(80, 90), [2] = 1},
        { [1] = Vec2(83, 88), [2] = 1},
        { [1] = Vec2(83, 88), [2] = 1},
        { [1] = Vec2(84, 88), [2] = 1},
        { [1] = Vec2(84, 88), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(29, 110), [2] = 0},
        { [1] = Vec2(28, 110), [2] = 1},
        { [1] = Vec2(28, 110), [2] = 1},
        { [1] = Vec2(28, 109), [2] = 1},
        { [1] = Vec2(28, 109), [2] = 1},
        { [1] = Vec2(29, 110), [2] = 1},
        { [1] = Vec2(29, 110), [2] = 1},
        { [1] = Vec2(31, 110), [2] = 1},
        { [1] = Vec2(31, 110), [2] = 1},
        { [1] = Vec2(33, 110), [2] = 1},
        { [1] = Vec2(33, 110), [2] = 1},
        { [1] = Vec2(37, 111), [2] = 1},
        { [1] = Vec2(37, 111), [2] = 1},
        { [1] = Vec2(38, 112), [2] = 1},
        { [1] = Vec2(38, 112), [2] = 1},
        { [1] = Vec2(40, 112), [2] = 1},
        { [1] = Vec2(40, 112), [2] = 1},
        { [1] = Vec2(40, 112), [2] = 1},
        { [1] = Vec2(40, 112), [2] = 1},
        { [1] = Vec2(42, 112), [2] = 1},
        { [1] = Vec2(42, 112), [2] = 1},
        { [1] = Vec2(42, 112), [2] = 1},
        { [1] = Vec2(42, 112), [2] = 1},
        { [1] = Vec2(44, 113), [2] = 1},
        { [1] = Vec2(44, 113), [2] = 1},
        { [1] = Vec2(44, 113), [2] = 1},
        { [1] = Vec2(44, 113), [2] = 1},
        { [1] = Vec2(45, 113), [2] = 1},
        { [1] = Vec2(45, 113), [2] = 1},
        { [1] = Vec2(45, 113), [2] = 1},
        { [1] = Vec2(45, 113), [2] = 1},
        { [1] = Vec2(47, 115), [2] = 1},
        { [1] = Vec2(47, 115), [2] = 1},
        { [1] = Vec2(48, 115), [2] = 1},
        { [1] = Vec2(48, 115), [2] = 1},
        { [1] = Vec2(48, 116), [2] = 1},
        { [1] = Vec2(48, 116), [2] = 1},
        { [1] = Vec2(49, 117), [2] = 1},
        { [1] = Vec2(49, 117), [2] = 1},
        { [1] = Vec2(49, 118), [2] = 1},
        { [1] = Vec2(49, 118), [2] = 1},
        { [1] = Vec2(49, 119), [2] = 1},
        { [1] = Vec2(49, 119), [2] = 1},
        { [1] = Vec2(49, 120), [2] = 1},
        { [1] = Vec2(49, 120), [2] = 1},
        { [1] = Vec2(49, 122), [2] = 1},
        { [1] = Vec2(49, 122), [2] = 1},
        { [1] = Vec2(49, 122), [2] = 1},
        { [1] = Vec2(49, 122), [2] = 1},
        { [1] = Vec2(48, 122), [2] = 1},
        { [1] = Vec2(48, 122), [2] = 1},
        { [1] = Vec2(48, 124), [2] = 1},
        { [1] = Vec2(48, 124), [2] = 1},
        { [1] = Vec2(48, 124), [2] = 1},
        { [1] = Vec2(48, 124), [2] = 1},
        { [1] = Vec2(47, 124), [2] = 1},
        { [1] = Vec2(47, 124), [2] = 1},
        { [1] = Vec2(46, 124), [2] = 1},
        { [1] = Vec2(46, 124), [2] = 1},
        { [1] = Vec2(45, 125), [2] = 1},
        { [1] = Vec2(45, 125), [2] = 1},
        { [1] = Vec2(44, 125), [2] = 1},
        { [1] = Vec2(44, 125), [2] = 1},
        { [1] = Vec2(44, 125), [2] = 1},
        { [1] = Vec2(44, 125), [2] = 1},
        { [1] = Vec2(43, 126), [2] = 1},
        { [1] = Vec2(43, 126), [2] = 1},
        { [1] = Vec2(43, 126), [2] = 1},
        { [1] = Vec2(43, 126), [2] = 1},
        { [1] = Vec2(45, 124), [2] = 1},
        { [1] = Vec2(45, 124), [2] = 1},
        { [1] = Vec2(47, 122), [2] = 1},
        { [1] = Vec2(47, 122), [2] = 1},
        { [1] = Vec2(50, 120), [2] = 1},
        { [1] = Vec2(50, 120), [2] = 1},
        { [1] = Vec2(52, 120), [2] = 1},
        { [1] = Vec2(52, 120), [2] = 1},
        { [1] = Vec2(53, 119), [2] = 1},
        { [1] = Vec2(53, 119), [2] = 1},
        { [1] = Vec2(54, 117), [2] = 1},
        { [1] = Vec2(54, 117), [2] = 1},
        { [1] = Vec2(55, 116), [2] = 1},
        { [1] = Vec2(55, 116), [2] = 1},
        { [1] = Vec2(57, 115), [2] = 1},
        { [1] = Vec2(57, 115), [2] = 1},
        { [1] = Vec2(57, 114), [2] = 1},
        { [1] = Vec2(57, 114), [2] = 1},
        { [1] = Vec2(58, 114), [2] = 1},
        { [1] = Vec2(58, 114), [2] = 1},
        { [1] = Vec2(59, 114), [2] = 1},
        { [1] = Vec2(59, 114), [2] = 1},
        { [1] = Vec2(60, 113), [2] = 1},
        { [1] = Vec2(60, 113), [2] = 1},
        { [1] = Vec2(60, 113), [2] = 1},
        { [1] = Vec2(60, 113), [2] = 1},
        { [1] = Vec2(60, 112), [2] = 1},
        { [1] = Vec2(60, 112), [2] = 1},
        { [1] = Vec2(61, 111), [2] = 1},
        { [1] = Vec2(61, 111), [2] = 1},
        { [1] = Vec2(62, 111), [2] = 1},
        { [1] = Vec2(62, 111), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(40, 94), [2] = 0},
        { [1] = Vec2(40, 94), [2] = 1},
        { [1] = Vec2(40, 94), [2] = 1},
        { [1] = Vec2(41, 94), [2] = 1},
        { [1] = Vec2(41, 94), [2] = 1},
        { [1] = Vec2(43, 96), [2] = 1},
        { [1] = Vec2(43, 96), [2] = 1},
        { [1] = Vec2(45, 97), [2] = 1},
        { [1] = Vec2(45, 97), [2] = 1},
        { [1] = Vec2(46, 97), [2] = 1},
        { [1] = Vec2(46, 97), [2] = 1},
        { [1] = Vec2(48, 99), [2] = 1},
        { [1] = Vec2(48, 99), [2] = 1},
        { [1] = Vec2(50, 99), [2] = 1},
        { [1] = Vec2(50, 99), [2] = 1},
        { [1] = Vec2(51, 100), [2] = 1},
        { [1] = Vec2(51, 100), [2] = 1},
        { [1] = Vec2(53, 101), [2] = 1},
        { [1] = Vec2(53, 101), [2] = 1},
        { [1] = Vec2(54, 101), [2] = 1},
        { [1] = Vec2(54, 101), [2] = 1},
        { [1] = Vec2(55, 101), [2] = 1},
        { [1] = Vec2(55, 101), [2] = 1},
        { [1] = Vec2(55, 102), [2] = 1},
        { [1] = Vec2(55, 102), [2] = 1},
        { [1] = Vec2(57, 103), [2] = 1},
        { [1] = Vec2(57, 103), [2] = 1},
        { [1] = Vec2(58, 103), [2] = 1},
        { [1] = Vec2(58, 103), [2] = 1},
        { [1] = Vec2(59, 104), [2] = 1},
        { [1] = Vec2(59, 104), [2] = 1},
        { [1] = Vec2(60, 104), [2] = 1},
        { [1] = Vec2(60, 104), [2] = 1},
        { [1] = Vec2(60, 105), [2] = 1},
        { [1] = Vec2(60, 105), [2] = 1},
        { [1] = Vec2(62, 106), [2] = 1},
        { [1] = Vec2(62, 106), [2] = 1},
        { [1] = Vec2(64, 107), [2] = 1},
        { [1] = Vec2(64, 107), [2] = 1},
        { [1] = Vec2(64, 108), [2] = 1},
        { [1] = Vec2(64, 108), [2] = 1},
        { [1] = Vec2(66, 109), [2] = 1},
        { [1] = Vec2(66, 109), [2] = 1},
        { [1] = Vec2(66, 109), [2] = 1},
        { [1] = Vec2(66, 109), [2] = 1},
        { [1] = Vec2(67, 109), [2] = 1},
        { [1] = Vec2(67, 109), [2] = 1},
        { [1] = Vec2(68, 111), [2] = 1},
        { [1] = Vec2(68, 111), [2] = 1},
        { [1] = Vec2(69, 112), [2] = 1},
        { [1] = Vec2(69, 112), [2] = 1},
        { [1] = Vec2(69, 113), [2] = 1},
        { [1] = Vec2(69, 113), [2] = 1},
        { [1] = Vec2(72, 114), [2] = 1},
        { [1] = Vec2(72, 114), [2] = 1},
        { [1] = Vec2(73, 115), [2] = 1},
        { [1] = Vec2(73, 115), [2] = 1},
        { [1] = Vec2(74, 116), [2] = 1},
        { [1] = Vec2(74, 116), [2] = 1},
        { [1] = Vec2(75, 116), [2] = 1},
        { [1] = Vec2(75, 116), [2] = 1},
        { [1] = Vec2(75, 117), [2] = 1},
        { [1] = Vec2(75, 117), [2] = 1},
        { [1] = Vec2(76, 117), [2] = 1},
        { [1] = Vec2(76, 117), [2] = 1},
        { [1] = Vec2(76, 118), [2] = 1},
        { [1] = Vec2(76, 118), [2] = 1},
        { [1] = Vec2(76, 118), [2] = 1},
        { [1] = Vec2(76, 118), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(87, 109), [2] = 0},
        { [1] = Vec2(87, 109), [2] = 1},
        { [1] = Vec2(87, 109), [2] = 1},
        { [1] = Vec2(89, 109), [2] = 1},
        { [1] = Vec2(89, 109), [2] = 1},
        { [1] = Vec2(93, 109), [2] = 1},
        { [1] = Vec2(93, 109), [2] = 1},
        { [1] = Vec2(96, 109), [2] = 1},
        { [1] = Vec2(96, 109), [2] = 1},
        { [1] = Vec2(100, 109), [2] = 1},
        { [1] = Vec2(100, 109), [2] = 1},
        { [1] = Vec2(102, 110), [2] = 1},
        { [1] = Vec2(102, 110), [2] = 1},
        { [1] = Vec2(105, 110), [2] = 1},
        { [1] = Vec2(105, 110), [2] = 1},
        { [1] = Vec2(108, 110), [2] = 1},
        { [1] = Vec2(108, 110), [2] = 1},
        { [1] = Vec2(109, 110), [2] = 1},
        { [1] = Vec2(109, 110), [2] = 1},
        { [1] = Vec2(111, 110), [2] = 1},
        { [1] = Vec2(111, 110), [2] = 1},
        { [1] = Vec2(112, 110), [2] = 1},
        { [1] = Vec2(112, 110), [2] = 1},
        { [1] = Vec2(113, 110), [2] = 1},
        { [1] = Vec2(113, 110), [2] = 1},
        { [1] = Vec2(115, 110), [2] = 1},
        { [1] = Vec2(115, 110), [2] = 1},
        { [1] = Vec2(116, 110), [2] = 1},
        { [1] = Vec2(116, 110), [2] = 1},
        { [1] = Vec2(117, 110), [2] = 1},
        { [1] = Vec2(117, 110), [2] = 1},
        { [1] = Vec2(119, 110), [2] = 1},
        { [1] = Vec2(119, 110), [2] = 1},
        { [1] = Vec2(121, 110), [2] = 1},
        { [1] = Vec2(121, 110), [2] = 1},
        { [1] = Vec2(121, 110), [2] = 1},
        { [1] = Vec2(121, 110), [2] = 1},
        { [1] = Vec2(121, 110), [2] = 1},
        { [1] = Vec2(121, 110), [2] = 1},
        { [1] = Vec2(123, 110), [2] = 1},
        { [1] = Vec2(123, 110), [2] = 1},
        { [1] = Vec2(124, 110), [2] = 1},
        { [1] = Vec2(124, 110), [2] = 1},
        { [1] = Vec2(124, 110), [2] = 1},
        { [1] = Vec2(124, 110), [2] = 1},
        { [1] = Vec2(126, 110), [2] = 1},
        { [1] = Vec2(126, 110), [2] = 1},
        { [1] = Vec2(126, 110), [2] = 1},
        { [1] = Vec2(126, 110), [2] = 1},
        { [1] = Vec2(127, 110), [2] = 1},
        { [1] = Vec2(127, 110), [2] = 1},
        { [1] = Vec2(129, 110), [2] = 1},
        { [1] = Vec2(129, 110), [2] = 1},
        { [1] = Vec2(129, 110), [2] = 1},
        { [1] = Vec2(129, 110), [2] = 1},
        { [1] = Vec2(131, 110), [2] = 1},
        { [1] = Vec2(131, 110), [2] = 1},
        { [1] = Vec2(131, 109), [2] = 1},
        { [1] = Vec2(131, 109), [2] = 1},
        { [1] = Vec2(132, 108), [2] = 1},
        { [1] = Vec2(132, 108), [2] = 1},
        { [1] = Vec2(133, 108), [2] = 1},
        { [1] = Vec2(133, 108), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(45, 80), [2] = 0},
        { [1] = Vec2(45, 81), [2] = 1},
        { [1] = Vec2(45, 81), [2] = 1},
        { [1] = Vec2(45, 79), [2] = 1},
        { [1] = Vec2(45, 79), [2] = 1},
        { [1] = Vec2(45, 75), [2] = 1},
        { [1] = Vec2(45, 75), [2] = 1},
        { [1] = Vec2(46, 70), [2] = 1},
        { [1] = Vec2(46, 70), [2] = 1},
        { [1] = Vec2(46, 64), [2] = 1},
        { [1] = Vec2(46, 64), [2] = 1},
        { [1] = Vec2(46, 63), [2] = 1},
        { [1] = Vec2(46, 63), [2] = 1},
        { [1] = Vec2(46, 62), [2] = 1},
        { [1] = Vec2(46, 62), [2] = 1},
        { [1] = Vec2(46, 60), [2] = 1},
        { [1] = Vec2(46, 60), [2] = 1},
        { [1] = Vec2(46, 59), [2] = 1},
        { [1] = Vec2(46, 59), [2] = 1},
        { [1] = Vec2(46, 57), [2] = 1},
        { [1] = Vec2(46, 57), [2] = 1},
        { [1] = Vec2(46, 57), [2] = 1},
        { [1] = Vec2(46, 57), [2] = 1},
        { [1] = Vec2(46, 56), [2] = 1},
        { [1] = Vec2(46, 56), [2] = 1},
        { [1] = Vec2(46, 55), [2] = 1},
        { [1] = Vec2(46, 55), [2] = 1},
        { [1] = Vec2(46, 54), [2] = 1},
        { [1] = Vec2(46, 54), [2] = 1},
        { [1] = Vec2(46, 54), [2] = 1},
        { [1] = Vec2(46, 54), [2] = 1},
        { [1] = Vec2(46, 51), [2] = 1},
        { [1] = Vec2(46, 51), [2] = 1},
        { [1] = Vec2(46, 50), [2] = 1},
        { [1] = Vec2(46, 50), [2] = 1},
        { [1] = Vec2(46, 49), [2] = 1},
        { [1] = Vec2(46, 49), [2] = 1},
        { [1] = Vec2(46, 47), [2] = 1},
        { [1] = Vec2(46, 47), [2] = 1},
        { [1] = Vec2(46, 45), [2] = 1},
        { [1] = Vec2(46, 45), [2] = 1},
        { [1] = Vec2(46, 45), [2] = 1},
        { [1] = Vec2(46, 45), [2] = 1},
        { [1] = Vec2(47, 43), [2] = 1},
        { [1] = Vec2(47, 43), [2] = 1},
        { [1] = Vec2(47, 41), [2] = 1},
        { [1] = Vec2(47, 41), [2] = 1},
        { [1] = Vec2(47, 40), [2] = 1},
        { [1] = Vec2(47, 40), [2] = 1},
        { [1] = Vec2(47, 38), [2] = 1},
        { [1] = Vec2(47, 38), [2] = 1},
        { [1] = Vec2(47, 37), [2] = 1},
        { [1] = Vec2(47, 37), [2] = 1},
        { [1] = Vec2(46, 36), [2] = 1},
        { [1] = Vec2(46, 36), [2] = 1},
        { [1] = Vec2(46, 34), [2] = 1},
        { [1] = Vec2(46, 34), [2] = 1},
        { [1] = Vec2(46, 32), [2] = 1},
        { [1] = Vec2(46, 32), [2] = 1},
        { [1] = Vec2(46, 32), [2] = 1},
        { [1] = Vec2(46, 32), [2] = 1},
        { [1] = Vec2(44, 30), [2] = 1},
        { [1] = Vec2(44, 30), [2] = 1},
        { [1] = Vec2(44, 29), [2] = 1},
        { [1] = Vec2(44, 29), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(25, 58), [2] = 0},
        { [1] = Vec2(26, 58), [2] = 1},
        { [1] = Vec2(26, 58), [2] = 1},
        { [1] = Vec2(27, 58), [2] = 1},
        { [1] = Vec2(27, 58), [2] = 1},
        { [1] = Vec2(31, 58), [2] = 1},
        { [1] = Vec2(31, 58), [2] = 1},
        { [1] = Vec2(38, 59), [2] = 1},
        { [1] = Vec2(38, 59), [2] = 1},
        { [1] = Vec2(40, 59), [2] = 1},
        { [1] = Vec2(40, 59), [2] = 1},
        { [1] = Vec2(43, 59), [2] = 1},
        { [1] = Vec2(43, 59), [2] = 1},
        { [1] = Vec2(45, 58), [2] = 1},
        { [1] = Vec2(45, 58), [2] = 1},
        { [1] = Vec2(45, 58), [2] = 1},
        { [1] = Vec2(45, 58), [2] = 1},
        { [1] = Vec2(47, 58), [2] = 1},
        { [1] = Vec2(47, 58), [2] = 1},
        { [1] = Vec2(49, 58), [2] = 1},
        { [1] = Vec2(49, 58), [2] = 1},
        { [1] = Vec2(51, 58), [2] = 1},
        { [1] = Vec2(51, 58), [2] = 1},
        { [1] = Vec2(53, 59), [2] = 1},
        { [1] = Vec2(53, 59), [2] = 1},
        { [1] = Vec2(54, 59), [2] = 1},
        { [1] = Vec2(54, 59), [2] = 1},
        { [1] = Vec2(55, 59), [2] = 1},
        { [1] = Vec2(55, 59), [2] = 1},
        { [1] = Vec2(57, 59), [2] = 1},
        { [1] = Vec2(57, 59), [2] = 1},
        { [1] = Vec2(59, 58), [2] = 1},
        { [1] = Vec2(59, 58), [2] = 1},
        { [1] = Vec2(60, 58), [2] = 1},
        { [1] = Vec2(60, 58), [2] = 1},
        { [1] = Vec2(61, 58), [2] = 1},
        { [1] = Vec2(61, 58), [2] = 1},
        { [1] = Vec2(62, 58), [2] = 1},
        { [1] = Vec2(62, 58), [2] = 1},
        { [1] = Vec2(62, 58), [2] = 1},
        { [1] = Vec2(62, 58), [2] = 1},
        { [1] = Vec2(63, 58), [2] = 1},
        { [1] = Vec2(63, 58), [2] = 1},
        { [1] = Vec2(65, 58), [2] = 1},
        { [1] = Vec2(65, 58), [2] = 1},
        { [1] = Vec2(66, 58), [2] = 1},
        { [1] = Vec2(66, 58), [2] = 1},
        { [1] = Vec2(66, 58), [2] = 1},
        { [1] = Vec2(66, 58), [2] = 1},
        { [1] = Vec2(67, 58), [2] = 1},
        { [1] = Vec2(67, 58), [2] = 1},
        { [1] = Vec2(69, 58), [2] = 1},
        { [1] = Vec2(69, 58), [2] = 1},
        { [1] = Vec2(69, 58), [2] = 1},
        { [1] = Vec2(69, 58), [2] = 1},
        { [1] = Vec2(70, 58), [2] = 1},
        { [1] = Vec2(70, 58), [2] = 1},
        { [1] = Vec2(71, 58), [2] = 1},
        { [1] = Vec2(71, 58), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(71, 79), [2] = 0},
        { [1] = Vec2(71, 77), [2] = 1},
        { [1] = Vec2(71, 77), [2] = 1},
        { [1] = Vec2(71, 75), [2] = 1},
        { [1] = Vec2(71, 75), [2] = 1},
        { [1] = Vec2(72, 70), [2] = 1},
        { [1] = Vec2(72, 70), [2] = 1},
        { [1] = Vec2(72, 67), [2] = 1},
        { [1] = Vec2(72, 67), [2] = 1},
        { [1] = Vec2(72, 64), [2] = 1},
        { [1] = Vec2(72, 64), [2] = 1},
        { [1] = Vec2(71, 61), [2] = 1},
        { [1] = Vec2(71, 61), [2] = 1},
        { [1] = Vec2(70, 59), [2] = 1},
        { [1] = Vec2(70, 59), [2] = 1},
        { [1] = Vec2(70, 56), [2] = 1},
        { [1] = Vec2(70, 56), [2] = 1},
        { [1] = Vec2(70, 54), [2] = 1},
        { [1] = Vec2(70, 54), [2] = 1},
        { [1] = Vec2(70, 53), [2] = 1},
        { [1] = Vec2(70, 53), [2] = 1},
        { [1] = Vec2(70, 52), [2] = 1},
        { [1] = Vec2(70, 52), [2] = 1},
        { [1] = Vec2(71, 51), [2] = 1},
        { [1] = Vec2(71, 51), [2] = 1},
        { [1] = Vec2(71, 50), [2] = 1},
        { [1] = Vec2(71, 50), [2] = 1},
        { [1] = Vec2(71, 48), [2] = 1},
        { [1] = Vec2(71, 48), [2] = 1},
        { [1] = Vec2(71, 48), [2] = 1},
        { [1] = Vec2(71, 48), [2] = 1},
        { [1] = Vec2(71, 46), [2] = 1},
        { [1] = Vec2(71, 46), [2] = 1},
        { [1] = Vec2(71, 45), [2] = 1},
        { [1] = Vec2(71, 45), [2] = 1},
        { [1] = Vec2(71, 44), [2] = 1},
        { [1] = Vec2(71, 44), [2] = 1},
        { [1] = Vec2(71, 43), [2] = 1},
        { [1] = Vec2(71, 43), [2] = 1},
        { [1] = Vec2(71, 41), [2] = 1},
        { [1] = Vec2(71, 41), [2] = 1},
        { [1] = Vec2(71, 41), [2] = 1},
        { [1] = Vec2(71, 41), [2] = 1},
        { [1] = Vec2(71, 39), [2] = 1},
        { [1] = Vec2(71, 39), [2] = 1},
        { [1] = Vec2(71, 38), [2] = 1},
        { [1] = Vec2(71, 38), [2] = 1},
        { [1] = Vec2(71, 36), [2] = 1},
        { [1] = Vec2(71, 36), [2] = 1},
        { [1] = Vec2(71, 34), [2] = 1},
        { [1] = Vec2(71, 34), [2] = 1},
        { [1] = Vec2(71, 34), [2] = 1},
        { [1] = Vec2(71, 34), [2] = 1},
        { [1] = Vec2(71, 32), [2] = 1},
        { [1] = Vec2(71, 32), [2] = 1},
        { [1] = Vec2(71, 32), [2] = 1},
        { [1] = Vec2(71, 32), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(132, 75), [2] = 0},
        { [1] = Vec2(132, 75), [2] = 1},
        { [1] = Vec2(132, 75), [2] = 1},
        { [1] = Vec2(132, 75), [2] = 1},
        { [1] = Vec2(132, 75), [2] = 1},
        { [1] = Vec2(130, 75), [2] = 1},
        { [1] = Vec2(130, 75), [2] = 1},
        { [1] = Vec2(128, 75), [2] = 1},
        { [1] = Vec2(128, 75), [2] = 1},
        { [1] = Vec2(128, 75), [2] = 1},
        { [1] = Vec2(128, 75), [2] = 1},
        { [1] = Vec2(126, 75), [2] = 1},
        { [1] = Vec2(126, 75), [2] = 1},
        { [1] = Vec2(125, 75), [2] = 1},
        { [1] = Vec2(125, 75), [2] = 1},
        { [1] = Vec2(123, 75), [2] = 1},
        { [1] = Vec2(123, 75), [2] = 1},
        { [1] = Vec2(123, 75), [2] = 1},
        { [1] = Vec2(123, 75), [2] = 1},
        { [1] = Vec2(121, 76), [2] = 1},
        { [1] = Vec2(121, 76), [2] = 1},
        { [1] = Vec2(121, 76), [2] = 1},
        { [1] = Vec2(121, 76), [2] = 1},
        { [1] = Vec2(120, 76), [2] = 1},
        { [1] = Vec2(120, 76), [2] = 1},
        { [1] = Vec2(119, 76), [2] = 1},
        { [1] = Vec2(119, 76), [2] = 1},
        { [1] = Vec2(118, 76), [2] = 1},
        { [1] = Vec2(118, 76), [2] = 1},
        { [1] = Vec2(117, 76), [2] = 1},
        { [1] = Vec2(117, 76), [2] = 1},
        { [1] = Vec2(116, 76), [2] = 1},
        { [1] = Vec2(116, 76), [2] = 1},
        { [1] = Vec2(115, 77), [2] = 1},
        { [1] = Vec2(115, 77), [2] = 1},
        { [1] = Vec2(113, 76), [2] = 1},
        { [1] = Vec2(113, 76), [2] = 1},
        { [1] = Vec2(111, 76), [2] = 1},
        { [1] = Vec2(111, 76), [2] = 1},
        { [1] = Vec2(110, 76), [2] = 1},
        { [1] = Vec2(110, 76), [2] = 1},
        { [1] = Vec2(107, 77), [2] = 1},
        { [1] = Vec2(107, 77), [2] = 1},
        { [1] = Vec2(107, 77), [2] = 1},
        { [1] = Vec2(107, 77), [2] = 1},
        { [1] = Vec2(104, 78), [2] = 1},
        { [1] = Vec2(104, 78), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(93, 78), [2] = 0},
        { [1] = Vec2(92, 77), [2] = 1},
        { [1] = Vec2(92, 77), [2] = 1},
        { [1] = Vec2(92, 77), [2] = 1},
        { [1] = Vec2(92, 77), [2] = 1},
        { [1] = Vec2(93, 75), [2] = 1},
        { [1] = Vec2(93, 75), [2] = 1},
        { [1] = Vec2(93, 75), [2] = 1},
        { [1] = Vec2(93, 75), [2] = 1},
        { [1] = Vec2(93, 72), [2] = 1},
        { [1] = Vec2(93, 72), [2] = 1},
        { [1] = Vec2(93, 71), [2] = 1},
        { [1] = Vec2(93, 71), [2] = 1},
        { [1] = Vec2(94, 70), [2] = 1},
        { [1] = Vec2(94, 70), [2] = 1},
        { [1] = Vec2(94, 67), [2] = 1},
        { [1] = Vec2(94, 67), [2] = 1},
        { [1] = Vec2(94, 65), [2] = 1},
        { [1] = Vec2(94, 65), [2] = 1},
        { [1] = Vec2(96, 64), [2] = 1},
        { [1] = Vec2(96, 64), [2] = 1},
        { [1] = Vec2(96, 62), [2] = 1},
        { [1] = Vec2(96, 62), [2] = 1},
        { [1] = Vec2(96, 59), [2] = 1},
        { [1] = Vec2(96, 59), [2] = 1},
        { [1] = Vec2(96, 58), [2] = 1},
        { [1] = Vec2(96, 58), [2] = 1},
        { [1] = Vec2(96, 56), [2] = 1},
        { [1] = Vec2(96, 56), [2] = 1},
        { [1] = Vec2(96, 55), [2] = 1},
        { [1] = Vec2(96, 55), [2] = 1},
        { [1] = Vec2(96, 53), [2] = 1},
        { [1] = Vec2(96, 53), [2] = 1},
        { [1] = Vec2(96, 51), [2] = 1},
        { [1] = Vec2(96, 51), [2] = 1},
        { [1] = Vec2(96, 50), [2] = 1},
        { [1] = Vec2(96, 50), [2] = 1},
        { [1] = Vec2(96, 49), [2] = 1},
        { [1] = Vec2(96, 49), [2] = 1},
        { [1] = Vec2(96, 47), [2] = 1},
        { [1] = Vec2(96, 47), [2] = 1},
        { [1] = Vec2(96, 46), [2] = 1},
        { [1] = Vec2(96, 46), [2] = 1},
        { [1] = Vec2(96, 46), [2] = 1},
        { [1] = Vec2(96, 46), [2] = 1},
        { [1] = Vec2(96, 45), [2] = 1},
        { [1] = Vec2(96, 45), [2] = 1},
        { [1] = Vec2(96, 44), [2] = 1},
        { [1] = Vec2(96, 44), [2] = 1},
        { [1] = Vec2(96, 42), [2] = 1},
        { [1] = Vec2(96, 42), [2] = 1},
        { [1] = Vec2(97, 41), [2] = 1},
        { [1] = Vec2(97, 41), [2] = 1},
        { [1] = Vec2(96, 39), [2] = 1},
        { [1] = Vec2(96, 39), [2] = 1},
        { [1] = Vec2(96, 39), [2] = 1},
        { [1] = Vec2(96, 39), [2] = 1},
        { [1] = Vec2(96, 38), [2] = 1},
        { [1] = Vec2(96, 38), [2] = 1},
        { [1] = Vec2(96, 37), [2] = 1},
        { [1] = Vec2(96, 37), [2] = 1},
        { [1] = Vec2(96, 36), [2] = 1},
        { [1] = Vec2(96, 36), [2] = 1},
        { [1] = Vec2(96, 35), [2] = 1},
        { [1] = Vec2(96, 35), [2] = 1},
        { [1] = Vec2(96, 34), [2] = 1},
        { [1] = Vec2(96, 34), [2] = 1},
        { [1] = Vec2(96, 34), [2] = 1},
        { [1] = Vec2(96, 34), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(96, 34), [2] = 0},
        { [1] = Vec2(96, 34), [2] = 1},
        { [1] = Vec2(96, 34), [2] = 1},
        { [1] = Vec2(98, 33), [2] = 1},
        { [1] = Vec2(98, 33), [2] = 1},
        { [1] = Vec2(100, 34), [2] = 1},
        { [1] = Vec2(100, 34), [2] = 1},
        { [1] = Vec2(103, 34), [2] = 1},
        { [1] = Vec2(103, 34), [2] = 1},
        { [1] = Vec2(105, 34), [2] = 1},
        { [1] = Vec2(105, 34), [2] = 1},
        { [1] = Vec2(107, 34), [2] = 1},
        { [1] = Vec2(107, 34), [2] = 1},
        { [1] = Vec2(108, 34), [2] = 1},
        { [1] = Vec2(108, 34), [2] = 1},
        { [1] = Vec2(111, 34), [2] = 1},
        { [1] = Vec2(111, 34), [2] = 1},
        { [1] = Vec2(113, 34), [2] = 1},
        { [1] = Vec2(113, 34), [2] = 1},
        { [1] = Vec2(117, 34), [2] = 1},
        { [1] = Vec2(117, 34), [2] = 1},
        { [1] = Vec2(118, 35), [2] = 1},
        { [1] = Vec2(118, 35), [2] = 1},
        { [1] = Vec2(119, 35), [2] = 1},
        { [1] = Vec2(119, 35), [2] = 1},
        { [1] = Vec2(120, 35), [2] = 1},
        { [1] = Vec2(120, 35), [2] = 1},
        { [1] = Vec2(122, 35), [2] = 1},
        { [1] = Vec2(122, 35), [2] = 1},
        { [1] = Vec2(123, 35), [2] = 1},
        { [1] = Vec2(123, 35), [2] = 1},
        { [1] = Vec2(125, 35), [2] = 1},
        { [1] = Vec2(125, 35), [2] = 1},
        { [1] = Vec2(127, 35), [2] = 1},
        { [1] = Vec2(127, 35), [2] = 1},
        { [1] = Vec2(129, 35), [2] = 1},
        { [1] = Vec2(129, 35), [2] = 1},
        { [1] = Vec2(129, 35), [2] = 1},
        { [1] = Vec2(129, 35), [2] = 1},
        { [1] = Vec2(130, 35), [2] = 1},
        { [1] = Vec2(130, 35), [2] = 1},
        { [1] = Vec2(131, 35), [2] = 1},
        { [1] = Vec2(131, 35), [2] = 1},
        { [1] = Vec2(132, 35), [2] = 1},
        { [1] = Vec2(132, 35), [2] = 1},
        { [1] = Vec2(132, 35), [2] = 1},
        { [1] = Vec2(132, 35), [2] = 1},
        { [1] = Vec2(132, 34), [2] = 1},
        { [1] = Vec2(132, 34), [2] = 1},
        { [1] = Vec2(134, 34), [2] = 1},
        { [1] = Vec2(134, 34), [2] = 1},
        { [1] = Vec2(134, 34), [2] = 1},
        { [1] = Vec2(134, 34), [2] = 1},
        { [1] = Vec2(135, 35), [2] = 1},
        { [1] = Vec2(135, 35), [2] = 1},
        { [1] = Vec2(135, 35), [2] = 1},
        { [1] = Vec2(135, 35), [2] = 1},
        { [1] = Vec2(135, 35), [2] = 1},
        { [1] = Vec2(135, 35), [2] = 1},
        { [2] = 2},
        { [1] = Vec2(127, 38), [2] = 0},
        { [1] = Vec2(126, 38), [2] = 1},
        { [1] = Vec2(126, 38), [2] = 1},
        { [1] = Vec2(126, 40), [2] = 1},
        { [1] = Vec2(126, 40), [2] = 1},
        { [1] = Vec2(126, 43), [2] = 1},
        { [1] = Vec2(126, 43), [2] = 1},
        { [1] = Vec2(126, 46), [2] = 1},
        { [1] = Vec2(126, 46), [2] = 1},
        { [1] = Vec2(126, 49), [2] = 1},
        { [1] = Vec2(126, 49), [2] = 1},
        { [1] = Vec2(126, 51), [2] = 1},
        { [1] = Vec2(126, 51), [2] = 1},
        { [1] = Vec2(127, 52), [2] = 1},
        { [1] = Vec2(127, 52), [2] = 1},
        { [1] = Vec2(127, 54), [2] = 1},
        { [1] = Vec2(127, 54), [2] = 1},
        { [1] = Vec2(127, 55), [2] = 1},
        { [1] = Vec2(127, 55), [2] = 1},
        { [1] = Vec2(126, 57), [2] = 1},
        { [1] = Vec2(126, 57), [2] = 1},
        { [1] = Vec2(126, 57), [2] = 1},
        { [1] = Vec2(126, 57), [2] = 1},
        { [1] = Vec2(126, 59), [2] = 1},
        { [1] = Vec2(126, 59), [2] = 1},
        { [1] = Vec2(127, 59), [2] = 1},
        { [1] = Vec2(127, 59), [2] = 1},
        { [1] = Vec2(128, 60), [2] = 1},
        { [1] = Vec2(128, 60), [2] = 1},
        { [1] = Vec2(128, 60), [2] = 1},
        { [1] = Vec2(128, 60), [2] = 1},
        { [1] = Vec2(128, 61), [2] = 1},
        { [1] = Vec2(128, 61), [2] = 1},
        { [1] = Vec2(128, 62), [2] = 1},
        { [1] = Vec2(128, 62), [2] = 1},
        { [1] = Vec2(128, 63), [2] = 1},
        { [1] = Vec2(128, 63), [2] = 1},
        { [1] = Vec2(128, 64), [2] = 1},
        { [1] = Vec2(128, 64), [2] = 1},
        { [1] = Vec2(128, 64), [2] = 1},
        { [1] = Vec2(128, 64), [2] = 1},
        { [1] = Vec2(128, 66), [2] = 1},
        { [1] = Vec2(128, 66), [2] = 1},
        { [1] = Vec2(128, 67), [2] = 1},
        { [1] = Vec2(128, 67), [2] = 1},
        { [1] = Vec2(128, 68), [2] = 1},
        { [1] = Vec2(128, 68), [2] = 1},
        { [1] = Vec2(128, 69), [2] = 1},
        { [1] = Vec2(128, 69), [2] = 1},
        { [1] = Vec2(128, 71), [2] = 1},
        { [1] = Vec2(128, 71), [2] = 1},
        { [1] = Vec2(128, 72), [2] = 1},
        { [1] = Vec2(128, 72), [2] = 1},
        { [1] = Vec2(128, 72), [2] = 1},
        { [1] = Vec2(128, 72), [2] = 1},
        { [1] = Vec2(127, 74), [2] = 1},
        { [1] = Vec2(127, 74), [2] = 1},
        { [1] = Vec2(127, 74), [2] = 1},
        { [1] = Vec2(127, 74), [2] = 1},
        { [1] = Vec2(127, 76), [2] = 1},
        { [1] = Vec2(127, 76), [2] = 1},
        { [1] = Vec2(127, 76), [2] = 1},
        { [1] = Vec2(127, 76), [2] = 1},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
        { [2] = 2},
    }}
else nil;

local PosData = if PlaceId == 96354063422506 then
    {
        [84409295758845] = CFr(-143.767456, -428.060516, 9491.1709, -0.0363359451, 0.987019658, -0.156434745, -2.8014183e-05, 0.156537116, 0.987672091, 0.999339581, 0.0358923674, -0.00566029549);
        [93963747744009] = CFr(73.5488281, -428.060516, 9490.5332, 0.0363359451, -0.987019658, 0.156434745, -2.8014183e-05, 0.156537116, 0.987672091, -0.999339581, -0.0358923674, 0.00566029549);
        [122150789929023] = CFr(94.8284683, -428.081146, 9343.37988, -0.991967916, -0.124959722, 0.0196113847, -0.000189460596, 0.1565115, 0.987676024, -0.126489133, 0.979739308, -0.155278072);
        [122395053342077] = CFr(-175.4365234375, -428.0605163574219, 9507.7236328125, 0.03633594512939453, -0.9870196580886841, 0.15643474459648132, -0.000028014183044433594, 0.15653711557388306, 0.9876720905303955, -0.9993395805358887, -0.035892367362976074, 0.005660295486450195);
    }
else nil;

return {
    Version = "TheMimicV3.Extra.Paintings";
    Function = function()
        return {
            Paints = PaintingDatas;
            Poses = PosData;
        };
    end;
};

end

Modules.Legacy = function(GG)
-- Slate / Book2: extracted from user-supplied TheMimicV3.D11.
-- Generated by tools/extract_legacy.py. Runtime and UI are injected by the bootstrap.
local GG = assert(GG, "Slate bootstrap context is required");

local QUEUE_INFO = GG.QUEUE_INFO or {};
local ScriptCache = GG.ScriptCache;
local LoaderSettings = GG.LoaderSettings;
local userIdentify = ScriptCache.userIdentify;
local LowerC = hookfunction or hookfunc;
local GetService = game.GetService;
local Instancen = Instance.new;
local Vec3 = Vector3.new;
local str = string;
local tble = table;
local Col3 = Color3;
local tk = GG.Task or task;

local TeleportService = GetService(game, "TeleportService");
local R = GetService(game, "ReplicatedStorage");
local H = GetService(game, "RunService");
local W = GetService(game, "Workspace");
local P = GetService(game, "Players");
local S = GetService(game, "Stats");

local IsA = game.IsA;
local twait = tk.wait;
local CFr = CFrame.new;
local Vec3 = Vector3.new;
local PivotTo = W.PivotTo;
local mfloor = math.floor;
local tblef = tble.find;
local strfind = str.find;
local tblein = tble.insert;
local GetPivot = W.GetPivot;
local GetChildren = game.GetChildren;
local GetAttribute = game.GetAttribute;
local WaitForChild = game.WaitForChild;
local GetDescendants = game.GetDescendants;
local FindFirstChild = game.FindFirstChild;
local PropChangeSignal = game.GetPropertyChangedSignal;
local FindFirstChildOfClass = game.FindFirstChildOfClass;
local FindFirstChildWhichIsA = game.FindFirstChildWhichIsA;
local GetAttributeChangedSignal = game.GetAttributeChangedSignal;

local VEC3 = Vec3(3,3,3);
local VEC2 = Vec3(2,2,2);
local VEC252 = Vec3(2,5,2);
local VEC10 = Vec3(10, 10, 10);
local CFR9E9 = CFr(0, 9e9, 0);
local RED = Col3.fromRGB(255, 0, 0);
local BLUE = Col3.fromRGB(0, 0, 255);
local GREEN = Col3.fromRGB(0, 255, 0);
local YELLOW = Col3.fromRGB(255, 255, 0);
local WHITE = Col3.fromRGB(255, 255, 255);
local PURPLE = Col3.fromRGB(77, 23, 129);
local DIM0010 = UDim2.new(0,0,1,0);
local EMPTY_OBJECT = {Parent=nil, SeatPart=nil};
local PERSISTENT = Enum.ModelStreamingMode.Persistent;

local HUGE99 = 30;

local PlaceId = game.PlaceId;

local ScriptData = {Sections = {}};
local Config = GG.Configs or {};

Config.Client = Config.Client or {};
Config.Client.Client = Config.Client.Client or {};
Config.Yen = Config.Yen or {};
Config.B2C1 = Config.B2C1 or {};
Config.B2C1.City = Config.B2C1.City or {};
Config.B2C1.City.ESP = Config.B2C1.City.ESP or {};
Config.B2C1.Rat = Config.B2C1.Rat or {};
Config.B2C1.Rat.ESP = Config.B2C1.Rat.ESP or {};
Config.B2C1.Village = Config.B2C1.Village or {};
Config.B2C1.Village.ESP = Config.B2C1.Village.ESP or {};
Config.B2C1.Ship = Config.B2C1.Ship or {};
Config.B2C1.Ship.ESP = Config.B2C1.Ship.ESP or {};
Config.B2C2 = Config.B2C2 or {};
Config.B2C2.Meat = Config.B2C2.Meat or {};
Config.B2C2.Meat.ESP = Config.B2C2.Meat.ESP or {};
Config.B2C2.Lever = Config.B2C2.Lever or {};
Config.B2C2.Lever.ESP = Config.B2C2.Lever.ESP or {};
Config.B2C2.Cook = Config.B2C2.Cook or {};
Config.B2C2.Kid = Config.B2C2.Kid or {};
Config.B2C2.Kid.ESP = Config.B2C2.Kid.ESP or {};
Config.B2C2.Nagisa = Config.B2C2.Nagisa or {};
Config.B2C3 = Config.B2C3 or {};
Config.B2C3.Maze = Config.B2C3.Maze or {};
Config.B2C3.Maze.ESP = Config.B2C3.Maze.ESP or {};
Config.B2C3.Larves = Config.B2C3.Larves or {};
Config.B2C3.Larves.ESP = Config.B2C3.Larves.ESP or {};
Config.B2C3.Boss = Config.B2C3.Boss or {};
Config.B2C4 = Config.B2C4 or {};
Config.B2C4.City = Config.B2C4.City or {};
Config.B2C4.City.ESP = Config.B2C4.City.ESP or {};
Config.B2C4.Mall = Config.B2C4.Mall or {};
Config.B2C4.Mall.ESP = Config.B2C4.Mall.ESP or {};
Config.B2C4.Draw = Config.B2C4.Draw or {};
Config.B2C4.Draw.ESP = Config.B2C4.Draw.ESP or {};
Config.B2C4.Enzukai = Config.B2C4.Enzukai or {};
Config.B2C4.Enzukai.ESP = Config.B2C4.Enzukai.ESP or {};
Config.B2C4.Final = Config.B2C4.Final or {};

return {
    Version = "TheMimicV3.D11";
    Function = function(CorePackage, WindLib, IntroLib, Windy, ClientPackage, CoruTask, CommonF, ESPF, PromptPackage, DownloadPackage, QueuePack)
        local CoreConnection    = {};
        local CoreDestroyed     = false;
        local ForceFloat        = "None";

        local Cam               = W.CurrentCamera;
        local selff             = P.LocalPlayer;
        local PSG               = selff.PlayerGui;
        local BP                = selff.Backpack or EMPTY_OBJECT;
        local selc              = selff.Character or EMPTY_OBJECT;
        local HumSelf           = selc.Parent and FindFirstChildOfClass(selc, "Humanoid") or EMPTY_OBJECT;
        local HumRSelf          = HumSelf.RootPart or EMPTY_OBJECT;
        local PSS               = WaitForChild(selff, "PlayerScripts", HUGE99);


        local ClientCon         = Config.Client.Client;
        local YenCon            = Config.Yen;
        local B2C1Con           = Config.B2C1;
        local B2C2Con           = Config.B2C2;
        local B2C3Con           = Config.B2C3;
        local B2C4Con           = Config.B2C4;
        local ArgsCraft         = {[1] = 0;[2] = {["__args"] = {};["__tree"] = {[1] = "CraftingService";[2] = "Interact"};["__callType"] = 0}};

        local Chapter           = if PlaceId == 6296321810 or PlaceId == 6479231833 or PlaceId == 6301638949 or PlaceId == 6480994221 then "B1C1"
                                  elseif PlaceId == 6373539583 or PlaceId == 6485055338 or PlaceId == 6406571212 or PlaceId == 6485055836 or PlaceId == 6425178683 or PlaceId == 6485056556 then "B1C2"
                                  elseif PlaceId == 6472459099 or PlaceId == 6688734180 or PlaceId == 6682163754 or PlaceId == 6688734313 or PlaceId == 6682164423 or PlaceId == 6688734395 then "B1C3"
                                  elseif PlaceId == 7251865082 or PlaceId == 7265396387 or PlaceId == 7251866503 or PlaceId == 7265396805 or PlaceId == 7251867155 or PlaceId == 7265397072 or PlaceId == 7251867574 or PlaceId == 7265397848 then "B1C4"
                                  elseif PlaceId == 8056702588 then "B2C1"
                                  elseif PlaceId == 13489800654 then "B2C2"
                                  elseif PlaceId == 15962819441 then "B2C3"
                                  elseif PlaceId == 96354063422506 then "B2C4"
                                  elseif PlaceId == 128715637193371 then "B3C1"
                                  elseif PlaceId == 7618863566 then "Jigoku"
                                  elseif PlaceId == 7068738088 or PlaceId == 7068951438 or PlaceId == 7068739000 or PlaceId == 7068951914 or PlaceId == 7068740106 or PlaceId == 7068952294 then "WitchTrial"
                                  elseif PlaceId == 7633631103 or PlaceId == 7633631351 or PlaceId == 7633631511 then "HalloweenTrial"
                                  elseif PlaceId == 6243699076 then "Lobby"
                                  elseif PlaceId == 7068737459 then "GLobby"
                                  else nil;

        local AllowedChapters = {["B2C1"] = true; ["B2C2"] = true; ["B2C3"] = true; ["B2C4"] = true};
        if not Chapter or not AllowedChapters[Chapter] then
            return function()
                warn("[Slate / Book2] This place is not supported by this package: " .. tostring(PlaceId));
                return false, "Unsupported place " .. tostring(PlaceId);
            end;
        end;

        local GameAI, GameAI2   = nil, nil;

        local dist              = CommonF.dist;
        local Tp                = CommonF.Tp;
        local HumanoidEquip     = CommonF.HumanoidEquip;
        local Tween             = CommonF.Tween;
        local Anchored          = CommonF.Anchored;
        local distOf            = CommonF.distOf;

        local RE                = {};
        local REQ               = {};
        local Functions         = {};
        local WindUI;
        local PromptConnections = {};
        local ActionConnections = {};
        local SignalSubscriptions = setmetatable({}, {__mode = "k"});
        local function Subscribe(signal, callback, once)
            local ok, sourceName, sourceLine = pcall(debug.info, callback, "sl");
            local key = ok and (tostring(sourceName) .. ":" .. tostring(sourceLine)) or tostring(callback);
            local subscriptions = SignalSubscriptions[signal];
            if not subscriptions then subscriptions = {}; SignalSubscriptions[signal] = subscriptions; end;
            local existing = subscriptions[key];
            if existing and existing.Connected then return existing; end;
            local function wrapped(...)
                if CoreDestroyed then return; end;
                if GG.Dispatch then return GG.Dispatch(callback, ...); end;
                return callback(...);
            end;
            local connection = if once then signal:Once(wrapped) else signal:Connect(wrapped);
            subscriptions[key] = connection;
            ActionConnections[#ActionConnections + 1] = connection;
            return connection;
        end;
        local function TrackSignal(signal, callback) return Subscribe(signal, callback, false); end;
        local function TrackOnce(signal, callback) return Subscribe(signal, callback, true); end;
        local function StopActions()
            for _, connection in pairs(ActionConnections) do pcall(function() connection:Disconnect(); end); end;
            for _, connection in pairs(PromptConnections) do pcall(function() connection:Disconnect(); end); end;
            table.clear(ActionConnections); table.clear(PromptConnections); table.clear(SignalSubscriptions);
            ForceFloat = "None";
            if Functions.FreeCam then pcall(function() Functions:FreeCam(false); end); end;
            if ClientPackage.UpdatePosition then ClientPackage.UpdatePosition(false, "None", HumRSelf); end;
        end;
        local function Cleanup()
            if CoreDestroyed then return; end;
            CoreDestroyed = true; ForceFloat = "None";
            StopActions();
            for _, connection in pairs(CoreConnection) do pcall(function() connection:Disconnect(); end); end;
            table.clear(CoreConnection);
        end;
        if GG.RegisterCleanup then GG.RegisterCleanup(Cleanup); end;


        Functions.PairingSections = function(self, data)
            if not self.PackSections and data[Chapter] then
                local PackSections = {Tabs={}};
                local GroupDat = {};
                local ActiveMap = {
                    [6373539583] = 1, [6485055338] = 1, [6406571212] = 2, [6485055836] = 2,
                    [6425178683] = 3, [6485056556] = 3, [6472459099] = 1, [6688734180] = 1,
                    [6682163754] = 2, [6688734313] = 2, [6682164423] = 3, [6688734395] = 3,
                };
                local WantedMap = ActiveMap[PlaceId];

                for i=1, #data[Chapter] do
                    if WantedMap and i ~= WantedMap then continue; end;
                    local sec=data[Chapter][i];
                    if not sec or not sec.dat then continue; end;
                    for i2=1, #sec.dat do
                        tblein(GroupDat, {
                            type = "Button";
                            EN = sec.dat[i2].i;
                            Callback = function()
                                Tp(HumRSelf, sec.dat[i2].C);
                            end;
                        });
                    end;
                end;
                
                PackSections.Tabs = {{
                    Tab={at="Section", Title="Sections", Icon="map-pinned", Path=Chapter}, Data=GroupDat
                }}; self.PackSections = PackSections;
            end;

            return LoaderSettings.TheMimicLoader.Load_Sections and self.PackSections or {};
        end;

        Functions.GetPing = function()
            local ok, ping = pcall(function() return S.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000; end);
            return ok and ping or 0.1;
        end;

        Functions.GameValidate = function(self)
            local function disable(parent, name)
                local child = parent and FindFirstChild(parent, name);
                if child and child:IsA("LocalScript") then child.Enabled = false; end;
            end;
            if Chapter == "Lobby" then disable(selc, "AntiFly"); end;
            if Chapter == "B1C4" or Chapter == "WitchTrial" then
                disable(PSS, "Anti-Fly"); disable(PSS, "Anti-Speed");
            end;
            local toolNames = {
                B1C4 = {"Katana", "Katana"}, B2C3 = {"BoneSword", "Bone Sword"},
                B2C4 = {"Bow", "SpiritBow"}, B3C1 = {"Gun", "Gun"},
            };
            local tool = toolNames[Chapter];
            if tool then
                self[tool[1]] = FindFirstChild(BP, tool[2]) or FindFirstChild(selc, tool[2]);
                if not self[tool[1]] then
                    tk.defer(function()
                        local found = WaitForChild(BP, tool[2], 30);
                        if not CoreDestroyed then self[tool[1]] = found; end;
                    end);
                end;
            end;
            local QuickTime = FindFirstChild(PSG, "QuickTime");
            self.GrabbedUI = QuickTime and FindFirstChild(QuickTime, "GrabbedUI");
            if self.AlreadyInit then return; end;
            self.AlreadyInit = true;
            if Chapter == "B2C1" or Chapter == "B2C2" then
                -- These chapters scramble object names; inspect the same mapping
                -- as 229, with a finite search and a direct-name fallback.
                tk.spawn(function()
                    if type(getgc) ~= "function" then return; end;
                    local DynamicControl;
                    local deadline = os.clock() + 20;
                    repeat
                        local ok, GCs = pcall(getgc, true);
                        if not ok then break; end;
                        for _, value in ipairs(GCs) do
                            if type(value) == "function" then
                                local infoOK, name = pcall(debug.info, value, "n");
                                if infoOK and name == "DynamicControl" then DynamicControl = value; end;
                            elseif type(value) == "table" and rawget(value, "TakeOver") then
                                self.TakeOver = value;
                            end;
                        end;
                        if DynamicControl and self.TakeOver then break; end;
                        twait(0.5);
                    until CoreDestroyed or os.clock() > deadline;
                    if CoreDestroyed or not DynamicControl or type(getupvalues) ~= "function" then return; end;
                    local ok, UPs = pcall(getupvalues, DynamicControl);
                    if not ok then return; end;
                    for _, f1 in pairs(UPs) do
                        if type(f1) == "function" then
                            local good, UPs2 = pcall(getupvalues, f1);
                            if good then
                                for _, value in pairs(UPs2) do
                                    if type(value) == "table" and (rawget(value, "Interactable") or rawget(value, "Safe")) then
                                        self.u18 = value; self.B2C1Cache = {}; return;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end);
            elseif Chapter == "B2C3" then
                self.GameMode = GetAttribute(W, "GamemodeMode");
                CoreConnection[#CoreConnection + 1] = GetAttributeChangedSignal(W, "GamemodeMode"):Connect(function()
                    self.GameMode = GetAttribute(W, "GamemodeMode");
                end);
                self.OneRunHouseClicked = {};
            elseif Chapter == "B2C4" then
                self.AnsweredMother = {
                    ["cult name?"] = "Kiiroibara Cult", ["I bloom"] = "Cherry Blossom",
                    ["Four I shaped in shadows dire—"] = "Evil God", ["pink"] = " Hiachi Masashige",
                    ["quietly"] = "Torii Gate", ["pathetic"] = "Me", ["in ink"] = "A brush",
                    ["Flames"] = "Enzukai", ["guard"] = "A komainu",
                };
                tk.spawn(function()
                    local Section4 = WaitForChild(W, "Section4", 30);
                    if not Section4 or CoreDestroyed then return; end;
                    for _, entry in ipairs({{"Tsukiya2", "Monster4"}, {"Tenome2", "Monster3"}, {"Rin2", "Monster2"}}) do
                        tk.spawn(function()
                            local folder = WaitForChild(Section4, entry[2], 30);
                            local monster = folder and WaitForChild(folder, entry[1], 30);
                            if not CoreDestroyed then self[entry[1]] = monster; end;
                        end);
                    end;
                end);
            end;
        end;

        Functions.FreeCam = function(self, isFree)
            Cam = W.CurrentCamera;
            if isFree and not self.FreeCamSaved then
                self.FreeCamSaved = {Camera = Cam, Type = Cam.CameraType, Subject = Cam.CameraSubject, CFrame = Cam.CFrame};
            end;
            if self.TakeOver then pcall(function() self.TakeOver:TakeOver(not isFree); end); end;
            if isFree and Chapter == "B2C1" then Cam.CameraType = Enum.CameraType.Scriptable; end;
            if not isFree and self.FreeCamSaved then
                local saved = self.FreeCamSaved; self.FreeCamSaved = nil;
                pcall(function()
                    saved.Camera.CameraType = saved.Type;
                    saved.Camera.CameraSubject = saved.Subject;
                    saved.Camera.CFrame = saved.CFrame;
                end);
            end;
        end;

        Functions.FreeYourself = function(self)
            if not self.GrabbedUI or not self.GrabbedUI.Visible then
                return;
            end; CommonF:CKey(Enum.KeyCode.E, 0.03);
        end;

        Functions.FirePrompt = function(self, args)
            local Prompt, EndAt, LookAt = args.Prompt, args.EndAt, args.LookAt;
            if not Prompt or not EndAt or not HumRSelf.Parent then return; end;
            local Max, LineOfSight = Prompt.MaxActivationDistance, Prompt.RequiresLineOfSight;
            local camera = W.CurrentCamera;
            local CameraType, CameraSubject, CameraCFrame = camera.CameraType, camera.CameraSubject, camera.CFrame;
            local ok, failure = pcall(function()
                Prompt.MaxActivationDistance = 250;
                Prompt.RequiresLineOfSight = false;
                self:FreeCam(true);
                if LookAt then camera.CFrame = CFr(EndAt.Position, LookAt); end;
                Tp(HumRSelf, EndAt, 0.3);
                Prompt:InputHoldBegin(); H.RenderStepped:Wait();
                if args.Safe then Tp(HumRSelf, args.Safe); end;
                local duration = math.max(0, Prompt.HoldDuration);
                tk.delay(math.max(0, duration - 0.2), function()
                    if not CoreDestroyed and HumRSelf.Parent then Tp(HumRSelf, EndAt); end;
                end);
                twait(duration); Prompt:InputHoldEnd(); twait(0.1);
            end);
            pcall(function() Prompt:InputHoldEnd(); Prompt.MaxActivationDistance = Max; Prompt.RequiresLineOfSight = LineOfSight; end);
            pcall(function() self:FreeCam(false); end);
            if camera.Parent then
                camera.CameraType, camera.CameraSubject, camera.CFrame = CameraType, CameraSubject, CameraCFrame;
            end;
            if not ok then error(failure, 0); end;
        end;

        Functions.ToolNow = function(self, index)
            if not selc.Parent then return false; end;
            local Tool = self[index];
            if not Tool or not Tool.Parent then
                local toolNames = {Gun = "Gun", Katana = "Katana", Bow = "SpiritBow", Cutlass = "Cutlass", BoneSword = "Bone Sword"};
                local name = toolNames[index] or index;
                Tool = FindFirstChild(BP, name) or FindFirstChild(selc, name); self[index] = Tool;
            end;
            if Tool and Tool.Parent ~= selc then
                HumanoidEquip(HumSelf, Tool);
            elseif not Tool then
                return false;
            end; return Tool;
        end;

        Functions.ToolActive = function(self, index)
            local Tool = self:ToolNow(index); if Tool then
                return Tool:Activate();
            end; return;
        end;

        Functions.B2C1Validate = function(self, obj, from)
            if self[obj] then return true; end;
            local Connections = getconnections(obj[from]); for i=1, #Connections do
                local vf=Connections[i]; if type(vf.Function) == 'function' then
                    local Cons = getconstants(vf.Function); for ri=1, #Cons do
                        local Con=Cons[ri]; if type(Con) == 'string' then
                            local Lowerest = str.lower(Con);
                            if Lowerest == 'billboardgui' or Lowerest == 'highlight' then
                                debug.setconstant(vf.Function, ri, "TJYS");
                            end;
                        end;
                    end;
                end;
            end; self[obj]=true;
            return self[obj];
        end;

        Functions.B2C1Get = function(self, obj)
            local B2C1Cache = self.B2C1Cache;
            if not B2C1Cache then
                B2C1Cache = {};
                self.B2C1Cache = B2C1Cache;
            end; if B2C1Cache[obj] and not B2C1Cache[obj].Parent then B2C1Cache[obj] = nil; end;
            if not B2C1Cache[obj] then
                local parts = str.split(obj, ".");
                local resolvedParts = {};
                local skipNext = false;
                for i = 1, #parts do
                    if skipNext then
                        skipNext = false;
                    else
                        local part = parts[i];
                        if i < #parts and tonumber(parts[i+1]) and not tonumber(part) then
                            part = part .. "." .. parts[i+1];
                            skipNext = true;
                        end;
                        tblein(resolvedParts, part);
                    end;
                end;
                parts = resolvedParts;

                local current = game;
                local startIdx = 1;
                if parts[1] == "Workspace" or parts[1] == "workspace" then
                    current = W;
                    startIdx = 2;
                end;
                for i = startIdx, #parts do
                    local name = parts[i];
                    local scrambled = self.u18 and self.u18[name] or name;
                    current = current and FindFirstChild(current, scrambled);
                    if not current then break; end;
                end; B2C1Cache[obj] = current;
            end; return B2C1Cache[obj];
        end;

        Functions.B2C1Func = function(self, where)
            if not HumRSelf.Parent then return; end;
            if where == "City/Complete" then
                return Tp(HumRSelf, CFr(-1783, 11, -4297));
            elseif where == "Rat/Book" then
                local Object = self:B2C1Get("Workspace.Section2.BookRead.Book");
                if not Object then return; end; local Interact = FindFirstChild(Object, "Interact");
                local Prox = Interact and FindFirstChildOfClass(Interact, "ProximityPrompt");
                if not Prox or not Prox.Enabled then return; end;
                return Tp(HumRSelf, Interact.CFrame, 0.3), fireproximityprompt(Prox);
            elseif where == "Rat/Rat" then
                local Object = self:B2C1Get("Workspace.Section2.Rats");
                local Well = self:B2C1Get("Workspace.Section2.Interactable.PoisonedWell.ProximityPrompt");
                local Bell = self:B2C1Get("Workspace.Section2.Interactable.Bell.ProximityPrompt");
                if not Object or not Well or not Bell then return; end;
                local CHs = GetChildren(Object); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "Cube");
                        Prox = Prox and FindFirstChildOfClass(Prox, "ProximityPrompt");
                        if not Prox then continue; end;
                        Tp(HumRSelf, Prox.Parent.CFrame, 0.3)
                        fireproximityprompt(Prox);
                        Tp(HumRSelf, Well.Parent.CFrame, 0.3);
                        fireproximityprompt(Well); twait(5);
                        Tp(HumRSelf, Bell.Parent.CFrame, 0.3);
                        fireproximityprompt(Bell); break;
                    end;
                end;
            elseif where == "Rat/Exit" then
                local Object = self:B2C1Get("Workspace.Section2.Interactable.Exit.ProximityPrompt");
                if not Object or not Object.Enabled then return; end;
                Tp(HumRSelf, Object.Parent.CFrame, 0.3); fireproximityprompt(Object);
            elseif where == "Rat/Run" then
                Tween({primary = HumRSelf; goal = { CFrame = CFr(-960.842529, -44.0736237, -3597.06372) }});
            elseif where == "Nagisa/Auto" then
                ForceFloat = true; CommonF.Tween({ primary = HumRSelf; goal = { CFrame = CFr(208.665894, 573.239563, -345.685211) } });
                twait(3); CommonF.Tween({ primary = HumRSelf; goal = { CFrame = CFr(595.243896, 582.230713, -344.577911) } }); ForceFloat = "None";
            elseif where == "Nagisa/Run" then
                ForceFloat = true; CommonF.Tween({ primary = HumRSelf; goal = { CFrame = CFr(3868.31982, 153.007477, 17.1698914) } }); ForceFloat = "None";
            elseif where == "Vil/Zone" then
                Tween({primary = HumRSelf; goal = { CFrame = CFr(4590.5249, 507.557373, 4480.6499) }});
            elseif where == "Vil/Talk" then
                Tp(HumRSelf, CFr(-326.344421, 23.1051254, 3662.32056));
            elseif where == "Vil/Key" then
                Tp(HumRSelf, CFr(-401.797424, 3070.25, 3864.77979), 1);
                local Object = self:B2C1Get("Workspace.Section4");
                if not Object then return; end;
                local Items = FindFirstChild(Object, "Items");
                local Key = Items and FindFirstChild(Items, "Key1");
                local Prox = Key and FindFirstChildOfClass(Key, "ProximityPrompt");
                if not Prox then return; end;
                Tp(HumRSelf, Key.CFrame, 0.3); fireproximityprompt(Prox);
            elseif where == "Vil/PaintTp" then
                Tp(HumRSelf, CFr(-249.45462, 3067.58838, 4218.84766));
            elseif where == "Vil/Pics" then
                local Object = self:B2C1Get("Workspace.Section4.Puzzle.Hints");
                if not Object then return; end; local CHs = GetChildren(Object);
                
                if not self.Hints or not self.Hints.Connected then
                    self.Hints = TrackSignal(Object.ChildAdded, function(v)
                        if v.ClassName == "Model" then
                            v.ModelStreamingMode = PERSISTENT;
                        end;
                    end);

                    for i=1, #CHs do
                        local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                            v.ModelStreamingMode = PERSISTENT;
                        end;
                    end;

                    self.Cords = {
                        CFr(-267.697571, 3070.85718, 4213.41504),
                        CFr(590.236572, 3070.94922, 4420.93457),
                        CFr(-675.159424, 3071.0813, 4998.77686),
                        CFr(-392.277039, 3071.03931, 3888.39697),
                        CFr(-10.6637068, 3070.17041, 4711.52637),
                    };
                end;

                for i=1, #self.Cords do
                    local v=self.Cords[i];
                    Tp(HumRSelf, v, 2);
                end;
            elseif where == "Vil/House" then
                local Object = self:B2C1Get("Workspace.Section4.HouseTeleporters.MainHouse.Enter.Teleporter.ProximityPrompt");
                if not Object or not Object.Enabled then return; end;
                Tp(HumRSelf, Object.Parent.CFrame, 0.3); for i=1, 2 do
                    fireproximityprompt(Object); twait(0.3);
                end;
            elseif where == "Vil/Candle" then
                local Hints = self:B2C1Get("Workspace.Section4.Puzzle.Hints");
                local Images = self:B2C1Get("Workspace.Section4.Puzzle.Frames");
                local Candles = self:B2C1Get("Workspace.Section4.Puzzle.Candles");
                if not Hints or not Images or not Candles then return; end;
                local Orb = self:B2C1Get("Workspace.Section4.Puzzle.Gem.Seishin.Orb.ProximityPrompt");
                if not Orb then
                    local Pics4, Names = {}, {};
                    local CHs = GetChildren(Hints); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local Image = FindFirstChild(v, "Image");
                            if not Image then continue; end;
                            tblein(Pics4, Image.Decal.Texture);
                        end;
                    end;

                    CHs = GetChildren(Images); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local Image = FindFirstChild(v, "Image");
                            if not Image then continue; end;
                            if tblef(Pics4, Image.Decal.Texture) then
                                tblein(Names, v.Name);
                            end;
                        end;
                    end;

                    CHs = GetChildren(Candles); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            if tblef(Names, v.Name) then
                                local Candle = FindFirstChild(v, "Candle");
                                local Wax = Candle and FindFirstChild(Candle, "Wax");
                                local Prox = Wax and FindFirstChildOfClass(Wax, "ProximityPrompt");
                                if not Prox or not Prox.Enabled then continue; end;
                                Tp(HumRSelf, Wax.CFrame, 0.3); fireproximityprompt(Prox);
                            end;
                        end;
                    end; twait(1);
                end; Orb = self:B2C1Get("Workspace.Section4.Puzzle.Gem.Seishin.Orb.ProximityPrompt");
                if Orb and Orb.Enabled then
                    Tp(HumRSelf, Orb.Parent.CFrame, 0.3);
                    fireproximityprompt(Orb);
                end; self:B2C1Func("Vil/Talk");
            elseif where == "Ship/Enter" then
                Tp(HumRSelf, CFr(-1250, 4, 6299.65));
            elseif where == "Ship/Candle" then
                local Rituals = self:B2C1Get("Workspace.Section5.RitualLight");
                if not Rituals then return; end; local CHs = GetChildren(Rituals);
                
                if not self.Rituals or not self.Rituals.Connected then
                    self.Rituals = TrackSignal(Rituals.ChildAdded, function(v)
                        if v.ClassName == "Model" then
                            v.ModelStreamingMode = PERSISTENT;
                        end;
                    end);

                    for i=1, #CHs do
                        local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                            v.ModelStreamingMode = PERSISTENT;
                        end;
                    end;

                    self.Cords = {
                        CFr(-6064, 547, 7146),
                        CFr(-6821, 759, 6431),
                        CFr(-5443, 461, 6336),
                    };

                    for i=1, #self.Cords do
                        local v=self.Cords[i];
                        Tp(HumRSelf, v, 0.3);
                    end; CHs=GetChildren(Rituals);
                end; for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChildWhichIsA(v, "ProximityPrompt", true);
                        if not Prox or not Prox.Enabled then continue; end;
                        ForceFloat = true;
                        self:FirePrompt({
                            Safe = Prox.Parent.CFrame * CFr(0, -10, 0);
                            Prompt = Prox;
                            LookAt = Prox.Parent.Position;
                            EndAt = Prox.Parent.CFrame * CFr(0, 3, 0);
                        });
                    end; ForceFloat = "None";
                end;
            elseif where == "Ship/Run" then
                Tp(HumRSelf, CFr(-6318.51, 418.696014, 6332.39));
            end;
        end;

        Functions.B2C1ESP = function(self, where, state)
            if not state then
                return ESPF.Visible(where, false);
            elseif where == "City/Key" then
                local Object = self:B2C1Get("Workspace.Section1.Items.Key");
                if not Object then return; end;
                ESPF.ESP(where, Object, {
                    Color = WHITE;
                    Size = VEC2;
                    Text = "Key";
                });
            elseif where == "Rat/Book" then
                local Object = self:B2C1Get("Workspace.Section2.BookRead.Book");
                if not Object then return; end; local ESPObject = ESPF.ESP(where, Object, {
                    Color = YELLOW;
                    Size = VEC2;
                    Text = "Book";
                }); local Interact = FindFirstChild(Object, "Interact"); if Interact then
                    TrackSignal(Interact.Destroying, function()
                        ESPObject.UpdateColor(GREEN);
                    end);
                else
                    ESPObject.UpdateColor(GREEN);
                end;
            elseif where == "Rat/Futakuchi" then
                local Object = self:B2C1Get("Workspace.Section2.Monsters.Futakuchi");
                if not Object then return; end; if self:B2C1Validate(Object, "DescendantAdded") then
                    ESPF.ESP(where, Object, {
                        Color = RED;
                        Size = VEC10;
                        Text = "Futakuchi";
                    });
                end;
            elseif where == "Rat/Rat" then
                local Object = self:B2C1Get("Workspace.Section2.Rats");
                if not Object then return; end;
                local CHs = GetChildren(Object); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "Cube");
                        Prox = Prox and FindFirstChildOfClass(Prox, "ProximityPrompt");
                        if not Prox then continue; end;
                        local ESPObject = ESPF.ESP(where, Prox.Parent, {
                            Color = if Prox.Enabled then YELLOW else GREEN;
                            Size = VEC2;
                            Text = "Rat";
                        }); if not PromptConnections[Prox] then
                            PromptConnections[Prox] = TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                ESPObject.UpdateColor(if Prox.Enabled then YELLOW else GREEN);
                            end);
                        end;
                    end;
                end;
            elseif where == "Vil/Kurobozu" then
                local Object = self:B2C1Get("Workspace.Section4.Monsters.Kurobozu");
                if not Object then return; end; if self:B2C1Validate(Object, "DescendantAdded") then
                    ESPF.ESP(where, Object, {
                        Color = RED;
                        Size = VEC10;
                        Text = "Kurobozu";
                    });
                end;
            elseif where == "Vil/Ohaguro" then
                local Object = self:B2C1Get("Workspace.Section4.Monsters.Ohaguro");
                if not Object then return; end; if self:B2C1Validate(Object, "DescendantAdded") then
                    ESPF.ESP(where, Object, {
                        Color = RED;
                        Size = VEC10;
                        Text = "Ohaguro";
                    });
                end;
            elseif where == "Ship/Monsters" then
                local Object = self:B2C1Get("Workspace.Section5.Monsters");
                if not Object then return; end;
                local CHs = GetChildren(Object);
                for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        if self:B2C1Validate(v, "DescendantAdded") then
                            ESPF.ESP(where, v, {
                                Color = RED;
                                Size = VEC10;
                                Text = v.Name;
                            });
                        end;
                    end;
                end;
            end; ESPF.Visible(where, true, true);
        end;

        Functions.GetFromCook = function(Givers, name)
            local Object = Givers and FindFirstChild(Givers, name);
            if not Object then return; end;
            local Handle = FindFirstChild(Object, "Handle");
            local Prox = Handle and FindFirstChildOfClass(Handle, "ProximityPrompt");
            if not Prox then return; end;
            Tp(HumRSelf, Handle.CFrame, 0.3);
            fireproximityprompt(Prox);
        end;

        Functions.PlaceCoun = function(Counter)
            local CHs = GetChildren(Counter); for i=1, #CHs do
                local v=CHs[i]; if v.Parent then
                    local Prox = FindFirstChildOfClass(v, "ProximityPrompt");
                    if not Prox then continue; end;
                    Tp(HumRSelf, Prox.Parent.CFrame, 0.3);
                    return fireproximityprompt(Prox);
                end;
            end;
        end;

        Functions.ToStove = function(Prox)
            Tp(HumRSelf, Prox.Parent.CFrame, 0.3);
            fireproximityprompt(Prox);
        end;

        Functions.TurnInFood = function(prompt)
            prompt.Parent.Parent.CanCollide = false; prompt.Enabled = true;
            Tp(HumRSelf, prompt.Parent.Parent.CFrame * CFr(0, -3, 0), 0.3);
            fireproximityprompt(prompt);
        end;

        Functions.B2C2Func = function(self, where)
            if where == "Statue" then
                local Object = self:B2C1Get("Workspace.Section1.UmiBozuSeeking_Intro_02");
                if not Object then return; end; local Hitbox = FindFirstChild(Object, "Hitbox_Entrance");
                if FindFirstChild(Hitbox, "TouchInterest") then
                    firetouchinterest(HumRSelf, Hitbox, 0);
                end; Tween({
                    primary = HumRSelf;
                    goal = {CFrame = CFr(-520, 30, -87.29)};
                }); Tp(HumRSelf, CFr(-520, 30, -87.2), 0.3);
                Anchored(HumRSelf, true);
                Tp(HumRSelf, CFr(-520, 30, -87.2), 30);
                Anchored(HumRSelf, false);
                Tp(HumRSelf, CFr(-551, 30, -87.29));
            elseif where == "Crounch" then
                local DoorA = self:B2C1Get("Workspace.Section2.Build.ProxDoorA.DoorFrame.ProximityPrompt"); if DoorA then
                    Tp(HumRSelf, DoorA.Parent.CFrame, 0.3);
                    fireproximityprompt(DoorA); ForceFloat = true;
                    repeat twait(0.1) until self:B2C1Get("Workspace.Section2.Build.ProxDoorB.DoorFrame");
                    local DoorB = self:B2C1Get("Workspace.Section2.Build.ProxDoorB.DoorFrame.ProximityPrompt");
                    if DoorB then
                        Tp(HumRSelf, DoorB.Parent.CFrame, 0.3);
                        fireproximityprompt(DoorB);
                    end; ForceFloat = false;
                end; Tp(HumRSelf, CFr(-3952.85, 700, 317.7), 70);

                local DoorL = self:B2C1Get("Workspace.Section2.TeleportDoor.PROMPTINHERE.ProximityPrompt");
                if not DoorL then return; end;
                Tp(HumRSelf, DoorL.Parent.CFrame, 0.3);
                fireproximityprompt(DoorL);
            elseif where == "Meat/Talk" then
                Tp(HumRSelf, CFr(-4443, 711, 1164)); WindUI:Notify({
                    Title = "<font color='rgb(255,0,0)'>ALERT</font>",
                    Content = "If you just collected meats, wait 11 seconds before talk to this NPC",
                    Icon = "circle-alert",
                    Duration = 11,
                });
            elseif where == "Meat/TpMeat" then
                local MeatRF = self:B2C1Get("Workspace.Section2.Rooms");
                if not MeatRF then return; end;
                for _, v in pairs(GetChildren(MeatRF)) do
                    if v.Name == "RestaurantRoom" then
                        local MeatF = FindFirstChild(v, "Meat");
                        if MeatF then
                            local MeatFChild = GetChildren(MeatF);
                            for i=1, #MeatFChild do
                                if MeatFChild[i].Transparency == 0 then
                                    return CommonF.Tp(HumRSelf, MeatFChild[i].CFrame);
                                end;
                            end;
                        end;
                    end;
                end;
            elseif where == "Meat/Exit" then
                local Object = self:B2C1Get("Workspace.Section2.Rooms.EndRoom.DoorTele.DoorFrame.ProximityPrompt");
                if not Object then return; end;
                Tp(HumRSelf, Object.Parent.CFrame, 0.3);
                fireproximityprompt(Object);
            elseif where == "Meat/Run" then
                ForceFloat = false; Tp(HumRSelf, CFr(-4590, 843.64, -35.54));
                twait(14); ForceFloat = true; tk.spawn(function()
                    Tween({primary = HumRSelf; goal = {CFrame = CFr(-5364, 682.12, 29.63)}});
                end); twait(2); ForceFloat = "None";
            elseif where == "Lever/Enter" then
                Tp(HumRSelf, CFr(-11035, -81.4, -12.56));
            elseif where == "Lever/Auto" then
                local Object = self:B2C1Get("Workspace.Section3.GATE_SYSTEM_01.Levers");
                if not Object then return; end; local CHs = GetChildren(Object);
                for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Lever = FindFirstChild(v, "Lever");
                        local Prox = Lever and FindFirstChildOfClass(Lever, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, Lever.CFrame, 0.3);
                        fireproximityprompt(Prox);
                    end;
                end; return twait(6), Tp(HumRSelf, CFr(-10060, 484.1, -9.52));
            elseif where == "Math" then
                Tp(HumRSelf, CFr(-2005.8, 968.25, -4909.48));
            elseif where == "Cook/Run" then
                return Tween({primary = HumRSelf; goal = {
                    CFrame = CFr(-3345.78, 1205, -6794.84)};
                    info = TweenInfo.new(
                        3,
                        Enum.EasingStyle.Linear,
                        Enum.EasingDirection.Out,
                        0,
                        false,
                        0
                    )
                }), twait(4), Tp(HumRSelf, CFr(-3347.32, 1205, -6824));
            elseif where == "Cursed/1" then
                Tween({primary = HumRSelf; goal = {CFrame = CFr(-4250.71, 613.7, -968.13)}});
            elseif where == "Cursed/2" then
                Tween({primary = HumRSelf; goal = {CFrame = CFr(-4079.71, 613.7, -968.13)}});
            elseif where == "Cursed/Remove" then
                local Object = self:B2C1Get("Workspace.Section3.5.GAMESTART");
                if not Object then return; end;
                Object.CanTouch = false;
            elseif where == "Kid/Find" then
                local Object = self:B2C1Get("Workspace.Section4.Daughter.IndicatorPic");
                if not Object then return; end;
                Tp(HumRSelf, Object.CFrame, 0.3);
                Tp(HumRSelf, CFr(-4334.81299, 690.94397, -2363.2771));
            elseif where == "Kid/Gate" then
                local Object = self:B2C1Get("Workspace.Section4.Door.Glowing");
                if not Object then return; end;
                Tp(HumRSelf, Object.CFrame);
            elseif where == "Kid/Notes" then
                local Object = self:B2C1Get("Workspace.Section4.SlenderGame.Notes");
                if not Object then return; end; local CHs = GetChildren(Object);
                for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChildOfClass(v, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, v.CFrame, 0.3); fireproximityprompt(Prox);
                    end;
                end;
            end;
        end;

        Functions.B2C2ESP = function(self, where, state)
            if not state then
                return ESPF.Visible(where, false);
            elseif where == "Meat/Ashina" then
                local Object = self:B2C1Get("Workspace.Section2.Monsters.Ashina");
                if not Object then return; end; if self:B2C1Validate(Object, "DescendantAdded") then
                    ESPF.ESP(where, Object, {
                        Color = RED;
                        Size = VEC10;
                        Text = "Ashina";
                    });
                end;
            elseif where == "Meat/Meats" then
                local MeatRF = self:B2C1Get("Workspace.Section2.Rooms");
                if not MeatRF then return; end;
                for _, v in pairs(GetChildren(MeatRF)) do
                    if v.Name == "RestaurantRoom" then
                        local MeatF = FindFirstChild(v, "Meat");
                        if MeatF then
                            local MeatFChild = GetChildren(MeatF);
                            for i=1, #MeatFChild do
                                if MeatFChild[i].Transparency == 0 then
                                    ESPF.ESP(where, MeatFChild[i], {
                                        Color = WHITE;
                                        Size = VEC2;
                                        Text = "Meat";
                                    });
                                end;
                            end;
                        end;
                    end;
                end;
            elseif where == "Lever/Levers" then
                local Object = self:B2C1Get("Workspace.Section3.GATE_SYSTEM_01.Levers");
                if not Object then return; end; local CHs = GetChildren(Object);
                for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Lever = FindFirstChild(v, "Lever");
                        local Prox = Lever and FindFirstChildOfClass(Lever, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        ESPF.ESP(where, Lever, {
                            Color = WHITE;
                            Size = VEC2;
                            Text = "Lever";
                        });
                    end;
                end;
            elseif where == "Math" then
                local MidANumber, MidBNumber = nil;
                local SymbolsAImage1, SymbolsAImage2 = nil;
                local SymbolsBImage1, SymbolsBImage2 = nil;
                local SymbolsANumber1, SymbolsANumber2 = nil;
                local SymbolsBNumber1, SymbolsBNumber2 = nil;
                local Descen = GetDescendants(W);
                for i,v in ipairs(Descen) do
                    if v.ClassName == "TextLabel" and v.Parent.ClassName == "SurfaceGui" and v.Parent.Parent.Name == "MiddleNumber" and v.Parent.Parent.Parent.Name == "SymbolsA" then
                        MidANumber = v.Text;
                    end;
                    if v.ClassName == "TextLabel" and v.Parent.ClassName == "SurfaceGui" and v.Parent.Parent.Name == "MiddleNumber" and v.Parent.Parent.Parent.Name == "SymbolsB" then
                        MidBNumber = v.Text;
                    end;
                    if v.ClassName == "ImageLabel" and v.Parent.ClassName == "SurfaceGui" and v.Parent.Parent.Name == "SymbolHolder" and v.Parent.Parent.Parent.Name == "SymbolsA" then
                        SymbolsAImage1 = v.Image;
                    end;
                    if v.ClassName == "ImageLabel" and v.Parent.ClassName == "SurfaceGui" and v.Parent.Parent.Name == "SymbolHolder" and v.Parent.Parent.Parent.Name == "SymbolsB" then
                        SymbolsBImage1 = v.Image;
                    end;
                end; for i,v in ipairs(Descen) do
                    if v.ClassName == "ImageLabel" and v.Parent.ClassName == "SurfaceGui" and v.Parent.Parent.Name == "SymbolHolder" and v.Parent.Parent.Parent.Name == "SymbolsA" then
                        if v.Image ~= SymbolsAImage1 then
                            SymbolsAImage2 = v.Image;
                        end;
                    end;
                    if v.ClassName == "ImageLabel" and v.Parent.ClassName == "SurfaceGui" and v.Parent.Parent.Name == "SymbolHolder" and v.Parent.Parent.Parent.Name == "SymbolsB" then
                        if v.Image ~= SymbolsBImage1 then
                            SymbolsBImage2 = v.Image;
                        end;
                    end;
                end; for i,v in ipairs(Descen) do
                    if v.ClassName == "ImageLabel" and FindFirstChild(v.Parent, "TextLabel") then
                        if v.Image == SymbolsAImage1 then
                            SymbolsANumber1 = v.Parent:WaitForChild("TextLabel").Text;
                        end;
                    end;
                    if v.ClassName == "ImageLabel" and FindFirstChild(v.Parent, "TextLabel") then
                        if v.Image == SymbolsAImage2 then
                            SymbolsANumber2 = v.Parent:WaitForChild("TextLabel").Text;
                        end;
                    end;
                    if v.ClassName == "ImageLabel" and FindFirstChild(v.Parent, "TextLabel") then
                        if v.Image == SymbolsBImage1 then
                            SymbolsBNumber1 = v.Parent:WaitForChild("TextLabel").Text;
                        end;
                    end;
                    if v.ClassName == "ImageLabel" and FindFirstChild(v.Parent, "TextLabel") then
                        if v.Image == SymbolsBImage2 then
                            SymbolsBNumber2 = v.Parent:WaitForChild("TextLabel").Text;
                        end;
                    end;
                end;
                local Answer1 = tostring(MidANumber - (SymbolsANumber1 + SymbolsANumber2));
                local Answer2 = tostring(MidBNumber - (SymbolsBNumber1 + SymbolsBNumber2));
                for i,v in ipairs(Descen) do
                    if v.ClassName == "TextLabel" and v.Parent.Parent.Parent.Name == "Kanji" then
                        for _, sec in ipairs(Descen) do
                            if sec.Name == "SymbolHolder[Empty]" and sec.Parent.Name == "SymbolsA" then
                                if v.Text == Answer1 then
                                    local HackImage1 = v.Parent:Clone();
                                    HackImage1.Parent = sec;
                                end;
                            end;
                            if sec.Name == "SymbolHolder[Empty]" and sec.Parent.Name == "SymbolsB" then
                                if v.Text == Answer2 then
                                    local HackImage2 = v.Parent:Clone();
                                    HackImage2.Parent = sec;
                                end;
                            end;
                        end;
                    end;
                end;
            elseif where == "Kid/Mother" then
                local Object = Functions:B2C1Get("Workspace.Section4.Monsters.Mother.HumanoidRootPart");
                if not Object then return; end; if self:B2C1Validate(Object, "DescendantAdded") then
                    ESPF.ESP(where, Object, {
                        Color = RED;
                        Size = VEC10;
                        Text = "Mother";
                    });
                end;
            end; ESPF.Visible(where, true, true)
        end;

        Functions.INVBP = function()
            PSG.Inventory.LocalScript.Enabled = false;
            PSG.Inventory.LocalScript.Enabled = true;
        end;

        Functions.B2C3CanCraft = function(CHs)
            local Count=0; for i=1, #CHs do
                local v=CHs[i]; if v.Parent then
                    if v.Name == "Stick" or v.Name == "Cloth" then
                        Count += 1;
                    end;
                end;
            end; return Count >= 3;
        end;

        Functions.B2C3Click = function(self, name)
            if not tblef(self.OneRunHouseClicked, name) then
                tblein(self.OneRunHouseClicked, name);
                R.Packages.Packet.PacketFunction:InvokeServer(0, {
                    __args = { [1] = name },
                    __tree = { [1] = "IspyService", [2] = "Clicked" },
                    __callType = 0
                }); twait();
            end;
        end;

        Functions.B2C3Func = function(self, where)
            if where == "Gozu" then
                Tp(HumRSelf, CFr(-582, 38, 417));
            elseif where == "Heart/Talk" then
                Tp(HumRSelf, CFr(-138, 45, 79));
            elseif where == "Heart/Auto" then
                local Hearts = GetChildren(W.Section1.Puzzle.Hearts); for i=1, #Hearts do
                    local v=Hearts[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, v.Heart.CFrame, 0.3); fireproximityprompt(Prox);
                    end;
                end;
                
                local CHs = GetChildren(W.Section1.Puzzle.SpinModel); for i=1, #CHs do
                    local arm=CHs[i]; if arm.Parent and arm.ClassName == "Model" then
                        local BeatingHeart = FindFirstChild(arm, "BeatingHeart");
                        local Heart = BeatingHeart and FindFirstChild(BeatingHeart, "Heart");
                        local Prox = Heart and FindFirstChild(Heart, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        local BPHeart = FindFirstChild(BP, "Heart"); if BPHeart then
                            HumanoidEquip(HumSelf, BPHeart);
                        end; Tp(HumRSelf, Heart.CFrame, 0.3); fireproximityprompt(Prox);
                    end;
                end;
            elseif where == "Heart/Run" then
                ForceFloat = true; Tp(HumRSelf, CFr(-101, 42, -395), 0.3);
                local CHs=GetChildren(W.Section1.Maze.Doors2); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Main = FindFirstChild(v, "MAIN");
                        if not Main or dist(Main.Position) > 30 then continue; end;
                        fireproximityprompt(Main.ProximityPrompt); break;
                    end;
                end; ForceFloat = "None";
            elseif where == "Maze/Craft" then
                local Holes = GetChildren(W.Section1.Maze.Holes);
                local Tables = GetChildren(W.Section1.Maze.Crafting.Tables);
                
                ForceFloat = true; for i=1, #Holes do
                    local v=Holes[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, v.CFrame, 0.3); fireproximityprompt(Prox);
                    end; if self.B2C3CanCraft(GetChildren(BP)) then break; end;
                end; Tp(HumRSelf, CFr(-78, 4, -442), 1);
                
                for i=1, #Tables do
                    local v=Tables[i]; if v.Parent then
                        local Root = FindFirstChild(v, "RootPart");
                        if dist(Root.Position) > 30 then continue; end;
                        local Prox = FindFirstChild(Root, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, Root.CFrame, 0.3);
                        fireproximityprompt(Prox);
                        R.Packages.Packet.PacketFunction:InvokeServer(unpack(ArgsCraft));
                        twait(0.3); PSG.Crafting.Frame.Visible = false; break;
                    end;
                end; ForceFloat = "None";
            elseif where == "Maze/Fire" then
                local Maze = W.Section1.Maze;
                local GrinDemon = if self.GameMode == "Normal" then Maze.GrinDemon else Maze.GrinDemonNM;
                local CHs = GetChildren(Maze.Crafting.ArmFlames); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Flame = FindFirstChild(v, "UndyingFlame");
                        if distOf(Flame, GrinDemon.HumanoidRootPart, 20) then continue; end;
                        local Prox = Flame and FindFirstChild(Flame, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, Flame.CFrame, 0.3); fireproximityprompt(Prox); break;
                    end;
                end;
            elseif where == "Maze/Escape" then
                Tp(HumRSelf, CFr(-74, 5.2, -880));
            elseif where == "Bell/Zone" then
                Tp(HumRSelf, CFr(-325.5, 15, -1114));
            elseif where == "Bell/Flys" then
                for amount=1, 2 do
                    local Flies = GetChildren(W.Section2.FlyNoobs.Flies); for i=1, #Flies do
                        local Area=Flies[i]; if Area.Parent then
                            local CHs=GetChildren(Area); for ri=1, #CHs do
                                local v=CHs[ri]; if v.Parent and v.ClassName == "Model" then
                                    local Hitbox = FindFirstChild(v, "FlyHitbox");
                                    if not Hitbox or v.eyes.Transparency == 1 then continue; end;
                                    if self:ToolNow("BoneSword") then
                                        Tp(HumRSelf, Hitbox.CFrame);
                                        self:ToolActive("BoneSword");
                                        twait(3);
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            elseif where == "Bell/Auto" then
                local Bells, Colors, IsSoundPlay, Remote = W.Section2.Bells, {
                    Black = Col3.fromRGB(17, 17, 17);
                    White = Col3.fromRGB(248, 248, 248); 
                    Red = Col3.fromRGB(248, 0, 0);
                }, function(sound)
                    return sound.IsPlaying or sound.TimePosition > 0;
                end, R.Packages.Packet.PacketFunction;

                local AddChild = function(Bell)
                    local Buttons = WaitForChild(Bell, "2", 10);
                    local Base = WaitForChild(Buttons, "Base");
                    local Select = WaitForChild(Base, "Select");
                    local PlayerSelect = WaitForChild(Base, "PlayerSelect");
                    local ProximityPrompt = WaitForChild(Base, "ProximityPrompt");
                    local BellModel = WaitForChild(Bell, "BellModel");
                    local BellAnimationController = WaitForChild(BellModel, "AnimationController");
                    local HandMinions = WaitForChild(Bell, "HandMinions");
                    
                    local IsFinished = false; TrackOnce(BellAnimationController.AnimationPlayed, function()
                        IsFinished = true;
                    end);

                    local ThreadLoop, Pattern, Threads = false, {}, {};
                    local CHs=GetChildren(Buttons); for i=1, #CHs do
                        local Button=CHs[i]; if Button.Parent and Button.Name == "Buttons" then
                            Threads[#Threads + 1] = TrackSignal(PropChangeSignal(Button, "Color"), function()
                                if Button.Color == Colors.White then
                                    tk.delay(0.1 + math.clamp(self.GetPing(), 0, 0.5), function()
                                        if IsSoundPlay(Select) then
                                            Pattern[#Pattern + 1] = Button;
                                        end;
                                    end);
                                elseif Button.Color == Colors.Red then
                                    Pattern = {};
                                end;
                            end);
                        end;
                    end;

                    Threads[#Threads + 1] = TrackSignal(H.Heartbeat, function()
                        if GetAttribute(HandMinions, "Health") <= 0 or GetAttribute(HandMinions, "CanDamage") then
                            IsFinished = true; tk.defer(function()
                                for i=1, #Threads do
                                    Threads[i]:Disconnect();
                                end;
                            end);
                        end; if IsFinished then
                            return;
                        end; if #Pattern >= 5 and not ThreadLoop then
                            ThreadLoop = true; twait(1 + math.clamp(self.GetPing(), 0, 0.5));
                            for index = 1, #Pattern do
                                local Button = Pattern[index];
                                Remote:InvokeServer(0, {
                                    __args = {[1] = Button,},
                                    __tree = {
                                        [1] = "PuzzleService",
                                        [2] = "Clicked",
                                    }, __callType = 0,
                                }); twait(0.03);
                            end; Remote:InvokeServer(0, {
                                __args = {},
                                __tree = {
                                    "PuzzleService",
                                    "ExitPuzzle"
                                }, __callType = 0
                            }); twait(0.3); Pattern = {}; ThreadLoop = false;
                        end;
                    end);
                end;

                local CHs = GetChildren(Bells); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        AddChild(v);
                    end;
                end;

                local DodoMeki = W.Section2.Monster.Dodomeki.Head; repeat 
                    local AllCompleted = true;
                        local CHs = GetChildren(Bells); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local Obj2 = FindFirstChild(v, "2");
                            local HandMinions = FindFirstChild(v, "HandMinions");
                            if not Obj2 or not HandMinions then continue; end;
                            local Base = FindFirstChild(Obj2, "Base");
                            local Prompt = Base and FindFirstChild(Base, "ProximityPrompt");
                            local Hitbox = FindFirstChild(HandMinions, "Hitbox1");
                            
                            if Prompt and Hitbox and GetAttribute(HandMinions, "Health") > 0 then
                                AllCompleted = false; while GetAttribute(HandMinions, "Health") > 0 and v.Parent do
                                    if DodoMeki.CFrame.Position.Y <= 60 then return; end;
                                    if not GetAttribute(HandMinions, "CanDamage") then
                                        Tp(HumRSelf, Base.CFrame, 0.5);
                                        if Prompt.Enabled then
                                            fireproximityprompt(Prompt);
                                            twait(5.3);
                                        end;
                                    elseif not PSG.QuickTime.GrabbedUI.Visible then
                                        if self:ToolNow("BoneSword") then
                                            Tp(HumRSelf, Hitbox.CFrame);
                                            self:ToolActive("BoneSword");
                                        end;
                                    end; twait(0.1);
                                end;
                            end;
                        end;
                    end; twait(1);
                until DodoMeki.CFrame.Position.Y <= 60 or AllCompleted;
            elseif where == "Bell/Puzzle" then
                local CHs=GetChildren(W.Section2.PuzzleDoor.Doors); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Shapes = FindFirstChild(v, "Shapes");
                        local Combos = Shapes and FindFirstChild(Shapes, "Combos");
                        if not Combos or Combos.Position.Y < 0 then continue; end;
                        local SurfaceGui = FindFirstChild(Combos, "SurfaceGui");
                        if not SurfaceGui then continue; end;
                        local CHs2 = GetChildren(SurfaceGui);
                        if #CHs2 == 0 then continue; end;
                        local rv={}; for ri=1, #CHs2 do
                            tblein(rv, CHs2[ri].Name);
                        end; Tp(HumRSelf, Combos.CFrame, 0.3);
                        fireproximityprompt(v.DoorDetector.ProximityPrompt);
                        return R.Packages.Packet.PacketFunction:InvokeServer(0, {
                            __args = {[1] = rv},
                            __tree = {
                                [1] = "DoorPuzzleService",
                                [2] = "Clicked",
                            },
                            __callType = 0,
                        });
                    end;
                end;
            elseif where == "Bell/TpDoor" then
                local CHs=GetChildren(W.Section2.PuzzleDoor.Doors); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Shapes = FindFirstChild(v, "Shapes");
                        local Combos = Shapes and FindFirstChild(Shapes, "Combos");
                        if not Combos or Combos.Position.Y < 0 then continue; end;
                        local SurfaceGui = FindFirstChild(Combos, "SurfaceGui");
                        if not SurfaceGui then continue; end;
                        local CHs2 = GetChildren(SurfaceGui);
                        if #CHs2 == 0 then continue; end;
                        return Tp(HumRSelf, Combos.CFrame, 0.3);
                    end;
                end;
            elseif where == "Bell/Run" then
                Tp(HumRSelf, CFr(-3888, -55, -2289));
            elseif where == "Enzukai/Enter" then
                local CHs = { W["Section2.5"].MindGame.Intro.Trigger, W["Section2.5"].MindGame.Intro.Trigger2 };
                for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        Tp(HumRSelf, v.CFrame, 0.3);
                    end;
                end;
            elseif where == "Enzukai/Auto" then
                local CHs = GetChildren(W["Section2.5"].MindGame.Boats); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Assign = FindFirstChild(v, "AssignedPlayer");
                        if Assign.Value ~= selff then continue; end;
                        local Enzukai = FindFirstChild(v, "EnzukaiGame");
                        local Root = Enzukai and FindFirstChild(Enzukai, "RootPart");
                        local ProxAt = Root and FindFirstChild(Root, "PromptAttachment");
                        local Prox = ProxAt and FindFirstChild(ProxAt, "ProximityPrompt");
                        while Prox and Prox.Parent and Enzukai.Parent do
                            if Prox.Enabled then
                                fireproximityprompt(Prox);
                            end; twait(0.1);
                        end; break;
                    end;
                end;
            elseif where == "Father/Isamu" then
                W.Section3.IsamuAI.Hitbox.CanTouch = false;
            elseif where == "Father/Auto" then
                Tp(HumRSelf, CFr(1136, 30, -2400));
            elseif where == "Train" then
                Tp(HumRSelf, W["Section3.5"].GhostTrain.TrainTrigger.CFrame);
            elseif where == "Larves" then
                local Dog = W.Section4.DogWall.RootPart.ProximityPrompt;
                local CHs = GetChildren(W.Section4.HotPotato.Givers); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Root = FindFirstChild(v, "RootPart");
                        local Prox = Root and FindFirstChild(Root, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, Root.CFrame, 0.3); fireproximityprompt(Prox); break;
                    end;
                end; Tp(HumRSelf, Dog.Parent.CFrame, 0.3); fireproximityprompt(Dog);
            elseif where == "Mud" then
                Tp(HumRSelf, W["Section4.5"].TeleportToSection5.CFrame);
            elseif where == "Yurei/House" then
                local CHs = GetChildren(W.Section5.ISPY.Houses); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Player = FindFirstChild(v, "Player");
                        local Root = Player and FindFirstChild(Player, "HumanoidRootPart");
                        local Prox = Root and FindFirstChild(Root, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, Root.CFrame, 0.3); fireproximityprompt(Prox); break;
                    end;
                end;
            elseif where == "Yurei/Click" then
                local CHs = GetChildren(W.Section5.ISPY.Houses); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Player = FindFirstChild(v, "Player");
                        local Root = Player and FindFirstChild(Player, "HumanoidRootPart");
                        if dist(Root.Position) > 50 then continue; end;

                        local Items = GetChildren(v.Items); for index=1, #Items do
                            local ItemName, Text = Items[index].Name, PSG.Section5.TextLabel.Text;
                            if strfind(Text, ItemName) then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Teddy Bear") and ItemName == "TeddyBear" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Traditional Lantern") and ItemName == "TraditionalLantern" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Japanese Stone Lantern") and ItemName == "JapaneseStoneLantern" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Rubber Duck") and ItemName == "RubberDuck" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Working Lantern") and ItemName == "WorkingLantern" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Sun Symbol") and ItemName == "SunSymbol" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Kintoru Head") and ItemName == "KintoruHead" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Mail Box") and ItemName == "MailBox" then
                                self:B2C3Click(ItemName, v.Name);
                            elseif strfind(Text, "Rice Barrel") and ItemName == "RiceBarrel" then
                                self:B2C3Click(ItemName, v.Name);
                            end; twait(0.3);
                        end;
                    end;
                end;
            elseif where == "Boss/TpSafe" then
                if self:B2C3Func("Boss/Map") then
                    Tp(HumRSelf, CFr(3078, 17, -540));
                end;
            elseif where == "Boss/Map" then
                if self.MapC then return true; end; self.MapC = true;
                local CHs = GetChildren(W.Section5.Boss.Build); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        if v.Name == "c01-15k" or v.Name == "InvisWall" then
                            v:Destroy();
                        end;
                    end;
                end; return true;
            elseif where == "Boss/Katanas" then
                if self:B2C3Func("Boss/Map") then
                    local CHs, CO = GetChildren(W.Section5.Boss.Katanas), 0; for i=1, #CHs do
                        if CO > 4 then return; end; ForceFloat = true;
                        local v=CHs[i]; if v.Parent and v.Transparency == 0 then
                            Tp(HumRSelf, v.CFrame * CFr(15,0,0), 0.3);
                            fireproximityprompt(v.ProximityPrompt); CO+=1;
                        end; ForceFloat = "None";
                    end; Functions:B2C3Func("Boss/TpSafe");
                end;
            elseif where == "Hell/Run" then
                Tp(HumRSelf, CFr(-1697, 246, 7806));
            end;
        end;

        Functions.B2C3ESP = function(self, where, state)
            if not state then
                return ESPF.Visible(where, false);
            elseif where == "Maze/GrinDemon" then
                local Maze = W.Section1.Maze;
                local GrinDemon = if self.GameMode == "Normal" then Maze.GrinDemon else Maze.GrinDemonNM;
                if not GrinDemon then return; end;
                ESPF.ESP(where, GrinDemon, {
                    Color = RED;
                    Size = VEC10;
                    Text = "Grin Demon";
                });
            elseif where == "Larves/Larves" then
                local CHs = GetChildren(W.Section4.HotPotato.Givers); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Root = FindFirstChild(v, "RootPart");
                        local Prox = Root and FindFirstChild(Root, "ProximityPrompt");
                        if not Prox then continue; end;
                        local ESPObject = ESPF.ESP(where, Root, {
                            Color = if Prox.Enabled then YELLOW else GREEN;
                            Size = VEC2;
                            Text = "Larves";
                        }); if not ESPObject.ChangeSignal or not ESPObject.ChangeSignal.Connected then
                            ESPObject.ChangeSignal = TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                ESPObject.UpdateColor(if Prox.Enabled then YELLOW else GREEN);
                            end);
                        end;
                    end;
                end;
            elseif where == "Larves/Soldier" then
                local CMs = {
                    W.Section4.StatueMonsters.Left,
                    W.Section4.StatueMonsters.Right,
                }; for i=1, #CMs do
                    local CHs = GetChildren(CMs[i]); for ri=1, #CHs do
                        local v=CHs[ri]; if v.Parent then
                            ESPF.ESP(where, v, {
                                Color = RED;
                                Size = VEC10;
                                Text = "Soldier";
                            });
                        end;
                    end;
                end;
            elseif where == "Larves/Boogey" then
                local BoogeymanAI = FindFirstChild(W.Section4.Monster, "BoogeymanAI");
                if not BoogeymanAI then return; end;
                ESPF.ESP(where, BoogeymanAI, {
                    Color = RED;
                    Size = VEC10;
                    Text = "Boogeyman";
                });
            end; ESPF.Visible(where, true, true);
        end;

        Functions.B2C4BP1 = function()
            local ScreenGui = FindFirstChild(PSG, "ScreenGui");
            if ScreenGui then
                ScreenGui.Enabled = false;
                
                local Frame = FindFirstChild(ScreenGui, "Frame");
                if Frame then Frame.Visible = false; end;
            end;

            local Remote = FindFirstChild(W.Section1.PlayerObjective, "Remote");
            if Remote then Remote:FireServer(1); end;
        end;

        Functions.B2C4BP2 = function()
            -- Services
            local RunService = game:GetService("RunService")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")

            -- Dependencies
            local spr = require(ReplicatedStorage._Libraries.spr)
            local Controllers = require(ReplicatedStorage.Client.Controllers)

            local script = game:GetService("Players").LocalPlayer.PlayerGui["S2.5"].LocalScript;
            local Section = workspace:WaitForChild("Section2.5")
            local TriviaGame = Section:WaitForChild("ChihiroMinigame"):WaitForChild("Trivia")
            local MonsterMother = TriviaGame:WaitForChild("Monster", 30):WaitForChild("Mother", 30)
            local SignalRemote = TriviaGame:WaitForChild("Signal")
            local TriviaUI = script.Parent

            -- Creates a corner element for the trivia UI with animated frames
            local function CreateCornerElement(isTop, isLeft)
                local canvasGroup = Instance.new("CanvasGroup")
                canvasGroup.BackgroundTransparency = 1
                canvasGroup.BorderSizePixel = 0
                canvasGroup.ZIndex = 2
                canvasGroup.Size = UDim2.fromScale(0.5, 0.5)
                canvasGroup.Position = UDim2.fromScale(isLeft and 0 or 1, isTop and 0 or 1)
                canvasGroup.Name = ""

                local aspectRatio = Instance.new("UIAspectRatioConstraint")
                aspectRatio.AspectRatio = 1
                aspectRatio.Parent = canvasGroup

                local function CreateFrame(isHorizontal)
                    local frame = Instance.new("Frame")
                    frame.Size = UDim2.fromScale(isHorizontal and 1 or 0.1, isHorizontal and 0.1 or 1)
                    frame.BorderSizePixel = 0
                    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    frame.Name = ""

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0.5, 0)
                    corner.Parent = frame
                    return frame
                end

                local horizontalFrame = CreateFrame(false)
                horizontalFrame.Position = UDim2.fromScale(isLeft and 0 or 1, 0)
                horizontalFrame.AnchorPoint = Vector2.new(isLeft and 0 or 1, 0)
                horizontalFrame.Parent = canvasGroup

                local verticalFrame = CreateFrame(true)
                verticalFrame.Position = UDim2.fromScale(0, isTop and 0 or 1)
                verticalFrame.AnchorPoint = Vector2.new(0, isTop and 0 or 1)
                verticalFrame.Parent = canvasGroup

                return {
                    group = canvasGroup,
                    x = horizontalFrame,
                    y = verticalFrame,
                    top = isTop,
                    left = isLeft
                }
            end

            -- Creates a folder with animated corner elements
            local function CreateCornerFolder(parent)
                local folder = Instance.new("Folder")
                folder.Name = ""

                local cornerData = { corners = {} }

                for i = 1, 4 do
                    local corner = CreateCornerElement(i < 3, i % 2 ~= 0)
                    local group = corner.group
                    local offset = Vector2.new(0, 0)
                    group.AnchorPoint = Vector2.new(corner.left and 0 or 1, corner.top and 0 or 1) +
                        offset * Vector2.new(corner.left and 1 or -1, corner.top and 1 or -1)
                    group.GroupTransparency = 1
                    group.Parent = folder
                    table.insert(cornerData.corners, corner)
                end

                function cornerData:animatePop()
                    for _, corner in self.corners do
                        local animOffset = Vector2.new(0.2, 0.2)
                        spr.target(corner.group, 0.5, 2, {
                            AnchorPoint = Vector2.new(corner.left and 0 or 1, corner.top and 0 or 1) +
                                animOffset * Vector2.new(corner.left and 1 or -1, corner.top and 1 or -1)
                        })
                        task.delay(0.25, function()
                            local nextOffset = Vector2.new(0.25, 0.25)
                            spr.target(corner.group, 0.5, 3, {
                                AnchorPoint = Vector2.new(corner.left and 0 or 1, corner.top and 0 or 1) +
                                    nextOffset * Vector2.new(corner.left and 1 or -1, corner.top and 1 or -1)
                            })
                        end)
                    end
                end

                function cornerData:animateIn()
                    for _, corner in self.corners do
                        local animOffset = Vector2.new(0, 0)
                        spr.target(corner.group, 1, 2, {
                            AnchorPoint = Vector2.new(corner.left and 0 or 1, corner.top and 0 or 1) +
                                animOffset * Vector2.new(corner.left and 1 or -1, corner.top and 1 or -1),
                            GroupTransparency = 1
                        })
                    end
                end

                function cornerData:animateOut()
                    for _, corner in self.corners do
                        local animOffset = Vector2.new(0.25, 0.25)
                        spr.target(corner.group, 0.9, 2, {
                            AnchorPoint = Vector2.new(corner.left and 0 or 1, corner.top and 0 or 1) +
                                animOffset * Vector2.new(corner.left and 1 or -1, corner.top and 1 or -1),
                            GroupTransparency = 0
                        })
                    end
                end

                function cornerData:animateOutDrag()
                    for _, corner in self.corners do
                        local animOffset = Vector2.new(0.4, 0.4)
                        spr.target(corner.group, 1, 2, {
                            AnchorPoint = Vector2.new(corner.left and 0 or 1, corner.top and 0 or 1) +
                                animOffset * Vector2.new(corner.left and 1 or -1, corner.top and 1 or -1),
                            GroupTransparency = 0
                        })
                        task.delay(0.1, function()
                            spr.target(corner.group, 1, 3, {
                                GroupTransparency = 1
                            })
                        end)
                    end
                end

                folder.Parent = parent
                return cornerData
            end

            -- Initialize corner animations
            local cornerAnimation1 = CreateCornerFolder(TriviaUI.Questions)
            local cornerAnimation2 = CreateCornerFolder(TriviaUI.Questions)
            local cornerAnimation3 = CreateCornerFolder(TriviaUI.Questions)

            -- Button and animation management
            local buttons = {}
            local buttonCallbacks = {}
            local isInteractionEnabled = true

            -- Reset button states
            local function ResetButtons()
                for _, callback in buttonCallbacks do
                    callback()
                end
                for _, buttonData in buttons do
                    spr.stop(buttonData.Button)
                    spr.stop(buttonData.Button.UIStroke)
                    buttonData.Button.BackgroundTransparency = 0.1
                    buttonData.Button.UIStroke.Transparency = 0.3
                    buttonData.Button.UIStroke.Color = Color3.fromRGB(255, 255, 255)
                    buttonData.Button.Size = UDim2.fromScale(1, 1)
                    spr.target(buttonData.Button.UIStroke, 1, 3, {
                        Color = Color3.fromRGB(0, 0, 0)
                    })
                    spr.target(buttonData.Button, 1, 3, {
                        Size = UDim2.fromScale(0.8, 0.8)
                    })
                    buttonData:SetAttribute("Selected", false)
                end
            end

            -- Set up button interactions
            for index, buttonFrame in TriviaUI.Selectors:GetChildren() do
                if buttonFrame:IsA("Frame") then
                    local function UpdateButtonState()
                        local isSelected = buttonFrame:GetAttribute("Selected")
                        spr.target(buttonFrame.Button.UIStroke, 1, 3, {
                            Color = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
                        })
                        spr.target(buttonFrame.Button, 1, 3, {
                            Size = isSelected and UDim2.fromScale(0.9, 0.9) or UDim2.fromScale(0.8, 0.8)
                        })
                    end

                    table.insert(buttonCallbacks, UpdateButtonState)
                    TrackSignal(buttonFrame:GetAttributeChangedSignal("Selected"), UpdateButtonState)

                    TrackSignal(buttonFrame.Button.Activated, function()
                        if not isInteractionEnabled then
                            isInteractionEnabled = true
                            SignalRemote:FireServer(1, index)
                            buttonFrame:SetAttribute("Selected", true)
                            cornerAnimation1:animatePop()
                            task.wait(0.4)
                            cornerAnimation1:animateIn()
                        end
                    end)

                    table.insert(buttons, buttonFrame)
                end
            end

            -- Store initial button positions
            local buttonPositions = {}
            for index, button in buttons do
                buttonPositions[index] = {
                    Position = button.Position,
                    AnchorPoint = button.AnchorPoint,
                    From = button
                }
            end

            -- Trivia game state
            local timerValue = 0
            local isGlitchActive = false

            -- Main trivia game function
            local function StartTriviaGame(questionText, answers, glitchEnabled)
                if isInteractionEnabled then
                    task.delay(0.1, function()
                        cornerAnimation2:animateOutDrag()
                        task.wait(0.1)
                        cornerAnimation3:animateOutDrag()
                        task.wait(0.6)
                        cornerAnimation2:animateIn()
                        cornerAnimation3:animateIn()
                    end)
                end

                TriviaUI.Questions.Visible = true
                TriviaUI.Selectors.Visible = true
                isInteractionEnabled = false
                ResetButtons()
                isGlitchActive = glitchEnabled or false

                for _, buttonData in buttonPositions do
                    buttonData.From.Position = buttonData.Position
                    buttonData.From.AnchorPoint = buttonData.AnchorPoint
                end

                if timerValue == 0 then
                    task.defer(function()
                        while timerValue > 0 do
                            task.wait(1)
                            TriviaUI.Questions.Timer.Text = tostring(timerValue)
                            if isGlitchActive and (timerValue % 5 == 0 and #buttonPositions > 1) then
                                script.GlitchSFX:Play()
                                local index1 = math.random(1, #buttonPositions)
                                local index2
                                repeat
                                    index2 = math.random(1, #buttonPositions)
                                until index2 and index2 ~= index1

                                local button1 = buttonPositions[index1]
                                local button2 = buttonPositions[index2]
                                local tempPos = button2.From.Position
                                local tempAnchor = button2.From.AnchorPoint
                                button2.From.Position = button1.From.Position
                                button2.From.AnchorPoint = button1.From.AnchorPoint
                                button1.From.Position = tempPos
                                button1.From.AnchorPoint = tempAnchor
                                button1.From.Button.Label.TextColor3 = Color3.fromRGB(0, 123, 255)
                                button2.From.Button.Label.TextColor3 = Color3.fromRGB(0, 123, 255)
                                task.delay(0.08333333333333333, function()
                                    button1.From.Button.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                                    button2.From.Button.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                                end)
                            end
                            timerValue = timerValue - 1
                        end
                    end)
                end

                timerValue = 20
                TriviaUI.Questions.Timer.Text = tostring(timerValue)
                cornerAnimation1:animateOut()
                cornerAnimation1:animatePop()
                spr.target(TriviaUI.Questions, 1, 3, {
                    BackgroundTransparency = 0.2
                })
                spr.target(TriviaUI.Questions.UIStroke, 1, 3, {
                    Transparency = 0.3
                })
                spr.target(TriviaUI.Questions.Question, 1, 3, {
                    TextTransparency = 0
                })
                spr.target(TriviaUI.Questions.Question.UIStroke, 1, 3, {
                    Transparency = 0
                })
                TriviaUI.Questions.Question.Text = questionText

                for index, answer in answers do
                    buttons[index].Button.Label.Text = answer
                end
            end

            -- Camera control
            local CurrentCamera = workspace.CurrentCamera
            local cameraConnection = nil

            local function UpdateCamera()
                if TriviaGame:GetAttribute("Game") then
                    if not (cameraConnection and cameraConnection.Connected) then
                        cameraConnection = TrackSignal(RunService.Heartbeat, function()
                            local cameraCFrame = CFrame.new(CurrentCamera.CFrame.Position, MonsterMother:GetPivot().Position + Vector3.new(0, 3, 0))
                            local x, y, _ = cameraCFrame:ToOrientation()
                            Controllers.camera:Enforce(Vector2.new(math.deg(x), math.deg(y)))
                        end)
                    end
                else
                    if cameraConnection then
                        cameraConnection:Disconnect()
                        cameraConnection = nil
                    end
                    return
                end
            end

            -- Initialize
            TrackSignal(TriviaGame:GetAttributeChangedSignal("Game"), UpdateCamera)
            UpdateCamera()

            -- Set initial UI transparency
            TriviaUI.Questions.BackgroundTransparency = 1
            TriviaUI.Questions.UIStroke.Transparency = 1
            TriviaUI.Questions.Question.TextTransparency = 1
            TriviaUI.Questions.Question.UIStroke.Transparency = 1

            -- Handle remote events
            TrackSignal(SignalRemote.OnClientEvent, function(eventType, ...)
                if eventType == 0 then
                    StartTriviaGame(...)
                elseif eventType == 1 then
                    spr.target(TriviaUI.Questions, 1, 3, {
                        BackgroundTransparency = 1
                    })
                    spr.target(TriviaUI.Questions.UIStroke, 1, 3, {
                        Transparency = 1
                    })
                    spr.target(TriviaUI.Questions.Question, 1, 3, {
                        TextTransparency = 1
                    })
                    spr.target(TriviaUI.Questions.Question.UIStroke, 1, 3, {
                        Transparency = 1
                    })
                    TriviaUI.Selectors.Visible = false
                elseif eventType == 2 then
                    TriviaUI:Destroy()
                elseif eventType == 3 then
                    local isCorrect = ...
                    if isCorrect then
                        TriviaGame.Correct:Play()
                    else
                        TriviaGame.Wrong:Play()
                    end
                end
            end)
        end;

        Functions.GetBowLook = function(pos, spr)
            if not spr then return; end;
            local eye = spr.Handle.MagicArrow.CFrame.Position;
            return CFr(eye, pos).LookVector;
        end;

        Functions.MagicArrowHit = function(self, Bow, Pos, cd)
            if not Bow or self.OnGoingArrow then return; end;
            self.OnGoingArrow = true;
            Bow.RemoteEvent:FireServer(0, true);
            twait(cd or 1);
            Bow.RemoteEvent:FireServer(0, false, self.GetBowLook(Pos, Bow));
            self.OnGoingArrow = false;
        end;

        Functions.B2C4Func = function(self, where)
            if where == "Cave" then
                Tp(HumRSelf, W.Section0.Cutscene.Trigger.CFrame);
            elseif where == "City/Auto" then
                Tp(HumRSelf, W.Section1.EnzukaiSneakSequence.GameStart.CFrame, 0.3);
                Tp(HumRSelf, W.Section1.OfficeTeleA.CFrame);
            elseif where == "City/Glass" then
                local CHs = GetChildren(W.Section1.EnzukaiSneakSequence.Activators); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        v:Destroy();
                    end;
                end;
            elseif where == "Office/Talk" then
                Tp(HumRSelf, CFr(4449, 44, 1660));
            elseif where == "Office/Auto" then
                local Numbs = W.Section1.PlayerObjective.CodeNumbers;
                local codextxt = {
                    [6] = Numbs["1stFloor"].SurfaceGui.Random,
                    [5] = Numbs["2ndFloor"].SurfaceGui.Random,
                    [4] = Numbs["3rdFloor"].SurfaceGui.Random,
                    [3] = Numbs["4thFloor"].SurfaceGui.Random,
                    [2] = Numbs["5thFloor"].SurfaceGui.Random,
                    [1] = Numbs["6thFloor"].SurfaceGui.Random,
                }; W.Section1.PlayerObjective.CodeDoor.Remote:FireServer(1, {});
                local c = {}; for i=1, 6 do
                    tblein(c, tonumber(codextxt[i].Text));
                end; return W.Section1.PlayerObjective.CodeDoor.Remote:FireServer(1, c);
            elseif where == "Office/Top" then
                local CHs = GetChildren(W.Section1.Map.Barriers); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        v:Destroy();
                    end;
                end;

                local PieceA = W.WHITE_FLAME_LANTERN.PieceA;
                local Ladder = W.Section1.PlayerObjective.LADDERPROMPT;

                Tp(HumRSelf, PieceA.CFrame, 0.3); fireproximityprompt(PieceA.ProximityPrompt);
                Tp(HumRSelf, Ladder.CFrame, 0.3); fireproximityprompt(Ladder.ProximityPrompt);
            elseif where == "Mall/Talk" then
                local CHs = GetChildren(W.Section2.WalkieTalkis); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "WalkieTalkie" then
                        Tp(HumRSelf, v.CFrame, 0.3);
                        fireproximityprompt(v.ProximityPrompt);
                    end;
                end;
            elseif where == "Mall/Trigger" then
                Tp(HumRSelf, W.Section2.Floor1.TRIGGER.CFrame);
            elseif where == "Mall/Eyes" then
                local folders = GetChildren(W.Section2.Floor1.TimedTrial); for i=1, #folders do
                    local folder=folders[i]; if not folder.Parent or folder.ClassName ~= "Folder" then
                        continue; 
                    end; local CHs = GetChildren(folder); for ir=1, #CHs do
                        local v=CHs[ir]; if v.Parent and v.Name == "EyePunch" then
                            local Root = FindFirstChild(v, "RootPart"); if not Root then continue; end;
                            local Prox = FindFirstChild(Root, "ProximityPrompt"); if not Prox then continue; end;
                            Tp(HumRSelf, Root.CFrame, 0.3); fireproximityprompt(Prox);
                        end;
                    end;
                end;
            elseif where == "Mall/Grab" then
                local Base = W.Section2.Speaker.SPEAKER;
                Tp(HumRSelf, Base.CFrame, 0.3);
                fireproximityprompt(Base["Pick Up"]);
            elseif where == "Mall/Place" then
                Tp(HumRSelf, CFr(-1351, -120, -942), 0.3);
                W.Section2.Speaker.Signal:FireServer();
            elseif where == "Mall/Chase1" then
                local CHs = {
                    CFr(-2925, -154, -117);
                    CFr(-2925, -152, 20);
                    CFr(-2971, -153, 90);
                    CFr(-3010, -156, 58);
                    CFr(-3010, -157, 1);
                    CFr(-3075, -161, 0);
                    CFr(-3078, -156, 44);
                    CFr(-3147, -163, 67);
                    CFr(-3156, -165, 6);
                    CFr(-3231, -169, 8);
                    CFr(-3325, -174, 8);
                    CFr(-3373, -177, -8);
                    CFr(-3452, -182, -41);
                    CFr(-3444, -182, -88);
                    CFr(-3424, -182, -148);
                    CFr(-3393, -181, -212);
                    CFr(-3353, -181, -297);
                    CFr(-3319, -180, -374);
                    CFr(-3343, -183, -464);
                    CFr(-3343, -183, -464);
                    CFr(-3401, -186, -505);
                    CFr(-3392, -187, -558);
                    CFr(-3441, -191, -584);
                    CFr(-3468, -190, -531);
                    CFr(-3543, -195, -551);
                    CFr(-3582, -197, -524);
                    CFr(-3619, -200, -608);
                    CFr(-3656, -203, -680);
                    CFr(-3710, -208, -784);
                    CFr(-3671, -207, -880);
                    CFr(-3601, -206, -1059);
                    CFr(-3449, -197, -999);
                    CFr(-3449, -197, -999);
                    CFr(-3241, -200, -902);
                }; Tp(HumRSelf, W["Section2.5"].ChaseSequence.StartPoint.CFrame, 0.3);
                local TWEENINFONOW = TweenInfo.new(1.3); for i=1, #CHs do
                    Tween({
                        primary = HumRSelf;
                        goal = {CFrame=CHs[i]};
                        info = TWEENINFONOW;
                    });
                end; Tween({primary = HumRSelf, goal = {CFrame = W["Section2.5"].ChaseSequence.EndPoint.CFrame}});
            elseif where == "Mall/Chase2" then
                Tp(HumRSelf, W["Section2.5"].ChaseSequence.SecondChaseStuff.ElevatorHit.CFrame);
            elseif where == "Car/Collect" then
                local CHs, Count = GetChildren(W["Section2.5"].ChihiroMinigame.CarFixObjective.CarParts), 0; for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and IsA(v, "BasePart") then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Count = Count + 1;
                        Tp(HumRSelf, v.CFrame, 0.3);
                        fireproximityprompt(Prox, 1);
                        if Count > 2 then
                            break;
                        end;
                    end;
                end;
                
                local V8 = FindFirstChild(W["Section2.5"].ChihiroMinigame.CarFixObjective.CarParts, "V8 Engine");
                local Base = if V8 then V8["Meshes/ls9_Cube (2)"] else nil; if V8 then
                    Tp(HumRSelf, Base.CFrame, 0.3);
                    fireproximityprompt(Base.ProximityPrompt);
                end; Tp(HumRSelf, CFr(-1924, -96, 1597));
            elseif where == "Car/Answer" then
                if not self.MotherLabels then
                    self.MotherLabels = {
                        PSG["S2.5"].Selectors["3"].Button.Label,
                        PSG["S2.5"].Selectors["2"].Button.Label,
                        PSG["S2.5"].Selectors["1"].Button.Label,
                    };
                end;

                local Answers = self.AnsweredMother;
                local Labels = self.MotherLabels;

                for i,v in pairs(Answers) do
                    if strfind(PSG["S2.5"].Questions.Question.Text, i) then
                        local answer = self.AnsweredMother[i];
                        for ri=1, 3 do
                            local rv=Labels[ri].Text;
                            if rv == answer then
                                W["Section2.5"].ChihiroMinigame.Trivia.Signal:FireServer(1, tonumber(Labels[ri].Parent.Parent.Name));
                                return;
                            end;
                        end;
                    end;
                end;
            elseif where == "Draw/Outside" then
                Tp(HumRSelf, CFr(-35, -431, 9154));
            elseif where == "Draw/Inside" then
                Tp(HumRSelf, CFr(87, -430, 9267));
            elseif where == "Draw/Tp" then
                local PaintStations=W.Section3.PaintPuzzle;
                local CHs = {
                    PaintStations.PaintStation_A.Pad;
                    PaintStations.PaintStation_B.Pad;
                    PaintStations.PaintStation_C.Pad;
                    PaintStations.PaintStation_D.Pad;
                }; for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "Draw");
                        if not Prox or not Prox.Enabled then continue; end;
                        return Tp(HumRSelf, Prox.Parent.CFrame);
                    end;
                end;
            elseif where == "Draw/Draw" then
                local Paints = self.Paints; if not Paints then
                    return WindUI:Notify({
                        Title = "<font color='rgb(255,255,0)'>Installer</font>",
                        Content = "Embedded painting data is unavailable. Reload this Book 2 build.",
                        Icon = "circle-alert",
                        Duration = 10,
                    });
                end;
                local CHs = GetChildren(W.Section3.PaintPuzzle); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Pad = FindFirstChild(v, "Pad");
                        if not Pad then continue; end;
                        if dist(Pad.Position) <= 10 then
                            local obj = FindFirstChildWhichIsA(Pad, "Decal");
                            local Text = obj.Texture;
                            local tonn = Text:gsub("rbxassetid://", "");
                            local target = tonumber(tonn);
                            local Pos = self.PaintPoses and self.PaintPoses[target];
                            if not Pos or not Paints[target] then
                                return WindUI:Notify({Title = "Drawing", Content = "This painting is absent from the supplied dataset.", Duration = 6});
                            end;
                            for _, v in pairs(Paints[target]) do
                                Pad.Controls.Draw:FireServer(Pos, v[1], v[2]);
                            end;
                        end;
                    end;
                end;
            elseif where == "Draw/Pillar" then
                local CHs = GetChildren(W.Section3.MagicPillars); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "Pillar" then
                        if not v.Text.SurfaceGui.Enabled then
                            return Tp(HumRSelf, v.PillarBase.CFrame);
                        end;
                    end;
                end;
            elseif where == "Draw/Item" then
                local CHs = GetChildren(W.WHITE_FLAME_LANTERN.PieceDnE); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        if v.Name == "PieceD" or v.Name == "PieceE" then
                            local Prox = FindFirstChild(v, "ProximityPrompt");
                            if not Prox then continue; end;
                            Tp(HumRSelf, v.CFrame, 0.3);
                            fireproximityprompt(Prox);
                        end;
                    end;
                end;
            elseif where == "Godmode" then
                sethiddenproperty(selff, "MaxSimulationRadius", 10000);
                sethiddenproperty(selff, "SimulationRadius", 10000);

                local CHs = {self.Tsukiya2, self.Rin2, self.Tenome2}; for i=1, #CHs do
                    local v=CHs[i]; if v and v.Parent then
                        local Root = FindFirstChild(v, "HumanoidRootPart");
                        local Hitbox = FindFirstChild(v, "Hitbox");

                        if Root then Root.CanTouch = false; end;
                        if Hitbox then Hitbox.CanTouch = false; end;
                    end;
                end;

                local EnzukaiRyu = FindFirstChild(W.Section4.BossMonster, "EnzukaiRyu");
                EnzukaiRyu = EnzukaiRyu and FindFirstChild(EnzukaiRyu, "Hitbox");

                local Enzukai2 = FindFirstChild(W.Section4.Monster, "Enzukai2");
                Enzukai2 = Enzukai2 and FindFirstChild(Enzukai2, "Hitbox");

                if EnzukaiRyu then EnzukaiRyu.CanTouch = false; end;
                if Enzukai2 then Enzukai2.CanTouch = false; end;
            elseif where == "Survivors" then
                local CHs = GetChildren(W.Section4.Rescue.NPCs); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "Pose" then
                        local Base = FindFirstChild(v, "HumanoidRootPart");
                        local Prox = Base and FindFirstChild(Base, "ProximityPrompt");
                        Tp(HumRSelf, Base.CFrame, 0.3); fireproximityprompt(Prox);
                        if i>4 then break; end;
                    end;
                end; Tp(HumRSelf, CFr(-98, 3, -2338));
            end;
        end;

        Functions.B2C4ESP = function(self, where, state)
            if not state then
                return ESPF.Visible(where, false);
            elseif where == "City/Glass" then
                local CHs = GetChildren(W.Section1.EnzukaiSneakSequence.Activators); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        ESPF.ESP(where, v, {
                            Color = RED;
                            Size = VEC2;
                            Text = "Glass";
                        });
                    end;
                end;
            elseif where == "City/Enzukai" then
                ESPF.ESP(where, W.Section1.EnzukaiSneakSequence.Monster.Enzukai, {
                    Color = RED;
                    Size = VEC2;
                    Text = "Enzukai";
                });
            elseif where == "Mall/Coins" then
                local CHs = GetChildren(W.Section2.Floor2.Coins); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox then continue; end;
                        local ESPObject = ESPF.ESP(where, v, {
                            Color = if not Prox.Enabled then GREEN else YELLOW;
                            Size = VEC2;
                            Text = "Coin";
                        }); if not ESPObject.ChangeSignal or not ESPObject.ChangeSignal.Connected then
                            ESPObject.ChangeSignal = TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                ESPObject.UpdateColor(if not Prox.Enabled then GREEN else YELLOW);
                            end);
                        end;
                    end;
                end;
            elseif where == "Mall/Talk" then
                local CHs = GetChildren(W.Section2.WalkieTalkis); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "WalkieTalkie" then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox then continue; end;
                        ESPF.ESP(where, v, {
                            Color = WHITE;
                            Size = VEC2;
                            Text = v.Name;
                        });
                    end;
                end;
            elseif where == "Mall/Monsters" then
                local CHs = {
                    W.Section2.Floor3.Monster.Tsukiya;
                    W.Section2.Floor1.Monster.Tenome;
                    W.Section2.Floor2.Monster.Rin;
                }; for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        ESPF.ESP(where, v, {
                            Color = RED;
                            Size = VEC10;
                            Text = v.Name;
                        });
                    end;
                end;
            elseif where == "Draw/Senzai" then
                local Senzai = FindFirstChild(W.Section3.Monster, "Senzai");
                if not Senzai then return; end; ESPF.ESP(where, Senzai, {
                    Color = RED;
                    Size = VEC10;
                    Text = "Senzai";
                });
            elseif where == "Draw/Ingredients" then
                local CHs = GetChildren(W.Section3.PaintPuzzle.Ingredients); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local ESPObject, Prox = nil, FindFirstChild(v, "ProximityPrompt");
                        if not Prox then continue; end; if v.Name == "Orchid" then
                            ESPObject = ESPF.ESP(where, v, {
                                Color = if Prox.Enabled then PURPLE else WHITE;
                                Size = VEC2;
                                Text = v.Name;
                            });
                        elseif v.Name == "Water" then
                            ESPObject = ESPF.ESP(where, v, {
                                Color = if Prox.Enabled then BLUE else WHITE;
                                Size = VEC2;
                                Text = v.Name;
                            });
                        end; if ESPObject and (not ESPObject.ChangeSignal or not ESPObject.ChangeSignal.Connected) then
                            ESPObject.ChangeSignal = TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                if not Prox.Enabled then return ESPObject.UpdateColor(WHITE); end;
                                if v.Name == "Orchid" then
                                    ESPObject.UpdateColor(PURPLE);
                                else
                                    ESPObject.UpdateColor(BLUE);
                                end;
                            end);
                        end;
                    end;
                end;
            elseif where == "Draw/Drawings" then
                local PaintStations=W.Section3.PaintPuzzle;
                local CHs = {
                    PaintStations.PaintStation_A.Pad;
                    PaintStations.PaintStation_B.Pad;
                    PaintStations.PaintStation_C.Pad;
                    PaintStations.PaintStation_D.Pad;
                }; for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "Draw");
                        if not Prox then continue; end;
                        local ESPObject = ESPF.ESP(where, v, {
                            Color = if Prox.Enabled then YELLOW else GREEN;
                            Size = VEC2;
                            Text = v.Name;
                        }); if not ESPObject.ChangeSignal or not ESPObject.ChangeSignal.Connected then
                            ESPObject.ChangeSignal = TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                ESPObject.UpdateColor(if Prox.Enabled then YELLOW else GREEN);
                            end);
                        end;
                    end;
                end;
            elseif where == "Survivors" then
                local CHs = GetChildren(W.Section4.Rescue.NPCs); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "Pose" then
                        ESPF.ESP(where, v, {
                            Color = GREEN;
                            Size = VEC2;
                            Text = v.Name;
                        });
                    end;
                end;
            elseif where == "Followers" then
                local CHs = {self.Tsukiya2, self.Rin2, self.Tenome2}; for i=1, #CHs do
                    local v=CHs[i]; if v and v.Parent then
                        ESPF.ESP(where, v, {
                            Color = RED;
                            Size = VEC10;
                            Text = v.Name;
                        });
                    end;
                end;
            end; ESPF.Visible(where, true, true);
        end;

        ScriptData.AutoData = {
            YenTab = ((Chapter == "B2C2" or Chapter == "B2C3" or Chapter == "B2C4" or Chapter == "B3C1") and {
                {type="Toggle", EN="Collect All Yen", EN2="Teleport & collect spawned yen", TH1="เก็บเงินทั้งหมด", TH2="วาปไปเก็บเงินทั้งหมดที่เกิดอยู่", Path="Auto"},
                {type="Toggle", EN="Yen Aura", EN2="Auto collect nearby Yen.", TH1="ออโต้เก็บเงิน", TH2="ออโต้เก็บเงินในระยะ", Path="Aura"},
                {type="Toggle", EN="ESP Yen", EN2="Show Yen boxes.", TH1="ESP เงิน", TH2="มองเห็นเงิน", Path="ESP"},
            });

            PackB2C1 = (Chapter == "B2C1" and {
                Tabs={
                    {Tab={at="B2C1", Title="City", Icon="book-open", Path="B2C1"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport to Senzai.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปหา Senzai", Callback=function()
                            Functions:B2C1Func("City/Complete");
                        end}; {type="Space"},
                        {type="Toggle", EN="ESP Key", EN2="Show key's box & name", TH1="ESP กุญแจ", TH2="มองเห็นกุญแจ", Path="City/ESP/Key", Callback=function(state)
                            B2C1Con.City.ESP.Key = state;
                            Functions:B2C1ESP("City/Key", state);
                        end},
                    }};
                    {Tab={at="B2C1", Title="Rat", Icon="book-open", Path="B2C1"}, Data={
                        {type="Button", EN="Read Book", EN2="Teleport & read the book.", TH1="อ่านหนังสือ", TH2="วาปไปอ่านหนังสือ", Callback=function()
                            Functions:B2C1Func("Rat/Book");
                        end};
                        {type="Button", EN="Auto Rat", EN2="Teleport to collect rats & ring the bell.", TH1="ออโต้หนู", TH2="วาปไปเก็บหนูแล้วสั่นระฆัง", Callback=function()
                            Functions:B2C1Func("Rat/Rat");
                        end};
                        {type="Button", EN="Exit", EN2="Teleport & exit.", TH1="ออก", TH2="วาปไปกดออก", Callback=function()
                            Functions:B2C1Func("Rat/Exit");
                        end};
                        {type="Button", EN="Run", EN2="Tween to the exit in chase sequence.", TH1="วิ่ง", TH2="ค่อยๆบินไปที่ทางออกในด่านวิ่งหนู", Callback=function()
                            Functions:B2C1Func("Rat/Run");
                        end}; {type="Space"},
                        {type="Toggle", EN="ESP Book", EN2="Show book's box & name", TH1="ESP หนังสือ", TH2="มองเห็นหนังสือ", Path="Rat/ESP/Book", Callback=function(state)
                            B2C1Con.Rat.ESP.Book = state;
                            Functions:B2C1ESP("Rat/Book", state);
                        end};
                        {type="Toggle", EN="ESP Futakuchi", EN2="Show Futakuchi's box & name", TH1="ESP Futakuchi", TH2="มองเห็น Futakuchi", Path="Rat/ESP/Futakuchi", Callback=function(state)
                            B2C1Con.Rat.ESP.Futakuchi = state;
                            Functions:B2C1ESP("Rat/Futakuchi", state);
                        end};
                        {type="Toggle", EN="ESP Rat", EN2="Show rats' box & name", TH1="ESP หนู", TH2="มองเห็นหนู", Path="Rat/ESP/Rat", Callback=function(state)
                            B2C1Con.Rat.ESP.Rat = state;
                            Functions:B2C1ESP("Rat/Rat", state);
                        end};
                    }};
                    {Tab={at="B2C1", Title="Nagisa", Icon="book-open", Path="B2C1"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport to the cave entrance.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปทางเข้าถ้ำ", Callback=function()
                            Functions:B2C1Func("Nagisa/Auto");
                        end};
                        {type="Button", EN="Auto Run", EN2="Tween to the cave exit in the chase sequence.", TH1="ออโต้วิ่ง", TH2="ค่อยๆบินไปที่ทางออกในด่านวิ่ง", Callback=function()
                            Functions:B2C1Func("Nagisa/Run");
                        end},
                    }};
                    {Tab={at="B2C1", Title="Village", Icon="book-open", Path="B2C1"}, Data={
                        {type="Button", EN="Teleport To Main Village", EN2="Tween to the main village. <font color='rgb(255,0,0)'>[1]</font>", TH1="วาปเข้าหมู่บ้าน", TH2="ค่อยๆบินไปที่หมู่บ้านหลัก <font color='rgb(255,0,0)'>[1]</font>", Callback=function()
                            Functions:B2C1Func("Vil/Zone");
                        end};
                        {type="Button", EN="Talk", EN2="Talk to the npc. <font color='rgb(255,0,0)'>[2]</font>", TH1="คุย", TH2="วาปไปหา NPC <font color='rgb(255,0,0)'>[2]</font>", Callback=function()
                            Functions:B2C1Func("Vil/Talk");
                        end};
                        {type="Button", EN="Get Key", EN2="Teleport & grab the key. <font color='rgb(255,0,0)'>[3]</font>", TH1="เก็บกุญแจ", TH2="วาปไปเก็บกุญแจ <font color='rgb(255,0,0)'>[3]</font>", Callback=function()
                            Functions:B2C1Func("Vil/Key");
                        end}; {type="Space"},

                        {type="Button", EN="Paint", EN2="Teleport to the house. <font color='rgb(255,0,0)'>[4]</font>", TH1="วาด", TH2="วาปไปที่จุดวาด <font color='rgb(255,0,0)'>[3]</font>", Callback=function()
                            Functions:B2C1Func("Vil/PaintTp");
                        end};
                        {type="Button", EN="Auto Paint · unavailable", EN2="The supplied 229 source has no B2C1 painting handler. B2C4 Auto Draw uses the embedded Paintings dataset.", TH1="ออโต้วาด", TH2="วาดให้ <font color='rgb(255,0,0)'>[3]</font>", Locked=true, Callback=function()
                            Functions:B2C1Func("Vil/Paint");
                        end}; {type="Space"},
                        
                        {type="Button", EN="Get Pictures", EN2="Intilize model <font color='rgb(255,0,0)'>[6]</font>", TH1="เก็บข้อมูลรูปภาพ", TH2="ตั้งค่าโมเดลเกม <font color='rgb(255,0,0)'>[6]</font>", Callback=function()
                            Functions:B2C1Func("Vil/Pics");
                        end};
                        {type="Button", EN="Enter House", EN2="Teleport to the main house. <font color='rgb(255,0,0)'>[7]</font>", TH1="เข้าบ้าน", TH2="วาปไปบ้านหลัก <font color='rgb(255,0,0)'>[7]</font>", Callback=function()
                            Functions:B2C1Func("Vil/House");
                        end};
                        {type="Button", EN="Auto Candles", EN2="Teleport & light the candle for you. <font color='rgb(255,0,0)'>[8]</font>", TH1="เทียน", TH2="วาปไปจุดเทียน <font color='rgb(255,0,0)'>[8]</font>", Callback=function()
                            Functions:B2C1Func("Vil/Candle");
                        end}; {type="Space"},

                        {type="Toggle", EN="ESP Kurobozu", EN2="Show box & name", TH1="ESP Kurobozu", TH2="มองเห็น Kurobozu", Path="Vil/ESP/Kurobozu", Callback=function(state)
                            B2C1Con.Village.ESP.Kurobozu = state;
                            Functions:B2C1ESP("Vil/Kurobozu", state);
                        end};
                        {type="Toggle", EN="ESP Ohaguro", EN2="Show box & name", TH1="ESP Ohaguro", TH2="มองเห็น Ohaguro", Path="Vil/ESP/Ohaguro", Callback=function(state)
                            B2C1Con.Village.ESP.Ohaguro = state;
                            Functions:B2C1ESP("Vil/Ohaguro", state);
                        end};
                    }};
                    {Tab={at="B2C1", Title="Ship", Icon="book-open", Path="B2C1"}, Data={
                        {type="Button", EN="Enter Ship", EN2="Teleport to the trigger.", TH1="เข้าเรือ", TH2="วาปไปที่ทางเข้าเรือ", Callback=function()
                            Functions:B2C1Func("Ship/Enter");
                        end};
                        {type="Button", EN="Auto Candle", EN2="Teleport & light the candle.", TH1="ออโต้เทียน", TH2="วาปและจุดเทียน", Callback=function()
                            Functions:B2C1Func("Ship/Candle");
                        end};
                        {type="Button", EN="Auto Run", EN2="Tween to the exit in the chase sequence.", TH1="ออโต้วิ่ง", TH2="ค่อยๆบินไปที่ทางออกในด่านวิ่ง", Callback=function()
                            Functions:B2C1Func("Ship/Run");
                        end}; {type="Space"};
                        {type="Toggle", EN="ESP Monsters", EN2="Show box & name", TH1="ESP ผี", TH2="มองเห็นผี", Path="Ship/ESP/Monsters", Callback=function(state)
                            B2C1Con.Ship.ESP.Monsters = state;
                            Functions:B2C1ESP("Ship/Monsters", state);
                        end};
                    }};
                };
            });

            PackB2C2 = (Chapter == "B2C2" and {
                Tabs={
                    {Tab={at="B2C2", Title="Statue", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Tween to the gate and wait 30 seconds.", TH1="ออโต้ผ่านด่าน", TH2="บินไปที่ประตูแล้วรอประมาณ 30 วินาที", Callback=function()
                            Functions:B2C2Func("Statue");
                        end};
                    }};
                    {Tab={at="B2C2", Title="Crounch", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Tween to the door and wait around 70 seconds.", TH1="ออโต้ผ่านด่าน", TH2="บินไปที่ประตูแล้วรอประมาณ 70 วินาที", Callback=function()
                            Functions:B2C2Func("Crounch");
                        end};
                    }};
                    {Tab={at="B2C2", Title="Meat", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Talk", EN2="Teleport to the NPC but does not talk for you due to anti cheat.", TH1="คุย", TH2="วาปไปหา NPC แต่จะไม่คุยให้เรื่องจากกันโปร", Callback=function()
                            Functions:B2C2Func("Meat/Talk");
                        end};
                        {type="Button", EN="Teleport To Meat", EN2="Teleport the meat but does not collect for you.", TH1="วาปไปหาเนื้อ", TH2="วาปไปหาเนื้อ แต่จะไม่เก็บให้", Callback=function()
                            Functions:B2C2Func("Meat/TpMeat");
                        end};
                        {type="Button", EN="Exit", EN2="Teleport to the exit door &  interact for you.", TH1="ออก", TH2="วาปไปที่ประตูทางออกแล้วกดออกให้", Callback=function()
                            Functions:B2C2Func("Meat/Exit");
                        end};
                        {type="Button", EN="Auto Run", EN2="Tween to the exit door.", TH1="ออโต้วิ่ง", TH2="ค่อยๆบินไปที่ประตูทางออก", Callback=function()
                            Functions:B2C2Func("Meat/Run");
                        end}; {type="Space"}, {type="Space"},
                        {type="Toggle", EN="ESP Ashina", EN2="Show Ashina's hitbox", TH1="ESP Ashina", TH2="มองเห็น Ashina", Path="Meat/ESP/Ashina", Callback=function(state)
                            B2C2Con.Meat.ESP.Ashina = state;
                            Functions:B2C2ESP("Meat/Ashina", state);
                        end};
                        {type="Toggle", EN="ESP Meats", EN2="Show meat's box", TH1="ESP เนื้อ", TH2="มองเห็นเนื้อ", Path="Meat/ESP/Meats", Callback=function(state)
                            B2C2Con.Meat.ESP.Meats = state;
                            Functions:B2C2ESP("Meat/Meats", state);
                        end};
                    }};
                    {Tab={at="B2C2", Title="Lever", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Enter Zone", EN2="Teleport & Interact with white door.", TH1="วาปเข้าด่าน", TH2="วาปไปที่ประตูสีขาวแล้วกดออกให้", Callback=function()
                            return Functions:B2C2Func("Lever/Enter");
                        end};
                        {type="Button", EN="Auto Levers", EN2="Teleport & Interact with levers.", TH1="ออโต้สับคันโยก", TH2="ออโต้สับคันโยกด้วยการวาป", Callback=function()
                            return Functions:B2C2Func("Lever/Auto");
                        end}; {type="Space"};
                        {type="Toggle", EN="ESP Levers", EN2="Show lever's box & name", TH1="ESP คันโยก", TH2="มองเห็นคันโยก", Path="Lever/ESP/Levers", Callback=function(state)
                            B2C2Con.Lever.ESP.Levers = state;
                            Functions:B2C2ESP("Lever/Levers", state);
                        end};
                    }};
                    {Tab={at="B2C2", Title="Math", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport you to the cooking area ( Skip current section ).", TH1="ออโต้ผ่านด่าน", TH2="วาปไปที่ด่านถัดไป ( ข้ามด่านปัจจุบัน )", Callback=function()
                            return Functions:B2C2Func("Math");
                        end};
                        {type="Button", EN="Reveal Number", EN2="Create the correct symbol at the exit door.", TH1="แสดงตัวเลขที่ถูกต้อง", TH2="สร้างสัญลักษ์ที่ถูกต้องที่ประตูทางออก. ", Callback=function()
                            return Functions:B2C2ESP("Math", true);
                        end};
                    }};
                    {Tab={at="B2C2", Title="Gordon Ramsey", Icon="book-open", Path="B2C2"}, Data={
                        {type="Toggle", EN="Auto Complete", EN2="Cooking food for you. This isn't instant toggle so if you want to turn it off; You have to wait. ( Singleplayer )", TH1="ออโต้ผ่านด่าน", TH2="ทำอาหารให้แต่ใช้ได้แค่เวลาเล่นคนเดียว เวลากดปิดจะไม่ปิดทันที", Path="Cook/AutoCook"};
                        {type="Button", EN="Auto Run", EN2="Tween to the exit of this cave.", TH1="ออโต้วิ่ง", TH2="ค่อยๆบินไปที่ทางออกถ้ำ", Callback=function()
                            return Functions:B2C2Func("Cook/Run");
                        end};
                    }};
                    {Tab={at="B2C2", Title="Cursed", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Tween you to the entrance of Cursed Zone 2.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปที่ประตูทางเข้าด่าน 2", Callback=function()
                            return Functions:B2C2Func("Cursed/1");
                        end}; {type="Space"};
                        {type="Button", EN="Enter Zone", EN2="Tween you to Cursed Zone 2.", TH1="เข้าด่าน2", TH2="บินไปที่ด่าน 2", Callback=function()
                            return Functions:B2C2Func("Cursed/2");
                        end};
                        {type="Button", EN="Remove Monster", EN2="This is client side so if you are with your friend, tell them not to go to 2nd floor. You must click this before enter 2nd floor to make it work.", TH1="ลบผีทิ้ง", TH2="ต้องกดก่อนเดินขึ้นไปข้างบน และถ้ามากับเพื่อนบอกให้เพื่อนอยู่แต่ด้านล่าง", Callback=function()
                            return Functions:B2C2Func("Cursed/Remove");
                        end};
                    }};
                    {Tab={at="B2C2", Title="Kid", Icon="book-open", Path="B2C2"}, Data={
                        {type="Button", EN="Find Kid", EN2="Teleport to the kid.", TH1="หาเด็ก", TH2="วาปไปหาเด็ก", Callback=function()
                            return Functions:B2C2Func("Kid/Find");
                        end};
                        {type="Button", EN="Teleport To Gate", EN2="Teleport & Interact with white door.", TH1="วาปเข้าประตู", TH2="วาปเข้าประตูสีขาว", Callback=function()
                            return Functions:B2C2Func("Kid/Gate");
                        end};
                        {type="Toggle", EN="Anti Mother", EN2="Teleport to safe spot when mother is near.", TH1="หลบแม่", TH2="วาปกลับจุดเกิดเวลาเจอแม่", Path="Kid/Anti Mother"};
                        {type="Toggle", EN="ESP Mother", EN2="Show mother's hitbox.", TH1="ESP แม่", TH2="มองเห็นแม่", Path="Kid/ESP/Mother", Callback=function(state)
                            B2C2Con.Kid.ESP.Mother = state;
                            return Functions:B2C2ESP("Kid/Mother", state);
                        end}; {type="Space"}; {type="Space"};
                        {type="Button", EN="Auto Collect Notes", EN2="Teleport & Collect notes.", TH1="ออโต้เก็บโน๊ต", TH2="วาปและเก็บโน๊ต", Callback=function()
                            return Functions:B2C2Func("Kid/Notes");
                        end};
                    }};
                    {Tab={at="B2C2", Title="Nagisa", Icon="book-open", Path="B2C2"}, Data={
                        {type="Toggle", EN="Auto Get Cannon Balls", EN2="Teleport & Grab cannon balls when out of it.", TH1="ออโต้หยิบลูกปืนใหญ่", TH2="วาปและหยิบลูกปืนใหญ่เมื่อเหลือ 0", Path="Nagisa/Auto Get Cannon Balls"};
                        {type="Toggle", EN="Anti Nagisa Beam", EN2="Teleport to safe spot when nagisa uses her beam.", TH1="ออโต้หลบกลิ่นปาก", TH2="วาปไปที่ปลอดภัยเวลามันพ่นกลิ่นปาก", Path="Nagisa/Anti Nagisa Beam"}; {type="Space"};
                        {type="Toggle", EN="Auto Kill Nagisa Serpent", EN2="Teleport & Spam katana", TH1="ออโต้ฆ่า Nagisa Serpent", TH2="วาปและสแปมดาบ", Path="Nagisa/Auto Kill Nagisa Serpent"}; {type="Space"};
                    }};
                };
            });

            PackB2C3 = (Chapter == "B2C3" and {
                Tabs={
                    {Tab={at="B2C3", Title="Gozu & Mezu", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport the the entrance", TH1="ออโต้ผ่านด่าน", TH2="วาปไปที่ทางเข้า", Callback=function()
                            return Functions:B2C3Func("Gozu");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Heart", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Talk", EN2="Teleport to the NPC.", TH1="คุย", TH2="วาปไปหา NPC", Callback=function()
                            return Functions:B2C3Func("Heart/Talk");
                        end};
                        {type="Button", EN="Auto Hearts", EN2="Teleport & Collect hearts.", TH1="ออโต้เก็บหัวใจ", TH2="วาปเก็บหัวใจ", Callback=function()
                            return Functions:B2C3Func("Heart/Auto");
                        end}; {type="Space"};
                        {type="Button", EN="Auto Run", EN2="Teleport to the exit in the chase sequence.", TH1="ออโต้วิ่ง", TH2="วาปไปที่ทางออกในด่านวิ่ง", Callback=function()
                            return Functions:B2C3Func("Heart/Run");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Maze", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Auto Craft", EN2="Teleport, collect items and craft a torch for you.", TH1="ออโต้คราฟ", TH2="วาปเก็บไอเทมมาคราฟแท่งไฟ", Callback=function()
                            return Functions:B2C3Func("Maze/Craft");
                        end};
                        {type="Button", EN="Get Fire", EN2="Teleport & light up your torch. You must equip your torch to use this.", TH1="จุดไฟ", TH2="วาปไปจุดไฟแต่ต้องถือแท่งไฟก่อน", Callback=function()
                            return Functions:B2C3Func("Maze/Fire");
                        end};
                        {type="Button", EN="Escape", EN2="Teleport to the exit.", TH1="ออก", TH2="วาปไปที่ทางออก", Callback=function()
                            return Functions:B2C3Func("Maze/Escape");
                        end}; {type="Space"};
                        {type="Toggle", EN="ESP Monster", EN2="Show monster's hitbox.", TH1="ESP ผี", TH2="มองเห็นผี", Path="Maze/ESP/GrinDemon", Callback=function(state)
                            B2C3Con.Maze.ESP.GrinDemon = state;
                            return Functions:B2C3ESP("Maze/GrinDemon", state);
                        end};
                    }};
                    {Tab={at="B2C3", Title="Bell", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Enter Zone", EN2="Teleport to the cutscene.", TH1="วาปเข้าด่าน", TH2="วาปไปที่คัตซีน", Callback=function()
                            return Functions:B2C3Func("Bell/Zone");
                        end};
                        {type="Button", EN="Kill All Flys", EN2="Teleport & kill all flys.", TH1="ออโต้ฆ่าแมลง", TH2="วาปฆ่าแมลง", Callback=function()
                            return Functions:B2C3Func("Bell/Flys");
                        end};
                        {type="Button", EN="Auto Bell", EN2="Auto ring the bell and attack the monster.", TH1="ออโต้ระฆัง", TH2="ออโต้ตีระฆังและเดี่ยวกับผี", Callback=function()
                            return WindUI:Notify({
                                Title = "<font color='rgb(255,0,0)'>WARNING</font>",
                                Content = "Hold on, Script is Intilizing, Do not press again.",
                                Icon = "circle-alert",
                                Duration = 10,
                            }), tk.delay(15, function()
                                return WindUI:Notify({
                                    Title = "<font color='rgb(255,0,0)'>WARNING</font>",
                                    Content = "Trust the process lol, it seem like it's not working but it actually work.",
                                    Icon = "circle-alert",
                                    Duration = 10,
                                });
                            end), Functions:B2C3Func("Bell/Auto");
                        end}; {type="Space"};
                        {type="Button", EN="Teleport To Door", EN2="Teleport to the puzzle door but does not complete for you.", TH1="วาปไปที่ประตู", TH2="วาปไปที่ประตูเพื่อแก้ปริศนา", Callback=function()
                            return Functions:B2C3Func("Bell/TpDoor");
                        end};
                        {type="Button", EN="Auto Complete Puzzle", EN2="Auto complete the puzzle but you have to be near the door.", TH1="ออโต้แก้ปริศนา", TH2="ออโต้แก้ปริศนาแต่ต้องอยู่ใกล้ประตู", Callback=function()
                            return Functions:B2C3Func("Bell/Puzzle");
                        end};
                        {type="Button", EN="Auto Run", EN2="Teleport to the exit.", TH1="ออโต้วิ่ง", TH2="วาปไปที่ทางออก", Callback=function()
                            return Functions:B2C3Func("Bell/Run");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Enzukai", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Enter Zone", EN2="Teleport to enzukai.", TH1="วาปเข้าด่าน", TH2="วาปไปที่ผี", Callback=function()
                            return Functions:B2C3Func("Enzukai/Enter");
                        end};
                        {type="Button", EN="Auto Complete", EN2="Auto interact with Enzukai.", TH1="ออโต้ผ่านด่าน", TH2="ออโต้คุยกับผีตอนอยู่บนแพ", Callback=function()
                            return Functions:B2C3Func("Enzukai/Auto");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Father", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Disable Isamu", EN2="Ignore his action bro he's not gonna kill us.", TH1="เพิกเฉยต่อการโจมตีของ Isamu", TH2="สนใจทำไมก็แค่ผีตัวนึง", Callback=function()
                            return Functions:B2C3Func("Father/Isamu");
                        end};
                        {type="Button", EN="Teleport To Safe Spot", EN2="Your sanity will drain but last long enough to survive each night.", TH1="วาปไปจุดที่ปลอดภัย", TH2="ค่าสติจะลดไวขึ้นแต่ก็อยู่ได้นานพอสำหรับคืนถัดไป", Callback=function()
                            return Functions:B2C3Func("Father/Auto");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Train", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Enter Zone", EN2="Teleport to the arrival area.", TH1="วาปเข้าด่าน", TH2="วาปไปที่รถไฟ", Callback=function()
                            return Functions:B2C3Func("Train");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Larves", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport to the exit.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปทางออก", Callback=function()
                            return Functions:B2C3Func("Larves");
                        end}; {type="Space"};
                        {type="Toggle", EN="ESP Larves", EN2="Show larve's hitbox.", TH1="ESP หนอน", TH2="มองเห็นหนอน", Path="Larves/ESP/Larves", Callback=function(state)
                            B2C3Con.Larves.ESP.Larves = state;
                            return Functions:B2C3ESP("Larves/Larves", state);
                        end};
                        {type="Toggle", EN="ESP Soldier", EN2="Show soldier's hitbox.", TH1="ESP ทหาร", TH2="มองเห็นทหาร", Path="Larves/ESP/Soldier", Callback=function(state)
                            B2C3Con.Larves.ESP.Soldier = state;
                            return Functions:B2C3ESP("Larves/Soldier", state);
                        end};
                        {type="Toggle", EN="ESP Boogey", EN2="Show Boogeyman's hitbox.", TH1="ESP บูกี้แมน", TH2="มองเห็นบูกี้แมน", Path="Larves/ESP/Boogey", Callback=function(state)
                            B2C3Con.Larves.ESP.Boogey = state;
                            return Functions:B2C3ESP("Larves/Boogey", state);
                        end};
                    }};
                    {Tab={at="B2C3", Title="Mud", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport to the exit.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปทางออก", Callback=function()
                            return Functions:B2C3Func("Mud");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Yurei", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Teleport To House", EN2="Teleport to the house; right at the interaction.", TH1="วาปเข้าบ้าน", TH2="วาปไปที่บ้าน จุดที่เอาไว้แก้ปริศนา", Callback=function()
                            return Functions:B2C3Func("Yurei/House");
                        end};
                        {type="Button", EN="Auto Click Items", EN2="Click all cursed items.", TH1="ออโต้กดไอเทม", TH2="ออโต้กดคลิกไอเทมที่ถูกต้อง", Callback=function()
                            return Functions:B2C3Func("Yurei/Click");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Boss", Icon="book-open", Path="B2C3"}, Data={
                        {type="Toggle", EN="Auto Complete", EN2="Auto kill Yurei. Do not turn this on before the fight has started.", TH1="ออโต้ผ่านด่าน", TH2="ออโต้ฆ่าผี ห้ามเปิดก่อนที่สงครามจะเริ่ม", Path="Boss/AutoKillYurei"}; {type="Space"};
                        {type="Button", EN="Clear Map", EN2="Remove map's border.", TH1="เคลียพื้นที่", TH2="ลบกำแพงแมพออก", Callback=function()
                            return Functions:B2C3Func("Boss/Map");
                        end};
                        {type="Button", EN="Teleport To Safe Spot", EN2="Teleport you outside the border.", TH1="วาปไปจุดที่ปลอดภัย", TH2="วาปออกไปนอกกำแพงแมพ", Callback=function()
                            return Functions:B2C3Func("Boss/TpSafe");
                        end};
                        {type="Button", EN="Get Katanas", EN2="Teleport & grab katanas", TH1="เก็บดาบ", TH2="วาปเก็บดาบ", Callback=function()
                            return Functions:B2C3Func("Boss/Katanas");
                        end};
                    }};
                    {Tab={at="B2C3", Title="Hell", Icon="book-open", Path="B2C3"}, Data={
                        {type="Button", EN="Auto Run", EN2="Teleport to the exit.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปทางออก", Callback=function()
                            return Functions:B2C3Func("Hell/Run");
                        end};
                    }};
                };
            });

            PackB2C4 = (Chapter == "B2C4" and {
                Tabs = {
                    {Tab={at="B2C4", Title="Bypass", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Patched Inventory", EN2="Sometimes your inventory just stuck on your screen and you can't do anything except rejoin BUT this button will fix it.", TH1="แก้บัคกระเป๋า", TH2="บางทีกระเป๋ามันค้างอยู่กลางจอละมันต้องออกเข้าใหม่ แต่กดปุ่มนี้แก้ได้", Callback=Functions.INVBP};
                        {type="Button", EN="Patched Reporter Cutscene", EN2="In the 6 floor building, there is an NPC for you to talk with but sometime the anti cheat can break your cutscene.", TH1="แก้บัคอัคซีนของนักข่าว", TH2="ในด่านตึก 6 ชั้นจะมี NPC ให้เราไปคุยแล้วในบางตัวรันมันโดนกันโปรทำบัค ให้กดปุ่มนี้เวลาบัค", Callback=Functions.B2C4BP1};
                        {type="Button", EN="Patched Mother's Game", EN2="In the minigame where mother will be asking you questions and you have to answer, the anti cheat will stop the answer from appearing, use this to fix it.", TH1="แก้บัคคำถามของแม่", TH2="ในด่านมินิเกมที่แม่จะถามคำถามแล้วเราต้องตอบ ในบางตัวรันมันโดนกันโปรทำบัค ให้กดปุ่มนี้เวลาบัค", Callback=Functions.B2C4BP2};
                    }};
                    {Tab={at="B2C4", Title="Cave", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport to the exit of this cave.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปที่ทางออกถ้ำ", Callback=function()
                            return Functions:B2C4Func("Cave");
                        end};
                    }};
                    {Tab={at="B2C4", Title="City", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Auto Complete", EN2="Teleport to the white door.", TH1="ออโต้ผ่านด่าน", TH2="วาปไปที่ประตูสีขาว", Callback=function()
                            return Functions:B2C4Func("City/Auto");
                        end}; {type="Space"};
                        {type="Button", EN="Destroy Glass", EN2="Remove glasses from the floor.", TH1="ลบกระจกออก", TH2="ลบกระจกที่อยู่บนพื้นออก", Callback=function()
                            return Functions:B2C4Func("City/Glass");
                        end};
                        {type="Toggle", EN="ESP Glass", EN2="Show glass's hitbox.", TH1="ESP กระจก", TH2="มองเห็นกระจก", Path="City/ESP/Glass", Callback=function(state)
                            B2C4Con.City.ESP.Glass = state;
                            return Functions:B2C4ESP("City/Glass", state);
                        end};
                        {type="Toggle", EN="ESP Enzukai", EN2="Show Enzukai's hitbox.", TH1="ESP ผี", TH2="มองเห็นผี", Path="City/ESP/Enzukai", Callback=function(state)
                            B2C4Con.City.ESP.Enzukai = state;
                            return Functions:B2C4ESP("City/Enzukai", state);
                        end};
                    }};
                    {Tab={at="B2C4", Title="Office", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Talk", EN2="Teleport to NPC.", TH1="คุย", TH2="วาปไปหา NPC", Callback=function()
                            return Functions:B2C4Func("Office/Talk");
                        end};
                        {type="Button", EN="Auto Codes", EN2="You have to interact with the keypad first.", TH1="ออโต้ใส่โค้ด", TH2="ต้องกดปุ่มที่ประตูก่อน", Callback=function()
                            return Functions:B2C4Func("Office/Auto");
                        end}; {type="Space"};
                        {type="Button", EN="Collect Item", EN2="Teleport, collect item, and escape. (Rooftop)", TH1="ออโต้ผ่านด่าน", TH2="วาปเก็บไอเทมและออก (ชั้นดาดฟ้า)", Callback=function()
                            return Functions:B2C4Func("Office/Top");
                        end};
                    }};
                    {Tab={at="B2C4", Title="Mall", Icon="book-open", Path="B2C4"}, Data={
                        {type="Paragraph", Title="Tutorial", Desc=[[<font color="#ff0000">You don't need auto coins</font>, <font color="#ffffff">All you have to do is punch & grab speaker then place it and escape. You can check YouTube video to understand more about it.</font>]]};
                        {type="Button", EN="Auto Walkie Talkis", EN2="Teleport & interact with walkie talkie", TH1="ออโต้กดวอสื่อสาร", TH2="วาปและกดใช้งาน", Callback=function()
                            return Functions:B2C4Func("Mall/Talk");
                        end};
                        {type="Button", EN="Auto Trigger Escape", EN2="Teleport to the entrance to trigger the game event.", TH1="ออโต้หลบหนี", TH2="วาปไปที่ทางเข้าเพื่อเริ่คัตซีน", Callback=function()
                            return Functions:B2C4Func("Mall/Trigger");
                        end};
                        {type="Button", EN="Auto Punch Eyes", EN2="Teleport & punch eyes.", TH1="ออโต้ต่อยดวงตา", TH2="วาปและต่อยดวงตา", Callback=function()
                            return Functions:B2C4Func("Mall/Eyes");
                        end};
                        {type="Button", EN="Grab Speaker", EN2="Teleport & grab the speaker.", TH1="เก็บลำโพง", TH2="วาปและเก็บลำโพง", Callback=function()
                            return Functions:B2C4Func("Mall/Grab");
                        end};
                        {type="Button", EN="Place Speaker", EN2="Teleport & place the speaker.", TH1="วางลำโพลง", TH2="วาปและวางลำโพง", Callback=function()
                            return Functions:B2C4Func("Mall/Place");
                        end}; {type="Space"};
                        {type="Toggle", EN="ESP Coins", EN2="Show coin's box.", TH1="ESP เหรียญ", TH2="มองเห็นเหรียญ", Path="Mall/ESP/Coins", Callback=function(state)
                            B2C4Con.Mall.ESP.Coins = state;
                            return Functions:B2C4ESP("Mall/Coins", state);
                        end};
                        {type="Toggle", EN="ESP Walkie Talkies", EN2="Show walkie talkie's box.", TH1="ESP วอสื่อสาร", TH2="มองเห็นวอสื่อสาร", Path="Mall/ESP/Glass", Callback=function(state)
                            B2C4Con.Mall.ESP.Walkie = state;
                            return Functions:B2C4ESP("Mall/Talk", state);
                        end};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox.", TH1="ESP ผี", TH2="มองเห็นผี", Path="Mall/ESP/Monsters", Callback=function(state)
                            B2C4Con.Mall.ESP.Monsters = state;
                            return Functions:B2C4ESP("Mall/Monsters", state);
                        end}; {type="Space"}; {type="Divider"}; {type="Space"};
                        {type="Button", EN="Auto Chase 1", EN2="The floor at the end of the chase must fall so that mean everything must be loaded before you use this. You can watch my YouTube tutorial to use this one.", TH1="ออโต้วิ่ง 1", TH2="พื้นห้างในตอนท้ายพัง หมายความว่าก่อนกดใช้งานต้องมั่นใจก่อนว่าแมพโหลดเสร็จแล้ว หรือลองเปิด YouTube ดูก็ได้", Callback=function()
                            return Functions:B2C4Func("Mall/Chase1");
                        end};
                        {type="Button", EN="Auto Chase 2", EN2="Teleport to the elevator.", TH1="ออโต้วิ่ง 2", TH2="วาปไปที่ลิฟ", Callback=function()
                            return Functions:B2C4Func("Mall/Chase2");
                        end};
                    }};
                    {Tab={at="B2C4", Title="Car", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Auto Collect Car Parts", EN2="Teleport & collect all car parts.", TH1="ออโต้เก็บชิ้นส่วนรถ", TH2="วาปแล้วเก็บชิ้นส่วนรถทั้งหมด", Callback=function()
                            return Functions:B2C4Func("Car/Collect");
                        end};
                        {type="Button", EN="Answer", EN2="Give mother the correct answer.", TH1="ตอบคำถาม", TH2="แม่!!! ผมตอบถูกแล้ว", Callback=function()
                            return Functions:B2C4Func("Car/Answer");
                        end};
                    }};
                    {Tab={at="B2C4", Title="Drawing", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Teleport Outside", EN2="Teleport to the gate.", TH1="วาปไปข้างนอก", TH2="วาปไปที่ทางเข้าหมู่บ้าน", Callback=function()
                            return Functions:B2C4Func("Draw/Outside");
                        end};
                        {type="Button", EN="Teleport Inside", EN2="Enter the village without trigger Senzai. Make sure you go back to the gat entrance after reaching 3/4 pillars so the game continue.", TH1="วาปไปข้างใน", TH2="วาปไปในหมู่บ้านทำให้ผีไม่เกิด โดยต้องกลับไปที่ทางเข้าเพื่อให้ผีเกิดตอนได้ครบ3/4เพื่อให้เล่นต่อได้", Callback=function()
                            return Functions:B2C4Func("Draw/Inside");
                        end};
                        {type="Button", EN="Teleport To Pad", EN2="Teleport to the drawing pad.", TH1="วาปไปที่แท่น", TH2="วาปไปที่แท่นวาดรูป", Callback=function()
                            return Functions:B2C4Func("Draw/Tp");
                        end};
                        {type="Button", EN="Draw", EN2="This only draw for you; Enter by yourself.", TH1="วาดรูป", TH2="วาดอย่างเดียว ไม่มีการวาปให้", Callback=function()
                            return Functions:B2C4Func("Draw/Draw");
                        end};
                        {type="Button", EN="Teleport To Pillar", EN2="Teleport to the pillar.", TH1="วาปไปที่เสา", TH2="วาปไปที่เสาผี", Callback=function()
                            return Functions:B2C4Func("Draw/Pillar");
                        end};
                        {type="Button", EN="Collect Quest Items", EN2="Teleport & collect item dropped.", TH1="ออโต้เก็บไอเทมจากผี", TH2="วาปและเก็บไอเทมที่ดรอปจากผี", Callback=function()
                            return Functions:B2C4Func("Draw/Item");
                        end}; {type="Space"};
                        {type="Toggle", EN="ESP Senzai", EN2="Show Senzai's hitbox.", TH1="ESP ผี", TH2="มองเห็นผี", Path="Draw/ESP/Senzai", Callback=function(state)
                            B2C4Con.Draw.ESP.Senzai = state;
                            return Functions:B2C4ESP("Draw/Senzai", state);
                        end};
                        {type="Toggle", EN="ESP Ingredients", EN2="Show ingredient's box.", TH1="ESP วัตถุดิบ", TH2="มองเห็นวัตถุดิบ", Path="Draw/ESP/Ingredients", Callback=function(state)
                            B2C4Con.Draw.ESP.Ingredients = state;
                            return Functions:B2C4ESP("Draw/Ingredients", state);
                        end};
                        {type="Toggle", EN="ESP Drawings", EN2="Show pad's box.", TH1="ESP แท่นวาดรูป", TH2="มองเห็นแท่นวาดรูป", Path="Draw/ESP/Pad", Callback=function(state)
                            B2C4Con.Draw.ESP.Drawings = state;
                            return Functions:B2C4ESP("Draw/Drawings", state);
                        end};
                    }};
                    {Tab={at="B2C4", Title="Enzukai", Icon="book-open", Path="B2C4"}, Data={
                        {type="Button", EN="Godmode", EN2="Disable monsters from touching you.", TH1="อมตะ", TH2="กันไม่ให้ผีแตะตัวได้", Callback=function()
                            return Functions:B2C4Func("Godmode");
                        end}; {type="Space"}; {type="Divider"}; {type="Space"};
                        {type="Button", EN="Auto Help Survivors", EN2="Teleport & interact with survivors.", TH1="ออโต้ช่วยคน", TH2="วาปและช่วยเหลือ", Callback=function()
                            return Functions:B2C4Func("Survivors");
                        end};
                        {type="Toggle", EN="ESP Survivors", EN2="Show survivor's box.", TH1="ESP ผู้รอดชีวิต", TH2="มองเห็นผู้รอดชีวิต", Path="Enzukai/ESP/Survivors", Callback=function(state)
                            B2C4Con.Enzukai.ESP.Survivors = state;
                            return Functions:B2C4ESP("Survivors", state);
                        end}; {type="Space"}; {type="Divider"}; {type="Space"};
                        {type="Toggle", EN="Auto Kill Enzukai-Ryu", EN2="Auto get supercharge and kill Enzukai.", TH1="ออโต้ฆ่า Enzukai", TH2="ออโต้ชาจและฆ่า Enzukai", Path="Enzukai/Auto Kill Enzukai-Ryu"};
                        {type="Toggle", EN="Auto Kill Monsters", EN2="Auto kill Enzukai's follower.", TH1="ออโต้ฆ่าผี", TH2="ออโต้ฆ่าลูกน้อง Enzukai", Path="Enzukai/Auto Kill Enzukai Followers"};
                        {type="Toggle", EN="ESP Followers", EN2="Show follower's box.", TH1="ESP ผี3ตัว", TH2="มองเห็นผีลุกน้องEnzukai", Path="Enzukai/ESP/Followers", Callback=function(state)
                            B2C4Con.Enzukai.ESP.Followers = state;
                            return Functions:B2C4ESP("Followers", state);
                        end};
                    }};
                    {Tab={at="B2C4", Title="Boss", Icon="book-open", Path="B2C4"}, Data={
                        {type="Toggle", EN="Auto Kill Final Boss", EN2="Auto kill EnzukaiRyu-Jin.", TH1="ออโต้ฆ่าบอส", TH2="ออโต้ฆ่า EnzukaiRyu-Jin", Path="Final/Auto Kill Final Boss"};
                    }};
                };
            });
        };

        CoruTask.New("B2C2@Cook", function()
            if Chapter ~= "B2C2" then
                return CoruTask.Close("B2C2@Cook");
            end;
            
            local matches = {};
            local selected = nil;
            local selectedObj = nil;

            local GetFromCook = Functions.GetFromCook;
            local PlaceCoun = Functions.PlaceCoun;
            local ToStove = Functions.ToStove;
            local TurnInFood = Functions.TurnInFood;
            
            while true do
                if not B2C2Con.Cook.AutoCook or CoreDestroyed then
                    return CoruTask.Close("B2C2@Cook");
                end; if not PSG.CookingUI.Timer.Visible then
                    twait(0.1); continue;
                end; if not ScriptCache.BarrierCook then
                    local Folder = Functions:B2C1Get("Workspace.Section3.Build2");
                    if not Folder then twait(0.1); continue; end;
                    local CHs = GetChildren(Folder); for i=1, #CHs do
                        local v = CHs[i]; if v.Name == "Barrier" and dist(v.Position) <= 100 then
                            v:Destroy();
                        end;
                    end; ScriptCache.BarrierCook = true;
                end;

                local Orders = Functions:B2C1Get("Workspace.Section3.Cooking.Orders");
                if not Orders then twait(0.1); continue; end; local CHs = GetChildren(Orders);
                local Givers = Functions:B2C1Get("Workspace.Section3.Cooking.Givers");
                local Stoves = Functions:B2C1Get("Workspace.Section3.Cooking.Stoves.stove.Detector.ProximityPrompt");
                local Counter = Functions:B2C1Get("Workspace.Section3.Cooking.WoodenCounters.WoodenCounter");
                local ChefPrompt = Functions:B2C1Get("Workspace.Section3.Cooking.TurnInFood.Detector.ProximityPrompt");

                for i=1, #CHs do
                    local v = CHs[i]; if v.Parent then
                        tblein(matches, v.Name);
                    end;
                end; if #matches > 0 then
                    selected = math.random(1, #matches);
                    selectedObj = matches[selected];
                    matches = {};
                    if selectedObj == "Ham Stew" then
                        GetFromCook(Givers, "Pot");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Ham");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Sausage");
                        PlaceCoun(Counter);
                        PlaceCoun(Counter);
                        ToStove(Stoves); twait(10);
                        if not B2C2Con.Cook.AutoCook or CoreDestroyed then
                            continue;
                        end; GetFromCook(Givers, "Bowl");
                        PlaceCoun(Counter);
                        ToStove(Stoves);
                        PlaceCoun(Counter);
                        PlaceCoun(Counter);
                        TurnInFood(ChefPrompt);
                    elseif selectedObj == "Chicken Soup" then
                        GetFromCook(Givers, "Pot");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Chicken");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Wrapped Meat");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Cheese");
                        PlaceCoun(Counter);
                        PlaceCoun(Counter);
                        ToStove(Stoves); twait(10);
                        if not B2C2Con.Cook.AutoCook or CoreDestroyed then
                            continue;
                        end; GetFromCook(Givers, "Bowl");
                        PlaceCoun(Counter);
                        ToStove(Stoves);
                        PlaceCoun(Counter);
                        PlaceCoun(Counter);
                        TurnInFood(ChefPrompt);
                    elseif selectedObj == "Spaghetti N Eyeballs" then
                        GetFromCook(Givers, "Bowl");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Eyeball");
                        PlaceCoun(Counter);
                        GetFromCook(Givers, "Spaghetti");
                        PlaceCoun(Counter);
                        PlaceCoun(Counter);
                        TurnInFood(ChefPrompt);
                    end;
                end; twait(0.1);
            end;
        end);

        CoruTask.New("B2C2@Mother", function()
            if Chapter ~= "B2C2" then
                return;
            end; while true do
                if not B2C2Con.Kid["Anti Mother"] or CoreDestroyed then
                    return CoruTask.Close("B2C2@Mother");
                end;

                local Object = Functions:B2C1Get("Workspace.Section4.Monsters.Mother.HumanoidRootPart");
                if Object then
                    if Object.Parent.Parent then
                        if dist(Object.Position) <= 150 then
                            Tp(HumRSelf, CFr(-4334.81299, 690.94397, -2363.2771));
                        end;
                    else
                        return;
                    end;
                end; twait(0.1);
            end;
        end);

        CoruTask.New("B2C2@Cannon&Lazer", function()
            if Chapter ~= "B2C2" then return; end;
            local SAFEPOS = CFr(1982.58, 100, -4780.12); while true do
                if not (B2C2Con.Nagisa["Auto Get Cannon Balls"] or B2C2Con.Nagisa["Anti Nagisa Beam"]) or CoreDestroyed then
                    return CoruTask.Close("B2C2@Cannon&Lazer");
                end;

                local BallGiver = Functions:B2C1Get("Workspace.Section5.BATTLESHIP.BallGivers.BallGiver.Interact.ProximityPrompt");
                local Laser = Functions:B2C1Get("Workspace.Section5.BOSS.NureMain.POISON");

                if BallGiver and Laser then
                    if B2C2Con.Nagisa["Auto Get Cannon Balls"] then
                        if PSG.BossFight.Ammo.Text == "0" and Laser.Transparency ~= 0.5 then
                            Tp(HumRSelf, BallGiver.Parent.CFrame, 0.3); for i=1, 5 do
                                fireproximityprompt(BallGiver, 1);
                            end;
                        end
                    end;
                    if B2C2Con.Nagisa["Anti Nagisa Beam"] then
                        if Laser.Transparency ~= 1 then
                            Tp(HumRSelf, SAFEPOS);
                        end;
                    end;
                end; twait(0.1);
            end;
        end);

        CoruTask.New("B2C2@Serpent", function()
            if Chapter ~= "B2C2" then return; end;

            local ShouldPause = false;
            local Connection = nil;
            local SAFEPOS = CFr(1972, 100, -4772);

            while true do
                if not B2C2Con.Nagisa["Auto Kill Nagisa Serpent"] or CoreDestroyed then
                    if Connection then
                        ShouldPause = false;
                        Connection:Disconnect();
                        Connection = nil;
                    end; return CoruTask.Close("B2C2@Serpent");
                end;
                
                if Connection then twait(0.1); continue; end;
                local Object = Functions:B2C1Get("Workspace.Section5.Stage2BOSS.NureStage2.TailHitbox1");
                if not Object then twait(0.1); continue; end;
                
                Connection = TrackSignal(H.RenderStepped, function()
                    if not selc.Parent or not HumRSelf.Parent then return; end;
                    if ShouldPause then return; end; if Object then
                        if not Functions:ToolNow("Cutlass") then
                            local Cutlass = Functions:B2C1Get("Workspace.Section5.BATTLESHIP.CutlassGiverModel.cutlass.ProximityPrompt");
                            if Cutlass and Cutlass.Enabled then
                                ShouldPause = true;
                                Tp(HumRSelf, Cutlass.Parent.CFrame, 0.3);
                                fireproximityprompt(Cutlass);
                            end;

                            if not Functions.Cutlass then
                                Functions.Cutlass = WaitForChild(BP, "Cutlass", 3);
                            end; ShouldPause = false;
                        else
                            if not FindFirstChild(Object, "TouchInterest") then
                                Tp(HumRSelf, Object.CFrame);
                                Functions:ToolActive("Cutlass");
                            else
                                Tp(HumRSelf, SAFEPOS);
                            end;
                        end;
                    end;
                end); twait(0.1);
            end;
        end);

        CoruTask.New("B2C3@Yurei", function()
            if Chapter ~= "B2C3" then return; end;

            local Yurei = nil;
            local BZONE = Vec3(3009, 17, -416);

            local modeDeadline = os.clock() + 20;
            repeat twait(0.1); until Functions.GameMode ~= nil or CoreDestroyed or os.clock() > modeDeadline;
            if CoreDestroyed or not Functions.GameMode then return; end; if Functions.GameMode == "Normal" then
                Yurei = WaitForChild(W.Section5.Boss.MonsterFolder, "Yurei", 30);
            else
                Yurei = WaitForChild(W.Section5.Boss.MonsterFolder, "YureiNM", 30);
            end;

            while true do
                if not B2C3Con.Boss["AutoKillYurei"] or CoreDestroyed then
                    Functions:FreeCam(false);
                    if dist(BZONE) < 600 then
                        Tp(HumRSelf, CFr(BZONE), 0.3);
                    end; return CoruTask.Close("B2C3@Yurei");
                end;

                if PSG.BossFight.Enabled then
                    if dist(BZONE) < 600 then
                        local Katana = FindFirstChild(BP, "Katana") or FindFirstChild(selc, "Katana");
                        if not Katana then
                            Functions:B2C3Func("Boss/Katanas");
                            continue;
                        else
                            Functions.Katana=Katana;
                            if Functions:ToolNow("Katana") then
                                Functions:FreeCam(true); ForceFloat = true;
                                Tp(HumRSelf, Yurei.Body.CFrame * CFr(0, -40, 0), 0.3);
                                Cam.CFrame = CFr(selc.Head.Position, Yurei.Body.Position);
                                Functions:ToolActive("Katana");
                            end; Functions:FreeCam(false); ForceFloat = "None";
                        end;
                    end;
                else
                    Tp(HumRSelf, CFr(BZONE), 0.3);
                end; twait(0.1);
            end;
        end);

        CoruTask.New("UNIFIED-Yen", function()
            local SpawnFolder = nil;
            
            if Chapter == "B2C2" or Chapter == "B2C3" or Chapter == "B2C4" then
                local MimicCurrencySpawns = WaitForChild(W, "MimicCurrencySpawns", 30);
                SpawnFolder = WaitForChild(MimicCurrencySpawns, "Yen", 30);
            elseif Chapter == "B3C1" then
                SpawnFolder = WaitForChild(W, "Yen", 30);
            else return; end;

            while true do
                if not (YenCon.ESP or YenCon.Aura or YenCon.Auto) or CoreDestroyed then
                    ESPF.Visible("Yen", false);
                    return CoruTask.Close("UNIFIED-Yen");
                end; 

                local SAVEDPOS, WAS = HumRSelf.Parent and HumRSelf.CFrame, YenCon.Auto;
                local CHs = GetChildren(SpawnFolder); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Prox = FindFirstChildOfClass(v, "ProximityPrompt");
                        if not Prox then continue; end;

                        if YenCon.Auto and Prox.Enabled then
                            Tp(HumRSelf, v.CFrame, 0.3); fireproximityprompt(Prox);
                        elseif YenCon.Aura and dist(v.Position) <= 20 then
                            fireproximityprompt(Prox);
                        end; if YenCon.ESP then
                            local ESPObject = ESPF.ESP("Yen", v, {
                                Color = BLUE;
                                Size = VEC2;
                                Text = "Yen";
                            });
                        end;
                    end;
                end; if WAS then Tp(HumRSelf, SAVEDPOS); end;
                if YenCon.ESP then ESPF.Visible("Yen", true, true); end;

                twait(0.1);
            end;
        end);

        CoruTask.New("B2C4@EnzukaiRyu", function()
            if Chapter ~= "B2C4" then return; end;

            local EnzukaiRyu = WaitForChild(W.Section4, "BossMonster", 30);
            EnzukaiRyu = WaitForChild(EnzukaiRyu, "EnzukaiRyu", 30);

            local SAFEPOS = CFr(46, 140, -2854);

            while true do
                if not B2C4Con.Enzukai["Auto Kill Enzukai-Ryu"] or CoreDestroyed then
                    ForceFloat = "None"; return CoruTask.Close("B2C4@EnzukaiRyu");
                end;

                if not EnzukaiRyu or not EnzukaiRyu.Parent or PSG.S4.Health.Front.Size == DIM0010 then
                    twait(0.1);
                    continue;
                end;

                if GetAttribute(EnzukaiRyu, "State") == 0 then
                    Tp(HumRSelf, SAFEPOS);
                elseif GetAttribute(EnzukaiRyu, "Mover_StartPivot") == nil then
                    Tp(HumRSelf, SAFEPOS);
                else
                    ForceFloat = true; if PSG.S4.Frame.Visible then
                        local EnzukaiRyuPos = EnzukaiRyu.Hitbox.Position;
                        local ENZLookVector = EnzukaiRyu.Hitbox.CFrame.LookVector;
                        Tp(HumRSelf, CFr(Vec3(EnzukaiRyuPos.X, EnzukaiRyuPos.Y + 10, EnzukaiRyuPos.Z) - ENZLookVector * 100));
                        tk.spawn(function() Functions:MagicArrowHit(Functions:ToolNow("Bow"), EnzukaiRyuPos, 0.7); end);
                    else
                        local CHs = GetChildren(W.Section4.WeakPoints.Points); for i=1, #CHs do
                            local v=CHs[i]; if v.Parent then
                                local Root = FindFirstChild(v, "RootPart");
                                local Icon = Root and FindFirstChild(Root, "Icon");
                                if not Icon or not Icon.Enabled then continue; end;

                                repeat
                                    if v.Parent then
                                        local Target, Focus = nil, nil;
                                        
                                        if v.EyeA.Transparency == 0 then Target = v.HitBoxA; Focus = v.EyeA; end;
                                        if v.EyeB.Transparency == 0 then Target = v.HitBoxB; Focus = v.EyeB; end;
                                        if v.EyeC.Transparency == 0 then Target = v.HitBoxC; Focus = v.EyeC; end;
                                        if v.EyeD.Transparency == 0 then Target = v.HitBoxD; Focus = v.EyeD; end;
                                        if v.EyeE.Transparency == 0 then Target = v.HitBoxE; Focus = v.EyeE; end;

                                        if not Target then break; end;
                                        local TargetPos, UpVector = nil, nil;

                                        while Focus.Transparency == 0 and Target.Parent and B2C4Con.Enzukai["Auto Kill Enzukai-Ryu"] and not CoreDestroyed do
                                            TargetPos = Target.Position;
                                            UpVector = Target.CFrame.UpVector;
                                            Tp(HumRSelf, CFr(Vec3(TargetPos.X, 50, TargetPos.Z) + UpVector * 20));
                                            Functions:MagicArrowHit(Functions:ToolNow("Bow"), TargetPos, 0.7); twait(0.01);
                                        end;
                                    end; twait(0.1);
                                until PSG.S4.Frame.Visible or not Root.Parent or not Icon.Parent or not Icon.Enabled or CoreDestroyed or not B2C4Con.Enzukai["Auto Kill Enzukai-Ryu"]; 
                            end;
                        end;
                    end;
                end; twait(0.1);
            end;
        end);

        CoruTask.New("B2C4@Followers", function()
            if Chapter ~= "B2C4" then return; end;

            local self = Functions;
            
            while true do
                if not B2C4Con.Enzukai["Auto Kill Enzukai Followers"] or CoreDestroyed then
                    ForceFloat = "None"; return CoruTask.Close("B2C4@Followers");
                end;

                if not PSG.S4.Frame.Visible then
                    ForceFloat = true; local CHs = GetChildren(W.Section4.WeakPoints.Points); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local Root = FindFirstChild(v, "RootPart");
                            local Icon = Root and FindFirstChild(Root, "Icon");
                            if not Icon or not Icon.Enabled then continue; end;

                            repeat
                                if v.Parent then
                                    local Target, Focus = nil, nil;
                                    
                                    if v.EyeA.Transparency == 0 then Target = v.HitBoxA; Focus = v.EyeA; end;
                                    if v.EyeB.Transparency == 0 then Target = v.HitBoxB; Focus = v.EyeB; end;
                                    if v.EyeC.Transparency == 0 then Target = v.HitBoxC; Focus = v.EyeC; end;
                                    if v.EyeD.Transparency == 0 then Target = v.HitBoxD; Focus = v.EyeD; end;
                                    if v.EyeE.Transparency == 0 then Target = v.HitBoxE; Focus = v.EyeE; end;

                                    if not Target then break; end;
                                    local TargetPos, UpVector = nil, nil;

                                    while Focus.Transparency == 0 and Target.Parent and B2C4Con.Enzukai["Auto Kill Enzukai Followers"] and not CoreDestroyed do
                                        TargetPos = Target.Position;
                                        UpVector = Target.CFrame.UpVector;
                                        Tp(HumRSelf, CFr(Vec3(TargetPos.X, 50, TargetPos.Z) + UpVector * 20));
                                        Functions:MagicArrowHit(Functions:ToolNow("Bow"), TargetPos, 0.7); twait(0.01);
                                    end;
                                end; twait(0.1);
                            until PSG.S4.Frame.Visible or not Root.Parent or not Icon.Parent or not Icon.Enabled or CoreDestroyed or not B2C4Con.Enzukai["Auto Kill Enzukai Followers"]; 
                        end;
                    end; ForceFloat = "None";
                else
                    local CHs = {self.Rin2, self.Tenome2, self.Tsukiya2}; for i=1, #CHs do
                        local v=CHs[i]; if v and v.Parent then
                            local Root = FindFirstChild(v, "HumanoidRootPart");
                            if not Root then continue; end;
                            
                            repeat
                                if GetAttribute(v, "State") == 0 then
                                    Tp(HumRSelf, Root.CFrame, 0.3);
                                    fireproximityprompt(Root.ProximityPrompt, 1);
                                else
                                    local Pos = Root.Position;
                                    Tp(HumRSelf, CFr(Vec3(Pos.X, Pos.Y, Pos.Z) + Root.CFrame.LookVector * 20));
                                    tk.spawn(function() Functions:MagicArrowHit(Functions:ToolNow("Bow"), Pos, 0.7); end);
                                end; twait(0.01);
                            until not v.Parent or not Root.Parent or not B2C4Con.Enzukai["Auto Kill Enzukai Followers"] or CoreDestroyed;
                        end;
                    end;
                end; twait(0.1);
            end;
        end);

        CoruTask.New("B2C4@EnzukaiJin", function()
            if Chapter ~= "B2C4" then return; end;

            local EnzukaiRyujin = WaitForChild(W.Section5.FinalForm, "EnzukaiRyujin", 30);
            local Moves = W.Section5.FinalForm.Moves;
            local SAFEPOS = CFr(53.280338287353516, 5.957849025726318, -0.8933286666870117);
            
            while true do
                if not B2C4Con.Final["Auto Kill Final Boss"] or CoreDestroyed then
                    ForceFloat = "None";
                    return CoruTask.Close("B2C4@EnzukaiJin");
                end;

                if not EnzukaiRyujin.Parent then
                    twait(0.1); continue;
                end;

                if GetAttribute(EnzukaiRyujin.VAnimator.Slam, "IsPlaying") == true then
                    Tp(HumRSelf, SAFEPOS);
                elseif PSG.S5.Frame.Visible then
                    ForceFloat = true; local HeadCF = EnzukaiRyujin.HeadHitBox.CFrame;
                    Tp(HumRSelf, HeadCF * CFr(-20, 0, 0));
                    tk.spawn(function() Functions:MagicArrowHit(Functions:ToolNow("Bow"), HeadCF.Position, 0.5); end);
                else
                    ForceFloat = true; local CHs = GetChildren(W.Section5.WeakPoints.Points); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local animated = FindFirstChild(v, "animated");
                            if not animated or animated.Value ~= 0 then continue; end;

                            repeat
                                if GetAttribute(EnzukaiRyujin.VAnimator.Slam, "IsPlaying") == true then
                                    Tp(HumRSelf, SAFEPOS);
                                elseif v.Parent then
                                    local Target, Focus = nil, nil;
                                    
                                    if v.EyeA.Transparency == 0 then Target = v.HitBoxA; Focus = v.EyeA; end;
                                    if v.EyeB.Transparency == 0 then Target = v.HitBoxB; Focus = v.EyeB; end;
                                    if v.EyeC.Transparency == 0 then Target = v.HitBoxC; Focus = v.EyeC; end;
                                    if v.EyeD.Transparency == 0 then Target = v.HitBoxD; Focus = v.EyeD; end;
                                    if v.EyeE.Transparency == 0 then Target = v.HitBoxE; Focus = v.EyeE; end;

                                    if not Target then break; end;
                                    local TargetPos, UpVector, h = nil, nil, 50;

                                    while Focus.Transparency == 0 and animated.Parent and animated.Value == 0 and Target.Parent and B2C4Con.Final["Auto Kill Final Boss"] and not CoreDestroyed and GetAttribute(EnzukaiRyujin.VAnimator.Slam, "IsPlaying") ~= true do
                                        TargetPos = Target.Position;
                                        UpVector = Target.CFrame.UpVector;
                                        h = if GetAttribute(Moves.EyeballLaser.Eyeball, "Active") then 80 else 50;
                                        Tp(HumRSelf, CFr(Vec3(TargetPos.X, TargetPos.Y + h, TargetPos.Z) + UpVector * 20));
                                        Functions:MagicArrowHit(Functions:ToolNow("Bow"), TargetPos, 0.7); twait(0.01);
                                    end;
                                end; twait(0.1);
                            until PSG.S5.Frame.Visible or not animated.Parent or animated.Value ~= 0 or CoreDestroyed or not B2C4Con.Final["Auto Kill Final Boss"]; 
                        end;
                    end; ForceFloat = "None"; Tp(HumRSelf, SAFEPOS);
                end; twait(0.1);
            end;
        end);

        local LSecureUI = function()
            WindUI = WindLib();
            local Window = WindUI:CreateWindow({
                Title = GG.Title or "MIMIC / Slate",
                Folder = GG.Folder or "MimicSlate",
                Transparent = false, Theme = "Slate", Acrylic = false,
                SideBarWidth = 178, HasOutline = true, NewElements = true,
                OpenButton = {Title = "SLATE", Enabled = true, Draggable = true, OnlyMobile = false},
                Topbar = {Height = 48, ButtonsType = "Mac"},
            });
            local Tabs = {};
            Tabs.Overview = Window:Tab({Title = "Overview", Icon = "layout-dashboard"});
            Tabs.Welcome = Tabs.Overview;
            Tabs.Yen = ScriptData.AutoData.YenTab and Window:Tab({Title = "Yen", Icon = "coins"}) or false;
            Tabs.B2C1 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB2C1);
            Tabs.B2C2 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB2C2);
            Tabs.B2C3 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB2C3);
            Tabs.B2C4 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB2C4);
            local sections = Functions:PairingSections(ScriptData.Sections);
            Tabs.Section = Windy:CreateDynamic(Window, Tabs, sections);
            if Tabs.Yen then Windy:CreateComponent(Tabs.Yen, ScriptData.AutoData.YenTab, "Yen"); end;
            GG.LegacyWindow = Window;
            GG.LegacyTabs = Tabs;
            if GG.AttachWindow then GG.AttachWindow(Window, Tabs, Functions, Chapter); end;
            Window:OnDestroy(function() Cleanup(); end);
            Window:SetToggleKey(Enum.KeyCode[LoaderSettings.UIKeybind or "RightShift"] or Enum.KeyCode.RightShift);
            ScriptCache.WindUI, ScriptCache.Window = WindUI, Window;
            Window:SelectTab(1);
        end;

        local LSecureLoad = function()
            local ok, failure = pcall(function()
                CoreDestroyed = false;
                GG.Configs = Config;
                GameAI, GameAI2 = FindFirstChild(W, "GameAI"), FindFirstChild(W, "GameAI2");
                if CommonF.Init then pcall(function() CommonF.Init(GetService(game, "VirtualInputManager")); end); end;
                if CoruTask.Init then CoruTask.Init(); end;
                GG.LegacyFunctions = Functions;
                GG.LegacyChapter = Chapter;
                GG.ResetTransient = function()
                    ForceFloat = "None";
                    pcall(function() Functions:FreeCam(false); end);
                    ClientPackage.UpdatePosition(false, "None", HumRSelf);
                end;
                GG.StopLegacyActions = StopActions;
                GG.LegacyState = function()
                    Cam = W.CurrentCamera;
                    return {Character = selc, Humanoid = HumSelf, Root = HumRSelf, Camera = Cam,
                        Backpack = BP, ForceFloat = ForceFloat, Destroyed = CoreDestroyed};
                end;
                LSecureUI();
                local function refreshCharacter(char)
                    selc = char; BP = selff:FindFirstChildOfClass("Backpack") or EMPTY_OBJECT;
                    HumSelf = WaitForChild(char, "Humanoid", 20) or EMPTY_OBJECT;
                    HumRSelf = WaitForChild(char, "HumanoidRootPart", 20) or EMPTY_OBJECT;
                    if CoreDestroyed then return; end;
                    Functions:GameValidate();
                end;
                CoreConnection[#CoreConnection + 1] = selff.CharacterAdded:Connect(refreshCharacter);
                CoreConnection[#CoreConnection + 1] = H.Stepped:Connect(function()
                    if CoreDestroyed then return; end;
                    Cam = W.CurrentCamera;
                    ClientPackage.UpdatePosition(false, ForceFloat, HumRSelf);
                end);
                if selff.Character then tk.spawn(refreshCharacter, selff.Character); end;
                if DownloadPackage and DownloadPackage.Signal then
                    CoreConnection[#CoreConnection + 1] = DownloadPackage.Signal:Connect(function(name, value)
                        if name == "Paintings" and type(value) == "table" then
                            Functions.Paints, Functions.PaintPoses = value.Paints, value.Poses;
                        end;
                    end);
                    if Chapter == "B2C4" then DownloadPackage.Download(false, "Paintings"); end;
                    GG.DownloadHandler = DownloadPackage;
                end;
                -- The dispatcher is a core service. Stop cancels action tasks,
                -- while this loop remains available for later toggle changes.
                task.spawn(function()
                    while not CoreDestroyed do
                        if Chapter == "B2C2" then
                            if B2C2Con.Cook.AutoCook then CoruTask.Handle("B2C2@Cook"); end;
                            if B2C2Con.Kid["Anti Mother"] then CoruTask.Handle("B2C2@Mother"); end;
                            if B2C2Con.Nagisa["Auto Get Cannon Balls"] or B2C2Con.Nagisa["Anti Nagisa Beam"] then CoruTask.Handle("B2C2@Cannon&Lazer"); end;
                            if B2C2Con.Nagisa["Auto Kill Nagisa Serpent"] then CoruTask.Handle("B2C2@Serpent"); end;
                        elseif Chapter == "B2C3" then
                            if B2C3Con.Boss.AutoKillYurei then CoruTask.Handle("B2C3@Yurei"); end;
                        elseif Chapter == "B2C4" then
                            if B2C4Con.Enzukai["Auto Kill Enzukai-Ryu"] then CoruTask.Handle("B2C4@EnzukaiRyu"); end;
                            if B2C4Con.Enzukai["Auto Kill Enzukai Followers"] then CoruTask.Handle("B2C4@Followers"); end;
                            if B2C4Con.Final["Auto Kill Final Boss"] then CoruTask.Handle("B2C4@EnzukaiJin"); end;
                        end;
                        if YenCon.ESP or YenCon.Aura or YenCon.Auto then CoruTask.Handle("UNIFIED-Yen"); end;
                        task.wait(0.12);
                    end;
                end);

                if GG.LoadingSignal then GG.LoadingSignal:Fire(100); end;
            end);
            if not ok then
                Cleanup();
                warn("[Slate] Initialization failed: " .. tostring(failure));
                return false, failure;
            end;
            return true;
        end;
        GG.LSecureLoad = LSecureLoad;
        return LSecureLoad;
    end;
};

end

local Runtime = (function()
-- Mimic runtime with the original cc WindUI interface.
local Runtime = {}
local VERSION = "1.1.0-cc"

local function environment()
    local ok, env = pcall(function() return getgenv and getgenv() end)
    return ok and type(env) == "table" and env or _G
end

local function clone(value, depth)
    depth = depth or 0
    if depth > 16 then return nil end
    local kind = type(value)
    if kind == "boolean" or kind == "string" then return value end
    if kind == "number" then
        if value == value and math.abs(value) < math.huge then return value end
        return nil
    end
    if kind ~= "table" then return nil end
    local out = {}
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then out[key] = clone(item, depth + 1) end
    end
    return out
end

local function signal(ctx)
    local event = Instance.new("BindableEvent")
    ctx.addCleanup(function() event:Destroy() end)
    return {
        Connect = function(_, fn) return event.Event:Connect(fn) end,
        Once = function(_, fn) return event.Event:Once(fn) end,
        Fire = function(_, ...) event:Fire(...) end,
        Wait = function() return event.Event:Wait() end,
    }
end

local function resetLegacyFlags(config, keepVisuals)
    -- Store preferences, but do not start saved chapter automation merely by loading a file.
    local excluded = {Client = true, SlateESP = true, Egao = true, NearbyKill = true, Interface = true}
    local function reset(node)
        for key, value in pairs(node) do
            if keepVisuals and key == "ESP" then continue end
            if type(value) == "boolean" then node[key] = false
            elseif type(value) == "table" then reset(value) end
        end
    end
    for key, value in pairs(config) do
        if not excluded[key] and type(value) == "table" then reset(value) end
    end
end

function Runtime.start(options)
    assert(type(options) == "table" and type(options.Modules) == "table", "Missing Slate modules")
    local modules, scope = options.Modules, options.Scope
    local env = environment()
    env.__MimicSlate = env.__MimicSlate or {}
    local previous = env.__MimicSlate.Active
    if previous and type(previous.Destroy) == "function" then pcall(previous.Destroy) end

    local services = {}
    for _, name in ipairs({"Players", "RunService", "UserInputService", "Lighting", "Workspace", "ReplicatedStorage", "TeleportService", "TweenService", "Stats", "HttpService", "ProximityPromptService"}) do
        services[name] = game:GetService(name)
    end
    local player = services.Players.LocalPlayer
    if not player then error("Mimic Slate requires a local player", 0) end
    local ctx = {
        Scope = scope, Version = VERSION, Services = services, Player = player,
        Config = {}, Connections = {}, Alive = true, Cleanups = {}, Actions = {},
        Modules = modules, QueueInfo = {}, UIUrl = options.UIUrl or "",
        LegacyTasks = {}, ActionEpoch = 0,
    }
    env.__MimicSlate.Active = ctx
    local queueTable = env.__MimicSlateQueue or {}
    env.__MimicSlateQueue = queueTable
    ctx.QueueInfo = clone(queueTable[scope]) or {}
    local inheritedQueueGeneration = tonumber(ctx.QueueInfo._Generation) or 0
    if ctx.QueueInfo.Cancelled then ctx.QueueInfo = {} end
    ctx.SourceCode = env.__MimicSlateSources and env.__MimicSlateSources[scope]

    ctx.addCleanup = function(fn) table.insert(ctx.Cleanups, fn) end
    ctx.Notify = function(title, content)
        if ctx.UI and ctx.Alive then
            ctx.UI:Notify({Title = tostring(title), Content = tostring(content or ""), Duration = 6, Icon = "info"})
        else warn("[Mimic Slate] " .. tostring(title) .. ": " .. tostring(content or "")) end
    end

    local http = services.HttpService
    local settingsPath = "MimicSlate_" .. scope .. ".json"
    local sharedPath = "MimicSlate_Shared.json"
    local function readSettings(path)
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return {} end
        local ok, result = pcall(function()
            if not isfile(path) then return {} end
            local data = http:JSONDecode(readfile(path))
            return type(data) == "table" and data or {}
        end)
        return ok and result or {}
    end
    ctx.Config = readSettings(settingsPath)
    local shared = readSettings(sharedPath)
    ctx.Config.Client = shared.Client or ctx.Config.Client or {Client = {}}
    ctx.Config.Client.Client = ctx.Config.Client.Client or {}
    ctx.Config.SlateESP = shared.SlateESP or ctx.Config.SlateESP or {}
    ctx.Config.Interface = shared.Interface or ctx.Config.Interface or {}
    resetLegacyFlags(ctx.Config)
    local saveGeneration = 0
    local function saveNow()
        if type(writefile) ~= "function" then return false end
        local ok = pcall(function()
            writefile(settingsPath, http:JSONEncode(clone(ctx.Config)))
            writefile(sharedPath, http:JSONEncode(clone({Client = ctx.Config.Client, SlateESP = ctx.Config.SlateESP, Interface = ctx.Config.Interface})))
        end)
        return ok
    end
    ctx.Save = function()
        saveGeneration += 1
        local generation = saveGeneration
        task.delay(0.35, function() if ctx.Alive and generation == saveGeneration then saveNow() end end)
    end

    local originalCamera = services.Workspace.CurrentCamera
    local originalCameraState = originalCamera and {CameraType = originalCamera.CameraType, CameraSubject = originalCamera.CameraSubject, FieldOfView = originalCamera.FieldOfView}
    local changedAnchors = setmetatable({}, {__mode = "k"})
    local activeTweens = {}
    local scheduler
    ctx.Destroy = function()
        if not ctx.Alive then return end
        saveNow()
        ctx.Alive = false
        ctx.ActionEpoch += 1
        for thread in pairs(ctx.Actions) do
            if thread ~= coroutine.running() then pcall(task.cancel, thread) end
        end
        for thread in pairs(ctx.LegacyTasks) do
            if thread ~= coroutine.running() then pcall(task.cancel, thread) end
        end
        if scheduler then scheduler.Destroy() end
        for tween in pairs(activeTweens) do pcall(function() tween:Cancel() end) end
        for i = #ctx.Cleanups, 1, -1 do pcall(ctx.Cleanups[i]) end
        for _, connection in pairs(ctx.Connections) do pcall(function() connection:Disconnect() end) end
        for part, value in pairs(changedAnchors) do if part.Parent then pcall(function() part.Anchored = value end) end end
        local camera = services.Workspace.CurrentCamera
        if camera and originalCameraState then
            pcall(function()
                camera.CameraType = originalCameraState.CameraType
                if originalCameraState.CameraSubject and originalCameraState.CameraSubject.Parent then camera.CameraSubject = originalCameraState.CameraSubject end
                camera.FieldOfView = originalCameraState.FieldOfView
            end)
        end
        pcall(function() services.RunService:Set3dRenderingEnabled(true) end)
        if ctx.Window then pcall(function() ctx.Window:Destroy() end) end
        if env.__MimicSlate.Active == ctx then env.__MimicSlate.Active = nil end
    end

    local function loadUI()
        if ctx.UIUrl ~= "" then
            local ok, result = pcall(function()
                local source = game:HttpGet(ctx.UIUrl)
                assert(type(source) == "string" and #source > 100, "UI download is empty")
                local fn, compileError = loadstring(source, "MimicSlate/UI")
                assert(fn, compileError)
                local ui = fn()
                assert(type(ui) == "table" and type(ui.CreateWindow) == "function", "UI response has an incompatible API")
                return ui
            end)
            if ok then ctx.UISource = "GitHub"; return result end
            ctx.UIError = tostring(result)
            if not modules.CCUI then error("Cannot load CC UI: " .. ctx.UIError, 0) end
        end
        assert(modules.CCUI, "CC UI is unavailable")
        ctx.UISource = "Bundled"
        return modules.CCUI()
    end
    local uiOK, uiResult = pcall(loadUI)
    if not uiOK then ctx.Destroy(); error(tostring(uiResult), 0) end
    ctx.UI = uiResult

    local function findQueue()
        local candidates = {}
        local function add(fn) if type(fn) == "function" then table.insert(candidates, fn) end end
        add(env.queue_on_teleport); add(env.queueonteleport); add(env.QueueOnTeleport)
        add(queue_on_teleport); add(queueonteleport)
        if type(syn) == "table" then add(syn.queue_on_teleport) end
        if type(fluxus) == "table" then add(fluxus.queue_on_teleport) end
        return candidates[1]
    end
    local queueGeneration = inheritedQueueGeneration
    ctx.QueueSelf = function(info)
        queueGeneration += 1
        info = clone(info) or {}
        info._Generation = queueGeneration
        info._Scope = scope
        info._Version = VERSION
        ctx.QueueInfo = info
        queueTable[scope] = info
        -- A state file lets a later Stop invalidate an already appended queued payload.
        if type(writefile) == "function" then pcall(function() writefile("MimicSlate_Queue_" .. scope .. ".json", http:JSONEncode(info)) end) end
        local queue = findQueue()
        if not queue or type(ctx.SourceCode) ~= "string" then return false end
        local encoded = http:JSONEncode(info)
        local source = string.format([==[
local E = (getgenv and getgenv()) or _G
E.__MimicSlateQueue = E.__MimicSlateQueue or {}
local scope, generation = %q, %d
local info = game:GetService("HttpService"):JSONDecode(%q)
if type(readfile)=="function" and type(isfile)=="function" then
    pcall(function()
        local path="MimicSlate_Queue_"..scope..".json"
        if isfile(path) then
            local latest=game:GetService("HttpService"):JSONDecode(readfile(path))
            if latest._Generation and latest._Generation>info._Generation then info=latest end
        end
    end)
end
local prior=E.__MimicSlateQueue[scope]
if not prior or (tonumber(prior._Generation) or 0)<=info._Generation then E.__MimicSlateQueue[scope]=info end
task.defer(function()
    local current=E.__MimicSlateQueue[scope]
    if not current or current.Cancelled or current._Generation~=generation then return end
    E.__MimicSlateSources=E.__MimicSlateSources or {}
    E.__MimicSlateSources[scope]=%q
    local fn,err=loadstring(E.__MimicSlateSources[scope],"MimicSlate/"..scope)
    if fn then fn() else warn(err) end
end)
]==], scope, queueGeneration, encoded, ctx.SourceCode)
        local ok = pcall(queue, source)
        return ok
    end

    local function root()
        local char = player.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    local function position(value)
        if typeof(value) == "Vector3" then return value end
        if typeof(value) == "CFrame" then return value.Position end
        if typeof(value) ~= "Instance" then return nil end
        if value:IsA("BasePart") then return value.Position end
        if value:IsA("Attachment") then return value.WorldPosition end
        if value:IsA("Model") then return value:GetPivot().Position end
        local part = value:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position
    end
    local function ensureAlive()
        if not ctx.Alive then error("Slate action cancelled", 0) end
    end
    local trackedTask = {}
    local function scheduled(mode, delay, fn, ...)
        local args, epoch = table.pack(...), ctx.ActionEpoch
        local function invoke()
            if not ctx.Alive or epoch ~= ctx.ActionEpoch then return end
            local running = coroutine.running()
            ctx.LegacyTasks[running] = epoch
            local ok, err = xpcall(function() fn(table.unpack(args, 1, args.n)) end, debug.traceback)
            ctx.LegacyTasks[running] = nil
            if not ok and ctx.Alive and epoch == ctx.ActionEpoch then
                ctx.Notify("Action paused", tostring(err):match("^[^\n]+"))
            end
        end
        local thread
        if mode == "delay" then thread = task.delay(delay, invoke)
        elseif mode == "defer" then thread = task.defer(invoke)
        else thread = task.spawn(invoke) end
        if coroutine.status(thread) ~= "dead" then ctx.LegacyTasks[thread] = epoch end
        return thread
    end
    trackedTask.spawn = function(fn, ...) return scheduled("spawn", 0, fn, ...) end
    trackedTask.defer = function(fn, ...) return scheduled("defer", 0, fn, ...) end
    trackedTask.delay = function(delay, fn, ...) return scheduled("delay", delay, fn, ...) end
    trackedTask.wait = function(duration)
        local thread = coroutine.running()
        local epoch = ctx.LegacyTasks[thread] or ctx.ActionEpoch
        ensureAlive()
        local elapsed = task.wait(duration)
        ensureAlive()
        if epoch ~= ctx.ActionEpoch then error("Slate action cancelled", 0) end
        return elapsed
    end
    trackedTask.cancel = function(thread) ctx.LegacyTasks[thread] = nil; return task.cancel(thread) end
    local function cancelLegacyTasks()
        ctx.ActionEpoch += 1
        for thread in pairs(ctx.LegacyTasks) do
            if thread ~= coroutine.running() then pcall(task.cancel, thread) end
            ctx.LegacyTasks[thread] = nil
        end
    end
    local common = {}
    common.dist = function(a, b)
        local pa, pb = position(a), position(b or root())
        return pa and pb and (pa - pb).Magnitude or math.huge
    end
    common.distOf = function(a, b, distance) return common.dist(a, b) <= (distance or math.huge) end
    common.Tp = function(part, target, delay)
        ensureAlive()
        part = part or root()
        assert(part and part.Parent, "Character is not ready")
        if typeof(target) == "Vector3" then target = CFrame.new(target) end
        assert(typeof(target) == "CFrame", "Destination is not ready")
        if part:IsA("Model") then part:PivotTo(target) else part.CFrame = target end
        if delay and delay > 0 then task.wait(delay); ensureAlive() end
        return true
    end
    common.Tween = function(args)
        ensureAlive()
        local part = args.primary or root()
        assert(part and part.Parent, "Character is not ready")
        local speed = math.clamp(tonumber(ctx.Config.Interface.TravelSpeed) or 85, 10, 250)
        local distance = args.goal.CFrame and common.dist(part, args.goal.CFrame) or 30
        local info = args.info or TweenInfo.new(math.clamp(distance / speed, 0.2, 25), Enum.EasingStyle.Linear)
        local tween = services.TweenService:Create(part, info, args.goal)
        activeTweens[tween] = true
        tween:Play()
        local state = tween.Completed:Wait()
        activeTweens[tween] = nil
        ensureAlive()
        if state == Enum.PlaybackState.Cancelled then error("Slate action cancelled", 0) end
        return tween
    end
    common.Anchored = function(part, value)
        ensureAlive()
        assert(part and part.Parent, "Character is not ready")
        if changedAnchors[part] == nil then changedAnchors[part] = part.Anchored end
        part.Anchored = value
    end
    common.HumanoidEquip = function(humanoid, tool)
        ensureAlive()
        assert(humanoid and humanoid.Parent and tool and tool.Parent, "Required tool is not ready")
        humanoid:EquipTool(tool)
    end
    common.Init = function(input) common.Input = input end
    common.CKey = function(_, key, duration)
        ensureAlive()
        local input = common.Input
        if not input then
            local ok, result = pcall(game.GetService, game, "VirtualInputManager")
            input = ok and result
        end
        assert(input, "Keyboard simulation is unavailable")
        input:SendKeyEvent(true, key, false, game)
        task.wait(duration or 0.03)
        input:SendKeyEvent(false, key, false, game)
    end

    scheduler = {Definitions = {}, Threads = {}, RetryAfter = {}, Intialized = false}
    scheduler.New = function(id, fn) scheduler.Definitions[id] = fn end
    scheduler.Init = function() scheduler.Intialized = true end
    scheduler.Close = function(id)
        local thread = scheduler.Threads[id]
        scheduler.Threads[id] = nil
        if thread and thread ~= coroutine.running() then pcall(task.cancel, thread) end
    end
    scheduler.Handle = function(id)
        if not ctx.Alive or scheduler.Threads[id] or (scheduler.RetryAfter[id] or 0) > os.clock() then return end
        local fn = scheduler.Definitions[id]
        if not fn then return end
        -- Defer so the thread is registered before a synchronous return can clear it.
        scheduler.Threads[id] = task.defer(function()
            local ok, err = xpcall(fn, debug.traceback)
            scheduler.Threads[id] = nil
            if not ok and ctx.Alive then
                scheduler.RetryAfter[id] = os.clock() + 6
                ctx.Notify("Action paused", id .. ": " .. tostring(err):match("^[^\n]+"))
            end
        end)
    end
    scheduler.Destroy = function()
        for id, thread in pairs(scheduler.Threads) do
            if thread ~= coroutine.running() then pcall(task.cancel, thread) end
            scheduler.Threads[id] = nil
        end
    end

    ctx.Visuals = modules.VisualsPlayer()(ctx)

    local currentAction = {}
    local overlayCallbacks = {}
    local legacyControls = {}
    local function runAction(key, fn, ...)
        if not ctx.Alive or currentAction[key] then return end
        local args = table.pack(...)
        local thread = coroutine.running()
        currentAction[key] = thread
        ctx.Actions[thread] = key
        local ok, result = xpcall(function() return fn(table.unpack(args, 1, args.n)) end, debug.traceback)
        ctx.Actions[thread] = nil
        currentAction[key] = nil
        if not ok and ctx.Alive then
            if ctx.GG and ctx.GG.ResetTransient then pcall(ctx.GG.ResetTransient) end
            for part, value in pairs(changedAnchors) do if part.Parent then pcall(function() part.Anchored = value end) end end
            local firstLine = tostring(result):match("^[^\n]+")
            ctx.Notify("Action unavailable", key .. "\n" .. firstLine)
        end
        return result
    end

    local function configPath(path, base)
        local keys = {}
        if base and base ~= "IGNORE" then for key in tostring(base):gmatch("[^/]+") do table.insert(keys, key) end end
        if path then for key in tostring(path):gmatch("[^/]+") do table.insert(keys, key) end end
        return keys
    end
    local function getValue(keys)
        local node = ctx.Config
        for _, key in ipairs(keys) do if type(node) ~= "table" then return nil end; node = node[key] end
        return node
    end
    local function setValue(keys, value)
        if #keys == 0 then return end
        local node = ctx.Config
        for i = 1, #keys - 1 do node[keys[i]] = node[keys[i]] or {}; node = node[keys[i]] end
        node[keys[#keys]] = value
        ctx.Save()
    end
    local windy = {}
    function windy:CreateComponent(tab, data, base)
        if not tab or type(data) ~= "table" then return end
        for index, item in ipairs(data) do
            local kind = item.type or item.Type
            if kind == "Group" then
                for _, group in ipairs(item.dats or {}) do
                    if group.Title then tab:Section({Title = group.Title}) end
                    self:CreateComponent(tab, group.dat, base)
                end
            elseif kind == "Space" then tab:Space()
            elseif kind == "Paragraph" then tab:Paragraph({Title = item.Title or item.EN or "", Desc = item.Desc or item.EN2 or ""})
            elseif kind == "Section" then tab:Section({Title = item.Title or item.EN or ""})
            elseif kind then
                local keys = configPath(item.Path, base)
                local value = getValue(keys)
                local params = {
                    Title = item.EN or item.Title or kind,
                    Desc = item.EN2 or item.Desc or "",
                    Icon = item.Icon, Locked = item.Locked == true,
                }
                local callback = item.Callback
                params.Callback = function(newValue)
                    if item.Locked or not ctx.Alive then return end
                    if kind ~= "Button" and item.Path then setValue(keys, newValue) end
                    if callback then return runAction(params.Title, callback, newValue) end
                end
                if kind == "Toggle" and callback and params.Title:match("^ESP ") then
                    table.insert(overlayCallbacks, {Keys = keys, Callback = callback})
                end
                if kind == "Toggle" then params.Value = value == true
                elseif kind == "Slider" then
                    local range = item.Value or {}
                    params.Value = {Min = range.Min or 0, Max = range.Max or 100, Default = tonumber(value) or range.Default or range.Min or 0}
                    params.Step = item.Step or 1
                elseif kind == "Input" then params.Value = value or item.Value or ""
                elseif kind == "Dropdown" then params.Value = value or item.Value; params.Values = item.Values; params.Multi = item.Multi
                else params.Value = value or item.Value end
                if type(tab[kind]) == "function" then
                    local control = tab[kind](tab, params)
                    if kind == "Toggle" and item.Path then table.insert(legacyControls, {Control = control, Keys = keys}) end
                    if item.Locked and control and control.Lock then control:Lock() end
                end
            end
        end
    end
    function windy:CreateDynamic(window, tabs, pack)
        if not pack or not pack.Tabs then return false end
        local output
        for _, group in ipairs(pack.Tabs) do
            local spec = group.Tab or {}
            local isTravel = spec.at == "Section"
            if isTravel then
                ctx.TravelTab = ctx.TravelTab or window:Tab({Title = "Teleport", Icon = "map-pinned"})
                output = ctx.TravelTab
            else
                ctx.ChapterTab = ctx.ChapterTab or window:Tab({Title = scope == "Gamemodes" and "Modes" or "Chapter", Icon = "book-open"})
                output = ctx.ChapterTab
            end
            if spec.Title and spec.Title ~= "Main" and not isTravel then output:Section({Title = spec.Title}) end
            self:CreateComponent(output, group.Data, spec.Path)
            if spec.at then tabs[spec.at] = output end
        end
        return output
    end

    local queuePack = {}
    queuePack.SetInfo = function(key, value) ctx.QueueInfo[key] = value end
    queuePack.Init = function()
        if not ctx.QueueSelf(ctx.QueueInfo) then error("This action needs queue_on_teleport support. Enable auto-execute or run the same file again after teleport.", 0) end
        return true
    end
    local download = {Signal = signal(ctx)}
    download.Download = function(check, name)
        if name ~= "Paintings" or not modules.Paintings then return false end
        if check then return true end
        local data = modules.Paintings().Function()
        download.Signal:Fire(name, data)
        return true
    end
    local promptPackage = {UpdateState = function() end}
    local uiFacade = setmetatable({}, {__index = ctx.UI})
    function uiFacade:CreateWindow(params)
        params = params or {}
        params.Title = scope == "Book3" and "Nevoirs - Rage" or ("Nevoirs - " .. (scope:gsub("Book", "Book ")))
        params.Subtitle = scope == "Gamemodes" and "GAMEMODES" or (scope:gsub("Book", "BOOK "))
        params.Author = "Nevoirs"
        params.Folder = scope == "Book3" and "Nevoirs_Rage" or ("Nevoirs_" .. scope)
        params.Theme = "Dark"
        params.Transparent = true
        params.Acrylic = false
        params.ToggleKey = Enum.KeyCode.RightControl
        local window = ctx.UI:CreateWindow(params)
        ctx.Window = window
        window:OnDestroy(ctx.Destroy)
        return window
    end

    local gg = {
        Configs = ctx.Config, ScriptCache = {userIdentify = "Nevoirs"}, QUEUE_INFO = ctx.QueueInfo,
        LoaderSettings = {TheMimicLoader = {Load_Sections = true}, UIKeybind = "RightControl", AllowClientTab = false, AllowAcrylicBlur = false, ESPMode = "Slate"},
        LoadingSignal = signal(ctx), ESPObjects = {}, RegisterCleanup = ctx.addCleanup,
        Title = "Nevoirs / " .. scope, LowerC = hookfunction or hookfunc,
        Task = trackedTask,
    }
    gg.Dispatch = function(fn, ...)
        if not ctx.Alive then return end
        local thread, args = coroutine.running(), table.pack(...)
        ctx.LegacyTasks[thread] = ctx.ActionEpoch
        local ok, result = xpcall(function() return fn(table.unpack(args, 1, args.n)) end, debug.traceback)
        ctx.LegacyTasks[thread] = nil
        if not ok and ctx.Alive then
            local now = os.clock()
            if not ctx.LastSignalError or now - ctx.LastSignalError > 5 then
                ctx.LastSignalError = now
                ctx.Notify("Action paused", tostring(result):match("^[^\n]+"))
            end
        end
        return result
    end
    ctx.GG = gg
    local extensions
    if modules.Book3Extensions and (scope == "Book3" or scope == "Gamemodes") then extensions = modules.Book3Extensions()(ctx) end

    local function addOverview(chapter)
        local tab = ctx.Overview
        tab:Paragraph({Title = "Nevoirs / " .. scope, Desc = "Main: nhiệm vụ và dịch chuyển · Chiến đấu: Nearby Kill · ESP: hiển thị · Cá nhân: di chuyển · Cài đặt: cấu hình."})
        if tab.Status then
            ctx.OverviewStatus = tab:Status({Title = "Session", Icon = "activity", State = "active", Fields = {Package = scope, Chapter = chapter or "Lobby / unknown", Player = player.DisplayName, Interface = ctx.UISource}})
        else
            tab:Paragraph({Title = scope .. " / " .. (chapter or "Lobby"), Desc = player.DisplayName})
        end
        if ctx.UIError then tab:Paragraph({Title = "Đang dùng UI đi kèm", Desc = "Không tải được UI raw. Bản WindUI của cc đã nhúng đang được sử dụng."}) end
        tab:Section({Title = "Quick actions"})
        tab:Button({Title = "Stop chapter actions", Icon = "square", Desc = "Stops active tasks and resets chapter switches.", Callback = function()
            scheduler.Destroy()
            cancelLegacyTasks()
            for thread in pairs(ctx.Actions) do if thread ~= coroutine.running() then pcall(task.cancel, thread) end end
            table.clear(ctx.Actions); table.clear(currentAction)
            resetLegacyFlags(ctx.Config, true)
            for _, entry in ipairs(legacyControls) do
                if entry.Control and entry.Control.SetValue then entry.Control:SetValue(getValue(entry.Keys) == true, true) end
            end
            if gg.StopLegacyActions then pcall(gg.StopLegacyActions) end
            if gg.ResetTransient then pcall(gg.ResetTransient) end
            if extensions and extensions.StopAll then extensions.StopAll() end
            for tween in pairs(activeTweens) do pcall(function() tween:Cancel() end) end
            for part, value in pairs(changedAnchors) do if part.Parent then pcall(function() part.Anchored = value end) end end
            ctx.Notify("Chapter actions stopped", "Movement and visual preferences are retained.")
        end})
        tab:Button({Title = "Unload", Icon = "power", Desc = "Closes the interface and restores managed player effects.", Callback = ctx.Destroy})
    end
    local function addSettings(window)
        local tab = window:Tab({Title = "Settings", Icon = "settings"})
        tab:Section({Title = "Interface"})
        tab:Slider({Title = "UI Scale", Desc = "Điều chỉnh kích thước giao diện.", Value = {Min = 0.58, Max = 0.90, Default = tonumber(ctx.Config.Interface.CCScale) or (services.UserInputService.TouchEnabled and 0.62 or 0.60)}, Step = 0.01, Callback = function(value)
            ctx.Config.Interface.CCScale = value; window:SetUIScale(value); ctx.Save()
        end})
        tab:Keybind({Title = "Menu key", Value = Enum.KeyCode.RightControl, ChangedCallback = function(key) window:SetToggleKey(key) end})
        tab:Slider({Title = "Travel speed", Desc = "Used by chapter routes that do not specify a duration.", Value = {Min = 10, Max = 200, Default = tonumber(ctx.Config.Interface.TravelSpeed) or 85}, Step = 5, Callback = function(value) ctx.Config.Interface.TravelSpeed = value; ctx.Save() end})
        tab:Section({Title = "Configuration"})
        tab:Button({Title = "Save preferences", Icon = "save", Callback = function()
            ctx.Notify(saveNow() and "Preferences saved" or "Session preferences", type(writefile) == "function" and "Saved on this device." or "File storage is unavailable; preferences last for this session.")
        end})
        tab:Paragraph({Title = "Nevoirs " .. VERSION, Desc = "UI gốc cc / WindUI · " .. scope .. "\nRightCtrl hoặc avatar bên trái để ẩn/hiện menu."})
    end
    gg.AttachWindow = function(window, tabs, functions, chapter)
        ctx.Window = window; ctx.LegacyFunctions = functions; ctx.Chapter = chapter
        ctx.Overview = tabs.Overview or tabs.Welcome or window:Tab({Title = "Overview", Icon = "home"})
        addOverview(chapter)
        if scope == "Book3" and chapter == "B3C1" and ctx.ChapterTab then
            local tab = ctx.ChapterTab
            tab:Section({Title = "Additional objectives"})
            tab:Button({Title = "Get bolt cutter", Desc = "Uses the City cutter interaction from the original chapter logic.", Icon = "scissors", Callback = function() runAction("Get bolt cutter", function() functions:B3C1Func("City/Cutter") end) end})
            for _, targetName in ipairs({"Terminal", "BoulderSeal"}) do
                local target = targetName
                local keys = {"B3C1", "IJO", "ESP", target}
                local cb = function(value) functions:B3C1ESP(target, value) end
                table.insert(overlayCallbacks, {Keys = keys, Callback = cb})
                tab:Toggle({Title = "ESP " .. target, Desc = "IJO objective marker.", Value = false, Callback = function(value) setValue(keys, value); runAction("ESP " .. target, cb, value) end})
            end
        end
        ctx.Visuals.BuildTabs(window)
        if extensions then extensions.BuildTabs(window, chapter) end
        addSettings(window)
        window:SetUIScale(math.clamp(tonumber(ctx.Config.Interface.CCScale) or (services.UserInputService.TouchEnabled and 0.62 or 0.60), 0.58, 0.90))
        window:SelectTab(1)
    end

    local success, failure = xpcall(function()
        local legacy = modules.Legacy(gg)
        local loader = legacy.Function(function() return {} end, function() return uiFacade end, {Init = function() end, Tutorial = function() end}, windy, ctx.Visuals.ClientPackage, scheduler, common, ctx.Visuals.ESPF, promptPackage, download, queuePack)
        assert(type(loader) == "function", "Chapter adapter did not return a loader")
        local loaded, reason = loader()
        if loaded == false then error(reason or "Chapter initialization failed", 0) end
    end, debug.traceback)
    if not success then
        if not ctx.Window then uiFacade:CreateWindow({}) end
        if not ctx.OverviewStatus then
            ctx.Overview = ctx.Overview or ctx.Window:Tab({Title = "Overview", Icon = "home"})
            addOverview(nil)
            ctx.Overview:Paragraph({Title = "Chapter adapter paused", Desc = "This area is not ready for the selected package. Player and visual controls remain available."})
            ctx.Visuals.BuildTabs(ctx.Window)
            if extensions then extensions.BuildTabs(ctx.Window, nil) end
            addSettings(ctx.Window)
        end
        ctx.Notify("Chapter adapter paused", tostring(failure):match("^[^\n]+"))
        warn("[Mimic Slate] " .. tostring(failure))
    end
    -- Refresh only selected ESP discovery adapters. Rendering and distances use
    -- the one shared renderer; legacy progress listeners are deduplicated there.
    local discoveryElapsed, discoveryBusy = 0, false
    table.insert(ctx.Connections, services.RunService.Heartbeat:Connect(function(dt)
        discoveryElapsed += dt
        if not ctx.Alive or discoveryBusy or discoveryElapsed < 2 then return end
        discoveryElapsed = 0
        discoveryBusy = true
        task.defer(function()
            for _, entry in ipairs(overlayCallbacks) do
                if not ctx.Alive then break end
                if getValue(entry.Keys) == true then pcall(entry.Callback, true) end
            end
            discoveryBusy = false
        end)
    end))
    return ctx
end

return Runtime

end)()

local E = (getgenv and getgenv()) or _G

return Runtime.start({Scope="Book2",Modules=Modules,UIUrl=E.MimicCCUIUrl or "https://raw.githubusercontent.com/eystearisdown/wyattrz/main/ui/CCUI.lua"})

]====]
local E = (getgenv and getgenv()) or _G
E.__MimicSlateSources = E.__MimicSlateSources or {}
E.__MimicSlateSources["Book2"] = PAYLOAD
local run, compileError = loadstring(PAYLOAD, "MimicSlate/Book2")
if not run then error(compileError, 0) end
return run()
