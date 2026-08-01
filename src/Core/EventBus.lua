local HttpService = game:GetService("HttpService")
local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    return setmetatable({ _listeners = {} }, EventBus)
end

function EventBus:Subscribe(topic, callback)
    if not self._listeners[topic] then
        self._listeners[topic] = {}
    end
    local id = HttpService:GenerateGUID(false)
    self._listeners[topic][id] = callback
    
    return function()
        if self._listeners[topic] then
            self._listeners[topic][id] = nil
        end
    end
end

function EventBus:Publish(topic, ...)
    if not self._listeners[topic] then return end
    for _, callback in pairs(self._listeners[topic]) do
        task.spawn(function(...)
            local success, err = pcall(callback, ...)
            if not success then
                warn(string.format("[EventBus Error] Topic: %s -> %s", tostring(topic), tostring(err)))
            end
        end, ...)
    end
end

return EventBus