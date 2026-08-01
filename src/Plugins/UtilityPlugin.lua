local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local UtilityPlugin = {}
UtilityPlugin.__index = UtilityPlugin

function UtilityPlugin.new()
    return setmetatable({
        Name = "Utility",
        Subscriptions = {},
        Active = false,
        LastScan = 0,
        Buffer = {}
    }, UtilityPlugin)
end

function UtilityPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function UtilityPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function UtilityPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function UtilityPlugin:Process(dt)
    if not self.Config.Utility or not self.Config.Utility.Enabled then return end

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

return UtilityPlugin