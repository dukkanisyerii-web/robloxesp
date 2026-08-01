local ConsolePlugin = {}
ConsolePlugin.__index = ConsolePlugin

function ConsolePlugin.new()
    return setmetatable({
        Name = "Console",
        Logs = {},
        MaxLogLines = 10,
        Subscriptions = {}
    }, ConsolePlugin)
end

function ConsolePlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    
    -- Konsol Arka Planı
    self.Background = Drawing.new("Square")
    self.Background.Size = Vector2.new(450, 180)
    self.Background.Position = Vector2.new(20, 550)
    self.Background.Color = Color3.fromRGB(10, 10, 14)
    self.Background.Filled = true
    self.Background.Visible = true

    -- Konsol Satır Nesneleri (Pool Mantığı)
    self.LogLines = {}
    for i = 1, self.MaxLogLines do
        local textObj = Drawing.new("Text")
        textObj.Size = 12
        textObj.Color = Color3.fromRGB(200, 200, 210)
        textObj.Position = Vector2.new(30, 535 + (i * 15))
        textObj.Visible = true
        table.insert(self.LogLines, textObj)
    end
end

function ConsolePlugin:Start()
    -- EventBus üzerinden gelen logları dinle
    local sub = self.EventBus:Subscribe("Engine/Log", function(message)
        self:PushLog(message)
    end)
    table.insert(self.Subscriptions, sub)
    
    -- RemoteSpy ve diğer modüllerden gelen verileri de konsola bağla
    local spySub = self.EventBus:Subscribe("RemoteSpy/DataIntercepted", function(data)
        self:PushLog(string.format("[Remote] %s (%s)", data.Name, data.Method))
    end)
    table.insert(self.Subscriptions, spySub)
    
    self:PushLog("Apex Nexus Enterprise Console v110 Aktif.")
end

function ConsolePlugin:PushLog(msg)
    table.insert(self.Logs, msg)
    if #self.Logs > self.MaxLogLines then
        table.remove(self.Logs, 1)
    end
    self:UpdateDisplay()
end

function ConsolePlugin:UpdateDisplay()
    for i, lineObj in ipairs(self.LogLines) do
        local logMsg = self.Logs[i]
        if logMsg then
            lineObj.Text = logMsg
            lineObj.Visible = true
        else
            lineObj.Visible = false
        end
    end
end

function ConsolePlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do unsub() end
    self.Subscriptions = {}
    
    if self.Background then self.Background:Remove() end
    for _, lineObj in ipairs(self.LogLines) do
        pcall(function() lineObj:Remove() end)
    end
    self.LogLines = {}
end

return ConsolePlugin