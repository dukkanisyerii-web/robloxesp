local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local MovementPlugin = {}
MovementPlugin.__index = MovementPlugin

function MovementPlugin.new()
    return setmetatable({
        Name = "Movement",
        Subscriptions = {},
        LastJumpTick = 0,
        LastFlyTick = 0
    }, MovementPlugin)
end

function MovementPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function MovementPlugin:Start()
    local sub = self.EventBus:Subscribe("Engine/RenderStepped", function(dt)
        self:ProcessMovement(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function MovementPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do unsub() end
    self.Subscriptions = {}
end

function MovementPlugin:ProcessMovement(dt)
    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if self.Config.Movement.BypassSpeed and hum.MoveDirection.Magnitude > 0 then
        local speedBoost = self.Config.Movement.SpeedValue or 28
        local adjusted = hum.MoveDirection * (speedBoost * dt)
        local safe = self.Config.Movement.SmoothMove and adjusted * 0.9 or adjusted
        root.CFrame = root.CFrame + safe
    end

    if self.Config.Movement.Bhop and hum.FloorMaterial ~= Enum.Material.Air and tick() - self.LastJumpTick > 0.08 then
        if self.Config.Movement.BhopHold then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        else
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        self.LastJumpTick = tick()
    end

    if self.Config.Movement.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanCollide = false
                end)
            end
        end
    end

    if self.Config.Movement.Fly then
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end

        if moveDir.Magnitude > 0 then
            root.CFrame = root.CFrame + (moveDir.Unit * ((self.Config.Movement.FlySpeed or 60) * dt))
        end

        root.AssemblyLinearVelocity = Vector3.new(0, 0.08, 0)
    end

    if self.Config.Movement.AntiVoid and root.Position.Y < -60 then
        root.CFrame = CFrame.new(root.Position.X, 60, root.Position.Z)
        root.AssemblyLinearVelocity = Vector3.zero
    end

    if self.Config.Movement.SilentGround then
        if hum.FloorMaterial ~= Enum.Material.Air then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X * 0.98, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z * 0.98)
        end
    end

    if self.Config.Movement.Slide then
        local moveMag = hum.MoveDirection.Magnitude
        if moveMag > 0.2 and hum.FloorMaterial ~= Enum.Material.Air then
            root.CFrame = root.CFrame + (hum.MoveDirection.Unit * (self.Config.Movement.SlideSpeed or 6) * dt)
        end
    end
end

return MovementPlugin