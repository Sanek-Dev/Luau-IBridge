-- Loader
if not getgenv or typeof(getgenv) ~= "function" then
    warn("[IBridge/Loader] Your executor doesn\'t support getgenv function")
    return nil
end

function IsStringNullOrEmpty(str)
    return not str or typeof(str) ~= "string" or str:len() < 1
end

function CheckApiFunc(funcName, libName)
    if not libName then
        return not IsStringNullOrEmpty(funcName) and getgenv()[funcName] and typeof(getgenv()[funcName]) == "function"
    end

    return not IsStringNullOrEmpty(libName) and getgenv()[libName] and typeof(getgenv()[libName]) == "table" and getgenv()[libName][funcName] and typeof(getgenv()[libName][funcName]) == "function"
end

local _RequiredAPI = {"cloneref", "isfile", "readfile", "writefile", "loadstring", "isfolder", "makefolder", "delfile", "delfolder"}
for i,v in ipairs(_RequiredAPI) do
    if not CheckApiFunc(v) then
        warn("[IBridge/Loader/apierror] Your executor doesn\'t support "..v)
        return nil
    end
end

function IsCryptSupported()
    return crypt and typeof(crypt) == "table" and crypt.encrypt and typeof(crypt.encrypt) == "function" and crypt.decrypt and typeof(crypt.decrypt) == "function"
end

-- Services & globals
local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))

-- Modules
-- IBridge
local IBridge = {}
IBridge.__index = IBridge

function IBridge.new(factory, fileName, dispatchTick)
    if not factory or typeof(factory) ~= "table" or not fileName or typeof(fileName) ~= "string" or string.len(fileName) < 1 then
        warn("[IBridge.new] Invalid arguments!")
        return nil
    end

    if dispatchTick and (typeof(dispatchTick) ~= "number" or (dispatchTick <= 0 and dispatchTick ~= -1)) then
        warn("[IBridge.new] Invalid dispatchTick argument!")
        return nil
    end

    local filePath = factory:FileNameToBridge(fileName)
    if not filePath then
        warn("[IBridge.new] Invalid filePath!")
        return nil
    end

    local bridge = {
        ["Factory"] = factory,
        ["FileName"] = fileName,
        ["FilePath"] = filePath,
        ["LastDispatchedId"] = 0,
        ["DispatchThread"] = nil,
        ["DispatchTick"] = dispatchTick or 0.5,
        ["DispatchActive"] = false
    }
    setmetatable(bridge, IBridge)

    return bridge
end

