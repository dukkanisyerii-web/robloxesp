local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Framework = {}
Framework.__index = Framework
Framework.Version = "1.0.0"

local function getLocalPlayer()
    local player = Players.LocalPlayer
    if player then
        return player
    end
    local players = Players:GetPlayers()
    if players and #players > 0 then
        return players[1]
    end
    return nil
end

function Framework.new()
    local self = setmetatable({
        Name = "ApexEngine",
        Config = {},
        Plugins = {},
        Listeners = {},
        RenderConnection = nil,
        Started = false,
        SessionStart = tick()
    }, Framework)

    self:BuildDefaultConfig()
    return self
end

function Framework:BuildDefaultConfig()
    self.Config = {
        Utility = {
            Enabled = true,
            ScanInterval = 0.05,
            AutoRecovery = true,
            SmartReset = true,
            FallbackProtection = true,
        },
        Diagnostics = {
            Enabled = true,
            ScanInterval = 0.25,
            RecordEvents = true,
            MaxHistory = 120,
            AlertFPS = 20,
            AlertPing = 200,
            AlertMemory = 45000,
        },
        PerformanceGuard = {
            Enabled = true,
            ScanInterval = 0.2,
            LowFPSThreshold = 22,
            MemoryPressureThreshold = 220,
            AggressiveCleanup = true,
        },
        Resilience = {
            Enabled = true,
            ScanInterval = 0.3,
            RecoverOnStall = true,
            MaxRecoveryAttempts = 3,
        },
        SessionAnalytics = {
            Enabled = true,
            ScanInterval = 0.2,
            MaxHistory = 180,
        },
        RecoveryCoordinator = {
            Enabled = true,
            ScanInterval = 0.4,
            Cooldown = 2,
            MaxAttempts = 2,
            MinHeight = -1000,
        },
    }
end

function Framework:Publish(eventName, payload)
    local listeners = self.Listeners[eventName]
    if not listeners then return end
    for _, listener in ipairs(listeners) do
        pcall(function()
            listener(payload)
        end)
    end
end

function Framework:Subscribe(eventName, callback)
    if not self.Listeners[eventName] then
        self.Listeners[eventName] = {}
    end
    table.insert(self.Listeners[eventName], callback)
end

function Framework:RegisterPlugin(plugin)
    if not plugin or not plugin.Name then
        error("Invalid plugin")
    end

    local instance = plugin.new()
    instance.Framework = self
    instance.Config = self.Config
    if instance.Init then
        instance:Init(self)
    end

    self.Plugins[instance.Name] = instance
    return instance
end

function Framework:EnablePlugin(name)
    local plugin = self.Plugins[name]
    if plugin and not plugin.Active then
        plugin.Active = true
        if plugin.Start then
            plugin:Start()
        end
    end
end

function Framework:DisablePlugin(name)
    local plugin = self.Plugins[name]
    if plugin and plugin.Active then
        plugin.Active = false
        if plugin.Stop then
            plugin:Stop()
        end
    end
end

function Framework:Bootstrap()
    if self.Started then return self end
    self.Started = true

    self:RegisterPlugin(UtilityPlugin)
    self:RegisterPlugin(DiagnosticsPlugin)
    self:RegisterPlugin(PerformanceGuardPlugin)
    self:RegisterPlugin(ResiliencePlugin)
    self:RegisterPlugin(SessionAnalyticsPlugin)
    self:RegisterPlugin(RecoveryCoordinatorPlugin)
    self:RegisterPlugin(StatusUIPlugin)

    self:EnablePlugin("Utility")
    self:EnablePlugin("Diagnostics")
    self:EnablePlugin("PerformanceGuard")
    self:EnablePlugin("Resilience")
    self:EnablePlugin("SessionAnalytics")
    self:EnablePlugin("RecoveryCoordinator")
    self:EnablePlugin("StatusUI")

    self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
        self:Tick(dt)
    end)

    if getgenv then
        getgenv().ApexEngine = self
        getgenv().ApexEngineBootstrap = function()
            return self:Bootstrap()
        end
    end

    print("[ApexEngine] Single-file framework loaded and running.")
    return self
