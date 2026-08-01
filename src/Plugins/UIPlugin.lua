local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local UIPlugin = {}
UIPlugin.__index = UIPlugin

function UIPlugin.new()
    return setmetatable({
        Name = "UI",
        Visible = true,
        Elements = {},
        Subscriptions = {},
        IntroVisible = true,
        IntroTimer = 0,
        MusicEnabled = true,
        MusicVolume = 0.35,
        GlowPhase = 0
    }, UIPlugin)
end

function UIPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    self.FileManager = DI:Resolve("FileManager")

    self.Window = Drawing.new("Square")
    self.Window.Size = Vector2.new(380, 450)
    self.Window.Position = Vector2.new(120, 120)
    self.Window.Color = Color3.fromRGB(18, 18, 22)
    self.Window.Filled = true
    self.Window.Visible = true

    self.WindowGlow = Drawing.new("Square")
    self.WindowGlow.Size = Vector2.new(390, 460)
    self.WindowGlow.Position = Vector2.new(115, 115)
    self.WindowGlow.Color = Color3.fromRGB(255, 90, 200)
    self.WindowGlow.Filled = false
    self.WindowGlow.Thickness = 2
    self.WindowGlow.Visible = true

    self.Title = Drawing.new("Text")
    self.Title.Text = "Apex Nexus Enterprise"
    self.Title.Size = 16
    self.Title.Color = Color3.fromRGB(255, 255, 255)
    self.Title.Position = Vector2.new(130, 130)
    self.Title.Visible = true

    self.SubTitle = Drawing.new("Text")
    self.SubTitle.Text = "by Sebastian"
    self.SubTitle.Size = 12
    self.SubTitle.Color = Color3.fromRGB(255, 140, 220)
    self.SubTitle.Position = Vector2.new(130, 152)
    self.SubTitle.Visible = true

    self.IntroText = Drawing.new("Text")
    self.IntroText.Text = "Loading..."
    self.IntroText.Size = 18
    self.IntroText.Color = Color3.fromRGB(255, 255, 255)
    self.IntroText.Position = Vector2.new(260, 320)
    self.IntroText.Visible = true

    self.StatusText = Drawing.new("Text")
    self.StatusText.Text = "Phonk Music: ON"
    self.StatusText.Size = 12
    self.StatusText.Color = Color3.fromRGB(0, 255, 140)
    self.StatusText.Position = Vector2.new(140, 600)
    self.StatusText.Visible = true

    self.LastToggleTime = 0
    self.YOffset = 185
end

function UIPlugin:AddToggle(label, category, key)
    local text = Drawing.new("Text")
    local state = self.Config[category][key]
    text.Text = string.format(" [ %s ] %s", state and "X" or " ", label)
    text.Size = 13
    text.Color = state and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 60, 60)
    text.Position = Vector2.new(140, self.YOffset)
    text.Visible = self.Visible

    table.insert(self.Elements, { Drawing = text, Cat = category, Key = key, Label = label })
    self.YOffset = self.YOffset + 24
end

function UIPlugin:UpdateIntro(dt)
    self.IntroTimer = self.IntroTimer + dt
    self.GlowPhase = self.GlowPhase + dt * 2

    if self.IntroVisible then
        local alpha = 0.5 + (math.sin(self.GlowPhase) * 0.5)
        self.WindowGlow.Color = Color3.fromRGB(255, 90, 200)
        self.IntroText.Text = string.format("Loading%s", string.rep(".", (math.floor(self.IntroTimer * 3) % 4)))
        self.IntroText.Position = Vector2.new(250 + math.sin(self.GlowPhase) * 8, 320 + math.cos(self.GlowPhase) * 6)
    end

    if self.IntroTimer > 1.8 then
        self.IntroVisible = false
        self.IntroText.Visible = false
        self.WindowGlow.Thickness = 1.5
    end
end

function UIPlugin:RefreshVisibility()
    self.Window.Visible = self.Visible
    self.WindowGlow.Visible = self.Visible
    self.Title.Visible = self.Visible
    self.SubTitle.Visible = self.Visible
    self.StatusText.Visible = self.Visible
    self.IntroText.Visible = self.Visible and self.IntroVisible
    for _, el in ipairs(self.Elements) do el.Drawing.Visible = self.Visible end
end

function UIPlugin:Start()
    self:AddToggle("Silent Aim", "Combat", "SilentAim")
    self:AddToggle("Triggerbot", "Combat", "Triggerbot")
    self:AddToggle("ESP Boxes", "Visuals", "Box")
    self:AddToggle("ESP Chams", "Visuals", "Chams")
    self:AddToggle("ESP Tracers", "Visuals", "Tracers")
    self:AddToggle("2D Radar", "Visuals", "Radar")
    self:AddToggle("Speed Bypass", "Movement", "BypassSpeed")
    self:AddToggle("Fly Mode", "Movement", "Fly")
    self:AddToggle("Noclip", "Movement", "Noclip")
    self:AddToggle("Bunny Hop", "Movement", "Bhop")

    self:RefreshVisibility()

    local sub1 = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Insert then
            self.Visible = not self.Visible
            self:RefreshVisibility()
        elseif input.KeyCode == Enum.KeyCode.M and self.Visible then
            self.MusicEnabled = not self.MusicEnabled
            self.StatusText.Text = self.MusicEnabled and "Phonk Music: ON" or "Phonk Music: OFF"
            self.StatusText.Color = self.MusicEnabled and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 90, 90)
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self.Visible then
            local now = os.clock()
            if now - self.LastToggleTime < 0.12 then return end
            self.LastToggleTime = now

            local mPos = UserInputService:GetMouseLocation()
            for _, el in ipairs(self.Elements) do
                local pos = el.Drawing.Position
                if mPos.X >= pos.X and mPos.X <= pos.X + 220 and mPos.Y >= pos.Y and mPos.Y <= pos.Y + 20 then
                    local current = self.Config[el.Cat][el.Key]
                    self.Config[el.Cat][el.Key] = not current
                    local newState = self.Config[el.Cat][el.Key]
                    el.Drawing.Text = string.format(" [ %s ] %s", newState and "X" or " ", el.Label)
                    el.Drawing.Color = newState and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 60, 60)
                    pcall(function()
                        self.FileManager:Save(self.Config)
                    end)
                end
            end
        end
    end)
    table.insert(self.Subscriptions, sub1)

    local sub2 = RunService.RenderStepped:Connect(function(dt)
        self:UpdateIntro(dt)
    end)
    table.insert(self.Subscriptions, sub2)
end

function UIPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then unsub:Disconnect() end
    end
    self.Subscriptions = {}
    self.Window.Visible = false
    self.WindowGlow.Visible = false
    self.Title.Visible = false
    self.SubTitle.Visible = false
    self.StatusText.Visible = false
    self.IntroText.Visible = false
    for _, el in ipairs(self.Elements) do el.Drawing.Visible = false end
end

return UIPlugin