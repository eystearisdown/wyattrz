-- CC Camera · B3C1 · original cc UI and camera target selection

pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, name in ipairs({"Nevoirs_Rage_UI", "Nevoirs_Mimic_UI", "MiniIY_UI", "Nevoirs_LeftToggle_UI", "FiHon_CompactNotifications"}) do
            local old = pg:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end
end)
pcall(function()
    if type(_G.__NevoirsB3C1Cleanup) == "function" then
        _G.__NevoirsB3C1Cleanup()
    end
end)
_G.NevoirsMimic_Loaded = true

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local LocalPlayer      = Players.LocalPlayer
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local WindUI -- one shared UI binding for all feature closures

-- Avatar/icon mặc định theo yêu cầu.
local NEVOIRS_AVATAR_ID = "rbxassetid://98606201759935"
local NEVOIRS_WINDOW_ICON = NEVOIRS_AVATAR_ID
local NEVOIRS_BRAND_TEXT = "N"
local NEVOIRS_BRAND_COLOR = Color3.fromRGB(94, 170, 255)
local NEVOIRS_UI_ICON = NEVOIRS_AVATAR_ID
local CAMERAREPLICA = nil -- silent camera replica cho Auto Nearby Kill; không xoay camera thật

pcall(function()
    if type(_G.__NevoirsLastNoclipCleanup) == "function" then
        _G.__NevoirsLastNoclipCleanup()
    end
    if type(_G.__NevoirsLastMoonwalkCleanup) == "function" then
        _G.__NevoirsLastMoonwalkCleanup()
    end
end)

-- ── States ────────────────────────────────────────────────────────────────────
local States = {
    TPWalk       = false,
    Noclip       = false,
    Moonwalk     = false,
    InfiniteJump  = false,
    ESPPlayer    = false,
    ESPMonster   = false,
    ESPTaskMaster = false,
    ESPTaskBody      = false,
    ESPTaskSpider    = false,
    ESPTaskGenerator = false,
    ESPTaskTerminal  = false,
    ESPTaskValve     = false,
    ESPTaskWire      = false,
    ESPTaskDirector  = false,
    ESPTaskExtra     = false,
    Fullbright   = false,
    AutoNearbyKill = false,
    AutoYenESP = false,
    AutoYenCollect = false,
    InstantInteract = false,
}

-- ── Persistent settings (executor workspace) ────────────────────────────────
local SETTINGS_FILE = "Nevoirs_B3C1_Settings.json"

local DEFAULT_SETTINGS = {
    TPWalkSpeed = 0,
    VFlySpeed = 0,

    AutoKillFireDelay = 0.03,
    AutoKillRangeGata = 70,
    AutoKillRangeHogo = 25,
    AutoKillRangeFleshBlock = 20,
    AutoKillRangeSpider = 20,
}

local SavedSettings = {}

local function __readSettings()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    local ok, exists = pcall(isfile, SETTINGS_FILE)
    if not ok or not exists then return end
    local okRead, raw = pcall(readfile, SETTINGS_FILE)
    if not okRead or type(raw) ~= "string" or raw == "" then return end
    local okDecode, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if okDecode and type(data) == "table" then
        SavedSettings = data
    end
end

local function __writeSettings()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode(SavedSettings))
    end)
end

local function getSetting(key, defaultValue)
    if SavedSettings[key] ~= nil then
        local n = tonumber(SavedSettings[key])
        if n ~= nil then return n end
        return SavedSettings[key]
    end
    return defaultValue
end

local function setSetting(key, value)
    SavedSettings[key] = value
    __writeSettings()
end

local function getNumberSetting(key, defaultValue, minValue, maxValue)
    local n = tonumber(getSetting(key, defaultValue))
    if n == nil or n ~= n or n == math.huge or n == -math.huge then
        n = defaultValue
    end
    if minValue ~= nil and n < minValue then n = minValue end
    if maxValue ~= nil and n > maxValue then n = maxValue end
    return n
end

__readSettings()

-- Migration nhẹ cho bản này: delay mặc định 0.03, Hogo 25, FleshBlock 20, Spider 10.
-- Không overwrite nếu bạn đã tự nhập giá trị khác các mặc định cũ.
if SavedSettings.__RangeSchema ~= "delay003_hogo25_flesh20_spider10_grunts_v4" then
    local oldDelay = tonumber(SavedSettings.AutoKillFireDelay)
    if oldDelay == nil or oldDelay == 0.12 then
        SavedSettings.AutoKillFireDelay = DEFAULT_SETTINGS.AutoKillFireDelay
    end

    local oldHogo = tonumber(SavedSettings.AutoKillRangeHogo)
    if oldHogo == nil or oldHogo == 70 then
        SavedSettings.AutoKillRangeHogo = DEFAULT_SETTINGS.AutoKillRangeHogo
    end

    local oldFlesh = tonumber(SavedSettings.AutoKillRangeFleshBlock)
    if oldFlesh == nil or oldFlesh == 70 or oldFlesh == 10 then
        SavedSettings.AutoKillRangeFleshBlock = DEFAULT_SETTINGS.AutoKillRangeFleshBlock
    end

    local oldSpider = tonumber(SavedSettings.AutoKillRangeSpider)
    if oldSpider == nil or oldSpider == 38 or oldSpider == 20 then
        SavedSettings.AutoKillRangeSpider = DEFAULT_SETTINGS.AutoKillRangeSpider
    end

    SavedSettings.__RangeSchema = "delay003_hogo25_flesh20_spider10_grunts_v4"
    __writeSettings()
end

local TPWalkSpeed = getNumberSetting("TPWalkSpeed", DEFAULT_SETTINGS.TPWalkSpeed, 0, 9999)


local OrigLighting = {
    Brightness     = Lighting.Brightness,
    GlobalShadows  = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient        = Lighting.Ambient,
    FogEnd         = Lighting.FogEnd,
}

local MonsterAllows = {
    Gata = true,
    Boss = true,
}

local TaskAllows = {
    Body = true,
    Spider = true,
    Generator = true,
    Terminal = true,
    Valve = true,
    Wire = true,
    Director = true,
    BoulderSeal = true,
    Cutter = true,
    Bandage = true,
    Diary = true,
    EntranceCard = true,
    C4 = true,
    PowerSwitch = true,
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "Nevoirs_Rage_UI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

local C_DIM = Color3.fromRGB(120, 120, 145)

-- ── Misc helpers ──────────────────────────────────────────────────────────────
local function getChar()     return LocalPlayer.Character end
local function getHRP(char)  return char and char:FindFirstChild("HumanoidRootPart") end

local function safeFolder(path)
    local cur = Workspace
    for _, name in ipairs(path) do
        cur = cur and cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

local function validPart(p)
    return p and p.Parent and p:IsDescendantOf(game) and p:IsA("BasePart")
end

local function validAdornee(obj)
    return obj and obj.Parent and obj:IsDescendantOf(game) and (obj:IsA("BasePart") or obj:IsA("Model"))
end

local function rootOf(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("Head")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("PromptPart")
        or obj:FindFirstChildWhichIsA("BasePart")
end

local function makeUniqueKey(base, inst)
    local id
    pcall(function()
        id = inst and inst:GetDebugId()
    end)
    if not id then
        pcall(function()
            id = inst and inst:GetFullName()
        end)
    end
    id = id or tostring(inst)
    return base .. "_" .. tostring(id)
end



-- ══════════════════════════════════════════════════════════════════════════════
-- ESP CORE
-- ══════════════════════════════════════════════════════════════════════════════
local espPool  = { Player = {}, Monster = {}, Task = {}, Yen = {} }
local pollConns = { Player = nil, Monster = nil, Task = nil, Yen = nil }

local function destroyEntry(e)
    if not e then return end
    pcall(function() if e.distConn then e.distConn:Disconnect() end end)
    pcall(function() if e.hl and e.hl.Parent then e.hl:Destroy() end end)
    pcall(function() if e.bb and e.bb.Parent then e.bb:Destroy() end end)
end

local function clearPool(cat)
    for k, e in pairs(espPool[cat]) do
        destroyEntry(e)
        espPool[cat][k] = nil
    end
end

local function stopPoll(cat)
    if pollConns[cat] then
        pollConns[cat]:Disconnect()
        pollConns[cat] = nil
    end
end

local function createESPEntry(cat, key, adornee, anchor, label, color)
    if not validAdornee(adornee) or not validPart(anchor) then return end
    if espPool[cat][key] then return end

    local ok1, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name = "MIIY_HL"
        h.Adornee = adornee
        h.FillColor = color
        h.OutlineColor = Color3.new(1,1,1)
        h.FillTransparency = 0.5
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = adornee
        return h
    end)
    if not ok1 or not hl or not hl.Parent then return end

    local ok2, bb = pcall(function()
        local b = Instance.new("BillboardGui")
        b.Name = "MIIY_BB"
        b.Adornee = anchor
        b.Size = UDim2.new(0, 160, 0, 36)
        b.StudsOffset = Vector3.new(0, 2.8, 0)
        b.AlwaysOnTop = true
        b.Parent = anchor
        return b
    end)
    if not ok2 or not bb or not bb.Parent then
        pcall(function() hl:Destroy() end)
        return
    end

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1,0,0.55,0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = color
    nameLbl.TextStrokeTransparency = 0.1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1,0,0.45,0)
    distLbl.Position = UDim2.new(0,0,0.55,0)
    distLbl.BackgroundTransparency = 1
    distLbl.TextColor3 = C_DIM
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 9
    distLbl.Parent = bb

    local distConn = RunService.Heartbeat:Connect(function()
        if not bb.Parent or not anchor.Parent then return end
        local mc  = getChar()
        local mrp = getHRP(mc)
        if mrp then
            distLbl.Text = string.format("%.0f st", (mrp.Position - anchor.Position).Magnitude)
        end
    end)

    espPool[cat][key] = {
        hl = hl,
        bb = bb,
        distConn = distConn,
        adornee = adornee,
        anchor = anchor,
        label = label,
        color = color,
    }
end

local function prunePool(cat)
    for k, e in pairs(espPool[cat]) do
        local ok = true
        if not e or not e.hl or not e.bb then
            ok = false
        end
        if ok then
            if not validAdornee(e.adornee) or not validPart(e.anchor) then
                ok = false
            end
        end
        if not ok then
            destroyEntry(e)
            espPool[cat][k] = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ESP PLAYER
-- ══════════════════════════════════════════════════════════════════════════════
local playerCharConns = {}

local function scanPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if not head then continue end

        local key = "Player_" .. tostring(plr.UserId)
        if espPool.Player[key] and espPool.Player[key].adornee ~= char then
            destroyEntry(espPool.Player[key])
            espPool.Player[key] = nil
        end

        createESPEntry("Player", key, char, head, plr.Name, Color3.fromRGB(0,255,200))
    end
end

