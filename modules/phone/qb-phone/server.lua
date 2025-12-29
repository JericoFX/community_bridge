---@diagnostic disable: duplicate-set-field
local resourceName = "qb-phone"
if GetResourceState(resourceName) == 'missing' then return end
if GetResourceState("lb-phone") ~= 'missing' then return end
if GetResourceState("gksphone") ~= 'missing' then return end
if GetResourceState("okokPhone") ~= 'missing' then return end
if GetResourceState("qs-smartphone") ~= 'missing' then return end
if GetResourceState("yseries") ~= 'missing' then return end
Phone = Phone or {}

---This will get the name of the Phone system being being used.
---@return string
Phone.GetPhoneName = function()
    return resourceName
end

Phone.GetResourceName = function()
    return resourceName
end

---This will get the phone number of the passed source.
---@param src number
---@return number|boolean
Phone.GetPlayerPhone = function(src)
    return Bridge.Framework.GetPlayerPhone(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(src, email, title, message)
    local identifier = Bridge.Framework.GetPlayerIdentifier(src)
    if not identifier then return false, print(" ^6 Could not Find Player Identifier ^0") end

    local mailData = { sender = email, subject = title, message = message }
    exports["qb-phone"]:sendNewMailToOffline(identifier, mailData)
    return true
end

local emailCooldowns = {}
local EMAIL_COOLDOWN_MS = 5000

RegisterNetEvent('community_bridge:Server:genericEmail', function(data)
    local src = source
    if not src or not data or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if emailCooldowns[src] and now - emailCooldowns[src] < EMAIL_COOLDOWN_MS then return end
    emailCooldowns[src] = now
    if type(data.email) ~= "string" or type(data.title) ~= "string" or type(data.message) ~= "string" then return end
    if data.email:len() > 100 or data.title:len() > 120 or data.message:len() > 2000 then return end
    return Phone.SendEmail(src, data.email, data.title, data.message)
end)

return Phone
