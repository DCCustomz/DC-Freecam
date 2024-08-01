local cam
local isFreecamActive = false
local movementSpeed = 0.5
local isUIVisible = true
local maxDistance = 10.0 -- Maximum distance the camera can be from the player
local playerCoords = nil
local SETTINGS = {
    BASE_MOVE_MULTIPLIER = 1.0,
    FAST_MOVE_MULTIPLIER = 2.0,
    SLOW_MOVE_MULTIPLIER = 0.5,
    LOOK_SENSITIVITY_X = 5.0,
    LOOK_SENSITIVITY_Y = 5.0,
}

function GetSpeedMultiplier()
    local fastNormal = GetDisabledControlNormal(0, 21) -- Shift key
    local slowNormal = GetDisabledControlNormal(0, 36) -- Ctrl key

    local baseSpeed = movementSpeed
    local fastSpeed = 1 + ((SETTINGS.FAST_MOVE_MULTIPLIER - 1) * fastNormal)
    local slowSpeed = 1 + ((SETTINGS.SLOW_MOVE_MULTIPLIER - 1) * slowNormal)

    local frameMultiplier = GetFrameTime() * 60
    local speedMultiplier = baseSpeed * fastSpeed / slowSpeed

    return speedMultiplier * frameMultiplier
end

function enableFreecam()
    local playerPed = PlayerPedId()
    playerCoords = GetEntityCoords(playerPed)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, playerCoords.x, playerCoords.y, playerCoords.z + 2)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(playerPed))
    RenderScriptCams(true, false, 0, true, true)

    isFreecamActive = true
    displayControlsUI()
    FreezeEntityPosition(playerPed, true)
end

function disableFreecam()
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)

    isFreecamActive = false
    hideControlsUI()
end

function EulerToMatrix(rotX, rotY, rotZ)
    local radX = math.rad(rotX)
    local radY = math.rad(rotY)
    local radZ = math.rad(rotZ)

    local sinX = math.sin(radX)
    local cosX = math.cos(radX)
    local sinY = math.sin(radY)
    local cosY = math.cos(radY)
    local sinZ = math.sin(radZ)
    local cosZ = math.cos(radZ)

    local vecX = {}
    local vecY = {}
    local vecZ = {}

    vecX.x = cosY * cosZ
    vecX.y = cosY * sinZ
    vecX.z = -sinY

    vecY.x = cosZ * sinX * sinY - cosX * sinZ
    vecY.y = cosX * cosZ - sinX * sinY * sinZ
    vecY.z = cosY * sinX

    vecZ.x = -cosX * cosZ * sinY + sinX * sinZ
    vecZ.y = -cosZ * sinX + cosX * sinY * sinZ
    vecZ.z = cosX * cosY

    vecX = vector3(vecX.x, vecX.y, vecX.z)
    vecY = vector3(vecY.x, vecY.y, vecY.z)
    vecZ = vector3(vecZ.x, vecZ.y, vecZ.z)

    return vecX, vecY, vecZ
end

function UpdateCamera()
    if not isFreecamActive then return end

    local pos = GetCamCoord(cam)
    local rot = GetCamRot(cam, 2)

    local vecX, vecY, vecZ = EulerToMatrix(rot.x, rot.y, rot.z)

    -- Get speed multiplier for movement
    local speedMultiplier = GetSpeedMultiplier()

    -- Get rotation input
    local lookX = GetDisabledControlNormal(0, 1)
    local lookY = GetDisabledControlNormal(0, 2)

    -- Calculate new rotation.
    local rotX = rot.x + (-lookY * SETTINGS.LOOK_SENSITIVITY_X)
    local rotZ = rot.z + (-lookX * SETTINGS.LOOK_SENSITIVITY_Y)
    local rotY = rot.y

    -- Adjust position relative to camera rotation.
    local moveX = (IsControlPressed(0, 33) and -1 or 0) + (IsControlPressed(0, 32) and 1 or 0) -- A and D keys
    local moveY = (IsControlPressed(0, 35) and 1 or 0) + (IsControlPressed(0, 34) and -1 or 0) -- W and S keys

    local newPos = pos + (vecX * moveY * speedMultiplier) + (vecY * moveX * speedMultiplier)

    -- Up and Down movement
    if IsControlPressed(0, 44) then -- Q
        newPos = newPos + (vecZ * speedMultiplier)
    end

    if IsControlPressed(0, 38) then -- E
        newPos = newPos + (vecZ * -speedMultiplier)
    end

    -- Check distance from player
    if #(newPos - playerCoords) > maxDistance then
        newPos = pos
    end

    -- Tilt Camera
    if IsDisabledControlPressed(0, 24) then -- Left Mouse Button
        rotY = rotY - 1.0
    end

    if IsDisabledControlPressed(0, 25) then -- Right Mouse Button
        rotY = rotY + 1.0
    end

    -- Adjust speed
    if IsControlJustReleased(0, 14) then -- Mouse Wheel Down
        movementSpeed = math.max(0.1, movementSpeed - 0.1)
    end

    if IsControlJustReleased(0, 15) then -- Mouse Wheel Up
        movementSpeed = movementSpeed + 0.1
    end

    -- Disable controls that move the player
    DisableControlAction(0, 30, true) -- Disable move left/right
    DisableControlAction(0, 31, true) -- Disable move forward/backward
    DisableControlAction(0, 24, true) -- Disable attack
    DisableControlAction(0, 25, true) -- Disable aim
    DisableControlAction(0, 140, true) -- Disable melee attack light
    DisableControlAction(0, 141, true) -- Disable melee attack heavy
    DisableControlAction(0, 142, true) -- Disable melee attack alternate
    DisableControlAction(0, 257, true) -- Disable melee attack 2
    DisableControlAction(0, 263, true) -- Disable melee attack 3
    DisableControlAction(0, 264, true) -- Disable melee attack 4

    -- Update camera
    SetCamCoord(cam, newPos.x, newPos.y, newPos.z)
    SetCamRot(cam, rotX, rotY, rotZ, 2)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if isFreecamActive then
            UpdateCamera()

            if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 73) then -- ESC or X
                disableFreecam()
            end

            if IsControlJustPressed(0, 19) then -- Left Alt
                if isUIVisible then
                    hideControlsUI()
                else
                    displayControlsUI()
                end
                isUIVisible = not isUIVisible
            end
        end
    end
end)

function displayControlsUI()
    lib.showTextUI([[
        Freecam Controls:
        W - Move Forward
        S - Move Backward
        A - Move Left
        D - Move Right
        Q - Move Up
        E - Move Down
        Mouse - Rotate Camera
        Left Mouse Button - Tilt Left
        Right Mouse Button - Tilt Right
        Mouse Wheel - Adjust Speed
        Left Alt - Toggle UI
        X - Exit Freecam
        Esc - Exit Freecam
    ]])
end

function hideControlsUI()
    lib.hideTextUI()
end

RegisterCommand('cam', function()
    if isFreecamActive then
        disableFreecam()
    else
        enableFreecam()
    end
end, false)

RegisterCommand('exitFreecam', function()
    disableFreecam()
end, false)
