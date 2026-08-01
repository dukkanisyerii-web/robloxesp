local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local AdvancedCombatPlugin = {}
AdvancedCombatPlugin.__index = AdvancedCombatPlugin

function AdvancedCombatPlugin.new()
    return setmetatable({
        Name = "AdvancedCombat",
        Subscriptions = {},
        Active = false,
        LastTrigger = 0,
        LastFire = 0,
        LastScan = 0,
        LastTargetChange = 0,
        CurrentTarget = nil,
        CurrentAimPart = nil,
        TargetHistory = {},
        RayParams = RaycastParams.new(),
        LastPrediction = Vector3.zero,
        LastCameraCFrame = CFrame.new()
    }, AdvancedCombatPlugin)
end

function AdvancedCombatPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    self.Security = DI:Resolve("Security")

    self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
    self.RayParams.IgnoreWater = true
end

function AdvancedCombatPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = self.EventBus:Subscribe("Engine/RenderStepped", function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function AdvancedCombatPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if type(unsub) == "function" then
            unsub()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function AdvancedCombatPlugin:GetPing()
    local success, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return (success and ping) and ping or 0.05
end

function AdvancedCombatPlugin:GetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

function AdvancedCombatPlugin:HasValidWeapon()
    local tool = self:GetWeapon()
    if not tool then return false end

    local name = string.lower(tool.Name or "")
    local blocked = {"sword", "baton", "knife", "melee", "tool"}
    for _, word in ipairs(blocked) do
        if string.find(name, word, 1, true) then
            return false
        end
    end

    return true
end

function AdvancedCombatPlugin:CanUseCombat()
    if not self.Config.AdvancedCombat or not self.Config.AdvancedCombat.Enabled then
        return false
    end

    local char = LocalPlayer.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    return true
end

function AdvancedCombatPlugin:IsVisible(targetPart)
    if not self.Config.AdvancedCombat.WallCheck then return true end
    if not targetPart then return false end

    local origin = Camera.CFrame.Position
    local direction = self.Security:SanitizeVector(targetPart.Position - origin)
    self.RayParams.FilterDescendantsInstances = {Camera, LocalPlayer.Character}

    local result = Workspace:Raycast(origin, direction, self.RayParams)
    if not result then
        return true
    end

    local part = result.Instance
    return part and (part:IsDescendantOf(targetPart.Parent) or part == targetPart)
end

function AdvancedCombatPlugin:GetCandidateParts(character)
    local parts = {}
    if not character then return parts end

    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    local root = character:FindFirstChild("HumanoidRootPart")

    if head then table.insert(parts, head) end
    if torso then table.insert(parts, torso) end
    if root then table.insert(parts, root) end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("BasePart") and string.lower(child.Name or "") == "humanoidrootpart" then
            table.insert(parts, child)
        end
    end

    return parts
end

function AdvancedCombatPlugin:GetAimPart(character)
    if not character then return nil end

    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    local root = character:FindFirstChild("HumanoidRootPart")

    local pref = self.Config.AdvancedCombat.HitboxPriority or "Head"
    if pref == "Head" and head then return head end
    if pref == "Torso" and torso then return torso end
    if pref == "Root" and root then return root end

    return head or torso or root
end

function AdvancedCombatPlugin:GetVisibleTargetParts(character)
    local parts = self:GetCandidateParts(character)
    local visible = {}
    for _, part in ipairs(parts) do
        if self:IsVisible(part) then
            table.insert(visible, part)
        end
    end
    return visible
end

function AdvancedCombatPlugin:ScoreTarget(player, character, rootPart, hum)
    local score = 0
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    local screenPos, onScreen = pcall(function()
        return Camera:WorldToViewportPoint(rootPart.Position)
    end)

    if not onScreen or not screenPos then
        return nil
    end

    local screenVector = Vector2.new(screenPos.X, screenPos.Y)
    local distance = (screenVector - center).Magnitude
    local fov = self.Config.AdvancedCombat.FOV or 220

    if distance > fov then
        return nil
    end

    score = score + (fov - distance) * 0.8
    score = score + (hum.Health or 0) * 0.02

    local visibleParts = self:GetVisibleTargetParts(character)
    if #visibleParts > 0 then
        score = score + 35
    end

    if self.CurrentTarget == character then
        score = score + 25
    end

    if self.Config.AdvancedCombat.TeamCheck and player.Team ~= LocalPlayer.Team then
        score = score + 10
    end

    if self.Config.AdvancedCombat.PrioritizeTargeted then
        local history = self.TargetHistory[player] or 0
        score = score + math.min(history * 3, 30)
    end

    return score, screenVector, distance
end

function AdvancedCombatPlugin:SelectTarget()
    local bestTarget = nil
    local bestScore = -math.huge
    local bestRoot = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if rootPart and hum and hum.Health > 0 then
                local isEnemy = not self.Config.AdvancedCombat.TeamCheck or (player.Team ~= LocalPlayer.Team)
                if isEnemy then
                    local score, _, _ = self:ScoreTarget(player, player.Character, rootPart, hum)
                    if score and score > bestScore then
                        bestScore = score
                        bestTarget = player.Character
                        bestRoot = rootPart
                    end
                end
            end
        end
    end

    return bestTarget, bestRoot
end

function AdvancedCombatPlugin:PredictPosition(aimPart)
    if not aimPart then return nil end

    local velocity = aimPart.AssemblyLinearVelocity or Vector3.zero
    local prediction = self.Config.AdvancedCombat.PredictionFactor or 0.16
    local ping = self:GetPing()
    local recoilScale = self.Config.AdvancedCombat.RecoilScale or 0.03
    local baseOffset = Vector3.new(0, recoilScale, 0)

    local predicted = aimPart.Position + (velocity * (prediction + ping))
    if self.Config.AdvancedCombat.RecoilCompensation then
        predicted = predicted + baseOffset
    end

    return predicted
end

function AdvancedCombatPlugin:ApplyAimAssist(targetPart, predictedPos)
    if not self.Config.AdvancedCombat.AimAssist then return end
    if not targetPart then return end

    local smoothness = self.Config.AdvancedCombat.Smoothness or 0.12
    local targetCF = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
    local nextCF = Camera.CFrame:Lerp(targetCF, smoothness)
    Camera.CFrame = nextCF
end

function AdvancedCombatPlugin:TryTriggerbot()
    if not self.Config.AdvancedCombat.Triggerbot then return end
    if not self:HasValidWeapon() then return end

    local now = tick()
    if now - self.LastTrigger < (self.Config.AdvancedCombat.TriggerDelay or 0.08) then
        return
    end

    local centerX = Camera.ViewportSize.X / 2
    local centerY = Camera.ViewportSize.Y / 2
    local mouseRay = Camera:ViewportPointToRay(centerX, centerY)
    self.RayParams.FilterDescendantsInstances = {Camera, LocalPlayer.Character}

    local result = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, self.RayParams)
    if not result or not result.Instance then return end

    local hitChar = result.Instance.Parent
    local hum = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local p = Players:GetPlayerFromCharacter(hitChar)
    if not p then return end

    local isEnemy = not self.Config.AdvancedCombat.TeamCheck or (p.Team ~= LocalPlayer.Team)
    if not isEnemy then return end

    self.LastTrigger = now
    pcall(function()
        local tool = self:GetWeapon()
        if tool then
            tool:Activate()
        end
    end)
