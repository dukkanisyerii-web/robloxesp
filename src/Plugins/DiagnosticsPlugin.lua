local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local DiagnosticsPlugin = {}
DiagnosticsPlugin.__index = DiagnosticsPlugin

function DiagnosticsPlugin.new()
    return setmetatable({
        Name = "Diagnostics",
        Active = false,
        Subscriptions = {},
        History = {},
        EventLog = {},
        LastScan = 0,
        Sequence = 0,
        LastDt = 0.016,
        WarningCount = 0,
        LastSummary = nil
    }, DiagnosticsPlugin)
end

function DiagnosticsPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    self.Security = DI:Resolve("Security")
end

function DiagnosticsPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function DiagnosticsPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function DiagnosticsPlugin:Process(dt)
    if not self.Config.Diagnostics or not self.Config.Diagnostics.Enabled then return end

    local now = tick()
    if now - self.LastScan < (self.Config.Diagnostics.ScanInterval or 0.25) then return end
    self.LastScan = now
    self.LastDt = dt
    self.Sequence = self.Sequence + 1

    local snapshot = self:CaptureSnapshot(dt)
    self:AppendHistory(snapshot)
    self:EvaluateHealth(snapshot)

    if self.Config.Diagnostics.RecordEvents then
        self:RecordEvent(snapshot)
    end

    if self.EventBus then
        pcall(function()
            self.EventBus:Publish("Framework/Diagnostics", snapshot)
        end)
    end
end

function DiagnosticsPlugin:CaptureSnapshot(dt)
    local localPlayer = Players.LocalPlayer
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end

    local memoryUsage = 0
    local success, result = pcall(function()
        return gcinfo and gcinfo() or 0
    end)
    if success then
        memoryUsage = tonumber(result) or 0
    end

    local physicsFps = 0
    pcall(function()
        physicsFps = workspace:GetRealPhysicsFPS()
    end)

    local ping = 0
    pcall(function()
        if localPlayer and localPlayer:GetNetworkPing then
            ping = localPlayer:GetNetworkPing() * 1000
        end
    end)

    local health = hum and hum.Health or 0
    local isAlive = hum and health > 0 or false
    local rootHeight = root and root.Position.Y or 0

    return {
        Sequence = self.Sequence,
        Timestamp = os.clock(),
        FPS = fps,
        PhysicsFPS = physicsFps,
        Memory = memoryUsage,
        Ping = ping,
        Health = health,
        Alive = isAlive,
        Height = rootHeight,
        PlayerCount = #Players:GetPlayers(),
        ServiceReady = true,
        Platform = self:GetPlatformSignature(),
        Notes = self:BuildNotes(fps, ping, health, memoryUsage)
    }
end

function DiagnosticsPlugin:BuildNotes(fps, ping, health, memoryUsage)
    local notes = {}

    if fps < 30 then
        table.insert(notes, "Low frame rate")
    end

    if ping > 180 then
        table.insert(notes, "High ping")
    end

    if health < 50 then
        table.insert(notes, "Low health")
    end

    if memoryUsage > 200 then
        table.insert(notes, "Memory pressure")
    end

    if #notes == 0 then
        table.insert(notes, "Stable")
    end

    return notes
end

function DiagnosticsPlugin:GetPlatformSignature()
    local signature = "Unknown"
    pcall(function()
        signature = tostring(identifyexecutor and identifyexecutor() or "Roblox")
    end)
    return signature
end

function DiagnosticsPlugin:AppendHistory(snapshot)
    table.insert(self.History, snapshot)
    if #self.History > (self.Config.Diagnostics.MaxHistory or 120) then
        table.remove(self.History, 1)
    end
end

function DiagnosticsPlugin:EvaluateHealth(snapshot)
    local thresholds = self.Config.Diagnostics or {}
    local level = "Green"

    if snapshot.FPS < (thresholds.AlertFPS or 20) or snapshot.Ping > (thresholds.AlertPing or 200) then
        level = "Yellow"
    end

    if snapshot.FPS < 12 or snapshot.Memory > (thresholds.AlertMemory or 45000) then
        level = "Red"
    end

    snapshot.AlertLevel = level

    if level ~= "Green" then
        self.WarningCount = self.WarningCount + 1
        self:LogWarning(snapshot, level)
    end

    self.LastSummary = self:BuildSummary(snapshot)
end

function DiagnosticsPlugin:BuildSummary(snapshot)
    local avgFps = 0
    local avgPing = 0
    local count = #self.History

    if count > 0 then
        for _, entry in ipairs(self.History) do
            avgFps = avgFps + (entry.FPS or 0)
            avgPing = avgPing + (entry.Ping or 0)
        end
        avgFps = avgFps / count
        avgPing = avgPing / count
    end

    return {
        AverageFPS = math.floor(avgFps),
        AveragePing = math.floor(avgPing),
        WarningCount = self.WarningCount,
        LastAlert = snapshot.AlertLevel,
        SampleCount = count
    }
end

function DiagnosticsPlugin:LogWarning(snapshot, level)
    local message = string.format("[Diagnostics] Alert %s - FPS: %d Ping: %d Memory: %d", level, snapshot.FPS, snapshot.Ping, snapshot.Memory)
    warn(message)
end

function DiagnosticsPlugin:RecordEvent(snapshot)
    table.insert(self.EventLog, {
        Sequence = snapshot.Sequence,
        Level = snapshot.AlertLevel,
        FPS = snapshot.FPS,
        Ping = snapshot.Ping,
        Memory = snapshot.Memory,
        Notes = snapshot.Notes
    })

    if #self.EventLog > 200 then
        table.remove(self.EventLog, 1)
    end
end

function DiagnosticsPlugin:GetSnapshot()
    return self.LastSummary or {
        AverageFPS = 0,
        AveragePing = 0,
        WarningCount = 0,
        LastAlert = "Green",
        SampleCount = 0
    }
end

return DiagnosticsPlugin
