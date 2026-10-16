-- Mimic CC UI 1.1.0 / Book3
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

Modules.Book3Extensions = function()
-- Slate Book 3 extensions. New Egao source takes precedence over 229's event finder.
-- No action starts on load; only an explicit control or a valid queued Egao session starts it.
return function(ctx)
    local S = ctx.Services
    local Player, Workspace, ReplicatedStorage = ctx.Player, S.Workspace, S.ReplicatedStorage
    local RunService, TeleportService, TweenService = S.RunService, S.TeleportService, S.TweenService
    local LOBBY, FOREST = 6243699076, 128715637193371
    local CHECKPOINT = CFrame.new(-3658, 8, 372)
    local alive, built, connections = true, false, {}
    local api = {}
    local egaoCard, nearbyCard, floatingCard, egaoToggle, nearbyToggle
    local egaoGeneration, nearbyGeneration = 0, 0
    local activeTween
    local owner = {}
    local bindName = "SlateEgaoLook_" .. tostring(math.random(100000, 999999))
    local weak = { __mode = "k" }

    ctx.Config.Egao = type(ctx.Config.Egao) == "table" and ctx.Config.Egao or {}
    ctx.Config.NearbyKill = type(ctx.Config.NearbyKill) == "table" and ctx.Config.NearbyKill or {}
    local options, nkOptions = ctx.Config.Egao, ctx.Config.NearbyKill
    for _, key in ipairs({ "AutoLook", "FullBright", "NoFog", "Floating" }) do
        if options[key] == nil then options[key] = true end
    end
    local queued = type(ctx.QueueInfo) == "table" and ctx.QueueInfo or {}
    if queued.Egao == true and type(queued.EgaoOptions) == "table" then
        for _, key in ipairs({ "AutoLook", "FullBright", "NoFog", "Floating" }) do
            if type(queued.EgaoOptions[key]) == "boolean" then options[key] = queued.EgaoOptions[key] end
        end
    end
    local nkDefaults = { FireDelay = 0.03, CreepRange = 70, HogoRange = 25, FleshRange = 20, SpiderRange = 20 }
    for key, value in pairs(nkDefaults) do
        nkOptions[key] = tonumber(nkOptions[key]) or value
    end
    nkOptions.Filters = type(nkOptions.Filters) == "table" and nkOptions.Filters or {}
    for _, key in ipairs({ "Gata", "Grunt", "Muki", "Hogo", "FleshBlock", "Spider" }) do
        if nkOptions.Filters[key] == nil then nkOptions.Filters[key] = true end
    end

    local E = {
        Running = false, Found = false, Phase = "idle", State = "idle", Detail = "Bật tìm kiếm để bắt đầu từ Lobby hoặc Forest.",
        Hops = math.max(0, tonumber(queued.Hops) or 0), StartedAt = tonumber(queued.StartedAt),
        Session = type(queued.EgaoSession) == "string" and queued.EgaoSession or nil,
        Queued = false, PendingTeleport = false, PendingSave = false, Retry = 0,
        LookActive = false, LookReason = "idle", Target = "—", TargetDistance = nil,
        Pulse = false, PulseExists = false, LastReason = queued.EgaoReason or "Chưa chạy",
    }
    local NK = { Running = false, Target = nil, Detail = "Chỉ xử lý mục tiêu trong tầm; không tự dịch chuyển.", State = "idle", Sent = 0, Hook = false }
    local lookPart, lookRig, lookLabel, lookStarted = nil, nil, nil, 0
    local pendingRig
    local rigs = setmetatable({}, weak)
    local lastRigScan, lastLookUi = 0, 0
    local hookStore
    local lastCardRefresh = 0

    local function valid()
        return alive and ctx.Alive ~= false
    end
    local function on(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
        return connection
    end
    local function save()
        if ctx.Save then pcall(ctx.Save) end
    end
    local function notify(title, text)
        if ctx.Notify then pcall(ctx.Notify, title, text) end
    end
    local function root()
        return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    end
    local function partAlive(part)
        return part and part.Parent and part:IsA("BasePart") and part:IsDescendantOf(Workspace)
    end
    local function path(names)
        local object = Workspace
        for _, name in ipairs(names) do
            object = object and object:FindFirstChild(name)
        end
        return object
    end
    local function ping()
        local ok, value = pcall(function() return S.Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        return ok and math.max(0, tonumber(value) or 0) or 0
    end
    local function duration(seconds)
        seconds = math.max(0, math.floor(seconds))
        return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
    end
    local function update(handle, data)
        if handle and handle.Update then pcall(function() handle:Update(data) end) end
    end
    local function showFloat(value)
        if not floatingCard then return end
        if floatingCard.SetVisible then
            pcall(function() floatingCard:SetVisible(value) end)
        elseif floatingCard.Set then
            pcall(function() floatingCard:Set(value) end)
        end
    end
    local function refresh(force)
        if not force and os.clock() - lastCardRefresh < 0.25 then return end
        lastCardRefresh = os.clock()
        local elapsed = E.StartedAt and (E.FinishedAt or os.time()) - E.StartedAt or 0
        local phaseNames = {
            idle = "Sẵn sàng", loading = "Đang tải", lobby = "Load Save 1", intro = "Chờ intro",
            map = "Chờ Forest", checkpoint = "Tới điểm kiểm tra", pulse = "Tìm Egao", returning = "Về Lobby",
            found = "Egao xuất hiện", paused = "Đã tạm dừng", stopped = "Đã dừng",
        }
        local lookText = not options.AutoLook and "Tắt" or (E.LookActive and "Đang theo dõi" or E.LookReason)
        local fields = {
            Phase = phaseNames[E.Phase] or E.Phase,
            Hops = tostring(E.Hops), Time = duration(elapsed), Ping = tostring(math.floor(ping() + 0.5)) .. " ms",
            Pulse = E.Pulse and "Hiện" or (E.PulseExists and "Ẩn" or "Chưa có UI"),
            Look = lookText, Target = E.Target .. (E.TargetDistance and (" · " .. E.TargetDistance .. " st") or ""),
            Queue = E.Queued and "Đã lưu phiên tiếp theo" or "Chưa xếp hàng", Reason = E.LastReason,
        }
        update(egaoCard, { Title = "EGAO / FOREST", Subtitle = E.Detail, State = E.State, Fields = fields })
        update(floatingCard, {
            Title = "EGAO · " .. (phaseNames[E.Phase] or E.Phase), Subtitle = E.Detail, State = E.State,
            Fields = { Hops = tostring(E.Hops), Time = duration(elapsed), Look = lookText, Target = fields.Target },
        })
        showFloat(E.Running and options.Floating == true)
        local target = NK.Target
        update(nearbyCard, {
            Title = "NEARBY / TARGET", Subtitle = NK.Detail, State = NK.State,
            Fields = {
                Target = target and target.instance.Name or "—",
                Kind = target and target.kind or "—", Range = target and (tostring(math.floor(target.dist)) .. " st") or "—",
                Packet = NK.Hook and "Camera replica sẵn sàng" or "Chưa hook · camera giữ nguyên",
                Sent = tostring(NK.Sent), Confirm = "Chưa có xác nhận hạ mục tiêu từ server",
            },
        })
    end
    local function setEgao(phase, detail, state, reason)
        E.Phase, E.Detail, E.State = phase, detail, state or "active"
        if reason then E.LastReason = reason end
        refresh(true)
    end
    local function running(generation)
        return valid() and E.Running and generation == egaoGeneration
    end
    local function sleep(seconds, generation)
        local finish = os.clock() + seconds
        repeat
            if not running(generation) then return false end
            task.wait(math.min(0.10, math.max(0.01, finish - os.clock())))
        until os.clock() >= finish
        return running(generation)
    end
    local function waitUntil(predicate, seconds, generation, interval)
        local finish = os.clock() + seconds
        repeat
            if not running(generation) then return nil end
            local value = predicate()
            if value then return value end
            if not sleep(interval or 0.15, generation) then return nil end
        until os.clock() >= finish
        return nil
    end
    local function environment()
        if ctx.Visuals and ctx.Visuals.SetEnvironment then
            ctx.Visuals:SetEnvironment("Egao", {
                FullBright = E.Running and options.FullBright == true,
                NoFog = E.Running and options.NoFog == true,
            })
        end
    end
    local function clearEnvironment()
        if ctx.Visuals and ctx.Visuals.ClearEnvironment then
            ctx.Visuals:ClearEnvironment("Egao")
        elseif ctx.Visuals and ctx.Visuals.SetEnvironment then
            ctx.Visuals:SetEnvironment("Egao", nil)
        end
    end
    local function stopLook(reason)
        E.LookActive, E.LookReason = false, reason or "Đã nhả camera"
        E.Target, E.TargetDistance = "—", nil
        lookPart, lookRig, lookLabel, pendingRig = nil, nil, nil, nil
        pcall(function() RunService:UnbindFromRenderStep(bindName) end)
    end

    local FACE_PRIORITY = { "sw face", "r eye", "l eye", "teeth", "gums", "head", "face", "RootPart" }
    local function registerRig(rig, newSpawn)
        if rig and rig:IsA("Model") and rig.Name == "EgaoEventRig" and not rigs[rig] then
            rigs[rig] = os.clock()
            if newSpawn and E.LookActive and rig ~= lookRig then
                pendingRig = rig
                lookPart, lookRig, lookLabel = nil, nil, nil
                E.Target, E.TargetDistance = "Phase mới · ổn định 1 giây", nil
            end
        end
    end
    local function targetInRig(rig)
        for _, name in ipairs(FACE_PRIORITY) do
            local part = rig:FindFirstChild(name, true)
            if partAlive(part) then return part, name end
        end
    end
    local function acquireLook()
        local now = os.clock()
        if now - lastRigScan < 0.08 then return end
        lastRigScan = now
        for _, child in ipairs(Workspace:GetChildren()) do registerRig(child) end
        local bestPart, bestRig, bestLabel, bestDistance
        local preferPending = false
        local hrp = root()
        if pendingRig and pendingRig.Parent and rigs[pendingRig] then
            if now - rigs[pendingRig] < 1 then return end
            local part, label = targetInRig(pendingRig)
            if part then
                bestPart, bestRig, bestLabel = part, pendingRig, label
                bestDistance = hrp and (hrp.Position - part.Position).Magnitude or 0
                preferPending = true
            elseif now - rigs[pendingRig] < 3.2 then
                return
            end
            pendingRig = nil
        end
        for rig, firstSeen in pairs(rigs) do
            if not rig.Parent or not rig:IsDescendantOf(Workspace) then
                rigs[rig] = nil
            elseif now - firstSeen >= 1 then
                local part, label = targetInRig(rig)
                if part then
                    local distance = hrp and (hrp.Position - part.Position).Magnitude or 0
                    if not bestPart or (not preferPending and distance < bestDistance) then
                        bestPart, bestRig, bestLabel, bestDistance = part, rig, label, distance
                    end
                end
            end
        end
        lookPart, lookRig, lookLabel = bestPart, bestRig, bestLabel
        E.Target = bestLabel or "Chờ rig / ổn định 1 giây"
        E.TargetDistance = bestDistance and tostring(math.floor(bestDistance)) or nil
    end
    local function startLook(reason)
        if not E.Running then return end
        E.Found = true
        setEgao("found", options.AutoLook and "Đã thấy tín hiệu Egao; theo dõi rig tối đa 62 giây mỗi đợt." or "Đã thấy Egao. Auto Look đang tắt.", "success", reason)
        if not options.AutoLook or E.LookActive then return end
        E.LookActive, E.LookReason, lookStarted = true, "Đang chờ rig", os.clock()
        lookPart, lookRig, lookLabel = nil, nil, nil
        acquireLook()
        RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
            if not valid() or not E.Running or not E.LookActive or not options.AutoLook then return stopLook("Đã tắt") end
            if os.clock() - lookStarted > 62 then
                stopLook("Đã theo dõi đủ 62 giây")
                return refresh(true)
            end
            if not partAlive(lookPart) or not lookRig or not lookRig.Parent then acquireLook() end
            local camera = Workspace.CurrentCamera
            if camera and partAlive(lookPart) then
                local position = lookPart.Position + (lookLabel == "RootPart" and Vector3.new(0, 3.35, 0) or Vector3.zero)
                if (position - camera.CFrame.Position).Magnitude >= 1 then camera.CFrame = CFrame.lookAt(camera.CFrame.Position, position) end
                if os.clock() - lastLookUi >= 0.12 then
                    lastLookUi = os.clock()
                    local hrp = root()
                    E.Target, E.TargetDistance = lookLabel or lookPart.Name, hrp and tostring(math.floor((hrp.Position - lookPart.Position).Magnitude)) or nil
                    E.LookReason = "Tracking · " .. tostring(math.floor(os.clock() - lookStarted)) .. "s"
                end
            end
        end)
    end
    local function queueInfo(enabled, reason)
        return {
            Egao = enabled, EgaoSession = E.Session, Hops = E.Hops, StartedAt = E.StartedAt,
            EgaoReason = reason or E.LastReason, EgaoQueuedAt = os.time(),
            EgaoOptions = { AutoLook = options.AutoLook, FullBright = options.FullBright, NoFog = options.NoFog, Floating = options.Floating },
        }
    end
    local function queueSelf(reason)
        if type(ctx.QueueSelf) ~= "function" then return false end
        local ok, result = pcall(ctx.QueueSelf, queueInfo(true, reason))
        if ok and result == true then E.Queued = true; return true end
        return false
    end
    local function syncToggle(value)
        if egaoToggle and egaoToggle.Set then pcall(function() egaoToggle:Set(value, true) end) end
    end
    local function stopEgao(reason, paused)
        if not E.Running and not E.Queued then return end
        E.Running, E.PendingTeleport, E.PendingSave = false, false, false
        E.FinishedAt = os.time()
        egaoGeneration = egaoGeneration + 1
        if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
        stopLook(reason or "Dừng thủ công")
        clearEnvironment()
        if E.Queued and type(ctx.QueueSelf) == "function" then
            local ok, cancelled = pcall(ctx.QueueSelf, queueInfo(false, reason or "manual stop"))
            if not ok or cancelled ~= true then
                notify("Egao / hàng chờ", "Không cập nhật được hàng chờ hủy. Nếu đã bắt đầu teleport, chạy lại loader và tắt Egao ở màn tiếp theo.")
            end
        end
        E.Queued = false
        syncToggle(false)
        setEgao(paused and "paused" or "stopped", reason or "Đã dừng trong phiên hiện tại.", paused and "error" or "idle", reason or "Dừng thủ công")
    end
    local function pause(reason)
        stopEgao(reason, true)
        notify("Egao / tạm dừng", reason)
    end
    local function requireQueue(reason)
        if queueSelf(reason) then return true end
        pause("Không thể xếp hàng chạy tiếp sau teleport. Cần executor hỗ trợ tiếp tục sau teleport (queue_on_teleport); bật lại khi khả năng này sẵn sàng.")
        return false
    end
    local function remoteNamed(name)
        local direct = ReplicatedStorage:FindFirstChild(name)
        if direct and direct:IsA("RemoteEvent") then return direct end
        for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
            if child.Name == name and child:IsA("RemoteEvent") then return child end
        end
    end
    local function gameLoaded(generation)
        setEgao("loading", "Chờ Roblox tải và nhân vật sẵn sàng.")
        if not waitUntil(function() return game:IsLoaded() end, 120, generation, 0.2) then
            if running(generation) then pause("Game chưa tải xong sau 120 giây. Bật lại khi loading hoàn tất.") end
            return false
        end
        return sleep(0.8, generation)
    end
    local function teleportLobby(generation, reason)
        if not running(generation) then return end
        local previousHops = E.Hops
        E.Hops = E.Hops + 1
        if not requireQueue(reason) then E.Hops = previousHops; refresh(true); return end
        E.PendingTeleport, E.Retry = true, 0
        setEgao("returning", "Không có tín hiệu; quay lại Lobby để thử lượt Forest mới.", "active", reason)
        if not sleep(0.45, generation) then return end
        -- Bounded retries, matching the supplied script's three delayed retries.
        for attempt = 0, 3 do
            if not running(generation) or not E.PendingTeleport then return end
            if attempt > 0 then
                if not sleep(4, generation) then return end
                if not running(generation) then return end
                if not requireQueue(reason) then return end
                E.Retry = attempt
                setEgao("returning", "Teleport Lobby · thử lại " .. attempt .. "/3.", "active", E.LastReason)
            end
            local ok, err = pcall(function() TeleportService:Teleport(LOBBY, Player) end)
            if not ok then setEgao("returning", "Lệnh teleport lỗi: " .. tostring(err), "error", "Teleport rejected") end
        end
        if sleep(6, generation) and E.PendingTeleport then pause("Teleport Lobby chưa hoàn tất sau các lần thử. Kiểm tra kết nối rồi bật lại.") end
    end
    local function runLobby(generation)
        if not gameLoaded(generation) then return end
        setEgao("lobby", "Chọn Save 1 bằng MimicSaveSync(0, 1).", "active", "Lobby → Forest Save 1")
        if not requireQueue("Lobby → Forest Save 1") then return end
        E.PendingSave = true
        for attempt = 1, 12 do
            if not running(generation) then return end
            local remote = remoteNamed("MimicSaveSync")
            if remote then
                local ok, err = pcall(function() remote:FireServer(0, 1) end)
                setEgao("lobby", ok and ("Đã yêu cầu Save 1 / Forest · " .. attempt .. "/12.") or ("MimicSaveSync lỗi: " .. tostring(err)), ok and "active" or "error")
                if not sleep(1.1, generation) then return end
            else
                setEgao("lobby", "Đợi MimicSaveSync · " .. attempt .. "/12.")
                if not sleep(0.6, generation) then return end
            end
        end
        if running(generation) then pause("Chưa vào Forest sau 12 lần. Kiểm tra Save 1 có lưu ở Forest rồi bật lại.") end
    end
    local function pulseFrame()
        local gui = Player:FindFirstChildOfClass("PlayerGui")
        local pulse = gui and gui:FindFirstChild("EgaoPulseText")
        local frame = pulse and pulse:FindFirstChild("Frame")
        return frame and frame:IsA("GuiObject") and frame or nil
    end
    local function forestReady(generation)
        if not gameLoaded(generation) then return false end
        setEgao("loading", "Đợi nhân vật trong Forest.")
        if not waitUntil(root, 20, generation) then
            if running(generation) then pause("Không tìm thấy HumanoidRootPart sau 20 giây.") end
            return false
        end
        setEgao("intro", "Đợi IntroCutscene hoặc map / giao diện đã tải.")
        local intro = waitUntil(function()
            local object = Workspace:FindFirstChild("IntroCutscene")
            if object then return object end
            if Workspace:FindFirstChild("Section3") and pulseFrame() then return true end
        end, 35, generation, 0.25)
        if not running(generation) then return false end
        if typeof(intro) == "Instance" and intro.Parent then
            setEgao("intro", "Chờ IntroCutscene.SpawnBox biến mất (tối đa 90 giây).")
            waitUntil(function() return not intro.Parent or not intro:FindFirstChild("SpawnBox") end, 90, generation, 0.1)
        end
        if not running(generation) then return false end
        setEgao("map", "Đợi EgaoPulseText và Section3 (tối đa 35 giây).")
        waitUntil(function() return Workspace:FindFirstChild("Section3") and pulseFrame() end, 35, generation, 0.25)
        return sleep(1.2, generation)
    end
    local function runForest(generation)
        if not forestReady(generation) then return end
        local hrp = waitUntil(root, 18, generation)
        if not hrp then
            if running(generation) then pause("Không tìm thấy HumanoidRootPart để tới điểm kiểm tra.") end
            return
        end
        setEgao("checkpoint", "Di chuyển 3 giây tới điểm kiểm tra Egao.")
        local ok, err = pcall(function()
            activeTween = TweenService:Create(hrp, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = CHECKPOINT })
            activeTween:Play()
        end)
        if not ok then return pause("Không tạo được tween tới điểm kiểm tra: " .. tostring(err)) end
        if not sleep(3.15, generation) then return end
        activeTween = nil
        if not hrp.Parent or root() ~= hrp then return pause("Nhân vật đổi trong khi di chuyển. Bật lại sau khi hồi sinh.") end
        local frame = waitUntil(pulseFrame, 30, generation, 0.15)
        if not running(generation) then return end
        if not frame then return teleportLobby(generation, "Không thấy EgaoPulseText sau loading + 30 giây") end
        local seconds = 5 + math.clamp(ping() / 1000, 0, 3)
        setEgao("pulse", "Chờ tín hiệu Egao trong " .. string.format("%.1f", seconds) .. " giây.")
        local found = waitUntil(function()
            local current = pulseFrame()
            return E.Found or (current and current.Visible)
        end, seconds, generation, 0.1)
        if not running(generation) then return end
        if found then startLook("Tín hiệu trong cửa sổ kiểm tra") else teleportLobby(generation, "EgaoPulseText không hiện trong cửa sổ kiểm tra") end
    end
    local function startEgao(resume)
        if E.Running or not valid() then return end
        if game.PlaceId ~= LOBBY and game.PlaceId ~= FOREST then
            syncToggle(false)
            return notify("Egao / vị trí", "Tính năng này chạy tại Main Lobby hoặc Book 3 Chapter 1. Hãy tới một trong hai nơi rồi bật.")
        end
        if not resume then
            E.Hops, E.StartedAt = 0, os.time()
            E.Session = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
        end
        E.StartedAt = E.StartedAt or os.time()
        E.FinishedAt = nil
        E.Running, E.Found, E.PendingTeleport, E.PendingSave, E.Queued = true, false, false, false, false
        E.LookReason, E.Target = "Chờ tín hiệu", "—"
        egaoGeneration = egaoGeneration + 1
        local generation = egaoGeneration
        environment()
        syncToggle(true)
        task.spawn(function()
            local ok, err = xpcall(function()
                if game.PlaceId == LOBBY then runLobby(generation) else runForest(generation) end
            end, function(message) return debug.traceback(tostring(message), 2) end)
            if not ok and running(generation) then pause("Lỗi tác vụ Egao: " .. tostring(err)) end
        end)
        task.spawn(function()
            local lastFrame, wasVisible
            while running(generation) do
                local frame = pulseFrame()
                E.PulseExists, E.Pulse = frame ~= nil, frame ~= nil and frame.Visible == true
                if E.Pulse and (frame ~= lastFrame or not wasVisible) then startLook("EgaoPulseText hiện") end
                lastFrame, wasVisible = frame, E.Pulse
                refresh()
                if not sleep(0.25, generation) then return end
            end
        end)
    end

    -- Nearby Kill adapter derived from cc; target-specific remotes never expand to a FleshBlock parent.
    local function killRange(kind)
        if kind == "Spider" then return math.clamp(nkOptions.SpiderRange, 0, 9999) end
        if kind == "FleshBlock" then return math.clamp(nkOptions.FleshRange, 0, 9999) end
        if kind == "Hogo" then return math.clamp(nkOptions.HogoRange, 0, 9999) end
        return math.clamp(nkOptions.CreepRange, 0, 9999)
    end
    local function aimDot(position)
        local camera = Workspace.CurrentCamera
        if not camera then return 0 end
        local delta = position - camera.CFrame.Position
        return delta.Magnitude < 0.01 and 1 or math.clamp(camera.CFrame.LookVector:Dot(delta.Unit), -1, 1)
    end
    local function lookingAtBody(body)
        if not partAlive(body) then return false end
        local camera = Workspace.CurrentCamera
        if not camera then return false end
        local params = RaycastParams.new()
        params.FilterType, params.IgnoreWater = Enum.RaycastFilterType.Exclude, true
        params.FilterDescendantsInstances = Player.Character and { Player.Character } or {}
        local result = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 260, params)
        if not result then return aimDot(body.Position) >= 0.86 end
        local hit, block = result.Instance, body.Parent
        return hit == body or hit:IsDescendantOf(body) or (block and (hit == block or hit:IsDescendantOf(block)))
    end
    local function nearestPart(object)
        local hrp = root()
        if not object or not object.Parent or not hrp then return nil, math.huge end
        local best, distance
        local function test(part)
            if partAlive(part) then
                local d = (part.Position - hrp.Position).Magnitude
                if not best or d < distance then best, distance = part, d end
            end
        end
        if object:IsA("BasePart") then test(object) else
            for _, part in ipairs(object:GetDescendants()) do if part:IsA("BasePart") then test(part) end end
        end
        return best, distance or math.huge
    end
    local function remotesIn(object)
        local list, seen = {}, {}
        local function add(remote)
            if remote and remote:IsA("RemoteEvent") and not seen[remote] and #list < 12 then
                seen[remote] = true
                table.insert(list, remote)
            end
        end
        if not object or not object.Parent then return list end
        if object:IsA("RemoteEvent") then add(object); return list end
        add(object:FindFirstChildWhichIsA("RemoteEvent"))
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("RemoteEvent") then add(child); if #list >= 12 then break end end
        end
        return list
    end
    local function refreshTarget(target)
        if not target or not nkOptions.Filters[target.kind] or not target.instance.Parent then return false end
        local hrp = root()
        if not hrp then return false end
        local humanoid = target.instance:IsA("Model") and target.instance:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then return false end
        local anchor, distance
        if target.kind == "Spider" then
            anchor = target.instance:FindFirstChild("Hitbox")
        elseif target.kind == "FleshBlock" then
            anchor = target.body
            if not partAlive(anchor) or anchor.Name:lower() ~= "body" or not lookingAtBody(anchor) then return false end
        else anchor, distance = nearestPart(target.instance) end
        if not partAlive(anchor) then return false end
        distance = distance or (anchor.Position - hrp.Position).Magnitude
        if distance > killRange(target.kind) then return false end
        target.anchor, target.dist, target.dot = anchor, distance, aimDot(anchor.Position)
        target.cframe = (target.kind == "Spider" or target.kind == "FleshBlock") and anchor.CFrame or CFrame.new(anchor.Position)
        return true
    end
    local function chooseTarget()
        local targets, seen = {}, {}
        local function add(object, kind, body)
            if not object or seen[body or object] or not nkOptions.Filters[kind] then return end
            seen[body or object] = true
            local target = { instance = object, kind = kind, body = body, lockedAt = os.clock(), remotesAt = 0 }
            if refreshTarget(target) then table.insert(targets, target) end
        end
        local section1 = path({ "Section1", "Grunts" })
        if section1 and nkOptions.Filters.Gata then
            for _, object in ipairs(section1:GetChildren()) do
                if object:IsA("Model") and object:FindFirstChildOfClass("Humanoid") then add(object, "Gata") end
            end
        end
        if nkOptions.Filters.Grunt then
            for _, section in ipairs(Workspace:GetChildren()) do
                if section.Name:match("^Section%d+") and section.Name ~= "Section1" then
                    local grunts = section:FindFirstChild("Grunts")
                    if grunts then
                        for _, object in ipairs(grunts:GetDescendants()) do
                            if object:IsA("Model") and object.Name:lower():find("grunt", 1, true) then add(object, "Grunt") end
                        end
                    end
                end
            end
        end
        local objective = path({ "Section4", "Lab", "Floor1", "Objective2" })
        if objective and nkOptions.Filters.Muki then
            for _, object in ipairs(objective:GetDescendants()) do
                if object:IsA("Model") and object.Name:lower():find("muki", 1, true) then add(object, "Muki") end
            end
        end
        if nkOptions.Filters.Hogo then
            for _, names in ipairs({ { "Section5", "StairsSection", "Monster" }, { "Section4" } }) do
                local folder = path(names)
                if folder then
                    local pool = folder:GetDescendants()
                    table.insert(pool, 1, folder)
                    for _, object in ipairs(pool) do
                        if object:IsA("Model") and object.Name:lower():find("hogo", 1, true) then add(object, "Hogo") end
                    end
                end
            end
        end
        local stairs = path({ "Section5", "StairsSection" })
        if stairs and nkOptions.Filters.FleshBlock then
            for _, object in ipairs(stairs:GetDescendants()) do
                if object:IsA("BasePart") and object.Name:lower() == "body" and object:GetFullName():lower():find("fleshblock", 1, true) then
                    add(object.Parent, "FleshBlock", object)
                end
            end
        end
        local spiders = path({ "Section2", "MAINOBJECTIVE2", "Spiders" })
        if spiders and nkOptions.Filters.Spider then
            for _, object in ipairs(spiders:GetChildren()) do if object.Name == "AkariSpider" then add(object, "Spider") end end
        end
        -- Deterministic selection avoids the non-transitive comparator in cc.
        -- Exclude FleshBlock while an eligible Hogo exists, then rank aim buckets and distance.
        local hasHogo = false
        for _, target in ipairs(targets) do if target.kind == "Hogo" then hasHogo = true; break end end
        local best, bestFront, bestAim
        for _, target in ipairs(targets) do
            if not (hasHogo and target.kind == "FleshBlock") then
                local front, aim = target.dot >= 0.45 and 1 or 0, math.floor((target.dot + 1) / 0.12)
                if not best or front > bestFront or (front == bestFront and (aim > bestAim or (aim == bestAim and target.dist < best.dist))) then
                    best, bestFront, bestAim = target, front, aim
                end
            end
        end
        return best
    end
    local function globalEnv()
        local ok, env = pcall(function() return getgenv() end)
        return ok and type(env) == "table" and env or _G
    end
    local lastHookAttempt = -10
    local function installHook()
        if os.clock() - lastHookAttempt < 3 then return NK.Hook end
        lastHookAttempt = os.clock()
        local env = globalEnv()
        local store = rawget(env, "__SlateNearbyPacketHookV1")
        if type(store) ~= "table" then
            store = { Records = setmetatable({}, weak), Owner = nil, Replica = nil, Workspace = Workspace }
            rawset(env, "__SlateNearbyPacketHookV1", store)
        end
        hookStore = store
        local modules = ReplicatedStorage:FindFirstChild("modules")
        local packetModule = modules and modules:FindFirstChild("Packet")
        if not packetModule then NK.Hook = false; return false end
        local ok, installed = pcall(function()
            local packet = require(packetModule)
            local updateState = packet.unreliablesend.ReplicationService.Character.updateState
            local mt = getmetatable(updateState)
            if type(mt) ~= "table" or type(mt.__call) ~= "function" then return false end
            local targetFunction = mt.__call
            if store.Records[targetFunction] then return true end
            local hookFn = rawget(env, "hookfunction") or hookfunction
            if type(hookFn) ~= "function" then return false end
            local closureFn = rawget(env, "newcclosure") or newcclosure or function(fn) return fn end
            local old
            old = hookFn(targetFunction, closureFn(function(...)
                local replica, camera = store.Replica, store.Workspace.CurrentCamera
                if store.Owner and replica and camera then
                    local args = table.pack(...)
                    local nameOk, name = pcall(function() return args[1].__name end)
                    if nameOk and name == "updateState" then
                        local direction = replica.Position - camera.CFrame.Position
                        if direction.Magnitude > 0.001 then
                            args[2] = CFrame.lookAt(camera.CFrame.Position, replica.Position)
                            return old(table.unpack(args, 1, args.n))
                        end
                    end
                end
                return old(...)
            end))
            store.Records[targetFunction] = true
            return true
        end)
        NK.Hook = ok and installed == true
        return NK.Hook
    end
    local function clearReplica()
        if hookStore and hookStore.Owner == owner then hookStore.Owner, hookStore.Replica = nil, nil end
    end
    local function stopNearby()
        NK.Running, NK.Target, NK.State = false, nil, "idle"
        NK.Detail = "Đã dừng; camera replica đã nhả."
        nearbyGeneration = nearbyGeneration + 1
        clearReplica()
        if nearbyToggle and nearbyToggle.Set then pcall(function() nearbyToggle:Set(false, true) end) end
        refresh(true)
    end
    local function startNearby()
        if NK.Running or not valid() then return end
        if ctx.Scope ~= "Book3" or game.PlaceId ~= FOREST then return notify("Nearby Kill", "Tính năng này dành cho Book 3 Chapter 1.") end
        NK.Running, NK.State, NK.Sent = true, "active", 0
        NK.Detail = "Đang tìm mục tiêu hợp lệ; ưu tiên tâm camera."
        nearbyGeneration = nearbyGeneration + 1
        local generation = nearbyGeneration
        task.spawn(function()
            local gunAction, nextRemoteScan = nil, 0
            local ok, err = xpcall(function()
                while valid() and NK.Running and generation == nearbyGeneration do
                    local now = os.clock()
                    if now >= nextRemoteScan or (gunAction and not gunAction.Parent) then
                        gunAction, nextRemoteScan = remoteNamed("GunAction"), now + 2
                        installHook()
                    end
                    if not valid() or not NK.Running or generation ~= nearbyGeneration then break end
                    local target = NK.Target
                    if not refreshTarget(target) or now - target.lockedAt > 1.35 then target = chooseTarget(); NK.Target = target end
                    if target and gunAction and gunAction.Parent then
                        if hookStore and NK.Hook then hookStore.Owner, hookStore.Replica = owner, target.cframe end
                        if not target.remotes or now - target.remotesAt >= 0.35 then
                            target.remotes = remotesIn((target.kind == "Spider" or target.kind == "FleshBlock") and target.anchor or target.instance)
                            target.remotesAt = now
                        end
                        local sent = 0
                        if pcall(function() gunAction:FireServer("fire") end) then sent = sent + 1 end
                        for index, remote in ipairs(target.remotes) do
                            if index > 8 then break end
                            if remote.Parent and pcall(function() remote:FireServer() end) then sent = sent + 1 end
                        end
                        NK.Sent = NK.Sent + sent
                        NK.State, NK.Detail = sent > 0 and "active" or "error", sent > 0 and "Đã gửi yêu cầu; chưa xác nhận hạ mục tiêu." or "Remote từ chối / đã đổi; đang dò lại."
                        if sent == 0 then gunAction = nil; nextRemoteScan = 0 end
                        refresh()
                        task.wait(math.clamp(nkOptions.FireDelay, 0.01, 10))
                    else
                        clearReplica()
                        NK.State = gunAction and "active" or "error"
                        NK.Detail = not gunAction and "Chưa thấy GunAction; tự dò lại mỗi 2 giây." or "Không có mục tiêu hợp lệ trong tầm / bộ lọc hiện tại."
                        refresh()
                        task.wait(0.25)
                    end
                end
            end, function(message) return debug.traceback(tostring(message), 2) end)
            if generation == nearbyGeneration then
                NK.Running, NK.Target = false, nil
                clearReplica()
                if not ok then NK.State, NK.Detail = "error", "Nearby Kill đã dừng do lỗi: " .. tostring(err); notify("Nearby Kill", NK.Detail) end
                refresh(true)
            end
        end)
    end

    on(Workspace.DescendantAdded, function(object)
        if E.Running and object.Name == "EgaoEventRig" then
            registerRig(object, true)
        elseif E.LookActive and lookRig and object:IsA("BasePart") and object:IsDescendantOf(lookRig) then
            local part, label = targetInRig(lookRig)
            if part then lookPart, lookLabel = part, label end
        end
    end)
    on(TeleportService.TeleportInitFailed, function(player, result, message)
        if player ~= Player or not E.Running or not (E.PendingTeleport or E.PendingSave) then return end
        local resultName = typeof(result) == "EnumItem" and result.Name or tostring(result)
        E.LastReason = "TeleportInitFailed: " .. resultName
        setEgao(E.PendingTeleport and "returning" or "lobby", resultName .. " · " .. tostring(message or "") .. " · đang dùng lượt thử còn lại.", "error", E.LastReason)
    end)

    function api.BuildTabs(window, chapter)
        if built or not valid() then return end
        built = true
        local applicable = game.PlaceId == LOBBY or game.PlaceId == FOREST or chapter == "B3C1"
        if not applicable then return end
        local tab = window:Tab({ Title = "Egao", Icon = "smile" })
        local function optionsChanged()
            save()
            if E.Running then environment() else clearEnvironment() end
            if E.Running and E.Queued then
                if not queueSelf(E.LastReason) then pause("Không cập nhật được tùy chọn trong hàng chờ. Kiểm tra khả năng tiếp tục sau teleport rồi bật lại.") end
            end
            refresh(true)
        end
        tab:Section({ Title = "FOREST EVENT", Icon = "sparkles" })
        if tab.Status then
            egaoCard = tab:Status({ Title = "EGAO / FOREST", Subtitle = E.Detail, State = "idle", Fields = { Phase = "Sẵn sàng", Hops = tostring(E.Hops), Time = "00:00:00", Ping = "—", Pulse = "—", Look = "—", Target = "—", Queue = "—", Reason = E.LastReason } })
        else egaoCard = window:Status({ Title = "EGAO / FOREST", Subtitle = E.Detail, Fields = {} }) end
        egaoToggle = tab:Toggle({ Title = "Auto Find Egao", Desc = "Lobby → Save 1 / Forest → kiểm tra tín hiệu → quay Lobby nếu chưa có.", Value = false, Callback = function(value) if value then startEgao(false) else stopEgao("Dừng thủ công", false) end end })
        tab:Toggle({ Title = "Auto Look", Desc = "Nhìn mặt Egao sau 1 giây ổn định; nhả camera sau 62 giây.", Value = options.AutoLook, Callback = function(value)
            options.AutoLook = value
            if not value then stopLook("Tắt Auto Look") elseif E.Running and E.Found then startLook("Bật Auto Look thủ công") end
            optionsChanged()
        end })
        tab:Toggle({ Title = "Fullbright khi tìm Egao", Value = options.FullBright, Callback = function(value) options.FullBright = value; optionsChanged() end })
        tab:Toggle({ Title = "No Fog khi tìm Egao", Desc = "Chỉ bỏ sương / Atmosphere; giữ các hiệu ứng màn hình khác.", Value = options.NoFog, Callback = function(value) options.NoFog = value; optionsChanged() end })
        if window.FloatingStatus then
            floatingCard = window:FloatingStatus({ Title = "EGAO", Subtitle = E.Detail, Fields = {}, Visible = false })
            tab:Toggle({ Title = "Thanh trạng thái nổi", Value = options.Floating, Callback = function(value) options.Floating = value; optionsChanged() end })
        end
        tab:Button({ Title = "Dừng tìm kiếm", Icon = "square", Callback = function() stopEgao("Dừng thủ công", false) end })
        tab:Paragraph({ Title = "Save 1 và tiếp tục sau teleport", Desc = "Luồng theo egao.txt mới: gọi MimicSaveSync(0, 1). Save 1 phải ở Forest. Cần executor hỗ trợ tiếp tục sau teleport; script sẽ tạm dừng nếu chưa thể xếp hàng chạy tiếp." })
        if ctx.Scope == "Book3" and (game.PlaceId == FOREST or chapter == "B3C1") then
            local near = window:Tab({ Title = "Nearby", Icon = "crosshair" })
            near:Section({ Title = "NEARBY KILL", Icon = "focus" })
            nearbyCard = near.Status and near:Status({ Title = "NEARBY / TARGET", Subtitle = NK.Detail, State = "idle", Fields = { Target = "—", Kind = "—", Range = "—", Packet = "Chưa hook", Sent = "0", Confirm = "Chưa có xác nhận server" } }) or nil
            nearbyToggle = near:Toggle({ Title = "Nearby Kill", Desc = "Gata, Grunt, Muki, Hogo, FleshBlock, Spider trong tầm. Không teleport.", Value = false, Callback = function(value) if value then startNearby() else stopNearby() end end })
            for _, spec in ipairs({
                { "CreepRange", "Tầm Gata / Grunt / Muki", 500 }, { "HogoRange", "Tầm HogoGuntai", 250 },
                { "FleshRange", "Tầm FleshBlock", 150 }, { "SpiderRange", "Tầm AkariSpider", 150 },
            }) do
                local key = spec[1]
                near:Slider({ Title = spec[2], Desc = "studs", Step = 1, Value = { Min = 0, Max = spec[3], Default = nkOptions[key] }, Callback = function(value) nkOptions[key] = tonumber(value) or nkDefaults[key]; save() end })
            end
            near:Slider({ Title = "Khoảng nghỉ bắn", Desc = "giây", Step = 0.01, Value = { Min = 0.01, Max = 1, Default = nkOptions.FireDelay }, Callback = function(value) nkOptions.FireDelay = tonumber(value) or 0.03; save() end })
            near:Section({ Title = "BỘ LỌC MỤC TIÊU", Icon = "filter" })
            for _, kind in ipairs({ "Gata", "Grunt", "Muki", "Hogo", "FleshBlock", "Spider" }) do
                local key = kind
                near:Toggle({ Title = kind, Value = nkOptions.Filters[key], Callback = function(value) nkOptions.Filters[key] = value; save() end })
            end
            near:Paragraph({ Title = "FleshBlock / phản hồi server", Desc = "FleshBlock chỉ hợp lệ khi camera đang nhìn đúng body / block. Chỉ gửi remote dưới body, không mở rộng lên parent. Số yêu cầu đã gửi không đồng nghĩa với số quái đã hạ." })
        end
        refresh(true)
        -- Queued startup is deferred so a newer queued cancellation can replace the session first.
        task.defer(function()
            if valid() and type(ctx.QueueInfo) == "table" and ctx.QueueInfo.Egao == true then startEgao(true) end
        end)
    end
    api.StartEgao = function() startEgao(false) end
    api.StopEgao = function() stopEgao("Dừng thủ công", false) end
    api.StopAll = function()
        stopEgao("Dừng mọi tác vụ", false)
        stopNearby()
        syncToggle(false)
    end
    api.GetStatus = function() return E, NK end
    function api.Destroy()
        if not alive then return end
        stopEgao("Đã unload Slate", false)
        stopNearby()
        alive = false
        stopLook("Đã unload Slate")
        clearEnvironment()
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        table.clear(connections)
        if floatingCard and floatingCard.Destroy then pcall(function() floatingCard:Destroy() end) end
        -- The singleton packet hook stays installed as a pass-through; it keeps no runtime callback.
        clearReplica()
    end
    if ctx.addCleanup then ctx.addCleanup(api.Destroy) end
    return api
