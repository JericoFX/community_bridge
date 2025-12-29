if GetResourceState('redutzu-mdt') == 'missing' then return end
Dispatch = Dispatch or {}
local dispatchCooldowns = {}
local DISPATCH_COOLDOWN_MS = 5000

RegisterNetEvent("community_bridge:server:dispatch:sendAlert", function(data)
    local src = source
    if not src or not data or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if dispatchCooldowns[src] and now - dispatchCooldowns[src] < DISPATCH_COOLDOWN_MS then return end
    dispatchCooldowns[src] = now
    if data.message and tostring(data.message):len() > 500 then return end
    -- TODO: Validate sender authorization once job/group info is available in the payload.
    TriggerEvent('redutzu-mdt:server:addDispatchToMDT', {
        code = data.code,
        title = data.message,
        street = data.street,
        duration = data.time,
        coords = data.coords
    })
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'redutzu-mdt'
end

return Dispatch
