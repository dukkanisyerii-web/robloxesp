local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local RadarPlugin = {}
RadarPlugin.__index = RadarPlugin

function RadarPlugin.new()
    return setmetatable({
        Name = "Radar",
        Subscriptions = {},
        Dots = {}
    }, RadarPlugin)
end

function RadarPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    
    -- Radar Arka Plan Kutusu
    self.Background = Drawing.new("Square")
    self.Background.Size = Vector2.new(150, 150)
    self.Background.Position = Vector2.new(30, 50)
    self.Background.Color = Color3.fromRGB(15, 15, 20)
    self.Background.Filled = true
    self.Background.Visible = false
end

function RadarPlugin:Start()
    local sub = self.EventBus:Subscribe("Engine/RenderStepped", function()
        self:UpdateRadar()
    end)
    table.insert(self.Subscriptions, sub)
end

function RadarPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do unsub() end
    self.Subscriptions = {}
    self.Background.Visible = false
    for _, dot in pairs(self.Dots) do dot:Remove() end
    self.Dots = {}
end

function RadarPlugin:UpdateRadar()
    local show = self.Config.Visuals.Radar and self.Config.Visuals.ESP
    self.Background.Visible = show
    
    if not show then
        for _, dot in pairs(self.Dots) do dot.Visible = false end
        return
    end
    
    local centerRadar = self.Background.Position + (self.Background.Size / 2)
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not localRoot then return end
    
    local index = 1
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local isEnemy = not self.Config.Combat.TeamCheck or (player.Team ~= LocalPlayer.Team)
            
            if root and isEnemy then
                local dot = self.Dots[index]
                if not dot then
                    dot = Drawing.new("Circle")
                    dot.Radius = 3
                    dot.Filled = true
                    self.Dots[index] = dot
                end
                
                local relPos = localRoot.CFrame:PointToObjectSpace(root.Position)
                local radarPos = centerRadar + Vector2.new(relPos.X, relPos.Z) * 0.8
                
                -- Radar sınırları içinde tut
                local distFromCenter = (radarPos - centerRadar).Magnitude
                if distFromCenter < 70 then
                    dot.Position = radarPos
                    dot.Color = self.Config.Visuals.VisibleColor
                    dot.Visible = true
                else
                    dot.Visible = false
                end
                index = index + 1
            end
        end
    end
end

return RadarPlugin