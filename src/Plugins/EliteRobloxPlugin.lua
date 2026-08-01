local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local EliteRobloxPlugin = {}
EliteRobloxPlugin.__index = EliteRobloxPlugin

function EliteRobloxPlugin.new()
    return setmetatable({
        Name = "EliteRoblox",
        Subscriptions = {},
        Active = false,
        LastScan = 0,
        Pulse = 0,
        Motion = 0
    }, EliteRobloxPlugin)
end

function EliteRobloxPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function EliteRobloxPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function EliteRobloxPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function EliteRobloxPlugin:Process(dt)
    if not self.Config.EliteRoblox or not self.Config.EliteRoblox.Enabled then return end

    local now = tick()
    if now - self.LastScan < (self.Config.EliteRoblox.ScanInterval or 0.03) then return end
    self.LastScan = now

    self:ApplyAdaptiveGlow(dt)
    self:ApplyTemporalEcho(dt)
    self:ApplyBloomTrail(dt)
end

function EliteRobloxPlugin:ApplyAdaptiveGlow(dt)
    if not self.Config.EliteRoblox.AdaptiveGlow then return end
    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Material = Enum.Material.Neon
            end)
        end
    end
end

function EliteRobloxPlugin:ApplyTemporalEcho(dt)
    if not self.Config.EliteRoblox.TemporalEcho then return end
    self.Pulse = self.Pulse + dt * 1.5
    local char = LocalPlayer.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        local offset = Vector3.new(math.sin(self.Pulse) * 0.03, math.cos(self.Pulse) * 0.02, 0)
        root.CFrame = root.CFrame + offset
    end
end

function EliteRobloxPlugin:ApplyBloomTrail(dt)
    if not self.Config.EliteRoblox.BloomTrail then return end
    self.Motion = self.Motion + dt * 2
    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = hum.WalkSpeed + math.sin(self.Motion) * 0.002
    end
end

return EliteRobloxPlugin
