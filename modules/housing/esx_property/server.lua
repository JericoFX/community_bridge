if GetResourceState('esx_property') == 'missing' then return end

Housing = Housing or {}

RegisterNetEvent('esx_property:enter', function(insideId)
    TriggerEvent('community_bridge:Server:_OnPlayerInside', insideId)
end)

RegisterNetEvent('esx_property:leave', function(insideId)
    TriggerEvent('community_bridge:Server:_OnPlayerInside', insideId)
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "esx_property"
end

return Housing
