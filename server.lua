-- ┌─────────────────────────────────────────────────────────────────────┐
-- │  RDE Advanced Shop System V4.7 — Server                             │
-- │  Framework : ox_core v2 + ox_inventory + ox_lib + oxmysql           │
-- │  Author    : RDE Development | rd-elite.com                          │
-- │                                                                       │
-- │  FIX LOG V4.0:                                                        │
-- │  [#1] player.addMoney() → player.getAccount().addBalance({amount=X}) │
-- │  [#2] get('job') ESX pattern → getGroups() ox_core pattern           │
-- │  [#3] AddEventHandler ox_inventory:buyItem → registerHook()          │
-- │  [#4] Stash drag-and-drop per shop (NEW FEATURE)                      │
-- │  [#5] swapItems hook → DB sync on stash item change                  │
-- │  [#6] rde_aipd integration: nostr:crime + wantedSet on robbery        │
-- └─────────────────────────────────────────────────────────────────────┘

local shops              = {}    -- ID → shop table
local robberyStates      = {}    -- shopId → {source, startTime}
local playerPermissions  = {}    -- source → bool (cached)
local deadPeds           = {}    -- shopId → bool
local stashPricesPending = {}    -- stashId → {itemName, shopId} for drag-in price dialogs
local shopsReady         = false -- true once loadShops() has fully completed
local pendingPlayers     = {}    -- players who joined before shopsReady

-- =============================================
-- UTILITY
-- =============================================
local function debugPrint(...)
    if Config.Debug then
        print('[RDE Shops - Server]', ...)
    end
end

local function getPlayerFromId(source)
    local player = Ox.GetPlayer(source)
    if not player then debugPrint('Player not found for source:', source) end
    return player
end

local function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- =============================================
-- STATEBAG SYNC
-- =============================================
local function syncShopStateBag(shopId)
    local shop = shops[shopId]
    if not shop then return end
    GlobalState['rde_shop_' .. shopId] = {
        id            = shop.id,
        name          = shop.name,
        blipName      = shop.blipName,
        pedModel      = shop.pedModel,
        coords        = {x = shop.coords.x, y = shop.coords.y, z = shop.coords.z, w = shop.coords.w},
        category      = shop.category,
        blipSprite    = shop.blipSprite,
        blipColor     = shop.blipColor,
        tillMoney     = shop.tillMoney,
        reputation    = shop.reputation,
        lastRobbed    = shop.lastRobbed,
        isBeingRobbed = robberyStates[shopId] ~= nil,
        pedDead       = deadPeds[shopId] ~= nil
    }
    debugPrint('Synced shop', shopId, 'via StateBag')
end

local function syncAllShopsStateBag()
    local shopList = {}
    for shopId in pairs(shops) do table.insert(shopList, shopId) end
    GlobalState.rde_shop_list = shopList
    for shopId in pairs(shops) do syncShopStateBag(shopId) end
    debugPrint('Synced all', tableCount(shops), 'shops via StateBag')
end

-- =============================================
-- PERMISSION SYSTEM
-- =============================================
local function checkOxCoreGroups(player)
    if not player then return false end
    local groups = player.getGroups and player.getGroups() or {}
    if type(groups) ~= 'table' then return false end
    for _, adminGroup in ipairs(Config.AdminGroups) do
        if groups[adminGroup] then return true end
    end
    return false
end

local function checkAcePermissions(source)
    for _, ace in ipairs(Config.AcePermissions) do
        if IsPlayerAceAllowed(source, ace) then return true end
    end
    return false
end

local function hasPermission(source)
    if playerPermissions[source] ~= nil then return playerPermissions[source] end
    local hasPerms = checkAcePermissions(source)
    if not hasPerms then
        local player = getPlayerFromId(source)
        if player then hasPerms = checkOxCoreGroups(player) end
    end
    playerPermissions[source] = hasPerms
    return hasPerms
end

-- =============================================
-- DATABASE INITIALIZATION
-- =============================================
local function initDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rde_shops` (
            `id`          INT AUTO_INCREMENT PRIMARY KEY,
            `name`        VARCHAR(100) NOT NULL,
            `blip_name`   VARCHAR(100) NOT NULL,
            `ped_model`   VARCHAR(50)  NOT NULL,
            `coords`      VARCHAR(100) NOT NULL,
            `heading`     FLOAT        NOT NULL DEFAULT 0,
            `category`    VARCHAR(50)  DEFAULT 'general',
            `blip_sprite` INT          DEFAULT 52,
            `blip_color`  INT          DEFAULT 2,
            `till_money`  INT          DEFAULT 0,
            `reputation`  INT          DEFAULT 0,
            `last_robbed` BIGINT       DEFAULT 0,
            `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            `updated_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rde_shop_prices` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `shop_id`    INT          NOT NULL,
            `item_name`  VARCHAR(50)  NOT NULL,
            `price`      INT          NOT NULL DEFAULT 10,
            `quantity`   INT          NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (`shop_id`) REFERENCES `rde_shops`(`id`) ON DELETE CASCADE,
            UNIQUE KEY `unique_shop_item` (`shop_id`, `item_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query('ALTER TABLE `rde_shop_prices` ADD COLUMN IF NOT EXISTS `quantity` INT NOT NULL DEFAULT 0')

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rde_shop_analytics` (
            `id`               INT AUTO_INCREMENT PRIMARY KEY,
            `shop_id`          INT NOT NULL,
            `transaction_type` ENUM('purchase','robbery') NOT NULL,
            `amount`           INT NOT NULL,
            `item_name`        VARCHAR(50) DEFAULT NULL,
            `timestamp`        TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`shop_id`) REFERENCES `rde_shops`(`id`) ON DELETE CASCADE,
            INDEX `idx_shop_timestamp` (`shop_id`, `timestamp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    debugPrint('Database tables initialized')
end

-- =============================================
-- OX_INVENTORY TIMING GUARD
-- =============================================
local oxInventoryReady = false

local function waitForOxInventory()
    if oxInventoryReady then return true end
    local attempts = 0
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(200)
        attempts = attempts + 1
        if attempts > 100 then
            print('^1[RDE Shops] ox_inventory did not start within 20s^7')
            return false
        end
    end
    Wait(500)
    oxInventoryReady = true
    return true
end

local function getOxShopId(shopId)
    return 'rde_shop_' .. shopId
end

local function getOxStashId(shopId)
    return 'rde_shop_stash_' .. shopId
end

-- =============================================
-- REPUTATION PRICE MULTIPLIER
-- =============================================
local function getPriceWithReputation(shopId, basePrice)
    local shop = shops[shopId]
    if not shop or not Config.Shops.reputation.enabled then return basePrice end
    local rep     = shop.reputation
    local maxRep  = Config.Shops.reputation.maxRep
    local minRep  = Config.Shops.reputation.minRep
    local maxMult = Config.Shops.reputation.priceMultiplierMax
    local minMult = Config.Shops.reputation.priceMultiplierMin
    local repPercent = math.max(0.0, math.min(1.0, (rep - minRep) / (maxRep - minRep)))
    local multiplier = minMult - (minMult - maxMult) * repPercent
    return math.max(1, math.floor(basePrice * multiplier))
end

-- =============================================
-- DB ITEM READER
-- =============================================
local function getShopItemsFromDB(shopId)
    local rows = MySQL.query.await(
        'SELECT item_name, price, quantity FROM rde_shop_prices WHERE shop_id = ? AND quantity > 0',
        {shopId}
    )
    local result = {}
    if rows then
        for _, row in ipairs(rows) do
            table.insert(result, { item_name = row.item_name, price = row.price, count = row.quantity })
        end
    end
    return result
end

-- =============================================
-- OX_INVENTORY SHOP REFRESH
-- =============================================
-- Debounce-Timers: verhindert dass RegisterShop während eines laufenden
-- Rebuilds erneut aufgerufen wird → fixiert "nil field 'items'" bei
-- schnellen Mehrfachkäufen (ox_inventory/modules/shops/server.lua:215).
local refreshTimers = {}

local function refreshOxShop(shopId)
    local shop = shops[shopId]
    if not shop then return end
    if not oxInventoryReady then
        debugPrint('refreshOxShop skipped (ox_inventory not ready) for shop', shopId)
        return
    end

    -- Debounce: wenn für diesen Shop bereits ein Refresh aussteht,
    -- einfach den bestehenden Timer laufen lassen (kein Doppel-Rebuild).
    -- Das verhindert den "nil field 'items'" Crash bei schnellen Mehrfachkäufen.
    if refreshTimers[shopId] then return end

    refreshTimers[shopId] = true
    SetTimeout(100, function()
        refreshTimers[shopId] = nil

        -- Zum Zeitpunkt des Ausführens nochmal prüfen (Shop könnte gelöscht sein)
        local s = shops[shopId]
        if not s or not oxInventoryReady then return end

        local oxShopId  = getOxShopId(shopId)
        local items     = getShopItemsFromDB(shopId)
        local inventory = {}

        for _, itemData in ipairs(items) do
            table.insert(inventory, {
                name     = itemData.item_name,
                price    = getPriceWithReputation(shopId, itemData.price),
                count    = itemData.count,
                currency = 'money',
            })
        end

        local shopCoords = nil
        if s.coords then
            shopCoords = vec3(s.coords.x, s.coords.y, s.coords.z)
        end

        local shopProperties = {
            name      = s.blipName,
            inventory = inventory,
        }
        if shopCoords then
            shopProperties.locations = { shopCoords }
        end

        local ok, err = pcall(function()
            exports.ox_inventory:RegisterShop(oxShopId, shopProperties)
        end)

        if not ok then
            print('^3[RDE Shops] RegisterShop failed for shop ' .. shopId .. ': ' .. tostring(err) .. '^7')
        else
            debugPrint('ox shop refreshed:', oxShopId, '—', #inventory, 'items', shopCoords and '(with location)' or '(no location)')
        end
    end)
end

-- =============================================
-- OX_INVENTORY STASH REGISTRATION (DRAG & DROP)
-- =============================================
-- Each shop gets a dedicated stash that admins can drag items into.
-- The stash acts as the stock container — items dragged in become available
-- for purchase; dragging out removes from stock.
local function registerShopStash(shopId)
    local shop = shops[shopId]
    if not shop then return end

    -- CORRECT ox_inventory RegisterStash API — positional args, NOT a named table.
    -- Signature: RegisterStash(id, label, slots, weight, owner)
    -- 'weight' not 'maxWeight'. owner=false = one shared stash for all.
    local stashSlots  = tonumber(Config.ShopInventory and Config.ShopInventory.slots)    or 100
    local stashWeight = tonumber(Config.ShopInventory and Config.ShopInventory.maxWeight) or 100000

    local ok, err = pcall(function()
        exports.ox_inventory:RegisterStash(
            getOxStashId(shopId),
            'Stock: ' .. shop.blipName,
            stashSlots,
            stashWeight,
            false
        )
    end)
    if not ok then
        print('^3[RDE Shops] RegisterStash failed for shop ' .. shopId .. ': ' .. tostring(err) .. '^7')
    else
        debugPrint('Registered stock stash for shop', shopId)
    end
end

-- =============================================
-- SHOP LOADING
-- =============================================
local function loadShops()
    waitForOxInventory()

    local result = MySQL.query.await('SELECT * FROM rde_shops')
    if not result then debugPrint('No shops found or DB error'); return end

    for _, shopData in ipairs(result) do
        local coords = json.decode(shopData.coords)
        shops[shopData.id] = {
            id         = shopData.id,
            name       = shopData.name,
            blipName   = shopData.blip_name,
            pedModel   = shopData.ped_model,
            coords     = vector4(coords.x, coords.y, coords.z, shopData.heading),
            category   = shopData.category,
            blipSprite = shopData.blip_sprite,
            blipColor  = shopData.blip_color,
            tillMoney  = shopData.till_money,
            reputation = shopData.reputation,
            lastRobbed = shopData.last_robbed
        }
        refreshOxShop(shopData.id)
        registerShopStash(shopData.id)
    end

    syncAllShopsStateBag()
    shopsReady = true
    debugPrint('Loaded', tableCount(shops), 'shops')

    -- Send shops to any players who connected before loadShops() finished
    for _, playerId in ipairs(pendingPlayers) do
        sendShopsToPlayer(playerId)
        debugPrint('Flushed pending player:', playerId)
    end
    pendingPlayers = {}
end

-- =============================================
-- OX_INVENTORY HOOKS
-- =============================================

-- [FIX #3] Use registerHook instead of AddEventHandler for purchase tracking.
-- The old AddEventHandler('ox_inventory:buyItem', ...) was wrong — it's not a net event.
-- registerHook with inventoryFilter is precise and efficient.
local function registerInventoryHooks()
    -- PURCHASE HOOK — fires after a customer buys from one of our registered shops
    exports.ox_inventory:registerHook('buyItem', function(payload)
        -- payload.shopType is the string ID we passed to RegisterShop ("rde_shop_N")
        local numericId = tonumber(tostring(payload.shopType):match('^rde_shop_(%d+)$'))
        if not numericId or not shops[numericId] then return end

        local shop      = shops[numericId]
        local itemName  = payload.itemName
        local count     = payload.count   or 1
        local totalCost = payload.totalPrice or ((payload.price or 0) * count)

        -- Accumulate till money
        shop.tillMoney = math.min(
            shop.tillMoney + math.floor(totalCost * Config.Shops.till.moneyAccumulationRate),
            Config.Shops.till.maxTillMoney
        )

        -- Decrement stock in DB
        MySQL.query([[
            UPDATE rde_shop_prices
            SET quantity = GREATEST(0, quantity - ?)
            WHERE shop_id = ? AND item_name = ?
        ]], {count, numericId, itemName})

        MySQL.query('UPDATE rde_shops SET till_money = ? WHERE id = ?', {shop.tillMoney, numericId})

        -- Reputation gain
        if Config.Shops.reputation.enabled then
            shop.reputation = math.min(
                shop.reputation + Config.Shops.reputation.repGainPerPurchase,
                Config.Shops.reputation.maxRep
            )
            MySQL.query('UPDATE rde_shops SET reputation = ? WHERE id = ?', {shop.reputation, numericId})
        end

        -- Analytics
        if Config.Shops.analytics.trackPurchases then
            MySQL.insert(
                'INSERT INTO rde_shop_analytics (shop_id, transaction_type, amount, item_name) VALUES (?, ?, ?, ?)',
                {numericId, 'purchase', totalCost, itemName}
            )
        end

        -- KEIN refreshOxShop hier — ox_inventory managed den Shop-Stock intern selbst.
        -- RegisterShop während eines laufenden buyItem-Hooks setzt shop.items kurz auf nil
        -- → Crash bei Mehrfachkäufen (ox_inventory/modules/shops/server.lua:215).
        -- DB-Decrement oben reicht: Stock bleibt nach Server-Restart korrekt.
        syncShopStateBag(numericId)

        TriggerClientEvent('rde_shops:client:showPurchaseEffect', payload.source, numericId)
        debugPrint('Purchase:', itemName, 'x' .. count, 'for $' .. totalCost, 'at shop', numericId)
    end, {
        inventoryFilter = { '^rde_shop_%d+$' }
    })

    -- DRAG & DROP HOOK — fires when any item is moved into or out of a shop stash
    exports.ox_inventory:registerHook('swapItems', function(payload)
        -- Detect target stash
        local toStashId   = type(payload.toInventory) == 'string' and payload.toInventory or nil
        local fromStashId = type(payload.fromInventory) == 'string' and payload.fromInventory or nil

        local toShopId   = toStashId   and tonumber(tostring(toStashId):match('^rde_shop_stash_(%d+)$'))   or nil
        local fromShopId = fromStashId and tonumber(tostring(fromStashId):match('^rde_shop_stash_(%d+)$')) or nil

        if toShopId and shops[toShopId] then
            -- Item dragged INTO shop stash → add to DB stock
            local itemName = payload.fromSlot and payload.fromSlot.name
            if not itemName then return end
            local count = payload.count or 1

            -- Check if item already has a price in DB, if not use default 10
            local existing = MySQL.single.await(
                'SELECT price FROM rde_shop_prices WHERE shop_id = ? AND item_name = ?',
                {toShopId, itemName}
            )
            local price = existing and existing.price or 10

            MySQL.query([[
                INSERT INTO rde_shop_prices (shop_id, item_name, price, quantity)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)
            ]], {toShopId, itemName, price, count})

            refreshOxShop(toShopId)
            debugPrint('Drag-in: +' .. count .. 'x ' .. itemName .. ' to shop', toShopId, '(price: $' .. price .. ')')

            -- Notify admin: item added, prompt to set price if new
            if not existing then
                TriggerClientEvent('rde_shops:client:promptStashItemPrice', payload.source, toShopId, itemName, price)
            end
        end

        if fromShopId and shops[fromShopId] then
            -- Item dragged OUT of shop stash → reduce DB stock
            local itemName = payload.fromSlot and payload.fromSlot.name
            if not itemName then return end
            local count = payload.count or 1

            MySQL.query([[
                UPDATE rde_shop_prices
                SET quantity = GREATEST(0, quantity - ?)
                WHERE shop_id = ? AND item_name = ?
            ]], {count, fromShopId, itemName})

            refreshOxShop(fromShopId)
            debugPrint('Drag-out: -' .. count .. 'x ' .. itemName .. ' from shop', fromShopId)
        end
    end, {
        inventoryFilter = { '^rde_shop_stash_%d+$' }
    })
end

-- =============================================
-- RDE_AIPD INTEGRATION
-- =============================================
-- [FIX #6] Notify rde_aipd on robbery for crime logging + wanted sync
local function notifyAipd(source, shopId)
    if GetResourceState('rde_aipd') ~= 'started' then return end
    local shop = shops[shopId]
    if not shop then return end

    -- Fire Nostr crime event (server-side)
    TriggerEvent('police:nostr:crime', source, 'ROBBERY', shop.blipName or 'Unknown', true)
    -- Fire wanted set (the robbery already triggers wanted via police alert, but also sync aipd)
    TriggerEvent('police:nostr:wantedSet', source, Config.Robbery.wantedLevel, 'SHOP_ROBBERY')

    debugPrint('rde_aipd notified of robbery at shop', shopId, 'by source', source)
end

-- =============================================
-- POLICE JOB CHECK (ox_core correct pattern)
-- =============================================
-- [FIX #2] player.get('job') is ESX/QB — ox_core uses getGroups()
local function countNearbyPolice(shopCoords)
    local copsNearby = 0
    for _, playerId in ipairs(GetPlayers()) do
        local targetPlayer = getPlayerFromId(tonumber(playerId))
        if targetPlayer then
            local groups = targetPlayer.getGroups and targetPlayer.getGroups() or {}
            local isPolice = false
            for _, policeJob in ipairs(Config.Robbery.policeJobs) do
                if groups[policeJob] then
                    isPolice = true
                    break
                end
            end
            if isPolice then
                local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(playerId)))
                local dist = #(vec3(shopCoords.x, shopCoords.y, shopCoords.z) - playerCoords)
                if dist < Config.Robbery.dispatchRadius then
                    copsNearby = copsNearby + 1
                end
            end
        end
    end
    return copsNearby
end

-- =============================================
-- PERMISSION CALLBACKS
-- =============================================
lib.callback.register('rde_shops:server:checkAdminPermission', function(source)
    return hasPermission(source)
end)

lib.callback.register('rde_shops:server:requestPermission', function(source)
    return hasPermission(source)
end)

-- =============================================
-- SHOP MANAGEMENT CALLBACKS
-- =============================================
lib.callback.register('rde_shops:server:createShop', function(source, data)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end
    if not data or not data.name or not data.coords then
        return {success = false, message = 'Invalid data'}
    end

    local coordsJson = json.encode({x = data.coords.x, y = data.coords.y, z = data.coords.z})
    local insertId   = MySQL.insert.await([[
        INSERT INTO rde_shops (name, blip_name, ped_model, coords, heading, category, blip_sprite, blip_color, till_money, reputation)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0)
    ]], {
        data.name,
        data.blipName or data.name,
        data.pedModel or 'mp_m_shopkeep_01',
        coordsJson,
        data.heading or 0.0,
        data.category or 'general',
        data.blipSprite or 52,
        data.blipColor or 2
    })

    if not insertId then return {success = false, message = 'Database error'} end

    shops[insertId] = {
        id         = insertId,
        name       = data.name,
        blipName   = data.blipName or data.name,
        pedModel   = data.pedModel or 'mp_m_shopkeep_01',
        coords     = vector4(data.coords.x, data.coords.y, data.coords.z, data.heading or 0.0),
        category   = data.category or 'general',
        blipSprite = data.blipSprite or 52,
        blipColor  = data.blipColor or 2,
        tillMoney  = 0,
        reputation = 0,
        lastRobbed = 0
    }

    refreshOxShop(insertId)
    registerShopStash(insertId)
    syncAllShopsStateBag()
    return {success = true, shopId = insertId}
end)

-- =============================================
-- TEMPLATE APPLY CALLBACK
-- =============================================
-- Wird vom Client nach createShop aufgerufen wenn ein Template gewählt wurde.
-- Schreibt alle Template-Items per Bulk-Insert in rde_shop_prices und
-- refresht danach den ox_inventory Shop einmalig.
lib.callback.register('rde_shops:server:applyTemplate', function(source, shopId, templateKey)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end
    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end
    if not templateKey or templateKey == 'none' then
        return {success = false, message = 'No template key provided'}
    end

    local tpl = Config.ShopTemplates and Config.ShopTemplates[templateKey]
    if not tpl then
        return {success = false, message = 'Unknown template: ' .. tostring(templateKey)}
    end
    if not tpl.items or #tpl.items == 0 then
        return {success = true, itemCount = 0}
    end

    -- Bulk-Insert: ON DUPLICATE KEY → bestehende Items nicht überschreiben
    -- falls der Shop bereits manuell Items hat.
    local insertedCount = 0
    for _, item in ipairs(tpl.items) do
        if type(item.name) == 'string' and item.name ~= '' then
            local qty   = item.quantity or 50
            local price = item.price    or 0
            MySQL.query.await([[
                INSERT INTO rde_shop_prices (shop_id, item_name, price, quantity)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    price    = VALUES(price),
                    quantity = quantity + VALUES(quantity)
            ]], {shopId, item.name, price, qty})
            insertedCount = insertedCount + 1
        end
    end

    -- Einmaliger ox_inventory Refresh nach Bulk-Insert
    refreshOxShop(shopId)
    debugPrint('Template "' .. templateKey .. '" applied to shop', shopId, '—', insertedCount, 'items')
    return {success = true, itemCount = insertedCount}
end)

lib.callback.register('rde_shops:server:deleteShop', function(source, shopId)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end

    MySQL.query.await('DELETE FROM rde_shops WHERE id = ?', {shopId})

    shops[shopId]         = nil
    robberyStates[shopId] = nil
    deadPeds[shopId]      = nil
    GlobalState['rde_shop_' .. shopId] = nil

    syncAllShopsStateBag()
    debugPrint('Shop deleted: ID', shopId)
    return {success = true}
end)

lib.callback.register('rde_shops:server:updateShop', function(source, shopId, data)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] or not data then return {success = false, message = 'Invalid data'} end

    MySQL.query.await([[
        UPDATE rde_shops
        SET name = ?, blip_name = ?, ped_model = ?, category = ?, blip_sprite = ?, blip_color = ?
        WHERE id = ?
    ]], {data.name, data.blipName or data.name, data.pedModel, data.category or 'general',
        data.blipSprite or 52, data.blipColor or 2, shopId})

    shops[shopId].name       = data.name
    shops[shopId].blipName   = data.blipName or data.name
    shops[shopId].pedModel   = data.pedModel
    shops[shopId].category   = data.category or 'general'
    shops[shopId].blipSprite = data.blipSprite or 52
    shops[shopId].blipColor  = data.blipColor or 2

    refreshOxShop(shopId)
    syncShopStateBag(shopId)
    return {success = true}
end)

-- =============================================
-- INVENTORY CALLBACKS
-- =============================================
lib.callback.register('rde_shops:server:openShopInventory', function(source, shopId)
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end

    local items = getShopItemsFromDB(shopId)
    if #items == 0 then return {success = false, message = L('shop_empty')} end

    -- IMPORTANT: refreshOxShop ist DEBOUNCED (async SetTimeout).
    -- Wir dürfen den Client NICHT vor dem RegisterShop triggern.
    -- Lösung: direkt synchron registrieren wenn nötig, dann sofort Client triggern.
    local oxShopId = getOxShopId(shopId)
    local shop     = shops[shopId]
    local inventory = {}
    for _, itemData in ipairs(items) do
        table.insert(inventory, {
            name     = itemData.item_name,
            price    = getPriceWithReputation(shopId, itemData.price),
            count    = itemData.count,
            currency = 'money',
        })
    end
    local shopProps = { name = shop.blipName, inventory = inventory }
    if shop.coords then
        shopProps.locations = { vec3(shop.coords.x, shop.coords.y, shop.coords.z) }
    end
    pcall(function() exports.ox_inventory:RegisterShop(oxShopId, shopProps) end)

    -- Jetzt ist der Shop garantiert registriert → Client kann öffnen
    TriggerClientEvent('rde_shops:client:doOpenShop', source, oxShopId, 1)
    return {success = true}
end)

-- [NEW] Open the shop's drag-and-drop stock stash for admin
lib.callback.register('rde_shops:server:openStockStash', function(source, shopId)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end
    TriggerClientEvent('rde_shops:client:doOpenStash', source, getOxStashId(shopId))
    return {success = true}
end)

lib.callback.register('rde_shops:server:getShopItems', function(source, shopId)
    if not hasPermission(source) then return nil end
    if not shops[shopId] then return nil end
    local rows = MySQL.query.await(
        'SELECT item_name, price, quantity FROM rde_shop_prices WHERE shop_id = ?', {shopId})
    local result = {}
    if rows then
        for _, row in ipairs(rows) do
            table.insert(result, {item_name = row.item_name, price = row.price, count = row.quantity})
        end
    end
    return result
end)

lib.callback.register('rde_shops:server:addShopItem', function(source, shopId, itemName, quantity, price)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end
    if type(itemName) ~= 'string' or itemName == '' then return {success = false, message = 'Invalid item name'} end
    if type(quantity) ~= 'number' or quantity < 1 then return {success = false, message = 'Quantity must be ≥ 1'} end
    if type(price) ~= 'number' or price < 0 then return {success = false, message = L('invalid_amount')} end

    MySQL.query.await([[
        INSERT INTO rde_shop_prices (shop_id, item_name, price, quantity)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            price    = VALUES(price),
            quantity = quantity + VALUES(quantity)
    ]], {shopId, itemName, price, quantity})

    refreshOxShop(shopId)
    debugPrint('Added', quantity, 'x', itemName, 'to shop', shopId, 'at $' .. price)
    return {success = true}
end)

lib.callback.register('rde_shops:server:updateShopItem', function(source, shopId, itemName, quantity, price)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end
    if type(quantity) ~= 'number' or quantity < 0 then return {success = false, message = 'Invalid quantity'} end
    if type(price) ~= 'number' or price < 0 then return {success = false, message = L('invalid_amount')} end

    MySQL.query.await(
        'UPDATE rde_shop_prices SET price = ?, quantity = ? WHERE shop_id = ? AND item_name = ?',
        {price, quantity, shopId, itemName})

    refreshOxShop(shopId)
    return {success = true}
end)

lib.callback.register('rde_shops:server:removeShopItem', function(source, shopId, itemName)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end

    MySQL.query.await('DELETE FROM rde_shop_prices WHERE shop_id = ? AND item_name = ?', {shopId, itemName})

    refreshOxShop(shopId)
    return {success = true}
end)

lib.callback.register('rde_shops:server:setItemPrice', function(source, shopId, itemName, price)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end
    if type(price) ~= 'number' or price < 0 then return {success = false, message = L('invalid_amount')} end

    MySQL.query.await(
        'UPDATE rde_shop_prices SET price = ? WHERE shop_id = ? AND item_name = ?',
        {price, shopId, itemName})

    refreshOxShop(shopId)
    return {success = true}
end)

-- [NEW] Called from client after drag-in price prompt
lib.callback.register('rde_shops:server:setDragInPrice', function(source, shopId, itemName, price)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    if not shops[shopId] then return {success = false, message = 'Shop not found'} end
    if type(price) ~= 'number' or price < 1 then return {success = false, message = L('invalid_amount')} end

    MySQL.query.await(
        'UPDATE rde_shop_prices SET price = ? WHERE shop_id = ? AND item_name = ?',
        {price, shopId, itemName})

    refreshOxShop(shopId)
    debugPrint('Drag-in price set for', itemName, 'in shop', shopId, '→ $' .. price)
    return {success = true}
end)

-- =============================================
-- ROBBERY SYSTEM
-- =============================================
lib.callback.register('rde_shops:server:checkRobbery', function(source, shopId)
    local shop = shops[shopId]
    if not shop then return {success = false, message = 'Shop not found'} end

    local currentTime = os.time()
    if currentTime - shop.lastRobbed < Config.Robbery.cooldown then
        return {success = false, message = L('robbery_cooldown')}
    end
    if shop.tillMoney <= 0 then
        return {success = false, message = L('till_empty')}
    end
    if robberyStates[shopId] then
        return {success = false, message = 'Already being robbed'}
    end

    -- [FIX #2] Use getGroups() instead of get('job')
    local copsNearby = countNearbyPolice(shop.coords)

    if copsNearby < Config.Robbery.minPolice then
        return {success = false, message = L('not_enough_police')}
    end

    local requiredTime = Config.Robbery.aimTime
    if Config.Robbery.progressive.enabled then
        requiredTime = requiredTime + (copsNearby * Config.Robbery.progressive.timeIncreasePerCop)
    end

    return {
        success      = true,
        requiredTime = requiredTime * 1000,
        copsNearby   = copsNearby
    }
end)

RegisterNetEvent('rde_shops:server:startRobbery', function(shopId)
    local source = source
    local shop   = shops[shopId]
    if not shop then return end

    robberyStates[shopId] = {source = source, startTime = os.time()}
    syncShopStateBag(shopId)
    debugPrint('Robbery started at shop', shopId, 'by player', source)
end)

RegisterNetEvent('rde_shops:server:completeRobbery', function(shopId)
    local source = source
    local shop   = shops[shopId]
    if not shop then return end

    -- Security: only the player who started this robbery can complete it
    local state = robberyStates[shopId]
    if not state or state.source ~= source then
        debugPrint('completeRobbery rejected: source', source, 'does not match robbery owner', state and state.source)
        return
    end

    local payout = math.floor(shop.tillMoney * Config.Robbery.payoutPercentage)
    payout = math.max(Config.Robbery.minPayout, math.min(payout, Config.Robbery.maxPayout))

    local player = getPlayerFromId(source)
    if not player then return end

    -- [FIX #1] player.addMoney() does not exist in ox_core.
    -- Correct API: player.getAccount('money').addBalance({amount = X, message = '...'})
    local account = player.getAccount and player.getAccount('money')
    if account then
        account.addBalance({amount = payout, message = 'Shop robbery proceeds'})
    else
        print('^1[RDE Shops] Could not find account for player ' .. tostring(source) .. '^7')
    end

    shop.tillMoney  = math.max(0, shop.tillMoney - payout)
    shop.lastRobbed = os.time()

    if Config.Shops.reputation.enabled then
        shop.reputation = math.max(
            shop.reputation - Config.Shops.reputation.repLossPerRobbery,
            Config.Shops.reputation.minRep
        )
    end

    MySQL.query('UPDATE rde_shops SET till_money = ?, reputation = ?, last_robbed = ? WHERE id = ?',
        {shop.tillMoney, shop.reputation, shop.lastRobbed, shopId})

    if Config.Shops.analytics.trackRobberies then
        MySQL.insert('INSERT INTO rde_shop_analytics (shop_id, transaction_type, amount) VALUES (?, ?, ?)',
            {shopId, 'robbery', payout})
    end

    -- Police Alert — [FIX #2] use getGroups() instead of get('job')
    if Config.Robbery.policeNotify then
        local alertData = {
            coords   = {x = shop.coords.x, y = shop.coords.y, z = shop.coords.z},
            shopName = shop.blipName
        }
        for _, playerId in ipairs(GetPlayers()) do
            local targetPlayer = getPlayerFromId(tonumber(playerId))
            if targetPlayer then
                local groups = targetPlayer.getGroups and targetPlayer.getGroups() or {}
                local isPolice = false
                for _, policeJob in ipairs(Config.Robbery.policeJobs) do
                    if groups[policeJob] then isPolice = true; break end
                end
                if isPolice then
                    TriggerClientEvent('rde_shops:client:policeAlert', tonumber(playerId), alertData)
                end
            end
        end
    end

    -- [FIX #6] Notify rde_aipd
    notifyAipd(source, shopId)

    robberyStates[shopId] = nil
    syncShopStateBag(shopId)

    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Shop System',
        description = string.format(L('robbery_success'), payout),
        type        = 'success'
    })

    TriggerClientEvent('rde_shops:client:robberyComplete', source, shopId)
    debugPrint('Robbery complete at shop', shopId, '— Payout: $' .. payout)
end)

RegisterNetEvent('rde_shops:server:cancelRobbery', function(shopId)
    if robberyStates[shopId] then
        robberyStates[shopId] = nil
        syncShopStateBag(shopId)
        debugPrint('Robbery cancelled at shop', shopId)
    end
end)

-- =============================================
-- PED DEATH & RESPAWN
-- =============================================
RegisterNetEvent('rde_shops:server:pedKilled', function(shopId)
    if not shops[shopId] then return end
    deadPeds[shopId] = true
    syncShopStateBag(shopId)
    SetTimeout(Config.Shops.ped.respawnTime, function()
        deadPeds[shopId] = nil
        syncShopStateBag(shopId)
        debugPrint('Ped respawned for shop', shopId)
    end)
    debugPrint('Ped killed at shop', shopId)
end)

-- =============================================
-- TILL MANAGEMENT
-- =============================================
lib.callback.register('rde_shops:server:getTillMoney', function(source, shopId)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    local shop = shops[shopId]
    if not shop then return {success = false, message = 'Shop not found'} end
    return {success = true, amount = shop.tillMoney}
end)

lib.callback.register('rde_shops:server:checkTill', function(source, shopId)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    local shop = shops[shopId]
    if not shop then return {success = false, message = 'Shop not found'} end
    return {success = true, amount = shop.tillMoney}
end)

lib.callback.register('rde_shops:server:emptyTill', function(source, shopId)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    local shop = shops[shopId]
    if not shop then return {success = false, message = 'Shop not found'} end
    if shop.tillMoney <= 0 then return {success = false, message = L('till_empty')} end

    local player = getPlayerFromId(source)
    if not player then return {success = false, message = 'Player not found'} end

    -- [FIX #1] Use correct ox_core account API
    local amount  = shop.tillMoney
    local account = player.getAccount and player.getAccount('money')
    if account then
        account.addBalance({amount = amount, message = 'Shop till collection'})
    else
        print('^1[RDE Shops] Could not find account for player ' .. tostring(source) .. '^7')
        return {success = false, message = 'Account error'}
    end

    shop.tillMoney = 0
    MySQL.query('UPDATE rde_shops SET till_money = 0 WHERE id = ?', {shopId})
    syncShopStateBag(shopId)

    return {success = true, amount = amount}
end)

-- =============================================
-- ANALYTICS
-- =============================================
lib.callback.register('rde_shops:server:getAnalytics', function(source, shopId)
    if not hasPermission(source) then return nil end
    if not shops[shopId] then return nil end

    local result = MySQL.query.await([[
        SELECT transaction_type, COUNT(*) AS count, SUM(amount) AS total, AVG(amount) AS average
        FROM rde_shop_analytics WHERE shop_id = ? GROUP BY transaction_type
    ]], {shopId})

    local analytics = {
        totalRevenue   = 0,
        totalPurchases = 0,
        totalRobberies = 0,
        avgTransaction = 0,
        reputation     = shops[shopId].reputation,
        tillMoney      = shops[shopId].tillMoney
    }

    if result then
        for _, row in ipairs(result) do
            if row.transaction_type == 'purchase' then
                analytics.totalRevenue   = row.total or 0
                analytics.totalPurchases = row.count or 0
                analytics.avgTransaction = math.floor(row.average or 0)
            elseif row.transaction_type == 'robbery' then
                analytics.totalRobberies = row.count or 0
            end
        end
    end

    return analytics
end)

-- =============================================
-- PLAYER EVENTS
-- =============================================
AddEventHandler('ox:playerLogout', function(playerId)
    playerPermissions[playerId] = nil
end)

AddEventHandler('playerDropped', function()
    playerPermissions[source] = nil
end)

local function buildShopSnapshot()
    local snapshot = {}
    for shopId, shop in pairs(shops) do
        snapshot[shopId] = {
            id         = shop.id,
            name       = shop.name,
            blipName   = shop.blipName,
            pedModel   = shop.pedModel,
            coords     = {x = shop.coords.x, y = shop.coords.y, z = shop.coords.z, w = shop.coords.w},
            category   = shop.category,
            blipSprite = shop.blipSprite,
            blipColor  = shop.blipColor,
            tillMoney  = shop.tillMoney,
            reputation = shop.reputation,
            lastRobbed = shop.lastRobbed,
        }
    end
    return snapshot
end

local function sendShopsToPlayer(source)
    TriggerClientEvent('rde_shops:client:syncAllShops', source, buildShopSnapshot())
    debugPrint('Sent all shops to player', source)
end

AddEventHandler('ox:playerLoaded', function(playerId, userId, charId)
    playerPermissions[playerId] = nil
    if not shopsReady then
        -- loadShops() still running (DB + ox_inventory init), queue the player
        table.insert(pendingPlayers, playerId)
        debugPrint('ox:playerLoaded → shops not ready yet, queued player', playerId)
    else
        sendShopsToPlayer(playerId)
        debugPrint('ox:playerLoaded → shops sent to', playerId)
    end
end)

lib.callback.register('rde_shops:server:getAllShops', function(source)
    return buildShopSnapshot()
end)

-- =============================================
-- INITIALIZATION
-- =============================================
CreateThread(function()
    initDatabase()
    Wait(1000)
    loadShops()
    Wait(500)
    -- Register hooks AFTER ox_inventory is ready
    registerInventoryHooks()
    debugPrint('Server initialized successfully ✓')
end)

-- =============================================
-- PASSIVE TILL INCOME
-- =============================================
CreateThread(function()
    Wait(10000)
    local cfg = Config.Shops.till.passiveIncome
    if not cfg or not cfg.enabled then return end
    local intervalMs = (cfg.interval or 300) * 1000
    while true do
        Wait(intervalMs)
        for shopId, shop in pairs(shops) do
            if shop.tillMoney < Config.Shops.till.maxTillMoney then
                local amount = math.random(cfg.minAmount, cfg.maxAmount)
                shop.tillMoney = math.min(shop.tillMoney + amount, Config.Shops.till.maxTillMoney)
                MySQL.query('UPDATE rde_shops SET till_money = ? WHERE id = ?', {shop.tillMoney, shopId})
                debugPrint('Passive income: shop', shopId, '+$' .. amount)
            end
        end
    end
end)

-- =============================================
-- AUTO-RESTOCK
-- =============================================
CreateThread(function()
    Wait(15000)
    local cfg = Config.Shops.restock
    if not cfg or not cfg.enabled then return end
    local intervalMs = (cfg.interval or 600) * 1000
    while true do
        Wait(intervalMs)
        for shopId in pairs(shops) do
            local rows = MySQL.query.await([[
                SELECT item_name, quantity FROM rde_shop_prices
                WHERE shop_id = ? AND quantity < ?
            ]], {shopId, cfg.maxStock})
            if rows and #rows > 0 then
                for _, row in ipairs(rows) do
                    local newQty = math.min(row.quantity + math.random(cfg.amountMin, cfg.amountMax), cfg.maxStock)
                    MySQL.query(
                        'UPDATE rde_shop_prices SET quantity = ? WHERE shop_id = ? AND item_name = ?',
                        {newQty, shopId, row.item_name}
                    )
                end
                refreshOxShop(shopId)
                debugPrint('Restocked shop', shopId, '—', #rows, 'items topped up')
            end
        end
    end
end)

print('^2[RDE | SHOPS V4.7]^7 Server loaded ✓')
