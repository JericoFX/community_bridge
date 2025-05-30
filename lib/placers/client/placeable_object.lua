Scaleform = Scaleform or Require("lib/scaleform/client/scaleform.lua")
Utility = Utility or Require("lib/utility/client/utility.lua")
Gizmo = Gizmo or Require("lib/placers/client/gizmo.lua")
Raycast = Raycast or Require("lib/raycast/client/raycast.lua")

PlaceableObject = PlaceableObject or {}

local data = {
    entity = nil,
    placing = false,
}

function PlaceableObject.Eyetrace(depth, disableSphere)
    local screenX = GetDisabledControlNormal(0, 239)
    local screenY = GetDisabledControlNormal(0, 240)

    local world, normal = GetWorldCoordFromScreenCoord(screenX, screenY)
    local playerPos = GetEntityCoords(PlayerPedId())
    local target = playerPos + normal * depth
    if not disableSphere then
        DrawSphere(target.x, target.y, target.z, 0.5, 255, 0, 0, 0.5)
    end
    return target
end

function PlaceableObject.InBoundary(pos, boundary)
    if not boundary then return false end
    local x, y, z = table.unpack(pos)
    local minX, minY, minZ = table.unpack(boundary.min)
    local maxX, maxY, maxZ = table.unpack(boundary.max)
    return x >= minX and x <= maxX and y >= minY and y <= maxY and z >= minZ and z <= maxZ
