local Callback = {}
local CallbackRegistry = {}

-- Constants
local RESOURCE = GetCurrentResourceName() or 'unknown'
local EVENT_NAMES = {
    CLIENT_TO_SERVER = RESOURCE .. ':CS:Callback',
    SERVER_TO_CLIENT = RESOURCE .. ':SC:Callback',
    CLIENT_RESPONSE = RESOURCE .. ':CSR:Callback',
    SERVER_RESPONSE = RESOURCE .. ':SCR:Callback'
}

-- Utility functions
local function generateCallbackId(name)
    return string.format('%s_%d', name, math.random(1000000, 9999999))
end

local function handleResponse(registry, name, callbackId, ...)
    local data = registry[callbackId]
    if not data then return end

    if data.callback then
        data.callback(...)
    end

    if data.promise then
        data.promise:resolve({ ... })
    end

    registry[callbackId] = nil
end

local function triggerCallback(eventName, target, name, args, callback)
    local callbackId = generateCallbackId(name)
    local promise = promise.new()
    local targets = nil

    CallbackRegistry[callbackId] = {
        callback = callback,
        promise = promise
    }

    if type(target) == 'table' then
        targets = {}
        for _, id in ipairs(target) do
            targets[tonumber(id)] = true
            TriggerClientEvent(eventName, tonumber(id), name, callbackId, table.unpack(args))
        end
    else
        if target ~= -1 then
            targets = {
                [tonumber(target)] = true
            }
        end
        TriggerClientEvent(eventName, tonumber(target), name, callbackId, table.unpack(args))
    end
    CallbackRegistry[callbackId].targets = targets

    if not callback then
        local result = Citizen.Await(promise)
        local returnResults = (result and type(result) == 'table' ) and result or {result}
        return table.unpack(returnResults)
    end
end

-- Server-side implementation
if IsDuplicityVersion() then
    function Callback.Register(name, handler)
        Callback[name] = handler
    end

    function Callback.Trigger(name, target, ...)
        local args = { ... }
        local callback = type(args[1]) == 'function' and table.remove(args, 1) or nil
        return triggerCallback(EVENT_NAMES.SERVER_TO_CLIENT, target or -1, name, args, callback)
    end

    RegisterNetEvent(EVENT_NAMES.CLIENT_TO_SERVER, function(name, callbackId, ...)
        if not name or not callbackId then return print(string.format("[%s] Warning: Invalid callback parameters - name: %s, callbackId: %s", RESOURCE, tostring(name), tostring(callbackId))) end

        local handler = Callback[name]
        if not handler then return end

        local playerId = source
        if not playerId or playerId == 0 then return print(string.format("[%s] Warning: Invalid source for callback '%s'", RESOURCE, name)) end

        local result = table.pack(handler(playerId, ...))
        TriggerClientEvent(EVENT_NAMES.CLIENT_RESPONSE, playerId, name, callbackId, table.unpack(result))
    end)

    RegisterNetEvent(EVENT_NAMES.SERVER_RESPONSE, function(name, callbackId, ...)
        local data = CallbackRegistry[callbackId]
        if not data then return end
        if data.targets and not data.targets[source] then return end
        handleResponse(CallbackRegistry, name, callbackId, ...)
    end)

    -- Client-side implementation
else
    local ClientCallbacks = {}
    local ReboundCallbacks = {}

    function Callback.Register(name, handler)
        ClientCallbacks[name] = handler
    end

    function Callback.RegisterRebound(name, handler)
        ReboundCallbacks[name] = handler
    end

    function Callback.Trigger(name, ...)
        local args = { ... }
        local callback = type(args[1]) == 'function' and table.remove(args, 1) or nil

        local callbackId = generateCallbackId(name)
        local promise = promise.new()

        CallbackRegistry[callbackId] = {
            callback = callback,
            promise = promise
        }

        TriggerServerEvent(EVENT_NAMES.CLIENT_TO_SERVER, name, callbackId, table.unpack(args))

        if not callback then
            local result = Citizen.Await(promise)
            return table.unpack(result)
        end
    end

    RegisterNetEvent(EVENT_NAMES.CLIENT_RESPONSE, function(name, callbackId, ...)
        if ReboundCallbacks[name] then
            ReboundCallbacks[name](...)
        end
        handleResponse(CallbackRegistry, name, callbackId, ...)
    end)

    RegisterNetEvent(EVENT_NAMES.SERVER_TO_CLIENT, function(name, callbackId, ...)
        local handler = ClientCallbacks[name]
        if not handler then return end

        local result = table.pack(handler(...))
        TriggerServerEvent(EVENT_NAMES.SERVER_RESPONSE, name, callbackId, table.unpack(result))
    end)
end

-- Exports
exports('Callback', Callback)
exports('RegisterCallback', Callback.Register)
exports('TriggerCallback', Callback.Trigger)
if not IsDuplicityVersion() then
    exports('RegisterRebound', Callback.RegisterRebound)
end

return Callback
