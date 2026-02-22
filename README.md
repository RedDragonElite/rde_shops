# 🏪 RDE Advanced Shop System — V1.0.0 Alpha
![photo_2026-02-22_03-19-31](https://github.com/user-attachments/assets/d6b99ba5-4500-4787-910a-8af4cb35fc89)

[![Version](https://img.shields.io/badge/version-1.0.0-red?style=for-the-badge&logo=github)](https://github.com/RedDragonElite)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)](https://github.com/communityox/ox_core)
[![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite)

**The most complete, production-grade shop system for FiveM.**  
Real-time ox_inventory UI, StateBag sync, dynamic reputation, a fully scripted robbery system with NPC reactions, passive income, analytics, and admin tools — all fully fixed and battle-tested.

Built on ox_core · ox_lib · ox_inventory · ox_target · oxmysql

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte*

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Configuration](#️-configuration)
- [Shop Categories](#-shop-categories)
- [Robbery System](#-robbery-system)
- [Reputation System](#-reputation-system)
- [Analytics](#-analytics)
- [Admin System](#️-admin-system)
- [Commands](#-commands)
- [Database](#️-database)
- [Localization](#-localization)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)
- [License](#-license)

---

## 🎯 Overview

**RDE Advanced Shop System V1.0.0** is a fully dynamic, in-world shop framework for FiveM servers. Admins can create, edit, and delete shops entirely in-game — no config restarts, no hardcoded locations. Every shop gets its own ox_inventory stash, a spawned NPC clerk, a map blip, and a full set of mechanics including till money, passive income, stock restock, robbery detection, police alerts, and a per-player reputation system.

This is the **Alpha release** — functional and tested, but feedback is welcome.

### Why RDE Shop System?

| Feature | Typical Shop Scripts | RDE Advanced Shop System |
| --- | --- | --- |
| Dynamic in-game shop creation | ❌ | ✅ Full CRUD in-game |
| ox_inventory UI integration | ❌ or broken | ✅ Fixed & stable |
| StateBag real-time sync | Polling | ✅ Instant |
| Robbery system w/ NPC reactions | ❌ | ✅ Hands up, fight back, die |
| Passive till income | ❌ | ✅ Configurable NPC customers |
| Per-player reputation | ❌ | ✅ Affects item prices |
| Auto stock restock | ❌ | ✅ Interval-based |
| Shop analytics | ❌ | ✅ Revenue, purchases, robberies |
| Police alert on robbery | ❌ | ✅ Dispatch + wanted level |
| Multi-language support | ❌ | ✅ EN + DE built-in |

---

## ✨ Features

### 🏪 Shop System

- Create, edit, and delete shops fully in-game via ox_lib UI
- Every shop has its own ox_inventory stash with configurable slots and max weight
- Spawned NPC clerks with selectable ped models, invincibility, freeze, and scenario settings
- Map blips with configurable sprite, color, name, and short-range display
- 7 built-in shop categories (General, Weapons, Clothing, Liquor, Electronics, Pharmacy, Custom) each with unique blip defaults and reputation multipliers
- Live price updates via `refreshOxShop()` after admin edits

### 💰 Till & Passive Income

- A percentage of every purchase flows into the shop's cash register (`moneyAccumulationRate`)
- Configurable max till balance
- Passive income simulates NPC customers even when no players are buying — keeps tills lively
- Admins can check and empty the till in-game
- Particle effects on till interaction

### 📦 Stock & Restock

- Stock depletes in real-time when players purchase items (removed from ox_inventory stash)
- Automatic restock on a configurable interval with min/max amounts per item and a hard cap per item

### 🎭 Reputation System

- Each player has a per-shop reputation score (range: -50 to 100)
- Reputation increases on every purchase and decreases on robbery
- Reputation directly affects item prices — loyal customers get discounts, known criminals pay a premium
- Reputation multipliers scale with shop category

### 📊 Analytics

- Per-shop tracking of total revenue, total purchases, total robberies, and average transaction value
- Till balance included in analytics view
- Configurable history retention period (days)

### 🛡️ Security & Permissions

- ACE permissions + ox_core group-based admin system
- Admin groups fully configurable: god, owner, admin, superadmin, moderator, mod, staff
- ACE fallback: `rde_shop.admin`, `rde_orgs.admin`, `command`
- Permission cache reset on player spawn

---

## 🔫 Robbery System

The most feature-rich part of the script. Every shop can be robbed — here's what happens:

**Trigger:** Player aims a qualifying weapon at the NPC clerk for `aimTime` seconds while a robbery isn't on cooldown.

**NPC Reactions:**
- 95% chance the clerk raises their hands and freezes during the timer
- 5% chance the clerk pulls a weapon and fights back
- If the player kills the clerk, the clerk drops money and eventually respawns
- NPC won't flee — they hold their ground or raise their hands

**Payout:** Scales with the till balance. Money is removed from the till on success.

**Police Alert:**
- Sends a dispatch alert to configured police jobs (`police`, `sheriff`, `state`)
- Sets the player's wanted level
- Progressive difficulty: more cops nearby = longer aim time + higher fight-back chance

**Cooldown:** Configurable per-shop cooldown after a successful robbery.

**Weapon List (configurable):**

```
WEAPON_PISTOL, WEAPON_PISTOL50, WEAPON_COMBATPISTOL, WEAPON_APPISTOL,
WEAPON_ASSAULTRIFLE, WEAPON_CARBINERIFLE, WEAPON_ADVANCEDRIFLE,
WEAPON_SMG, WEAPON_MICROSMG, WEAPON_PUMPSHOTGUN, WEAPON_SAWNOFFSHOTGUN,
WEAPON_KNIFE, WEAPON_MACHETE, WEAPON_BAT
```

---

## 📦 Dependencies

| Resource | Required | Notes |
| --- | --- | --- |
| [oxmysql](https://github.com/communityox/oxmysql) | ✅ Required | Database layer |
| [ox_core](https://github.com/communityox/ox_core) | ✅ Required | Player/character framework |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ Required | UI, callbacks, notifications |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ✅ Required | Shop stash + item UI |
| [ox_target](https://github.com/communityox/ox_target) | ✅ Required | NPC interaction |

---

## 🚀 Installation

### 1. Clone the repository

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_shop.git
```

### 2. Add to `server.cfg`

```
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure rde_shop
```

> **Order matters.** `rde_shop` must start **after** all its dependencies.

### 3. Database

Tables are created automatically on first start. No manual SQL import needed.

### 4. Configure (Optional)

Edit `config.lua` to adjust robbery settings, till rates, restock intervals, reputation thresholds, admin groups, and language.

### 5. Restart & Create Your First Shop

```
restart rde_shop
```

Then in-game, use your admin interaction to open Shop Management and create your first shop.

---

## ⚙️ Configuration

### Core

```lua
Config.DefaultLanguage = 'en'       -- 'en' or 'de'
Config.Debug = false                 -- verbose console logging
Config.TablePrefix = 'rde_'         -- database table prefix

Config.AdminGroups = {
    'god', 'owner', 'admin', 'superadmin', 'moderator', 'mod', 'staff'
}

Config.AcePermissions = {
    'rde_shop.admin',
    'rde_orgs.admin',
    'command'
}
```

### Shop Inventory

```lua
Config.ShopInventory = {
    slots = 100,
    maxWeight = 100000
}
```

### NPC Clerk

```lua
Config.Shops.ped = {
    invincible = false,
    frozen = true,
    blockevents = true,             -- NPC ignores all external events (won't flee)
    scenario = 'WORLD_HUMAN_STAND_MOBILE',
    deadPedCleanupTime = 20000,     -- ms before dead ped is removed
    respawnTime = 60000,            -- ms before ped respawns after death
}
```

### Till & Passive Income

```lua
Config.Shops.till = {
    moneyAccumulationRate = 0.15,   -- 15% of each purchase goes to the till
    maxTillMoney = 5000,
    enableParticles = true,

    passiveIncome = {
        enabled   = true,
        interval  = 300,            -- every 5 minutes
        minAmount = 50,
        maxAmount = 250,
    },
}
```

### Restock

```lua
Config.Shops.restock = {
    enabled   = true,
    interval  = 600,                -- every 10 minutes
    amountMin = 1,
    amountMax = 5,
    maxStock  = 100,
}
```

### Reputation

```lua
Config.Shops.reputation = {
    enabled = true,
    maxRep = 100,
    minRep = -50,
    repGainPerPurchase = 1,
    repLossPerRobbery = 10,
    priceMultiplierMax = 0.9,       -- 10% discount at max rep
    priceMultiplierMin = 1.5,       -- 50% markup at min rep
}
```

### Robbery

```lua
Config.Robbery = {
    enabled = true,
    weaponRequired = true,
    aimTime = 5.0,                  -- seconds to aim before robbery triggers
    cooldown = 600,                 -- seconds between robberies on same shop

    npc = {
        handsUpChance = 0.95,
        fightBackChance = 0.05,
        canBeKilled = true,
        giveMoneyOnDeath = true,
    },

    progressive = {
        enabled = true,
        timeIncreasePerCop = 1.0,
        fightBackChanceIncreasePerCop = 0.02,
    },

    policeNotify = true,
    policeJobs = {'police', 'sheriff', 'state'},
    minPolice = 0,
    dispatchRadius = 300.0,
    wantedLevel = 2,
}
```

### Blip & Map Options

13 blip sprites and 10 blip colors are available to choose from, all configurable in `Config.BlipSprites` and `Config.BlipColors`.

---

## 🏷️ Shop Categories

| Category | Blip | Rep Multiplier | Notes |
| --- | --- | --- | --- |
| 🏪 General Store | Sprite 52, Green | 1.0x | |
| 🔫 Weapon Shop | Sprite 110, Red | 1.5x | High robbery severity |
| 👔 Clothing Store | Sprite 73, Blue | 0.8x | |
| 🍺 Liquor Store | Sprite 93, Yellow | 1.2x | |
| 📱 Electronics | Sprite 521, White | 1.3x | |
| 💊 Pharmacy | Sprite 153, Dark | 1.4x | |
| ⭐ Custom | Sprite 52, Green | 1.0x | |

---

## 🛡️ Admin System

Admin access is verified against ox_core groups listed in `Config.AdminGroups`, with ACE permission fallback.

Admins can:
- Create, edit, and delete any shop
- Manage shop inventory (add/remove items, set prices)
- Check and empty any shop's till
- View full shop analytics
- Get a cached permission refresh on every spawn

```
# server.cfg
add_ace group.admin rde_shop.admin allow
add_principal identifier.steam:110000xxxxxxxx group.admin
```

---

## 📋 Commands

| Command | Who | Description |
| --- | --- | --- |
| `/shop` | Player | Open nearest shop (if in range) |
| `/shopmanage` | Admin | Open shop management menu |

---

## 🗄️ Database

Tables are created automatically on first start. The system uses `Config.TablePrefix` (default `rde_`) for all table names. No manual SQL required.

---

## 🌐 Localization

Built-in English and German support. Switch with `Config.DefaultLanguage = 'en'` or `'de'`.

All locale strings are in `Config.Locales` — add new languages by copying the `en` block and translating.

---

## 🐛 Troubleshooting

**Shop inventory won't open?**  
Make sure `ox_inventory` is fully started before `rde_shop`. The shop stash is registered at startup using stable IDs — check F8 for any export errors.

**Admin permission always returning false?**  
Verify the player's ox_core group matches an entry in `Config.AdminGroups` exactly. Restart the resource after any group changes and confirm `checkAdminPermission` callback is reachable.

**Robbery not triggering?**  
Ensure the player has a qualifying weapon from `Config.Robbery.weaponTypes` equipped and drawn, and that the shop cooldown has expired.

**NPC not spawning / disappearing instantly?**  
Check `Config.Shops.ped.deadPedCleanupTime` and `respawnTime`. Enable `Config.Debug = true` for verbose spawn logs.

**Till always showing $0?**  
The `getTillMoney` callback was broken during development — fixed in V1.0.0. Ensure you're running the current `server.lua`.

**Police alert not sending?**  
Confirm `Config.Robbery.policeNotify = true` and that the jobs listed in `policeJobs` match your server's actual job names.

---

## 📝 Changelog

### V1.0.0 Alpha — Initial Release (Current)

**Critical Fixes:**
- Shop inventory now opens correctly — `forceOpenInventory` → `OpenInventory` (correct ox_inventory API)
- Stable shop IDs replace timestamp spam — shops register at startup, not on every click
- Stock now depletes on purchase (RemoveItem from stash)
- `checkAdminPermission` callback now exists — was always returning false
- `getTillMoney` callback now exists — till check was completely broken
- `checkRobbery` callback now exists — robbery was completely broken
- `completeRobbery` now returns payout correctly
- `Config.Robbery.pedAnimDict` / `pedAnimName` defined — client was referencing undefined config fields

**Medium Fixes:**
- `itemInfo.client?.image` → Lua-compliant syntax
- Police alert now sends correct table format
- `#shops` on sparse table → `tableCount()`
- Memory leak on `RegisterShop` eliminated
- `SetModelAsNoLongerNeeded` called after ped spawn

**Improvements:**
- `refreshOxShop()`: live price update after admin edits
- StateBag listener for late-join players
- Stock depletes in real-time on purchase
- `ox:playerSpawned` permission cache reset
- Particle effect timeout guard
- NPC raises hands during robbery timer
- Analytics now shows till balance
- Ped cleanup: 20s after death, 60s respawn

### V0.x — Pre-Release

- Development & internal testing

---

## 📜 License

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE ADVANCED SHOP SYSTEM V1.0.0 ALPHA                               #
#   ARCHITECT:  .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com     #
#   ORIGIN:     https://github.com/RedDragonElite                                 #
#                                                                                 #
#   WARNING: THIS CODE IS PROTECTED BY DIGITAL VOODOO AND PURE HATRED FOR LEAKERS #
#                                                                                 #
#   [ THE RULES OF THE GAME ]                                                     #
#                                                                                 #
#   1. // THE "FUCK GREED" PROTOCOL (FREE USE)                                    #
#      You are free to use, edit, and abuse this code on your server.             #
#      Learn from it. Break it. Fix it. That is the hacker way.                   #
#      Cost: 0.00€. If you paid for this, you got scammed by a rat.               #
#                                                                                 #
#   2. // THE TEBEX KILL SWITCH (COMMERCIAL SUICIDE)                              #
#      If I find this script on Tebex, Patreon, or in a paid "Premium Pack":      #
#      > I will DMCA your store into oblivion.                                    #
#      > I will publicly shame your community.                                    #
#      > I hope your server lag spikes to 9999ms every time you blink.            #
#      SELLING FREE WORK IS THEFT. AND I AM THE JUDGE.                            #
#                                                                                 #
#   3. // THE CREDIT OATH                                                         #
#      Keep this header. If you remove my name, you admit you have no skill.      #
#      You can add "Edited by [YourName]", but never erase the original creator.  #
#      Don't be a skid. Respect the architecture.                                 #
#                                                                                 #
#   4. // THE CURSE OF THE COPY-PASTE                                             #
#      This code uses StateBags, ox_inventory stashes, and layered callbacks.     #
#      If you just copy-paste without reading, it WILL break.                     #
#      Don't come crying to my DMs. RTFM or learn to code.                        #
#                                                                                 #
#   --------------------------------------------------------------------------    #
#   "We build the future on the graves of paid resources."                        #
#   "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."                          #
#   --------------------------------------------------------------------------    #
###################################################################################
```

**TL;DR:**
- ✅ Free forever — use it, edit it, learn from it
- ✅ Keep the header — credit where it's due
- ❌ Don't sell it — commercial use = instant DMCA
- ❌ Don't be a skid — copy-paste without reading won't work anyway

---

## 🌐 Community & Support

| | |
| --- | --- |
| 🐙 GitHub | [RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| 🔵 Nostr (RDE) | [RedDragonElite](https://primal.net/p/nprofile1qqsv8km2w8yr0sp7mtk3t44qfw7wmvh8caqpnrd7z6ll6mn9ts03teg9ha4rl) |
| 🔵 Nostr (Shin) | [SerpentsByte](https://primal.net/p/nprofile1qqs8p6u423fappfqrrmxful5kt95hs7d04yr25x88apv7k4vszf4gcqynchct) |
| 🎯 RDE Props | [rde_props](https://github.com/RedDragonElite/rde_props) |
| 🚪 RDE Doors | [rde_doors](https://github.com/RedDragonElite/rde_doors) |
| 🚗 RDE Car Service | [rde_carservice](https://github.com/RedDragonElite/rde_carservice) |

**When asking for help, always include:**
- Full error from server console or txAdmin
- Your `server.cfg` resource start order
- ox_core / ox_lib / ox_inventory versions in use

---

*"We build the future on the graves of paid resources."*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

🐉 Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)

[⬆ Back to Top](#-rde-advanced-shop-system--v100-alpha)
