Housing = Housing or {}

---This is an internal event, listen for 'community_bridge:Client:OnPlayerInside' instead.
---This event is triggered when a player enters or leaves a property.
---@param insideId string
RegisterNetEvent('community_bridge:Server:_OnPlayerInside', function(insideId)
    local src = source
    if not src or src == 0 then return end
    local currentBucket = GetPlayerRoutingBucket(src)
    local playerEntity = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerEntity)
    TriggerEvent('community_bridge:Client:OnPlayerInside', src, insideId, currentBucket, playerCoords)
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "default"
end

return Housing
