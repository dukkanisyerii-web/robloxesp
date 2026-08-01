local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CombatPlugin = {}
CombatPlugin.__index = CombatPlugin

function CombatPlugin.new()
    return setmetatable({
        Name = "Combat",
        Subscriptions = {},
        RayParams = RaycastParams.new(),
        LastTrigger = 0,
        LastTargetChange = 0,
        LastAimTick = 0,
        CurrentTarget = nil,
        TargetHistory = {}
    }, CombatPlugin)
end

function CombatPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    self.Security = DI:Resolve("Security")

    self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
    self.RayParams.IgnoreWater = true
end

function CombatPlugin:Start()
    local sub = self.EventBus:Subscribe("Engine/RenderStepped", function(dt)
        self:ProcessCombat(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function CombatPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do unsub() end
    self.Subscriptions = {}
end

function CombatPlugin:GetPing()
    local success, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return (success and ping) and ping or 0.05
end

function CombatPlugin:IsVisible(targetPart)
    if not self.Config.Combat.WallCheck then return true end
    if not targetPart then return false end

    local origin = Camera.CFrame.Position
    local direction = self.Security:SanitizeVector(targetPart.Position - origin)
    self.RayParams.FilterDescendantsInstances = {Camera, LocalPlayer.Character}

    local result = Workspace:Raycast(origin, direction, self.RayParams)
    return (result and result.Instance:IsDescendantOf(targetPart.Parent)) or false
end

function CombatPlugin:GetBestTarget()
    local bestTarget = nil
    local minDistance = self.Config.Combat.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isEnemy = not self.Config.Combat.TeamCheck or (player.Team ~= LocalPlayer.Team)
            if isEnemy then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen and screenPos.Z > 0 then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist < minDistance and self:IsVisible(root) then
                            minDistance = dist
                            bestTarget = player.Character
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

function CombatPlugin:GetAimPart(target)
    if not target then return nil end

    local head = target:FindFirstChild("Head")
    local torso = target:FindFirstChild("Torso") or target:FindFirstChild("UpperTorso")
    local root = target:FindFirstChild("HumanoidRootPart")

    if self.Config.Combat.HitboxPriority == "Head" and head then
        return head
    elseif self.Config.Combat.HitboxPriority == "Torso" and torso then
        return torso
    elseif self.Config.Combat.HitboxPriority == "Root" and root then
        return root
    end

    return (self.Config.Combat.AutoHeadLock and head) or root or torso
end

function CombatPlugin:HasValidWeapon()
    local char = LocalPlayer.Character
    if not char then return false end

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end

    local toolName = string.lower(tool.Name or "")
    local blockedWords = {"sword", "baton", "melee", "tool"}
    for _, word in ipairs(blockedWords) do
        if string.find(toolName, word, 1, true) then
            return false
        end
    end

    return true
end

function CombatPlugin:ApplyRecoilCompensation(aimPart, predictedPos)
    if not self.Config.Combat.RecoilCompensation then return predictedPos end
    local recoilScale = self.Config.Combat.RecoilScale or 0.04
    local offset = Vector3.new(0, recoilScale, 0)
    return predictedPos + offset
end

function CombatPlugin:ProcessCombat(dt)
    local target = self:GetBestTarget()
    if target ~= self.LastTarget then
        self.LastTarget = target
        self.LastTargetChange = tick()
        self.EventBus:Publish("Combat/TargetChanged", target)
    end

    if not target then
        return
    end

    local aimPart = self:GetAimPart(target)

    if aimPart then
        local velocity = aimPart.AssemblyLinearVelocity or Vector3.zero
        local predictedPos = aimPart.Position + (velocity * (self.Config.Combat.PredictionFactor + self:GetPing()))
        predictedPos = self:ApplyRecoilCompensation(aimPart, predictedPos)

        if self.Config.Combat.Aimlock and not self.Config.Combat.SilentAim then
            local targetCF = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, self.Config.Combat.Smoothness)
        end
    end

    if self.Config.Combat.Triggerbot and self:HasValidWeapon() and (tick() - self.LastTrigger >= (self.Config.Combat.TriggerDelay or 0.08)) then
        local mouseRay = Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        self.RayParams.FilterDescendantsInstances = {Camera, LocalPlayer.Character}
        local res = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, self.RayParams)
        if res and res.Instance then
            local hitChar = res.Instance.Parent
            local hum = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local p = Players:GetPlayerFromCharacter(hitChar)
                if p and (not self.Config.Combat.TeamCheck or p.Team ~= LocalPlayer.Team) then
                    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then
                        self.LastTrigger = tick()
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
        end
    end
end

return CombatPlugin