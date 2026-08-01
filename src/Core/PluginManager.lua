local PluginManager = {}
PluginManager.__index = PluginManager

function PluginManager.new(diContainer)
    return setmetatable({
        DI = diContainer,
        Plugins = {}
    }, PluginManager)
end

function PluginManager:Register(pluginModule)
    local plugin = pluginModule.new()
    assert(plugin.Name, "[PluginManager] Plugin adı tanımlı olmalıdır!")
    
    self.Plugins[plugin.Name] = {
        Instance = plugin,
        Running = false,
        ErrorCount = 0,
        MaxErrorsBeforeDisable = 5
    }
    
    if plugin.Init then
        local success, err = pcall(function() plugin:Init(self.DI) end)
        if not success then
            warn(string.format("[Plugin Init Error][%s]: %s", plugin.Name, tostring(err)))
        end
    end
end

function PluginManager:Enable(name)
    local pData = self.Plugins[name]
    if pData and not pData.Running then
        pData.Running = true
        if pData.Instance.Start then
            task.spawn(function()
                local success, err = pcall(function() pData.Instance:Start() end)
                if not success then
                    self:HandlePluginError(name, err)
                end
            end)
        end
    end
end

function PluginManager:HandlePluginError(name, err)
    local pData = self.Plugins[name]
    if not pData then return end
    
    pData.ErrorCount = pData.ErrorCount + 1
    warn(string.format("[Error Boundary] %s eklentisinde hata yakalandı (%d/%d): %s", 
        name, pData.ErrorCount, pData.MaxErrorsBeforeDisable, tostring(err)))
    
    if pData.ErrorCount >= pData.MaxErrorsBeforeDisable then
        warn(string.format("[Error Boundary] %s eklentisi çok fazla hata ürettiği için güvenli şekilde devre dışı bırakılıyor.", name))
        self:Disable(name)
    end
end

function PluginManager:Disable(name)
    local pData = self.Plugins[name]
    if pData and pData.Running then
        pData.Running = false
        pcall(function()
            if pData.Instance.Stop then
                pData.Instance:Stop()
            end
        end)
    end
end

function PluginManager:DisableAll()
    for name, _ in pairs(self.Plugins) do
        self:Disable(name)
    end
end

return PluginManager