end

function Framework:Tick(dt)
    for _, plugin in pairs(self.Plugins) do
        if plugin.Active and plugin.Process then
            pcall(function()
                plugin:Process(dt)
            end)
        end
    end
end

function Framework:Shutdown()
    if self.RenderConnection then
        self.RenderConnection:Disconnect()
        self.RenderConnection = nil
    end

    for _, plugin in pairs(self.Plugins) do
        if plugin.Active then
            pcall(function()
                if plugin.Stop then
                    plugin:Stop()
                end
            end)
        end
    end

    self.Started = false
    print("[ApexEngine] Shutdown complete.")
end

local UtilityPlugin = {}
UtilityPlugin.__index = UtilityPlugin

function UtilityPlugin.new()
    return setmetatable({
        Name = "Utility",
        Active = false,
        LastScan = 0,
        Subscriptions = {},
    }, UtilityPlugin)
end

function UtilityPlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function UtilityPlugin:Start()
    self.Active = true
end

function UtilityPlugin:Stop()
    self.Active = false
end

function UtilityPlugin:Process(dt)
    if not self.Config.Utility.Enabled then return end
    local now = tick()
    if now - self.LastScan < (self.Config.Utility.ScanInterval or 0.05) then return end
    self.LastScan = now

    self:ApplyAutoRecovery()
    self:ApplySmartReset()
    self:ApplyFallbackProtection()
end

function UtilityPlugin:ApplyAutoRecovery()
    if not self.Config.Utility.AutoRecovery then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then
        pcall(function()
            LocalPlayer:Kick("Recovery")
        end)
    end
end

function UtilityPlugin:ApplySmartReset()
    if not self.Config.Utility.SmartReset then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and math.abs(root.Position.Y) > 5000 then
        pcall(function()
            LocalPlayer:LoadCharacter()
        end)
    end
end

function UtilityPlugin:ApplyFallbackProtection()
    if not self.Config.Utility.FallbackProtection then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < 20 then
        pcall(function()
            hum.Health = math.max(hum.Health, 20)
        end)
    end
end

local DiagnosticsPlugin = {}
DiagnosticsPlugin.__index = DiagnosticsPlugin

function DiagnosticsPlugin.new()
    return setmetatable({
        Name = "Diagnostics",
        Active = false,
        LastScan = 0,
        History = {},
        WarningCount = 0,
    }, DiagnosticsPlugin)
end

function DiagnosticsPlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function DiagnosticsPlugin:Start()
    self.Active = true
end

function DiagnosticsPlugin:Stop()
    self.Active = false
end

function DiagnosticsPlugin:Process(dt)
    if not self.Config.Diagnostics.Enabled then return end
    local now = tick()
    if now - self.LastScan < (self.Config.Diagnostics.ScanInterval or 0.25) then return end
    self.LastScan = now

    local snapshot = self:CaptureSnapshot(dt)
    self:AppendHistory(snapshot)
    self:Evaluate(snapshot)

    self.Framework:Publish("Framework/Diagnostics", snapshot)
end

function DiagnosticsPlugin:CaptureSnapshot(dt)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end

    local ping = 0
    pcall(function()
        if LocalPlayer and LocalPlayer.GetNetworkPing then
            ping = LocalPlayer:GetNetworkPing() * 1000
        end
    end)

    local health = hum and hum.Health or 0
    local height = root and root.Position.Y or 0

    return {
        Timestamp = tick(),
        FPS = fps,
        Ping = ping,
        Health = health,
        Height = height,
        PlayerCount = #Players:GetPlayers(),
        AlertLevel = "Green",
    }
end