local function setPlayerESP(state)
    States.ESPPlayer = state
    stopPoll("Player")
    for _, c in ipairs(playerCharConns) do pcall(function() c:Disconnect() end) end
    table.clear(playerCharConns)
    clearPool("Player")
    if not state then return end

    scanPlayers()

    local function hookPlayer(plr)
        if plr == LocalPlayer then return end
        local c = plr.CharacterAdded:Connect(function()
            task.wait(0.3)
            if States.ESPPlayer then
                local key = "Player_" .. tostring(plr.UserId)
                destroyEntry(espPool.Player[key])
                espPool.Player[key] = nil
                scanPlayers()
            end
        end)
        table.insert(playerCharConns, c)
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        hookPlayer(plr)
    end

    table.insert(playerCharConns, Players.PlayerAdded:Connect(function(plr)
        hookPlayer(plr)
        task.wait(0.5)
        if States.ESPPlayer then scanPlayers() end
    end))

    table.insert(playerCharConns, Players.PlayerRemoving:Connect(function(plr)
        local key = "Player_" .. tostring(plr.UserId)
        destroyEntry(espPool.Player[key])
        espPool.Player[key] = nil
    end))

    local t = 0
    pollConns.Player = RunService.Heartbeat:Connect(function(dt)
        t = t + dt
        if t >= 1 then
            t = 0
            prunePool("Player")
            if States.ESPPlayer then scanPlayers() end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ESP MONSTER
-- ══════════════════════════════════════════════════════════════════════════════
local C_MON = Color3.fromRGB(220, 60, 60)

local function scanMonsters()
    local function addCreep(model)
        if not model or not model.Parent then return end
        local hitbox = model:FindFirstChild("Hitbox") or rootOf(model)
        if not hitbox or not validPart(hitbox) then return end
        local key = makeUniqueKey("Monster_Creep", model)
        if espPool.Monster[key] and espPool.Monster[key].adornee ~= model then
            destroyEntry(espPool.Monster[key])
            espPool.Monster[key] = nil
        end
        createESPEntry("Monster", key, model, hitbox, "Creep", C_MON)
    end

    if MonsterAllows.Gata then
        -- Gata gốc: Section1.Grunts, model có Humanoid.
        local grunts = safeFolder({"Section1","Grunts"})
        if grunts then
            for _, v in ipairs(grunts:GetChildren()) do
                if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
                    addCreep(v)
                end
            end
        end

        -- Grunts mở rộng: ví dụ Section2.Grunts.Grunt1 và các thư mục Grunts khác trong Section.
        local seenGrunts = {}
        local function addGruntFolder(folder)
            if not folder then return end
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("Model") and not seenGrunts[obj] then
                    local n = tostring(obj.Name or ""):lower()
                    if n:find("grunt", 1, true) and (obj:FindFirstChildOfClass("Humanoid") or rootOf(obj)) then
                        seenGrunts[obj] = true
                        addCreep(obj)
                    end
                end
            end
        end
        addGruntFolder(safeFolder({"Section2","Grunts"}))
        addGruntFolder(safeFolder({"Section3","Grunts"}))
        addGruntFolder(safeFolder({"Section4","Grunts"}))
        addGruntFolder(safeFolder({"Section5","Grunts"}))
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name:match("^Section%d+") and obj.Name ~= "Section1" then
                addGruntFolder(obj:FindFirstChild("Grunts"))
            end
        end

        -- Muki/Muki2: cùng nhánh Creep, mở rộng bằng tên chứa "muki" để không miss biến thể cùng loại.
        local mukiRoots = {
            safeFolder({"Section4","Lab","Floor1","Objective2","MukiSpawn"}),
            safeFolder({"Section4","Lab","Floor1","Objective2"}),
        }
        local seen = {}
        for _, root in ipairs(mukiRoots) do
            if root then
                local pool = root:GetDescendants()
                table.insert(pool, 1, root)
                for _, obj in ipairs(pool) do
                    if obj:IsA("Model") then
                        local n = tostring(obj.Name or ""):lower()
                        if n:find("muki", 1, true) and not seen[obj] then
                            seen[obj] = true
                            addCreep(obj)
                        end
                    end
                end
            end
        end
    end

    -- Boss / NM boss ESP.
    -- Update workspace mới: các bản NM đôi khi là Model trực tiếp
    -- (workspace.Section2.Monster.AkariNM, workspace.Section2.Rage.AkariRageNM,
    -- workspace.Section3.Monster.MizunoNM) và không phải lúc nào cũng expose Hitbox
    -- ngay lúc scan. Vì vậy mỗi entry có cả hitboxPath + modelPath fallback.
    local C_MON_NM = Color3.fromRGB(255, 115, 95)
    local bosses = {
        { hitboxPath = {"Section2","Monster","Akari","Hitbox"},      modelPath = {"Section2","Monster","Akari"},      label = "Akari",        color = C_MON },
        { hitboxPath = {"Section2","Monster","AkariNM","Hitbox"},    modelPath = {"Section2","Monster","AkariNM"},    label = "AkariNM",      color = C_MON_NM },

        { hitboxPath = {"Section2","Rage","AkariRage","Hitbox"},     modelPath = {"Section2","Rage","AkariRage"},     label = "Akari Rage",   color = C_MON },
        { hitboxPath = {"Section2","Rage","AkariRageNM","Hitbox"},   modelPath = {"Section2","Rage","AkariRageNM"},   label = "AkariRageNM",  color = C_MON_NM },

        { hitboxPath = {"Section3","Monster","Mizuno","Hitbox"},     modelPath = {"Section3","Monster","Mizuno"},     label = "Mizuno",       color = C_MON },
        { hitboxPath = {"Section3","Monster","MizunoNM","Hitbox"},   modelPath = {"Section3","Monster","MizunoNM"},   label = "MizunoNM",     color = C_MON_NM },

        { hitboxPath = {"Section4","Monster","HogoGuntai","Hitbox"}, modelPath = {"Section4","Monster","HogoGuntai"}, label = "HogoGuntai",   color = C_MON },
        { hitboxPath = {"Section4","Monster","HogoGuntaiNM","Hitbox"}, modelPath = {"Section4","Monster","HogoGuntaiNM"}, label = "HogoGuntaiNM", color = C_MON_NM },
        { hitboxPath = {"Section5","StairsSection","Monster","HogoGuntai","Hitbox"}, modelPath = {"Section5","StairsSection","Monster","HogoGuntai"}, label = "HogoGuntai", color = C_MON },
        { hitboxPath = {"Section5","StairsSection","Monster","HogoGuntaiNM","Hitbox"}, modelPath = {"Section5","StairsSection","Monster","HogoGuntaiNM"}, label = "HogoGuntaiNM", color = C_MON_NM },
        { hitboxPath = {"Section5","Monster","Baigai","Hitbox"},     modelPath = {"Section5","Monster","Baigai"},     label = "Baigai",       color = C_MON },
        { hitboxPath = {"Section5","Monster","BaigaiNM","Hitbox"},   modelPath = {"Section5","Monster","BaigaiNM"},   label = "BaigaiNM",     color = C_MON_NM },
    }

    local function resolveBossEntry(b)
        local anchor = safeFolder(b.hitboxPath)
        local model = safeFolder(b.modelPath)

        if anchor and not validPart(anchor) then
            anchor = nil
        end

        if not anchor and model then
            anchor = model:FindFirstChild("Hitbox")
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChild("RootPart")
                or model:FindFirstChild("Head")
                or model:FindFirstChildWhichIsA("BasePart", true)
        end

        if not model and anchor then
            model = anchor:FindFirstAncestorOfClass("Model") or anchor.Parent
        end

        if anchor and validPart(anchor) then
            local adornee = (model and model:IsA("Model")) and model or anchor
            return adornee, anchor
        end
        return nil, nil
    end

    if MonsterAllows.Boss then
        for _, b in ipairs(bosses) do
            local adornee, hitbox = resolveBossEntry(b)
            if adornee and hitbox then
                local key = makeUniqueKey("Monster_" .. b.label, adornee)
                if espPool.Monster[key] and espPool.Monster[key].adornee ~= adornee then
                    destroyEntry(espPool.Monster[key])
                    espPool.Monster[key] = nil
                end
                createESPEntry("Monster", key, adornee, hitbox, b.label, b.color or C_MON)
            end
        end
    end
end

local function setMonsterESP(state)
    States.ESPMonster = state
    stopPoll("Monster")
    clearPool("Monster")
    if not state then return end

    scanMonsters()

    local t = 0
    pollConns.Monster = RunService.Heartbeat:Connect(function(dt)
        t = t + dt
        if t >= 1.5 then
            t = 0
            prunePool("Monster")
            if States.ESPMonster then scanMonsters() end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ESP TASK (Granular - selectable task types with full model charms)
-- ══════════════════════════════════════════════════════════════════════════════
local C_TASK = Color3.fromRGB(80, 180, 255)

-- Individual scan functions for each task type (adornee = Model for full Highlight charm)
local function scanTaskBodies()
    if not States.ESPTaskBody then return end
    local deadCiv = safeFolder({"Section1","DeadCivilians"})
    if not deadCiv then return end
    for _, v in ipairs(deadCiv:GetChildren()) do
        if v and v.Parent then
            local hrp = v:FindFirstChild("HumanoidRootPart")
            local prompt = hrp and hrp:FindFirstChildWhichIsA("ProximityPrompt")
            if hrp and prompt and validPart(hrp) then
                local key = makeUniqueKey("Task_Body", v)
                if espPool.Task[key] and espPool.Task[key].adornee ~= v then
                    destroyEntry(espPool.Task[key])
                    espPool.Task[key] = nil
                end
                createESPEntry("Task", key, v, hrp, "Body", C_TASK)
            end
        end
    end
end

local function scanTaskSpiders()
    if not States.ESPTaskSpider then return end
    local spiders = safeFolder({"Section2","MAINOBJECTIVE2","Spiders"})
    if not spiders then return end
    for _, v in ipairs(spiders:GetChildren()) do
        if v.Name == "AkariSpider" then
            local hitbox = v:FindFirstChild("Hitbox")
            if hitbox and validPart(hitbox) then
                local key = makeUniqueKey("Task_Spider", v)
                if espPool.Task[key] and espPool.Task[key].adornee ~= v then
                    destroyEntry(espPool.Task[key])
                    espPool.Task[key] = nil
                end
                createESPEntry("Task", key, v, hitbox, "Spider", C_TASK)
            end
        end
    end
end

local function scanTaskGenerators()
    if not States.ESPTaskGenerator then return end
    local circuits = safeFolder({"Section3","OBJECTIVE","Circuits"})
    if not circuits then return end
    for _, v in ipairs(circuits:GetChildren()) do
        if v.Name == "CircuitPillar" then
            local pp = v:FindFirstChild("PromptPart")
            if pp and validPart(pp) then
                local key = makeUniqueKey("Task_Gen", v)
                if espPool.Task[key] and espPool.Task[key].anchor ~= pp then
                    destroyEntry(espPool.Task[key])
                    espPool.Task[key] = nil
                end
                createESPEntry("Task", key, v, pp, "Generator", C_TASK)
            end
        end
    end
end

local function scanTaskTerminals()
    if not States.ESPTaskTerminal then return end
    local terminals = safeFolder({"Section4","Lab","CleanseRoomObjective","ShapeTerminals"})
    if not terminals then return end
    for _, v in ipairs(terminals:GetChildren()) do
        local pp = v:FindFirstChild("PromptPart")
        local pr = pp and pp:FindFirstChildWhichIsA("ProximityPrompt")
        if pp and pr and validPart(pp) then
            local key = makeUniqueKey("Task_Terminal", v)
            if espPool.Task[key] and espPool.Task[key].anchor ~= pp then
                destroyEntry(espPool.Task[key])
                espPool.Task[key] = nil
            end
            createESPEntry("Task", key, v, pp, "Terminal", C_TASK)
        end
    end
end

local function scanTaskValves()
    if not States.ESPTaskValve then return end
    local valves = safeFolder({"Section4","Lab","CleanseRoomObjective","Valves"})
    if not valves then return end
    for _, v in ipairs(valves:GetChildren()) do
        if v:IsA("Model") then
            local icon = v:FindFirstChild("Notification") and v.Notification:FindFirstChild("Icon")
            if icon and icon.Enabled then
                local anchor = rootOf(v) or v:FindFirstChildWhichIsA("BasePart")
                if anchor and validPart(anchor) then
                    local key = makeUniqueKey("Task_Valve", v)
                    if espPool.Task[key] and espPool.Task[key].anchor ~= anchor then
                        destroyEntry(espPool.Task[key])
                        espPool.Task[key] = nil
                    end
                    createESPEntry("Task", key, v, anchor, "Valve", C_TASK)
                end
            end
        end
    end
end

local function scanTaskWires()
    if not States.ESPTaskWire then return end
    local boxes = safeFolder({"Section5","MainObjective","Boxes"})
    if not boxes then return end
    for _, box in ipairs(boxes:GetChildren()) do
        if box.Name == "WireBox" then
            local pp = box:FindFirstChild("PromptPart")
            local prompt = pp and pp:FindFirstChildWhichIsA("ProximityPrompt")
            if pp and prompt and prompt.Enabled and validPart(pp) then
                local key = makeUniqueKey("Task_Wire", box)
                if espPool.Task[key] and espPool.Task[key].anchor ~= pp then
                    destroyEntry(espPool.Task[key])
                    espPool.Task[key] = nil
                end
                createESPEntry("Task", key, box, pp, "Wire", C_TASK)
            end
        end
    end
end

local function scanTaskDirector()
    if not States.ESPTaskDirector then return end
    local root = safeFolder({"Section4","Lab","Floor1","Objective","DirectorSpawn"})
    if not root then return end

    local function addDirector(obj, label)
        if not obj then return end
        local anchor
        if obj:IsA("BasePart") then
            anchor = obj
        else
            local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
            anchor = (prompt and prompt.Parent and prompt.Parent:IsA("BasePart")) and prompt.Parent or rootOf(obj)
        end
        if not anchor or not validPart(anchor) then return end
        local key = makeUniqueKey("Task_Director", obj)
        if espPool.Task[key] and espPool.Task[key].anchor ~= anchor then
            destroyEntry(espPool.Task[key])
            espPool.Task[key] = nil
        end
        createESPEntry("Task", key, obj, anchor, label or "Director", C_TASK)
    end

    addDirector(root, "Director")
    local director = root:FindFirstChild("Director")
    if director then addDirector(director, "Director") end
    local card = director and director:FindFirstChild("IDCARD2")
    if card then addDirector(card, "ID Card") end
end

-- Additional objective markers and a single-session Egao assistant.
-- Egao face order/checkpoint/1s settle/62s look window follow the supplied Egao extension.
-- No lobby hopping or queued loader is used in this B3C1 test build.
local Extra = (function()
    local api = {}
    local alive, generation, running, autoLook = true, 0, false, true
    local activeTween, heartbeat, bindActive, statusCard
    local phase, detail = "Chưa chạy", "Kiểm tra một lượt tại Forest; không tự đổi server."
    local bindName = "NevoirsEgaoLook_" .. tostring(math.random(100000, 999999))
    local rigs = setmetatable({}, { __mode = "k" })
    local targetRig, targetPart, targetName, pendingRig, lookStarted
    local timeAccumulator, lookAllowed, lastAnnouncedRig = 0, false, nil
    local paths = {
        { key = "BoulderSeal", path = {"Section4","Lab","Floor1","Objective2","C4Explode","BoulderSeal"}, label = "Boulder Seal" },
        { key = "Cutter", path = {"Section1","SchoolGatePart","Truck","BoltCutter"}, label = "Bolt Cutter", prompt = true },
        { key = "Bandage", path = {"Section2","Items","Bandage"}, label = "Bandage", prompt = true },
        { key = "Diary", path = {"Section2","MAINOBJECTIVE","Diary"}, label = "Diary", prompt = true },
        { key = "EntranceCard", path = {"Section4","Lab","Floor1","Entrance","IDCARD"}, label = "Lab Keycard", prompt = true },
        { key = "C4", path = {"Section4","Lab","Floor1","Objective2","C4Explode"}, label = "C4 • 1", children = "C4Bomb", prompt = true },
        { key = "C4", path = {"Section4","Lab","Floor1","Objective3","C4Explode"}, label = "C4 • 2", children = "C4Bomb", prompt = true },
        { key = "PowerSwitch", path = {"Section5","MainObjective","PowerSwitch"}, label = "Main Switch", prompt = true },
    }
    local function notify(title, text)
        if WindUI and WindUI.Notify then
            pcall(function() WindUI:Notify({ Title = title, Content = text, Icon = "smile", Duration = 4 }) end)
        end
    end
    local function anchorFor(obj)
        local prompt = obj and obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        local anchor = prompt and prompt.Parent
        if anchor and anchor:IsA("Attachment") then anchor = anchor.Parent end
        if not validPart(anchor) then
            anchor = rootOf(obj)
            if not validPart(anchor) and obj then anchor = obj:FindFirstChildWhichIsA("BasePart", true) end
        end
        return anchor, prompt
    end
    function api.ScanObjectives()
        local seen = {}
        if States.ESPTaskExtra then
            local function add(obj, entry)
                if not obj or not obj.Parent then return end
                local anchor, prompt = anchorFor(obj)
                if not validPart(anchor) or (entry.prompt and (not prompt or not prompt.Enabled)) then return end
                -- Folder prompts cannot be Highlight adornees: choose their actual model/part.
                local adornee = validAdornee(obj) and obj or anchor
                local key = makeUniqueKey("Task_Extra_" .. entry.key, obj)
                seen[key] = true
                local current = espPool.Task[key]
                if current and (current.anchor ~= anchor or current.adornee ~= adornee) then
                    destroyEntry(current)
                    espPool.Task[key] = nil
                end
                createESPEntry("Task", key, adornee, anchor, entry.label, C_TASK)
            end
            for _, entry in ipairs(paths) do
                if TaskAllows[entry.key] then
                    local object = safeFolder(entry.path)
                    if entry.children then
                        for _, child in ipairs(object and object:GetChildren() or {}) do
                            if child.Name == entry.children then add(child, entry) end
                        end
                    else add(object, entry) end
                end
            end
        end
        -- Refresh task eligibility as well as existence; completed prompts lose their markers.
        for key, entry in pairs(espPool.Task) do
            if key:sub(1, 11) == "Task_Extra_" and not seen[key] then
                destroyEntry(entry)
                espPool.Task[key] = nil
            end
        end
    end
    local function refreshStatus()
        if statusCard and statusCard.SetDesc then
            local text = phase .. "\n" .. detail
            if targetPart and validPart(targetPart) then
                local hrp = getHRP(getChar())
                text = text .. "\n" .. tostring(targetName) .. (hrp and (" • " .. math.floor((hrp.Position - targetPart.Position).Magnitude) .. " st") or "")
            end
            pcall(function() statusCard:SetDesc(text) end)
        end
    end
    local function setStatus(nextPhase, nextDetail)
        phase, detail = nextPhase, nextDetail
        refreshStatus()
    end
    local function pulseFrame()
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local pulse = gui and gui:FindFirstChild("EgaoPulseText")
        local frame = pulse and pulse:FindFirstChild("Frame")
        if not frame or not frame:IsA("GuiObject") then return nil end
        local ancestor = frame
        while ancestor and ancestor ~= gui do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then return frame, false end
            if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return frame, false end
            ancestor = ancestor.Parent
        end
        return frame, true
    end
    local facePriority = {"sw face", "r eye", "l eye", "teeth", "gums", "head", "face", "RootPart"}
    local function partInRig(rig)
        for _, name in ipairs(facePriority) do
            local part = rig:FindFirstChild(name, true)
            if validPart(part) then return part, name end
        end
    end
    local function registerRigs()
        for _, object in ipairs(Workspace:GetChildren()) do
            if object.Name == "EgaoEventRig" and object:IsA("Model") and not rigs[object] then
                rigs[object] = os.clock()
                pendingRig = object
                targetRig, targetPart, targetName = nil, nil, nil
            end
        end
        for object in pairs(rigs) do
            if not object.Parent or not object:IsDescendantOf(Workspace) then rigs[object] = nil end
        end
    end
    local function selectRig()
        local now, best, bestPart, bestName, bestDistance = os.clock(), nil, nil, nil, math.huge
        local hrp = getHRP(getChar())
        if pendingRig and rigs[pendingRig] then
            if now - rigs[pendingRig] < 1 then return nil end
            local part, name = partInRig(pendingRig)
            if part then
                best, bestPart, bestName = pendingRig, part, name
            elseif now - rigs[pendingRig] < 3.2 then return nil end
            pendingRig = nil
        end
        if not best and targetRig and targetRig.Parent and rigs[targetRig] then
            local part, name = partInRig(targetRig)
            if part then best, bestPart, bestName = targetRig, part, name end
        end
        if not best then
            for rig, firstSeen in pairs(rigs) do
                if now - firstSeen >= 1 then
                    local part, name = partInRig(rig)
                    local distance = part and hrp and (hrp.Position - part.Position).Magnitude or math.huge
                    if part and (not best or distance < bestDistance) then
                        best, bestPart, bestName, bestDistance = rig, part, name, distance
                    end
                end
            end
        end
        targetRig, targetPart, targetName = best, bestPart, bestName
        return best
    end
    local function stopLook()
        if bindActive then pcall(function() RunService:UnbindFromRenderStep(bindName) end) end
        bindActive = false
    end
    local function startLook()
        if bindActive or not autoLook or not lookAllowed then return end
        bindActive, lookStarted = true, os.clock()
        RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
            if not alive or not running or not autoLook or not lookAllowed then return stopLook() end
            if os.clock() - lookStarted >= 62 then
                lookAllowed = false
                stopLook()
                setStatus("Đã nhả camera", "Đủ 62 giây cho đợt hiện tại; tiếp tục quan sát tín hiệu/rig mới.")
                return
            end
            if validPart(targetPart) and targetRig and targetRig.Parent then
                local camera = Workspace.CurrentCamera
                if camera then
                    local position = targetPart.Position + (targetName == "RootPart" and Vector3.new(0, 3.35, 0) or Vector3.zero)
                    if (position - camera.CFrame.Position).Magnitude > 0.5 then
                        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, position)
                    end
                end
            end
        end)
    end
    function api.Stop(reason)
        generation = generation + 1
        running, lookAllowed = false, false
        if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
        if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
        stopLook()
        targetRig, targetPart, targetName, pendingRig = nil, nil, nil, nil
        table.clear(rigs)
        lastAnnouncedRig = nil
        setStatus("Đã dừng", reason or "Không có phiên kiểm tra hoặc điều khiển camera đang chạy.")
    end
    function api.Monitor()
        if not alive then return false end
        api.Stop("Bắt đầu lượt mới.")
        if not safeFolder({"Section3"}) then
            setStatus("Chưa sẵn sàng", "Cần Forest/Section3 tải xong; không tự tới lobby hay tải Save.")
            notify("Egao", detail)
            return false
        end
        running = true
        local char = getChar()
        local wasPulse, lostFor = false, 0
        setStatus("Đang quan sát", "Chờ tín hiệu hoặc EgaoEventRig; chưa xác nhận event.")
        heartbeat = RunService.Heartbeat:Connect(function(dt)
            timeAccumulator = timeAccumulator + dt
            if timeAccumulator < 0.15 then return end
            local elapsed = timeAccumulator
            timeAccumulator = 0
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if getChar() ~= char or not char or not humanoid or humanoid.Health <= 0 then
                api.Stop("Nhân vật đổi hoặc đã chết; hãy bắt đầu lượt mới sau hồi sinh.")
                return
            end
            if not safeFolder({"Section3"}) then return api.Stop("Đã rời Forest/Section3.") end
            registerRigs()
            local rig = selectRig()
            local _, pulse = pulseFrame()
            if pulse and not wasPulse then
                lookAllowed = true
                stopLook()
                if not rig then setStatus("Có tín hiệu UI", "Chưa thấy EgaoEventRig; tín hiệu UI chưa xác nhận event.") end
            end
            wasPulse = pulse == true
            if rig then
                lostFor = 0
                if lastAnnouncedRig ~= rig then
                    lastAnnouncedRig = rig
                    lookAllowed = true
                    stopLook()
                    notify("Egao • phát hiện rig", "Đã thấy EgaoEventRig; không đồng nghĩa đã hoàn tất event.")
                end
                if bindActive then
                    phase, detail = "Đang nhìn Egao", "Đã xác nhận rig; theo dõi mặt tối đa 62 giây mỗi đợt."
                elseif lookAllowed then
                    phase, detail = "Đã thấy rig Egao", autoLook and "Chuẩn bị theo dõi mặt." or "Auto Look tắt; bạn điều khiển camera."
                end
                startLook()
            else
                if bindActive then stopLook() end
                lostFor = lostFor + elapsed
                if lostFor >= 3 and lastAnnouncedRig then
                    lastAnnouncedRig = nil
                    setStatus("Không thấy rig", "Có thể đang đổi phase hoặc rig chưa tải; chưa xác nhận event hoàn tất.")
                end
            end
            refreshStatus()
        end)
        return true
    end
    function api.Checkpoint()
        if activeTween then return notify("Egao", "Đang tới điểm kiểm tra. Dừng trước khi thử lại.") end
        if not api.Monitor() then return end
        local thisGeneration = generation
        local hrp = getHRP(getChar())
        if not validPart(hrp) then return api.Stop("Không có HumanoidRootPart hợp lệ.") end
        local ok, err = pcall(function()
            activeTween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(3, Enum.EasingStyle.Linear), { CFrame = CFrame.new(-3658, 8, 372) })
            activeTween:Play()
        end)
        if not ok then return api.Stop("Không thể tới điểm kiểm tra: " .. tostring(err)) end
        setStatus("Tới điểm kiểm tra", "Di chuyển một lần trong 3 giây; không tự đổi server khi không có event.")
        task.delay(3.2, function()
            if not alive or not running or generation ~= thisGeneration then return end
            activeTween = nil
            if getHRP(getChar()) ~= hrp then return api.Stop("Nhân vật đổi trong khi di chuyển.") end
            if (hrp.Position - Vector3.new(-3658, 8, 372)).Magnitude > 20 then
                setStatus("Chưa tới điểm kiểm tra", "Vị trí chưa khớp; theo dõi vẫn bật, bạn có thể dừng và thử lại.")
            elseif not lastAnnouncedRig then
                setStatus("Đang kiểm tra tại điểm", "Chờ tín hiệu và rig; không có tín hiệu không khẳng định server thiếu event.")
            end
        end)
    end
    function api.SetAutoLook(value)
        autoLook = value == true
        if not autoLook then
            stopLook()
            if running and targetRig then setStatus("Đã thấy rig Egao", "Auto Look tắt; bạn điều khiển camera.") end
        elseif running and targetRig then lookAllowed = true; startLook() end
    end
    function api.BuildUI(tab)
        safeDivider(tab)
        safeParagraph(tab, "Egao • một lượt Forest", "Quan sát hoặc tới điểm kiểm tra; không tự hop/lặp Save.", "smile")
        pcall(function() statusCard = tab:Paragraph({ Title = "Trạng thái Egao", Desc = phase .. "\n" .. detail, Image = "activity" }) end)
        addButton(tab, "Egao • quan sát tại chỗ", "Chờ tín hiệu và xác nhận rig; không TP.", api.Monitor)
        addButton(tab, "Egao • tới điểm kiểm tra", "Di chuyển một lần tới checkpoint của nguồn Egao bổ sung.", api.Checkpoint)
        addToggle(tab, "Egao • Auto Look", "Theo dõi rig sau 1 giây ổn định, tối đa 62 giây mỗi đợt.", true, api.SetAutoLook)
        addButton(tab, "Egao • nhả camera và dừng", "Hủy di chuyển và mọi theo dõi Egao trong phiên này.", function() api.Stop("Dừng thủ công.") end)
    end
    function api.cleanup()
        alive = false
        api.Stop("Đã unload.")
    end
    return api
end)()

local function scanAllActiveTasks()
    scanTaskBodies()
    scanTaskSpiders()
    scanTaskGenerators()
    scanTaskTerminals()
    scanTaskValves()
    scanTaskWires()
    scanTaskDirector()
    Extra.ScanObjectives()
end

local function isAnyTaskESPActive()
    return States.ESPTaskBody or States.ESPTaskSpider or States.ESPTaskGenerator
        or States.ESPTaskTerminal or States.ESPTaskValve or States.ESPTaskWire
        or States.ESPTaskDirector or States.ESPTaskExtra
end

local function clearTaskType(prefix)
    for k, e in pairs(espPool.Task) do
        if k:match("^Task_" .. prefix) then
            destroyEntry(e)
            espPool.Task[k] = nil
        end
    end
end

local taskPollConn
local function stopTaskPoll()
    if taskPollConn then
        taskPollConn:Disconnect()
        taskPollConn = nil
    end
end

local function startTaskPollIfNeeded()
    if taskPollConn then return end
    local t = 0
    taskPollConn = RunService.Heartbeat:Connect(function(dt)
        t = t + dt
        if t >= 1 then
            t = 0
            prunePool("Task")
            if isAnyTaskESPActive() then
                scanAllActiveTasks()
            else
                stopTaskPoll()
            end
        end
    end)
end

-- Individual toggle functions for each task type
local function setTaskBodyESP(state)
    States.ESPTaskBody = state
    clearTaskType("Body")
    if state then
        scanTaskBodies()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function setTaskSpiderESP(state)
    States.ESPTaskSpider = state
    clearTaskType("Spider")
    if state then
        scanTaskSpiders()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function setTaskGeneratorESP(state)
    States.ESPTaskGenerator = state
    clearTaskType("Gen")
    if state then
        scanTaskGenerators()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function setTaskTerminalESP(state)
    States.ESPTaskTerminal = state
    clearTaskType("Terminal")
    if state then
        scanTaskTerminals()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function setTaskValveESP(state)
    States.ESPTaskValve = state
    clearTaskType("Valve")
    if state then
        scanTaskValves()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function setTaskWireESP(state)
    States.ESPTaskWire = state
    clearTaskType("Wire")
    if state then
        scanTaskWires()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function setTaskDirectorESP(state)
    States.ESPTaskDirector = state
    clearTaskType("Director")
    if state then
        scanTaskDirector()
        startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then
        stopTaskPoll()
    end
end

local function refreshMonsterESP()
    if States.ESPMonster then setMonsterESP(true) end
end

local function setMonsterAllowGata(state)
    MonsterAllows.Gata = state
    refreshMonsterESP()
end

local function setMonsterAllowBoss(state)
    MonsterAllows.Boss = state
    refreshMonsterESP()
end

