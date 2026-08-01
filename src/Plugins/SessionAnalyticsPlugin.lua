local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SessionAnalyticsPlugin = {}
SessionAnalyticsPlugin.__index = SessionAnalyticsPlugin

function SessionAnalyticsPlugin.new()
    return setmetatable({
        Name = "SessionAnalytics",
        Active = false,
        Subscriptions = {},
        LastScan = 0,
        SessionStart = tick(),
        Metrics = {},
        History = {},
        EventLog = {},
        Playback = {
            Samples = 0,
            AverageFPS = 0,
            AveragePing = 0,
            AverageHealth = 0
        }
    }, SessionAnalyticsPlugin)
end

function SessionAnalyticsPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function SessionAnalyticsPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function SessionAnalyticsPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function SessionAnalyticsPlugin:Process(dt)
    if not self.Config.SessionAnalytics or not self.Config.SessionAnalytics.Enabled then return end

    local now = tick()
    if now - self.LastScan < (self.Config.SessionAnalytics.ScanInterval or 0.2) then return end
    self.LastScan = now

    local snapshot = self:CaptureSnapshot(dt)
    self:AppendHistory(snapshot)
    self:UpdatePlayback(snapshot)
    self:RecordEvent(snapshot)

    if self.EventBus then
        pcall(function()
            self.EventBus:Publish("Framework/SessionAnalytics", snapshot)
        end)
    end
end

function SessionAnalyticsPlugin:CaptureSnapshot(dt)
    local localPlayer = Players.LocalPlayer
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end

    local ping = 0
    pcall(function()
        if localPlayer and localPlayer:GetNetworkPing then
            ping = localPlayer:GetNetworkPing() * 1000
        end
    end)

    local health = hum and hum.Health or 0
    local position = root and root.Position or Vector3.zero
    local uptime = tick() - self.SessionStart

    return {
        Timestamp = tick(),
        Uptime = uptime,
        FPS = fps,
        Ping = ping,
        Health = health,
        Position = position,
        Alive = health > 0,
        PlayerCount = #Players:GetPlayers(),
        SessionState = self:BuildSessionState(fps, ping, health)
    }
end

function SessionAnalyticsPlugin:BuildSessionState(fps, ping, health)
    if fps < 20 or ping > 180 then
        return "Degraded"
    end

    if health < 30 then
        return "AtRisk"
    end

    return "Stable"
end

function SessionAnalyticsPlugin:AppendHistory(snapshot)
    table.insert(self.History, snapshot)
    if #self.History > (self.Config.SessionAnalytics.MaxHistory or 180) then
        table.remove(self.History, 1)
    end
end

function SessionAnalyticsPlugin:UpdatePlayback(snapshot)
    local count = #self.History
    local totalFps = 0
    local totalPing = 0
    local totalHealth = 0

    for _, entry in ipairs(self.History) do
        totalFps = totalFps + (entry.FPS or 0)
        totalPing = totalPing + (entry.Ping or 0)
        totalHealth = totalHealth + (entry.Health or 0)
    end

    self.Playback.Samples = count
    self.Playback.AverageFPS = count > 0 and math.floor(totalFps / count) or 0
    self.Playback.AveragePing = count > 0 and math.floor(totalPing / count) or 0
    self.Playback.AverageHealth = count > 0 and (totalHealth / count) or 0
end

function SessionAnalyticsPlugin:RecordEvent(snapshot)
    table.insert(self.EventLog, {
        Timestamp = snapshot.Timestamp,
        State = snapshot.SessionState,
        FPS = snapshot.FPS,
        Ping = snapshot.Ping,
        Health = snapshot.Health,
        Uptime = snapshot.Uptime
    })

    if #self.EventLog > 240 then
        table.remove(self.EventLog, 1)
    end
end

function SessionAnalyticsPlugin:GetSummary()
    return {
        Playback = self.Playback,
        HistoryLength = #self.History,
        EventCount = #self.EventLog,
        SessionStart = self.SessionStart,
        CurrentState = self.History[#self.History] and self.History[#self.History].SessionState or "Idle"
    }
end

return SessionAnalyticsPlugin