function DiagnosticsPlugin:AppendHistory(snapshot)
    table.insert(self.History, snapshot)
    if #self.History > (self.Config.Diagnostics.MaxHistory or 120) then
        table.remove(self.History, 1)
    end
end

function DiagnosticsPlugin:Evaluate(snapshot)
    local cfg = self.Config.Diagnostics or {}
    local level = "Green"
    if snapshot.FPS < (cfg.AlertFPS or 20) or snapshot.Ping > (cfg.AlertPing or 200) then
        level = "Yellow"
    end
    if snapshot.FPS < 12 or snapshot.Ping > 400 then
        level = "Red"
    end
    snapshot.AlertLevel = level
    if level ~= "Green" then
        self.WarningCount = self.WarningCount + 1
        warn("[Diagnostics] Alert " .. level .. " FPS=" .. tostring(snapshot.FPS) .. " Ping=" .. tostring(snapshot.Ping))
    end
end

local PerformanceGuardPlugin = {}
PerformanceGuardPlugin.__index = PerformanceGuardPlugin

function PerformanceGuardPlugin.new()
    return setmetatable({
        Name = "PerformanceGuard",
        Active = false,
        LastScan = 0,
        ThrottleLevel = 0,
        CleanupCycles = 0,
    }, PerformanceGuardPlugin)
end

function PerformanceGuardPlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function PerformanceGuardPlugin:Start()
    self.Active = true
end

function PerformanceGuardPlugin:Stop()
    self.Active = false
end

function PerformanceGuardPlugin:Process(dt)
    if not self.Config.PerformanceGuard.Enabled then return end
    local now = tick()
    if now - self.LastScan < (self.Config.PerformanceGuard.ScanInterval or 0.2) then return end
    self.LastScan = now

    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end

    if fps < (self.Config.PerformanceGuard.LowFPSThreshold or 22) then
        self.ThrottleLevel = math.min(3, self.ThrottleLevel + 1)
    elseif fps > 55 then
        self.ThrottleLevel = math.max(0, self.ThrottleLevel - 1)
    end

    if self.Config.PerformanceGuard.AggressiveCleanup and self.ThrottleLevel >= 2 then
        self.CleanupCycles = self.CleanupCycles + 1
        collectgarbage()
        collectgarbage("collect")
    end

    self.Framework:Publish("Framework/Performance", {
        FPS = fps,
        ThrottleLevel = self.ThrottleLevel,
        CleanupCycles = self.CleanupCycles,
    })
end

local ResiliencePlugin = {}
ResiliencePlugin.__index = ResiliencePlugin

function ResiliencePlugin.new()
    return setmetatable({
        Name = "Resilience",
        Active = false,
        LastScan = 0,
        RecoveryAttempts = 0,
        LastHealth = 0,
        LastPosition = Vector3.zero,
        History = {},
    }, ResiliencePlugin)
end

function ResiliencePlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function ResiliencePlugin:Start()
    self.Active = true
end

function ResiliencePlugin:Stop()
    self.Active = false
end

function ResiliencePlugin:Process(dt)
    if not self.Config.Resilience.Enabled then return end
    local now = tick()
    if now - self.LastScan < (self.Config.Resilience.ScanInterval or 0.3) then return end
    self.LastScan = now

    local snapshot = self:CaptureSnapshot()
    self:AppendHistory(snapshot)
    self:Assess(snapshot)

    if self.Config.Resilience.RecoverOnStall then
        self:AttemptRecovery(snapshot)
    end

    self.Framework:Publish("Framework/Resilience", snapshot)
end

function ResiliencePlugin:CaptureSnapshot()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local position = root and root.Position or Vector3.zero
    return {
        Timestamp = tick(),
        Health = hum and hum.Health or 0,
        Position = position,
        IsAlive = hum and hum.Health > 0 or false,
    }
end

function ResiliencePlugin:AppendHistory(snapshot)
    table.insert(self.History, snapshot)
    if #self.History > 80 then
        table.remove(self.History, 1)
    end
