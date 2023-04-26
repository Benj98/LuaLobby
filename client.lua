local countdown = 0
local blips = {}

RegisterNetEvent('fivem-lobby:startCountdown')
AddEventHandler('fivem-lobby:startCountdown', function(count)
    countdown = count

    Citizen.CreateThread(function()
        while countdown > 0 do
            Citizen.Wait(1000)

            countdown = countdown - 1
        end
    end)
end)

RegisterNetEvent('fivem-lobby:cancelCountdown')
AddEventHandler('fivem-lobby:cancelCountdown', function()
    countdown = 0
end)

RegisterNetEvent('fivem-lobby:startRound')
AddEventHandler('fivem-lobby:startRound', function()
    print("Round started!")

end)

RegisterNetEvent('fivem-lobby:displayLobbies')
AddEventHandler('fivem-lobby:displayLobbies', function(lobbies)
    local message = "Available lobbies:\n"
    for _, lobby in ipairs(lobbies) do
        message = message .. "ID: " .. lobby.id .. " | Players: " .. lobby.playerCount .. "\n"
    end

    TriggerEvent('chat:addMessage', { 
        args = { message } 
    })
end)

RegisterNetEvent('fivem-lobby:spawnPlayerAtLocation')
AddEventHandler('fivem-lobby:spawnPlayerAtLocation', function(spawnLocation, team)
    if team ~= "spectator" then
        local model

        if team == "cop" then
            model = GetHashKey("police")
        else
            model = GetHashKey("blista")
        end
    
        RequestModel(model)
        while not HasModelLoaded(model) do
            Citizen.Wait(0)
        end
    
        local vehicle = CreateVehicle(model, spawnLocation.x, spawnLocation.y, spawnLocation.z, spawnLocation.rot, true, false)
    
        SetVehicleOnGroundProperly(vehicle)
        SetEntityHeading(vehicle, spawnLocation.rot)
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    
        SetModelAsNoLongerNeeded(model)

        FreezeEntityPosition(playerPed, true)
        FreezeEntityPosition(vehicle, true)
    
        Citizen.CreateThread(function()
            local freezeTime = 1000
    
            if team == "cop" then
                freezeTime = 6000
            end
    
            Citizen.Wait(freezeTime)
    
            FreezeEntityPosition(playerPed, false)
            FreezeEntityPosition(vehicle, false)
        end)
    else 
        exports.spawnmanager:spawnPlayer({
            x = spawnLocation.x,
            y = spawnLocation.y,
            z = spawnLocation.z,
            heading = spawnLocation.rot,
            skipFade = true
        })
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if countdown > 0 then
            SetTextFont(0)
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("Round starting in " .. countdown .. " seconds...")
            DrawText(0.4, 0.05)
        end
    end
end)

RegisterNetEvent('fivem-lobby:playerAddedToLobby')
AddEventHandler('fivem-lobby:playerAddedToLobby', function(lobbyId)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0},
        multiline = true,
        args = {"Lobby System", "You have been added to Lobby ID: " .. lobbyId}
    })
end)

RegisterNetEvent('fivem-lobby:clientRemoveAllWeapons')
AddEventHandler('fivem-lobby:clientRemoveAllWeapons', function()
    local playerPed = PlayerPedId()
    RemoveAllPedWeapons(playerPed, true)
end)

AddEventHandler('fivem-lobby:clientRemoveEffects', function()
    local playerPed = PlayerPedId()

    ResetPedMovementClipset(playerPed, 0)
    RemoveAnimSet("move_heist_lester")
    SetRunSprintMultiplierForPlayer(playerPed, 1)
end)

AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
    TriggerServerEvent('server:onPlayerDied', killerType, deathCoords)
end)

RegisterNetEvent('fivem-lobby:createBlipForCop')
AddEventHandler('fivem-lobby:createBlipForCop', function(suspectId)
    local suspect = GetPlayerFromServerId(suspectId)

    if suspect ~= -1 then
        print('createBlipForCop called')
        
        local suspectPed = GetPlayerPed(suspect)
        local blip = AddBlipForEntity(suspectPed)

        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Suspect")
        EndTextCommandSetBlipName(blip)

        blips[suspectId] = blip
    end
end)

RegisterNetEvent('fivem-lobby:removeAllBlips')
AddEventHandler('fivem-lobby:removeAllBlips', function()
    print('remove all blips called')
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}
end)

function setTimeAndFreeze()
    local hour, minute = 0, 0

    SetClockTime(hour, minute, 0)

    NetworkOverrideClockTime(hour, minute, 0)

    PauseClock(true)
end

setTimeAndFreeze()