local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local VisualsPlugin = {}
VisualsPlugin.__index = VisualsPlugin

function VisualsPlugin.new()
    return setmetatable({
        Name = "Visuals",
        Subscriptions = {},
        Cache = {},
        CurrentTarget = nil,
        LastRenderTime = 0
    }, VisualsPlugin)
end

function VisualsPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    self.Security = DI:Resolve("Security")

    self.FOVCircle = Drawing.new("Circle")
    self.FOVCircle.Thickness = 1.2
    self.FOVCircle.NumSides = 64
    self.FOVCircle.Visible = false

    self.OverlayGlow = Drawing.new("Circle")
    self.OverlayGlow.Thickness = 1
    self.OverlayGlow.NumSides = 48
    self.OverlayGlow.Visible = false
end

function VisualsPlugin:AddPlayer(player)
    if player == LocalPlayer or self.Cache[player] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "NexusChams"
    highlight.FillTransparency = 0.25
    highlight.OutlineTransparency = 0
    highlight.Enabled = false

    self.Cache[player] = {
        Box = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        HealthBar = Drawing.new("Line"),
        HealthBarBg = Drawing.new("Line"),
        CornerBox = Drawing.new("Line"),
        Highlight = highlight,
        LastSeen = os.clock()
    }

    local c = self.Cache[player]
    c.Box.Thickness = 1
    c.Box.Filled = false
    c.Tracer.Thickness = 1
    c.Name.Size = 13
    c.Name.Center = true
    c.Name.Outline = true
    c.HealthBar.Thickness = 2
    c.HealthBarBg.Thickness = 2
    c.CornerBox.Thickness = 1
end

function VisualsPlugin:RemovePlayer(player)
    local cache = self.Cache[player]
    if cache then
        pcall(function() cache.Box:Remove() end)
        pcall(function() cache.Tracer:Remove() end)
        pcall(function() cache.Name:Remove() end)
        pcall(function() cache.HealthBar:Remove() end)
        pcall(function() cache.HealthBarBg:Remove() end)
        pcall(function() cache.CornerBox:Remove() end)
        if cache.Highlight then cache.Highlight:Destroy() end
        self.Cache[player] = nil
    end
end

function VisualsPlugin:Start()
    for _, p in ipairs(Players:GetPlayers()) do self:AddPlayer(p) end
    table.insert(self.Subscriptions, Players.PlayerAdded:Connect(function(p) self:AddPlayer(p) end))
    table.insert(self.Subscriptions, Players.PlayerRemoving:Connect(function(p) self:RemovePlayer(p) end))

    local sub1 = self.EventBus:Subscribe("Combat/TargetChanged", function(target)
        self.CurrentTarget = target
    end)

    local sub2 = self.EventBus:Subscribe("Engine/RenderStepped", function(dt)
        self.LastRenderTime = dt
        self:RenderESP()
    end)

    table.insert(self.Subscriptions, sub1)
    table.insert(self.Subscriptions, sub2)
end

function VisualsPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if type(unsub) == "function" then
            unsub()
        end
    end
    self.Subscriptions = {}
    self.FOVCircle.Visible = false
    for _, cache in pairs(self.Cache) do
        if cache.Box then cache.Box.Visible = false end
        if cache.Tracer then cache.Tracer.Visible = false end
        if cache.Name then cache.Name.Visible = false end
        if cache.HealthBar then cache.HealthBar.Visible = false end
        if cache.HealthBarBg then cache.HealthBarBg.Visible = false end
        if cache.CornerBox then cache.CornerBox.Visible = false end
        if cache.Highlight then cache.Highlight.Enabled = false end
    end
end

function VisualsPlugin:GetPlayerColor(player, char)
    local isTarget = char and (char == self.CurrentTarget)
    if isTarget then
        return Color3.fromRGB(255, 170, 0)
    end
    return self.Config.Visuals.VisibleColor
end

