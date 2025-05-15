-- DUI (Direct User Interface) Manager for FiveM
-- Table-based implementation with mouse support, botones, hover, cámara y reemplazo de textura

---@class DUI
DUI = {}

local DEFAULT_WIDTH <const> = 1280
local DEFAULT_HEIGHT <const> = 720

local activeInstances = {}
local instanceCounter = 0

local mouseState = {
    tracking = false,
    activeId = nil,
    lastX = 0,
    lastY = 0,
    isPressed = false,
    currentButton = nil
}

local MOUSE_BUTTONS <const> = {
    LEFT = "left",
    MIDDLE = "middle",
    RIGHT = "right"
}

---@class DUIInstance
---@field id number
---@field url string
---@field width number
---@field height number
---@field handle number
---@field txd string
---@field txn string
---@field active boolean
---@field trackMouse boolean
---@field mouseScale table<string, number>
---@field buttons table<string, table>
---@field hoveredButton string|nil

function DUI.Create(url, width, height)
    if not url or type(url) ~= "string" then
        return print("DUI.Create: URL is required and must be a string")
    end

    width = width or DEFAULT_WIDTH
    height = height or DEFAULT_HEIGHT
    instanceCounter = instanceCounter + 1

    local id = instanceCounter
    local handle = CreateDui(url, width, height)

    if not handle then
        return print("DUI.Create: Failed to create DUI instance")
    end

    local instance = {
        id = id,
        url = url,
        width = width,
        height = height,
        handle = handle,
        txd = "dui_" .. id,
        txn = "texture_" .. id,
        active = true,
        trackMouse = false,
        mouseScale = {
            x = 1.0,
            y = 1.0
        },
        buttons = {},
        hoveredButton = nil
    }

    -- Create runtime texture
    local duiHandle = GetDuiHandle(handle)
    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(instance.txd), instance.txn, duiHandle)

    activeInstances[id] = instance
    return id
end

function DUI.Destroy(id)
    local instance = activeInstances[id]
    if not instance then return false end

    if instance.handle then
        DestroyDui(instance.handle)
    end

    activeInstances[id] = nil
    return true
end

function DUI.SetURL(id, url)
    local instance = activeInstances[id]
    if not instance then return false end

    SetDuiUrl(instance.handle, url)
    instance.url = url
    return true
end

function DUI.SendMessage(id, message)
    local instance = activeInstances[id]
    if not instance then return false end

    SendDuiMessage(instance.handle, json.encode(message))
    return true
end

-- NUEVO: Reemplazar la textura de un DUI existente
---@param id number DUI instance ID
---@param url string Nueva URL de la textura
---@return boolean success
function DUI.ReplaceTexture(id, url)
    local instance = activeInstances[id]
    if not instance then return false end

    -- Destruir el DUI anterior
    if instance.handle then
        DestroyDui(instance.handle)
    end

    -- Crear uno nuevo con la nueva textura
    local handle = CreateDui(url, instance.width, instance.height)
    if not handle then
        print("DUI.ReplaceTexture: Failed to create new DUI for id", id)
        return false
    end

    instance.handle = handle
    instance.url = url

    local duiHandle = GetDuiHandle(handle)
    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(instance.txd), instance.txn, duiHandle)
    return true
end

function DUI.MoveMouse(id, x, y)
    local instance = activeInstances[id]
    if not instance then return false end

    SendDuiMouseMove(instance.handle, x, y)
    return true
end

function DUI.MouseDown(id, button)
    local instance = activeInstances[id]
    if not instance then return false end

    if not MOUSE_BUTTONS[button:upper()] then
        return print("DUI.MouseDown: Invalid button. Must be 'left', 'middle', or 'right'")
    end

    if instance.trackMouse then
        mouseState.isPressed = true
        mouseState.currentButton = button
    end

    SendDuiMouseDown(instance.handle, button)
    return true
end

function DUI.MouseUp(id, button)
    local instance = activeInstances[id]
    if not instance then return false end

    if not MOUSE_BUTTONS[button:upper()] then
        return print("DUI.MouseUp: Invalid button. Must be 'left', 'middle', or 'right'")
    end

    if instance.trackMouse then
        mouseState.isPressed = false
        mouseState.currentButton = nil
    end

    SendDuiMouseUp(instance.handle, button)
    return true
end

function DUI.MouseWheel(id, deltaY, deltaX)
    local instance = activeInstances[id]
    if not instance then return false end

    SendDuiMouseWheel(instance.handle, deltaY, deltaX)
    return true
