---@diagnostic disable: duplicate-set-field
local resourceName = "yseries"
if GetResourceState(resourceName) == 'missing' then return end
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
    return exports.yseries:GetPhoneNumberBySourceId(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
Phone.SendEmail = function(src, email, title, message)
    local phoneNumber = exports.yseries:GetPhoneNumberBySourceId(src)
    if not phoneNumber then return false, print("Could not find phone number for source: " .. tostring(src)) end
    -- assuming received is a boolean?
    local _, received = exports.yseries:SendMail({
        title = title,
        sender = email,
        senderDisplayName = email,
        content = message,
    }, 'phoneNumber', phoneNumber)
    return received
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