end
-- Creates a placeable object in the game world.
-- @param model (string) The model of the object to create.
-- @param onConfirm (function) [optional] The callback function to execute when the object is confirmed.
-- @param onUpdate (function) [optional] The callback function to execute when the object is moved.
-- @param onCancel (function) [optional] The callback function to execute when the object is canceled.
-- @param settings (table) [optional] Additional settings for the placeable object.
--     - depthMin (number) The minimum depth for the object placement. Default is 2.0.
--     - depthMax (number) The maximum depth for the object placement. Default is 10.0.
--     - rotationStep (number) The rotation step for the object. Default is 15.0.
--     - depthStep (number) The depth step for the object. Default is 1.0.
function PlaceableObject.Create(data, model, onConfirm, onUpdate, onCancel, settings)
    local settings = settings or {}
    local depthMin = settings.depthMin or 2.0
    depthMax = settings.depthMax or 10.0
    rotationStep = settings.rotationStep or 15.0
    depthStep = settings.depthStep or 1.0
    disableSphere = settings.useSphere and false or true
    local depth = settings.depth or 10.0
    data.placing = true
    data.paused = false
    local initialPos = nil
    local placeOnGround = true
    local allowedMats = settings.allowedMats
    local boundary = settings.boundary
    local config = settings.config or {}

    --scaleform
    local scaleform = Scaleform.SetupInstructionalButtons({
        {type = "CLEAR_ALL"},
        {type = "SET_CLEAR_SPACE", int = 200},
        {type = "SET_DATA_SLOT", name = config?.place_object?.name or 'Place Object:', keyIndex = config?.place_object?.key or {223}, int = 5},
        {type = "SET_DATA_SLOT", name = config?.cancel_placement?.name or 'Cancel Placement:', keyIndex = config?.cancel_placement?.key or {222}, int = 4},
        {type = "SET_DATA_SLOT", name = config?.snap_to_ground?.name or 'Snap to Ground:', keyIndex = config?.snap_to_ground?.key or {19}, int = 1},
        {type = "SET_DATA_SLOT", name = config?.rotate?.name or 'Rotate:', keyIndex = config?.rotate?.key or {14, 15}, int = 2},
        {type = "SET_DATA_SLOT", name = config?.distance?.name or 'Distance:', keyIndex = config?.distance?.key or {14,15,36}, int = 3},
        {type = "SET_DATA_SLOT", name = config?.toggle_placement?.name or 'Toggle Placement:', keyIndex = config?.toggle_placement?.key or {199}, int = 0},
        {type = "SET_DATA_SLOT", name = config?.gizmo?.name or 'Toggle Gizmo:', keyIndex = config?.gizmo?.key or {38}, int = 6},
        {type = "DRAW_INSTRUCTIONAL_BUTTONS"},
        {type = "SET_BACKGROUND_COLOUR"},
    })
    local heading = -GetEntityHeading(PlayerPedId())

    local pos = PlaceableObject.Eyetrace(depth, disableSphere)
    if not data.spawned and model then
        --get player heading
        local obj = Utility.CreateProp(model, pos, vector3(0, 0, heading), nil)
        data.spawned = obj
    end
    assert(data.spawned, "Failed to create object")
    SetEntityCollision(data.spawned, false, false)
    SetEntityAlpha(data.spawned, 150, false)

    SetPedConfigFlag(PlayerPedId(), 146, true)
    SetCanClimbOnEntity(data.spawned, false)
    SetEntityCompletelyDisableCollision(data.spawned, true, false)
    SetEntityNoCollisionEntity(PlayerPedId(), data.spawned, false)
    local inBounds = true
    if allowedMats or boundary then
        CreateThread(function()
            while data.placing do
                local hit, _, coords, _, materialHash = Raycast.FromCamera(1, 4)
                if hit and hit ~=1 and (allowedMats?[materialHash] or PlaceableObject.InBoundary(GetEntityCoords(data.spawned), boundary)) then
                    if not inBounds then
                        inBounds = true
                        SetEntityDrawOutlineColor(0, 255, 0, 255)
                        SetEntityDrawOutline(data.spawned, true)
                    end
                elseif inBounds then
                    inBounds = false
                    SetEntityDrawOutline(data.spawned, false)
                end
                Wait(500)
            end
        end)
    end

    CreateThread(function()
        while data.placing do
            if data.paused then goto continue end
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 36, true) -- INPUT_DUCK.

            if IsDisabledControlJustPressed(0, 223) then -- left click
                if not inBounds then 
                    Notify.SendNotify("You can't place this object here", "error", 5000)
                elseif onConfirm then 
                    onConfirm(data.spawned, pos, heading) 
                    data.placing  = false
                end
            end

            if IsDisabledControlJustPressed(0, 25) then -- right click
                data.placing  = false
                if onCancel then
                    onCancel(data.spawned, pos, heading)
                else
                    DeleteEntity(data.spawned)
                end
                return
            end

            if IsControlJustPressed(0,19) then
                placeOnGround = not placeOnGround
            end

            if IsControlJustPressed(0, 38) then -- TAB key to switch to gizmo
                data.placing = false                
                return Gizmo.UseGizmo(data.spawned, onConfirm, onUpdate, onCancel, settings)
            end

            if IsControlPressed(0,224) then -- left ctrl
                if IsControlJustPressed(0, 261) then -- scroll up
                    depth = depth + depthStep
                    if depth > depthMax then
                        depth = depthMax
                    end
                end

                if IsControlJustPressed(0, 262) then -- scroll down
                    depth = depth - depthStep
                    if depth < depthMin then
                        depth = depthMin
                    end
                end
            else
                if IsControlJustPressed(0, 261) then -- scroll up
                    heading = heading + rotationStep
                    if heading > 360 then
                        heading = 0
                    end
                end
                if IsControlJustPressed(0, 262) then -- scroll down
                    heading = heading - rotationStep
                    if heading < 0 then
                        heading = 360
                    end
                end
            end

            pos = PlaceableObject.Eyetrace(depth, disableSphere)
            if data.spawned then
                SetEntityCoords(data.spawned, pos.x, pos.y, pos.z)
                SetEntityHeading(data.spawned, heading)
                if placeOnGround then
                    PlaceObjectOnGroundProperly(data.spawned)
                    pos = GetEntityCoords(data.spawned)
                end
            end
            if onUpdate and type(onUpdate) == 'function' then onUpdate(data.spawned, pos, heading) end
            ::continue::
            if IsControlJustPressed(0, 199) then -- home
                data.paused = not data.paused
            end
            Wait(1)
        end
    end)
end

return PlaceableObject