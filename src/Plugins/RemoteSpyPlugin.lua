local RemoteSpyPlugin = {}
RemoteSpyPlugin.__index = RemoteSpyPlugin

function RemoteSpyPlugin.new()
    return setmetatable({
        Name = "RemoteSpy",
        IsLogging = true,
        Active = false,
        Subscriptions = {}
    }, RemoteSpyPlugin)
end

function RemoteSpyPlugin:Init(DI)
    -- EventBus bağımlılığı DI üzerinden güvenle alınıyor ve saklanıyor
    self.EventBus = DI:Resolve("EventBus")
end

function RemoteSpyPlugin:Start()
    if self.Active then return end
    self.Active = true

    -- Hook işlemini güvenli bir şekilde sarmalıyoruz
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(selfObj, ...)
            -- Eğer plugin durdurulduysa veya loglama kapalıysa orijinal akışı bozmadan devam et
            if not self.Active or not self.IsLogging then
                return oldNamecall(selfObj, ...)
            end

            local method = getnamecallmethod()
            
            -- Mantiksal hata (and/or önceliği) parantezlerle düzeltildi
            local isRemoteCall = (method == "FireServer" or method == "InvokeServer") 
                and (selfObj:IsA("RemoteEvent") or selfObj:IsA("RemoteFunction"))

            if isRemoteCall then
                if selfObj.Name ~= "AnalyticsEvent" then
                    -- Performans optimizasyonu: Sürekli print yapmak yerine EventBus üzerinden yayınla
                    if self.EventBus then
                        self.EventBus:Publish("RemoteSpy/DataIntercepted", {
                            Name = selfObj.Name,
                            Method = method,
                            Arguments = {...}
                        })
                    else
                        print(string.format("[RemoteSpy] Yakalandı -> Remote: %s | Metot: %s", selfObj.Name, method))
                    end
                end
            end

            return oldNamecall(selfObj, ...)
        end)
    end)
end

function RemoteSpyPlugin:Stop()
    -- Stop metodu artık güvenli bir şekilde bayrağı kapatarak mantıksal döngüyü sonlandırıyor
    self.Active = false
    
    for _, unsub in ipairs(self.Subscriptions) do
        if type(unsub) == "function" then
            unsub()
        end
    end
    self.Subscriptions = {}
end

return RemoteSpyPlugin