local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RecoveryCoordinatorPlugin = {}
RecoveryCoordinatorPlugin.__index = RecoveryCoordinatorPlugin

function RecoveryCoordinatorPlugin.new()
    return setmetatable({
        Name = "RecoveryCoordinator",
        Active = false,
        Subscriptions = {},
        LastScan = 0,
        RecoveryCooldown = 0,
        LastRecovery = 0,
        Attempts = 0,
        LastState = nil
    }, RecoveryCoordinatorPlugin)
end

function RecoveryCoordinatorPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function RecoveryCoordinatorPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function RecoveryCoordinatorPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function RecoveryCoordinatorPlugin:Process(dt)
    if not self.Config.RecoveryCoordinator or not self.Config.RecoveryCoordinator.Enabled then return end

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
    local localPlayer = Players.LocalPlayer
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    return {
        Timestamp = tick(),
        Health = hum and hum.Health or 0,
        Alive = hum and hum.Health > 0 or false,
        RootHeight = root and root.Position.Y or 0,
        CharacterPresent = char ~= nil,
        PlayerReady = localPlayer ~= nil
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

    local localPlayer = Players.LocalPlayer
    local char = localPlayer and localPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            char.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
        end)
    end

    if self.EventBus then
        pcall(function()
            self.EventBus:Publish("Framework/RecoveryCoordinator", state)
        end)
    end
end

function RecoveryCoordinatorPlugin:GetState()
    return self.LastState
end

return RecoveryCoordinatorPlugin
