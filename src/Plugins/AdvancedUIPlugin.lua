local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local AdvancedUIPlugin = {}
AdvancedUIPlugin.__index = AdvancedUIPlugin

function AdvancedUIPlugin.new()
    local self = setmetatable({}, AdvancedUIPlugin)
    self.Name = "AdvancedUI"
    self.IsOpen = true
    self.CurrentTab = "Combat"
    return self
end

function AdvancedUIPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    
    -- Ana Pencere (Drawing API Tabanlı Akıcı Vektör Çizimler)
    self.MainBox = Drawing.new("Square")
    self.MainBox.Size = Vector2.new(600, 400)
    self.MainBox.Position = Vector2.new(200, 150)
    self.MainBox.Color = Color3.fromRGB(12, 12, 16)
    self.MainBox.Filled = true
    self.MainBox.Visible = true

    -- Sol Sidebar (Menü Sekmeleri İçin)
    self.Sidebar = Drawing.new("Square")
    self.Sidebar.Size = Vector2.new(130, 400)
    self.Sidebar.Position = Vector2.new(200, 150)
    self.Sidebar.Color = Color3.fromRGB(18, 18, 24)
    self.Sidebar.Filled = true
    self.Sidebar.Visible = true

    -- Kayan Duyuru / Yazı (Marquee Text)
    self.MarqueeText = Drawing.new("Text")
    self.MarqueeText.Text = "⚡ APEX NEXUS ENTERPRISE v100.0 | MOBILE & PC SUPPORTED | SECURE BYPASS ACTIVE ⚡"
    self.MarqueeText.Size = 12
    self.MarqueeText.Color = Color3.fromRGB(0, 255, 150)
    self.MarqueeText.Position = Vector2.new(220, 115)
    self.MarqueeText.Visible = true
end

function AdvancedUIPlugin:Start()
    -- Aç/Kapat Tuşu (Insert veya Mobil için özel tetikleyici)
    local sub = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Insert then
            self.IsOpen = not self.IsOpen
            self.MainBox.Visible = self.IsOpen
            self.Sidebar.Visible = self.IsOpen
            self.MarqueeText.Visible = self.IsOpen
        end
    end)
    table.insert(self.Subscriptions, sub)
end

function AdvancedUIPlugin:Stop()
    if self.MainBox then self.MainBox:Remove() end
    if self.Sidebar then self.Sidebar:Remove() end
    if self.MarqueeText then self.MarqueeText:Remove() end
end

return AdvancedUIPlugin