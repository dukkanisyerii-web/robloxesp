local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local RareFeaturesPlugin = {}
RareFeaturesPlugin.__index = RareFeaturesPlugin

function RareFeaturesPlugin.new()
    return setmetatable({
        Name = "RareFeatures",
        Subscriptions = {},
        Active = false,
        LastPulse = 0,
        PulsePhase = 0,
        LastScan = 0
    }, RareFeaturesPlugin)
end

function RareFeaturesPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function RareFeaturesPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function RareFeaturesPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function RareFeaturesPlugin:Process(dt)
    if not self.Config.RareFeatures or not self.Config.RareFeatures.Enabled then return end

    local now = tick()
    if now - self.LastScan < (self.Config.RareFeatures.ScanInterval or 0.05) then return end
    self.LastScan = now

    self:ApplyGhostOutline(dt)
    self:ApplyAuraPulse(dt)
    self:ApplyTargetEcho(dt)
end

function RareFeaturesPlugin:ApplyGhostOutline(dt)
    if not self.Config.RareFeatures.GhostOutline then return end
    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                if part.Transparency < 0.8 then
                    part.Transparency = math.clamp(part.Transparency + (dt * 0.002), 0, 0.15)
                end
            end)
        end
    end
end

function RareFeaturesPlugin:ApplyAuraPulse(dt)
    if not self.Config.RareFeatures.AuraPulse then return end

    self.PulsePhase = self.PulsePhase + dt * 2
    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local bodyColor = Color3.fromRGB(255, 120, 255)
    local pulse = 0.5 + (math.sin(self.PulsePhase) * 0.5)
    if pulse > 0.8 then
        hum.WalkSpeed = math.max(hum.WalkSpeed, 16)
    end
end

function RareFeaturesPlugin:ApplyTargetEcho(dt)
    if not self.Config.RareFeatures.TargetEcho then return end

    local target = self.EventBus and self.EventBus:Publish("RareFeatures/TargetEcho", tostring(LocalPlayer.Name))
    return target
end

return RareFeaturesPlugin