end

function AdvancedCombatPlugin:TryAutoFire()
    if not self.Config.AdvancedCombat.AutoFire then return end
    if not self:HasValidWeapon() then return end

    local now = tick()
    if now - self.LastFire < (self.Config.AdvancedCombat.AutoFireDelay or 0.08) then
        return
    end

    local tool = self:GetWeapon()
    if not tool then return end

    self.LastFire = now
    pcall(function()
        tool:Activate()
    end)
end

function AdvancedCombatPlugin:Process(dt)
    if not self:CanUseCombat() then return end

    local now = tick()
    if now - self.LastScan < (self.Config.AdvancedCombat.ScanInterval or 0.025) then
        return
    end
    self.LastScan = now

    local target, rootPart = self:SelectTarget()
    if target ~= self.CurrentTarget then
        self.CurrentTarget = target
        self.LastTargetChange = now
        self.EventBus:Publish("Combat/TargetChanged", target)
    end

    if not target or not rootPart then
        return
    end

    self.CurrentAimPart = self:GetAimPart(target)

    if self.CurrentAimPart then
        local predictedPos = self:PredictPosition(self.CurrentAimPart)
        if predictedPos then
            self.LastPrediction = predictedPos
            self:ApplyAimAssist(self.CurrentAimPart, predictedPos)
        end
    end

    self:TryAutoFire()
    self:TryTriggerbot()

    if self.CurrentTarget then
        local player = Players:GetPlayerFromCharacter(self.CurrentTarget)
        if player then
            self.TargetHistory[player] = (self.TargetHistory[player] or 0) + 1
        end
    end
end

return AdvancedCombatPlugin