function IBridge.GetPlayerUsername(Self)
    return string.sub(Self.FileName, #Self.Factory:GetPrefix(), Self.FileName:len())
end

function IBridge.ReadData(Self)
    if not isfile(Self.FilePath) then return nil end

    local content = readfile(Self.FilePath)
    if IsStringNullOrEmpty(content) then return nil end

    if Self.Factory.UseEncryption then
        content = crypt.decrypt(content, Self.Factory.EncryptionKey)
    end

    return HttpService:JSONDecode(content)
end

function IBridge.GetLastPacketTime(Self)
    local data = Self:ReadData()
    if not data then return nil end

    return data.sendTime
end

function IBridge.WriteDataTable(Self, dataTable)
    if not dataTable or typeof(dataTable) ~= "table" then
        warn("[IBridge.WriteDataTable] Invalid dataTable argument!")
        return false
    end

    local str = HttpService:JSONEncode(dataTable)
    if IsStringNullOrEmpty(str) then return false end

    writefile(Self.FilePath, Self.Factory.UseEncryption and crypt.encrypt(str, Self.Factory.EncryptionKey) or str)
    return true
end

function IBridge.WritePacket(Self, _type, body)
    if not _type or typeof(_type) ~= "number" then
        warn("[IBridge.WritePacket] Invalid type argument!")
        return false
    end

    if not body or typeof(body) ~= "string" then
        warn("[IBridge.WritePacket] Invalid body argument!")
        return false
    end

    local id = 1
    local data = Self:ReadData()
    if data and (tick() - data.sendTime) < 60 then -- id refreshes every minute
        id = data.id + 1
    end

    local dataTable = {
        ["id"] = id,
        ["type"] = _type,
        ["sendTime"] = tick(),
        ["body"] = body
    }
    
    return Self:WriteDataTable(dataTable)
end

function IBridge.SendHeartbeat(Self) -- Not used yet
    return Self:WritePacket(0, "")
end

function IBridge.SendCode(Self, code)
    if IsStringNullOrEmpty(code) then
        warn("[IBridge.SendCode] Invalid code argument!")
        return false
    end

    return Self:WritePacket(1, code)
end

function IBridge.DispatchCode(Self)
    local packet = Self:ReadData()
    if not packet or packet.type ~= 1 or (packet.id and Self.LastDispatchedId == packet.id) or IsStringNullOrEmpty(packet.body) then return false end

    local fn, errMsg = loadstring(packet.body)
    if not fn then
        if errMsg then warn("[IBridge.DispatchCode] Failed to dispatch code: "..errMsg) end
        return false
    end

    local ret, status = pcall(fn)
    if not ret and status then
        warn("[IBridge.DispatchCode] Error happened while executing code: "..status)
    end

    Self.LastDispatchedId = packet.id
    return ret
end

-- Warning: function yields until dispatch thread successfully dispatches initial code
function IBridge.StartDispatchThread(Self)
    if Self.DispatchTick == -1 then
        warn("[IBridge.StartDispatchThread] Cannot start dispatch thread on other player\'s bridge")
        return false
    end

    if Self.DispatchActive then
        warn("[IBridge.StartDispatchThread] Dispatch is already active!")
        return false
    end

    if Self.DispatchThread then
        warn("[IBridge.StartDispatchThread] Cannot start second dispatch thread!")
        return false
    end

    Self.DispatchActive = true
    Self:SendCode("getgenv().IBRIDGES_LOAD_STATUSES[\""..Self.FilePath.."\"] = true")

    Self.DispatchThread = task.spawn(function()
        while Self.DispatchActive do
            Self:DispatchCode()
            task.wait(Self.DispatchTick)
        end
    end)

    while not getgenv().IBRIDGES_LOAD_STATUSES[Self.FilePath] do task.wait() end

    return true
end

-- Warning: function yields until dispatch thread finishes its execution
function IBridge.StopDispatchThread(Self)
    if not Self.DispatchActive or not Self.DispatchThread then
        warn("[IBridge.StopDispatchThread] Dispatch thread is not active!")
        return
    end

    Self.DispatchActive = false
    while coroutine.status(Self.DispatchThread) == "normal" do task.wait() end
    task.cancel(Self.DispatchThread)
    Self.DispatchThread = nil
    getgenv().IBRIDGES_LOAD_STATUSES[Self.FilePath] = false
end

function IBridge.CleanUp(Self)
    if Self.DispatchTick == -1 then
        warn("[IBridge.CleanUp] Cannot cleanup other player\'s bridge!")
        return
    end

    if Self.DispatchActive and Self.DispatchThread then Self:StopDispatchThread() end
    if isfile(Self.FilePath) then delfile(Self.FilePath) end
end

-- IBridgeFactory
local IBridgeFactory = {}
IBridgeFactory.__index = IBridgeFactory

function IBridgeFactory.new(useEncryption: boolean?, encryptionKey: string?, bridgesDirectoryName: string?, filenamePrefix: string?)
    if not Players.LocalPlayer then
        warn("[IBridgeFactory.new] Bridge factory cannot be created when there\'s no LocalPlayer!")
        return nil
    end

    if useEncryption and not IsCryptSupported() then
        warn("[IBridgeFactory.new] Cannot use encryption because your executor doesn\'t support crypt library!")
        return nil
    end

    if useEncryption and IsStringNullOrEmpty(encryptionKey) then
        warn("[IBridgeFactory.new] Invalid encryptionKey argument!")
        return nil
    end

    local dirName = bridgesDirectoryName or "IBridge_Bridges"
    if not isfolder(dirName) then makefolder(dirName) end

    if not getgenv().IBRIDGES_LOAD_STATUSES then
        getgenv().IBRIDGES_LOAD_STATUSES = {}
    end

    local factory = {
        ["FilePrefix"] = filenamePrefix or "ibridge_",
        ["DirectoryName"] = dirName,
        ["UseEncryption"] = useEncryption,
        ["EncryptionKey"] = encryptionKey,
        ["AllBridges"] = {}
    }
    setmetatable(factory, IBridgeFactory)

    return factory
end

function IBridgeFactory.GetPrefix(Self)
    return Self.FilePrefix
end

function IBridgeFactory.GetDirectoryName(Self)
    return Self.DirectoryName
end

function IBridgeFactory.FileNameToBridge(Self, filename)
    if IsStringNullOrEmpty(filename) then return nil end

    return Self:GetDirectoryName().."/"..filename
end

-- One player instance can have only one IBridge at the time!
function IBridgeFactory.CreateBridge(Self, dispatchTick)
    if dispatchTick <= 0 then
        warn("[IBridgeFactory.CreateBridge] Cannot create a bridge with negative dispatchTick!")
        return nil
    end

    local bridge = IBridge.new(Self, Self:GetPrefix()..Players.LocalPlayer.Name..".txt", dispatchTick)
    if bridge then table.insert(Self.AllBridges, bridge) end

    return bridge
end

function IBridgeFactory.GetBridgeForPlayer(Self, playerUsername)
    local bridge = IBridge.new(Self, Self:GetPrefix()..playerUsername..".txt", -1)
    if bridge then table.insert(Self.AllBridges, bridge) end

    return bridge
end

function IBridgeFactory.CleanUp(Self)
    for i,v in ipairs(Self.AllBridges) do
        v:CleanUp()
    end
    if isfolder(Self.DirectoryName) then delfolder(Self.DirectoryName) end
end

return IBridgeFactory
