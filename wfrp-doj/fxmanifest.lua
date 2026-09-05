fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'wfrp @rick'
description 'DOJ Duty & Courtroom Tools for VORP'
version '1.1.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/sounds/*.mp3',
    'ui/sounds/*.ogg',
    'ui/sounds/*.wav'
}

shared_scripts {
    'config.lua',
    'locales/en.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/duty.lua',
    'client/hud.lua',
    'client/courtroom.lua',
    'client/nui.lua',
    'client/lawyer.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/webhooks.lua',
    'server/lawyer.lua'
}

dependencies {
    'vorp_core',
    'oxmysql'
}
