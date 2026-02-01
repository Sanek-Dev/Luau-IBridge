# ⚠️ Disclaimer
**This script can be very buggy as its based on files and _can't be reliable_.**
# Luau-IBridge
With help of this module you can make communication between different executor instances based on players' names (File API in executor required)
## 🖊️ Loadstring
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
```
## Usage Example
```luau
local IBridgeFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sanek-Dev/Luau-IBridge/refs/heads/main/Source.luau"))()
local MainBridgeFactory = IBridgeFactory.new()
local TestBridge = MainBridgeFactory:CreateBridge()
if TestBridge:StartDispatchThread() then
    print("Started bridge client")
end

local sendComm = false -- set to true to send packet to an other instance
if sendComm then
    local CommBridge = MainBridgeFactory:GetBridgeForPlayer("PlayerUsername")
    CommBridge:SendCode("print(\"Hello, Bridge World!!!\")")
    print("Sent hello world to the other instance")
end
```
