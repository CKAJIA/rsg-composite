fx_version "adamant"
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."
games {"rdr3"}

author '@CKAJIA'
description 'Herbs and Eggs (separate plant and egg spawning)'
version '2.0.0'

shared_scripts {
	'@ox_lib/init.lua',
    "exports.js",
    'config.lua',
    'config_tree_eggs.lua',
}

client_scripts {
	'client/dataview.lua',
	'client/client.lua',
	'client/utilites.lua',
	'client/tree_eggs.lua',
	'client/deletedherbs.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua'
}

exports {
    'NativeCreateComposite',
	'NativeGetGroundZFor3dCoord',
	'StartCreateComposite',
	'FindPicupCompositeAndCoords'
}

dependencies {
    'rsg-core',
    'ox_lib',
}

lua54 'yes'
