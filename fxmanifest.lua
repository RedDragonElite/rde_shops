fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'RDE Advanced Shop System V2.0.0'
author      'RDE Development | rd-elite.com'
description 'Ultra-realistic shop system — ox_core + ox_inventory + ox_target + Shop Templates + Debounced Refresh'
version     '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'config.lua',
    'data/shop_templates.lua'   -- Shop Templates (client + server)
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
    ╔══════════════════════════════════════════════════════════════════════╗
    ║          🔥 V4.8.0 — CUSTOMER BUY FIX                                ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║                                                                      ║
    ║  🔴 CRITICAL FIX                                                     ║
    ║  ✅ FIX: "You can not open this inventory" beim Einkaufen            ║
    ║     Root cause: ox_inventory:openInventory('shop', data) expects     ║
    ║     `data` to be a TABLE with `.type` field, NOT a raw string.       ║
    ║     The previous fix #2 in v4.7 changed the call from                ║
    ║     `{ type = oxShopId }` to a bare string, which made               ║
    ║     ox_inventory's server callback fail silently (Shops[nil] = nil). ║
    ║     This broke ALL customer purchases while admin "Drag & Drop       ║
    ║     Stock" kept working because stash uses a different API.          ║
    ║                                                                      ║
    ║  Bonus improvements:                                                  ║
    ║  ✅ Added `locations` array to RegisterShop call. This gives us:     ║
    ║     • shop.id format "rde_shop_N 1" → enables pattern matching       ║
    ║       in buyItem hook (shopType/shopId parsing)                      ║
    ║     • Optional 10m distance check by ox_inventory itself             ║
    ║     • Aligns with overextended's documented shop registration format ║
    ║                                                                      ║
    ║  Zero database changes. Zero config changes. Pure code fix.          ║
    ║                                                                      ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║          🔥 V4.7.0 — FULL OX STACK EDITION (PREVIOUS RELEASE)        ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║                                                                      ║
    ║  🔴 CRITICAL FIXES                                                   ║
    ║  ✅ FIX: Ped schwimmt in der Luft                                    ║
    ║     → z - 1.0 Offset entfernt                                        ║
    ║     → PlaceObjectOnGroundProperly() nach Spawn                       ║
    ║     → Scenario VOR FreezeEntityPosition starten                      ║
    ║     → Wait(200) nach CreatePed für Physics-Settling                  ║
    ║  ✅ FIX: player.addMoney() existiert nicht in ox_core                ║
    ║     → player.getAccount().addBalance({amount=X}) korrekt             ║
    ║  ✅ FIX: targetPlayer.get('job') ist ESX-Pattern                     ║
    ║     → Ersetzt durch player.getGroups() + policeJobs-Check            ║
    ║     → Cops-Nearby funktioniert jetzt korrekt                         ║
    ║  ✅ FIX: AddEventHandler('ox_inventory:buyItem') → registerHook      ║
    ║     → Korrekte buyItem Hook-API mit inventoryFilter                  ║
    ║  ⚠️  REGRESSION (fixed in v4.8): openInventory shop arg → string     ║
    ║                                                                      ║
    ║  ✨ ENHANCEMENTS                                                     ║
    ║  ✅ NEW: ox_inventory Drag & Drop für Admin Stock                     ║
    ║     → Stash pro Shop registriert                                     ║
    ║     → swapItems Hook synct DB automatisch bei Drag-In                ║
    ║     → Preis-Dialog beim ersten Drag-In                               ║
    ║  ✅ NEW: rde_aipd Integration                                        ║
    ║     → LogCrime('ROBBERY') bei Robbery Start (Client)                 ║
    ║     → police:nostr:crime Event bei Robbery Complete (Server)         ║
    ║     → Wanted Level Sync via rde_aipd wenn aktiv                      ║
    ║  ✅ IMPROVED: Robbery System komplett überarbeitet                   ║
    ║     → Realistischere Phasen: Einschüchterung → Countdown → Beute     ║
    ║     → Clerk-Reaktion (Hands Up / Fight Back) verbessert              ║
    ║     → Flee-Detection korrekt (Blick weg = Abbruch)                   ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
]]
