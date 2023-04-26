LobbyHandler = {}

local lobbies = {}
local maxPlayersPerLobby = 20

local lobbyStatus = {
    OPEN = 1,
    FULL = 2,
    IN_PROGRESS = 3
}

LobbyHandler.lobbyStatus = lobbyStatus

function LobbyHandler.createLobby()
    local lobby = {
        players = {},
        countdown = 0,
        status = lobbyStatus.OPEN,
        canGiveWeapons = false
    }
    table.insert(lobbies, lobby)
    return #lobbies
end

function LobbyHandler.getLobbies()
    return lobbies
end

function LobbyHandler.lobbyExists(lobbyId)
    return lobbies[lobbyId] ~= nil
end

function LobbyHandler.getLobbyPlayerCount(lobbyId)
    if LobbyHandler.lobbyExists(lobbyId) then
        return #lobbies[lobbyId].players
    else
        return 0
    end
end

function LobbyHandler.findAvailableLobby()
    for i, lobby in ipairs(lobbies) do
        if lobby.status == lobbyStatus.OPEN and #lobby.players < maxPlayersPerLobby then
            return i
        end
    end
    return nil
end

function LobbyHandler.startRoundIfNeeded(lobbyId)
    if LobbyHandler.getLobbyPlayerCount(lobbyId) >= 2 and LobbyHandler.getLobbyStatus(lobbyId) == lobbyStatus.OPEN then
        local countdown = 10
        LobbyHandler.startCountdown(lobbyId, countdown)

        local players = LobbyHandler.getPlayers(lobbyId)
        for _, playerId in ipairs(players) do
            TriggerClientEvent('fivem-lobby:startCountdown', playerId, countdown)
        end

        local roundTimer

        SetTimeout(countdown * 1000, function()
            if LobbyHandler.getLobbyPlayerCount(lobbyId) >= 2 then
                -- Current round

                lobbies[lobbyId].roundCounter = (lobbies[lobbyId].roundCounter or 0) + 1
                local currentRound = lobbies[lobbyId].roundCounter

                local currentPlayers = LobbyHandler.getPlayers(lobbyId)
                LobbyHandler.assignTeams(lobbyId)

                LobbyHandler.giveWeaponsToPlayers(lobbyId)

                SetTimeout(500, function()
                    LobbyHandler.sendTeamMessage(lobbyId, "both", "The round is starting now!")
                    LobbyHandler.sendTeamMessage(lobbyId, "suspects", "You are a suspect, evade until the time runs out or kill all of the cops!")
                    LobbyHandler.sendTeamMessage(lobbyId, "cops", "You are a cop! Catch all of the suspects.")
                end)

                LobbyHandler.updateLobbyStatus(lobbyId, LobbyHandler.lobbyStatus.IN_PROGRESS)

                for _, playerId in ipairs(currentPlayers) do
                    TriggerClientEvent('fivem-lobby:startRound', playerId)
                end

                roundTimer = SetTimeout((5 * 60 * 1000), function()
                    if lobbies[lobbyId].roundCounter == currentRound then
                        LobbyHandler.endRound(lobbyId)
                    end
                end)

                lobbies[lobbyId].roundTimerId = roundTimer
            else
                local currentPlayers = LobbyHandler.getPlayers(lobbyId)

                if LobbyHandler.lobbyExists(lobbyId) then
                    LobbyHandler.cancelCountdown(lobbyId)
                else
                    return 0
                end

                print("Not enough players, cancelling countdown")

                for _, playerId in ipairs(currentPlayers) do
                    TriggerClientEvent('fivem-lobby:cancelCountdown', playerId)

                    TriggerClientEvent('chat:addMessage', playerId, {
                        color = {255, 0, 0},
                        multiline = true,
                        args = { "Lobby System", "There are not enough players to start the round." }
                    })
                end
            end
        end)
    end
end

