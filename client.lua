local QBCore = exports['qb-core']:GetCoreObject()

local restrictedArea = vector3(461.06, -1018.90, 28.08)
local restrictedRadius = 10.0

function Draw3DText(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local scale = 0.35
    local font = 4

    if onScreen then
        SetTextFont(font)
        SetTextScale(scale, scale)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)

        if #(coords - restrictedArea) <= restrictedRadius then
            Draw3DText(restrictedArea, "/impoundmenu to see vehicles impounded")
        end
    end
end)

RegisterCommand("impound", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70)

    if vehicle and vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        local model = GetEntityModel(vehicle)
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

        QBCore.Functions.TriggerCallback("police:checkPoliceJob", function(isPolice)
            if isPolice then
                lib.progressBar({
                    duration = 5000,
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

RegisterCommand("impoundmenu", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

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

RegisterNetEvent("police:confirmTakeVehicle")
AddEventHandler("police:confirmTakeVehicle", function(vehicleData)
    TriggerServerEvent("police:takeImpoundedVehicle", vehicleData)
    lib.hideContext()
end)

RegisterNetEvent("police:cancel")
AddEventHandler("police:cancel", function()
    lib.hideContext()
    QBCore.Functions.Notify("Operation cancelled.", "error")
end)