end

end

Modules.Legacy = function(GG)
-- Slate / Book3: extracted from user-supplied TheMimicV3.D11.
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
Config.B3C1 = Config.B3C1 or {};
Config.B3C1.City = Config.B3C1.City or {};
Config.B3C1.City.ESP = Config.B3C1.City.ESP or {};
Config.B3C1.School = Config.B3C1.School or {};
Config.B3C1.School.ESP = Config.B3C1.School.ESP or {};
Config.B3C1.Forest = Config.B3C1.Forest or {};
Config.B3C1.Forest.ESP = Config.B3C1.Forest.ESP or {};
Config.B3C1.IJO = Config.B3C1.IJO or {};
Config.B3C1.IJO.ESP = Config.B3C1.IJO.ESP or {};
Config.B3C1.Water = Config.B3C1.Water or {};
Config.B3C1.Water.ESP = Config.B3C1.Water.ESP or {};

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
        local B3C1Con           = Config.B3C1;
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

        local AllowedChapters = {["B3C1"] = true; ["Lobby"] = true};
        if not Chapter or not AllowedChapters[Chapter] then
            return function()
                warn("[Slate / Book3] This place is not supported by this package: " .. tostring(PlaceId));
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

        Functions.B3C1Func = function(self, where)
            if where == "City/Kill" then
                local CHs=GetChildren(W.Section1.Grunts); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                        local sRE = FindFirstChild(v, "RemoteEvent");
                        if not sRE then continue; end;
                        while v.Parent and sRE.Parent and not CoreDestroyed do
                            if self:ToolNow("Gun") then
                                local Pivot = GetPivot(v);
                                Tp(HumRSelf, Pivot*CFr(0, 40, 0));
                                R.GunAction:FireServer("fire");
                                sRE:FireServer();
                            end; twait();
                        end;
                    end;
                end;
            elseif where == "City/Body" then
                local Bodies = GetChildren(W.Section1.DeadCivilians); for i=1, #Bodies do
                    local v = Bodies[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "HumanoidRootPart");
                        Prox = Prox and FindFirstChild(Prox, "ProximityPrompt");
                        if Prox then
                            Tp(HumRSelf, Prox.Parent.CFrame, 0.3);
                            fireproximityprompt(Prox);
                        end;
                    end;
                end; return Tp(HumRSelf, CFr(81, 9.3, 224));
            elseif where == "City/Mika" then
                Tp(HumRSelf, W.Section1.Monster.Trigger.CFrame);
            elseif where == "City/Hideo" then
                Tp(HumRSelf, GetPivot(W.Section1.HideoScene.Hideo2));
            elseif where == "City/Cutter" then
                local Prox = W.Section1.SchoolGatePart.Truck.BoltCutter.Main.ProximityPrompt;
                Tp(HumRSelf, Prox.Parent.CFrame); fireproximityprompt(Prox);
            elseif where == "City/Cut" then
                local Prox = W.Section1.SchoolGatePart.Gate.Chain.PromptPart.ProximityPrompt;
                Tp(HumRSelf, Prox.Parent.CFrame, 0.3); for i=1, 4 do
                    fireproximityprompt(Prox);
                end;
            elseif where == "School/Med" then
                fireproximityprompt(W.Section2.Items.Bandage.Handle.ProximityPrompt);
            elseif where == "School/Heal" then
                local sRE = R.modules.Packet.Reliable;
                sRE:FireServer("Section2/HideoMinigameStarted");
                sRE:FireServer("Section2/HideoHealed");
                return sRE:FireServer("Section2/HideoMinigameEnded");
            elseif where == "School/Note" then
                Tp(HumRSelf, CFr(142, 20, 504), 0.3);
                fireproximityprompt(W.Section2.MAINOBJECTIVE.Locker.LockerDoor.ProximityPart.ProximityPrompt);
                Tp(HumRSelf, CFr(142, 20, 504), 0.3);
                fireproximityprompt(W.Section2.MAINOBJECTIVE.Diary.ProximityPrompt, 0.3);
            elseif where == "School/Freeze" then
                local CHs = GetChildren(W.Section2.MAINOBJECTIVE2.Spiders); for i=1, #CHs do
                    local v=CHs[i]; if v.Name ~= "AkariSpider" then continue; end;
                    local RootPart = FindFirstChild(v, "RootPart");
                    if not RootPart then continue; end;

                    local Bones = FindFirstChild(RootPart, "Bone");
                    if not Bones then continue; end;
                    Bones:Destroy();
                end;
            elseif where == "School/Spider" then
                local CHs = GetChildren(W.Section2.MAINOBJECTIVE2.Spiders); for i=1, #CHs do
                    local v=CHs[i]; if v.Name ~= "AkariSpider" then continue; end;
                    local Hitbox = FindFirstChild(v, "Hitbox");
                    if not Hitbox then continue; end;
                    local sRE = FindFirstChild(Hitbox, "RemoteEvent");
                    if not sRE then continue; end;

                    local Akari = FindFirstChild(W.Section2.Monster, "AkariNM") or FindFirstChild(W.Section2.Monster, "Akari");
                    Akari = Akari or FindFirstChild(W.Section2.Rage, "AkariRageNM", true) or FindFirstChild(W.Section2.Rage, "AkariRage", true);
                    if not Akari or not Akari.Parent then return; end;
                    
                    if distOf(Akari.Hitbox, HumRSelf, 60) then continue; end;

                    Tp(HumRSelf, Hitbox.CFrame, 0.3);

                    for ri=1, 50 do
                        if not Hitbox.Parent or not sRE.Parent then
                            break;
                        end;

                        if distOf(Akari.Hitbox, HumRSelf, 60) then
                            Tp(HumRSelf, CFr(142, 20, 504)); break;
                        end;

                        if self:ToolNow("Gun") then
                            R.GunAction:FireServer("fire");
                            sRE:FireServer(); twait();
                        end;
                    end;
                end;
            elseif where == "School/Exit" then
                Tp(HumRSelf, CFr(175, 8, 508), 0.3);
                fireproximityprompt(W.Section2.School.Doors.ExitDoor.ProxPart.ProximityPrompt);
            elseif where == "School/Forest" then
                Tp(HumRSelf, CFr(-197, 50, 338));
            elseif where == "Forest/Cave" then
                Tp(HumRSelf, W.Section3.Trigger.CFrame, 1);
                Tp(HumRSelf, W.Section3.OBJECTIVE.Trigger2.CFrame);
            elseif where == "Forest/Generator" then
                local CHs = GetChildren(W.Section3.OBJECTIVE.Circuits); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "CircuitPillar" then
                        v.CollisionPart.CanCollide = false;
                        Tp(HumRSelf, v.CollisionPart.CFrame, 0.3);
                        fireproximityprompt(v.PromptPart.ProximityPrompt);
                        for i=1, 3 do
                            if GetAttribute(v, "CurrentRound") == 4 then
                                return;
                            end; R.modules.Packet.Reliable:FireServer(
                                "Section3/CircuitRoundComplete",
                                v
                            );
                        end;
                    end;
                end;
            elseif where == "IJO/Keycard" then
                local Prompt = W.Section4.Lab.Floor1.Entrance.IDCARD.ProximityPrompt;
                Tp(HumRSelf, Prompt.Parent.CFrame, 0.3); fireproximityprompt(Prompt);
            elseif where == "IJO/PASS" then
                R.modules.Packet.Unreliable:FireServer(
                    "Section4/LaptopSubmit",
                    W.Section4.Lab.Floor1.Objective.StickyNote.PASSWORD.SurfaceGui.RandomNumber.Text
                );
            elseif where == "IJO/C4" then
                local CHs=GetChildren(W.Section4.Lab.Floor1.Objective2.C4Explode); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "C4Bomb" then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, v.CFrame, 0.3);
                        fireproximityprompt(Prox, 1);
                    end;
                end;
            elseif where == "IJO/C4_2" then
                Tween({primary = HumRSelf; goal = { CFrame = CFr(-4147, 107, 2154) }, info=TweenInfo.new(3)});
                Tween({primary = HumRSelf; goal = { CFrame = CFr(-4143, 107, 2501) }, info=TweenInfo.new(3)});
                local CHs = GetChildren(W.Section4.Lab.Floor1.Objective3.C4Explode); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "C4Bomb" then
                        local Prox = FindFirstChild(v, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        Tp(HumRSelf, v.CFrame, 0.3);
                        fireproximityprompt(Prox, 1);
                    end;
                end;
            elseif where == "IJO/Exit" then
                Tp(HumRSelf, CFr(-3379, -300, 4451));
            elseif where == "IJO/Terminal" then
                local HogoGuntai = FindFirstChild(W.Section4.Monster, "HogoGuntai");
                local CHs=GetChildren(W.Section4.Lab.CleanseRoomObjective.ShapeTerminals); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and strfind(v.Name, "Terminal") then
                        local Prox = FindFirstChild(v, "PromptPart");
                        Prox = Prox and FindFirstChild(Prox, "ProximityPrompt");
                        if not Prox or not Prox.Enabled then continue; end;
                        if distOf(HogoGuntai.Hitbox, Prox.Parent, 60) then
                            continue;
                        end; Tp(HumRSelf, Prox.Parent.CFrame, 0.3);
                        fireproximityprompt(Prox); twait(0.3);
                        Tp(HumRSelf, CFr(-3389, -298, 4390), 1);
                        R.modules.Packet.Reliable:FireServer(
                            "ShapeTerminal/RoundComplete",
                            v
                        );
                        R.modules.Packet.Reliable:FireServer(
                            "ShapeTerminal/Release",
                            v
                        );
                    end;
                end; Tp(HumRSelf, CFr(-3389, -298, 4390));
            elseif where == "IJO/Valve" then
                local HogoGuntai = FindFirstChild(W.Section4.Monster, "HogoGuntai");
                local CHs=GetChildren(W.Section4.Lab.CleanseRoomObjective.Valves);
                
                for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                        local Icon = v.Notification.Icon;
                        if not Icon.Enabled then continue; end;
                        local Chs = GetChildren(v);
                        while Icon.Enabled do
                            Tp(HumRSelf, Icon.Parent.CFrame); for i=1, #Chs do
                                local v2 = Chs[i]; if v2 and v2.Name == "Turners" then
                                    local Prompt = FindFirstChild(v2, "Right");
                                    if distOf(HogoGuntai.Hitbox, Prompt.Parent, 60) then
                                        return Tp(HumRSelf, CFr(-3389, -298, 4390));
                                    elseif Prompt then
                                        Tp(HumRSelf, Icon.Parent.CFrame);
                                        fireproximityprompt(Prompt);
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            elseif where == "IJO/Threat" then
                R.modules.Packet.Reliable:FireServer("Section4/LockdownSkillCheckHit");
            elseif where == "Water/Stair" then
                Tp(HumRSelf, W.Section5.StairsSection.EndTrigger.CFrame);
            elseif where == "Water/Main" then
                local MainSwitch = W.Section5.MainObjective.PowerSwitch.RootPart.ProximityPrompt;
                Tp(HumRSelf, MainSwitch.Parent.CFrame, 0.3);
                fireproximityprompt(MainSwitch, 1);
            elseif where == "Water/Wire" then
                local sRE = R.modules.Packet.Reliable;
                local CHs = GetChildren(W.Section5.MainObjective.Boxes);

                for i=1, #CHs do
                    local box=CHs[i]; if box.Parent and box.Name == "WireBox" then
                        if box.PromptPart.ProximityPrompt.Enabled then
                            sRE:FireServer("Section5/WireBoxClaim", box);
                            sRE:FireServer("Section5/WireBoxClaim", box);

                            for _,v in pairs(GetChildren(box.Bolt)) do
                                if v.Name == "Screw" then
                                    sRE:FireServer("Section5/WireBoxScrewDone", v);
                                end;
                            end; for _,v in pairs(GetChildren(box.Cuttable)) do
                                if v.Name == "Cut" then
                                    sRE:FireServer("Section5/WireBoxCutDone", v);
                                end;
                            end;

                            sRE:FireServer("Section5/WireBoxComplete", box);
                        end;
                    end;
                end;
            end;
        end;

        Functions.B3C1ESP = function(self, where, state)
            if not state then
                return ESPF.Visible(where, false);
            elseif where == "City/Gatas" then
                local CHs=GetChildren(W.Section1.Grunts); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                        ESPF.ESP(where, v, {
                            Color = RED;
                            Size = VEC10;
                            Text = v.Name;
                        });
                    end;
                end;
            elseif where == "City/Bodies" then
                local Bodies = GetChildren(W.Section1.DeadCivilians); for i=1, #Bodies do
                    local v = Bodies[i]; if v.Parent then
                        local Prox = FindFirstChild(v, "HumanoidRootPart");
                        Prox = Prox and FindFirstChild(Prox, "ProximityPrompt");
                        local ESPObject = ESPF.ESP(where, v, {
                            Color = if Prox then YELLOW else GREEN;
                            Size = VEC10;
                            Text = v.Name;
                        }); if Prox and (not ESPObject.PropChange or not ESPObject.PropChange.Connected) then
                            ESPObject.PropChange = TrackOnce(Prox.Destroying, function()
                                ESPObject.UpdateColor(GREEN);
                            end);
                        end;
                    end;
                end;
            elseif where == "Akari" then
                local Akari = FindFirstChild(W.Section2.Monster, "AkariNM") or FindFirstChild(W.Section2.Monster, "Akari");
                Akari = Akari or FindFirstChild(W.Section2.Rage, "AkariRageNM", true) or FindFirstChild(W.Section2.Rage, "AkariRage", true);
                if not Akari then return; end; ESPF.ESP(where, Akari, {
                    Color = RED;
                    Size = VEC10;
                    Text = Akari.Name;
                });
            elseif where == "Mizuno" then
                local Mizuno = FindFirstChild(W.Section3.Monster, "Mizuno") or FindFirstChild(W.Section3.Monster, "MizunoNM");
                if not Mizuno then return; end; ESPF.ESP(where, Mizuno, {
                    Color = RED;
                    Size = VEC10;
                    Text = "Mizuno";
                });
            elseif where == "Terminal" then
                local CHs=GetChildren(W.Section4.Lab.CleanseRoomObjective.ShapeTerminals); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.Name == "Terminal" then
                        ESPF.ESP(where, v, {
                            Color = WHITE;
                            Size = VEC10;
                            Text = "Terminal";
                        });
                    end;
                end;
            elseif where == "BoulderSeal" then
                ESPF.ESP(where, W.Section4.Lab.Floor1.Objective2.C4Explode.BoulderSeal, {
                    Color = GREEN;
                    Size = VEC10;
                    Text = "Seal";
                });
            elseif where == "HogoGuntai" then
                ESPF.ESP(where, W.Section4.Monster.HogoGuntai, {
                    Color = RED;
                    Size = VEC10;
                    Text = "HogoGuntai";
                });
            elseif where == "Baigai" then
                ESPF.ESP(where, W.Section5.Monster.Baigai, {
                    Color = RED;
                    Size = VEC10;
                    Text = "Baigai";
                });
            end; ESPF.Visible(where, true, true);
        end;

        ScriptData.AutoData = {
            YenTab = ((Chapter == "B2C2" or Chapter == "B2C3" or Chapter == "B2C4" or Chapter == "B3C1") and {
                {type="Toggle", EN="Collect All Yen", EN2="Teleport & collect spawned yen", TH1="เก็บเงินทั้งหมด", TH2="วาปไปเก็บเงินทั้งหมดที่เกิดอยู่", Path="Auto"},
                {type="Toggle", EN="Yen Aura", EN2="Auto collect nearby Yen.", TH1="ออโต้เก็บเงิน", TH2="ออโต้เก็บเงินในระยะ", Path="Aura"},
                {type="Toggle", EN="ESP Yen", EN2="Show Yen boxes.", TH1="ESP เงิน", TH2="มองเห็นเงิน", Path="ESP"},
            });

            PackB3C1 = (Chapter == "B3C1" and {
                Tabs={
                    {Tab={at="B3C1", Title="City", Icon="book-open", Path="B3C1"}, Data={
                        {type="Button", EN="Kill All Gatas", EN2="Teleport & fire a shot with client validation.", TH1="ยิง Gatas", TH2="วาปไปยิง Gatas พร้อมการยืนยันจาก Client", Callback=function()
                            return Functions:B3C1Func("City/Kill");
                        end};
                        {type="Button", EN="Interact All Dead Bodies", EN2="Teleport to dead bodies and interact.", TH1="รายงานศพ", TH2="วาปไปรายงานศพ", Callback=function()
                            return Functions:B3C1Func("City/Body");
                        end};
                        {type="Button", EN="Teleport To Mika", EN2="Watch she's gone.", TH1="วาปไปหา Mika", TH2="ไปดูฉากสิ้นหวัง", Callback=function()
                            return Functions:B3C1Func("City/Mika");
                        end};
                        {type="Button", EN="Teleport To Hideo/Door", EN2="Tell Hideo a sad story.", TH1="วาปไปหา Hideo", TH2="ไปเล่าเรื่องราวสิ้นหวัง", Callback=function()
                            return Functions:B3C1Func("City/Hideo");
                        end};
                        {type="Button", EN="Cut The Chains", EN2="Teleport & magically cut the chain.", TH1="ตัดโซ่", TH2="วาปและตัดโซ่แบบงงๆ", Callback=function()
                            return Functions:B3C1Func("City/Cut");
                        end}; {type="Space"}; {type="Space"};
                        {type="Toggle", EN="ESP Gatas", EN2="Show Gatas' hitbox", TH1="ESP Gatas", TH2="มองเห็น Gatas", Path="City/ESP/Gatas", Callback=function(state)
                            B3C1Con.City.ESP.Gatas = state;
                            return Functions:B3C1ESP("City/Gatas", state);
                        end};
                        {type="Toggle", EN="ESP Dead Bodies", EN2="Show dead bodies", TH1="ESP ศพ", TH2="มองเห็นศพ", Path="City/ESP/Bodies", Callback=function(state)
                            B3C1Con.City.ESP.Bodies = state;
                            return Functions:B3C1ESP("City/Bodies", state);
                        end};
                    }};
                    {Tab={at="B3C1", Title="School", Icon="book-open", Path="B3C1"}, Data={
                        {type="Button", EN="Grab Medical Kit", EN2="Magically grab it.", TH1="หยิบกล่องปฐมพยาบาล", TH2="หยิบกล่องปฐมพยาบาลแบบงงๆ", Callback=function()
                            return Functions:B3C1Func("School/Med");
                        end};
                        {type="Button", EN="Heal Hideo", EN2="Magically teleport to him & heal.", TH1="รักษา Hideo", TH2="วาปไปแบบงงๆแล้วรักษา", Callback=function()
                            return Functions:B3C1Func("School/Heal");
                        end};
                        {type="Button", EN="Read Note", EN2="Teleport & read note.", TH1="อ่านโน๊ต", TH2="วาปไปอ่านโน๊ต", Callback=function()
                            return Functions:B3C1Func("School/Note");
                        end};
                        {type="Button", EN="Freeze Spiders", EN2="Permanently stop spiders from moving.", TH1="หยุดแมงมุม", TH2="ทำให้แมงมุมขยับไม่ได้แบบถาวร", Callback=function()
                            return Functions:B3C1Func("School/Freeze");
                        end};
                        {type="Button", EN="Kill Spiders", EN2="Teleport & kill all spiders", TH1="ฆ่าแมงมุม", TH2="วาปฆ่าแมงมุมทั้งหมด", Callback=function()
                            return Functions:B3C1Func("School/Spider");
                        end};
                        {type="Button", EN="Exit", EN2="Teleport to exit door.", TH1="ออก", TH2="วาปไปที่ประตูทางออก", Callback=function()
                            return Functions:B3C1Func("School/Exit");
                        end};
                        {type="Button", EN="Enter Forest", EN2="Teleport to the forest.", TH1="เข้าป่า", TH2="วาปเข้าป่า", Callback=function()
                            return Functions:B3C1Func("School/Forest");
                        end};
                        {type="Toggle", EN="ESP Akari", EN2="Show Akari's hitbox.", TH1="ESP Akari", TH2="มองเห็น Akari", Path="School/ESP/Akari", Callback=function(state)
                            B3C1Con.School.ESP.Akari = state;
                            return Functions:B3C1ESP("Akari", state);
                        end};
                    }};
                    {Tab={at="B3C1", Title="Forest", Icon="book-open", Path="B3C1"}, Data={
                        {type="Button", EN="Teleport To IJO Entrance", EN2="Teleport to the cave entrance for cutscene.", TH1="วาปไปที่ทางเข้าถ้ำ", TH2="วาปไปที่ทางเข้าถ้ำเพื่อเริ่มฉากต่อสู้", Callback=function()
                            return Functions:B3C1Func("Forest/Cave");
                        end};
                        {type="Button", EN="Auto Fix Generators", EN2="Teleport & fix generators.", TH1="ซ่อม Generator", TH2="วาปไปซ่อม Generator", Callback=function()
                            return Functions:B3C1Func("Forest/Generator");
                        end}; {type="Space"}; {type="Space"};
                        {type="Toggle", EN="ESP Mizuno", EN2="Show Mizuno's hitbox.", TH1="ESP Mizuno", TH2="มองเห็น Mizuno", Path="Forest/ESP/Mizuno", Callback=function(state)
                            B3C1Con.Forest.ESP.Mizuno = state;
                            return Functions:B3C1ESP("Mizuno", state);
                        end};
                    }};
                    {Tab={at="IJO", Title="IJO", Icon="book-open", Path="B3C1"}, Data={
                        {type="Button", EN="Grab Keycard", EN2="Teleport & collect keycard. <font color='rgb(255,0,0)'>You must open the gate or termianl & valve won't spawn.</font>", TH1="เก็บคีย์การ์ด", TH2="วาปไปเก็บคีย์การ์ด", Callback=function()
                            return Functions:B3C1Func("IJO/Keycard");
                        end};
                        {type="Button", EN="Enter Codes", EN2="Magically enter the code from anywhere.", TH1="ใส่รหัส", TH2="ใส่รหัสจากที่ไหนก็ได้แบบงงๆ", Callback=function()
                            return Functions:B3C1Func("IJO/PASS");
                        end};
                        {type="Button", EN="Place C4 (1)", EN2="Teleport & place C4.", TH1="วางระเบิด C4", TH2="วาปไปวางระเบิด C4", Callback=function()
                            return Functions:B3C1Func("IJO/C4");
                        end};
                        {type="Button", EN="Place C4 (2)", EN2="Teleport & place C4 at Netamo.", TH1="วางระเบิด C4 ที่ผี", TH2="วาปไปวางระเบิด C4 ที่ผี", Callback=function()
                            return Functions:B3C1Func("IJO/C4_2");
                        end}; {type="Space"};
                        {type="Button", EN="Trigger Leave Event", EN2="Teleport & attempt to exit IJO Place to continue the game.", TH1="วาปไปที่ทางออก IJO", TH2="วาปไปที่ทางออก IJO เพื่อให้เกมดำเนินต่อ", Callback=function()
                            return Functions:B3C1Func("IJO/Exit");
                        end};
                        {type="Button", EN="Activate Terminals", EN2="Teleport & activate terminals.", TH1="เปิด terminals", TH2="วาปไปเปิด terminals", Callback=function()
                            return Functions:B3C1Func("IJO/Terminal");
                        end};
                        {type="Button", EN="Turn Valves", EN2="Teleport & turn valves.", TH1="เปิดวาล์ว", TH2="วาปไปเปิดวาล์ว", Callback=function()
                            return Functions:B3C1Func("IJO/Valve");
                        end};
                        {type="Button", EN="Hit Skill Check", EN2="Enter the 'Lock Threat' minigame by yourself. Only press this button by the amout of circles on screen.", TH1="กดสกิล", TH2="กดเพื่อเริ่มมินิเกม 'Lock Threat' ด้วยตัวเองแล้วค่อยกดออโต้ตามจำนวนวงกลมบนหน้าจอ", Callback=function()
                            return Functions:B3C1Func("IJO/Threat");
                        end}; {type="Space"}; {type="Space"};
                        {type="Toggle", EN="ESP HogoGuntai", EN2="Show HogoGuntai's hitbox.", TH1="ESP HogoGuntai", TH2="มองเห็น HogoGuntai", Path="IJO/ESP/HogoGuntai", Callback=function(state)
                            B3C1Con.IJO.ESP.HogoGuntai = state;
                            return Functions:B3C1ESP("HogoGuntai", state);
                        end};
                    }};
                    {Tab={at="B3C1", Title="Water", Icon="book-open", Path="B3C1"}, Data={ {type="Space"},
                        {type="Button", EN="Complete Stair", EN2="Teleport to the end of stair.", TH1="จบด่านบันได", TH2="วาปไปข้างล่างบันได", Callback=function()
                            return Functions:B3C1Func("Water/Stair");
                        end}; {type="Space"};
                        {type="Button", EN="Main Switch", EN2="Teleport & interact with the main switch.", TH1="เปิดสวิตช์หลัก", TH2="วาปไปเปิดสวิตช์หลัก", Callback=function()
                            return Functions:B3C1Func("Water/Main");
                        end};
                        {type="Button", EN="Auto Wire", EN2="Magically interact with the all boxes.", TH1="เสียบสายไฟอัตโนมัติ", TH2="วาปไปเสียบสายไฟอัตโนมัติ", Callback=function()
                            return Functions:B3C1Func("Water/Wire");
                        end}; {type="Space"}; {type="Space"};
                        {type="Toggle", EN="ESP Baigai", EN2="Show Baigai's hitbox.", TH1="ESP Baigai", TH2="มองเห็น Baigai", Path="Water/ESP/Baigai", Callback=function(state)
                            B3C1Con.Water.ESP.Baigai = state;
                            return Functions:B3C1ESP("Baigai", state);
                        end};
                    }};
                };
            });
        };

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
            Tabs.B3C1 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB3C1);
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

                -- The dispatcher is a core service. Stop cancels action tasks,
                -- while this loop remains available for later toggle changes.
                task.spawn(function()
                    while not CoreDestroyed do
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

return Runtime.start({Scope="Book3",Modules=Modules,UIUrl=E.MimicCCUIUrl or "https://raw.githubusercontent.com/eystearisdown/wyattrz/main/ui/CCUI.lua"})

]====]
local E = (getgenv and getgenv()) or _G
E.__MimicSlateSources = E.__MimicSlateSources or {}
E.__MimicSlateSources["Book3"] = PAYLOAD
local run, compileError = loadstring(PAYLOAD, "MimicSlate/Book3")
if not run then error(compileError, 0) end
return run()
