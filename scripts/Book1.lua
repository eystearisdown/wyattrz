-- Mimic Slate 1.0.0 / Book1
-- Loads the shared Slate UI from your GitHub repository.
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

Modules.Legacy = function(GG)
-- Slate / Book1: extracted from user-supplied TheMimicV3.D11.
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

local ScriptData = {
    Sections = {
        B1C1 = {
            [1] = (PlaceId == 6296321810 or PlaceId == 6479231833) and { i = "Map1", dat = {
                [1] = { i = "Spawn", C = CFr(269.3022155761719, 3, -1.3705496788024902) };
                [2] = { i = "Jigoku", C = CFr(316.1304626464844, 3.2333202362060547, 316.0523681640625) };
                [3] = { i = "Key 1", C = CFr(670.4268798828125, 3.049999713897705, 484.9584655761719) };
                [4] = { i = "Key 2", C = CFr(860.452880859375, 3.1949996948242188, 219.03762817382812) };
                [5] = { i = "Entrance Maze", C = CFr(3164.7529296875, 37.40338134765625, -1586.5648193359375) };
                [6] = { i = "Key 3", C = CFr(3317.523681640625, 37.64610290527344, -1764.0106201171875) };
                [7] = { i = "Exit Maze", C = CFr(3416.580322265625, 37.646121978759766, -1538.938720703125) };
            }} or {};
            [2] = (PlaceId == 6301638949 or PlaceId == 6480994221) and { i = "Map2", dat = {
                [1] = { i = "Spawn", C = CFr(284.4999084472656, 73.06249237060547, 101.47504425048828) };
                [2] = { i = "Cave House", C = CFr(32.434173583984375, 94.35484313964844, -1233.511962890625) };
                [3] = { i = "Entrance Main House", C = CFr(-112.36238861083984, 91.99998474121094, -2021.73974609375) };
                [4] = { i = "Spawn Hotel", C = CFr(-268.7034606933594, 91.63571166992188, -3243.083251953125) };
                [5] = { i = "Spawn Hotel 2nd Floor", C = CFr(-248.93421936035156, 128.62155151367188, -2547.898193359375) };
                [6] = { i = "Spawn Hotel 3rd Floor", C = CFr(237.497314453125, 199.52268981933594, -2568.7646484375) };
                [7] = { i = "Exit Hotel", C = CFr(1274.949951171875, 199.5399932861328, -2537.929931640625) };
                [8] = { i = "Spawn Outside Hotel", C = CFr(2139.439453125, 257.1267395019531, -2504.615966796875) };
                [9] = { i = "Chapter 2 Entrance Gate", C = CFr(2138.8232421875, 257.12353515625, -2742.88427734375) };
            }} or {};
        };
        B1C2 = {
            [1] = { i = "Map1", dat = {
                [1] = { i = "Spawn", C = CFr(31.30192756652832, 14.765870094299316, -50.99848937988281) };
                [2] = { i = "Key 1", C = CFr(146.7581329345703, 26.52265739440918, -429.7537841796875) };
                [3] = { i = "Lever Room", C = CFr(136.9575653076172, 14.773530006408691, -340.3115234375) };
                [4] = { i = "Exit Hallway", C = CFr(196.88290405273438, 26.39544677734375, -703.8648071289062) };
                [5] = { i = "Exit Samurai", C = CFr(234.37767028808594, 51.09593200683594, -1297.229736328125) };
                [6] = { i = "Butterfly 1", C = CFr(234.37767028808594, 51.09593200683594, -1297.229736328125) };
                [7] = { i = "Butterfly 2", C = CFr(220.61093139648438, 52.18296813964844, -1644.1612548828125) };
            }};
            [2] = { i = "Map2", dat = {
                [1] = { i = "Spawn", C = CFr(400.1822814941406, -47.07728958129883, 909.1865234375) };
                [2] = { i = "Butterfly Outside", C = CFr(431.97601318359375, 60.81093215942383, 380.8719787597656) };
                [3] = { i = "Key", C = CFr(161.5194091796875, 101.88359069824219, -562.4013671875) };
                [4] = { i = "Butterfly Inside", C = CFr(258.27105712890625, 94.61199188232422, -848.0752563476562) };
                [5] = { i = "Exit Door", C = CFr(235.35060119628906, 101.9432373046875, -551.535888671875) };
            }};
            [3] = { i = "Map3", dat = {
                [1] = { i = "Spawn", C = CFr(-96.32198333740234, 75.3413314819336, -22.335594177246094) };
                [2] = { i = "Butterfly", C = CFr(671.8909912109375, 78.17596435546875, -115.32154083251953) };
                [3] = { i = "Exit", C = CFr(827.9335327148438, 75.3413314819336, -352.0482482910156) };
            }};
        };
        B1C3 = {
            [1] = { i = "Map1", dat = {
                [1] = { i = "Spawn", C = CFr(1112.6671142578125, 83.19374084472656, -359.1717834472656) };
                [2] = { i = "Cave Spawn", C = CFr(1899.2449951171875, 4.8473639488220215, 281.3607177734375) };
                [3] = { i = "Kaito Entrance", C = CFr(2047.682861328125, -0.4862976670265198, 561.9852294921875) };
                [4] = { i = "Kaito Exit", C = CFr(2314.2900390625, 5.150242328643799, 818.3004760742188) };
                [5] = { i = "Hand Entrance", C = CFr(2408.81396484375, -23.031116485595703, 1459.683837890625) };
                [6] = { i = "Hand Exit", C = CFr(2413.467529296875, -23.03111457824707, 1816.749267578125) };
            }};
            [2] = { i = "Map2", dat = {
                [1] = { i = "Spawn", C = CFr(39.31187057495117, 36.4764518737793, 84.27843475341797) };
                [2] = { i = "Blade", C = CFr(79.64765930175781, 36.359718322753906, 87.4922866821289) };
                [3] = { i = "Butterfly", C = CFr(128.96363830566406, 36.35921859741211, 98.9471435546875) };
                [4] = { i = "Rose", C = CFr(322.61297607421875, 37.51033401489258, 78.7746810913086) };
                [5] = { i = "Bell Safe Spot", C = CFr(210.59703063964844, 31.717370986938477, 407.951416015625) };
            }};
        };
    };
};
local Config = GG.Configs or {};

