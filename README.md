# 🏪 RDE Advanced Shop System — V2.0.0

[![image](https://private-user-images.githubusercontent.com/57282916/556398263-c3ab9f75-2885-4d2b-ab26-5e63024c2338.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzQ2NzcyODEsIm5iZiI6MTc3NDY3Njk4MSwicGF0aCI6Ii81NzI4MjkxNi81NTYzOTgyNjMtYzNhYjlmNzUtMjg4NS00ZDJiLWFiMjYtNWU2MzAyNGMyMzM4LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjAzMjglMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYwMzI4VDA1NDk0MVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWI4Yjc2NDhjNDJlZWEzMjBiOTVmZWIwZTA1ZDI0NDZhOWQyYzhmZGM4NTc3OTA1MWYyYmRlMWZmNmJhZDFmMWUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0._4JWkhyh9KRDp1ogFn3BruBa61sGufIdp3vatN3tddY)](https://private-user-images.githubusercontent.com/57282916/556398263-c3ab9f75-2885-4d2b-ab26-5e63024c2338.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzQ2NzcyODEsIm5iZiI6MTc3NDY3Njk4MSwicGF0aCI6Ii81NzI4MjkxNi81NTYzOTgyNjMtYzNhYjlmNzUtMjg4NS00ZDJiLWFiMjYtNWU2MzAyNGMyMzM4LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjAzMjglMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYwMzI4VDA1NDk0MVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWI4Yjc2NDhjNDJlZWEzMjBiOTVmZWIwZTA1ZDI0NDZhOWQyYzhmZGM4NTc3OTA1MWYyYmRlMWZmNmJhZDFmMWUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0._4JWkhyh9KRDp1ogFn3BruBa61sGufIdp3vatN3tddY)

[![Version](https://img.shields.io/badge/version-2.0.0-red?style=for-the-badge&logo=github)](https://github.com/RedDragonElite)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](https://github.com/RedDragonElite/rde_shops/blob/main/LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)](https://github.com/communityox/ox_core)
[![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite)

**The most complete, production-grade shop system for FiveM.**  
Real-time ox\_inventory UI, StateBag sync, dynamic reputation, a fully scripted robbery system with NPC reactions, passive income, analytics, admin tools, **shop templates for instant bulk-creation, 80+ blip options, and a fully race-condition-free purchase system** — battle-tested on live servers.

Built on ox\_core · ox\_lib · ox\_inventory · ox\_target · oxmysql

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte*

---

## 📖 Table of Contents

* [Overview](#-overview)
* [What's New in V2.0.0](#-whats-new-in-v200)
* [Features](#-features)
* [Dependencies](#-dependencies)
* [Installation](#-installation)
* [Configuration](#️-configuration)
* [Shop Templates](#-shop-templates)
* [Shop Categories](#-shop-categories)
* [Blip System](#-blip-system)
* [Robbery System](#-robbery-system)
* [Reputation System](#-reputation-system)
* [Analytics](#-analytics)
* [Admin System](#️-admin-system)
* [Commands](#-commands)
* [Database](#️-database)
* [Localization](#-localization)
* [Troubleshooting](#-troubleshooting)
* [Changelog](#-changelog)
* [License](#-license)

---

## 🎯 Overview

**RDE Advanced Shop System V2.0.0** is a fully dynamic, in-world shop framework for FiveM servers. Admins can create, edit, and delete shops entirely in-game — no config restarts, no hardcoded locations. Every shop gets its own ox\_inventory stash, a spawned NPC clerk, a map blip, and a full set of mechanics including till money, passive income, stock restock, robbery detection, police alerts, and a per-player reputation system.

V2.0.0 adds **Shop Templates** for instant Ammu-Nation/supermarket/pharmacy setup with a single menu selection, a massively expanded blip library with 80+ icons and 29 colors, and a definitive fix for the multi-purchase race condition that previously caused ox\_inventory to throw `nil field 'items'` errors.

### Why RDE Shop System?

| Feature | Typical Shop Scripts | RDE Advanced Shop System |
| --- | --- | --- |
| Dynamic in-game shop creation | ❌ | ✅ Full CRUD in-game |
| Shop Templates (bulk item presets) | ❌ | ✅ 5 templates, 70+ items |
| ox\_inventory UI integration | ❌ or broken | ✅ Fixed & stable |
| StateBag real-time sync | Polling | ✅ Instant |
| Multi-purchase race condition fix | ❌ crashes | ✅ Debounced refresh |
| Robbery system w/ NPC reactions | ❌ | ✅ Hands up, fight back, die |
| Passive till income | ❌ | ✅ Configurable NPC customers |
| Per-player reputation | ❌ | ✅ Affects item prices |
| Auto stock restock | ❌ | ✅ Interval-based |
| Shop analytics | ❌ | ✅ Revenue, purchases, robberies |
| Police alert on robbery | ❌ | ✅ Dispatch + wanted level |
| Multi-language support | ❌ | ✅ EN + DE built-in |
| Blip variety | ~13 options | ✅ 80+ sprites, 29 colors |

---

## 🆕 What's New in V2.0.0

### 🗂️ Shop Templates
The biggest quality-of-life feature in V2. When creating a shop via `/createshop`, you now get an **optional template selection step** before the input dialog. Pick a preset and all items are bulk-inserted into your new shop automatically — no more adding 70 weapons one by one.

Five templates ship out of the box:
- 🔫 **Ammu-Nation (Complete)** — 70 items: all ammo, melee, pistols, SMGs, shotguns, marksman rifles, every attachment, extended clips, drum mags, all scopes, all muzzles, skins, and vests
- 🏪 **24/7 Supermarket** — snacks, drinks, first aid, cigarettes, phone
- 💊 **Pharmacy** — bandages, medikit, painkillers, antidote, adrenaline, defibrillator
- ⛽ **Gas Station** — drinks, jerrycan, rag, basics
- 🍺 **Liquor Store** — beer, wine, vodka, whiskey, rum, cocktails

**Templates are item-presets only — they do NOT spawn shops at fixed locations.** You still place the shop wherever you want with `/createshop`. The template just fills the inventory.

Adding your own template is one Lua block in `data/shop_templates.lua`. No other files need touching.

### 🗺️ Massively Expanded Blip Library
From 13 sprites and 10 colors to **80+ sprites and 29 colors**. Blips are now grouped into logical categories in the dropdown:
- Shops & Services (gun shop, clothing, pharmacy, bar, casino, nightclub, strip club...)
- Property & Buildings (house, office, warehouse, bunker, hangar, marina, yacht, bank...)
- Crime & Black Market (drugs, cash, weapons deal, weed stash, meth lab, money press...)
- Vehicles (truck, bus, helicopter, boat, sports car, train...)
- Racing & Sports (land race, air race, water race, stunt, tennis, basketball, darts...)
- Generic (star, POI marker, info, business, gift...)

### 🔧 Race-Condition Fix — Multi-Purchase Crash
`ox_inventory/modules/shops/server.lua:215: attempt to index a nil value (field 'items')` — this crash happened when a player dragged multiple items quickly. Root cause: `RegisterShop` was called inside the `buyItem` hook, which sets the shop internally to `nil` during rebuild. Any concurrent purchase hit `nil` and crashed, closing the UI.

**Fix:** `RegisterShop` is no longer called in the `buyItem` hook at all. ox\_inventory manages live stock internally once `RegisterShop` has been called at startup. We only write DB decrements, till money, and reputation. A debounced refresh (100ms) handles admin-triggered changes like price edits and item additions — never purchases.

### 🔧 openInventory Race-Condition Fix
`You can not open this inventory` — this happened because `openShopInventory` was calling the debounced `refreshOxShop` (async, 100ms delay) and then immediately firing `TriggerClientEvent` to open the UI. The client arrived before `RegisterShop` completed.

**Fix:** `openShopInventory` now does a **synchronous** `RegisterShop` call inline before triggering the client event. The shop is guaranteed to be registered when the client opens it.

---

## ✨ Features

### 🏪 Shop System

* Create, edit, and delete shops fully in-game via ox\_lib UI
* **Optional template selection at shop creation** — bulk-load 70+ items in one click
* Every shop has its own ox\_inventory stash with configurable slots and max weight
* Spawned NPC clerks with selectable ped models, invincibility, freeze, and scenario settings
* Map blips with **80+ configurable sprites, 29 colors**, name, and short-range display
* 7 built-in shop categories (General, Weapons, Clothing, Liquor, Electronics, Pharmacy, Custom) each with unique blip defaults and reputation multipliers
* Live price updates after admin edits via debounced `refreshOxShop()`

### 💰 Till & Passive Income

* A percentage of every purchase flows into the shop's cash register (`moneyAccumulationRate`)
* Configurable max till balance
* Passive income simulates NPC customers even when no players are buying
* Admins can check and empty the till in-game
* Particle effects on till interaction

### 📦 Stock & Restock

* Stock depletes in real-time when players purchase items
* Automatic restock on a configurable interval with min/max amounts and a hard cap per item

### 🎭 Reputation System

* Each player has a per-shop reputation score (range: -50 to 100)
* Reputation increases on every purchase and decreases on robbery
* Reputation directly affects item prices — loyal customers get discounts, criminals pay a premium
* Multipliers scale with shop category

### 📊 Analytics

* Per-shop tracking of total revenue, total purchases, total robberies, and average transaction value
* Till balance included in analytics view
* Configurable history retention period (days)

### 🛡️ Security & Permissions

* ACE permissions + ox\_core group-based admin system
* Admin groups fully configurable: god, owner, admin, superadmin, moderator, mod, staff
* ACE fallback: `rde_shop.admin`, `rde_orgs.admin`, `command`
* Permission cache reset on player spawn

---

## 🔫 Robbery System

Every shop can be robbed — here's what happens:

**Trigger:** Player aims a qualifying weapon at the NPC clerk for `aimTime` seconds while a robbery isn't on cooldown.

**NPC Reactions:**
* 95% chance the clerk raises their hands and freezes during the timer
* 5% chance the clerk pulls a weapon and fights back
* If the player kills the clerk, the clerk drops money and eventually respawns
* NPC won't flee — they hold their ground or raise their hands

**Payout:** Scales with the till balance. Money is removed from the till on success.

**Police Alert:**
* Sends a dispatch alert to configured police jobs (`police`, `sheriff`, `state`)
* Sets the player's wanted level
* Progressive difficulty: more cops nearby = longer aim time + higher fight-back chance

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
| [ox\_core](https://github.com/communityox/ox_core) | ✅ Required | Player/character framework |
| [ox\_lib](https://github.com/communityox/ox_lib) | ✅ Required | UI, callbacks, notifications |
| [ox\_inventory](https://github.com/communityox/ox_inventory) | ✅ Required | Shop stash + item UI |
| [ox\_target](https://github.com/communityox/ox_target) | ✅ Required | NPC interaction |

---

## 🚀 Installation

### 1. Clone the repository

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_shops.git
```

### 2. Add to `server.cfg`

```
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure rde_shops
```

> **Order matters.** `rde_shops` must start **after** all its dependencies.

### 3. Database

Tables are created automatically on first start. No manual SQL import needed.

### 4. Configure (Optional)

Edit `config.lua` to adjust robbery settings, till rates, restock intervals, reputation thresholds, admin groups, and language. Edit `data/shop_templates.lua` to add or modify item templates.

### 5. Restart & Create Your First Shop

```
restart rde_shops
```

Then in-game: `/createshop` → pick a template (or none) → fill in name/ped/blip → done.

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
    blockevents = true,
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

---

## 🗂️ Shop Templates

Templates are defined in `data/shop_templates.lua` and loaded as a **shared script** (available on both client and server). They appear in the first step of `/createshop` as an optional dropdown — selecting "No Template" starts with an empty shop as before.

### Built-in Templates

| Key | Label | Items |
| --- | --- | --- |
| `ammu_nation` | 🔫 Ammu-Nation (Complete) | 70 — ammo, melee, pistols, SMGs, shotguns, marksman, all attachments |
| `supermarket_247` | 🏪 24/7 Supermarket | 13 — food, drinks, first aid, cigarettes, phone |
| `pharmacy` | 💊 Pharmacy | 7 — bandages, medikit, painkillers, antidote, adrenaline, defib |
| `gas_station` | ⛽ Gas Station | 8 — drinks, jerrycan, rag, bandage |
| `liquor_store` | 🍺 Liquor Store | 8 — beer, wine, vodka, whiskey, rum, cocktails |

### Adding Your Own Template

Open `data/shop_templates.lua` and add a new block to `Config.ShopTemplates`:

```lua
Config.ShopTemplates['my_black_market'] = {
    label       = '💀 Black Market',
    description = 'Off the books.',
    category    = 'weapons',
    pedModel    = 'g_m_y_lost_01',
    blipSprite  = 110,
    blipColor   = 1,

    items = {
        { name = 'WEAPON_ASSAULTRIFLE', price = 18000, quantity = 5, metadata = { registered = false } },
        { name = 'ammo-rifle',          price = 25,    quantity = 300 },
        -- add as many as you want
    }
}
```

No other files need changing. The template appears automatically in the next `/createshop` dialog.

---

## 🏷️ Shop Categories

| Category | Default Blip | Rep Multiplier | Notes |
| --- | --- | --- | --- |
| 🏪 General Store | Sprite 52, Green | 1.0x | |
| 🔫 Weapon Shop | Sprite 110, Red | 1.5x | High robbery severity |
| 👔 Clothing Store | Sprite 73, Blue | 0.8x | |
| 🍺 Liquor Store | Sprite 93, Yellow | 1.2x | |
| 📱 Electronics | Sprite 521, White | 1.3x | |
| 💊 Pharmacy | Sprite 153, Dark | 1.4x | |
| ⭐ Custom | Sprite 52, Green | 1.0x | |

---

## 🗺️ Blip System

V2.0.0 ships with **80+ blip sprites and 29 colors** available in the `/createshop` dropdown, grouped by category. A few highlights:

**Sprites (selection):**

| Icon | Sprite | Label |
| --- | --- | --- |
| 🔫 | 110 | Gun Shop |
| 🏪 | 52 | Store / Supermarket |
| 💊 | 153 | Pharmacy |
| 🍺 | 93 | Bar |
| ⛽ | 361 | Gas Station |
| 🏦 | 108 | Bank |
| 💎 | 617 | Jeweler |
| 💊 | 51 | Drugs |
| 💰 | 272 | Cash |
| 🏁 | 38 | Race Flag |
| 🏠 | 40 | House / Safehouse |
| 🏢 | 475 | Office |
| 🏭 | 500 | Money Press |

Full list in `Config.BlipSprites` inside `config.lua`. Reference: [FiveM Blip Docs](https://docs.fivem.net/docs/game-references/blips/)

**Colors:** White, Red, Green, Blue, Black, Yellow, Light Blue, Purple, Pink, Orange, Brown, Grey, Navy, Cyan, Dark Green, Dark Red, Gold, Royal Blue, Mint, Amber, Indigo, Silver — and more. Full list in `Config.BlipColors`.

---

## 🛡️ Admin System

Admin access is verified against ox\_core groups listed in `Config.AdminGroups`, with ACE permission fallback.

Admins can:
* Create, edit, and delete any shop (with optional template selection)
* Manage shop inventory (add/remove items, set prices, drag & drop stock)
* Check and empty any shop's till
* View full shop analytics
* Get a cached permission refresh on every spawn

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
| `/createshop` | Admin | Create a new shop (with template selection) |

---

## 🗄️ Database

Tables are created automatically on first start. The system uses `Config.TablePrefix` (default `rde_`) for all table names. No manual SQL required.

---

## 🌐 Localization

Built-in English and German support. Switch with `Config.DefaultLanguage = 'en'` or `'de'`.

All locale strings are in `Config.Locales` — add new languages by copying the `en` block and translating.

---

## 🐛 Troubleshooting

**"You can not open this inventory"**  
Fixed in V2.0.0. `openShopInventory` now synchronously calls `RegisterShop` before triggering the client event. If you still see this after updating, ensure you replaced both `server.lua` and `client.lua`.

**Items crash the shop UI after the first purchase / multi-buy broken**  
Fixed in V2.0.0. `RegisterShop` is no longer called inside the `buyItem` hook. ox\_inventory manages live stock internally. Only DB writes happen on purchase now.

**Shop inventory won't open at all?**  
Make sure `ox_inventory` is fully started before `rde_shops`. Check F8 for export errors on startup.

**Admin permission always returning false?**  
Verify the player's ox\_core group matches an entry in `Config.AdminGroups` exactly. Restart the resource after any group changes.

**Robbery not triggering?**  
Ensure the player has a qualifying weapon from `Config.Robbery.weaponTypes` equipped and drawn, and that the shop cooldown has expired.

**NPC not spawning / disappearing instantly?**  
Enable `Config.Debug = true` for verbose spawn logs. Check `deadPedCleanupTime` and `respawnTime`.

**Till always showing $0?**  
Ensure you're on V2.0.0 — `getTillMoney` was broken in early releases.

**Police alert not sending?**  
Confirm `Config.Robbery.policeNotify = true` and that the jobs in `policeJobs` match your server's actual job names.

---

## 📝 Changelog

### V2.0.0 — Template & Stability Release *(Current)*

**New Features:**
* ✅ **Shop Templates** — `/createshop` now has a 3-step flow: template selection → shop data → done. Five built-in templates (Ammu-Nation 70 items, 24/7, Pharmacy, Gas Station, Liquor Store). Templates are defined in `data/shop_templates.lua` (new shared script). Adding custom templates requires no code changes.
* ✅ **80+ Blip Sprites** — expanded from 13 to 80+ options, grouped by category (shops, crime, vehicles, property, racing, generic). Full FiveM blip reference coverage for relevant IDs.
* ✅ **29 Blip Colors** — expanded from 10 to 29, all official GTA color IDs with descriptive labels.
* ✅ **Template-aware `/createshop`** — Ped model, blip sprite/color, and category are pre-filled from the selected template. Admin can override any field.
* ✅ **`Config.GetTemplateOptions()`** — helper returns ox\_lib-compatible select list, always sorted alphabetically with "No Template" pinned at top.

**Critical Fixes:**
* ✅ **Multi-purchase race condition** (`nil field 'items'` crash) — `RegisterShop` removed from `buyItem` hook entirely. Debounced refresh (100ms) only fires on admin actions.
* ✅ **`openInventory` race condition** (`You can not open this inventory`) — `openShopInventory` now performs a synchronous `RegisterShop` call inline before `TriggerClientEvent`. Shop is guaranteed registered when client opens it.

**Infrastructure:**
* ✅ `data/shop_templates.lua` added as `shared_script` in `fxmanifest.lua`
* ✅ `rde_shops:server:applyTemplate` callback — bulk `INSERT ... ON DUPLICATE KEY UPDATE` with single `refreshOxShop()` after all items inserted
* ✅ `refreshTimers` debounce table — prevents double `RegisterShop` during rapid admin actions
* ✅ Version bumped to `2.0.0` in `fxmanifest.lua`

---

### V1.0.0 Alpha — Initial Release

**Critical Fixes:**
* Shop inventory now opens correctly — `forceOpenInventory` → `OpenInventory`
* Stable shop IDs replace timestamp spam
* Stock now depletes on purchase
* `checkAdminPermission` callback now exists
* `getTillMoney` callback now exists
* `checkRobbery` callback now exists
* `completeRobbery` now returns payout correctly
* `Config.Robbery.pedAnimDict` / `pedAnimName` defined

**Medium Fixes:**
* Police alert now sends correct table format
* `#shops` on sparse table → `tableCount()`
* Memory leak on `RegisterShop` eliminated
* `SetModelAsNoLongerNeeded` called after ped spawn

**Improvements:**
* `refreshOxShop()`: live price update after admin edits
* StateBag listener for late-join players
* `ox:playerSpawned` permission cache reset
* NPC raises hands during robbery timer
* Analytics now shows till balance
* Ped cleanup: 20s after death, 60s respawn

---

## 📜 License

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE ADVANCED SHOP SYSTEM V2.0.0                                   #
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
* ✅ Free forever — use it, edit it, learn from it
* ✅ Keep the header — credit where it's due
* ❌ Don't sell it — commercial use = instant DMCA
* ❌ Don't be a skid — copy-paste without reading won't work anyway

---

## 🌐 Community & Support

| | |
| --- | --- |
| 🐙 GitHub | [RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| 🔵 Nostr (RDE) | [RedDragonElite](https://primal.net/p/nprofile1qqsv8km2w8yr0sp7mtk3t44qfw7wmvh8caqpnrd7z6ll6mn9ts03teg9ha4rl) |
| 🔵 Nostr (Shin) | [SerpentsByte](https://primal.net/p/nprofile1qqs8p6u423fappfqrrmxful5kt95hs7d04yr25x88apv7k4vszf4gcqynchct) |
| 🎯 RDE Props | [rde\_props](https://github.com/RedDragonElite/rde_props) |
| 🚪 RDE Doors | [rde\_doors](https://github.com/RedDragonElite/rde_doors) |
| 🚗 RDE Car Service | [rde\_carservice](https://github.com/RedDragonElite/rde_carservice) |

**When asking for help, always include:**
* Full error from server console or txAdmin
* Your `server.cfg` resource start order
* ox\_core / ox\_lib / ox\_inventory versions in use

---

*"We build the future on the graves of paid resources."*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

🐉 Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)

[⬆ Back to Top](#-rde-advanced-shop-system--v200)