function VisualsPlugin:RenderESP()
    if not Camera then return end

    self.FOVCircle.Visible = self.Config.Combat.ShowFOV and self.Config.Visuals.ESP
    self.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    self.FOVCircle.Radius = self.Config.Combat.FOV
    self.FOVCircle.Color = self.Config.Visuals.VisibleColor

    self.OverlayGlow.Visible = self.Config.Visuals.ESP and self.Config.Visuals.Chams
    self.OverlayGlow.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    self.OverlayGlow.Radius = math.max(40, self.Config.Combat.FOV - 40)
    self.OverlayGlow.Color = Color3.fromRGB(255, 255, 255)

    if not self.Config.Visuals.ESP then
        for _, cache in pairs(self.Cache) do
            if cache.Box then cache.Box.Visible = false end
            if cache.Tracer then cache.Tracer.Visible = false end
            if cache.Name then cache.Name.Visible = false end
            if cache.HealthBar then cache.HealthBar.Visible = false end
            if cache.HealthBarBg then cache.HealthBarBg.Visible = false end
            if cache.CornerBox then cache.CornerBox.Visible = false end
            if cache.Highlight then cache.Highlight.Enabled = false end
        end
        return
    end

    for player, cache in pairs(self.Cache) do
        local success, char = pcall(function()
            return player.Character
        end)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local isEnemy = not self.Config.Combat.TeamCheck or (player.Team ~= LocalPlayer.Team)

        if success and char and root and hum and hum.Health > 0 and isEnemy then
            cache.LastSeen = os.clock()

            if self.Config.Visuals.Chams then
                if cache.Highlight.Parent ~= char then
                    cache.Highlight.Parent = char
                end
                cache.Highlight.Enabled = true
                local color = self:GetPlayerColor(player, char)
                cache.Highlight.FillColor = color
                cache.Highlight.OutlineColor = color
            else
                cache.Highlight.Enabled = false
            end

            local rootPos = self.Security and self.Security:SanitizeVector(root.Position) or root.Position
            local pos, onScreen = pcall(function()
                return Camera:WorldToViewportPoint(rootPos)
            end)

            if onScreen then
                local head = char:FindFirstChild("Head")
                local headPos = head and pcall(function()
                    return Camera:WorldToViewportPoint(self.Security and self.Security:SanitizeVector(head.Position + Vector3.new(0, 0.5, 0)) or (head.Position + Vector3.new(0, 0.5, 0)))
                end) or nil
                local legPos = pcall(function()
                    return Camera:WorldToViewportPoint(self.Security and self.Security:SanitizeVector(rootPos - Vector3.new(0, 3, 0)) or (rootPos - Vector3.new(0, 3, 0)))
                end)

                local headScreen = headPos and headPos[1] or pos[1]
                local legScreen = legPos and legPos[1] or pos[1]
                local height = math.abs(headScreen.Y - legScreen.Y)
                local width = math.max(18, height / 2)
                local color = self:GetPlayerColor(player, char)

                if self.Config.Visuals.Box then
                    cache.Box.Size = Vector2.new(width, height)
                    cache.Box.Position = Vector2.new(pos[1].X - width / 2, headScreen.Y)
                    cache.Box.Color = color
                    cache.Box.Visible = true
                else
                    cache.Box.Visible = false
                end

                if self.Config.Visuals.CornerBox then
                    local x1, y1 = pos[1].X - width / 2, headScreen.Y
                    local x2, y2 = pos[1].X + width / 2, headScreen.Y
                    local x3, y3 = pos[1].X - width / 2, headScreen.Y + height
                    local x4, y4 = pos[1].X + width / 2, headScreen.Y + height
                    cache.CornerBox.From = Vector2.new(x1, y1)
                    cache.CornerBox.To = Vector2.new(x1 + width * 0.2, y1)
                    cache.CornerBox.Color = color
                    cache.CornerBox.Visible = true
                else
                    cache.CornerBox.Visible = false
                end

                if self.Config.Visuals.CornerBox then
                    local x1, y1 = pos[1].X - width / 2, headScreen.Y
                    local x2, y2 = pos[1].X + width / 2, headScreen.Y
                    local x3, y3 = pos[1].X - width / 2, headScreen.Y + height
                    local x4, y4 = pos[1].X + width / 2, headScreen.Y + height
                    cache.CornerBox.From = Vector2.new(x1, y1)
                    cache.CornerBox.To = Vector2.new(x1 + width * 0.25, y1)
                    cache.CornerBox.Color = color
                    cache.CornerBox.Visible = true
                else
                    cache.CornerBox.Visible = false
                end

                if self.Config.Visuals.Tracers then
                    cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    cache.Tracer.To = Vector2.new(pos[1].X, legScreen.Y)
                    cache.Tracer.Color = color
                    cache.Tracer.Visible = true
                else
                    cache.Tracer.Visible = false
                end

                if self.Config.Visuals.HealthBar then
                    local healthRatio = math.clamp((hum.Health or 0) / math.max(1, hum.MaxHealth or 100), 0, 1)
                    local barHeight = height * healthRatio
                    local barY = headScreen.Y + (height - barHeight)
                    cache.HealthBarBg.From = Vector2.new(pos[1].X + width / 2 + 6, headScreen.Y)
                    cache.HealthBarBg.To = Vector2.new(pos[1].X + width / 2 + 6, headScreen.Y + height)
                    cache.HealthBarBg.Color = Color3.fromRGB(20, 20, 20)
                    cache.HealthBarBg.Visible = true
                    cache.HealthBar.From = Vector2.new(pos[1].X + width / 2 + 6, barY)
                    cache.HealthBar.To = Vector2.new(pos[1].X + width / 2 + 6, headScreen.Y + height)
                    cache.HealthBar.Color = healthRatio > 0.5 and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 90, 90)
                    cache.HealthBar.Visible = true
                else
                    cache.HealthBar.Visible = false
                    cache.HealthBarBg.Visible = false
                end

                if self.Config.Visuals.HealthBar then
                    local healthRatio = math.clamp((hum.Health or 0) / math.max(1, hum.MaxHealth or 100), 0, 1)
                    local barHeight = height * healthRatio
                    local barY = headScreen.Y + (height - barHeight)
                    cache.HealthBarBg.From = Vector2.new(pos[1].X + width / 2 + 6, headScreen.Y)
                    cache.HealthBarBg.To = Vector2.new(pos[1].X + width / 2 + 6, headScreen.Y + height)
                    cache.HealthBarBg.Color = Color3.fromRGB(30, 30, 30)
                    cache.HealthBarBg.Visible = true
                    cache.HealthBar.From = Vector2.new(pos[1].X + width / 2 + 6, barY)
                    cache.HealthBar.To = Vector2.new(pos[1].X + width / 2 + 6, headScreen.Y + height)
                    cache.HealthBar.Color = healthRatio > 0.5 and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 90, 90)
                    cache.HealthBar.Visible = true
                else
                    cache.HealthBar.Visible = false
                    cache.HealthBarBg.Visible = false
                end

                if self.Config.Visuals.NameTags then
                    cache.Name.Text = string.format("%s [%d studs]", player.Name, math.floor((rootPos - Camera.CFrame.Position).Magnitude))
                    cache.Name.Position = Vector2.new(pos[1].X, headScreen.Y - 18)
                    cache.Name.Color = Color3.fromRGB(255, 255, 255)
                    cache.Name.Visible = true
                else
                    cache.Name.Visible = false
                end
            else
                cache.Box.Visible = false
                cache.Tracer.Visible = false
                cache.Name.Visible = false
                cache.CornerBox.Visible = false
                cache.HealthBar.Visible = false
                cache.HealthBarBg.Visible = false
            end
        else
            cache.Box.Visible = false
            cache.Tracer.Visible = false
            cache.Name.Visible = false
            cache.CornerBox.Visible = false
            cache.HealthBar.Visible = false
            cache.HealthBarBg.Visible = false
            if cache.Highlight then cache.Highlight.Enabled = false end
        end
    end
end

return VisualsPlugin