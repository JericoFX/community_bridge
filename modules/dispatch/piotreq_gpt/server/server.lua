if GetResourceState('piotreq_gpt') == 'missing' then return end
Dispatch = Dispatch or {}
local dispatchCooldowns = {}
local DISPATCH_COOLDOWN_MS = 5000

Dispatch.SendAlert = function(src, alertData)
    -- No clue if this works, but itd be nice to have someone test it.
    --https://piotreq-scripts.gitbook.io/piotreq-scripts/assets-and-guides/police-mdt/dispatch-system
    exports['piotreq_gpt']:SendAlert(src, {
    title = alertData.message or "No message provided",
    code = alertData.code or '10-80',
    icon = alertData.icon or 'fa-solid fa-question',
    info = {
        {icon = 'fa-solid fa-road', isStreet = true},
        {icon = alertData.icon or 'fa-solid fa-question', data = alertData.message or "No additional info"},
    },
    blip = { -- optional
        scale = alertData.blipData and alertData.blipData.scale or 1.0,
        sprite = alertData.blipData and alertData.blipData.sprite or 161,
        category = 1, -- default 1
        color = alertData.blipData and alertData.blipData.color or 84,
        hidden = false, -- default false (hidden on legend)
        priority = alertData.priority or 5, -- default 5
        short = true, -- as short range? default true
        alpha = 200, -- default 255
        name = alertData.message or "Dispatch Alert"
    },
    type = 'normal', -- default normal
    canAnswer = false, -- default false
    maxOfficers = 6, -- default 4
    time = 10,-- 10 minutes, default 5
    notifyTime = 8000, -- 8 seconds, default 7
    })
end

RegisterNetEvent('community_bridge:Server:piotreq_gpt', function(data)
    local src = source
    if not src or not data or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if dispatchCooldowns[src] and now - dispatchCooldowns[src] < DISPATCH_COOLDOWN_MS then return end
    dispatchCooldowns[src] = now
    if data.message and tostring(data.message):len() > 500 then return end
    -- TODO: Validate sender authorization once job/group info is available in the payload.
    Dispatch.SendAlert(src, data)
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'piotreq_gpt'
end

return Dispatch
