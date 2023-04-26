local playersInLobby = {}
local lobbyCountdown = 10
local firstSpawn = {}

function addAllOnlinePlayersToLobbies()
    local onlinePlayers = GetPlayers()
    for _, playerId in ipairs(onlinePlayers) do
        local lobbyId = LobbyHandler.findAvailableLobby()

        if not lobbyId then
            lobbyId = LobbyHandler.createLobby()
        end

        if not LobbyHandler.isLobbyFull(lobbyId) then
            LobbyHandler.addPlayer(lobbyId, tonumber(playerId))
        else
            TriggerClientEvent('chat:addMessage', tonumber(playerId), {
                color = {255, 0, 0},
                multiline = true,
                args = {"Lobby System", "The lobby is full."}
            })
        end
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        addAllOnlinePlayersToLobbies()
        SetRoutingBucketPopulationEnabled(0, false)
        local lobbyId = LobbyHandler.findAvailableLobby()
        if not lobbyId then
            lobbyId = LobbyHandler.createLobby()
        end
    end
end)

-- AddEventHandler('playerConnecting', function(source, oldId)
--     local _source = source
--     local lobbyId = LobbyHandler.findAvailableLobby()

--     if not lobbyId then
--         lobbyId = LobbyHandler.createLobby()
--         SetRoutingBucketPopulationEnabled(lobbyId, false)
--     end

--     LobbyHandler.addPlayer(lobbyId, _source)
--     TriggerClientEvent('fivem-lobby:playerAddedToLobby', _source, lobbyId)

--     LobbyHandler.startRoundIfNeeded(lobbyId)
-- end)

AddEventHandler('playerSpawned', function(spawnInfo)
    local _source = source
    if not firstSpawn[_source] then
        firstSpawn[_source] = true
        local lobbyId = LobbyHandler.findAvailableLobby()

        if not lobbyId then
            lobbyId = LobbyHandler.createLobby()
            SetRoutingBucketPopulationEnabled(lobbyId, false)
        end

        LobbyHandler.addPlayer(lobbyId, _source)
        TriggerClientEvent('fivem-lobby:playerAddedToLobby', _source, lobbyId)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local _source = source
    local lobbyId = LobbyHandler.findPlayerLobby(_source)

    print(_source .. ' disconnected because ' .. reason)

    if lobbyId then
        LobbyHandler.removePlayer(lobbyId, _source)
    end
end)

RegisterNetEvent('server:onPlayerDied')
AddEventHandler('server:onPlayerDied', function(killerType, coords)
    local _source = source
    local lobbyId = LobbyHandler.findPlayerLobby(_source)

    if lobbyId and LobbyHandler.getLobbyStatus(lobbyId) == LobbyHandler.lobbyStatus.IN_PROGRESS then
        LobbyHandler.handlePlayerDeath(lobbyId, _source)
    end
end)

RegisterCommand('lobbies', function(source, args, rawCommand)
    local _source = source
    local lobbies = LobbyHandler.getLobbies()

    local lobbyInfo = {}
    for i, lobby in ipairs(lobbies) do
        table.insert(lobbyInfo, {
            id = i,
            playerCount = #lobby.players
        })
    end

    TriggerClientEvent('fivem-lobby:displayLobbies', _source, lobbyInfo)
end, false)

RegisterCommand('leavelobby', function(source, args, rawCommand)
    local _source = source
    local lobbyId = LobbyHandler.findPlayerLobby(_source)

    if lobbyId then

        LobbyHandler.removePlayer(lobbyId, _source)

        if LobbyHandler.getLobbyPlayerCount(lobbyId) == 0 and not LobbyHandler.isFirstLobby(lobbyId) then
            LobbyHandler.deleteLobby(lobbyId)
        else
            LobbyHandler.setLobbyOpenIfEmpty(lobbyId)
        end

        TriggerClientEvent('chat:addMessage', _source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"Lobby System", "You have left the lobby."}
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"Lobby System", "You are not in any lobby."}
        })
    end
end, false)

RegisterCommand('joinlobby', function(source, args, rawCommand)
    local _source = source
    local lobbyId = tonumber(args[1])

    if lobbyId and LobbyHandler.lobbyExists(lobbyId) then
        if LobbyHandler.getLobbyStatus(lobbyId) == LobbyHandler.lobbyStatus.OPEN then
            local currentLobbyId = LobbyHandler.findPlayerLobby(_source)
            if currentLobbyId then
                LobbyHandler.removePlayer(currentLobbyId, _source)
                if LobbyHandler.getPlayers(currentLobbyId) == 0 and not LobbyHandler.isFirstLobby(currentLobbyId) then
                    LobbyHandler.deleteLobby(currentLobbyId)
                else
                    LobbyHandler.setLobbyOpenIfEmpty(currentLobbyId)
                end
            end
            LobbyHandler.addPlayer(lobbyId, _source)
            TriggerClientEvent('chat:addMessage', _source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"Lobby System", "You have joined Lobby ID: " .. lobbyId}
            })
        else
            TriggerClientEvent('chat:addMessage', _source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"Lobby System", "The lobby is full."}
            })
        end
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"Lobby System", "Invalid lobby ID."}
        })
    end
end, false)