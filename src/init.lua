local RunService = game:GetService("RunService")

local EventBus = require(script.Core.EventBus)
local DIContainer = require(script.Core.DIContainer)
local PluginManager = require(script.Core.PluginManager)
local Security = require(script.Core.Security)
local Config = require(script.Data.Config)
local FileManager = require(script.Data.FileManager)

local CombatPlugin = require(script.Plugins.CombatPlugin)
local VisualsPlugin = require(script.Plugins.VisualsPlugin)
local MovementPlugin = require(script.Plugins.MovementPlugin)
local RadarPlugin = require(script.Plugins.RadarPlugin)
local UIPlugin = require(script.Plugins.UIPlugin)
local MemoryScannerPlugin = require(script.Plugins.memoryScannerPlugin)
local AmmoPlugin = require(script.Plugins.AmmoPlugin)
local AdvancedCombatPlugin = require(script.Plugins.AdvancedCombatPlugin)
local RareFeaturesPlugin = require(script.Plugins.RareFeaturesPlugin)
local EliteRobloxPlugin = require(script.Plugins.EliteRobloxPlugin)
local UtilityPlugin = require(script.Plugins.UtilityPlugin)
local DiagnosticsPlugin = require(script.Plugins.DiagnosticsPlugin)
local PerformanceGuardPlugin = require(script.Plugins.PerformanceGuardPlugin)
local ResiliencePlugin = require(script.Plugins.ResiliencePlugin)
local SessionAnalyticsPlugin = require(script.Plugins.SessionAnalyticsPlugin)
local RecoveryCoordinatorPlugin = require(script.Plugins.RecoveryCoordinatorPlugin)

local ApexNexus = {}

function ApexNexus:Bootstrap()
    print("[NEXUS v100] Initializing Enterprise Core...")
    
    self.Security = Security.new()
    if not self.Security:VerifyEnvironment() then
        warn("[NEXUS Security] Uyarı: Güvenlik doğrulaması başarısız oldu!")
    end
    
    -- Config yükle
    FileManager:Load(Config)
    
    self.EventBus = EventBus.new()
    self.DI = DIContainer.new()
    
    self.DI:Register("EventBus", self.EventBus)
    self.DI:Register("Config", Config)
    self.DI:Register("FileManager", FileManager)
    self.DI:Register("Security", self.Security)
    
    self.PluginManager = PluginManager.new(self.DI)
    
    -- Plugin kayıtları
    self.PluginManager:Register(CombatPlugin)
    self.PluginManager:Register(VisualsPlugin)
    self.PluginManager:Register(MovementPlugin)
    self.PluginManager:Register(RadarPlugin)
    self.PluginManager:Register(UIPlugin)
    self.PluginManager:Register(MemoryScannerPlugin)
    self.PluginManager:Register(AmmoPlugin)
    self.PluginManager:Register(AdvancedCombatPlugin)
    self.PluginManager:Register(RareFeaturesPlugin)
    self.PluginManager:Register(EliteRobloxPlugin)
    self.PluginManager:Register(UtilityPlugin)
    self.PluginManager:Register(DiagnosticsPlugin)
    self.PluginManager:Register(PerformanceGuardPlugin)
    self.PluginManager:Register(ResiliencePlugin)
    self.PluginManager:Register(SessionAnalyticsPlugin)
    self.PluginManager:Register(RecoveryCoordinatorPlugin)
    
    -- Hepsini etkinleştir
    self.PluginManager:Enable("UI")
    self.PluginManager:Enable("Combat")
    self.PluginManager:Enable("Visuals")
    self.PluginManager:Enable("Movement")
    self.PluginManager:Enable("Radar")
    self.PluginManager:Enable("MemoryScanner")
    self.PluginManager:Enable("Ammo")
    self.PluginManager:Enable("AdvancedCombat")
    self.PluginManager:Enable("RareFeatures")
    self.PluginManager:Enable("EliteRoblox")
    self.PluginManager:Enable("Utility")
    self.PluginManager:Enable("Diagnostics")
    self.PluginManager:Enable("PerformanceGuard")
    self.PluginManager:Enable("Resilience")
    self.PluginManager:Enable("SessionAnalytics")
    self.PluginManager:Enable("RecoveryCoordinator")
    
    -- Ana Döngü (Heartbeat / Event Hub)
    self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
        self.EventBus:Publish("Engine/RenderStepped", dt)
    end)
    
    print("[NEXUS v100] All Systems Fully Deployed & Running.")
end

function ApexNexus:Shutdown()
    if self.RenderConnection then self.RenderConnection:Disconnect() end
    self.PluginManager:DisableAll()
    print("[NEXUS] Framework cleanly unloaded. Memory cleared.")
end

return ApexNexus