function LobbyHandler.endRound(lobbyId)
    local mainSpawn = { x = 441, y = -982, z = 30, rot = 0 }

    if LobbyHandler.lobbyExists(lobbyId) then
        print("Ending round for lobbyId: ", lobbyId)
        LobbyHandler.cancelRoundTimer(lobbyId)
        LobbyHandler.cancelCountdown(lobbyId)

        local winningTeam = LobbyHandler.determineWinners(lobbyId)
        local winningMessage = "The " .. winningTeam .. " have won the round!"

        local currentPlayers = LobbyHandler.getPlayers(lobbyId)
        for _, playerId in ipairs(currentPlayers) do
            TriggerClientEvent('chat:addMessage', playerId, {
                color = {255, 255, 0},
                multiline = true,
                args = { "Lobby", winningMessage }
            })

            TriggerClientEvent('fivem-lobby:spawnPlayerAtLocation', playerId, mainSpawn, "spectator")
            TriggerClientEvent('fivem-lobby:clientRemoveAllWeapons', playerId)

            TriggerClientEvent('fivem-lobby:removeAllBlips', playerId)
        end

        LobbyHandler.updateLobbyStatus(lobbyId, LobbyHandler.lobbyStatus.OPEN)
        LobbyHandler.setLobbyOpenIfEmpty(lobbyId)
        
        lobbies[lobbyId].canGiveWeapons = false
        
        if LobbyHandler.lobbyExists(lobbyId) then
            LobbyHandler.startRoundIfNeeded(lobbyId)
        end
    end
end

function LobbyHandler.handlePlayerDeath(lobbyId, playerId)
    if not LobbyHandler.lobbyExists(lobbyId) then
        return
    end

    local playerName = GetPlayerName(playerId)

    LobbyHandler.sendTeamMessage(lobbyId, "both", playerName .. " has died.")
    LobbyHandler.removePlayerFromTeam(lobbyId, playerId)

    local teams = lobbies[lobbyId].teams

    if #teams.suspects == 0 or #teams.cops == 0 then
        LobbyHandler.endRound(lobbyId)
    end
end

function LobbyHandler.cancelRoundTimer(lobbyId)
    if LobbyHandler.lobbyExists(lobbyId) and lobbies[lobbyId].roundTimerId ~= nil then
        ClearTimeout(lobbies[lobbyId].roundTimerId)
        lobbies[lobbyId].roundTimerId = nil
        print('clearing timer ' .. lobbies[lobbyId].roundTimerId)
    end
end

function LobbyHandler.giveWeaponsToPlayers(lobbyId)
    Citizen.CreateThread(function()
        Citizen.Wait(30000)

        lobbies[lobbyId].canGiveWeapons = true

        local players = LobbyHandler.getPlayers(lobbyId)
        for _, playerId in ipairs(players) do
            local ped = GetPlayerPed(playerId)

            if lobbies[lobbyId].canGiveWeapons then
                local pistolHash = GetHashKey("WEAPON_PISTOL")
                GiveWeaponToPed(ped, pistolHash, 250, false, true)

                local assaultRifleHash = GetHashKey("WEAPON_ASSAULTRIFLE")
                GiveWeaponToPed(ped, assaultRifleHash, 500, false, false)
            end
        end
    end)
end

function LobbyHandler.setLobbyOpenIfEmpty(lobbyId)
    if #lobbies[lobbyId].players == 0 then
        lobbies[lobbyId].status = lobbyStatus.OPEN
    end
end

function LobbyHandler.findPlayerLobby(playerId)
    print('findPlayerLobby called ' .. playerId)
    for i, lobby in ipairs(lobbies) do
        print('Checking lobby: ' .. i)
        for _, player in ipairs(lobby.players) do
            print('Player in lobby ' .. i .. ': ' .. player)
            if player == playerId then
                print('Player found in lobby: ' .. i .. " | Player ID: " .. playerId)
                return i
            end
        end
    end
    return nil
end

function LobbyHandler.isFirstLobby(lobbyId)
    return lobbyId == 1
end

function LobbyHandler.isLobbyFull(lobbyId)
    return #lobbies[lobbyId].players >= maxPlayersPerLobby
end

function LobbyHandler.getLobbyStatus(lobbyId)
    return lobbies[lobbyId].status
end

