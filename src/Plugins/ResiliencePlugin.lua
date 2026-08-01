local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ResiliencePlugin = {}
ResiliencePlugin.__index = ResiliencePlugin

function ResiliencePlugin.new()
    return setmetatable({
        Name = "Resilience",
        Active = false,
        Subscriptions = {},
        LastScan = 0,
        RecoveryAttempts = 0,
        State = {
            LastHealth = 0,
            LastPosition = Vector3.zero,
            LastTimestamp = 0,
            Stable = true
        },
        History = {}
    }, ResiliencePlugin)
end

function ResiliencePlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function ResiliencePlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function ResiliencePlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function ResiliencePlugin:Process(dt)
    if not self.Config.Resilience or not self.Config.Resilience.Enabled then return end

    local now = tick()
    if now - self.LastScan < (self.Config.Resilience.ScanInterval or 0.3) then return end
    self.LastScan = now

    local snapshot = self:CaptureSnapshot()
    self:AppendHistory(snapshot)
    self:AssessStability(snapshot)

    if self.Config.Resilience.RecoverOnStall then
        self:AttemptRecovery(snapshot)
    end

    if self.EventBus then
        pcall(function()
            self.EventBus:Publish("Framework/Resilience", snapshot)
        end)
    end
end

function ResiliencePlugin:CaptureSnapshot()
    local localPlayer = Players.LocalPlayer
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    local health = hum and hum.Health or 0
    local position = root and root.Position or Vector3.zero
    local timestamp = tick()

    return {
        Timestamp = timestamp,
        Health = health,
        Position = position,
        IsAlive = health > 0,
        Stable = true
    }
end

function ResiliencePlugin:AppendHistory(snapshot)
    table.insert(self.History, snapshot)
    if #self.History > 80 then
        table.remove(self.History, 1)
    end
end

function ResiliencePlugin:AssessStability(snapshot)
    local previous = self.History[#self.History - 1]
    if not previous then return end

    local deltaHealth = math.abs((snapshot.Health or 0) - (previous.Health or 0))
    local deltaPosition = (snapshot.Position - previous.Position).Magnitude

    if deltaHealth < 0.01 and deltaPosition < 0.01 then
        self.State.Stable = true
    else
        self.State.Stable = false
    end

    self.State.LastHealth = snapshot.Health
    self.State.LastPosition = snapshot.Position
    self.State.LastTimestamp = snapshot.Timestamp
end

function ResiliencePlugin:AttemptRecovery(snapshot)
    local cfg = self.Config.Resilience or {}
    if self.State.Stable or not snapshot.IsAlive then return end

    if self.RecoveryAttempts >= (cfg.MaxRecoveryAttempts or 3) then
        return
    end

    self.RecoveryAttempts = self.RecoveryAttempts + 1
    self:RunRecoveryRoutine(snapshot)
end

function ResiliencePlugin:RunRecoveryRoutine(snapshot)
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if char and hum then
        pcall(function()
            if hum.Health < 1 then
                hum.Health = 1
            end
        end)
    end

    if snapshot.Position and snapshot.Position.Y < -1000 then
        pcall(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
            end
        end)
    end
end

function ResiliencePlugin:GetState()
    return self.State
end

return ResiliencePlugin
