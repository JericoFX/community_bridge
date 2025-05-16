---@class CacheEntry
---@field Name string
---@field Compare fun(): any
---@field WaitTime integer | nil
---@field LastChecked integer|nil
---@field OnChange fun(new:any, old:any)[]
---@field Value any

---@class CacheModule
---@field Caches table<string, CacheEntry>
---@field LoopRunning boolean
---@field Create fun(name:string, compare:fun():any, waitTime:integer | nil): CacheEntry
---@field Get fun(name:string): any
---@field OnChange fun(name:string, onChange:fun(new:any, old:any))
---@field Remove fun(name:string)
local Cache = {} ---@type CacheModule

local Config = Require("settings/sharedConfig.lua")
local max = 5000
local CreateThread = CreateThread
local Wait = Wait
local GetGameTimer = GetGameTimer

local resourceCallbacks = {} -- Add callbacks from resources

Cache.Caches = Cache.Caches or {}
Cache.LoopRunning = Cache.LoopRunning or false

---@param ... any
local function debugPrint(...)
    if Config.DebugLevel == 0 then return end
    print("^2[Cache]^0", ...)
end

local function HasActiveCaches()
    for _, cache in pairs(Cache.Caches) do
        if cache.WaitTime ~= nil then
            return true
        end
    end
    return false
end

local function processCacheEntry(now, cache)
    cache.LastChecked = cache.LastChecked or now
    cache.WaitTime = tonumber(cache.WaitTime) or max
    local elapsed = now - cache.LastChecked
    local remaining = cache.WaitTime - elapsed

    if remaining <= 0 then
        local oldValue = cache.Value
        cache.Value = cache.Compare()
        if cache.Value ~= oldValue and cache.OnChange then
            for i, onChange in ipairs(cache.OnChange) do
                Citizen.CreateThreadNow(function()
                    Wait(0)
                    onChange(cache.Value, oldValue)
                end)
            end
        end
        cache.LastChecked = now
        remaining = cache.WaitTime
    end

    return remaining
end

local function getNextWait(now)
    local minWait = nil
    for name, cache in pairs(Cache.Caches) do
        if cache.Compare and cache.WaitTime ~= nil then
            local remaining = processCacheEntry(now, cache)
            if not minWait or remaining < minWait then
                minWait = remaining
                if minWait <= 0 then break end
            end
        end
    end
    return minWait
end

local function StartLoop()
    if Cache.LoopRunning then return end
    if not HasActiveCaches() then return end
    Cache.LoopRunning = true
    CreateThread(function()
        while Cache.LoopRunning do
            local now = GetGameTimer()
            local minWait = getNextWait(now)
            if minWait then
                Wait(math.max(0, minWait))
            else
                Wait(max)
            end
            if not HasActiveCaches() then
                Cache.LoopRunning = false
            end
        end
    end)
end

---@param name string
---@param compare fun():any
---@param waitTime integer | nil
---@return CacheEntry | nil
function Cache.Create(name, compare, waitTime)
    assert(name, "Cache name is required.")
    assert(compare, "Comparison function is required.")
    if type(waitTime) ~= "number" then
        waitTime = nil
    end
    local _name = tostring(name)
    local cache = Cache.Caches[_name]
    if cache and cache.Compare == compare then
        debugPrint(_name .. " already exists with the same comparison function.")
        return cache
    end
    local ok, result = pcall(compare)
    if not ok then
        debugPrint("Error creating cache '" .. _name .. "': " .. tostring(result))
        return nil
    end
    ---@type CacheEntry
    local newCache = {
        Name = _name,
        Compare = compare,
        WaitTime = waitTime, -- can be nil
        LastChecked = nil,
        OnChange = {},
        Value = result
    }
    Cache.Caches[_name] = newCache

    debugPrint(_name .. " created with initial value: " .. tostring(result))
    for _, onChange in pairs(newCache.OnChange) do
        onChange(newCache.Value, 0)
    end
    StartLoop()
    return newCache
end

---@param name string
---@return any
function Cache.Get(name)
    assert(name, "Cache name is required.")
    local _name = tostring(name)
    local cache = Cache.Caches[_name]
    return cache and cache.Value or nil
end

--- This add a callback to the cache entry that will be called when the value changes.
--- The callback will be called with the new value and the old value.
--- you can call the value again to delete the callback.
---@param name string
---@param onChange fun(new:any, old:any)
function Cache.OnChange(name, onChange)
    assert(name, "Cache name is required.")
    local _name = tostring(name)
    local cache = Cache.Caches[_name]
    assert(cache, "Cache with name '" .. _name .. "' does not exist.")

    -- Figure out which resource is trying to register this callback
    local invokingResource = GetInvokingResource()
    if not invokingResource then return end

    -- Make sure we have a place to store callbacks for this resource
    resourceCallbacks[invokingResource] = resourceCallbacks[invokingResource] or {}

    -- Add the new callback to our list
    local callbackIndex = #cache.OnChange + 1
    cache.OnChange[callbackIndex] = onChange

    -- Keep track of this callback so we can clean it up later
    table.insert(resourceCallbacks[invokingResource], {
        cacheName = _name,
        index = callbackIndex
    })

    -- Watch for when the resource stops and clean up its callbacks
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == invokingResource then
            -- Clean up any callbacks this resource registered
            local callbacks = resourceCallbacks[resourceName]
            if callbacks then
                for _, cb in ipairs(callbacks) do
                    local targetCache = Cache.Caches[cb.cacheName]
                    if targetCache then
                        -- Remove the callback from our list
                        table.remove(targetCache.OnChange, cb.index)
                        debugPrint(("Removed OnChange callback from cache '%s' - resource '%s' stopped"):format(
                            cb.cacheName,
                            resourceName
                        ))
                    end
                end
                -- Clear out all callbacks for this resource
                resourceCallbacks[resourceName] = nil
            end
        end
    end)

    debugPrint(("Added new OnChange callback to cache '%s' from resource '%s'"):format(_name, invokingResource))
end

---@param name string
function Cache.Remove(name)
    assert(name, "Cache name is required.")
    local _name = tostring(name)
    local cache = Cache.Caches[_name]
    if cache then
        Cache.Caches[_name] = nil
        debugPrint(_name .. " removed from cache.")
        if next(Cache.Caches) == nil then
            Cache.LoopRunning = false
        end
    end
end

---@param name string
---@param newValue any
function Cache.Update(name, newValue)
    assert(name, "Cache name is required.")
    local _name = tostring(name)
    local cache = Cache.Caches[_name]
    assert(cache, "Cache with name '" .. _name .. "' does not exist.")
    local oldValue = cache.Value
    if oldValue ~= newValue then
        cache.Value = newValue
        for _, onChange in pairs(cache.OnChange) do
            onChange(newValue, oldValue)
        end
    end
end

return Cache