end

function DUI.Click(id, x, y, button)
    button = button or "left"
    local instance = activeInstances[id]
    if not instance then return false end

    -- Detectar si el click está sobre algún botón
    if instance.buttons then
        for name, btn in pairs(instance.buttons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.onClick then
                    btn.onClick(name, x, y, button)
                end
            end
        end
    end

    if not DUI.MoveMouse(id, x, y) then return false end
    if not DUI.MouseDown(id, button) then return false end
    Citizen.Wait(50)
    return DUI.MouseUp(id, button)
end

function DUI.TrackMouse(id, enabled, scaleX, scaleY)
    local instance = activeInstances[id]
    if not instance then return false end

    instance.trackMouse = enabled
    instance.mouseScale.x = scaleX or 1.0
    instance.mouseScale.y = scaleY or 1.0

    if enabled then
        mouseState.tracking = true
        mouseState.activeId = id
    elseif mouseState.activeId == id then
        mouseState.tracking = false
        mouseState.activeId = nil
    end

    return true
end

-- Añade un botón clickeable y con hover a una instancia DUI
function DUI.AddButton(id, name, x, y, w, h, onClick, onHover)
    local instance = activeInstances[id]
    if not instance then return false end
    instance.buttons = instance.buttons or {}
    instance.hoveredButton = instance.hoveredButton or nil
    instance.buttons[name] = {
        x = x,
        y = y,
        w = w,
        h = h,
        onClick = onClick,
        onHover = onHover,
        hovered = false
    }
    return true
end

local function UpdateMousePosition(screenX, screenY)
    if not mouseState.tracking or not mouseState.activeId then return false end

    local instance = activeInstances[mouseState.activeId]
    if not instance or not instance.trackMouse then return false end

    local scaledX = screenX * instance.mouseScale.x
    local scaledY = screenY * instance.mouseScale.y

    -- Detección de hover sobre botones
    if instance.buttons then
        local hovered = nil
        for btnName, btn in pairs(instance.buttons) do
            if scaledX >= btn.x and scaledX <= btn.x + btn.w and scaledY >= btn.y and scaledY <= btn.y + btn.h then
                hovered = btnName
                if not btn.hovered then
                    btn.hovered = true
                    if btn.onHover then btn.onHover(true) end
                end
            else
                if btn.hovered then
                    btn.hovered = false
                    if btn.onHover then btn.onHover(false) end
                end
            end
        end
        instance.hoveredButton = hovered
    end

    if scaledX ~= mouseState.lastX or scaledY ~= mouseState.lastY then
        mouseState.lastX = scaledX
        mouseState.lastY = scaledY
        DUI.MoveMouse(mouseState.activeId, scaledX, scaledY)
        return true
    end

    return false
end

Citizen.CreateThread(function()
    while true do
        if mouseState.tracking and mouseState.activeId then
            local instance = activeInstances[mouseState.activeId]
            if instance and instance.trackMouse then
                local screenX, screenY = GetNuiCursorPosition()
                UpdateMousePosition(screenX, screenY)
                if mouseState.isPressed and mouseState.currentButton then
                    SendDuiMouseDown(instance.handle, mouseState.currentButton)
                end
            end
        end
        Citizen.Wait(0)
    end
end)

function DUI.GetTextures(id)
    local instance = activeInstances[id]
    if not instance then return nil, nil end
    return instance.txd, instance.txn
end

function DUI.Exists(id)
    local instance = activeInstances[id]
    return instance ~= nil and instance.active
end

function DUI.GetActiveInstances()
    return activeInstances
end

function DUI.CleanupAll()
    for id in pairs(activeInstances) do
        DUI.Destroy(id)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DUI.CleanupAll()
end)

-- Cámara: acercar y restaurar
function DUI.FocusCamera(pos, distancia, fov)
    local playerPed = PlayerPedId()
    local rot = GetEntityRotation(playerPed)
    local forward = vector3(
        math.sin(math.rad(rot.z)) * math.cos(math.rad(rot.x)),
        -math.cos(math.rad(rot.z)) * math.cos(math.rad(rot.x)),
        math.sin(math.rad(rot.x))
    )
    local camPos = pos - forward * distancia

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, pos.x, pos.y, pos.z)
    SetCamFov(cam, fov or 60.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    return cam
end

function DUI.ClearCamera(cam)
    if cam then
        SetCamActive(cam, false)
        DestroyCam(cam, false)
        RenderScriptCams(false, false, 0, true, true)
    end
end

return DUI
