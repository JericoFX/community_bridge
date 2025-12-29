Dispatch = Dispatch or {}
local dispatchCooldowns = {}
local DISPATCH_COOLDOWN_MS = 5000

RegisterNetEvent("community_bridge:Server:DispatchAlert", function(data)
    local src = source
    if not src or not data or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if dispatchCooldowns[src] and now - dispatchCooldowns[src] < DISPATCH_COOLDOWN_MS then return end
    dispatchCooldowns[src] = now
    local jobs = data.jobs
    if type(jobs) ~= "table" then return end
    if data.message and tostring(data.message):len() > 500 then return end
    local jobData = Bridge.Framework.GetPlayerJobData(src)
    local jobName = jobData and jobData.jobName
    local senderAuthorized = false
    for _, name in pairs(jobs) do
        if type(name) ~= "string" then goto continue_auth end
        if jobName and name == jobName then senderAuthorized = true break end
        ::continue_auth::
    end
    if not senderAuthorized then return end
    for _, name in pairs(jobs) do
        if type(name) ~= "string" then goto continue_send end
        local activeJobPlayers = Bridge.Framework.GetPlayersByJob(name)
        for _, src in pairs(activeJobPlayers) do
            TriggerClientEvent('community_bridge:Client:DispatchAlert', src, data)
        end
        ::continue_send::
    end
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'default'
end

return Dispatch