local function applyTaskMaster()
    setTaskBodyESP(States.ESPTaskMaster and TaskAllows.Body)
    setTaskSpiderESP(States.ESPTaskMaster and TaskAllows.Spider)
    setTaskGeneratorESP(States.ESPTaskMaster and TaskAllows.Generator)
    setTaskTerminalESP(States.ESPTaskMaster and TaskAllows.Terminal)
    setTaskValveESP(States.ESPTaskMaster and TaskAllows.Valve)
    setTaskWireESP(States.ESPTaskMaster and TaskAllows.Wire)
    setTaskDirectorESP(States.ESPTaskMaster and TaskAllows.Director)
    States.ESPTaskExtra = States.ESPTaskMaster and (
        TaskAllows.BoulderSeal or TaskAllows.Cutter or TaskAllows.Bandage
        or TaskAllows.Diary or TaskAllows.EntranceCard or TaskAllows.C4 or TaskAllows.PowerSwitch
    ) or false
    Extra.ScanObjectives()
    if States.ESPTaskExtra then startTaskPollIfNeeded()
    elseif not isAnyTaskESPActive() then stopTaskPoll() end
end

local function setTaskMasterESP(state)
    States.ESPTaskMaster = state
    applyTaskMaster()
end

local function setTaskAllow(kind, state)
    TaskAllows[kind] = state
    applyTaskMaster()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AUTO YEN SUPPORT (logic gốc: Workspace.MimicCurrencySpawns.Yen + prompt <= 10 studs)
-- Nằm ở tab Main/Auto, không đưa vào ESP tab để tránh rối.
-- ══════════════════════════════════════════════════════════════════════════════
local C_YEN = Color3.fromRGB(255, 220, 55)
local YEN_COLLECT_RANGE = 10

local function getYenFolders()
    local out, seen = {}, {}
    local function add(folder)
        if folder and folder.Parent and not seen[folder] then
            seen[folder] = true
            table.insert(out, folder)
        end
    end

    -- Path cũ.
    local oldRoot = Workspace:FindFirstChild("MimicCurrencySpawns")
    add(oldRoot and oldRoot:FindFirstChild("Yen"))

    -- Workspace mới theo finder: workspace.Yen.YenCoin.
    add(Workspace:FindFirstChild("Yen"))

    -- Fallback nhẹ cho các biến thể tên folder, không GetDescendants toàn map.
    add(Workspace:FindFirstChild("YenSpawns"))
    add(Workspace:FindFirstChild("CurrencyYen"))

    return out
end

local function getYenFolder()
    local folders = getYenFolders()
    return folders[1]
end

local function getLocalDistance(part)
    local hrp = getHRP(getChar())
    if not hrp or not part or not part:IsA("BasePart") then return math.huge end
    return (part.Position - hrp.Position).Magnitude
end

