-- RDE Advanced Shop System V3.1.0 - Server
-- Framework: ox_core v2 + ox_inventory
-- FIXES: Critical shop open bug, all missing callbacks, police alert, payout return

local shops = {}             -- Alle Shops (ID als Key)
local robberyStates = {}     -- Aktive Raubüberfälle (ShopID als Key)
local playerPermissions = {} -- Cached Player-Permissions (source als Key)
local deadPeds = {}          -- Tote Peds für Respawn-Logik

-- =============================================
-- UTILITY FUNCTIONS
-- =============================================
local function debugPrint(...)
    if Config.Debug then
        print('[RDE Shops - Server]', ...)
    end
end

local function getPlayerFromId(source)
    local player = Ox.GetPlayer(source)
    if not player then
        debugPrint('Player not found for source:', source)
        return nil
    end
    return player
end

local function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- =============================================
-- STATEBAG SYSTEM (REALTIME SYNC)
-- =============================================
local function syncShopStateBag(shopId)
    local shop = shops[shopId]
    if not shop then return end

    GlobalState['rde_shop_' .. shopId] = {
        id          = shop.id,
        name        = shop.name,
        blipName    = shop.blipName,
        pedModel    = shop.pedModel,
        coords      = {x = shop.coords.x, y = shop.coords.y, z = shop.coords.z, w = shop.coords.w},
        category    = shop.category,
        blipSprite  = shop.blipSprite,
        blipColor   = shop.blipColor,
        tillMoney   = shop.tillMoney,
        reputation  = shop.reputation,
        lastRobbed  = shop.lastRobbed,
        isBeingRobbed = robberyStates[shopId] ~= nil,
        pedDead     = deadPeds[shopId] ~= nil
    }

    debugPrint('Synced shop', shopId, 'via StateBag')
end

local function syncAllShopsStateBag()
    local shopList = {}
    for shopId in pairs(shops) do
        table.insert(shopList, shopId)
    end
    GlobalState.rde_shop_list = shopList

    for shopId in pairs(shops) do
        syncShopStateBag(shopId)
    end

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
    for _, acePermission in ipairs(Config.AcePermissions) do
        if IsPlayerAceAllowed(source, acePermission) then return true end
    end
    return false
end

local function hasPermission(source)
    if playerPermissions[source] ~= nil then
        return playerPermissions[source]
    end

    local hasPerms = checkAcePermissions(source)

    if not hasPerms then
        local player = getPlayerFromId(source)
        if player then
            hasPerms = checkOxCoreGroups(player)
        end
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
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `name`       VARCHAR(100) NOT NULL,
            `blip_name`  VARCHAR(100) NOT NULL,
            `ped_model`  VARCHAR(50)  NOT NULL,
            `coords`     VARCHAR(100) NOT NULL,
            `heading`    FLOAT        NOT NULL DEFAULT 0,
            `category`   VARCHAR(50)  DEFAULT 'general',
            `blip_sprite` INT         DEFAULT 52,
            `blip_color`  INT         DEFAULT 2,
            `till_money`  INT         DEFAULT 0,
            `reputation`  INT         DEFAULT 0,
            `last_robbed` BIGINT      DEFAULT 0,
            `created_at`  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
            `updated_at`  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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

    -- Migration: add quantity column for existing installs that predate V3.1
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
-- OX_INVENTORY INTEGRATION  (V3.2 — DB-Only)
-- =============================================
-- Items + quantities live exclusively in rde_shop_prices.
-- No ox_inventory stash is involved for stock management.
-- This means every add/edit/remove instantly updates the shop
-- with zero sync gaps.

local function getOxShopId(shopId)
    return 'rde_shop_' .. shopId
end

-- Read items for a shop straight from DB (quantity > 0 only)
local function getShopItemsFromDB(shopId)
    local rows = MySQL.query.await(
        'SELECT item_name, price, quantity FROM rde_shop_prices WHERE shop_id = ? AND quantity > 0',
        {shopId}
    )
    local result = {}
    if rows then
        for _, row in ipairs(rows) do
            table.insert(result, {
                item_name = row.item_name,
                price     = row.price,
                count     = row.quantity,
            })
        end
    end
    return result
end

