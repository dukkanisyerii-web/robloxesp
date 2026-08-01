local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local AmmoPlugin = {}
AmmoPlugin.__index = AmmoPlugin

function AmmoPlugin.new()
    return setmetatable({
        Name = "Ammo",
        Subscriptions = {},
        Active = false,
        LastScan = 0,
        AmmoNamePatterns = {
            "ammo",
            "clip",
            "mag",
            "round",
            "bullet",
            "reserve",
            "capacity",
            "magazine",
            "bullets"
        }
    }, AmmoPlugin)
end

function AmmoPlugin:Init(DI)
    self.EventBus = DI:Resolve("EventBus")
    self.Config = DI:Resolve("Config")
end

function AmmoPlugin:Start()
    if self.Active then return end
    self.Active = true

    local sub = RunService.RenderStepped:Connect(function(dt)
        self:ProcessAmmo(dt)
    end)
    table.insert(self.Subscriptions, sub)
end

function AmmoPlugin:Stop()
    for _, unsub in ipairs(self.Subscriptions) do
        if typeof(unsub) == "RBXScriptConnection" then
            unsub:Disconnect()
        end
    end
    self.Subscriptions = {}
    self.Active = false
end

function AmmoPlugin:IsAmmoObject(obj)
    if not obj then return false end

    local className = obj.ClassName
    if className ~= "IntValue" and className ~= "NumberValue" and className ~= "StringValue" then
        return false
    end

    local name = string.lower(obj.Name or "")
    for _, pattern in ipairs(self.AmmoNamePatterns) do
        if string.find(name, pattern, 1, true) then
            return true
        end
    end

    return false
end

function AmmoPlugin:PatchAmmoObject(obj)
    if not obj then return end

    local maxAmmo = tonumber((self.Config.Ammo and self.Config.Ammo.MaxAmmo) or 999) or 999
    local className = obj.ClassName

    if className == "IntValue" then
        obj.Value = math.max(1, math.floor(maxAmmo))
    elseif className == "NumberValue" then
        obj.Value = maxAmmo
    elseif className == "StringValue" then
        obj.Value = tostring(maxAmmo)
    end
end

function AmmoPlugin:FindAmmoObjects(container)
    local found = {}
    if not container then return found end

    for _, obj in ipairs(container:GetDescendants()) do
        if self:IsAmmoObject(obj) then
            table.insert(found, obj)
        end
    end

    return found
end

function AmmoPlugin:ProcessAmmo(dt)
    if not self.Config.Ammo or not self.Config.Ammo.Enabled then return end
    if tick() - self.LastScan < (self.Config.Ammo.ScanInterval or 0.1) then return end
    self.LastScan = tick()

    local containers = {}
    local character = LocalPlayer.Character
    if character then
        table.insert(containers, character)
    end

    local backpack = LocalPlayer.Backpack
    if backpack then
        table.insert(containers, backpack)
    end

    for _, container in ipairs(containers) do
        for _, obj in ipairs(self:FindAmmoObjects(container)) do
            self:PatchAmmoObject(obj)
        end

        if self.Config.Ammo.ApplyToBackpack then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    for _, obj in ipairs(self:FindAmmoObjects(child)) do
                        self:PatchAmmoObject(obj)
                    end
                end
            end
        end
    end
end

return AmmoPlugin