function LobbyHandler.addPlayer(lobbyId, playerId)
    table.insert(lobbies[lobbyId].players, playerId)
    SetPlayerRoutingBucket(playerId, lobbyId)

    if lobbies[lobbyId].status == lobbyStatus.OPEN and lobbies[lobbyId].countdown == 0 then
        LobbyHandler.startRoundIfNeeded(lobbyId)
    end
end

function LobbyHandler.startCountdown(lobbyId, count)
    lobbies[lobbyId].countdown = count
end

function LobbyHandler.getCountdown(lobbyId)
    return lobbies[lobbyId].countdown
end

function LobbyHandler.cancelCountdown(lobbyId)
    if LobbyHandler.lobbyExists(lobbyId) then
        lobbies[lobbyId].countdown = 0
    else
        print("Lobby doesn't exist.")
    end
end

function LobbyHandler.updateLobbyStatus(lobbyId, status)
    lobbies[lobbyId].status = status
end

function LobbyHandler.removePlayer(lobbyId, playerId)
    local lobbyCoordinates = { x = 441, y = -982, z = 30, rot = 0 }

    for i, player in ipairs(lobbies[lobbyId].players) do

        if player == playerId then
            table.remove(lobbies[lobbyId].players, i)
            TriggerClientEvent('fivem-lobby:cancelCountdown', i)

            if lobbies[lobbyId].status == LobbyHandler.lobbyStatus.IN_PROGRESS then
                TriggerClientEvent('fivem-lobby:spawnPlayerAtLocation', playerId, lobbyCoordinates, "spectator")
                TriggerClientEvent('fivem-lobby:clientRemoveAllWeapons', playerId)

                LobbyHandler.removePlayerFromTeam(lobbyId, playerId)

                -- Cancel the round if there are not enough players.
                if LobbyHandler.getLobbyPlayerCount(lobbyId) < 2 then
                    LobbyHandler.updateLobbyStatus(lobbyId, LobbyHandler.lobbyStatus.OPEN)
                    lobbies[lobbyId].countdown = 0
                    LobbyHandler.cancelRoundTimer(lobbyId)
                    LobbyHandler.endRound(lobbyId)

                    local remainingPlayers = LobbyHandler.getPlayers(lobbyId)

                    for _, remainingPlayerId in ipairs(remainingPlayers) do
                        TriggerClientEvent('fivem-lobby:cancelRound', remainingPlayerId)

                        TriggerClientEvent('chat:addMessage', remainingPlayerId, {
                            color = {255, 0, 0},
                            multiline = true,
                            args = { "Lobby System", "Not enough players, round ended." }
                        })
                    end
                end
            end

            break
        end
    end
end

function LobbyHandler.deleteLobby(lobbyId)
    if LobbyHandler.lobbyExists(lobbyId) then
        table.remove(lobbies, lobbyId)
    else
        print("Lobby does not exist: ", lobbyId)
    end
end

function LobbyHandler.getPlayers(lobbyId)
    if LobbyHandler.lobbyExists(lobbyId) then
        return lobbies[lobbyId].players
    else
        print("Lobby does not exist: ", lobbyId)
        return {}
    end
end

function LobbyHandler.sendTeamMessage(lobbyId, messageType, message)
    local teams = lobbies[lobbyId].teams

    if messageType == "suspects" or messageType == "both" then
        for _, suspectId in ipairs(teams.suspects) do
            TriggerClientEvent('chat:addMessage', suspectId, {
                color = {255, 0, 0},
                multiline = true,
                args = { "[Suspect] " .. message }
            })
        end
    end

    if messageType == "cops" or messageType == "both" then
        for _, copId in ipairs(teams.cops) do
            TriggerClientEvent('chat:addMessage', copId, {
                color = {51, 153, 255},
                multiline = true,
                args = { "[Cop] " .. message }
            })
        end
    end
end

function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

