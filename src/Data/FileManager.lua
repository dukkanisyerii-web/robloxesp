local HttpService = game:GetService("HttpService")
local FileManager = {}
FileManager.FileName = "ApexNexus_Enterprise_Config.json"

function FileManager:Save(configTable)
    if writefile then
        local success, encoded = pcall(function()
            return HttpService:JSONEncode(configTable)
        end)
        if success then
            pcall(function() writefile(self.FileName, encoded) end)
        end
    end
end

function FileManager:Load(configTable)
    if readfile and isfile and isfile(self.FileName) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(self.FileName))
        end)
        if success and type(decoded) == "table" then
            for cat, values in pairs(decoded) do
                if configTable[cat] and type(values) == "table" then
                    for k, v in pairs(values) do
                        configTable[cat][k] = v
                    end
                end
            end
        end
    end
end

return FileManager