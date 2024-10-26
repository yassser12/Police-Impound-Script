local QBCore = exports['qb-core']:GetCoreObject()

local restrictedArea = vector3(461.06, -1018.90, 28.08)  -- The allowed vector
local restrictedRadius = 10.0  -- Radius around the allowed vector

-- Function to draw 3D text
function Draw3DText(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local scale = 0.35 -- Adjust the scale of the text
    local font = 4 -- Set the font type (1-7)
    
    if onScreen then
        SetTextFont(font)
        SetTextScale(scale, scale)
        SetTextColour(255, 255, 255, 215) -- White color with some transparency
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Create a thread to continuously draw the 3D text
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Wait 0 ms to keep the loop running

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)

        -- Check if the player is within the vicinity of the restricted area
        if #(coords - restrictedArea) <= restrictedRadius then
            Draw3DText(restrictedArea, "/impoundmenu to see vehicles impounded")
        end
    end
end)

-- Register the command for impounding a vehicle
RegisterCommand("impound", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70) -- Find the closest vehicle within 5 meters

    if vehicle and vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        local model = GetEntityModel(vehicle)
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

        -- Check if the player is a police officer
        QBCore.Functions.TriggerCallback("police:checkPoliceJob", function(isPolice)
            if isPolice then
                lib.progressBar({
                    duration = 5000,  -- Progress bar duration
                    label = 'Impounding vehicle...',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { car = true },
                    anim = {
                        dict = 'mp_car_bomb',
                        clip = 'car_bomb_drop'
                    },
                    onCancel = function() 
                        QBCore.Functions.Notify('Impound canceled.', 'error')
                    end,
                })

                -- Trigger server event to impound the vehicle
                TriggerServerEvent("police:impoundVehicle", vehicleNetId, plate, model)
                QBCore.Functions.Notify('Vehicle impounded!', 'success')
            else
                QBCore.Functions.Notify('You are not authorized to do this.', 'error')
            end
        end)
    else
        QBCore.Functions.Notify('No nearby vehicles found to impound.', 'error')
    end
end)

-- Register the command for the impound menu
RegisterCommand("impoundmenu", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    -- Check if the player is within the allowed area
    if #(coords - restrictedArea) > restrictedRadius then
        QBCore.Functions.Notify("rak bera zone ser l comico.", "error")
        return
    end

    QBCore.Functions.TriggerCallback("police:getImpoundedVehicles", function(vehicles)
        if #vehicles > 0 then
            local menuOptions = {}

            for _, vehicle in ipairs(vehicles) do
                table.insert(menuOptions, {
                    title = vehicle.model .. " (" .. vehicle.plate .. ")",
                    description = "Impounded At: " .. vehicle.impounded_at,
                    event = "police:viewImpoundedVehicle",
                    args = vehicle
                })
            end

            lib.registerContext({
                id = 'impound_menu',
                title = 'Impounded Vehicles',
                options = menuOptions
            })

            lib.showContext('impound_menu')
        else
            QBCore.Functions.Notify("No vehicles currently impounded.", "error")
        end
    end)
end)

-- Event triggered when selecting a vehicle from the menu
RegisterNetEvent("police:viewImpoundedVehicle")
AddEventHandler("police:viewImpoundedVehicle", function(vehicleData)
    local confirmMenuOptions = {
        {
            title = "Take Vehicle",
            description = "Spawn the vehicle and get inside.",
            event = "police:confirmTakeVehicle",
            args = vehicleData
        },
        {
            title = "Cancel",
            description = "Cancel the operation.",
            event = "police:cancel",
        }
    }

    lib.registerContext({
        id = 'confirm_vehicle_menu',
        title = 'Confirm Vehicle Action',
        options = confirmMenuOptions
    })

    lib.showContext('confirm_vehicle_menu')
end)

-- Event triggered when confirming to take the vehicle
RegisterNetEvent("police:confirmTakeVehicle")
AddEventHandler("police:confirmTakeVehicle", function(vehicleData)
    -- Trigger the server event to take the vehicle
    TriggerServerEvent("police:takeImpoundedVehicle", vehicleData)
    lib.hideContext() -- Hide the context menu after selection
end)

-- Event triggered when cancelling the operation
RegisterNetEvent("police:cancel")
AddEventHandler("police:cancel", function()
    lib.hideContext() -- Hide the context menu on cancel
    QBCore.Functions.Notify("Operation cancelled.", "error")
end)