function LobbyHandler.assignTeams(lobbyId)
    getRandomSpawnLocations(function(spawnLocations)
        if not spawnLocations then
            print("No spawn locations found")
            return
        end

        local players = lobbies[lobbyId].players
        local totalPlayers = #players
        local suspects = math.max(1, math.floor((totalPlayers - 1) / 4))
        local cops = totalPlayers - suspects

        local shuffledPlayers = {}

        for _, player in ipairs(players) do
            table.insert(shuffledPlayers, {id = player, team = nil})
        end

        math.randomseed(os.time())

        shuffle(shuffledPlayers) 

        for i = 1, suspects do
            local index = math.random(1, #shuffledPlayers)
            shuffledPlayers[index].team = "suspect"
        end

        for _, player in ipairs(shuffledPlayers) do
            if player.team == nil then
                player.team = "cop"
            end
        end

        lobbies[lobbyId].teams = {
            suspects = {},
            cops = {}
        }

        for _, player in ipairs(shuffledPlayers) do
            if player.team == "suspect" then
                table.insert(lobbies[lobbyId].teams.suspects, player.id)
            else
                table.insert(lobbies[lobbyId].teams.cops, player.id)
            end

            print('triggering custom damages')
            TriggerClientEvent('CustomDamages:assignTeams', player.id, lobbies[lobbyId].teams)

            local spawnLocation
            if player.team == "suspect" then
                spawnLocation = getRandomLocationForTeam(spawnLocations, "suspect")
            else
                spawnLocation = getRandomLocationForTeam(spawnLocations, "cop")
            end

            if spawnLocation then
                TriggerClientEvent('fivem-lobby:spawnPlayerAtLocation', player.id, spawnLocation, player.team)
            end

            local suspects = lobbies[lobbyId].teams.suspects
            local cops = lobbies[lobbyId].teams.cops

            if player.team == "cop" then
                Citizen.CreateThread(function()
                    Wait(3000)
                    for _, suspectId in ipairs(suspects) do
                        print("trigger createBlipForCop")
                        TriggerClientEvent('fivem-lobby:createBlipForCop', player.id, suspectId)
                    end
                end)
            end
        end
    end)
end

function LobbyHandler.getPlayerTeam(lobbyId, playerId)
    local lobby = lobbies[lobbyId]
    print('getPlayerTeam ', lobbyId)
    print('playerId:', playerId)
    if not lobby then
        return nil
    end

    for _, suspectId in ipairs(lobby.teams.suspects) do
        if suspectId == playerId then
            return "suspect"
        end
    end

    for _, copId in ipairs(lobby.teams.cops) do
        if copId == playerId then
            return "cop"
        end
    end

    return nil
end

function LobbyHandler.removePlayerFromTeam(lobbyId, playerId)
    local teams = lobbies[lobbyId].teams

    for i, suspectId in ipairs(teams.suspects) do
        if suspectId == playerId then
            table.remove(teams.suspects, i)
            return
        end
    end

    for i, copId in ipairs(teams.cops) do
        if copId == playerId then
            table.remove(teams.cops, i)
            return
        end
    end
end

function LobbyHandler.determineWinners(lobbyId)
    local teams = lobbies[lobbyId].teams

    if #teams.suspects > 0 then
        return "suspects"
    else
        return "cops"
    end
end

-- Get the spawns from the database.

function getRandomSpawnLocations(cb)
    MySQL.Async.fetchAll("SELECT * FROM roundspawns ORDER BY RAND() LIMIT 1", {}, function(rows)
        if #rows > 0 then
            local row = rows[1]
            local coordinates = json.decode(row.coordinates)
            cb(coordinates)
        else
            print("No rows found")
            cb(nil)
        end
    end)
end

function getRandomLocationForTeam(spawnLocations, team)
    local teamLocations = {}

    for _, location in ipairs(spawnLocations) do
        if location.team == team then
            table.insert(teamLocations, location)
        end
    end

    if #teamLocations == 0 then
        return nil
    end

    local randomIndex = math.random(1, #teamLocations)
    return teamLocations[randomIndex]
end

exports("getPlayerTeam", function(lobbyId, playerId)
    print('getPlayerTeam - lobbyhandler')
    return LobbyHandler.getPlayerTeam(lobbyId, playerId)
end)

exports("findPlayerLobby", function(playerId)
    print('findPlayerLobby - lobbyhandler')
    return LobbyHandler.findPlayerLobby(playerId)
end)

exports('LobbyHandler', function() return LobbyHandler end)

return LobbyHandler