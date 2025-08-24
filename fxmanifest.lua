fx_version 'cerulean'
game 'gta5'

author 'qwezert'
description 'qbx_fight'
repository ''
version '0.0.1'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

ox_lib 'locale'

shared_script '@ox_lib/init.lua'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    '@qbx_core/modules/lib.lua',
    'client/utils.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'locales/*.json',
    'config/*.lua',
    'client/**/*.lua',
    'carcols_gen9.meta',
    'carmodcols_gen9.meta',
}

