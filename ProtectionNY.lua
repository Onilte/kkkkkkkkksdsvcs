local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProtectionModule = {}
ProtectionModule.__index = ProtectionModule

local _encryptionKey = nil
local _isInitialized = false
local _settings = {}

local EncryptionSystem = {}

function EncryptionSystem.xorEncrypt(String, Key)
    local KeyCodesMap, StringCodesMap = {}, {}
    for _, Codepoint in utf8.codes(Key) do
        table.insert(KeyCodesMap, Codepoint)
    end
    for _, Codepoint in utf8.codes(String) do
        table.insert(StringCodesMap, Codepoint)
    end
    local Result = ""
    for Index, Codepoint in ipairs(StringCodesMap) do
        local KeyIndex = ((Index - 1) % #KeyCodesMap) + 1
        local XORResult = bit32.bxor(KeyCodesMap[KeyIndex], Codepoint)
        Result = Result .. utf8.char(XORResult)
    end
    return Result
end

function EncryptionSystem.base64Encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r, byte = '', x:byte()
        for i = 8, 1, -1 do 
            r = r .. (byte % 2^i - byte % 2^(i-1) > 0 and '1' or '0') 
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do 
            c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) 
        end
        return b:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function EncryptionSystem.encryptArgument(arg, key)
    local argString
    
    if type(arg) == "string" then
        argString = "STR:" .. arg
    elseif type(arg) == "number" then
        argString = "NUM:" .. tostring(arg)
    elseif type(arg) == "boolean" then
        argString = "BOOL:" .. tostring(arg)
    elseif typeof(arg) == "Instance" then
        argString = "INST:" .. arg:GetFullName()
    elseif arg == nil then
        argString = "NIL:nil"
    else
        argString = "UNK:" .. tostring(arg)
    end
    
    local encrypted = EncryptionSystem.xorEncrypt(argString, key)
    return EncryptionSystem.base64Encode(encrypted)
end

function ProtectionModule:init(encryptionKey, settings)
    if _isInitialized then
        return false
    end
    
    if not encryptionKey or type(encryptionKey) ~= "string" then
        error("ProtectionModule: Encryption key required")
    end
    
    _encryptionKey = encryptionKey
    _settings = settings or {}
    _isInitialized = true
    
    _settings.addTimestamp = _settings.addTimestamp ~= false
    _settings.debugMode = _settings.debugMode or false
    _settings.maxRetries = _settings.maxRetries or 3
    
    return true
end

function ProtectionModule:_checkInit()
    if not _isInitialized then
        error("ProtectionModule: Module not initialized")
    end
end

function ProtectionModule.encrypt(originalRemote)
    ProtectionModule:_checkInit()
    
    if not originalRemote then
        error("ProtectionModule: nil RemoteEvent passed")
    end
    
    if not originalRemote:IsA("RemoteEvent") and not originalRemote:IsA("RemoteFunction") then
        error("ProtectionModule: object must be RemoteEvent or RemoteFunction")
    end
    
    local protectedRemote = {}
    local remoteType = originalRemote:IsA("RemoteEvent") and "Event" or "Function"
    
    if remoteType == "Event" then
        function protectedRemote:FireServer(...)
            local args = {...}
            local encryptedArgs = {}
            
            for i, arg in ipairs(args) do
                encryptedArgs[i] = EncryptionSystem.encryptArgument(arg, _encryptionKey)
            end
            
            if _settings.addTimestamp then
                table.insert(encryptedArgs, EncryptionSystem.encryptArgument(tostring(tick()), _encryptionKey))
            end
            
            return originalRemote:FireServer(unpack(encryptedArgs))
        end
    end
    
    if remoteType == "Function" then
        function protectedRemote:InvokeServer(...)
            local args = {...}
            local encryptedArgs = {}
            
            for i, arg in ipairs(args) do
                encryptedArgs[i] = EncryptionSystem.encryptArgument(arg, _encryptionKey)
            end
            
            if _settings.addTimestamp then
                table.insert(encryptedArgs, EncryptionSystem.encryptArgument(tostring(tick()), _encryptionKey))
            end
            
            return originalRemote:InvokeServer(unpack(encryptedArgs))
        end
    end
    
    setmetatable(protectedRemote, {
        __index = function(t, k)
            if rawget(t, k) then
                return rawget(t, k)
            end
            return originalRemote[k]
        end,
        __newindex = function(t, k, v)
            originalRemote[k] = v
        end,
        __tostring = function()
            return
        end
    })
    
    return protectedRemote
end

function ProtectionModule:isInitialized()
    return _isInitialized
end

function ProtectionModule:getSettings()
    self:_checkInit()
    return _settings
end

function ProtectionModule:updateSettings(newSettings)
    self:_checkInit()
    if type(newSettings) ~= "table" then
        error("ProtectionModule: Settings must be a table")
    end
    
    for key, value in pairs(newSettings) do
        _settings[key] = value
    end
end

function ProtectionModule.generateKey(length)
    length = length or 32
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
    local key = ""
    
    for i = 1, length do
        local randomIndex = math.random(1, #chars)
        key = key .. string.sub(chars, randomIndex, randomIndex)
    end
    
    return key
end

function ProtectionModule:reset()
    _encryptionKey = nil
    _isInitialized = false
    _settings = {}
end

return ProtectionModule
