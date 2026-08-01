local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera

local SpectatorPlugin = {}
SpectatorPlugin.__index = SpectatorPlugin

function SpectatorPlugin.new()
    return setmetatable({
        Name = "Spectator Warning",
        Subscriptions = {},
        Spectators = {}
    }, SpectatorPlugin)
end

function SpectatorPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    
    -- Ekrandaki Uyarı Yazısı
    self.WarningText = Drawing.new("Text")
    self.WarningText.Size = 18
    self.WarningText.Color = Color3.fromRGB(255, 50, 50)
    self.WarningText.Center = true
    self.WarningText.Outline = true
    self.WarningText.Position = Vector2.new(Camera.ViewportSize.X / 2, 50)
    self.WarningText.Visible = false
end

function SpectatorPlugin:Start()
    local sub = self.EventBus:Subscribe("Engine/RenderStepped", function()
        self:CheckSpectators()
    end)
    table.insert(self.Subscriptions, sub)
end

function SpectatorPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do unsub() end
    self.Subscriptions = {}
    self.WarningText.Visible = false
end

function SpectatorPlugin:CheckSpectators()
    self.Spectators = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Basit kamera takibi (Roblox motorunda diğer oyuncuların kamerasını doğrudan okumak zordur, 
            -- ancak belirli oyun motoru açıklarında veya custom spectator sistemlerinde kontrol edilebilir)
            pcall(function()
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then
                    -- Eğer karakteri yoksa ama oyundaysa, büyük ihtimalle izleyici (spectator) modundadır
                    table.insert(self.Spectators, player.Name)
                end
            end)
        end
    end
    
    if #self.Spectators > 0 then
        self.WarningText.Text = "⚠️ DIKKAT! IZLENIYORSUN: " .. table.concat(self.Spectators, ", ")
        self.WarningText.Visible = true
        
        -- Eğer biri izliyorsa Rage özelliklerini (Fly, Aimbot vb.) otomatik kapat (Panic Mode)
        -- self.EventBus:Publish("Security/PanicMode")
    else
        self.WarningText.Visible = false
    end
end

return SpectatorPlugin