end

function ResiliencePlugin:Assess(snapshot)
    local previous = self.History[#self.History - 1]
    if not previous then return end
    local deltaHealth = math.abs((snapshot.Health or 0) - (previous.Health or 0))
    local deltaPos = (snapshot.Position - previous.Position).Magnitude
    if deltaHealth < 0.01 and deltaPos < 0.01 then
        self.LastHealth = snapshot.Health
        self.LastPosition = snapshot.Position
    end
end

function ResiliencePlugin:AttemptRecovery(snapshot)
    local cfg = self.Config.Resilience or {}
    if self.RecoveryAttempts >= (cfg.MaxRecoveryAttempts or 3) then return end
    if snapshot.Health > 0 then return end
    self.RecoveryAttempts = self.RecoveryAttempts + 1
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            char.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
        end)
    end
end

local SessionAnalyticsPlugin = {}
SessionAnalyticsPlugin.__index = SessionAnalyticsPlugin

function SessionAnalyticsPlugin.new()
    return setmetatable({
        Name = "SessionAnalytics",
        Active = false,
        LastScan = 0,
        History = {},
        EventLog = {},
        Playback = {Samples = 0, AverageFPS = 0, AveragePing = 0, AverageHealth = 0},
    }, SessionAnalyticsPlugin)
end

function SessionAnalyticsPlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function SessionAnalyticsPlugin:Start()
    self.Active = true
end

function SessionAnalyticsPlugin:Stop()
    self.Active = false
end

function SessionAnalyticsPlugin:Process(dt)
    if not self.Config.SessionAnalytics.Enabled then return end
    local now = tick()
    if now - self.LastScan < (self.Config.SessionAnalytics.ScanInterval or 0.2) then return end
    self.LastScan = now

    local snapshot = self:CaptureSnapshot(dt)
    self:AppendHistory(snapshot)
    self:UpdatePlayback()
    self:RecordEvent(snapshot)
    self.Framework:Publish("Framework/SessionAnalytics", snapshot)
end

function SessionAnalyticsPlugin:CaptureSnapshot(dt)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end

    local ping = 0
    pcall(function()
        if LocalPlayer and LocalPlayer.GetNetworkPing then
            ping = LocalPlayer:GetNetworkPing() * 1000
        end
    end)

    return {
        Timestamp = tick(),
        FPS = fps,
        Ping = ping,
        Health = hum and hum.Health or 0,
        Position = root and root.Position or Vector3.zero,
        Alive = hum and hum.Health > 0 or false,
        PlayerCount = #Players:GetPlayers(),
    }
end

function SessionAnalyticsPlugin:AppendHistory(snapshot)
    table.insert(self.History, snapshot)
    if #self.History > (self.Config.SessionAnalytics.MaxHistory or 180) then
        table.remove(self.History, 1)
    end
end

function SessionAnalyticsPlugin:UpdatePlayback()
    local count = #self.History
    if count == 0 then return end
    local totalFps = 0
    local totalPing = 0
    local totalHealth = 0
    for _, entry in ipairs(self.History) do
        totalFps = totalFps + (entry.FPS or 0)
        totalPing = totalPing + (entry.Ping or 0)
        totalHealth = totalHealth + (entry.Health or 0)
    end
    self.Playback.Samples = count
    self.Playback.AverageFPS = math.floor(totalFps / count)
    self.Playback.AveragePing = math.floor(totalPing / count)
    self.Playback.AverageHealth = totalHealth / count
end

function SessionAnalyticsPlugin:RecordEvent(snapshot)
    table.insert(self.EventLog, {
        Timestamp = snapshot.Timestamp,
        FPS = snapshot.FPS,
        Ping = snapshot.Ping,
        Health = snapshot.Health,
        Alive = snapshot.Alive,
    })
    if #self.EventLog > 240 then
        table.remove(self.EventLog, 1)
    end
end

