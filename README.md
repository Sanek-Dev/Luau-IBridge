# ⚠️ Disclaimer
**This script can be very buggy as its based on files and _can't be reliable_.**
# Luau-IBridge
With help of this module you can make communication between different executor instances based on players' names (File API in executor required)
## 🖊️ Loadstring
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
```
## Usage Example
Note: Dont forget to sometimes clear unused files inside workspace/${BridgesFolderName} folder (these can be deleted freely, especially do that if you use alot of instances)<br/>
*Server Code (every instance can be server and open client bridges to other instances at the same time):*
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
local MainBridgeFactory = IBridgeFactory.new({
    ["UseEncryption"] = true,
    ["EncryptionKey"] = "Secret_Key123" -- If unsure what to use, generate one using print(tostring(crypt.generatekey())) if your executor supports it then paste it here
}) -- server and client must have the same factory params
local ServerBridge = MainBridgeFactory:CreateBridge()
if ServerBridge then
    print("Started IBridge server")
else
    error("Failed to start IBridge server")
end

-- This function does not block(yield) current thread
if ServerBridge:StartDispatchThread() then
    print("Listening to packets from other instances...")
end
```
*Client Code:*
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
local MainBridgeFactory = IBridgeFactory.new({
    ["UseEncryption"] = true,
    ["EncryptionKey"] = "Secret_Key123" -- If unsure what to use, generate one using print(tostring(crypt.generatekey())) if your executor supports it then paste it here
}) -- server and client must have the same factory params
local ClientBridge = MainBridgeFactory:GetBridgeForPlayer("PlayerUsername")
if ClientBridge then
    print("Opened client IBridge bridge")
else
    error("Failed to open client bridge!")
end

if ClientBridge:SendCode("print('Hello from "..game.Players.LocalPlayer.DisplayName.." instance!')") then
    print("Sent print packet")
end
```
