local RunService = game:GetService("RunService")

local PerformanceGuardPlugin = {}
PerformanceGuardPlugin.__index = PerformanceGuardPlugin

function PerformanceGuardPlugin.new()
    return setmetatable({
        Name = "PerformanceGuard",
        Active = false,
        Subscriptions = {},
        LastScan = 0,
        AdaptiveState = {
            ThrottleLevel = 0,
            CleanupCycles = 0,
            LastQualityDrop = 0,
            StableSamples = 0
        },
        Profile = {}
    }, PerformanceGuardPlugin)
end

function PerformanceGuardPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
    self.Diagnostics = DI:Resolve("Diagnostics")
end

function PerformanceGuardPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:Process(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function PerformanceGuardPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function PerformanceGuardPlugin:Process(dt)
    if not self.Config.PerformanceGuard or not self.Config.PerformanceGuard.Enabled then return end

    local now = tick()
    if now - self.LastScan < (self.Config.PerformanceGuard.ScanInterval or 0.2) then return end
    self.LastScan = now

    local profile = self:CaptureProfile(dt)
    self.Profile = profile
    self:ApplyAdaptiveThrottle(profile)
    self:RunCleanup(profile)

    if self.EventBus then
        pcall(function()
            self.EventBus:Publish("Framework/Performance", profile)
        end)
    end
end

function PerformanceGuardPlugin:CaptureProfile(dt)
    local fps = 0
    if dt and dt > 0 then
        fps = math.max(1, math.floor(1 / dt))
    end

    local memory = 0
    local success, result = pcall(function()
        return gcinfo and gcinfo() or 0
    end)
    if success then
        memory = tonumber(result) or 0
    end

    return {
        Timestamp = os.clock(),
        FPS = fps,
        Memory = memory,
        ThrottleLevel = self.AdaptiveState.ThrottleLevel,
        CleanupCycles = self.AdaptiveState.CleanupCycles,
        StableSamples = self.AdaptiveState.StableSamples
    }
end

function PerformanceGuardPlugin:ApplyAdaptiveThrottle(profile)
    local cfg = self.Config.PerformanceGuard or {}
    local level = self.AdaptiveState.ThrottleLevel

    if profile.FPS < (cfg.LowFPSThreshold or 22) then
        level = math.min(3, level + 1)
    elseif profile.FPS > 55 then
        level = math.max(0, level - 1)
    else
        self.AdaptiveState.StableSamples = self.AdaptiveState.StableSamples + 1
    end

    self.AdaptiveState.ThrottleLevel = level

    if level >= 2 and cfg.AggressiveCleanup then
        self:ScheduleCleanup()
    end
end

function PerformanceGuardPlugin:ScheduleCleanup()
    self.AdaptiveState.CleanupCycles = self.AdaptiveState.CleanupCycles + 1
    self:RunCleanup(self.Profile)
end

function PerformanceGuardPlugin:RunCleanup(profile)
    if not profile then return end
    local cfg = self.Config.PerformanceGuard or {}

    if cfg.AggressiveCleanup and profile.Memory > (cfg.MemoryPressureThreshold or 220) then
        collectgarbage()
        collectgarbage("collect")
    end

    if self.AdaptiveState.CleanupCycles > 15 then
        self.AdaptiveState.CleanupCycles = 0
        self.AdaptiveState.StableSamples = 0
    end
end

function PerformanceGuardPlugin:GetProfile()
    return self.Profile
end

return PerformanceGuardPlugin