local RecoveryCoordinatorPlugin = {}
RecoveryCoordinatorPlugin.__index = RecoveryCoordinatorPlugin

function RecoveryCoordinatorPlugin.new()
    return setmetatable({
        Name = "RecoveryCoordinator",
        Active = false,
        LastScan = 0,
        LastRecovery = 0,
        Attempts = 0,
        LastState = nil,
    }, RecoveryCoordinatorPlugin)
end

function RecoveryCoordinatorPlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function RecoveryCoordinatorPlugin:Start()
    self.Active = true
end

function RecoveryCoordinatorPlugin:Stop()
    self.Active = false
end

function RecoveryCoordinatorPlugin:Process(dt)
    if not self.Config.RecoveryCoordinator.Enabled then return end
    local now = tick()
    if now - self.LastScan < (self.Config.RecoveryCoordinator.ScanInterval or 0.4) then return end
    self.LastScan = now

    local state = self:CaptureState()
    self.LastState = state
    if self:ShouldRecover(state, now) then
        self:AttemptRecovery(state)
    end
end

function RecoveryCoordinatorPlugin:CaptureState()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return {
        Timestamp = tick(),
        Health = hum and hum.Health or 0,
        Alive = hum and hum.Health > 0 or false,
        RootHeight = root and root.Position.Y or 0,
        CharacterPresent = char ~= nil,
    }
end

function RecoveryCoordinatorPlugin:ShouldRecover(state, now)
    local cfg = self.Config.RecoveryCoordinator or {}
    if not state.Alive then
        return now - self.LastRecovery >= (cfg.Cooldown or 2)
    end
    if state.RootHeight < (cfg.MinHeight or -1000) then
        return now - self.LastRecovery >= (cfg.Cooldown or 2)
    end
    return false
end

function RecoveryCoordinatorPlugin:AttemptRecovery(state)
    local cfg = self.Config.RecoveryCoordinator or {}
    if self.Attempts >= (cfg.MaxAttempts or 2) then return end
    self.Attempts = self.Attempts + 1
    self.LastRecovery = tick()

    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            char.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
        end)
    end
end

local StatusUIPlugin = {}
StatusUIPlugin.__index = StatusUIPlugin

function StatusUIPlugin.new()
    return setmetatable({
        Name = "StatusUI",
        Active = false,
        Gui = nil,
    }, StatusUIPlugin)
end

function StatusUIPlugin:Init(framework)
    self.Framework = framework
    self.Config = framework.Config
end

function StatusUIPlugin:Start()
    self.Active = true
    self:BuildGui()
end

function StatusUIPlugin:Stop()
    self.Active = false
    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

function StatusUIPlugin:BuildGui()
    local player = getLocalPlayer()
    if not player then return end
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    if self.Gui then
        self.Gui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ApexEngineStatus"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.02, 0, 0.02, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 28)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ApexEngine Online"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Size = UDim2.new(1, -20, 1, -36)
    body.Position = UDim2.new(0, 10, 0, 34)
    body.BackgroundTransparency = 1
    body.Text = "Diagnostics • Performance • Resilience"
    body.TextColor3 = Color3.fromRGB(180, 220, 255)
    body.Font = Enum.Font.Gotham
    body.TextSize = 14
    body.TextWrapped = true
    body.Parent = frame

    self.Gui = gui
end

function StatusUIPlugin:Process(dt)
    if not self.Gui then return end
    local frame = self.Gui:FindFirstChild("MainFrame")
    if not frame then return end
    local body = frame:FindFirstChild("Body")
    if not body then return end
    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end
    body.Text = string.format("Modules: %d\nFPS: %d\nStatus: Active", #self.Framework.Plugins, fps)
end

local engine = Framework.new()
engine:Bootstrap()

if getgenv then
    getgenv().ApexEngine = engine
    getgenv().ApexEngineBootstrap = function()
        return engine:Bootstrap()
    end
end

return engine
