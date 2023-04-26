fx_version 'bodacious'
games { 'gta5' }

author 'Bagz'
description 'A Lobby system for FiveM.'
version '1.0.0'

client_script {
    'client.lua'
}

server_script {
    '@mysql-async/lib/MySQL.lua',
    'server.lua',
    'lobby_handler.lua'
}

server_exports {
    'LobbyHandler',
    'findPlayerLobby',
    'getPlayerTeam'
}

shared_script 'shared.lua'