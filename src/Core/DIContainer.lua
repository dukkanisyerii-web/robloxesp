local DIContainer = {}
DIContainer.__index = DIContainer

function DIContainer.new()
    return setmetatable({ _services = {} }, DIContainer)
end

function DIContainer:Register(name, service)
    self._services[name] = service
end

function DIContainer:Resolve(name)
    local service = self._services[name]
    assert(service, "[DIContainer] Servis bulunamadı: " .. tostring(name))
    return service
end

return DIContainer