local function findYenPrompt(yen)
    if not yen or not yen.Parent then return nil end
    if yen:IsA("ProximityPrompt") then return yen end

    local direct = yen:FindFirstChildWhichIsA("ProximityPrompt")
    if direct then return direct end

    for _, d in ipairs(yen:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            return d
        end
    end
    return nil
end

local function getYenAnchor(yen)
    if not yen or not yen.Parent then return nil end
    if yen:IsA("BasePart") then return yen end

    local prompt = findYenPrompt(yen)
    local p = prompt and prompt.Parent
    if p and p:IsA("BasePart") then return p end
    if p and p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then return p.Parent end

    return rootOf(yen)
end

local function fireYenPrompt(prompt)
    if not prompt or prompt.Enabled == false then return false end
    local ok = false
    pcall(function() prompt.HoldDuration = 0 end)
    ok = pcall(function() fireproximityprompt(prompt, 1, true) end) or ok
    ok = pcall(function() fireproximityprompt(prompt, 1) end) or ok
    ok = pcall(function() fireproximityprompt(prompt) end) or ok
    return ok
end

local function touchYenAnchor(anchor)
    local hrp = getHRP(getChar())
    if not hrp or not anchor or not validPart(anchor) then return false end
    local ok = false
    if type(firetouchinterest) == "function" then
        ok = pcall(function() firetouchinterest(hrp, anchor, 0) end) or ok
        task.wait()
        ok = pcall(function() firetouchinterest(hrp, anchor, 1) end) or ok
    end
    return ok
end

local function scanYenSupport()
    local folders = getYenFolders()
    if #folders == 0 then
        if States.AutoYenESP then clearPool("Yen") end
        return
    end

    local seen = {}
    for _, folder in ipairs(folders) do
        for _, yen in ipairs(folder:GetChildren()) do
            if yen and yen.Parent and not seen[yen] then
                seen[yen] = true
                local anchor = getYenAnchor(yen)
                if anchor and validPart(anchor) then
                    if States.AutoYenCollect and getLocalDistance(anchor) <= YEN_COLLECT_RANGE then
                        local prompt = findYenPrompt(yen)
                        local fired = prompt and fireYenPrompt(prompt)
                        if not fired then
                            touchYenAnchor(anchor)
                        end
                    end

                    if States.AutoYenESP then
                        local adornee = (yen:IsA("Model") or yen:IsA("BasePart")) and yen or anchor
                        local key = makeUniqueKey("Yen", yen)
                        createESPEntry("Yen", key, adornee, anchor, "Yen", C_YEN)
                    end
                end
            end
        end
    end

    if States.AutoYenESP then
        prunePool("Yen")
    end
end

local function isYenSupportActive()
    return States.AutoYenESP or States.AutoYenCollect
end

local function startYenSupportLoop()
    if pollConns.Yen then return end
    local t = 0
    pollConns.Yen = RunService.Heartbeat:Connect(function(dt)
        t = t + dt
        if t < 0.20 then return end
        t = 0

        if not isYenSupportActive() then
            clearPool("Yen")
            stopPoll("Yen")
            return
        end

        scanYenSupport()
    end)
end

local function setYenESP(state)
    States.AutoYenESP = state and true or false
    if States.AutoYenESP then
        scanYenSupport()
        startYenSupportLoop()
    else
        clearPool("Yen")
        if not isYenSupportActive() then stopPoll("Yen") end
    end
end

local function setYenCollect(state)
    States.AutoYenCollect = state and true or false
    if States.AutoYenCollect then
        startYenSupportLoop()
    elseif not isYenSupportActive() then
        stopPoll("Yen")
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOCAL PLAYER: INSTANT E
-- Chỉ đổi thời gian giữ; không đổi khoảng cách, line-of-sight hay tự kích hoạt.
-- Theo dõi prompt tải muộn và khôi phục giá trị khi tắt/reload.
-- ══════════════════════════════════════════════════════════════════════════════
local InstantInteract = { prompts = {}, added = nil, removing = nil }

function InstantInteract:restorePrompt(prompt)
    local record = self.prompts[prompt]
    if not record then return end
    self.prompts[prompt] = nil
    if record.changed then record.changed:Disconnect() end
    pcall(function()
        if prompt.HoldDuration == 0 then
            prompt.HoldDuration = record.duration
        end
    end)
end

function InstantInteract:track(prompt)
    if not States.InstantInteract or not prompt:IsA("ProximityPrompt") or self.prompts[prompt] then return end
    local ok, duration = pcall(function() return prompt.HoldDuration end)
    if not ok then return end
    local record = { duration = duration }
    self.prompts[prompt] = record
    record.changed = prompt:GetPropertyChangedSignal("HoldDuration"):Connect(function()
        if not States.InstantInteract or self.prompts[prompt] ~= record then return end
        pcall(function()
            local current = prompt.HoldDuration
            if current ~= 0 then
                -- Giữ lại thời gian mới do game đặt để khôi phục đúng khi tắt.
                record.duration = current
                prompt.HoldDuration = 0
            end
        end)
    end)
    pcall(function() prompt.HoldDuration = 0 end)
end

function InstantInteract:scan()
    if not States.InstantInteract then return end
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("ProximityPrompt") then self:track(instance) end
    end
end

function InstantInteract:stop()
    States.InstantInteract = false
    if self.added then self.added:Disconnect(); self.added = nil end
    if self.removing then self.removing:Disconnect(); self.removing = nil end
    local pending = {}
    for prompt in pairs(self.prompts) do pending[#pending + 1] = prompt end
    for _, prompt in ipairs(pending) do self:restorePrompt(prompt) end
end

function InstantInteract:setEnabled(enabled)
    self:stop()
    if not enabled then return end
    States.InstantInteract = true
    self.added = Workspace.DescendantAdded:Connect(function(instance)
        self:track(instance)
    end)
    self.removing = Workspace.DescendantRemoving:Connect(function(instance)
        self:restorePrompt(instance)
    end)
    self:scan()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIC: TPWALK
-- ══════════════════════════════════════════════════════════════════════════════
local tpwalkConn
local function applyTPWalk()
    if tpwalkConn then tpwalkConn:Disconnect(); tpwalkConn = nil end
    if not States.TPWalk then return end
    tpwalkConn = RunService.Heartbeat:Connect(function(dt)
        pcall(function()
            local char = getChar()
            if not char then return end
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.MoveDirection.Magnitude > 0 then
                char:TranslateBy(hum.MoveDirection * TPWalkSpeed * dt * 10)
            end
        end)
    end)
end
local function toggleTPWalk(e) States.TPWalk = e; applyTPWalk() end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIC: NOCLIP
-- Dạng tối giản giống Infinite Yield: bật thì ép CanCollide=false theo Stepped,
-- tắt thì chỉ ngắt loop. Không reset Humanoid/velocity/camera để tránh giật,
-- lock hướng, hoặc lỗi cutscene.
-- ══════════════════════════════════════════════════════════════════════════════
local noclipConn
local noclipCollisionCache = setmetatable({}, { __mode = "k" })

local function restoreNoclipCollision()
    for part, oldValue in pairs(noclipCollisionCache) do
        if typeof(part) == "Instance" and part.Parent then
            pcall(function() part.CanCollide = oldValue end)
        end
    end
    noclipCollisionCache = setmetatable({}, { __mode = "k" })
end

local function setCharacterNoclip(char)
    char = char or getChar()
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if noclipCollisionCache[part] == nil then
                noclipCollisionCache[part] = part.CanCollide
            end
            if part.CanCollide then
                pcall(function() part.CanCollide = false end)
            end
        end
    end
end

local function applyNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end

    if not States.Noclip then
        return
    end

    setCharacterNoclip(getChar())

    noclipConn = RunService.Stepped:Connect(function()
        if not States.Noclip then
            if noclipConn then
                noclipConn:Disconnect()
                noclipConn = nil
            end
            return
        end
        setCharacterNoclip(getChar())
    end)
end

local function toggleNoclip(e)
    States.Noclip = e and true or false
    if States.Noclip then
        applyNoclip()
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        restoreNoclipCollision()
    end
end

pcall(function()
    _G.__NevoirsLastNoclipCleanup = function()
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        States.Noclip = false
        restoreNoclipCollision()
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIC: MOONWALK / REVERSE FACING
-- Xoay hướng nhân vật ngược lại với hướng camera theo trục ngang.
-- Không dùng BodyGyro/BodyVelocity, không reset velocity, không đổi Humanoid state.
-- ══════════════════════════════════════════════════════════════════════════════
local moonwalkConn
local moonwalkAutoRotateCache = setmetatable({}, { __mode = "k" })

local function clearMoonwalkAutoRotate()
    for hum, oldAutoRotate in pairs(moonwalkAutoRotateCache) do
        if typeof(hum) == "Instance" and hum.Parent then
            pcall(function()
                hum.AutoRotate = oldAutoRotate
            end)
        end
    end
    moonwalkAutoRotateCache = setmetatable({}, { __mode = "k" })
end

local function setMoonwalkHumanoid(hum)
    if not hum then return end
    if moonwalkAutoRotateCache[hum] == nil then
        moonwalkAutoRotateCache[hum] = hum.AutoRotate
    end
    if hum.AutoRotate ~= false then
        pcall(function() hum.AutoRotate = false end)
    end
end

local function applyMoonwalk()
    if moonwalkConn then
        moonwalkConn:Disconnect()
        moonwalkConn = nil
    end

    if not States.Moonwalk then
        clearMoonwalkAutoRotate()
        return
    end

    moonwalkConn = RunService.RenderStepped:Connect(function()
        if not States.Moonwalk then
            if moonwalkConn then
                moonwalkConn:Disconnect()
                moonwalkConn = nil
            end
            clearMoonwalkAutoRotate()
            return
        end

        local char = getChar()
        if not char then return end

        local hum = char:FindFirstChildWhichIsA("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        if not hum or not hrp or not cam or hum.Health <= 0 then return end

        setMoonwalkHumanoid(hum)

        local look = cam.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude < 0.05 then return end

        local reverseLook = -flatLook.Unit
        local pos = hrp.Position

        pcall(function()
            hrp.CFrame = CFrame.lookAt(pos, pos + reverseLook)
        end)
    end)
end

local function toggleMoonwalk(e)
    States.Moonwalk = e and true or false
    applyMoonwalk()
end

pcall(function()
    _G.__NevoirsLastMoonwalkCleanup = function()
        if moonwalkConn then
            moonwalkConn:Disconnect()
            moonwalkConn = nil
        end
        States.Moonwalk = false
        clearMoonwalkAutoRotate()
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIC: INFINITE JUMP
-- ══════════════════════════════════════════════════════════════════════════════
local ijConn
local function toggleInfiniteJump(e)
    States.InfiniteJump = e
    if ijConn then ijConn:Disconnect(); ijConn = nil end
    if not e then return end
    ijConn = UserInputService.JumpRequest:Connect(function()
        local char = getChar()
        if not char then return end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIC: FULLBRIGHT
-- ══════════════════════════════════════════════════════════════════════════════
local fbConn
local function applyFullbright()
    if fbConn then fbConn:Disconnect(); fbConn = nil end
    if not States.Fullbright then return end
    fbConn = RunService.Heartbeat:Connect(function()
        Lighting.Brightness     = 2
        Lighting.GlobalShadows  = false
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.Ambient        = Color3.new(1,1,1)
        Lighting.FogEnd         = 100000
    end)
end
local function toggleFullbright(e)
    States.Fullbright = e
    if e then applyFullbright()
    else
        if fbConn then fbConn:Disconnect(); fbConn = nil end
        Lighting.Brightness     = OrigLighting.Brightness
        Lighting.GlobalShadows  = OrigLighting.GlobalShadows
        Lighting.OutdoorAmbient = OrigLighting.OutdoorAmbient
        Lighting.Ambient        = OrigLighting.Ambient
        Lighting.FogEnd         = OrigLighting.FogEnd
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIC: VFLY TỰ DO (camera-direction, không cần nút lên/xuống)
-- ══════════════════════════════════════════════════════════════════════════════
local Camera = workspace.CurrentCamera
local vflyBV, vflyBG, vflyConn, vflyStateConn
local vflyHumanoid, vflyOldWalkSpeed = nil, nil
local VFlySpeed = getNumberSetting("VFlySpeed", DEFAULT_SETTINGS.VFlySpeed, 0, 99999)

local function cleanVFly()
    if vflyConn      then vflyConn:Disconnect();      vflyConn      = nil end
    if vflyStateConn then vflyStateConn:Disconnect(); vflyStateConn = nil end
    pcall(function() if vflyBV and vflyBV.Parent then vflyBV:Destroy() end end)
    pcall(function() if vflyBG and vflyBG.Parent then vflyBG:Destroy() end end)
    vflyBV = nil; vflyBG = nil
end

local function applyVFly()
    cleanVFly()
    if not States.VFly then return end
    local char = getChar()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not hum then return end

    vflyBG = Instance.new("BodyGyro")
    vflyBG.MaxTorque = Vector3.new(9e9,9e9,9e9)
    vflyBG.P = 9e4; vflyBG.D = 1e3
    vflyBG.CFrame = hrp.CFrame; vflyBG.Parent = hrp

    vflyBV = Instance.new("BodyVelocity")
    vflyBV.MaxForce = Vector3.new(9e9,9e9,9e9)
    vflyBV.Velocity = Vector3.zero; vflyBV.P = 1e4; vflyBV.Parent = hrp

    vflyHumanoid = hum
    vflyOldWalkSpeed = hum.WalkSpeed
    hum.WalkSpeed = 0
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    vflyStateConn = hum.StateChanged:Connect(function(_, new)
        if States.VFly and new ~= Enum.HumanoidStateType.Physics then
            task.defer(function()
                if States.VFly then hum:ChangeState(Enum.HumanoidStateType.Physics) end
            end)
        end
    end)

    vflyConn = RunService.RenderStepped:Connect(function()
        if not States.VFly then cleanVFly(); return end
        if not vflyBV or not vflyBV.Parent then cleanVFly(); applyVFly(); return end

        Camera = workspace.CurrentCamera or Camera
        local camCF = Camera.CFrame
        local look  = camCF.LookVector
        local right = camCF.RightVector
        local flatL = Vector3.new(look.X, 0, look.Z)
        local flatR = Vector3.new(right.X, 0, right.Z)
        if flatL.Magnitude > 0 then flatL = flatL.Unit end
        if flatR.Magnitude > 0 then flatR = flatR.Unit end

        local move = Vector3.zero
        local md = hum.MoveDirection
        if md.Magnitude > 0.16 and flatL.Magnitude > 0 and flatR.Magnitude > 0 then
            -- Mobile joystick: lấy hướng input ngang rồi chiếu lại theo hướng camera đầy đủ.
            -- Nhìn lên trời + kéo tới = bay lên; nhìn xuống + kéo tới = bay xuống.
            local forward = math.clamp(md:Dot(flatL), -1, 1)
            local strafe  = math.clamp(md:Dot(flatR), -1, 1)
            if math.abs(forward) < 0.18 then forward = 0 end
            if math.abs(strafe) < 0.18 then strafe = 0 end
            if forward ~= 0 or strafe ~= 0 then
                move = move + (look * forward) + (right * strafe)
            end
        else
            -- PC fallback: vẫn dùng WASD, nhưng W/S đi theo LookVector 3D của camera.
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        end

        -- Phím phụ cho PC; mobile không cần nút riêng.
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
            move = move + Vector3.new(0,1,0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            move = move - Vector3.new(0,1,0)
        end

        if move.Magnitude > 0.08 then
            vflyBV.Velocity = move.Unit * VFlySpeed
            if look.Magnitude > 0 then
                vflyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + look)
            end
        else
            -- Không còn trượt/giật khi đứng im: giữ vị trí, không decay vận tốc cũ.
            vflyBV.Velocity = Vector3.zero
            vflyBG.CFrame = hrp.CFrame
        end
    end)
end

local function toggleVFly(e)
    States.VFly = e
    if e then applyVFly()
    else
        cleanVFly()
        local hum = vflyHumanoid
        if hum and hum.Parent then
            pcall(function()
                if vflyOldWalkSpeed ~= nil then hum.WalkSpeed = vflyOldWalkSpeed end
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
        vflyHumanoid = nil
        vflyOldWalkSpeed = nil
    end
end
States.VFly = false  -- khai báo sau vì toggleVFly dùng

-- ── Respawn ───────────────────────────────────────────────────────────────────
local characterAddedConn
characterAddedConn = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.7)
    if States.TPWalk       then applyTPWalk()            end
    if States.Noclip       then applyNoclip()            end
    if States.InfiniteJump then toggleInfiniteJump(true) end
    if States.Fullbright   then applyFullbright()        end
    if States.VFly         then applyVFly()              end
    if States.ESPPlayer    then setPlayerESP(true)       end
    if States.ESPMonster   then setMonsterESP(true)      end
    if States.ESPTaskBody      then setTaskBodyESP(true)      end
    if States.ESPTaskSpider    then setTaskSpiderESP(true)    end
    if States.ESPTaskGenerator then setTaskGeneratorESP(true) end
    if States.ESPTaskTerminal  then setTaskTerminalESP(true)  end
    if States.ESPTaskValve     then setTaskValveESP(true)     end
    if States.ESPTaskWire      then setTaskWireESP(true)      end
    if States.ESPTaskDirector  then setTaskDirectorESP(true)  end
    if States.AutoYenESP       then setYenESP(true)            end
    if States.AutoYenCollect   then startYenSupportLoop()      end
    if States.InstantInteract then InstantInteract:scan()      end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- AUTO ACTIONS
-- Bản này giữ UI/Fly gốc, chỉ sửa Auto: không TP, chỉ xử lý object gần nhất
-- và dùng flow gần nhất với script 229. Không dùng chỉnh cự li client-side.
-- ══════════════════════════════════════════════════════════════════════════════
-- WindUI is shared from the service declarations above.

local function packetHasServerCall(packet)
    if not packet then return false end
    if typeof(packet) == "Instance" then
        return packet:IsA("RemoteEvent") or packet:IsA("RemoteFunction")
    end
    return type(packet) == "table" and (type(packet.FireServer) == "function" or type(packet.InvokeServer) == "function")
end

local function safeRequirePacket(module)
    if not module or not module:IsA("ModuleScript") then return nil end
    local ok, result = pcall(require, module)
    if ok then return result end
    return nil
end

local function getReliablePacket()
    -- Giữ path gốc: ReplicatedStorage.modules.Packet.Reliable, thêm fallback require để tránh miss Packet module.
    local modules = ReplicatedStorage:FindFirstChild("modules")
    local packet = modules and modules:FindFirstChild("Packet")

    if packet then
        local directReliable = packet:FindFirstChild("Reliable")
        if packetHasServerCall(directReliable) then
            return directReliable
        end

        local requiredPacket = safeRequirePacket(packet)
        if type(requiredPacket) == "table" and packetHasServerCall(requiredPacket.Reliable) then
            return requiredPacket.Reliable
        end

        for _, obj in ipairs(packet:GetDescendants()) do
            if obj.Name == "Reliable" and packetHasServerCall(obj) then
                return obj
            end
        end
    end

    -- Fallback từ bản cũ nếu executor/game đã có biến R global ở ngoài.
    local ok, reliable = pcall(function()
        return R.modules.Packet.Reliable
    end)
    if ok and packetHasServerCall(reliable) then return reliable end

    return nil
end


local function getDistance(part)
    local hrp = getHRP(getChar())
    if not hrp or not part then return math.huge end
    return (part.Position - hrp.Position).Magnitude
end

local function isNearEnough(part)
    -- Đã bỏ mục cự li: chỉ cần object tồn tại; việc prompt có fire được hay không để game/executor xử lý.
    return part ~= nil
end

local function promptAnchor(prompt)
    if not prompt then return nil end
    local p = prompt.Parent
    if p and p:IsA("BasePart") then return p end
    if p and p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then return p.Parent end
    return rootOf(p)
end

local function preparePromptForAuto(prompt, extraRange)
    if not prompt then return end

    -- Đã loại bỏ toàn bộ chỉnh cự li. Không sửa MaxActivationDistance/RequiresLineOfSight
    -- để tránh tình trạng UI/task hoạt động khác logic gốc. Chỉ rút HoldDuration cho thao tác nhanh hơn.
    pcall(function() prompt.HoldDuration = 0 end)
end

local function pressPrompt(prompt, holdTime)
    if not prompt then return false end

    preparePromptForAuto(prompt)

    local ok = false
    local duration = tonumber(holdTime) or 1

    ok = pcall(function()
        fireproximityprompt(prompt, duration, true)
    end) or ok

    ok = pcall(function()
        fireproximityprompt(prompt, duration)
    end) or ok

    ok = pcall(function()
        fireproximityprompt(prompt)
    end) or ok

    return ok
end

local function pressPromptOriginalOnce(prompt)
    if not prompt then return false end
    preparePromptForAuto(prompt)

    -- Dành riêng cho Generator: script mẫu chỉ gọi fireproximityprompt(prompt) đúng 1 lần.
    -- Không dùng chuỗi fallback nhiều kiểu ở đây để tránh tạo nhiều task UI chồng lên nhau.
    local ok = pcall(function()
        fireproximityprompt(prompt)
    end)

    if not ok then
        ok = pcall(function()
            fireproximityprompt(prompt, 1, true)
        end)
    end

    return ok
end

-- Task UI ownership is captured around this interaction only. Never scan-and-hide
-- every matching GUI: completed generator rounds must be confirmed first.
local TaskAssist = { busy = nil, epoch = 0, hidden = {} }

function TaskAssist.notify(title, message)
    print("[Nevoirs] " .. title .. ": " .. message)
    if WindUI and WindUI.Notify then
        pcall(function()
            WindUI:Notify({Title = title, Content = message, Duration = 4, Icon = "info"})
        end)
    end
end

function TaskAssist.uiMatches(gui, kind)
    if not (gui:IsA("ScreenGui") or gui:IsA("GuiObject")) then return false end
    if gui == ScreenGui or gui:IsDescendantOf(ScreenGui) then return false end
    -- Match an actual minigame container name, never arbitrary labels/text.
    local name = gui.Name:lower():gsub("[^%w]", "")
    local base = kind == "Generator" and {"circuit", "generator"} or {"shape", "terminal", "shapeterminal"}
    for _, prefix in ipairs(base) do
        if name == prefix or name == prefix .. "ui" or name == prefix .. "gui"
            or name == prefix .. "game" or name == prefix .. "minigame"
            or name == prefix .. "frame" then
            return true
        end
    end
    return false
end

function TaskAssist.visible(gui)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local item = gui
    while item and item ~= pg do
        if item:IsA("ScreenGui") and not item.Enabled then return false end
        if item:IsA("GuiObject") and not item.Visible then return false end
        item = item.Parent
    end
    return item == pg
end

function TaskAssist.restore(kind)
    local restored = {}
    for gui, record in pairs(TaskAssist.hidden) do
        if not kind or record.kind == kind then
            if gui.Parent then
                pcall(function()
                    if gui:IsA("ScreenGui") then
                        if gui.Enabled == false then gui.Enabled = record.value end
                    elseif gui.Visible == false then
                        gui.Visible = record.value
                    end
                end)
                restored[gui] = true
            end
            TaskAssist.hidden[gui] = nil
        end
    end
    return restored
end

function TaskAssist.begin(kind, target)
    if TaskAssist.busy then
        TaskAssist.notify(kind, "Đang xử lý " .. TaskAssist.busy.kind .. "; đợi lượt hiện tại kết thúc.")
        return nil
    end
    local restored = TaskAssist.restore(kind)
    local session = {
        kind = kind, target = target, character = getChar(), epoch = TaskAssist.epoch,
        before = {}, owned = {}, triggered = false, connection = nil,
    }
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetDescendants()) do
            if TaskAssist.uiMatches(gui, kind) then
                -- A previously captured container is safe to reuse for this next session.
                session.before[gui] = not restored[gui] and TaskAssist.visible(gui) or false
            end
        end
    end
    TaskAssist.busy = session
    return session
end

function TaskAssist.valid(session)
    if session.epoch ~= TaskAssist.epoch or not ScreenGui.Parent then return false end
    if getChar() ~= session.character or not session.character or not session.character.Parent then return false end
    local hum = session.character:FindFirstChildOfClass("Humanoid")
    return (not hum or hum.Health > 0) and session.target.Parent ~= nil
        and session.target:IsDescendantOf(Workspace)
end

function TaskAssist.capture(session)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local found = false
    if pg then
        for _, gui in ipairs(pg:GetDescendants()) do
            if TaskAssist.uiMatches(gui, session.kind) and TaskAssist.visible(gui) then
                found = true
                if session.before[gui] ~= true then session.owned[gui] = true end
            end
        end
    end
    return found
end

function TaskAssist.watchPrompt(session, prompt)
    session.connection = prompt.Triggered:Connect(function(player)
        if not player or player == LocalPlayer then session.triggered = true end
    end)
end

function TaskAssist.finish(session)
    if session.connection then session.connection:Disconnect(); session.connection = nil end
    if TaskAssist.busy == session then TaskAssist.busy = nil end
end

function TaskAssist.closeOwned(session)
    local count = 0
    TaskAssist.capture(session)
    for gui in pairs(session.owned) do
        if gui.Parent and TaskAssist.visible(gui) then
            -- Prefer the smallest captured task container; do not hide its parent too.
            local hasOwnedChild = false
            for other in pairs(session.owned) do
                if other ~= gui and other.Parent and other:IsDescendantOf(gui) then
                    hasOwnedChild = true
                    break
                end
            end
            if not hasOwnedChild then
                local ok = pcall(function()
                    local value = gui:IsA("ScreenGui") and gui.Enabled or gui.Visible
                    TaskAssist.hidden[gui] = {kind = session.kind, value = value}
                    if gui:IsA("ScreenGui") then gui.Enabled = false else gui.Visible = false end
                end)
                if ok then count = count + 1 end
            end
        end
    end
    return count
end

function TaskAssist.cancel()
    TaskAssist.epoch = TaskAssist.epoch + 1
    if TaskAssist.busy then TaskAssist.finish(TaskAssist.busy) end
    TaskAssist.restore()
end

local function nearestFrom(list, getPart, filter)
    local nearest, nearestPart, best = nil, nil, math.huge
    for _, item in ipairs(list) do
        if (not filter or filter(item)) then
            local part = getPart(item)
            if part and validPart(part) then
                local d = getDistance(part)
                if d < best then
                    nearest, nearestPart, best = item, part, d
                end
            end
        end
    end
    return nearest, nearestPart, best
end

local GeneratorAutoRunning = false

local function collectCircuitPillars(folder)
    local list = {}
    if not folder then return list end

    -- Script gốc đặt CircuitPillar trực tiếp trong Circuits; dùng GetDescendants làm fallback để không miss khi map đổi folder con.
    for _, obj in ipairs(folder:GetChildren()) do
        if obj.Name == "CircuitPillar" then
            table.insert(list, obj)
        end
    end

    if #list == 0 then
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj.Name == "CircuitPillar" then
                table.insert(list, obj)
            end
        end
    end

    return list
end

local function getGeneratorPromptPart(pillar)
    if not pillar then return nil end
    -- Generator gốc dùng CollisionPart làm điểm thao tác, nên ưu tiên nó để chọn đúng máy phát gần nhất.
    return pillar:FindFirstChild("CollisionPart")
        or pillar:FindFirstChild("PromptPart")
        or rootOf(pillar)
end

local function getGeneratorPrompt(pillar)
    local pp = pillar and pillar:FindFirstChild("PromptPart")
    if pp then
        local prompt = pp:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then return prompt end
    end

    if pillar then
        for _, d in ipairs(pillar:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                return d
            end
        end
    end

    return nil
end

local function nearestGenerator(folder)
    local best, bestPart, bestDist = nil, nil, math.huge
    local fallback, fallbackPart, fallbackDist = nil, nil, math.huge

    for _, pillar in ipairs(collectCircuitPillars(folder)) do
        local part = getGeneratorPromptPart(pillar)
        if part and validPart(part) then
            local dist = getDistance(part)
            if dist < fallbackDist then
                fallback, fallbackPart, fallbackDist = pillar, part, dist
            end

            local prompt = getGeneratorPrompt(pillar)
            if prompt and prompt.Enabled ~= false and dist < bestDist then
                best, bestPart, bestDist = pillar, part, dist
            end
        end
    end

    -- Ưu tiên prompt enabled như script gốc, nhưng vẫn fallback direct remote nếu prompt bị ẩn.
    if best then return best, bestPart, bestDist end
    return fallback, fallbackPart, fallbackDist
end

local function fireReliablePacket(reliable, key, target)
    if not reliable then return false end

    if typeof(reliable) == "Instance" then
        if reliable:IsA("RemoteEvent") then
            reliable:FireServer(key, target)
            return true
        elseif reliable:IsA("RemoteFunction") then
            reliable:InvokeServer(key, target)
            return true
        end
    elseif type(reliable) == "table" then
        if type(reliable.FireServer) == "function" then
            reliable:FireServer(key, target)
            return true
        elseif type(reliable.InvokeServer) == "function" then
            reliable:InvokeServer(key, target)
            return true
        end
    else
        local ok = pcall(function()
            reliable:FireServer(key, target)
        end)
        return ok
    end

    return false
end

local function autoGenerator()
    if GeneratorAutoRunning then
        return TaskAssist.notify("Generator", "Máy phát đang được xử lý; đợi hoàn tất rồi bấm lại.")
    end
    if TaskAssist.busy then
        return TaskAssist.notify("Generator", "Đang có phiên nhiệm vụ khác; đợi phiên đó kết thúc.")
    end

    GeneratorAutoRunning = true
    task.spawn(function()
        local session
        local okRun, errRun = pcall(function()
            local folder = safeFolder({"Section3","OBJECTIVE","Circuits"})
            if not folder then return TaskAssist.notify("Generator", "Chưa tìm thấy máy phát ở khu hiện tại.") end
            local pillar, anchor, dist = nearestGenerator(folder)
            if not pillar or not anchor then return TaskAssist.notify("Generator", "Không tìm thấy máy phát.") end
            local reliable = getReliablePacket()
            if not reliable then return TaskAssist.notify("Generator", "Chưa tải được Packet Reliable.") end
            session = TaskAssist.begin("Generator", pillar)
            if not session then return end
            local collisionPart = pillar:FindFirstChild("CollisionPart")
            local prompt = getGeneratorPrompt(pillar)

            -- Preserve the uploaded cc's working generator flow and timing.
            pcall(function()
                if collisionPart and collisionPart:IsA("BasePart") then collisionPart.CanCollide = false end
            end)
            if prompt then
                TaskAssist.watchPrompt(session, prompt)
                preparePromptForAuto(prompt)
                pressPromptOriginalOnce(prompt)
            else
                warn("[Nevoirs] Không tìm thấy prompt máy phát; giữ fallback packet gốc.")
            end
            task.wait(1)
            if not TaskAssist.valid(session) then return end
            TaskAssist.capture(session)
            local sent = 0
            for _ = 1, 3 do
                if not TaskAssist.valid(session) then break end
                -- Source 229 exposes this exact completion state for CircuitPillar.
                if pillar:GetAttribute("CurrentRound") == 4 then break end
                local okFire, acceptedCall = pcall(fireReliablePacket, reliable, "Section3/CircuitRoundComplete", pillar)
                if okFire and acceptedCall then sent = sent + 1 end
            end

            local deadline = os.clock() + 2
            while TaskAssist.valid(session) and pillar:GetAttribute("CurrentRound") ~= 4 and os.clock() < deadline do
                TaskAssist.capture(session)
                task.wait(0.05)
            end
            if not TaskAssist.valid(session) then return end
            if pillar:GetAttribute("CurrentRound") == 4 then
                local closed = TaskAssist.closeOwned(session)
                TaskAssist.notify("Generator", closed > 0
                    and "Đã xác nhận đủ vòng và ẩn đúng bảng máy phát của lượt này."
                    or "Máy phát đã đủ vòng; chưa nhận diện được bảng an toàn, hãy đóng bảng thủ công.")
            else
                TaskAssist.notify("Generator", ("Đã gửi %d lượt; chưa xác nhận máy hoàn tất. Hãy kiểm tra bảng và đứng sát máy."):format(sent))
            end
            print(("[Nevoirs] Generator: %d packet | %.1f studs | CurrentRound=%s"):format(sent, dist or 0, tostring(pillar:GetAttribute("CurrentRound"))))
        end)
        if session then TaskAssist.finish(session) end
        GeneratorAutoRunning = false
        if not okRun then TaskAssist.notify("Generator", "Lỗi xử lý: " .. tostring(errRun)) end
    end)
end

local function autoTerminal()
    if TaskAssist.busy then
        return TaskAssist.notify("Terminal", "Đang có phiên nhiệm vụ khác; đợi phiên đó kết thúc.")
    end
    local folder = safeFolder({"Section4","Lab","CleanseRoomObjective","ShapeTerminals"})
    if not folder then return TaskAssist.notify("Terminal", "Chưa thấy terminal. Kiểm tra cổng và tiến trình khu Lab.") end
    local terminal, pp, distance = nearestFrom(folder:GetChildren(), function(v)
        return v:FindFirstChild("PromptPart") or rootOf(v)
    end, function(v)
        if not v.Name:lower():find("terminal", 1, true) then return false end
        local part = v:FindFirstChild("PromptPart") or rootOf(v)
        local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
        local anchor = promptAnchor(prompt)
        return prompt and prompt.Enabled and anchor and getDistance(anchor) <= prompt.MaxActivationDistance + 0.5
    end)
    if not terminal or not pp then
        return TaskAssist.notify("Terminal", "Không có terminal đang mở tương tác trong tầm. Hãy đứng sát máy chưa hoàn tất.")
    end
    local prompt = pp:FindFirstChildWhichIsA("ProximityPrompt")
    local reliable = getReliablePacket()
    if not reliable then return TaskAssist.notify("Terminal", "Chưa tải được Packet Reliable.") end
    local session = TaskAssist.begin("Terminal", terminal)
    if not session then return end
    task.spawn(function()
        local opened = false
        local released = false
        local okRun, errRun = pcall(function()
            TaskAssist.watchPrompt(session, prompt)
            local invoked = pressPromptOriginalOnce(prompt)
            if not invoked then return TaskAssist.notify("Terminal", "Executor chưa gọi được tương tác terminal.") end
            opened = session.triggered
            task.wait(0.35)
            local deadline = os.clock() + 1
            local visibleUI = TaskAssist.capture(session)
            while TaskAssist.valid(session) and not session.triggered and not visibleUI and os.clock() < deadline do
                task.wait(0.05)
                visibleUI = TaskAssist.capture(session)
            end
            if not TaskAssist.valid(session) then return end
            -- A successful function call alone is not proof that the minigame opened.
            opened = session.triggered or visibleUI
            if not opened then
                return TaskAssist.notify("Terminal", "Đã thử mở nhưng chưa xác nhận được phiên. Mở tương tác thủ công rồi thử lại.")
            end
            local completedBefore = {}
            for _, key in ipairs({"Completed", "Complete", "Solved", "IsCompleted", "Finished"}) do
                completedBefore[key] = terminal:GetAttribute(key)
            end
            local roundBefore = terminal:GetAttribute("CurrentRound")
            -- Match current 229: one RoundComplete followed by Release, no teleport.
            local okSend, sent = pcall(fireReliablePacket, reliable, "ShapeTerminal/RoundComplete", terminal)
            local okRelease, didRelease = pcall(fireReliablePacket, reliable, "ShapeTerminal/Release", terminal)
            released = okRelease and didRelease
            if not okSend or not sent then return TaskAssist.notify("Terminal", "Không gửi được lượt xử lý terminal.") end
            local confirmed, progressed = false, false
            deadline = os.clock() + 1.5
            repeat
                if not TaskAssist.valid(session) then return end
                for _, key in ipairs({"Completed", "Complete", "Solved", "IsCompleted", "Finished"}) do
                    if terminal:GetAttribute(key) == true and completedBefore[key] ~= true then confirmed = true end
                end
                local round = terminal:GetAttribute("CurrentRound")
                progressed = type(round) == "number" and type(roundBefore) == "number" and round > roundBefore
                if confirmed or progressed then break end
                task.wait(0.05)
            until os.clock() >= deadline
            if confirmed then
                TaskAssist.notify("Terminal", "Đã thấy trạng thái hoàn tất của terminal.")
            elseif progressed then
                TaskAssist.notify("Terminal", "Terminal đã tăng tiến độ. Kiểm tra vòng còn lại trước khi bấm tiếp.")
            else
                TaskAssist.notify("Terminal", ("Đã gửi 1 lượt + %s ở %.1f studs; chưa có xác nhận hoàn tất. Kiểm tra mục tiêu trong game."):format(released and "nhả máy" or "chưa nhả được máy", distance or 0))
            end
        end)
        -- Release on interruption/error too, without ever forcing any GUI hidden.
        if (opened or session.triggered) and not released and terminal.Parent then
            pcall(fireReliablePacket, reliable, "ShapeTerminal/Release", terminal)
        end
        TaskAssist.finish(session)
        if not okRun then TaskAssist.notify("Terminal", "Lỗi xử lý: " .. tostring(errRun)) end
    end)
end

local function getValveIcon(valve)
    if not valve then return nil end
    local notif = valve:FindFirstChild("Notification") or valve:FindFirstChild("Notification", true)
    return notif and (notif:FindFirstChild("Icon") or notif:FindFirstChild("Icon", true))
end

local function valveIconEnabled(valve)
    local foundIcon = false
    for _, d in ipairs(valve:GetDescendants()) do
        if d.Name == "Icon" and d:IsA("BillboardGui") then
            foundIcon = true
            if d.Enabled then return true end
        elseif d.Name == "Icon" and d:IsA("GuiObject") then
            foundIcon = true
            if d.Visible then return true end
        end
    end

    if not foundIcon then
        for _, d in ipairs(valve:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                return true
            end
        end
    end

    return false
end

local function valveHasTurnerPrompt(valve)
    for _, d in ipairs(valve:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local n = string.lower(d.Name)
            local pn = d.Parent and string.lower(d.Parent.Name) or ""
            if n == "right" or pn == "right" or d:FindFirstAncestor("Turners") then
                return true
            end
        end
    end
    return false
end

local function getValvePrompts(valve)
    local prompts = {}
    for _, d in ipairs(valve:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local n = string.lower(d.Name)
            local pn = d.Parent and string.lower(d.Parent.Name) or ""
            local inTurners = d:FindFirstAncestor("Turners") ~= nil
            if n == "right" or pn == "right" or inTurners then
                table.insert(prompts, d)
            end
        end
    end
    table.sort(prompts, function(a, b)
        local aa = promptAnchor(a)
        local bb = promptAnchor(b)
        return getDistance(aa) < getDistance(bb)
    end)
    return prompts
end

local function pressValvePrompt(prompt)
    if not prompt then return false end
    local ok = false
    preparePromptForAuto(prompt, 18)
    ok = pcall(function()
        local hold = tonumber(prompt.HoldDuration) or 0
        fireproximityprompt(prompt, math.max(hold + 0.05, 1), true)
    end) or ok
    ok = pcall(function() fireproximityprompt(prompt, 1, true) end) or ok
    ok = pcall(function() fireproximityprompt(prompt, 1) end) or ok
    ok = pcall(function() fireproximityprompt(prompt) end) or ok
    return ok
end

local function autoValve()
    local folder = safeFolder({"Section4","Lab","CleanseRoomObjective","Valves"})
    if not folder then return warn("[Nevoirs] Không tìm thấy thư mục van") end

    local valve, anchor = nearestFrom(folder:GetChildren(), function(v)
        if not v:IsA("Model") then return nil end
        local icon = getValveIcon(v)
        if icon and icon.Parent and icon.Parent:IsA("BasePart") then return icon.Parent end
        local prompt = getValvePrompts(v)[1]
        return promptAnchor(prompt) or rootOf(v)
    end, function(v)
        return v:IsA("Model") and valveHasTurnerPrompt(v) and valveIconEnabled(v)
    end)

    if not valve or not anchor then return warn("[Nevoirs] Không tìm thấy van") end

    local started = os.clock()
    local prompts = getValvePrompts(valve)

    if #prompts == 0 then
        return warn("[Nevoirs] Van gần nhất không có prompt xoay")
    end

    while os.clock() - started < 35 do
        if not valveIconEnabled(valve) then
            break
        end

        for _, prompt in ipairs(prompts) do
            if prompt and prompt.Parent then
                pressValvePrompt(prompt)
                task.wait(0.12)
            end
        end

        prompts = getValvePrompts(valve)
        task.wait(0.08)
    end
end

local function autoWire()
    local folder = safeFolder({"Section5","MainObjective","Boxes"})
    if not folder then return warn("[Nevoirs] Không tìm thấy thư mục hộp dây") end

    local box, pp = nearestFrom(folder:GetChildren(), function(v)
        if v.Name ~= "WireBox" then return nil end
        return v:FindFirstChild("PromptPart") or rootOf(v)
    end, function(v)
        if v.Name ~= "WireBox" then return false end
        local part = v:FindFirstChild("PromptPart")
        local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
        return prompt ~= nil and prompt.Enabled ~= false
    end)

    if not box or not pp then return warn("[Nevoirs] Không tìm thấy hộp dây") end

    local reliable = getReliablePacket()
    if not reliable then return warn("[Nevoirs] Không tìm thấy Packet Reliable") end
    -- Sát script gốc: không mở UI hộp dây, claim 2 lần rồi gửi screw/cut/complete.
    pcall(function() reliable:FireServer("Section5/WireBoxClaim", box) end)
    task.wait(0.03)
    pcall(function() reliable:FireServer("Section5/WireBoxClaim", box) end)
    task.wait(0.03)

    local bolt = box:FindFirstChild("Bolt")
    if bolt then
        for _, screw in ipairs(bolt:GetChildren()) do
            if screw.Name == "Screw" then
                pcall(function() reliable:FireServer("Section5/WireBoxScrewDone", screw) end)
                task.wait(0.015)
            end
        end
    end

    local cuttable = box:FindFirstChild("Cuttable")
    if cuttable then
        for _, cut in ipairs(cuttable:GetChildren()) do
            if cut.Name == "Cut" then
                pcall(function() reliable:FireServer("Section5/WireBoxCutDone", cut) end)
                task.wait(0.015)
            end
        end
    end

    pcall(function() reliable:FireServer("Section5/WireBoxComplete", box) end)
    pcall(function()
        local prompt = box.PromptPart and box.PromptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then prompt.Enabled = false end
    end)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- AUTO NEARBY KILL: GATAS / GRUNTS / MUKI / HOGOGUNTAI / FLESHBLOCK / SPIDER, KHÔNG TELEPORT
-- Bám logic B3C1 gốc: GunAction("fire") + RemoteEvent target + CAMERAREPLICA.
-- Bản này sửa lại target-acquire: không phụ thuộc 1 remote cố định, tự refresh remote/part
-- để tránh lỗi "lúc đầu shoot, những lần sau báo không có target".
-- ══════════════════════════════════════════════════════════════════════════════
-- WindUI is forward-declared before task actions; do not shadow it here.
local AutoNearbyKillRunning = false
local AutoNearbyKillTarget = nil
local CameraReplicaHookInstalled = false
local CameraReplicaLastTry = 0

local AUTO_KILL_ICON = NEVOIRS_UI_ICON
local TARGET_RELOCK_INTERVAL = 1.35

local AutoKillConfig = {
    FireDelay = getNumberSetting("AutoKillFireDelay", DEFAULT_SETTINGS.AutoKillFireDelay, 0.01, 10),
    RangeGata = getNumberSetting("AutoKillRangeGata", DEFAULT_SETTINGS.AutoKillRangeGata, 0, 9999),
    RangeGrunt = getNumberSetting("AutoKillRangeGrunt", DEFAULT_SETTINGS.AutoKillRangeGata, 0, 9999),
    RangeMuki = getNumberSetting("AutoKillRangeMuki", DEFAULT_SETTINGS.AutoKillRangeGata, 0, 9999),
    RangeHogo = getNumberSetting("AutoKillRangeHogo", DEFAULT_SETTINGS.AutoKillRangeHogo, 0, 9999),
    RangeFleshBlock = getNumberSetting("AutoKillRangeFleshBlock", DEFAULT_SETTINGS.AutoKillRangeFleshBlock, 0, 9999),
    RangeSpider = getNumberSetting("AutoKillRangeSpider", DEFAULT_SETTINGS.AutoKillRangeSpider, 0, 9999),
}

local function normalizeKillKind(kind)
    local k = tostring(kind or ""):lower()
    if k:find("spider", 1, true) then return "Spider" end
    if k:find("flesh", 1, true) or k:find("block", 1, true) then return "FleshBlock" end
    if k:find("hogo", 1, true) then return "Hogo" end
    if k:find("muki", 1, true) then return "Muki" end
    if k:find("grunt", 1, true) then return "Grunt" end
    return "Gata"
end

local function getKillRange(kind)
    local k = normalizeKillKind(kind)
    if k == "Spider" then return AutoKillConfig.RangeSpider end
    if k == "FleshBlock" then return AutoKillConfig.RangeFleshBlock end
    if k == "Hogo" then return AutoKillConfig.RangeHogo end
    if k == "Muki" then return AutoKillConfig.RangeMuki end
    if k == "Grunt" then return AutoKillConfig.RangeGrunt end
    return AutoKillConfig.RangeGata
end

local function getAutoKillFireDelay()
    local n = tonumber(AutoKillConfig.FireDelay) or DEFAULT_SETTINGS.AutoKillFireDelay
    if n < 0.01 then n = 0.01 end
    return n
end

local setFireSettingsPanelVisible = function() end

local function smallNotify(title, content, icon)
    pcall(function()
        if WindUI and WindUI.Notify then
            WindUI:Notify({
                Title = title or "Nevoirs",
                Content = content or "",
                Icon = icon or AUTO_KILL_ICON,
                Duration = 2,
            })
        end
    end)
end

local function getGunActionRemote()
    local r = ReplicatedStorage:FindFirstChild("GunAction")
    if r and r:IsA("RemoteEvent") then return r end

    local okGG, ggRemote = pcall(function()
        return GG and GG.R and GG.R.GunAction
    end)
    if okGG and ggRemote and typeof(ggRemote) == "Instance" and ggRemote:IsA("RemoteEvent") then
        return ggRemote
    end

    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d.Name == "GunAction" and d:IsA("RemoteEvent") then
            return d
        end
    end

    return nil
end

local function collectRemoteEvents(obj)
    local remotes, seen = {}, {}

    local function add(r)
        if r and typeof(r) == "Instance" and r:IsA("RemoteEvent") and not seen[r] then
            seen[r] = true
            table.insert(remotes, r)
        end
    end

    if not obj or not obj.Parent then return remotes end

    if obj:IsA("RemoteEvent") then
        add(obj)
        return remotes
    end

    add(obj:FindFirstChildWhichIsA("RemoteEvent"))

    local hitbox = obj:FindFirstChild("Hitbox", true)
    if hitbox then
        add(hitbox:FindFirstChild("RemoteEvent"))
        add(hitbox:FindFirstChildWhichIsA("RemoteEvent"))
    end

    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            add(d)
            if #remotes >= 12 then break end -- chặn trường hợp model có quá nhiều remote phụ
        end
    end

    return remotes
end

local function nearestBasePartOf(obj)
    if not obj or not obj.Parent then return nil, math.huge end
    local hrp = getHRP(getChar())
    if not hrp then return nil, math.huge end

    if not obj:IsA("BasePart") then
        for _, name in ipairs({"Hitbox", "HumanoidRootPart", "RootPart", "Head"}) do
            local preferred = obj:FindFirstChild(name, true)
            if preferred and validPart(preferred) then return preferred, (preferred.Position - hrp.Position).Magnitude end
        end
    end
    local best, bestDist = nil, math.huge

    local function try(part)
        if part and validPart(part) then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then
                best, bestDist = part, d
            end
        end
    end

    if obj:IsA("BasePart") then
        try(obj)
    elseif obj:IsA("Model") or obj:IsA("Folder") then
        -- Ưu tiên Hitbox/HumanoidRootPart nhưng vẫn fallback part gần nhất.
        try(obj:FindFirstChild("Hitbox", true))
        try(obj:FindFirstChild("HumanoidRootPart", true))
        try(obj:FindFirstChild("Head", true))
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then
                try(d)
            end
        end
    else
        try(rootOf(obj))
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then
                try(d)
            end
        end
    end

    return best, bestDist
end

local function getAimDot(targetPos)
    local cam = Workspace.CurrentCamera
    if not cam or not targetPos then return 0 end
    local delta = targetPos - cam.CFrame.Position
    if delta.Magnitude <= 0.01 then return 1 end
    return math.clamp(cam.CFrame.LookVector:Dot(delta.Unit), -1, 1)
end

-- FleshBlock: khôi phục đúng behavior của nevoirs.lua gốc.
-- Chỉ lock body mà camera/raycast thực sự đang nhìn tới; fallback bằng aim-dot khi raycast không có hit.
AutoKillConfig.IsLookingAtFleshBody = (function()
    local function getLookRayHit(maxDistance)
        local cam = Workspace.CurrentCamera
        if not cam then return nil end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        local ignore = {}
        local char = getChar()
        if char then table.insert(ignore, char) end
        params.FilterDescendantsInstances = ignore

        local ok, result = pcall(function()
            return Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * (tonumber(maxDistance) or 250), params)
        end)
        if ok and result then return result.Instance, result.Position end
        return nil
    end

    return function(body)
        if not validPart(body) then return false end
        local hit = getLookRayHit(260)
        if not hit then
            return getAimDot(body.Position) >= 0.86
        end
        if hit == body or hit:IsDescendantOf(body) then return true end
        local block = body.Parent
        if block and (hit == block or hit:IsDescendantOf(block)) then return true end
        return false
    end
end)()

local CameraReplicaBridge = (function()
    -- Reuse one forwarding hook across reruns. A new session only takes ownership
    -- of the target value; cleanup detaches it without unhooking someone else's hook.
    local shared = rawget(_G, "__CCNKCameraBridgeV2")
    if type(shared) ~= "table" then shared={}; _G.__CCNKCameraBridgeV2=shared end
    local owner = {}
    shared.owner=owner; shared.target=nil
    local api={}
    function api:Set(cf) if shared.owner==owner then shared.target=cf end end
    function api:Release() if shared.owner==owner then shared.target=nil; shared.owner=nil end end
    function api:Install()
        local modules=ReplicatedStorage:FindFirstChild("modules")
        local packetModule=modules and modules:FindFirstChild("Packet")
        if not packetModule then return false end
        local ok,packet=pcall(require,packetModule)
        if not ok then return false end
        local okState,updateState=pcall(function() return packet.unreliablesend.ReplicationService.Character.updateState end)
        if not okState or not updateState then return false end
        local mt=getmetatable(updateState)
        if type(mt)~="table" or type(mt.__call)~="function" then return false end
        if shared.meta==mt and shared.installed then CameraReplicaHookInstalled=true; return true end
        if os.clock()-CameraReplicaLastTry<3 then return false end
        CameraReplicaLastTry=os.clock()
        local hookFn=(GG and GG.LowerC) or hookfunction
        if type(hookFn)~="function" then return false end
        local old
        local handler=function(...)
            local args=table.pack(...)
            if shared.owner and shared.target and args[1] and args[1].__name=="updateState" then
                local cam=Workspace.CurrentCamera
                if cam then args[2]=CFrame.lookAt(cam.CFrame.Position,shared.target.Position) end
            end
            return old(table.unpack(args,1,args.n))
        end
        local closure=type(newcclosure)=="function" and newcclosure(handler) or handler
        local hooked,result=pcall(hookFn,mt.__call,closure)
        if not hooked or type(result)~="function" then return false end
        old=result
        shared.meta=mt; shared.installed=true
        CameraReplicaHookInstalled=true
        return true
    end
    return api
end)()

local function installCameraReplicaHook() return CameraReplicaBridge:Install() end

local function addKillTarget(out, inst, kind, maxRange)
    if not inst or not inst.Parent then return end
    local hum = inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") or nil
    if hum and hum.Health <= 0 then return end

    local anchor, dist = nearestBasePartOf(inst)
    if not anchor or dist > maxRange then return end

    local pos = anchor.Position
    local dot = getAimDot(pos)
    local remotes = collectRemoteEvents(inst)

    table.insert(out, {
        kind = kind or tostring(inst.Name or "Monster"),
        instance = inst,
        anchor = anchor,
        cframe = CFrame.new(pos),
        dist = dist,
        dot = dot,
        maxRange = maxRange,
        remoteCount = #remotes,
        remotes = remotes,
        lockStarted = os.clock(),
        lastNoRemoteNotice = 0,
    })
end

local function collectGataTargets(out)
    local grunts = safeFolder({"Section1", "Grunts"})
    if not grunts then return end

    for _, gata in ipairs(grunts:GetChildren()) do
        if gata:IsA("Model") and gata:FindFirstChildOfClass("Humanoid") then
            addKillTarget(out, gata, "Gata", getKillRange("Gata"))
        end
    end
end

local function collectGruntTargets(out)
    -- Grunts mở rộng: ví dụ Section2.Grunts.Grunt1. Dùng chung range với Gata/Creep.
    local seen = {}

    local function scanFolder(folder)
        if not folder then return end
        local pool = folder:GetDescendants()
        table.insert(pool, 1, folder)
        for _, obj in ipairs(pool) do
            if obj:IsA("Model") and not seen[obj] then
                local n = tostring(obj.Name or ""):lower()
                if n:find("grunt", 1, true) and (obj:FindFirstChildOfClass("Humanoid") or rootOf(obj)) then
                    seen[obj] = true
                    addKillTarget(out, obj, obj.Name, getKillRange("Grunt"))
                end
            end
        end
    end

    scanFolder(safeFolder({"Section2", "Grunts"}))
    scanFolder(safeFolder({"Section3", "Grunts"}))
    scanFolder(safeFolder({"Section4", "Grunts"}))
    scanFolder(safeFolder({"Section5", "Grunts"}))
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:match("^Section%d+") and obj.Name ~= "Section1" then
            scanFolder(obj:FindFirstChild("Grunts"))
        end
    end
end

local function collectMukiTargets(out)
    local roots = {
        safeFolder({"Section4", "Lab", "Floor1", "Objective2", "MukiSpawn"}),
        safeFolder({"Section4", "Lab", "Floor1", "Objective2"}),
    }
    local seen = {}

    for _, root in pairs(roots) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("Model") and not seen[obj] then
                    local n = tostring(obj.Name or ""):lower()
                    if n:find("muki", 1, true) then
                        seen[obj] = true
                        addKillTarget(out, obj, obj.Name, getKillRange(obj.Name))
                    end
                end
            end
        end
    end
end

local function collectHogoGuntaiTargets(out)
    local paths = {
        {"Section5", "StairsSection", "Monster"},
        {"Section4", "Monster"},
        {"Section4"},
    }
    local seen = {}

    for _, path in ipairs(paths) do
        local folder = safeFolder(path)
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("Model") and not seen[obj] then
                    local n = tostring(obj.Name or ""):lower()
                    if n:find("hogoguntai", 1, true) or n:find("hogo", 1, true) then
                        seen[obj] = true
                        addKillTarget(out, obj, obj.Name, getKillRange(obj.Name))
                    end
                end
            end
        end
    end
end


local function collectFleshBlockTargets(out)
    -- Theo path bạn gửi: Section5.StairsSection.FleshBlock.Block.body
    -- Bản này CHỈ lấy đúng BasePart tên body làm anchor/range.
    -- Không lấy Block/Screen/SurfaceGui/parent để tránh remote global làm bắn toàn bộ FleshBlock.
    local roots = {
        safeFolder({"Section5", "StairsSection", "FleshBlock"}),
        safeFolder({"Section5", "StairsSection"}),
    }
    local seenBody = {}

    local function tryAddBody(body)
        if not body or not validPart(body) then return end
        if tostring(body.Name or ""):lower() ~= "body" then return end
        if seenBody[body] then return end

        local hrp = getHRP(getChar())
        if not hrp then return end

        local range = getKillRange("FleshBlock")
        local dist = (body.Position - hrp.Position).Magnitude
        if dist > range then return end

        -- Logic gốc nevoirs.lua: FleshBlock chỉ hợp lệ khi đang nhìn/raycast đúng body.
        -- Điều này tránh lock cả cụm FleshBlock chỉ vì chúng nằm trong range.
        if not AutoKillConfig.IsLookingAtFleshBody(body) then return end

        seenBody[body] = true

        local block = body.Parent or body
        local remotes = collectRemoteEvents(body)

        table.insert(out, {
            kind = "FleshBlock",
            instance = block,
            anchor = body,
            fleshBody = body,
            cframe = body.CFrame,
            dist = dist,
            dot = getAimDot(body.Position),
            maxRange = range,
            remoteCount = #remotes,
            remotes = remotes,
            lockStarted = os.clock(),
            lastNoRemoteNotice = 0,
        })
    end

    for _, root in pairs(roots) do
        if root then
            -- Ưu tiên path chính xác trước.
            local directBlock = root:FindFirstChild("Block")
            local directBody = directBlock and (directBlock:FindFirstChild("body") or directBlock:FindFirstChild("Body"))
            tryAddBody(directBody)

            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("BasePart") and tostring(obj.Name or ""):lower() == "body" then
                    local path = tostring(obj:GetFullName() or ""):lower()
                    if path:find("fleshblock", 1, true) then
                        tryAddBody(obj)
                    end
                end
            end
        end
    end
end

local function collectSpiderTargets(out)
    local spiders = safeFolder({"Section2", "MAINOBJECTIVE2", "Spiders"})
    if not spiders then return end

    for _, spider in ipairs(spiders:GetChildren()) do
        if spider.Name == "AkariSpider" then
            local hitbox = spider:FindFirstChild("Hitbox")
            local remote = hitbox and hitbox:FindFirstChild("RemoteEvent")
            if hitbox and validPart(hitbox) and getDistance(hitbox) <= getKillRange("Spider") then
                table.insert(out, {
                    kind = "Spider",
                    instance = spider,
                    anchor = hitbox,
                    cframe = hitbox.CFrame,
                    dist = getDistance(hitbox),
                    dot = getAimDot(hitbox.Position),
                    maxRange = getKillRange("Spider"),
                    remoteCount = (remote and remote:IsA("RemoteEvent")) and 1 or 0,
                    remotes = (remote and remote:IsA("RemoteEvent")) and {remote} or {},
                    lockStarted = os.clock(),
                    lastNoRemoteNotice = 0,
                })
            end
        end
    end
end

local function refreshKillTarget(target)
    if not target or not target.instance or not target.instance.Parent then return false end

    local hum = target.instance:IsA("Model") and target.instance:FindFirstChildOfClass("Humanoid") or nil
    if hum and hum.Health <= 0 then return false end
    local maxRange = getKillRange(target.kind)
    local anchor, dist

    local nk = normalizeKillKind(target.kind)
    if nk == "Spider" then
        anchor = target.instance:FindFirstChild("Hitbox")
        if anchor then dist = getDistance(anchor) end
    elseif nk == "FleshBlock" then
        -- FleshBlock chỉ được tính theo body chính đã lock. Không fallback sang nearest part/parent.
        anchor = target.fleshBody
        if not validPart(anchor) then
            anchor = target.instance:FindFirstChild("body", true) or target.instance:FindFirstChild("Body", true)
        end
        if anchor and validPart(anchor) and tostring(anchor.Name or ""):lower() == "body" then
            dist = getDistance(anchor)
            -- Logic gốc: đang giữ target cũng phải tiếp tục nhìn đúng FleshBlock body.
            if not AutoKillConfig.IsLookingAtFleshBody(anchor) then return false end
        else
            return false
        end
    else
        local hum = target.instance:IsA("Model") and target.instance:FindFirstChildOfClass("Humanoid") or nil
        if hum and hum.Health <= 0 then return false end
        anchor, dist = nearestBasePartOf(target.instance)
    end

    if not anchor or not validPart(anchor) or not dist or dist > maxRange then return false end

    local pos = anchor.Position
    target.anchor = anchor
    target.dist = dist
    target.dot = getAimDot(pos)
    target.cframe = (normalizeKillKind(target.kind) == "Spider" or normalizeKillKind(target.kind) == "FleshBlock") and anchor.CFrame or CFrame.new(pos)
    local remoteRoot = (nk == "Spider" or nk == "FleshBlock") and anchor or target.instance
    local stale = target.remoteRoot ~= remoteRoot or os.clock() >= (target.remoteCheckAt or 0)
    for _, remote in ipairs(target.remotes or {}) do if not remote.Parent then stale = true; break end end
    if stale then
        target.remotes = collectRemoteEvents(remoteRoot)
        target.remoteRoot = remoteRoot
        target.remoteCheckAt = os.clock() + 0.5
    end
    if nk == "FleshBlock" then target.fleshBody = anchor end
    target.remoteCount = #(target.remotes or {})

    return true
end

local function chooseNearbyKillTarget()
    local targets = {}
    collectGataTargets(targets)
    collectGruntTargets(targets)
    collectMukiTargets(targets)
    collectHogoGuntaiTargets(targets)
    collectFleshBlockTargets(targets)
    collectSpiderTargets(targets)
    if #targets == 0 then return nil end

    table.sort(targets, function(a, b)
        local ak = normalizeKillKind(a.kind)
        local bk = normalizeKillKind(b.kind)

        -- Nếu có Hogo và FleshBlock cùng hợp lệ, ưu tiên Hogo trước.
        if (ak == "Hogo" and bk == "FleshBlock") or (ak == "FleshBlock" and bk == "Hogo") then
            return ak == "Hogo"
        end

        -- Ưu tiên mục tiêu đang gần tâm màn hình hơn; nếu tương đương thì lấy gần hơn.
        local aLook = a.dot >= 0.45
        local bLook = b.dot >= 0.45
        if aLook ~= bLook then return aLook end
        if math.abs(a.dot - b.dot) > 0.12 then return a.dot > b.dot end

        -- Với creep/boss lớn, part gần nhất đáng tin hơn pivot. Spider giữ gần nhất.
        return a.dist < b.dist
    end)

    return targets[1]
end

local function fireNearbyKillOnce(target, gunAction)
    if not refreshKillTarget(target) then return false end

    -- Silent camera replica: không xoay camera thật, chỉ cấp vị trí target cho hook updateState.
    CAMERAREPLICA = target.cframe
    CameraReplicaBridge:Set(target.cframe)

    pcall(function()
        if gunAction and gunAction.Parent then
            gunAction:FireServer("fire")
        end
    end)

    local fired = false
    local remotes = target.remotes or {}

    for i, remote in ipairs(remotes) do
        if i > 8 then break end
        if remote and remote.Parent then
            local ok = pcall(function()
                remote:FireServer()
            end)
            fired = ok or fired
        end
    end

    if not fired and target.kind ~= "Spider" then
        -- FleshBlock chủ yếu dùng GunAction + camera replica vào body; không fire remote parent để tránh bắn toàn bộ.
        if normalizeKillKind(target.kind) ~= "FleshBlock" and os.clock() - (target.lastNoRemoteNotice or 0) > 4 then
            target.lastNoRemoteNotice = os.clock()
            warn(("[Nevoirs] %s trong range nhưng chưa tìm thấy RemoteEvent target; vẫn thử GunAction."):format(tostring(target.kind)))
        end
        fired = true
    end

    return fired
end

-- One camera-prioritized target. The selector and shooting sequence come from cc.
local NearbyCamera = {alive = true, generation = 0}

function NearbyCamera:ClearTarget()
    AutoNearbyKillTarget = nil
    CAMERAREPLICA = nil
    CameraReplicaBridge:Set(nil)
end

function NearbyCamera:SetEnabled(enabled)
    if not self.alive then return end
    enabled = enabled and true or false
    if enabled and States.AutoNearbyKill and AutoNearbyKillRunning then return end
    self.generation += 1
    local generation = self.generation
    States.AutoNearbyKill = enabled
    AutoNearbyKillRunning = enabled
    self:ClearTarget()
    if not enabled then return end

    task.spawn(function()
        local gunAction, character = nil, nil
        local nextRemoteCheck, nextHookCheck = -math.huge, -math.huge
        local okWorker, workerErr = xpcall(function()
            while self.alive and States.AutoNearbyKill and generation == self.generation do
                local now = os.clock()
                local current = getChar()
                local humanoid = current and current:FindFirstChildOfClass("Humanoid")
                local root = getHRP(current)
                if current ~= character then
                    character = current
                    gunAction = nil
                    nextRemoteCheck = -math.huge
                    self:ClearTarget()
                end
                if not current or not root or not humanoid or humanoid.Health <= 0 then
                    self:ClearTarget()
                    task.wait(0.25)
                else
                    if now >= nextRemoteCheck or (gunAction and not gunAction.Parent) then
                        gunAction = getGunActionRemote()
                        nextRemoteCheck = now + 2
                    end
                    if now >= nextHookCheck then
                        installCameraReplicaHook()
                        nextHookCheck = now + 3
                    end
                    if gunAction then
                        local target = AutoNearbyKillTarget
                        if not refreshKillTarget(target)
                            or (target.lockStarted and now - target.lockStarted > TARGET_RELOCK_INTERVAL) then
                            target = chooseNearbyKillTarget()
                            AutoNearbyKillTarget = target
                            if target then target.lockStarted = now end
                        end
                        if target then
                            fireNearbyKillOnce(target, gunAction)
                            task.wait(getAutoKillFireDelay())
                        else
                            self:ClearTarget()
                            task.wait(0.25)
                        end
                    else
                        self:ClearTarget()
                        task.wait(0.25)
                    end
                end
            end
        end, function(err) return debug.traceback(tostring(err), 2) end)
        -- A stopped worker must never clear a newer worker's camera target.
        if generation == self.generation then
            States.AutoNearbyKill = false
            AutoNearbyKillRunning = false
            self:ClearTarget()
        end
        if not okWorker then warn("[Nevoirs] Nearby Kill camera worker lỗi:", workerErr) end
    end)
end

function NearbyCamera:Destroy()
    if not self.alive then return end
    self:SetEnabled(false)
    self.alive = false
    CameraReplicaBridge:Release()
end

local function toggleAutoNearbyKill(enabled) NearbyCamera:SetEnabled(enabled) end

-- ══════════════════════════════════════════════════════════════════════════════

-- B3C1 PHASE ACTIONS
-- Phase actions: giữ logic B3C1 cần thiết, không còn các nhánh Brutal đã loại bỏ.
-- ══════════════════════════════════════════════════════════════════════════════
local Phase = (function()
    -- One explicit action at a time. No chained chapter automation or kill/TP loop.
    local alive, busy, generation = true, false, 0
    local useTeleport = true
    local frozenSpider = nil
    local freezeAccumulator = 0

    local function notify(title, message)
        smallNotify(title, message, NEVOIRS_UI_ICON)
    end

    local function objectCFrame(obj)
        if not obj or not obj.Parent then return nil end
        if obj:IsA("BasePart") then return obj.CFrame end
        if obj:IsA("Model") then
            local ok, cf = pcall(function() return obj:GetPivot() end)
            if ok then return cf end
        end
        local root = rootOf(obj)
        return root and root.CFrame or nil
    end

    local function restoreSpider(announce)
        local saved = frozenSpider
        frozenSpider = nil
        if saved then
            local restored = false
            local ok = pcall(function()
                if saved.parent.Parent and saved.bone.Parent == nil then
                    saved.bone.Parent = saved.parent
                    restored = true
                end
            end)
            if announce then
                notify("Spider", ok and restored and "Đã khôi phục rig local còn tồn tại." or "Rig đã đổi; không thể khôi phục bản cũ.")
            end
        elseif announce then
            notify("Spider", "Không có rig local đang tạm giữ.")
        end
    end

    local function validContext(ctx, target)
        if not alive or generation ~= ctx.generation or getChar() ~= ctx.character then return false end
        if not ctx.root.Parent or getHRP(ctx.character) ~= ctx.root then return false end
        local hum = ctx.character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then return false end
        if ctx.section and (not ctx.section.Parent or Workspace:FindFirstChild(ctx.section.Name) ~= ctx.section) then return false end
        if target and (not target.Parent or not target:IsDescendantOf(Workspace)) then return false end
        return true
    end

    local function waitContext(ctx, duration, target)
        local deadline = os.clock() + duration
        repeat
            if not validContext(ctx, target) then return false end
            local remaining = deadline - os.clock()
            if remaining <= 0 then return true end
            task.wait(math.min(0.05, remaining))
        until false
    end

    local function runAction(title, sectionName, callback)
        if not alive then return end
        if busy then return notify(title, "Một thao tác đang chạy; chờ hoặc bấm Hủy thao tác Main.") end
        local character = getChar()
        local root = getHRP(character)
        local section = sectionName and safeFolder({sectionName}) or nil
        if not root or (sectionName and not section) then
            return notify(title, "Chưa có nhân vật hoặc khu nhiệm vụ chưa được tải.")
        end
        busy = true
        local ctx = {character = character, root = root, section = section, generation = generation, title = title}
        local ok, err = xpcall(function()
            if validContext(ctx) then callback(ctx) end
        end, function(e) return debug.traceback(tostring(e), 2) end)
        if generation == ctx.generation then busy = false end
        if not ok then
            warn("[Nevoirs] Main action:", title, err)
            notify(title, "Thao tác gặp lỗi; chưa xác nhận hoàn tất.")
        end
    end

    local function moveTo(ctx, cf, target)
        if typeof(cf) ~= "CFrame" or not validContext(ctx, target) then return false end
        local ok = pcall(function()
            ctx.root.AssemblyLinearVelocity = Vector3.zero
            ctx.root.AssemblyAngularVelocity = Vector3.zero
            ctx.root.CFrame = cf
        end)
        if not ok or not waitContext(ctx, 0.15, target) then return false end
        if (ctx.root.Position - cf.Position).Magnitude > 10 then
            notify(ctx.title, "Vị trí chưa ổn định; đã dừng trước khi tương tác.")
            return false
        end
        return true
    end

    local function promptEligible(prompt)
        return prompt and prompt.Parent and prompt:IsA("ProximityPrompt") and prompt.Enabled
            and prompt:IsDescendantOf(Workspace) and validPart(promptAnchor(prompt))
    end

    local function promptFinished(prompt, target)
        return not target.Parent or not prompt.Parent or not prompt:IsDescendantOf(Workspace) or not prompt.Enabled
    end

    local function interactOne(ctx, prompt, target)
        target = target or (prompt and prompt.Parent)
        if not validContext(ctx, target) or not promptEligible(prompt) then
            return notify(ctx.title, "Chưa có tương tác hợp lệ ở tiến độ hiện tại.")
        end
        local anchor = promptAnchor(prompt)
        if useTeleport and not moveTo(ctx, anchor.CFrame + Vector3.new(0, 1.5, 0), target) then return end
        if not validContext(ctx, target) or not promptEligible(prompt) then return end
        if not useTeleport and (ctx.root.Position - anchor.Position).Magnitude > prompt.MaxActivationDistance + 2 then
            return notify(ctx.title, "Đang ngoài tầm tương tác; tới gần hoặc bật TP tới mục tiêu.")
        end
        if type(fireproximityprompt) ~= "function" then
            return notify(ctx.title, "Executor chưa cung cấp fireproximityprompt.")
        end
        -- Retry another signature only on a client call error, never send all signatures.
        local duration = math.max(0, tonumber(prompt.HoldDuration) or 0)
        local ok, err = pcall(fireproximityprompt, prompt, duration)
        if not ok and validContext(ctx, target) and promptEligible(prompt) then
            ok, err = pcall(fireproximityprompt, prompt)
        end
        if not ok then
            warn("[Nevoirs] Prompt action:", err)
            return notify(ctx.title, "Không gửi được tương tác; chưa xác nhận hoàn tất.")
        end
        local deadline = os.clock() + 1.8
        repeat
            if not validContext(ctx) then return end
            if promptFinished(prompt, target) then
                return notify(ctx.title, "Tương tác đã đổi trạng thái. Kiểm tra tiến độ trong game.")
            end
            if not waitContext(ctx, 0.08) then return end
        until os.clock() >= deadline
        notify(ctx.title, "Đã gửi tương tác cho 1 mục; chưa thấy xác nhận hoàn tất.")
    end

    local function pathPrompt(path)
        local obj = safeFolder(path)
        if obj and obj:IsA("ProximityPrompt") then return obj end
        return obj and obj:FindFirstChildWhichIsA("ProximityPrompt", true) or nil
    end

    local function selectPrompt(folder, accept)
        local best, distance = nil, math.huge
        if not folder then return nil end
        for _, obj in ipairs(folder:GetChildren()) do
            if not accept or accept(obj) then
                local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if promptEligible(prompt) then
                    local d = getDistance(promptAnchor(prompt))
                    if d < distance then best, distance = {prompt = prompt, target = obj}, d end
                end
            end
        end
        return best
    end

    local function promptAction(title, sectionName, path)
        runAction(title, sectionName, function(ctx)
            interactOne(ctx, pathPrompt(path))
        end)
    end

    local function pointAction(title, sectionName, cf, target)
        runAction(title, sectionName, function(ctx)
            local dest = type(cf) == "function" and cf() or cf
            if typeof(dest) ~= "CFrame" then return notify(title, "Chưa tìm thấy điểm đến trong khu hiện tại.") end
            if moveTo(ctx, dest, target) then
                notify(title, "Đã tới điểm chọn; không tự chạy nhiệm vụ tiếp theo.")
            end
        end)
    end

    local function callPacket(channel, ...)
        if not channel then return false end
        local args = table.pack(...)
        local ok, sent = pcall(function()
            if typeof(channel) == "Instance" then
                if channel:IsA("RemoteEvent") then
                    channel:FireServer(table.unpack(args, 1, args.n))
                    return true
                elseif channel:IsA("RemoteFunction") then
                    channel:InvokeServer(table.unpack(args, 1, args.n))
                    return true
                end
            elseif type(channel) == "table" then
                if type(channel.FireServer) == "function" then
                    channel:FireServer(table.unpack(args, 1, args.n))
                    return true
                elseif type(channel.InvokeServer) == "function" then
                    channel:InvokeServer(table.unpack(args, 1, args.n))
                    return true
                end
            end
            return false
        end)
        return ok and sent == true
    end

    local function interactBody()
        runAction("Kiểm tra 1 xác", "Section1", function(ctx)
            local candidate = selectPrompt(safeFolder({"Section1", "DeadCivilians"}))
            if not candidate then return notify(ctx.title, "Không có xác chưa kiểm tra với prompt hợp lệ.") end
            interactOne(ctx, candidate.prompt, candidate.target)
        end)
    end

    local function grabCutter()
        promptAction("Bolt cutter", "Section1", {"Section1", "SchoolGatePart", "Truck", "BoltCutter", "Main", "ProximityPrompt"})
    end

    local function cutChain()
        promptAction("Cắt 1 lượt xích", "Section1", {"Section1", "SchoolGatePart", "Gate", "Chain", "PromptPart", "ProximityPrompt"})
    end

    local function grabMedicalKit()
        promptAction("Medical Kit", "Section2", {"Section2", "Items", "Bandage", "Handle", "ProximityPrompt"})
    end

    local function healHideo()
        -- Known packet sequence from cc/229; source has no proven session/GUI schema.
        -- This is a single explicit button action, never a background worker or TP route.
        runAction("Heal Hideo", "Section2", function(ctx)
            local reliable = getReliablePacket()
            if not reliable then return notify(ctx.title, "Không tìm thấy Packet Reliable.") end
            for _, event in ipairs({"Section2/HideoMinigameStarted", "Section2/HideoHealed", "Section2/HideoMinigameEnded"}) do
                if not validContext(ctx) then return end
                if not callPacket(reliable, event) then
                    return notify(ctx.title, "Gửi yêu cầu thất bại; chưa xác nhận chữa xong.")
                end
            end
            notify(ctx.title, "Đã gửi yêu cầu chữa. Cần bandage/phiên chữa hợp lệ; kiểm tra tiến độ game.")
        end)
    end

    local function openLocker()
        promptAction("Mở locker", "Section2", {"Section2", "MAINOBJECTIVE", "Locker", "LockerDoor", "ProximityPart", "ProximityPrompt"})
    end

    local function readDiary()
        promptAction("Đọc diary", "Section2", {"Section2", "MAINOBJECTIVE", "Diary", "ProximityPrompt"})
    end

    local function exitSchool()
        promptAction("Mở cửa ra trường", "Section2", {"Section2", "School", "Doors", "ExitDoor", "ProxPart", "ProximityPrompt"})
    end

    local function freezeOneSpider()
        if not alive then return end
        if frozenSpider then restoreSpider(false) end
        local folder = safeFolder({"Section2", "MAINOBJECTIVE2", "Spiders"})
        local nearest, best = nil, math.huge
        for _, spider in ipairs(folder and folder:GetChildren() or {}) do
            local root = spider.Name == "AkariSpider" and spider:FindFirstChild("RootPart")
            local bone = root and root:FindFirstChild("Bone")
            if bone and validPart(root) then
                local distance = getDistance(root)
                if distance < best then nearest, best = {model = spider, parent = root, bone = bone}, distance end
            end
        end
        if not nearest then return notify("Freeze Spider", "Chưa thấy RootPart.Bone phù hợp; không đổi rig khác.") end
        local ok = pcall(function() nearest.bone.Parent = nil end)
        if not ok then return notify("Freeze Spider", "Không thể tạm giữ rig local trên executor này.") end
        frozenSpider = nearest
        frozenSpider.character = getChar()
        notify("Freeze Spider", "Đã tạm tách Bone của 1 Spider ở client. Chưa xác nhận NPC trên server dừng.")
    end

    local function grabKeycard()
        promptAction("Keycard cửa Lab", "Section4", {"Section4", "Lab", "Floor1", "Entrance", "IDCARD", "ProximityPrompt"})
    end

    local function readLaptopPassword()
        if not alive then return end
        -- Read-only: never teleport, copy clipboard, submit a password, or reuse stale data.
        local label = safeFolder({"Section4", "Lab", "Floor1", "Objective", "StickyNote", "PASSWORD", "SurfaceGui", "RandomNumber"})
        local ok, code = pcall(function()
            return label and (label:IsA("TextLabel") or label:IsA("TextBox")) and label.Text or nil
        end)
        if not ok or type(code) ~= "string" or not code:find("%S") then
            return notify("Mã laptop", "Chưa đọc được mã hiện tại. Khu/vật thể có thể chưa được tải.")
        end
        code = code:gsub("<[^>]*>", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if code == "" then return notify("Mã laptop", "Chưa có mã hiện tại.") end
        notify("Mã laptop", "Mã hiện tại: " .. code)
    end

    local function placeC4(stage)
        runAction("Đặt 1 C4 #" .. stage, "Section4", function(ctx)
            local folder = safeFolder({"Section4", "Lab", "Floor1", stage == 1 and "Objective2" or "Objective3", "C4Explode"})
            local candidate = selectPrompt(folder, function(obj) return obj.Name == "C4Bomb" end)
            if not candidate then
                return notify(ctx.title, "Chưa có C4 hợp lệ; cần mở đúng giai đoạn trước.")
            end
            -- Objective3 being loaded with an enabled prompt is required. Do not replay
            -- the old two-tween route or silently advance a preceding objective.
            interactOne(ctx, candidate.prompt, candidate.target)
        end)
    end

    local function hitSkillCheck()
        runAction("Lock Threat • 1 nhịp", "Section4", function(ctx)
            if not safeFolder({"Section4", "Lab"}) then return notify(ctx.title, "Lab chưa được tải.") end
            if callPacket(getReliablePacket(), "Section4/LockdownSkillCheckHit") then
                notify(ctx.title, "Đã gửi 1 nhịp. Chỉ có tác dụng khi bạn đã mở đúng minigame.")
            else
                notify(ctx.title, "Không gửi được nhịp; chưa xác nhận kết quả.")
            end
        end)
    end

    local function activateMainSwitch()
        promptAction("Main Switch", "Section5", {"Section5", "MainObjective", "PowerSwitch", "RootPart", "ProximityPrompt"})
    end

    local function cancelAction(announce)
        generation += 1
        busy = false
        if announce then notify("Main", "Đã hủy các bước còn chờ. Thao tác đã gửi không thể thu hồi.") end
    end

    local respawnConnection = LocalPlayer.CharacterAdded:Connect(function()
        cancelAction(false)
        restoreSpider(false)
    end)
    local heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        freezeAccumulator += dt
        if freezeAccumulator < 0.8 then return end
        freezeAccumulator = 0
        if frozenSpider and (getChar() ~= frozenSpider.character or not frozenSpider.model.Parent) then restoreSpider(false) end
    end)

    return {
        setTeleport = function(enabled) useTeleport = enabled and true or false end,
        cancel = function() cancelAction(true) end,
        interactAllBodies = interactBody,
        grabCutter = grabCutter,
        cutChain = cutChain,
        tpMika = function()
            local trigger = safeFolder({"Section1", "Monster", "Trigger"})
            pointAction("TP Mika", "Section1", objectCFrame(trigger), trigger)
        end,
        tpCityHideo = function()
            local hideo = safeFolder({"Section1", "HideoScene", "Hideo2"})
            pointAction("TP Hideo City", "Section1", objectCFrame(hideo), hideo)
        end,
        grabMedicalKit = grabMedicalKit,
        tpSchoolHideo = function() pointAction("TP Hideo School", "Section2", CFrame.new(175, 8, 338)) end,
        healHideo = healHideo,
        tpLocker = function() pointAction("TP Locker", "Section2", CFrame.new(143, 20, 504)) end,
        openLocker = openLocker,
        readDiary = readDiary,
        exitSchool = exitSchool,
        tpSchoolExit = function() pointAction("TP cửa ra trường", "Section2", CFrame.new(175, 8, 508)) end,
        tpForest = function() pointAction("TP Forest", "Section2", CFrame.new(-197, 50, 338)) end,
        freezeOneSpider = freezeOneSpider,
        restoreSpider = function() restoreSpider(true) end,
        tpForestCave = function()
            local target = safeFolder({"Section3", "Trigger"})
            pointAction("TP cửa hang", "Section3", objectCFrame(target), target)
        end,
        tpIJOEntrance = function()
            local target = safeFolder({"Section3", "OBJECTIVE", "Trigger2"})
            pointAction("TP IJO Entrance", "Section3", objectCFrame(target), target)
        end,
        grabKeycard = grabKeycard,
        readLaptopPassword = readLaptopPassword,
        placeC4First = function() placeC4(1) end,
        placeC4Second = function() placeC4(2) end,
        tpIJOExit = function() pointAction("TP lối ra IJO", "Section4", CFrame.new(-3379, -300, 4451)) end,
        hitSkillCheck = hitSkillCheck,
        tpStairEnd = function()
            local target = safeFolder({"Section5", "StairsSection", "EndTrigger"})
            pointAction("TP cuối cầu thang", "Section5", objectCFrame(target), target)
        end,
        activateMainSwitch = activateMainSwitch,
        cleanup = function()
            if not alive then return end
            alive = false
            cancelAction(false)
            restoreSpider(false)
            respawnConnection:Disconnect()
            heartbeatConnection:Disconnect()
        end,
    }
end)()

-- ══════════════════════════════════════════════════════════════════════════════
-- UI: WindUI compact layout (mobile + PC balanced)
-- Logic phía trên được giữ nguyên; block này chỉ đổi giao diện và input tốc độ.
-- ══════════════════════════════════════════════════════════════════════════════
function clampNumber(value, minValue, maxValue, fallback)
    local n
    local t = typeof(value)

    if t == "number" then
        n = value
    elseif t == "string" then
        n = tonumber((value:gsub(",", ".")))
    elseif t == "Instance" then
        pcall(function()
            if value:IsA("TextBox") or value:IsA("TextLabel") or value:IsA("TextButton") then
                n = tonumber((value.Text or ""):gsub(",", "."))
            end
        end)
    elseif t == "table" then
        for _, key in ipairs({"Value", "value", "Text", "text", "Input", "input", "CurrentValue", "currentValue"}) do
            local ok, raw = pcall(function() return value[key] end)
            if ok and raw ~= nil then
                local got = clampNumber(raw, minValue, maxValue, nil)
                if got ~= nil then
                    n = got
                    break
                end
            end
        end
    else
        n = tonumber(tostring(value or ""):gsub(",", "."))
    end

    if not n then return fallback end
    if n ~= n or n == math.huge or n == -math.huge then return fallback end
    return math.clamp(n, minValue, maxValue)
end

function loadWindUI()
    local sources = {
        "https://raw.githubusercontent.com/eystearisdown/wyattrz/main/ui.lua",
    }

    local function cacheBust(url)
        local sep = url:find("?", 1, true) and "&" or "?"
        local stamp = tostring(os.time()) .. "-" .. tostring(math.floor((os.clock() or 0) * 1000000)) .. "-" .. tostring(math.random(100000, 999999))
        return url .. sep .. "nevoirs_cb=" .. stamp
    end

    local function badSource(source)
        if type(source) ~= "string" then
            return true, "source_not_string"
        end
        if #source < 1024 then
            return true, "source_too_short_" .. tostring(#source)
        end

        local head = source:sub(1, 6000)
        local lower = head:lower()
        if source:sub(1, 3) == "429" or lower:find("too many requests", 1, true) then
            return true, "github_429"
        end
        if lower:find("<!doctype", 1, true) or lower:find("<html", 1, true) then
            return true, "html_response"
        end
        if lower:find("rate limit", 1, true) then
            return true, "rate_limited"
        end
        if lower:find("not found", 1, true) and #source < 10000 then
            return true, "not_found"
        end

        return false, nil
    end

    local lastErr = "unknown"

    for attempt = 1, 2 do
        for index, baseUrl in ipairs(sources) do
            local url = cacheBust(baseUrl)
            local okGet, source = pcall(function()
                return game:HttpGet(url, true)
            end)

            if okGet then
                local bad, reason = badSource(source)
                if not bad then
                    local fn, loadErr = loadstring(source)
                    if fn then
                        local okRun, lib = pcall(fn)
                        if okRun and lib then
                            warn("[Nevoirs] WindUI loaded from source #" .. tostring(index) .. " attempt " .. tostring(attempt))
                            return lib
                        end
                        lastErr = "run_failed_source_" .. tostring(index) .. ": " .. tostring(lib)
                    else
                        lastErr = "compile_failed_source_" .. tostring(index) .. ": " .. tostring(loadErr)
                    end
                else
                    lastErr = "bad_source_" .. tostring(index) .. ": " .. tostring(reason)
                end
            else
                lastErr = "http_failed_source_" .. tostring(index) .. ": " .. tostring(source)
            end
        end
        task.wait(0.35 * attempt)
    end

    warn("[Nevoirs] WindUI load failed: " .. tostring(lastErr))
    return nil
end


function __InstallCompactNotify(ui, fallbackTitle)
    if not ui or ui.__FiHonCompactNotifyInstalled then return end
    ui.__FiHonCompactNotifyInstalled = true

    local Players_Notify = game:GetService("Players")
    local TweenService_Notify = game:GetService("TweenService")
    local UserInputService_Notify = game:GetService("UserInputService")
    local LocalPlayer_Notify = Players_Notify.LocalPlayer
    local DEFAULT_NOTIFY_ICON = rawget(_G, "NEVOIRS_UI_ICON") or (typeof(NEVOIRS_UI_ICON) == "string" and NEVOIRS_UI_ICON) or "rbxassetid://17617869383"

    local function resolveNotifyIcon(icon)
        icon = tostring(icon or "")
        if icon:find("rbxassetid://", 1, true) then return icon end
        if icon:match("^%d+$") then return "rbxassetid://" .. icon end
        return DEFAULT_NOTIFY_ICON
    end

    local function getNotifyHolder()
        local pg = LocalPlayer_Notify and LocalPlayer_Notify:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end

        local gui = pg:FindFirstChild("FiHon_CompactNotifications")
        if not gui then
            gui = Instance.new("ScreenGui")
            gui.Name = "FiHon_CompactNotifications"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.DisplayOrder = 999999
            gui.Parent = pg
        end

        local holder = gui:FindFirstChild("Holder")
        if not holder then
            holder = Instance.new("Frame")
            holder.Name = "Holder"
            holder.AnchorPoint = Vector2.new(1, 1)
            holder.Position = UDim2.new(1, -8, 1, -12)
            holder.BackgroundTransparency = 1
            holder.BorderSizePixel = 0
            holder.Parent = gui

            local layout = Instance.new("UIListLayout")
            layout.Name = "Layout"
            layout.FillDirection = Enum.FillDirection.Vertical
            layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 4)
            layout.Parent = holder
        end

        local width = UserInputService_Notify.TouchEnabled and 206 or 224
        holder.Size = UDim2.new(0, width, 1, -24)
        return holder
    end

    local function compactNotify(payload)
        payload = (typeof(payload) == "table") and payload or { Content = tostring(payload or "") }
        local holder = getNotifyHolder()
        if not holder then return end

        local touch = UserInputService_Notify.TouchEnabled
        local w = touch and 206 or 224
        local h = touch and 44 or 48
        local duration = 2

        local card = Instance.new("Frame")
        card.Name = "CompactNotify"
        card.Size = UDim2.fromOffset(w, h)
        card.LayoutOrder = math.floor(os.clock() * 100000)
        card.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
        card.BackgroundTransparency = 1
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.Parent = holder

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = card

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Transparency = 1
        stroke.Color = Color3.fromRGB(78, 158, 230)
        stroke.Parent = card

        local iconImg = Instance.new("TextLabel")
        iconImg.Name = "Icon"
        iconImg.BackgroundTransparency = 1
        iconImg.Position = UDim2.fromOffset(10, touch and 8 or 9)
        iconImg.Size = UDim2.fromOffset(touch and 22 or 24, touch and 26 or 28)
        iconImg.Font = Enum.Font.GothamBold
        iconImg.Text = NEVOIRS_BRAND_TEXT
        iconImg.TextSize = touch and 14 or 15
        iconImg.TextColor3 = NEVOIRS_BRAND_COLOR
        iconImg.TextTransparency = 1
        iconImg.Parent = card
        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(touch and 39 or 43, 5)
        title.Size = UDim2.new(1, touch and -48 or -54, 0, touch and 15 or 17)
        title.Font = Enum.Font.GothamSemibold
        title.TextSize = touch and 11 or 12
        title.TextColor3 = Color3.fromRGB(245, 247, 255)
        title.TextTransparency = 1
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextYAlignment = Enum.TextYAlignment.Center
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.RichText = true
        title.Text = tostring(payload.Title or fallbackTitle or "Notification")
        title.Parent = card

        local content = Instance.new("TextLabel")
        content.Name = "Content"
        content.BackgroundTransparency = 1
        content.Position = UDim2.fromOffset(touch and 39 or 43, touch and 22 or 24)
        content.Size = UDim2.new(1, touch and -48 or -54, 0, touch and 17 or 18)
        content.Font = Enum.Font.Gotham
        content.TextSize = touch and 9 or 10
        content.TextColor3 = Color3.fromRGB(215, 222, 235)
        content.TextTransparency = 1
        content.TextXAlignment = Enum.TextXAlignment.Left
        content.TextYAlignment = Enum.TextYAlignment.Top
        content.TextWrapped = false
        content.TextTruncate = Enum.TextTruncate.AtEnd
        content.RichText = true
        content.Text = tostring(payload.Content or payload.Text or "")
        content.Parent = card

        pcall(function()
            TweenService_Notify:Create(card, TweenInfo.new(0.12), {BackgroundTransparency = 0.36}):Play()
            TweenService_Notify:Create(stroke, TweenInfo.new(0.12), {Transparency = 0.50}):Play()
            TweenService_Notify:Create(iconImg, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
            TweenService_Notify:Create(title, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
            TweenService_Notify:Create(content, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
        end)

        task.delay(duration, function()
            if not card or not card.Parent then return end
            pcall(function()
                TweenService_Notify:Create(card, TweenInfo.new(0.16), {BackgroundTransparency = 1}):Play()
                TweenService_Notify:Create(stroke, TweenInfo.new(0.16), {Transparency = 1}):Play()
                TweenService_Notify:Create(iconImg, TweenInfo.new(0.16), {TextTransparency = 1}):Play()
                TweenService_Notify:Create(title, TweenInfo.new(0.16), {TextTransparency = 1}):Play()
                TweenService_Notify:Create(content, TweenInfo.new(0.16), {TextTransparency = 1}):Play()
            end)
            task.wait(0.18)
            pcall(function() card:Destroy() end)
        end)

        return card
    end

    ui.__FiHonOriginalNotify = ui.Notify
    ui.Notify = function(self, payload)
        if payload == nil and typeof(self) == "table" and (self.Title or self.Content or self.Text or self.Duration) then
            payload = self
        end
        return compactNotify(payload)
    end
end


local runtimeCleanupDone = false
local function cleanupNevoirsRuntime()
    if runtimeCleanupDone then return end
    runtimeCleanupDone = true
    InstantInteract:stop()
    TaskAssist.cancel()

    States.TPWalk = false
    States.Noclip = false
    States.Moonwalk = false
    States.InfiniteJump = false
    States.Fullbright = false
    States.VFly = false
    States.ESPPlayer = false
    States.ESPMonster = false
    States.ESPTaskMaster = false
    States.ESPTaskBody = false
    States.ESPTaskSpider = false
    States.ESPTaskGenerator = false
    States.ESPTaskTerminal = false
    States.ESPTaskValve = false
    States.ESPTaskWire = false
    States.ESPTaskDirector = false
    States.ESPTaskExtra = false
    States.AutoNearbyKill = false
    States.AutoYenESP = false
    States.AutoYenCollect = false

    CAMERAREPLICA = nil
    AutoNearbyKillTarget = nil
    if NearbyCamera then pcall(function() NearbyCamera:Destroy() end) end
    if Phase and Phase.cleanup then pcall(Phase.cleanup) end
    if Extra and Extra.cleanup then pcall(Extra.cleanup) end

    local function disconnect(conn)
        if conn then pcall(function() conn:Disconnect() end) end
    end

    disconnect(tpwalkConn); tpwalkConn = nil
    disconnect(noclipConn); noclipConn = nil
    disconnect(moonwalkConn); moonwalkConn = nil
    disconnect(ijConn); ijConn = nil
    disconnect(fbConn); fbConn = nil
    disconnect(vflyConn); vflyConn = nil
    disconnect(vflyStateConn); vflyStateConn = nil
    disconnect(taskPollConn); taskPollConn = nil
    disconnect(characterAddedConn); characterAddedConn = nil
    disconnect(playerGuiDescConn); playerGuiDescConn = nil

    for _, conn in ipairs(playerCharConns) do disconnect(conn) end
    table.clear(playerCharConns)

    for cat in pairs(pollConns) do
        stopPoll(cat)
    end
    for cat in pairs(espPool) do
        clearPool(cat)
    end

    restoreNoclipCollision()
    clearMoonwalkAutoRotate()
    cleanVFly()
    if vflyHumanoid and vflyHumanoid.Parent and vflyOldWalkSpeed ~= nil then
        pcall(function()
            vflyHumanoid.WalkSpeed = vflyOldWalkSpeed
            vflyHumanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
    vflyHumanoid = nil
    vflyOldWalkSpeed = nil

    pcall(function()
        Lighting.Brightness = OrigLighting.Brightness
        Lighting.GlobalShadows = OrigLighting.GlobalShadows
        Lighting.OutdoorAmbient = OrigLighting.OutdoorAmbient
        Lighting.Ambient = OrigLighting.Ambient
        Lighting.FogEnd = OrigLighting.FogEnd
    end)

    pcall(function() if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end end)

    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, name in ipairs({"Nevoirs_LeftToggle_UI", "FiHon_CompactNotifications"}) do
            local gui = pg:FindFirstChild(name)
            if gui then pcall(function() gui:Destroy() end) end
        end
    end

    pcall(function()
        if Window and Window.Destroy then Window:Destroy() end
    end)
end

_G.__NevoirsB3C1Cleanup = cleanupNevoirsRuntime

WindUI = loadWindUI()
if not WindUI then
    warn("[Nevoirs - Rage] Không tải được WindUI. Hãy kiểm tra HttpGet/GitHub trong executor.")
    cleanupNevoirsRuntime()
    return
end

pcall(function() WindUI:SetTheme("Dark") end)
pcall(function() WindUI.TransparencyValue = 0.12 end)
pcall(function() __InstallCompactNotify(WindUI, "Nevoirs") end)

-- Setting Auto Nearby Kill giờ nằm trực tiếp trong WindUI (không còn overlay riêng).
setFireSettingsPanelVisible = function(_) end

function getWindowSize()
    local camera = Workspace.CurrentCamera or workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 600)
    local touch = UserInputService.TouchEnabled
    local small = touch or viewport.X < 760 or viewport.Y < 460
    local ratio = 1.55 -- gần 4:3 nhưng kéo ngang dài hơn một chút; sidebar đã thu gọn để nhường main

    if small then
        local h = math.clamp(math.floor(viewport.Y * 0.78), 320, 430)
        local maxW = math.max(420, math.min(math.floor(viewport.X * 0.92), 680))
        local minW = math.min(480, maxW)
        local w = math.clamp(math.floor(h * ratio), minW, maxW)
        return UDim2.fromOffset(w, h), Vector2.new(w, h), Vector2.new(w, h), 118, false
    end

    return UDim2.fromOffset(650, 420), Vector2.new(650, 420), Vector2.new(650, 420), 122, false
end

windowSize, minSize, maxSize, sidebarWidth, canResize = getWindowSize()
openButtonScale = UserInputService.TouchEnabled and 0.72 or 0.66
BASE_UI_SCALE = UserInputService.TouchEnabled and 0.62 or 0.60
DEFAULT_UI_SCALE = getNumberSetting("UIScale", BASE_UI_SCALE, 0.58, 0.90)
BASE_TOGGLE_SIZE_SCALE = 1
ToggleSizeScale = getNumberSetting("ToggleSizeScale", BASE_TOGGLE_SIZE_SCALE, 0.60, 2.20)

Window = WindUI:CreateWindow({
    Title = "Nevoirs - B3C1",
    Icon = NEVOIRS_WINDOW_ICON,
    Author = "Nevoirs",
    Folder = "Nevoirs_B3C1",
    Size = windowSize,
    MinSize = minSize,
    MaxSize = maxSize,
    ToggleKey = Enum.KeyCode.RightControl,
    Transparent = true,
    Theme = "Dark",
    Resizable = canResize,
    SideBarWidth = sidebarWidth,
    HideSearchBar = true,
    ScrollBarEnabled = true,
    Topbar = {
        Height = UserInputService.TouchEnabled and 64 or 58,
        ButtonsType = "Default",
    },
    OpenButton = {
        Enabled = false,
    },
})

MENU_AVATAR_SIZE = UserInputService.TouchEnabled and 56 or 52

function __isUiChromeAvatar(obj)
    local a = obj
    while a do
        local n = tostring(a.Name or "")
        if n == "FiHon_LeftToggle_UI" or n == "Nevoirs_LeftToggle_UI" or n == "Nevoirs_WorkspaceFinder_Toggle" or n == "FiHon_CompactNotifications" then
            return true
        end
        a = a.Parent
    end
    return false
end

function __isMenuIcon(obj)
    if not (obj and (obj:IsA("ImageLabel") or obj:IsA("ImageButton"))) then return false end
    local image = tostring(obj.Image or "")
    return image == tostring(NEVOIRS_UI_ICON) or image:find("98606201759935", 1, true) ~= nil or image:find("106478063464970", 1, true) ~= nil
end

function styleMenuAvatarImage(obj)
    if not __isMenuIcon(obj) then return end
    -- Giữ màu asset gốc, không tint tím/xanh lên ảnh.
    obj.ImageColor3 = Color3.fromRGB(255, 255, 255)
    obj.ImageTransparency = 0
    obj.ScaleType = Enum.ScaleType.Crop
    obj.ClipsDescendants = true

    local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = obj

    if not __isUiChromeAvatar(obj) then
        obj.Size = UDim2.fromOffset(MENU_AVATAR_SIZE, MENU_AVATAR_SIZE)
        local st = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
        st.Thickness = 1.2
        st.Transparency = 0.15
        st.Color = Color3.fromRGB(78, 158, 230)
        st.Parent = obj
    end
end

function applyMenuAvatarChrome()
    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        pcall(styleMenuAvatarImage, obj)
    end
end

applyMenuAvatarChrome()
task.delay(0.25, applyMenuAvatarChrome)
task.delay(0.8, applyMenuAvatarChrome)
playerGuiDescConn = nil
pcall(function()
    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        playerGuiDescConn = playerGui.DescendantAdded:Connect(function(obj)
            task.defer(function()
                pcall(styleMenuAvatarImage, obj)
            end)
        end)
    end
end)

pcall(function()
    Window:SetUIScale(DEFAULT_UI_SCALE)
end)

pcall(function()
    if Window.EditOpenButton then
        Window:EditOpenButton({ Enabled = false })
    end
end)



-- Toggle tròn bên trái, cùng style Workspace Finder.
windowOpen = true
function toggleNevoirsWindow()
    local ok = false
    pcall(function()
        if Window.Toggle then
            Window:Toggle()
            ok = true
        end
    end)
    if ok then return end

    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
        task.wait()
        vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
        ok = true
    end)
    if ok then return end

    windowOpen = not windowOpen
    pcall(function() if Window.SetVisible then Window:SetVisible(windowOpen) end end)
    pcall(function() if windowOpen and Window.Open then Window:Open() elseif (not windowOpen) and Window.Close then Window:Close() end end)
    pcall(function() if windowOpen and Window.Show then Window:Show() elseif (not windowOpen) and Window.Hide then Window:Hide() end end)
end

function createNevoirsLeftToggle()
    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local old = pg:FindFirstChild("Nevoirs_LeftToggle_UI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Nevoirs_LeftToggle_UI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999998
    gui.Parent = pg

    local scale = math.clamp(tonumber(ToggleSizeScale) or 1, 0.60, 2.20)
    local hitSize = math.floor((UserInputService.TouchEnabled and 46 or 42) * scale)
    local visualSize = math.floor((UserInputService.TouchEnabled and 20 or 18) * scale)
    local btn = Instance.new("ImageButton")
    btn.Name = "NevoirsToggle"
    btn.AnchorPoint = Vector2.new(0, 0.5)
    -- Dịch toggle lên trên một chút, giữ vùng bấm trong suốt để mobile vẫn dễ chạm.
    btn.Position = UDim2.new(0, 12, 0.5, -70)
    btn.Size = UDim2.fromOffset(hitSize, hitSize)
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Image = ""
    btn.Parent = gui

    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.fromScale(0.5, 0.5)
    logo.Size = UDim2.fromOffset(visualSize + 10, visualSize + 10)
    logo.BackgroundColor3 = Color3.fromRGB(13, 18, 28)
    logo.BackgroundTransparency = 0.04
    logo.BorderSizePixel = 0
    logo.Image = NEVOIRS_AVATAR_ID
    logo.ImageColor3 = Color3.fromRGB(255, 255, 255)
    logo.ScaleType = Enum.ScaleType.Crop
    logo.Parent = btn

    local co = Instance.new("UICorner")
    co.CornerRadius = UDim.new(1, 0)
    co.Parent = logo
    local st = Instance.new("UIStroke")
    st.Thickness = 1.2
    st.Transparency = 0.15
    st.Color = NEVOIRS_BRAND_COLOR
    st.Parent = logo

    btn.MouseButton1Click:Connect(toggleNevoirsWindow)
end

createNevoirsLeftToggle()

function applyNevoirsToggleSize()
    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end

    local gui = pg:FindFirstChild("Nevoirs_LeftToggle_UI")
    local btn = gui and gui:FindFirstChild("NevoirsToggle")
    local logo = btn and btn:FindFirstChild("Logo")
    if not btn or not logo then return end

    local scale = math.clamp(tonumber(ToggleSizeScale) or 1, 0.60, 2.20)
    local hitSize = math.floor((UserInputService.TouchEnabled and 46 or 42) * scale)
    local visualSize = math.floor((UserInputService.TouchEnabled and 20 or 18) * scale)

    btn.Size = UDim2.fromOffset(hitSize, hitSize)
    logo.Size = UDim2.fromOffset(visualSize + 8, visualSize + 8)

    local st = logo:FindFirstChildOfClass("UIStroke")
    if st then
        st.Thickness = math.max(1, 1 * scale)
    end
end

applyNevoirsToggleSize()

-- Không ép icon rbxasset thành hình tròn nữa; giữ nguyên style ảnh gốc/WindUI.


pcall(function()
    WindUI:Notify({
        Title = "Nevoirs - B3C1",
        Content = "CC Camera. Nút tròn bên trái để ẩn/hiện menu.",
        Icon = "check",
        Duration = 2,
    })
end)


MainTab    = Window:Tab({ Title = "Main", Icon = "shield" })
CombatTab  = Window:Tab({ Title = "Chiến đấu", Icon = "crosshair" })
ESPTab     = Window:Tab({ Title = "ESP", Icon = "eye" })
PlayerTab  = Window:Tab({ Title = "Cá nhân", Icon = "user" })
SettingTab = Window:Tab({ Title = "Cài đặt", Icon = "settings" })

function safeParagraph(tab, title, desc, icon)
    pcall(function()
        tab:Paragraph({
            Title = title,
            Desc = desc,
            Image = icon,
            ImageSize = 26,
            Color = NEVOIRS_BRAND_COLOR,
        })
    end)
end

function safeDivider(tab)
    pcall(function() tab:Divider() end)
end

COMPACT_CONTROLS = true

function setElementVisible(element, visible)
    if not element then return end
    pcall(function() if element.SetVisible then element:SetVisible(visible) end end)
    pcall(function() if element.Visible ~= nil then element.Visible = visible end end)
    pcall(function() if element.Instance and element.Instance.Visible ~= nil then element.Instance.Visible = visible end end)
    pcall(function() if element.Frame and element.Frame.Visible ~= nil then element.Frame.Visible = visible end end)
    pcall(function() if element.Container and element.Container.Visible ~= nil then element.Container.Visible = visible end end)
    pcall(function() if element.ElementFrame then element.ElementFrame.Visible = visible end end)
    pcall(function() if element.UIElements and element.UIElements.Main then element.UIElements.Main.Visible = visible end end)
    pcall(function() for _, frame in pairs(element) do if type(frame) == "table" and frame.UIElements and frame.UIElements.Main then frame.UIElements.Main.Visible = visible end end end)
end

function addToggle(tab, title, desc, value, callback)
    local ok, element = pcall(function()
        local options = {
            Title = title,
            Value = value and true or false,
            Callback = function(state)
                local okCb, err = pcall(callback, state and true or false)
                if not okCb then warn("[Nevoirs - Rage] Toggle lỗi:", title, err) end
            end,
        }
        if not COMPACT_CONTROLS and desc and desc ~= "" then options.Desc = desc end
        return tab:Toggle(options)
    end)
    if not ok then warn("[Nevoirs - Rage] Không tạo được toggle:", title, element) end
    return element
end

function addButton(tab, title, desc, callback)
    local ok, element = pcall(function()
        local options = {
            Title = title,
            Callback = function()
                task.spawn(function()
                    local okCb, err = pcall(callback)
                    if not okCb then warn("[Nevoirs - Rage] Button lỗi:", title, err) end
                end)
            end,
        }
        if not COMPACT_CONTROLS and desc and desc ~= "" then options.Desc = desc end
        return tab:Button(options)
    end)
    if not ok then warn("[Nevoirs - Rage] Không tạo được button:", title, element) end
    return element
end

function applyNumeric(title, rawValue, minValue, maxValue, callback)
    local value = clampNumber(rawValue, minValue, maxValue, nil)
    if value == nil then
        warn("[Nevoirs - Rage] Giá trị không hợp lệ:", title, tostring(rawValue))
        return
    end
    local okCb, err = pcall(callback, value)
    if not okCb then warn("[Nevoirs - Rage] Number lỗi:", title, err) end
end

function addNumberInput(tab, title, desc, defaultText, minValue, maxValue, callback, stepValue, settingKey)
    local defaultValue = clampNumber(defaultText, minValue, maxValue, minValue)
    local function handle(input)
        local value = clampNumber(input, minValue, maxValue, defaultValue)
        if value == nil then value = defaultValue end
        if settingKey then setSetting(settingKey, value) end
        applyNumeric(title, value, minValue, maxValue, callback)
    end
    local okInput, inputElement = pcall(function()
        local options = {
            Title = title,
            Value = tostring(defaultValue),
            Type = "Input",
            Placeholder = tostring(defaultValue),
            Callback = handle,
        }
        if not COMPACT_CONTROLS and desc and desc ~= "" then options.Desc = desc end
        return tab:Input(options)
    end)
    if not okInput then
        warn("[Nevoirs - Rage] Không tạo được input:", title, inputElement)
    end
    handle(defaultValue)
    return inputElement
end

-- MAIN / B3C1 PHASES
safeParagraph(MainTab, "Nearby Kill", "Ưu tiên mục tiêu theo hướng camera như cc gốc.", "crosshair")
addToggle(MainTab, "Auto Nearby Kill", "Một mục tiêu mỗi nhịp; không tự di chuyển.", false, toggleAutoNearbyKill)

safeDivider(MainTab)
safeParagraph(MainTab, "Thao tác nhiệm vụ", "Mỗi lần bấm xử lý một mục; điều kiện tiến độ vẫn do game quyết định.", "settings-2")
addToggle(MainTab, "TP tới mục tiêu khi tương tác", "Áp dụng xác, đồ nhiệm vụ, xích, locker, C4 và công tắc. Không áp dụng Terminal/Generator/Valve/Wire.", true, Phase.setTeleport)
addButton(MainTab, "Hủy thao tác Main đang chờ", "", Phase.cancel)
safeParagraph(MainTab, "A. City", "Section 1", "map-pin")
addButton(MainTab, "Kiểm tra 1 xác gần nhất", "", Phase.interactAllBodies)
addButton(MainTab, "Nhặt Bolt cutter", "", Phase.grabCutter)
addButton(MainTab, "Cắt xích • 1 lượt", "Cần cutter/tiến độ hợp lệ; không gửi 4 lần liên tiếp.", Phase.cutChain)
addButton(MainTab, "TP Mika", "", Phase.tpMika)
addButton(MainTab, "TP Hideo", "", Phase.tpCityHideo)

safeDivider(MainTab)
safeParagraph(MainTab, "B. School", "Section 2", "school")
addButton(MainTab, "Medical Kit", "", Phase.grabMedicalKit)
addButton(MainTab, "TP Hideo", "", Phase.tpSchoolHideo)
addButton(MainTab, "Heal Hideo • đã mở phiên chữa", "Cần bandage và mở phiên chữa trước; chỉ gửi yêu cầu một lần bấm.", Phase.healHideo)
addButton(MainTab, "TP Locker", "", Phase.tpLocker)
addButton(MainTab, "Mở Locker", "", Phase.openLocker)
addButton(MainTab, "Đọc Diary", "", Phase.readDiary)
addButton(MainTab, "Freeze 1 Spider • local thử nghiệm", "Tạm tách Bone có thể khôi phục; không bảo đảm dừng NPC server.", Phase.freezeOneSpider)
addButton(MainTab, "Khôi phục Spider local", "", Phase.restoreSpider)
addButton(MainTab, "TP tới cửa ra trường", "", Phase.tpSchoolExit)
addButton(MainTab, "Mở cửa ra trường", "", Phase.exitSchool)
addButton(MainTab, "TP tới Forest", "", Phase.tpForest)

safeDivider(MainTab)
safeParagraph(MainTab, "C. Jungle", "Section 3", "trees")
addButton(MainTab, "TP tới cửa hang", "Một điểm đến; không tự đi tiếp.", Phase.tpForestCave)
addButton(MainTab, "TP IJO Entrance", "Một điểm đến; không tự nối route từ cửa hang.", Phase.tpIJOEntrance)
addButton(MainTab, "Fix Generator", "", autoGenerator)

safeDivider(MainTab)
safeParagraph(MainTab, "D. IJO", "Section 4", "building-2")
addButton(MainTab, "Keycard", "", Phase.grabKeycard)
addButton(MainTab, "Đọc mã Laptop • popup", "Chỉ đọc mã hiện tại; không TP hoặc tự nhập.", Phase.readLaptopPassword)
addButton(MainTab, "C4 #1 • 1 quả", "", Phase.placeC4First)
addButton(MainTab, "C4 #2 • 1 quả", "Cần mở đúng giai đoạn trước; không tự chạy route Netamo.", Phase.placeC4Second)
addButton(MainTab, "Activate Terminals", "", autoTerminal)
addButton(MainTab, "Turn Valves", "", autoValve)
addButton(MainTab, "Lock Threat • 1 nhịp", "Mở minigame trước khi bấm; không tự căn thời điểm.", Phase.hitSkillCheck)
addButton(MainTab, "TP lối ra IJO", "", Phase.tpIJOExit)

safeDivider(MainTab)
safeParagraph(MainTab, "E. Water", "Section 5", "waves")
addButton(MainTab, "TP cuối cầu thang", "", Phase.tpStairEnd)
addButton(MainTab, "Main Switch", "", Phase.activateMainSwitch)
addButton(MainTab, "Auto Wire", "", autoWire)

Extra.BuildUI(MainTab)

-- CHIẾN ĐẤU
safeParagraph(CombatTab, "Nearby Kill · camera", "Ưu tiên theo hướng nhìn; điều kiện nhận hit vẫn do game quyết định.", "crosshair")
addNumberInput(CombatTab, "Delay bắn (s)", "", AutoKillConfig.FireDelay, 0.01, 10, function(v)
    AutoKillConfig.FireDelay = v
end, 0.01, "AutoKillFireDelay")
for _, spec in ipairs({
    {"Gata", "RangeGata", "AutoKillRangeGata"},
    {"Grunt", "RangeGrunt", "AutoKillRangeGrunt"},
    {"Muki", "RangeMuki", "AutoKillRangeMuki"},
    {"HogoGuntai", "RangeHogo", "AutoKillRangeHogo"},
    {"FleshBlock", "RangeFleshBlock", "AutoKillRangeFleshBlock"},
    {"Spider", "RangeSpider", "AutoKillRangeSpider"},
}) do
    local label, key, setting = spec[1], spec[2], spec[3]
    addNumberInput(CombatTab, "Tầm " .. label, "", AutoKillConfig[key], 0, 9999, function(v)
        AutoKillConfig[key] = v
        NearbyCamera:ClearTarget()
    end, 1, setting)
end

-- ESP
safeParagraph(ESPTab, "ESP người chơi", "Highlight + tên + khoảng cách.", "users")
addToggle(ESPTab, "Người chơi", "Bật ESP cho player khác.", false, setPlayerESP)

safeDivider(ESPTab)
safeParagraph(ESPTab, "ESP quái", "Highlight, tên và khoảng cách.", "skull")
addToggle(ESPTab, "Quái", "Bật ESP quái đang có trong map.", false, setMonsterESP)
addToggle(ESPTab, "Creep", "Gata + Grunts + Muki.", true, function(v)
    MonsterAllows.Gata = v
    if States.ESPMonster then setMonsterESP(true) end
end)
addToggle(ESPTab, "Boss", "Boss/NM theo registry B3C1.", true, function(v)
    MonsterAllows.Boss = v
    if States.ESPMonster then setMonsterESP(true) end
end)

safeDivider(ESPTab)
safeParagraph(ESPTab, "ESP nhiệm vụ", "Master + bộ lọc theo phase.", "list-check")
addToggle(ESPTab, "Master ESP Nhiệm vụ", "", false, setTaskMasterESP)
addToggle(ESPTab, "Xác", "", true, function(v) setTaskAllow("Body", v) end)
addToggle(ESPTab, "Nhện", "", true, function(v) setTaskAllow("Spider", v) end)
addToggle(ESPTab, "Máy phát", "", true, function(v) setTaskAllow("Generator", v) end)
addToggle(ESPTab, "Terminal", "", true, function(v) setTaskAllow("Terminal", v) end)
addToggle(ESPTab, "Van", "", true, function(v) setTaskAllow("Valve", v) end)
addToggle(ESPTab, "Dây điện", "", true, function(v) setTaskAllow("Wire", v) end)
addToggle(ESPTab, "Director", "", true, function(v) setTaskAllow("Director", v) end)
addToggle(ESPTab, "Boulder Seal", "", true, function(v) setTaskAllow("BoulderSeal", v) end)
addToggle(ESPTab, "Bolt Cutter", "", true, function(v) setTaskAllow("Cutter", v) end)
addToggle(ESPTab, "Bandage", "", true, function(v) setTaskAllow("Bandage", v) end)
addToggle(ESPTab, "Diary", "", true, function(v) setTaskAllow("Diary", v) end)
addToggle(ESPTab, "Lab Keycard", "Thẻ cửa vào; riêng với thẻ Director.", true, function(v) setTaskAllow("EntranceCard", v) end)
addToggle(ESPTab, "C4 • hai giai đoạn", "", true, function(v) setTaskAllow("C4", v) end)
addToggle(ESPTab, "Main Switch", "", true, function(v) setTaskAllow("PowerSwitch", v) end)

-- CÁ NHÂN
safeParagraph(PlayerTab, "Di chuyển", "Các chức năng local player.", "user")
TPWalkSpeedInput, VFlySpeedInput = nil, nil
addToggle(PlayerTab, "TPWalk", "Dịch chuyển theo hướng di chuyển hiện tại.", false, function(v)
    toggleTPWalk(v)
    setElementVisible(TPWalkSpeedInput, v)
end)
TPWalkSpeedInput = addNumberInput(PlayerTab, "TPWalk • Tốc", "Nhập số thủ công.", TPWalkSpeed, 0, 9999, function(v)
    TPWalkSpeed = v
end, 0.1, "TPWalkSpeed")
setElementVisible(TPWalkSpeedInput, false)

addToggle(PlayerTab, "Noclip", "Tắt va chạm; khi tắt sẽ restore trạng thái cũ.", false, toggleNoclip)
addToggle(PlayerTab, "Moonwalk", "Quay hướng nhân vật ngược camera.", false, toggleMoonwalk)
addToggle(PlayerTab, "Nhảy vô hạn", "JumpRequest, hỗ trợ mobile/PC.", false, toggleInfiniteJump)
addToggle(PlayerTab, "Sáng map", "Fullbright; tắt sẽ khôi phục ánh sáng gốc.", false, toggleFullbright)

addToggle(PlayerTab, "VFly", "Bay theo camera, joystick mobile và WASD PC.", false, function(v)
    toggleVFly(v)
    setElementVisible(VFlySpeedInput, v)
end)
VFlySpeedInput = addNumberInput(PlayerTab, "VFly • Tốc", "Nhập số thủ công.", VFlySpeed, 0, 99999, function(v)
    VFlySpeed = v
end, 0.1, "VFlySpeed")
setElementVisible(VFlySpeedInput, false)

safeDivider(PlayerTab)
safeParagraph(PlayerTab, "Tương tác & Yen", "Thiết lập nền dùng chung cho local player.", "hand")
addToggle(PlayerTab, "Instant E", "Bỏ thời gian giữ tương tác; tắt để khôi phục. Giữ điều kiện khoảng cách của game.", false, function(v)
    InstantInteract:setEnabled(v)
end)
addToggle(PlayerTab, "ESP Yen", "Đánh dấu Yen trong khu vực đang tải.", false, setYenESP)
addToggle(PlayerTab, "Yen Aura", "Nhặt Yen trong 10 studs, dùng chung worker với ESP Yen.", false, setYenCollect)

-- CÀI ĐẶT
safeParagraph(SettingTab, "Giao diện", "Các giá trị được lưu trong workspace executor.", "settings")
addNumberInput(SettingTab, "UI Scale", "Độ lớn tổng thể UI.", DEFAULT_UI_SCALE, 0.58, 0.90, function(v)
    DEFAULT_UI_SCALE = math.clamp(tonumber(v) or DEFAULT_UI_SCALE, 0.58, 0.90)
    pcall(function() Window:SetUIScale(DEFAULT_UI_SCALE) end)
end, 0.01, "UIScale")

addNumberInput(SettingTab, "Toggle Size", "Kích cỡ nút avatar ngoài màn hình.", ToggleSizeScale, 0.60, 2.20, function(v)
    ToggleSizeScale = math.clamp(tonumber(v) or ToggleSizeScale or 1, 0.60, 2.20)
    applyNevoirsToggleSize()
end, 0.05, "ToggleSizeScale")

pcall(function() MainTab:Select() end)
print("[Nevoirs - B3C1] ✅ CC Camera loaded")