Config.Client = Config.Client or {};
Config.Client.Client = Config.Client.Client or {};
Config.Yen = Config.Yen or {};
Config.B1C4 = Config.B1C4 or {};
Config.B1C4.Map4 = Config.B1C4.Map4 or {};

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
        local B1C4Con           = Config.B1C4;
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

        local AllowedChapters = {["B1C1"] = true; ["B1C2"] = true; ["B1C3"] = true; ["B1C4"] = true};
        if not Chapter or not AllowedChapters[Chapter] then
            return function()
                warn("[Slate / Book1] This place is not supported by this package: " .. tostring(PlaceId));
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

        Functions.AutoCompleteBook1 = function()
            if PlaceId == 6296321810 or PlaceId == 6479231833 then
                return Tp(HumRSelf, CFr(3507, 37.65, -1539.45));
            elseif PlaceId == 6301638949 or PlaceId == 6480994221 then
                return Tp(HumRSelf, CFr(1274.95, 199.54, -2537.93));
            end;
            if PlaceId == 6373539583 or PlaceId == 6485055338 then
                return Tp(HumRSelf, CFr(64.88, 55.28, -1590));
            elseif PlaceId == 6406571212 or PlaceId == 6485055836 then
                return Tp(HumRSelf, CFr(235.17, 101.94, -590));
            elseif PlaceId == 6425178683 or PlaceId == 6485056556 then
                return Tp(HumRSelf, CFr(829.97, 72.49, -353.46));
            end;
            if PlaceId == 6472459099 or PlaceId == 6688734180 then
                return Tp(HumRSelf, CFr(2411.93, -23.03, 2300));
            elseif  PlaceId == 6682163754 or PlaceId == 6688734313 then
                return Tp(HumRSelf, CFr(245.69, 31.72, 450));
            elseif  PlaceId == 6682164423 or PlaceId == 6688734395 then
                return Tp(HumRSelf, CFr(-651, 648.99, -1014.35), 5), Tp(HumRSelf, CFr(-644.07, 947.82, -1490));
            end;
            if PlaceId == 7251865082 or PlaceId == 7265396387 then
                return Tp(HumRSelf, CFr(91, -48.35, -1416.24));
            elseif PlaceId == 7251866503 or PlaceId == 7265396805 then
                local CHs = GetChildren(W.Butterflies); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        Tp(HumRSelf, v.CFrame, 0.3);
                        fireproximityprompt(v.ProximityPrompt, 1);
                    end;
                end;
            elseif PlaceId == 7251867155 or PlaceId == 7265397072 then
                local CHs = GetChildren(W.GameInfo.PuzzleItems); for i=1, #CHs do
                    local v=CHs[i]; if v.Parent and v.ProximityPrompt.Enabled then
                        Tp(HumRSelf, v.CFrame, 0.3); fireproximityprompt(v.ProximityPrompt);
                    end;
                end; Tp(HumRSelf, CFr(688.41, 28.37, 2251.57), 0.3);
                local Burner = W.Well.Burner; for i=1, 6 do
                    fireproximityprompt(Burner.ProximityPrompt);
                end;
            end;
        end;

        Functions.ESPMonsterBook1 = function(state)
            if not state then return ESPF.Visible("Monster", false); else
                if GameAI then
                    local CHs = GetChildren(GameAI); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            ESPF.ESP("Monster", v, {
                                Color = RED;
                                Size = VEC10;
                                Text = v.Name;
                            });
                        end;
                    end;
                end; if GameAI2 then
                    local CHs = GetChildren(GameAI2); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                            ESPF.ESP("Monster", v, {
                                Color = RED;
                                Size = VEC10;
                                Text = v.Name;
                            });
                        end;
                    end;
                end; if Chapter == "B1C3" then
                    local Omu = FindFirstChild(W, "omukadeMAIN");
                    local DMGP = Omu and FindFirstChild(Omu, "damagepart");
                    if DMGP then DMGP.Transparency = 0; end;
                    if Omu then ESPF.ESP("Monster", DMGP, {
                        Color = RED;
                        Size = VEC10;
                        Text = "Train Chu Chu LOL";
                    }); end;
                end; ESPF.Visible("Monster", true,  true);
            end; return;
        end;

        Functions.ESPItemsBook1 = function(state)
            if not state then return ESPF.Visible("Items", false); else
                local Givers = FindFirstChild(W, "Givers");
                if Givers then
                    local CHs = GetChildren(Givers); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                            ESPF.ESP("Items", v, {
                                Color = WHITE;
                                Size = VEC2;
                                Text = v.Name;
                            });
                        end;
                    end;
                end; if Chapter == "B1C2" or PlaceId == 6682164423 or PlaceId == 6688734395 then
                    local CHs = GetChildren(W); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                            if v.Name ~= "Key1" and v.Name ~= "Butterfly" and not FindFirstChild(v, "ProxPart") then continue; end;
                            ESPF.ESP("Items", v, {
                                Color = WHITE;
                                Size = VEC2;
                                Text = v.Name;
                            });
                        end;
                    end;
                elseif PlaceId == 6472459099 or PlaceId == 6688734180 then
                    local CHs = GetChildren(W); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            if v.Name ~= "Butterfly" and v.Name ~= "Crowbar" and v.Name ~= "Blade" then continue; end;
                            ESPF.ESP("Items", v, {
                                Color = WHITE;
                                Size = VEC2;
                                Text = v.Name;
                            });
                        end;
                    end; ESPF.ESP("Items", FindFirstChild(W.OfferItem, "Sword"), {
                        Color = GREEN;
                        Size = VEC2;
                        Text = "Place sword here";
                    });
                elseif PlaceId == 6682163754 or PlaceId == 6688734313 then
                    local CHs = GetChildren(W.BellFolder); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local Prox = FindFirstChild(v, "ProximityPrompt");
                            if not Prox then continue; end;
                            local ESPObject = ESPF.ESP("Items", v, {
                                Color = if Prox.Enabled then YELLOW else GREEN;
                                Size = VEC2;
                                Text = v.Name;
                            }); TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                ESPObject.UpdateColor(GREEN);
                            end);
                        end;
                    end;
                elseif PlaceId == 7251865082 or PlaceId == 7265396387 then
                    local CHs = GetChildren(W); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local Prox = FindFirstChild(v, "ProxPart");
                            if Prox then 
                                ESPF.ESP("Items", Prox, {
                                    Color = WHITE;
                                    Size = VEC2;
                                    Text = Prox.ProximityPrompt.ObjectText;
                                });
                            elseif FindFirstChild(v, "Model") and FindFirstChild(v.Model, "Model") then
                                local Prox = FindFirstChild(v.Model.Model, "ProxPart", true);
                                if not Prox then continue; end;
                                ESPF.ESP("Items", Prox, {
                                    Color = WHITE;
                                    Size = VEC2;
                                    Text = Prox.ProximityPrompt.ObjectText;
                                });
                            end;
                        end;
                    end;
                elseif PlaceId == 7251866503 or PlaceId == 7265396805 then
                    local CHs = GetChildren(W.Butterflies); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local ESPObject = ESPF.ESP("Items", v, {
                                Color = WHITE;
                                Size = VEC2;
                                Text = v.Name;
                            });
                        end;
                    end;
                elseif PlaceId == 7251867155 or PlaceId == 7265397072 then
                    local CHs, CHs2 = GetChildren(W), GetChildren(W.GameInfo.PuzzleItems);
                    for i=1, #CHs do
                        local v=CHs[i]; if v.Parent and v.ClassName == "Model" then
                            if v.Name == "Model" and FindFirstChild(v, "Spirit") then
                                ESPF.ESP("Items", v.Spirit.ProxPart, {
                                    Color = WHITE;
                                    Size = VEC2;
                                    Text = "Butterfly";
                                });
                            elseif v.Name == "Key" then
                                ESPF.ESP("Items", v, {
                                    Color = WHITE;
                                    Size = VEC2;
                                    Text = v.Name;
                                });
                            end;
                        end;
                    end; for i=1, #CHs2 do
                        local v=CHs2[i]; if v.Parent then
                            local Prox = FindFirstChild(v, "ProximityPrompt");
                            local ESPObject = ESPF.ESP("Items", v, {
                                Color = if Prox.Enabled then YELLOW else GREEN;
                                Size = VEC2;
                                Text = "Cursed Item";
                            }); TrackSignal(PropChangeSignal(Prox, "Enabled"), function()
                                ESPObject.UpdateColor(if Prox.Enabled then YELLOW else GREEN);
                            end);
                        end;
                    end;
                elseif PlaceId == 7251867574 or PlaceId == 7265397848 then
                    local CHs = GetChildren(W.GameHearts); for i=1, #CHs do
                        local v=CHs[i]; if v.Parent then
                            local HPs = FindFirstChild(v, "Health");
                            if not HPs then continue; end;
                            local ESPObject = ESPF.ESP("Items", v, {
                                Color = if HPs.Value > 0 then YELLOW else GREEN;
                                Size = VEC2;
                                Text = v.Name;
                            }); TrackSignal(PropChangeSignal(HPs, "Value"), function()
                                ESPObject.UpdateColor(if HPs.Value > 0 then YELLOW else GREEN);
                            end);
                        end;
                    end;
                end;
            end; ESPF.Visible("Items", true, true);
        end;

        ScriptData.AutoData = {
            PackB1C1 = (Chapter == "B1C1" and {
                Tabs={
                    {Tab={at="B1C1", Title="Main", Icon="book-open", Path="B1C1"}, Data={
                        {type="Button", EN="Auto Complete Game", EN2="Teleport to the end of the game.", TH1="ออโต้จบเกม", TH2="วาปไปที่ด่านสุดท้ายของเกม", Callback=Functions.AutoCompleteBook1}; {type="Space"},
                        {type="Toggle", EN="ESP Items", EN2="Show item's box & name", Path="ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                    }};
                };
            });

            PackB1C2 = (Chapter == "B1C2" and {
                Tabs={
                    {Tab={at="B1C2", Title="Main", Icon="book-open", Path="B1C2"}, Data={
                        {type="Button", EN="Auto Complete Game", EN2="Teleport to the end of the game.", TH1="ออโต้จบเกม", TH2="วาปไปที่ด่านสุดท้ายของเกม", Callback=Functions.AutoCompleteBook1}; {type="Space"},
                        {type="Toggle", EN="ESP Items", EN2="Show item's box & name", Path="ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                    }};
                };
            });

            PackB1C3 = (Chapter == "B1C3" and {
                Tabs={
                    {Tab={at="B1C3", Title="Main", Icon="book-open", Path="B1C3"}, Data={
                        {type="Button", EN="Auto Complete Game", EN2="Teleport to the end of the game.", TH1="ออโต้จบเกม", TH2="วาปไปที่ด่านสุดท้ายของเกม", Callback=Functions.AutoCompleteBook1}; {type="Space"},
                        {type="Toggle", EN="ESP Items", EN2="Show item's box & name", Path="ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                    }};
                };
            });

            PackB1C4 = (Chapter == "B1C4" and {
                Tabs= ((PlaceId == 7251865082 or PlaceId == 7265396387) and {
                    {Tab={at="B1C4", Title="Map 1", Icon="book-open", Path="B1C4"}, Data={
                        {type="Button", EN="Auto Complete Game", EN2="Teleport to the end of the game.", TH1="ออโต้จบเกม", TH2="วาปไปที่ด่านสุดท้ายของเกม", Callback=Functions.AutoCompleteBook1};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="Map1/ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                        {type="Toggle", EN="ESP Items", EN2="Show item's box & name", Path="Map1/ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1};
                    }};
                }) or ((PlaceId == 7251866503 or PlaceId == 7265396805) and {
                    {Tab={at="B1C4", Title="Map 2", Icon="book-open", Path="B1C4"}, Data={
                        {type="Button", EN="Auto Complete Game", EN2="Teleport to the end of the game.", TH1="ออโต้จบเกม", TH2="วาปไปที่ด่านสุดท้ายของเกม", Callback=Functions.AutoCompleteBook1};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="Map2/ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                        {type="Toggle", EN="ESP Butterflies", EN2="Show item's box & name", Path="Map2/ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1};
                    }};
                }) or ((PlaceId == 7251867155 or PlaceId == 7265397072) and {
                    {Tab={at="B1C4", Title="Map 3", Icon="book-open", Path="B1C4"}, Data={
                        {type="Button", EN="Auto Complete Game", EN2="Teleport to the end of the game.", TH1="ออโต้จบเกม", TH2="วาปไปที่ด่านสุดท้ายของเกม", Callback=Functions.AutoCompleteBook1};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="Map3/ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                        {type="Toggle", EN="ESP Items", EN2="Show item's box & name", Path="Map3/ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1};
                    }};
                }) or ((PlaceId == 7251867574 or PlaceId == 7265397848) and {
                    {Tab={at="B1C4", Title="Map 4", Icon="book-open", Path="B1C4"}, Data={
                        {type="Toggle", EN="Auto Kill Sama", EN2="Automatically destroy hearts.", TH1="ออโต้ทำลายหัวใจ", TH2="ทำลายหัวใจผี", Path="Map4/AutoKillSama"};
                        {type="Toggle", EN="Auto Kill Saigomo", EN2="Automatically kill saigomo.", TH1="ออโต้ฆ่า Saigomo", TH2="ออโต้ฆ่าผี", Path="Map4/AutoKillSaigomo"};
                        {type="Toggle", EN="ESP Monsters", EN2="Show monster's hitbox & name", Path="Map4/ESP/Monsters", TH1="ESP ผี", TH2="มองเห็นผี", Callback=Functions.ESPMonsterBook1};
                        {type="Toggle", EN="ESP Hearts", EN2="Show item's box & name", Path="Map4/ESP/Items", TH1="ESP ไอเทม", TH2="มองเห็นไอเทม", Callback=Functions.ESPItemsBook1}; {type="Space"};
                    }};
                });
            });
        };

        CoruTask.New("B1C4@Sama", function()
            if PlaceId ~= 7251867574 and PlaceId ~= 7265397848 then
                return;
            end;
            
            local SAFESAMA = CFr(2823, 155, 2490); while true do
                local CHs=GetChildren(W.GameHearts); for i=1, #CHs do
                    if not B1C4Con.Map4.AutoKillSama or CoreDestroyed then
                        return CoruTask.Close("B1C4@Sama");
                    end; local v=CHs[i]; if v.Parent then
                        local Root = FindFirstChild(v, "Root");
                        if not Root then continue; end;
                        local CFH = Root.CFrame;
                        while not FindFirstChild(v, "Destroyed") and B1C4Con.Map4.AutoKillSama and not CoreDestroyed do
                            while Cam.FieldOfView > 71 do
                                Tp(HumRSelf, SAFESAMA); twait(0.03);
                            end;

                            while selc.Parent and Functions:ToolNow("Katana") and Cam.FieldOfView < 72 and not FindFirstChild(v, "Destroyed") do
                                Tp(HumRSelf, CFH); Functions:ToolActive("Katana"); twait(0.1);
                            end; twait(0.1);
                        end;
                    end;
                end; twait(0.1);
            end;
        end);

        CoruTask.New("B1C4@Saigomo", function()
            if PlaceId ~= 7251867574 and PlaceId ~= 7265397848 then
                return;
            end;
            
            local SaiConnection = nil;
            local SAFESAIGOMO = CFr(2718.18, 266.32, 2537.03);
            local BossBattle = WaitForChild(W, "BossBattle", 30);
            local Saigomo = WaitForChild(BossBattle, "Saigomo", 30);
            local HumRSai = WaitForChild(Saigomo, "HumanoidRootPart", 30);
            local Sound = WaitForChild(HumRSai, "roar", 30);

            if Sound and Sound.Parent then
                local CHs = {
                    WaitForChild(Saigomo, "SpiderHitbox", 30),
                    WaitForChild(Saigomo, "hitbox1", 30),
                    WaitForChild(Saigomo, "hitbox2", 30),
                }; for i=1, #CHs do
                    local v=CHs[i]; if v.Parent then
                        local Touch = WaitForChild(v, "TouchInterest", 30);
                        if Touch then Touch:Destroy(); end;
                    end;
                end; Saigomo.SpiderHitbox.Size = Vec3(50, 50, 50);
            end;

            while true do
                if not B1C4Con.Map4.AutoKillSaigomo or CoreDestroyed then
                    if SaiConnection then
                        SaiConnection:Disconnect();
                        SaiConnection = nil;
                    end; return CoruTask.Close("B1C4@Saigomo");
                end; if not SaiConnection then
                    SaiConnection = TrackSignal(H.Heartbeat, function()
                        if not selc.Parent or not HumRSelf.Parent then return; end;
                        if not Sound.Parent or not HumRSai.Parent then return; end;

                        if Sound.IsPlaying then
                            Tp(HumRSelf, SAFESAIGOMO);
                        else
                            if Functions:ToolNow("Katana") then
                                Tp(HumRSelf, HumRSai.CFrame + HumRSai.CFrame.RightVector*-20);
                                Functions:ToolActive("Katana");
                            end;
                        end;
                    end);
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
            Tabs.B1C1 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB1C1);
            Tabs.B1C2 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB1C2);
            Tabs.B1C3 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB1C3);
            Tabs.B1C4 = Windy:CreateDynamic(Window, Tabs, ScriptData.AutoData.PackB1C4);
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
                        if Chapter == "B1C4" then
                            if B1C4Con.Map4.AutoKillSama then CoruTask.Handle("B1C4@Sama"); end;
                            if B1C4Con.Map4.AutoKillSaigomo then CoruTask.Handle("B1C4@Saigomo"); end;
                        end;
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
-- Mimic Slate runtime. UI and all game adapters are injected by the release builder.
local Runtime = {}
local VERSION = "1.0.0"

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
            if not modules.SlateUI then error("Cannot load Slate UI: " .. ctx.UIError, 0) end
        end
        assert(modules.SlateUI, "Slate UI is unavailable")
        ctx.UISource = "Bundled"
        return modules.SlateUI()
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
        params.Title = "MIMIC"
        params.Subtitle = scope == "Gamemodes" and "GAMEMODES" or (scope:gsub("Book", "BOOK "))
        params.Folder = "MimicSlate/" .. scope
        params.Size = UDim2.fromOffset(680, 490)
        params.SideBarWidth = 152
        params.Transparent = false
        params.Acrylic = false
        params.ToggleKey = Enum.KeyCode.RightControl
        local window = ctx.UI:CreateWindow(params)
        ctx.Window = window
        window:OnDestroy(ctx.Destroy)
        return window
    end

    local gg = {
        Configs = ctx.Config, ScriptCache = {userIdentify = "Mimic Slate"}, QUEUE_INFO = ctx.QueueInfo,
        LoaderSettings = {TheMimicLoader = {Load_Sections = true}, UIKeybind = "RightControl", AllowClientTab = false, AllowAcrylicBlur = false, ESPMode = "Slate"},
        LoadingSignal = signal(ctx), ESPObjects = {}, RegisterCleanup = ctx.addCleanup,
        Title = "MIMIC / " .. scope, LowerC = hookfunction or hookfunc,
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
        tab:Paragraph({Title = "Mimic Slate", Desc = "A shared interface for every chapter. Open Chapter for the current area, Visuals for markers, and Player for movement."})
        if tab.Status then
            ctx.OverviewStatus = tab:Status({Title = "Session", Icon = "activity", State = "active", Fields = {Package = scope, Chapter = chapter or "Lobby / unknown", Player = player.DisplayName, Interface = ctx.UISource}})
        else
            tab:Paragraph({Title = scope .. " / " .. (chapter or "Lobby"), Desc = player.DisplayName})
        end
        if ctx.UIError then tab:Paragraph({Title = "Using included interface", Desc = "The remote UI could not be downloaded. The included Slate interface is active."}) end
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
        tab:Slider({Title = "Interface scale", Desc = "Adjusts the menu size for your screen.", Value = {Min = 0.65, Max = 1.25, Default = tonumber(ctx.Config.Interface.Scale) or 1}, Step = 0.05, Callback = function(value)
            ctx.Config.Interface.Scale = value; window:SetUIScale(value); ctx.Save()
        end})
        tab:Keybind({Title = "Menu key", Value = Enum.KeyCode.RightControl, ChangedCallback = function(key) window:SetToggleKey(key) end})
        tab:Slider({Title = "Travel speed", Desc = "Used by chapter routes that do not specify a duration.", Value = {Min = 10, Max = 200, Default = tonumber(ctx.Config.Interface.TravelSpeed) or 85}, Step = 5, Callback = function(value) ctx.Config.Interface.TravelSpeed = value; ctx.Save() end})
        tab:Section({Title = "Configuration"})
        tab:Button({Title = "Save preferences", Icon = "save", Callback = function()
            ctx.Notify(saveNow() and "Preferences saved" or "Session preferences", type(writefile) == "function" and "Saved on this device." or "File storage is unavailable; preferences last for this session.")
        end})
        tab:Paragraph({Title = "Mimic Slate " .. VERSION, Desc = "UI: Slate · Package: " .. scope .. "\nUse the floating M button to open the menu on mobile."})
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
        window:SetUIScale(tonumber(ctx.Config.Interface.Scale) or 1)
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

return Runtime.start({Scope="Book1",Modules=Modules,UIUrl=E.MimicSlateUIUrl or "https://raw.githubusercontent.com/eystearisdown/wyattrz/main/ui/SlateUI.lua"})

]====]
local E = (getgenv and getgenv()) or _G
E.__MimicSlateSources = E.__MimicSlateSources or {}
E.__MimicSlateSources["Book1"] = PAYLOAD
local run, compileError = loadstring(PAYLOAD, "MimicSlate/Book1")
if not run then error(compileError, 0) end
return run()
