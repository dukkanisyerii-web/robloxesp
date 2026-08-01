local MemoryScannerPlugin = {}
MemoryScannerPlugin.__index = MemoryScannerPlugin

function MemoryScannerPlugin.new()
    return setmetatable({
        Name = "MemoryScanner",
        IsLogging = true,
        CaptureArguments = true,
        CaptureStack = true,
        Active = false,
        Subscriptions = {},
        LogEntries = {},
        FilteredNames = {
            AnalyticsEvent = true,
            ChatService = true,
            ReplicatedStorage = true
        },
        TrackedRemotes = {},
        Stats = {
            TotalIntercepts = 0,
            TotalIgnored = 0,
            TotalBlocked = 0,
            UniqueRemotes = 0,
            LastInterceptAt = nil
        },
        MaxLogEntries = 150
    }, MemoryScannerPlugin)
end

function MemoryScannerPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")

    local memoryConfig = self.Config and self.Config.MemoryScanner or {}
    if memoryConfig.Enabled ~= nil then
        self.IsLogging = memoryConfig.Enabled
    end

    if memoryConfig.CaptureArguments ~= nil then
        self.CaptureArguments = memoryConfig.CaptureArguments
    end

    if memoryConfig.CaptureStack ~= nil then
        self.CaptureStack = memoryConfig.CaptureStack
    end

    if type(memoryConfig.MaxLogEntries) == "number" and memoryConfig.MaxLogEntries > 0 then
        self.MaxLogEntries = memoryConfig.MaxLogEntries
    end

    for remoteName, enabled in pairs(memoryConfig.BlockedRemotes or {}) do
        if enabled then
            self.FilteredNames[remoteName] = true
        end
    end
end

function MemoryScannerPlugin:ApplySettings(memoryConfig)
    if not memoryConfig then return end
    if memoryConfig.Enabled ~= nil then
        self.IsLogging = memoryConfig.Enabled
    end

    if memoryConfig.CaptureArguments ~= nil then
        self.CaptureArguments = memoryConfig.CaptureArguments
    end

    if memoryConfig.CaptureStack ~= nil then
        self.CaptureStack = memoryConfig.CaptureStack
    end

    if type(memoryConfig.MaxLogEntries) == "number" and memoryConfig.MaxLogEntries > 0 then
        self.MaxLogEntries = memoryConfig.MaxLogEntries
    end
end

function MemoryScannerPlugin:ResetStats()
    self.LogEntries = {}
    self.TrackedRemotes = {}
    self.Stats = {
        TotalIntercepts = 0,
        TotalIgnored = 0,
        TotalBlocked = 0,
        UniqueRemotes = 0,
        LastInterceptAt = nil
    }
end

function MemoryScannerPlugin:GetStats()
    self.Stats.UniqueRemotes = 0
    for _ in pairs(self.TrackedRemotes) do
        self.Stats.UniqueRemotes = self.Stats.UniqueRemotes + 1
    end
    return self.Stats
end

function MemoryScannerPlugin:Start()
    if self.Active then return end
    self.Active = true

    self.Subscriptions = {}

    if self.EventBus then
        table.insert(self.Subscriptions, self.EventBus:Subscribe("MemoryScanner/ToggleLogging", function(enabled)
            self.IsLogging = enabled
        end))

        table.insert(self.Subscriptions, self.EventBus:Subscribe("MemoryScanner/ApplySettings", function(settings)
            self:ApplySettings(settings)
        end))

        table.insert(self.Subscriptions, self.EventBus:Subscribe("MemoryScanner/ResetStats", function()
            self:ResetStats()
        end))
    end

    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(selfObj, ...)
            if not self.Active or not self.IsLogging then
                return oldNamecall(selfObj, ...)
            end

            local method = getnamecallmethod()
            local isRemoteCall = (method == "FireServer" or method == "InvokeServer")

            local isRemoteInstance = false
            if isRemoteCall then
                local okEvent, isRemoteEvent = pcall(function()
                    return selfObj:IsA("RemoteEvent")
                end)
                if okEvent and isRemoteEvent then
                    isRemoteInstance = true
                else
                    local okFunc, isRemoteFunction = pcall(function()
                        return selfObj:IsA("RemoteFunction")
                    end)
                    if okFunc and isRemoteFunction then
                        isRemoteInstance = true
                    end
                end
            end

            if isRemoteInstance then
                local remoteName = tostring(selfObj.Name or "Unknown")
                if self.FilteredNames[remoteName] then
                    self.Stats.TotalIgnored = self.Stats.TotalIgnored + 1
                    return oldNamecall(selfObj, ...)
                end

                self.Stats.TotalIntercepts = self.Stats.TotalIntercepts + 1
                self.Stats.LastInterceptAt = os.clock()
                self.TrackedRemotes[remoteName] = true

                local payload = {
                    Name = remoteName,
                    Method = method,
                    Arguments = self.CaptureArguments and {...} or nil,
                    Timestamp = os.clock(),
                    Stack = self.CaptureStack and debug.traceback("", 3) or nil
                }

                table.insert(self.LogEntries, payload)
                while #self.LogEntries > self.MaxLogEntries do
                    table.remove(self.LogEntries, 1)
                end

                if self.EventBus then
                    self.EventBus:Publish("MemoryScanner/RemoteIntercepted", payload)
                    self.EventBus:Publish("MemoryScanner/StatsUpdated", self:GetStats())
                else
                    print(string.format("[MemoryScanner] %s -> %s", remoteName, method))
                end
            end

            return oldNamecall(selfObj, ...)
        end)
    end)
end

function MemoryScannerPlugin:Stop()
    self.Active = false

    for _, unsub in ipairs(self.Subscriptions) do
        if type(unsub) == "function" then
            unsub()
        end
    end
    self.Subscriptions = {}
end

return MemoryScannerPlugin