-- Apply reputation multiplier to a price
local function getPriceWithReputation(shopId, basePrice)
    local shop = shops[shopId]
    if not shop or not Config.Shops.reputation.enabled then return basePrice end

    local rep     = shop.reputation
    local maxRep  = Config.Shops.reputation.maxRep
    local minRep  = Config.Shops.reputation.minRep
    local maxMult = Config.Shops.reputation.priceMultiplierMax
    local minMult = Config.Shops.reputation.priceMultiplierMin

    local repPercent = (rep - minRep) / (maxRep - minRep)
    repPercent = math.max(0.0, math.min(1.0, repPercent))
    local multiplier = minMult - (minMult - maxMult) * repPercent
    return math.max(1, math.floor(basePrice * multiplier))
end

-- Rebuild ox_inventory shop definition from DB — call after ANY stock/price change
local function refreshOxShop(shopId)
    local shop = shops[shopId]
    if not shop then return end

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

    -- NOTE: No 'locations' field here.
    -- When using ox_target to open shops we call forceOpenInventory on the server,
    -- which bypasses ox_inventory's distance check entirely. Passing locations would
    -- cause the "Du hast keinen Zugang" error because the server-side distance check
    -- compares player position against those coords and blocks access via ox_target.
    exports.ox_inventory:RegisterShop(oxShopId, {
        name      = shop.blipName,
        inventory = inventory,
    })

    debugPrint('ox shop refreshed:', oxShopId, '— Items:', #inventory)
end

-- =============================================
-- SHOP LOADING & INITIALIZATION
-- =============================================
local function loadShops()
    local result = MySQL.query.await('SELECT * FROM rde_shops')
    if not result then
        debugPrint('No shops found or DB error')
        return
    end

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

        -- Register as ox_inventory shop (customer buying UI)
        refreshOxShop(shopData.id)
    end

    syncAllShopsStateBag()
    debugPrint('Loaded', tableCount(shops), 'shops')
end

-- =============================================
-- PERMISSION CALLBACKS
-- =============================================

-- FIX: Client calls 'checkAdminPermission' on init — was not registered before
lib.callback.register('rde_shops:server:checkAdminPermission', function(source)
    return hasPermission(source)
end)

-- Alias kept for backwards compatibility
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

    local insertId = MySQL.insert.await([[
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

    if not insertId then
        return {success = false, message = 'Database error'}
    end

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
    syncAllShopsStateBag()
    return {success = true, shopId = insertId}
end)

lib.callback.register('rde_shops:server:deleteShop', function(source, shopId)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end

    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end

    -- Items are deleted via CASCADE on rde_shop_prices FK
    MySQL.query.await('DELETE FROM rde_shops WHERE id = ?', {shopId})

    shops[shopId] = nil
    robberyStates[shopId] = nil
    deadPeds[shopId] = nil
    GlobalState['rde_shop_' .. shopId] = nil

    syncAllShopsStateBag()
    debugPrint('Shop deleted: ID', shopId)
    return {success = true}
end)

lib.callback.register('rde_shops:server:updateShop', function(source, shopId, data)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end

    if not shops[shopId] or not data then
        return {success = false, message = 'Invalid data'}
    end

    MySQL.query.await([[
        UPDATE rde_shops
        SET name = ?, blip_name = ?, ped_model = ?, category = ?, blip_sprite = ?, blip_color = ?
        WHERE id = ?
    ]], {
        data.name,
        data.blipName or data.name,
        data.pedModel,
        data.category or 'general',
        data.blipSprite or 52,
        data.blipColor or 2,
        shopId
    })

    shops[shopId].name       = data.name
    shops[shopId].blipName   = data.blipName or data.name
    shops[shopId].pedModel   = data.pedModel
    shops[shopId].category   = data.category or 'general'
    shops[shopId].blipSprite = data.blipSprite or 52
    shops[shopId].blipColor  = data.blipColor or 2

    -- Refresh ox_inventory shop registration with new name
    refreshOxShop(shopId)
    syncShopStateBag(shopId)
    return {success = true}
end)

-- =============================================
-- INVENTORY CALLBACKS
-- =============================================

-- Customer opens the shop to buy items
-- Customer opens shop.
-- IMPORTANT: forceOpenInventory does NOT support 'shop' as invType (not in the type list).
-- The only working method is the CLIENT export openInventory('shop', { type = id }).
-- We validate + refresh on the server, then trigger a client event to open the UI.
lib.callback.register('rde_shops:server:openShopInventory', function(source, shopId)
    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end

    local items = getShopItemsFromDB(shopId)
    if #items == 0 then
        return {success = false, message = L('shop_empty')}
    end

    -- Rebuild shop definition so stock/prices are current
    refreshOxShop(shopId)

    -- Tell the client to open the shop UI directly.
    -- No 'locations' in RegisterShop → no distance check → no "kein Zugang" error.
    TriggerClientEvent('rde_shops:client:doOpenShop', source, getOxShopId(shopId))

    return {success = true}
end)

-- Get all shop items (for admin UI)
lib.callback.register('rde_shops:server:getShopItems', function(source, shopId)
    if not hasPermission(source) then return nil end
    if not shops[shopId] then return nil end
    -- Return ALL items including quantity 0 so admin can see the full list
    local rows = MySQL.query.await(
        'SELECT item_name, price, quantity FROM rde_shop_prices WHERE shop_id = ?',
        {shopId}
    )
    local result = {}
    if rows then
        for _, row in ipairs(rows) do
            table.insert(result, {
                item_name = row.item_name,
                price     = row.price,
                count     = row.quantity,
            })
        end
    end
    return result
end)

-- Add or update a shop item (item_name + quantity + price)
lib.callback.register('rde_shops:server:addShopItem', function(source, shopId, itemName, quantity, price)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end
    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end
    if type(itemName) ~= 'string' or itemName == '' then
        return {success = false, message = 'Invalid item name'}
    end
    if type(quantity) ~= 'number' or quantity < 1 then
        return {success = false, message = 'Quantity must be at least 1'}
    end
    if type(price) ~= 'number' or price < 0 then
        return {success = false, message = L('invalid_amount')}
    end

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

-- Update price and/or quantity for an existing item
lib.callback.register('rde_shops:server:updateShopItem', function(source, shopId, itemName, quantity, price)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end
    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end
    if type(quantity) ~= 'number' or quantity < 0 then
        return {success = false, message = 'Invalid quantity'}
    end
    if type(price) ~= 'number' or price < 0 then
        return {success = false, message = L('invalid_amount')}
    end

    MySQL.query.await(
        'UPDATE rde_shop_prices SET price = ?, quantity = ? WHERE shop_id = ? AND item_name = ?',
        {price, quantity, shopId, itemName}
    )

    refreshOxShop(shopId)
    debugPrint('Updated', itemName, 'in shop', shopId, '— qty:', quantity, 'price: $' .. price)
    return {success = true}
end)

-- Remove an item entirely from a shop
lib.callback.register('rde_shops:server:removeShopItem', function(source, shopId, itemName)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end
    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end

    MySQL.query.await(
        'DELETE FROM rde_shop_prices WHERE shop_id = ? AND item_name = ?',
        {shopId, itemName}
    )

    refreshOxShop(shopId)
    debugPrint('Removed', itemName, 'from shop', shopId)
    return {success = true}
end)

-- Legacy: set only the price (kept for backwards compat)
lib.callback.register('rde_shops:server:setItemPrice', function(source, shopId, itemName, price)
    if not hasPermission(source) then
        return {success = false, message = L('no_permission')}
    end
    if not shops[shopId] then
        return {success = false, message = 'Shop not found'}
    end
    if type(price) ~= 'number' or price < 0 then
        return {success = false, message = L('invalid_amount')}
    end

    MySQL.query.await(
        'UPDATE rde_shop_prices SET price = ? WHERE shop_id = ? AND item_name = ?',
        {price, shopId, itemName}
    )

    refreshOxShop(shopId)
    return {success = true}
end)

-- =============================================
-- ox_inventory PURCHASE HOOK
-- =============================================
AddEventHandler('ox_inventory:buyItem', function(source, shopId, itemName, count, price, currency)
    local numericId = tonumber(shopId:match('^rde_shop_(%d+)$'))
    if not numericId or not shops[numericId] then return end

    local shop      = shops[numericId]
    local totalCost = (price or 0) * (count or 1)

    -- Accumulate till money
    shop.tillMoney = math.min(
        shop.tillMoney + math.floor(totalCost * Config.Shops.till.moneyAccumulationRate),
        Config.Shops.till.maxTillMoney
    )

    -- Decrement stock in DB (not a stash)
    MySQL.query([[
        UPDATE rde_shop_prices
        SET quantity = GREATEST(0, quantity - ?)
        WHERE shop_id = ? AND item_name = ?
    ]], {count, numericId, itemName})

    MySQL.query('UPDATE rde_shops SET till_money = ? WHERE id = ?', {shop.tillMoney, numericId})

    -- Reputation
    if Config.Shops.reputation.enabled then
        shop.reputation = math.min(
            shop.reputation + Config.Shops.reputation.repGainPerPurchase,
            Config.Shops.reputation.maxRep
        )
        MySQL.query('UPDATE rde_shops SET reputation = ? WHERE id = ?', {shop.reputation, numericId})
    end

    -- Analytics
    if Config.Shops.analytics.trackPurchases then
        MySQL.insert('INSERT INTO rde_shop_analytics (shop_id, transaction_type, amount, item_name) VALUES (?, ?, ?, ?)',
            {numericId, 'purchase', totalCost, itemName})
    end

    -- Refresh shop so updated stock is reflected
    refreshOxShop(numericId)
    syncShopStateBag(numericId)

    -- Visual feedback for nearby shop ped
    TriggerClientEvent('rde_shops:client:showPurchaseEffect', source, numericId)

    debugPrint('Purchase:', itemName, 'x' .. count, 'for $' .. totalCost, 'at shop', numericId)
end)

-- =============================================
-- ROBBERY SYSTEM
-- =============================================

-- FIX: Client calls this but it was never registered on the server
lib.callback.register('rde_shops:server:checkRobbery', function(source, shopId)
    local shop = shops[shopId]
    if not shop then
        return {success = false, message = 'Shop not found'}
    end

    -- Check cooldown
    local currentTime = os.time()
    if currentTime - shop.lastRobbed < Config.Robbery.cooldown then
        return {success = false, message = L('robbery_cooldown')}
    end

    -- Check till
    if shop.tillMoney <= 0 then
        return {success = false, message = L('till_empty')}
    end

    -- Already being robbed
    if robberyStates[shopId] then
        return {success = false, message = 'Already being robbed'}
    end

    -- Check min police
    local copsNearby = 0
    local shopCoords = shop.coords
    for _, playerId in ipairs(GetPlayers()) do
        local targetPlayer = getPlayerFromId(tonumber(playerId))
        if targetPlayer then
            local job = targetPlayer.get and targetPlayer.get('job')
            if job and job.name then
                for _, policeJob in ipairs(Config.Robbery.policeJobs) do
                    if job.name == policeJob then
                        local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(playerId)))
                        local dist = #(vec3(shopCoords.x, shopCoords.y, shopCoords.z) - playerCoords)
                        if dist < Config.Robbery.dispatchRadius then
                            copsNearby = copsNearby + 1
                        end
                        break
                    end
                end
            end
        end
    end

    if copsNearby < Config.Robbery.minPolice then
        return {success = false, message = L('not_enough_police')}
    end

    -- Calculate required aim time (increases with cops nearby)
    local requiredTime = Config.Robbery.aimTime
    if Config.Robbery.progressive.enabled then
        requiredTime = requiredTime + (copsNearby * Config.Robbery.progressive.timeIncreasePerCop)
    end

    return {
        success      = true,
        requiredTime = requiredTime * 1000, -- Convert to ms for client
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

    local payout = math.floor(shop.tillMoney * Config.Robbery.payoutPercentage)
    payout = math.max(Config.Robbery.minPayout, math.min(payout, Config.Robbery.maxPayout))

    local player = getPlayerFromId(source)
    if not player then return end

    player.addMoney('money', payout)

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

    -- Police Alert
    if Config.Robbery.policeNotify then
        local alertData = {
            coords   = {x = shop.coords.x, y = shop.coords.y, z = shop.coords.z},
            shopName = shop.blipName
        }
        for _, playerId in ipairs(GetPlayers()) do
            local targetPlayer = getPlayerFromId(tonumber(playerId))
            if targetPlayer then
                local job = targetPlayer.get and targetPlayer.get('job')
                if job and job.name then
                    for _, policeJob in ipairs(Config.Robbery.policeJobs) do
                        if job.name == policeJob then
                            -- FIX: Send as single table (not two separate args)
                            TriggerClientEvent('rde_shops:client:policeAlert', playerId, alertData)
                            break
                        end
                    end
                end
            end
        end
    end

    robberyStates[shopId] = nil
    syncShopStateBag(shopId)

    -- FIX: Include payout in response so client can display it
    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Shop System',
        description = string.format(L('robbery_success'), payout),
        type        = 'success'
    })

    -- Respawn the shopkeeper after configured time
    TriggerClientEvent('rde_shops:client:robberyComplete', source, shopId)

    debugPrint('Robbery completed at shop', shopId, '— Payout: $' .. payout)
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

-- FIX: Client calls 'getTillMoney' — register both names to be safe
lib.callback.register('rde_shops:server:getTillMoney', function(source, shopId)
    if not hasPermission(source) then return {success = false, message = L('no_permission')} end
    local shop = shops[shopId]
    if not shop then return {success = false, message = 'Shop not found'} end
    return {success = true, amount = shop.tillMoney}
end)

-- Original name kept as alias
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

    local amount   = shop.tillMoney
    player.addMoney('money', amount)
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
        SELECT
            transaction_type,
            COUNT(*)    AS count,
            SUM(amount) AS total,
            AVG(amount) AS average
        FROM rde_shop_analytics
        WHERE shop_id = ?
        GROUP BY transaction_type
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
-- INITIALIZATION
-- =============================================
CreateThread(function()
    initDatabase()
    Wait(1000)
    loadShops()
    debugPrint('Server initialized successfully ✓')
end)

-- =============================================
-- PASSIVE TILL INCOME
-- Simuliert NPC-Kunden — Kasse füllt sich auch
-- ohne echte Spielerkäufe langsam auf.
-- =============================================
CreateThread(function()
    Wait(10000) -- Warten bis loadShops fertig

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
                debugPrint('Passive income: shop', shopId, '+$'..amount, '→ till $'..shop.tillMoney)
            end
        end
    end
end)

-- =============================================
-- AUTO-RESTOCK
-- Jedes Item das Bestand < maxStock hat wird
-- periodisch um eine zufällige Menge aufgestockt.
-- =============================================
CreateThread(function()
    Wait(15000) -- Warten bis loadShops fertig

    local cfg = Config.Shops.restock
    if not cfg or not cfg.enabled then return end

    local intervalMs = (cfg.interval or 600) * 1000

    while true do
        Wait(intervalMs)

        for shopId in pairs(shops) do
            -- Alle Items dieses Shops lesen die noch nicht auf maxStock sind
            local rows = MySQL.query.await([[
                SELECT item_name, quantity FROM rde_shop_prices
                WHERE shop_id = ? AND quantity < ?
            ]], {shopId, cfg.maxStock})

            if rows and #rows > 0 then
                for _, row in ipairs(rows) do
                    local restockAmount = math.random(cfg.amountMin, cfg.amountMax)
                    local newQty = math.min(row.quantity + restockAmount, cfg.maxStock)

                    MySQL.query(
                        'UPDATE rde_shop_prices SET quantity = ? WHERE shop_id = ? AND item_name = ?',
                        {newQty, shopId, row.item_name}
                    )
                end

                -- Shop-Definition in ox_inventory neu aufbauen damit Kunden
                -- sofort den aktualisierten Stock sehen
                refreshOxShop(shopId)
                debugPrint('Restocked shop', shopId, '—', #rows, 'items topped up')
            end
        end
    end
end)

-- ox_core: fires when a character logs out
-- Docs: https://coxdocs.dev/ox_core/Events/server → ox:playerLogout
AddEventHandler('ox:playerLogout', function(playerId, userId, charId)
    playerPermissions[playerId] = nil
end)

-- Standard FiveM fallback
AddEventHandler('playerDropped', function()
    playerPermissions[source] = nil
end)

-- Helper: build a plain-table snapshot of all shops safe to send over network
-- (vector4 cannot cross the network boundary, so coords become plain tables)
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

-- Send all shops directly to a single player
local function sendShopsToPlayer(source)
    TriggerClientEvent('rde_shops:client:syncAllShops', source, buildShopSnapshot())
    debugPrint('Sent all shops to player', source)
end

-- ox_core: fires when a character has been selected and loaded
-- Docs: https://coxdocs.dev/ox_core/Events/server → ox:playerLoaded
AddEventHandler('ox:playerLoaded', function(playerId, userId, charId)
    playerPermissions[playerId] = nil
    sendShopsToPlayer(playerId)
    debugPrint('ox:playerLoaded — shops sent to', playerId)
end)

-- Fallback for servers that use different spawn events
lib.callback.register('rde_shops:server:getAllShops', function(source)
    return buildShopSnapshot()
end)

print('^2[RDE | SHOPS V3.2]^7 Server loaded ✓')