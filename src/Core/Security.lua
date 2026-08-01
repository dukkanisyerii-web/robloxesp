local Security = {}
Security.__index = Security

function Security.new()
    return setmetatable({
        LastCheck = 0,
        BlockedFlags = {}
    }, Security)
end

function Security:VerifyEnvironment()
    local pass = true
    local now = os.clock()
    if now - self.LastCheck < 0.2 then
        return not self.BlockedFlags.environment
    end

    self.LastCheck = now

    local ok, env = pcall(function() return getgenv() end)
    if not ok or not env then
        pass = false
        self.BlockedFlags.environment = true
        return false
    end

    local safeCalls = {
        "getrawmetatable",
        "setrawmetatable",
        "hookmetamethod",
        "getnamecallmethod"
    }

    for _, name in ipairs(safeCalls) do
        if type(env[name]) ~= "function" then
            self.BlockedFlags[name] = true
        end
    end

    return pass
end

function Security:SanitizeVector(vec)
    if not vec or typeof(vec) ~= "Vector3" then return Vector3.zero end
    if math.abs(vec.X) > 100000 or math.abs(vec.Y) > 100000 or math.abs(vec.Z) > 100000 then
        return Vector3.zero
    end
    return vec
end

function Security:IsBlocked(flag)
    return self.BlockedFlags[flag] == true
end

return Security