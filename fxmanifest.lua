fx_version 'cerulean'
game 'gta5'

lua54 'yes'  -- Enable Lua 5.4

author 'deoyx'
description 'Police Impound System'
version '1.0.0'

shared_script '@ox_lib/init.lua'  -- Ensure this line is present
client_script 'client.lua'
server_script 'server.lua'
