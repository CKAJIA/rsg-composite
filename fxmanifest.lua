fx_version "adamant"
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."
games {"rdr3"}

author '@CKAJIA'
description 'Herbs and Eggs'
version '1.0.0'

shared_scripts {
	'@ox_lib/init.lua',
    "exports.js",
    'config.lua',
}

client_scripts {
	'client/client.lua',
	'client/utilites.lua',
	'client/deletedherbs.lua',
	'client/dataview.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua',
    'server/versionchecker.lua'
}

exports {
    'NativeCreateComposite',
    'NativeGetCompositeEntities',
	'StartCreateComposite',
	'FindPicupCompositeAndCoords'
}

dependencies {
    'rsg-core',
    'ox_lib',
}

lua54 'yes'