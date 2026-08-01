local Config = {
    Version = "v100.0-Enterprise",
    Combat = {
        SilentAim = true,
        Aimlock = false,
        AutoHeadLock = true,
        Triggerbot = true,
        TriggerDelay = 0.08,
        Smoothness = 0.15,
        PredictionFactor = 0.165,
        WallCheck = true,
        TeamCheck = true,
        FOV = 250,
        ShowFOV = true,
        HitboxPriority = "Head",
        RecoilCompensation = true,
        RecoilScale = 0.04
    },
    AdvancedCombat = {
        Enabled = true,
        AimAssist = true,
        AutoFire = false,
        AutoFireDelay = 0.07,
        Triggerbot = true,
        TriggerDelay = 0.06,
        ScanInterval = 0.025,
        WallCheck = true,
        TeamCheck = true,
        FOV = 220,
        PredictionFactor = 0.16,
        Smoothness = 0.12,
        HitboxPriority = "Head",
        RecoilCompensation = true,
        RecoilScale = 0.03,
        PrioritizeTargeted = true,
        PrioritizeVisible = true
    },
    Visuals = {
        ESP = true,
        Box = true,
        CornerBox = true,
        Tracers = true,
        Chams = true,
        Skeleton = true,
        HealthBar = true,
        NameTags = true,
        Radar = true,
        VisibleColor = Color3.fromRGB(0, 255, 120),
        HiddenColor = Color3.fromRGB(255, 45, 45)
    },
    Movement = {
        BypassSpeed = false,
        SpeedValue = 28,
        Fly = false,
        FlySpeed = 60,
        Noclip = false,
        Bhop = true,
        AntiVoid = true,
        Slide = false,
        SlideSpeed = 6,
        SmoothMove = true,
        BhopHold = true,
        SilentGround = true
    },
    MemoryScanner = {
        Enabled = true,
        CaptureArguments = true,
        CaptureStack = true,
        MaxLogEntries = 150,
        BlockedRemotes = {
            AnalyticsEvent = true,
            ChatService = true
        }
    },
    Ammo = {
        Enabled = true,
        MaxAmmo = 999,
        ScanInterval = 0.1,
        ApplyToBackpack = true
    },
    RareFeatures = {
        Enabled = true,
        ScanInterval = 0.05,
        GhostOutline = true,
        AuraPulse = true,
        TargetEcho = true
    },
    EliteRoblox = {
        Enabled = true,
        ScanInterval = 0.03,
        AdaptiveGlow = true,
        TemporalEcho = true,
        BloomTrail = true
    },
    Utility = {
        Enabled = true,
        ScanInterval = 0.05,
        AutoRecovery = true,
        SmartReset = true,
        FallbackProtection = true
    },
    Diagnostics = {
        Enabled = true,
        ScanInterval = 0.25,
        RecordEvents = true,
        MaxHistory = 120,
        AlertFPS = 20,
        AlertPing = 200,
        AlertMemory = 45000
    },
    PerformanceGuard = {
        Enabled = true,
        ScanInterval = 0.2,
        LowFPSThreshold = 22,
        MemoryPressureThreshold = 220,
        AggressiveCleanup = true
    },
    Resilience = {
        Enabled = true,
        ScanInterval = 0.3,
        RecoverOnStall = true,
        MaxRecoveryAttempts = 3
    },
    SessionAnalytics = {
        Enabled = true,
        ScanInterval = 0.2,
        MaxHistory = 180
    },
    RecoveryCoordinator = {
        Enabled = true,
        ScanInterval = 0.4,
        Cooldown = 2,
        MaxAttempts = 2,
        MinHeight = -1000
    }
}

return Config