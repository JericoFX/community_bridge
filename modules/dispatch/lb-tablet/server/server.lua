if GetResourceState('lb-tablet') == 'missing' then return end
Dispatch = Dispatch or {}
local dispatchCooldowns = {}
local DISPATCH_COOLDOWN_MS = 5000

RegisterNetEvent("community_bridge:server:dispatch:sendAlert", function(data)
    local src = source
    if not src or not data or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if dispatchCooldowns[src] and now - dispatchCooldowns[src] < DISPATCH_COOLDOWN_MS then return end
    dispatchCooldowns[src] = now
    if type(data.job) ~= "string" then return end
    local jobData = Bridge.Framework.GetPlayerJobData(src)
    if not jobData or jobData.jobName ~= data.job then return end
    exports["lb-tablet"]:AddDispatch(data) -- this has a return value but we dont really have a use for it atm.
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'lb-tablet'
end

return Dispatch
