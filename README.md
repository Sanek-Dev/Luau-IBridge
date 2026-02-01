# ⚠️ Disclaimer
**This script can be very buggy as its based on files and _can't be reliable_.**
# Luau-IBridge
With help of this module you can make communication between different executor instances based on players' names (File API in executor required)
## 🖊️ Loadstring
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
```
## Usage Example
Note: Dont forget to sometimes clear unused files inside workspace/${BridgesFolderName} folder (these can be deleted freely, especially do that if you use alot of instances)
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
local MainBridgeFactory = IBridgeFactory.new({
    ["UseEncryption"] = true,
    ["EncryptionKey"] = "Secret_Key123" -- change that, if unsure, gen one key using crypt.generatekey() and paste it here, but DONT USE DIFFERENT KEYS in the same session
})
local ServerBridge = MainBridgeFactory:CreateBridge()
if ServerBridge:StartDispatchThread() then
    print("Started bridge server")
end

local sendComm = false -- set to true to send packet to an other instance
if sendComm then
    local CommBridge = MainBridgeFactory:GetBridgeForPlayer("PlayerUsername")
    CommBridge:SendCode("print(\"Hello, Bridge World!\")")
    print("Sent hello world to the other instance")
end
```
