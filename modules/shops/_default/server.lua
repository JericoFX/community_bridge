---@diagnostic disable: duplicate-set-field
Shops = Shops or {}

local registeredShops = {}

local Language = Language or Require("modules/locales/shared.lua")
local locale = Language.Locale
local SHOP_INTERACT_DISTANCE = 3.0

local function getCoordsDistance(a, b)
    if not a or not b then return nil end
    local coordsA = a
    if type(a) == "table" and a.x and a.y and a.z then
        coordsA = vector3(a.x, a.y, a.z)
    end
    local coordsB = b
    if type(b) == "table" and b.x and b.y and b.z then
        coordsB = vector3(b.x, b.y, b.z)
    end
    if type(coordsA) == "vector3" and type(coordsB) == "vector3" then
        return #(coordsA - coordsB)
    end
    return nil
end

local function isPlayerInShopGroups(src, groups)
    if not groups then return true end
    if type(groups) ~= "table" then return false end
    local jobData = Framework.GetPlayerJobData(src)
    local jobName = jobData and jobData.jobName
    if not jobName then return false end
    if groups[jobName] then return true end
    for _, group in pairs(groups) do
        if group == jobName then return true end
    end
    return false
end

---This can open a shop for the client
---@param src number
---@param shopName string
---@return boolean
Shops.OpenShop = function(src, shopName)
    if not shopName and not registeredShops[shopName] then return false, print("community_bridge PLAYERID "..src.." attempted to open invalid shop: "..shopName) end
    TriggerClientEvent('community_bridge:Client:openShop', src, 'shop', shopName, registeredShops[shopName])
    return true
end

---This will create a shop to use on the client side, shops must be registered server side and exsist in the shop inventory table to allow any purchases passed.
---@param shopName string
---@param shopInventory table
---@param shopCoords table
---@param shopGroups table
---@return boolean
Shops.CreateShop = function(shopName, shopInventory, shopCoords, shopGroups)
    if not shopName and not shopInventory and not shopCoords then return false end
    if registeredShops[shopName] then return true end
    registeredShops[shopName] = {name = shopName, inventory = shopInventory, shopCoords = shopCoords, groups = shopGroups}
    return true
end

---This is an internal event to complete a shop transaction, it will verify pass items and amounts are registered to the created shop. Please do not use this function directly.
---@param src number
---@param shopName string
---@param item string
---@param amount number
---@param account string
---@return nil
Shops.CompleteCheckout = function(src, shopName, item, amount, account)
    if not src or not shopName or not item or not amount or not account then return end
    if not amount or amount <= 0 then return end

    local shopData = registeredShops[shopName]
    if not shopData then return end
    if shopData.groups and not isPlayerInShopGroups(src, shopData.groups) then return end
    if shopData.shopCoords then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local distance = getCoordsDistance(playerCoords, shopData.shopCoords)
        if distance and distance > SHOP_INTERACT_DISTANCE then return end
    end

    local itemData = nil
    for _, data in pairs(shopData.inventory) do
        if data.name == item then
            itemData = data
            break
        end
    end
    if not itemData or not itemData.price then return print("community_bridge Player ID "..src.." attempted to purchase invalid item from shop: "..shopName) end
    if itemData.count then
        if itemData.count <= 0 then return Notify.SendNotify(src, locale('Shops.NotEnoughStock'), "error", 5000) end
        if amount > itemData.count then return Notify.SendNotify(src, locale('Shops.NotEnoughStock'), "error", 5000) end
    end
    local totalCost = tonumber(itemData.price) * amount
    local balance = Framework.GetAccountBalance(src, account)
    if not balance then return end
    if balance <= 0 then return Notify.SendNotify(src, locale('Shops.NotEnoughMoney'), "error", 5000) end
    if balance < totalCost then return Notify.SendNotify(src, locale('Shops.NotEnoughMoney'), "error", 5000) end

    if not Framework.RemoveAccountBalance(src, account, totalCost) then return end

    local success = Inventory.AddItem(src, itemData.name, amount)
    if not success then
        Framework.AddAccountBalance(src, account, totalCost)
        return Notify.SendNotify(src, locale('Shops.PurchaseFailed'), "error", 5000)
    end
    if itemData.count then
        itemData.count = itemData.count - amount
    end

    local itemLabel = Inventory.GetItemInfo(itemData.name).label or itemData.name
    Notify.SendNotify(src, locale('Shops.PurchasedItem', amount, itemLabel), "success", 5000)
end

---This is an internal event to complete a checkout, complete with multiple validations. Please do not use this event directly.
---@param shopName string
---@param item string
---@param amount number
---@param account string
RegisterNetEvent("community_bridge:Server:completeCheckout", function(shopName, item, amount, account)
    local src = source
    if not shopName or not item or not account or not amount then return end
    if account ~= "money" and account ~= "bank" then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    Shops.CompleteCheckout(src, shopName, item, amount, account)
end)

return Shops
