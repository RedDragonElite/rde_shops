fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'RDE Advanced Shop System V1.0.0 - Boss Edition'
author      'RDE Development | Claude AI'
description 'Ultra-realistic shop system with fixed ox_inventory UI, StateBag sync, robbery & NPC mechanics'
version     '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'ox_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}

--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║           🔥 V1.0.0 — ALPHA (ALL BUGS FIXED)                     ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  🔴 CRITICAL FIXES                                               ║
    ║  ✅ FIX: Shop inventory öffnet sich jetzt KORREKT                ║
    ║     → forceOpenInventory → OpenInventory (korrektes API)         ║
    ║     → Stable shop IDs statt Timestamp-Spam                       ║
    ║     → RegisterShop bei Startup, nicht bei jedem Klick            ║
    ║     → Stock depletes beim Kauf (RemoveItem aus Stash)            ║
    ║  ✅ FIX: checkAdminPermission Callback existiert jetzt           ║
    ║     → Admin-Permission auf Init-Check war immer false!           ║
    ║  ✅ FIX: getTillMoney Callback existiert jetzt                   ║
    ║     → Till-Check war komplett broken                             ║
    ║  ✅ FIX: checkRobbery Callback existiert jetzt                   ║
    ║     → Robbery war komplett broken                                ║
    ║  ✅ FIX: completeRobbery gibt Payout korrekt zurück              ║
    ║  ✅ FIX: Config.Robbery.pedAnimDict/pedAnimName definiert        ║
    ║     → Client referenzierte undefined Config-Felder               ║
    ║                                                                  ║
    ║  🟡 MEDIUM FIXES                                                 ║
    ║  ✅ FIX: itemInfo.client?.image → Lua-konforme Syntax            ║
    ║  ✅ FIX: Police Alert sendet jetzt korrektes table Format        ║
    ║  ✅ FIX: #shops auf sparse table → tableCount()                  ║
    ║  ✅ FIX: Memory Leak bei RegisterShop eliminiert                 ║
    ║  ✅ FIX: SetModelAsNoLongerNeeded nach Ped-Spawn                 ║
    ║                                                                  ║
    ║  ✨ IMPROVEMENTS                                                 ║
    ║  ✅ refreshOxShop(): Live-Update nach Preisänderung              ║
    ║  ✅ StateBag Listener für late-join Spieler                      ║
    ║  ✅ Stock depletes in Echtzeit beim Kauf                         ║
    ║  ✅ ox:playerSpawned permission cache reset                      ║
    ║  ✅ Particle effect timeout guard                                ║
    ║  ✅ Robbery: NPC hebt Hände hoch während Timer läuft             ║
    ║  ✅ Analytics zeigt jetzt auch Till-Kontostand                   ║
    ║  ✅ Config.Shops.ped timing: 20s cleanup, 60s respawn            ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝

]]
