if GetResourceState('emergencydispatch') == 'missing' then return end
Dispatch = Dispatch or {}
local dispatchCooldowns = {}
local DISPATCH_COOLDOWN_MS = 5000

RegisterNetEvent("community_bridge:server:dispatch:sendAlert", function(data)
    local src = source
    if not src or not data or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if dispatchCooldowns[src] and now - dispatchCooldowns[src] < DISPATCH_COOLDOWN_MS then return end
    dispatchCooldowns[src] = now
    local job = data.job or (type(data.jobs) == "table" and data.jobs[1]) or 'police'
    if type(job) ~= "string" then return end
    local jobData = Bridge.Framework.GetPlayerJobData(src)
    if jobData and jobData.jobName and jobData.jobName ~= job then return end
    local message = tostring(data.message or "An Alert Has Been Made")
    if message:len() > 500 then return end
    local coords = data.coords or vector3(0, 0, 0)

    TriggerEvent('emergencydispatch:emergencycall:new', job, message, coords, true)
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'emergencydispatch'
end

return Dispatch
