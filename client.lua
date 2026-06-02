-- ┌─────────────────────────────────────────────────────────────────────┐
-- │  RDE Advanced Shop System V4.8 — Client                             │
-- │  Framework : ox_core v2 + ox_inventory + ox_lib + ox_target         │
-- │  Author    : RDE Development | rd-elite.com                          │
-- │                                                                       │
-- │  FIX LOG V4.0:                                                        │
-- │  [#1] PED FLOATING IN AIR (spawn side):                              │
-- │       - z - 1.0 Offset ENTFERNT (falsch für alle Umgebungen)         │
-- │       - PlaceObjectOnGroundProperly() nach Spawn                      │
-- │       - Scenario starten VOR FreezeEntityPosition (Reihenfolge!)      │
-- │       - Wait(200) nach CreatePed für Physics-Settling                 │
-- │  [#2] openInventory('shop', {type=id}) → openInventory('shop', id)   │
-- │  [#3] rde_aipd: LogCrime('ROBBERY') bei Robbery Start                │
-- │  [#4] Drag & Drop Stash öffnen via openInventory('stash', ...)       │
-- │  [#5] promptStashItemPrice Listener für Preis-Dialog nach Drag-In    │
-- │                                                                       │
-- │  FIX LOG V4.8:                                                        │
-- │  [#6] PED FLOATING IN AIR (coord save side — ROOT CAUSE):            │
-- │       - GetEntityCoords(PlayerPedId()) gibt Körpermitte zurück        │
-- │         (~1.0–1.2 Units über dem Boden) → falscher Z in DB           │
-- │       - Fix: GetGroundZFor_3dCoord() nach GetEntityCoords()           │
-- │         liefert exakten Navmesh-Boden-Z für die gespeicherten Coords  │
-- │       - Gilt für createShop UND moveShop                              │
-- └─────────────────────────────────────────────────────────────────────┘

local shops             = {}     -- ID → shop table
local shopPeds          = {}     -- ID → ped entity
local shopBlips         = {}     -- ID → blip handle

local currentRobbery    = nil
local robberyInProgress = false
local robberyThread     = nil
local isAdmin           = false
local permissionChecked = false

local particleEffects   = {}

-- =============================================
-- UTILITY
-- =============================================
local function debugPrint(...)
    if Config.Debug then print('[RDE Shops - Client]', ...) end
end

local function notify(message, nType, duration)
    lib.notify({
        title       = 'Shop System',
        description = message,
        type        = nType or 'info',
        position    = 'top',
        duration    = duration or 4000
    })
end

local function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function playParticleEffect(coords, dict, name)
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeout = GetGameTimer() + 5000
        while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    end
    if not HasNamedPtfxAssetLoaded(dict) then return end
    UseParticleFxAssetNextCall(dict)
    local effect = StartParticleFxLoopedAtCoord(name, coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0, 1.0, false, false, false, false)
    table.insert(particleEffects, effect)
    return effect
end

local function clearParticleEffects()
    for _, effect in ipairs(particleEffects) do StopParticleFxLooped(effect, false) end
    particleEffects = {}
end

-- =============================================
-- PED MANAGEMENT — PED FLOATING FIX
-- =============================================
-- [FIX #1] The original code used z - 1.0 which placed the ped at the wrong
-- height in many locations (indoors, elevated terrain, etc.), causing the
-- "swimming in the air" visual bug. Fixes applied:
--   1. Spawn at exact Z from config (no offset)
--   2. Wait(200) after CreatePed — lets the physics engine settle the ped
--   3. PlaceObjectOnGroundProperly() — snaps ped to navmesh/ground surface
--   4. Start scenario BEFORE FreezeEntityPosition — this is critical:
--      freezing BEFORE scenario causes the walking anim to loop while frozen,
--      which looks like "swimming". Starting scenario first then freezing
--      locks the scenario's idle pose instead.
local function createShopPed(shopId, shop)
    if not shop then return end

    -- Clean up any existing ped for this shop
    if shopPeds[shopId] and DoesEntityExist(shopPeds[shopId]) then
        exports.ox_target:removeLocalEntity(shopPeds[shopId])
        DeleteEntity(shopPeds[shopId])
        shopPeds[shopId] = nil
    end

    local pedModel = GetHashKey(shop.pedModel)
    if not IsModelInCdimage(pedModel) then
        debugPrint('ERROR: Ped model not in game files:', shop.pedModel)
        return
    end

    if not lib.requestModel(pedModel, 5000) then
        debugPrint('ERROR: Failed to load ped model:', shop.pedModel)
        return
    end

    -- CORRECT ped spawn approach (same method ox_inventory uses for its own shop peds):
    --
    -- The stored Z comes from GetEntityCoords(PlayerPedId()) when the admin created
    -- the shop — that IS the foot-level floor Z. Using it exactly is correct.
    --
    -- z + 0.5 + Wait(600) unfrozen was WRONG:
    --   • In GTA interiors the collision mesh may not be loaded yet → ped falls through
    --   • Unfrozen peds in interiors can drift / get pushed by ambient physics
    --   • 600ms blocks the thread = 6 frames frozen out of ped logic
    --
    -- Correct order: spawn → flags → FreezeEntityPosition → TaskStartScenarioInPlace
    -- Freezing first at the correct Z keeps the ped exactly where the admin placed it.
    -- The scenario then plays its idle animation while frozen — no swimming.
    local ped = CreatePed(
        4,
        pedModel,
        shop.coords.x,
        shop.coords.y,
        shop.coords.z,   -- exact stored Z (admin foot-level = correct floor Z)
        shop.coords.w,
        false,
        true
    )

    if not DoesEntityExist(ped) then
        debugPrint('ERROR: Failed to create ped for shop:', shopId)
        SetModelAsNoLongerNeeded(pedModel)
        return
    end

    SetModelAsNoLongerNeeded(pedModel)
    SetEntityAsMissionEntity(ped, true, true)

    -- Behaviour flags
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5,  false)
    SetPedConfigFlag(ped, 65,  true)
    SetPedConfigFlag(ped, 166, true)
    SetPedConfigFlag(ped, 229, true)
    SetPedConfigFlag(ped, 17,  false)
    SetEntityInvincible(ped, false)
    SetPedRelationshipGroupHash(ped, GetHashKey('CIVMALE'))

    -- 1. Freeze first — locks ped at the correct floor Z immediately
    FreezeEntityPosition(ped, Config.Shops.ped.frozen)
    -- 2. Then start scenario — plays idle anim while frozen, no swimming
    if Config.Shops.ped.scenario then
        TaskStartScenarioInPlace(ped, Config.Shops.ped.scenario, 0, true)
    end

    shopPeds[shopId] = ped

    -- ox_target interaction zones
    local catCfg = shop.category and Config.ShopCategories[shop.category]
    local icon   = catCfg and catCfg.icon or Config.Shops.interaction.icon

    exports.ox_target:addLocalEntity(ped, {
        {
            name     = 'rde_shop_browse_' .. shopId,
            icon     = icon,
            label    = '🛒 ' .. shop.blipName,
            distance = Config.Shops.interaction.distance,
            onSelect = function() openShopInventory(shopId) end
        },
        {
            name     = 'rde_shop_manage_' .. shopId,
            icon     = 'fas fa-toolbox',
            label    = '⚙️ Shop Management',
            distance = Config.Shops.interaction.distance,
            canInteract = function() return isAdmin end,
            onSelect = function() openAdminMenu(shopId) end
        }
    })

    debugPrint('Created ped for shop:', shopId, '— Model:', shop.pedModel)
end

-- =============================================
-- PED KILL & RESPAWN
-- =============================================
local function killAndRespawnPed(shopId, shop)
    local ped = shopPeds[shopId]
    if not ped or not DoesEntityExist(ped) then return end

    ClearPedTasks(ped)
    SetEntityHealth(ped, 0)
    SetEntityInvincible(ped, false)

    SetTimeout(Config.Shops.ped.deadPedCleanupTime, function()
        if DoesEntityExist(ped) then
            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
        end
        shopPeds[shopId] = nil
        debugPrint('Ped corpse cleaned up for shop:', shopId)

        local remainingTime = math.max(0, Config.Shops.ped.respawnTime - Config.Shops.ped.deadPedCleanupTime)
        SetTimeout(remainingTime, function()
            if shops[shopId] and not shopPeds[shopId] then
                CreateThread(function()
                    createShopPed(shopId, shops[shopId])
                end)
                debugPrint('Ped respawned for shop:', shopId)
            end
        end)
    end)
end

-- =============================================
-- BLIP MANAGEMENT
-- =============================================
local function createShopBlip(shopId, shop)
    if not Config.Shops.blip.enabled then return end

    if shopBlips[shopId] then RemoveBlip(shopBlips[shopId]) end

    local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
    SetBlipSprite(blip, shop.blipSprite or 52)
    SetBlipColour(blip, shop.blipColor or 2)
    SetBlipScale(blip, Config.Shops.blip.scale)
    SetBlipDisplay(blip, Config.Shops.blip.display)
    SetBlipAsShortRange(blip, Config.Shops.blip.shortRange)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shop.blipName)
    EndTextCommandSetBlipName(blip)

    shopBlips[shopId] = blip
    debugPrint('Created blip for shop:', shopId)
end

local function deleteShop(shopId)
    if shopPeds[shopId] then
        if DoesEntityExist(shopPeds[shopId]) then
            exports.ox_target:removeLocalEntity(shopPeds[shopId])
            DeleteEntity(shopPeds[shopId])
        end
        shopPeds[shopId] = nil
    end
    if shopBlips[shopId] then
        RemoveBlip(shopBlips[shopId])
        shopBlips[shopId] = nil
    end
    shops[shopId] = nil
    debugPrint('Deleted local shop:', shopId)
end

-- =============================================
-- SHOP BROWSING — CUSTOMER BUY
-- =============================================
function openShopInventory(shopId)
    local shop = shops[shopId]
    if not shop then return end

    lib.callback('rde_shops:server:openShopInventory', false, function(result)
        if not result or not result.success then
            notify(result and result.message or 'Failed to open shop', 'error')
        end
        -- Server triggers rde_shops:client:doOpenShop to actually open the UI
    end, shopId)
end

-- [FIX v4.8] CRITICAL: ox_inventory's openShop callback expects data as a TABLE
-- with `.type` field, NOT a raw string. Sending a string makes `data.type` nil
-- on the server side, which causes `Shops[nil]` lookup to fail and triggers the
-- "You can not open this inventory" notification.
--
-- See ox_inventory/modules/shops/server.lua line 121-127:
--   lib.callback.register('ox_inventory:openShop', function(source, data)
--       ...
--       if data then
--           shop = Shops[data.type]   ← needs table with .type field
--           if not shop then return end
--
-- ❌ Old (v4.7): openInventory('shop', oxShopId)               -- breaks customer buy
-- ✅ New (v4.8): openInventory('shop', { type = oxShopId, id = 1 })
--
-- The `id = 1` matches the first entry in `locations` array on the server-side
-- RegisterShop call. This also enables ox_inventory's built-in distance check
-- and proper shopType/shopId parsing in the buyItem hook.
RegisterNetEvent('rde_shops:client:doOpenShop', function(oxShopId, instanceId)
    exports.ox_inventory:openInventory('shop', {
        type = oxShopId,
        id   = instanceId or 1,
    })
end)

-- [NEW #4] Open the drag-and-drop stock stash for admin management
RegisterNetEvent('rde_shops:client:doOpenStash', function(stashId)
    -- CORRECT ox_inventory stash open API per docs:
    -- openInventory('stash', {id = stashId}) NOT openInventory('stash', stashId)
    exports.ox_inventory:openInventory('stash', {id = stashId})
end)

-- =============================================
-- STOCK MANAGEMENT (text menu + drag & drop)
-- =============================================
function openStockManagement(shopId)
    if not isAdmin then notify(L('no_permission'), 'error') return end

    lib.callback('rde_shops:server:getShopItems', false, function(items)
        local allItems = exports.ox_inventory:Items()
        local options  = {}

        table.insert(options, {
            title       = '📦 Drag & Drop Stock',
            description = 'Open ox_inventory stash — drag items in to add stock',
            icon        = 'inbox',
            iconColor   = '#8b5cf6',
            onSelect    = function()
                lib.callback('rde_shops:server:openStockStash', false, function(result)
                    if not result or not result.success then
                        notify(result and result.message or 'Failed to open stash', 'error')
                    end
                end, shopId)
            end
        })

        table.insert(options, {
            title       = '➕ Add Item (Manual)',
            description = 'Add by item name, quantity and price',
            icon        = 'plus',
            iconColor   = '#10b981',
            onSelect    = function() addShopItemDialog(shopId) end
        })

        if items and #items > 0 then
            for _, itemData in ipairs(items) do
                local info  = allItems and allItems[itemData.item_name]
                local label = info and info.label or itemData.item_name
                local image = info and info.client and info.client.image or nil

                table.insert(options, {
                    title       = label,
                    description = 'Stock: ' .. itemData.count .. '   Price: $' .. itemData.price,
                    icon        = 'box',
                    image       = image,
                    iconColor   = itemData.count > 0 and '#3b82f6' or '#ef4444',
                    metadata    = {
                        {label = 'Item ID',  value = itemData.item_name},
                        {label = 'In Stock', value = itemData.count},
                        {label = 'Price',    value = '$' .. itemData.price}
                    },
                    onSelect = function()
                        editShopItemDialog(shopId, itemData.item_name, itemData.count, itemData.price, label)
                    end
                })
            end
        else
            table.insert(options, {
                title       = '📭 No items yet',
                description = 'Drag items via the stash or press "Add Item (Manual)"',
                icon        = 'info',
                iconColor   = '#6b7280',
                disabled    = true
            })
        end

        lib.registerContext({
            id      = 'rde_stock_mgmt',
            title   = '📦 Stock — ' .. (shops[shopId] and shops[shopId].name or 'Shop'),
            menu    = 'rde_shop_admin',
            options = options
        })
        lib.showContext('rde_stock_mgmt')
    end, shopId)
end

function addShopItemDialog(shopId)
    local input = lib.inputDialog('➕ Add Item to Shop', {
        {type='input',  label='Item Name (internal ID)', description='Exact ox_inventory item name',
         placeholder='water', required=true, min=1, max=50},
        {type='number', label='Quantity in Stock', default=50, required=true, min=1, max=999999},
        {type='number', label='Price per Item ($)', default=10, required=true, min=1, max=999999}
    })
    if not input then lib.showContext('rde_stock_mgmt') return end

    lib.callback('rde_shops:server:addShopItem', false, function(result)
        if result and result.success then
            notify('Added ' .. input[2] .. 'x ' .. input[1] .. ' at $' .. input[3], 'success')
        else
            notify(result and result.message or 'Failed to add item', 'error')
        end
        Wait(200)
        openStockManagement(shopId)
    end, shopId, input[1], tonumber(input[2]), tonumber(input[3]))
end

function editShopItemDialog(shopId, itemName, currentQty, currentPrice, itemLabel)
    local input = lib.inputDialog('✏️ Edit: ' .. itemLabel, {
        {type='number', label='Quantity in Stock', description='Set to 0 to hide from customers',
         default=currentQty, required=true, min=0, max=999999},
        {type='number', label='Price ($)', default=currentPrice, required=true, min=0, max=999999}
    })
    if not input then lib.showContext('rde_stock_mgmt') return end

    if tonumber(input[1]) == 0 then
        local alert = lib.alertDialog({
            header   = '🗑️ Remove Item?',
            content  = 'Quantity is 0. Remove ' .. itemLabel .. ' entirely from the shop?',
            centered = true,
            cancel   = true,
            labels   = {confirm = 'Remove', cancel = 'Set to 0 (hidden)'}
        })
        if alert == 'confirm' then
            lib.callback('rde_shops:server:removeShopItem', false, function(result)
                notify(result and result.success and (itemLabel .. ' removed!') or 'Failed to remove',
                    result and result.success and 'success' or 'error')
                Wait(200)
                openStockManagement(shopId)
            end, shopId, itemName)
            return
        end
    end

    lib.callback('rde_shops:server:updateShopItem', false, function(result)
        if result and result.success then
            notify('Updated ' .. itemLabel .. ' — qty: ' .. input[1] .. '  price: $' .. input[2], 'success')
        else
            notify(result and result.message or 'Failed to update', 'error')
        end
        Wait(200)
        openStockManagement(shopId)
    end, shopId, itemName, tonumber(input[1]), tonumber(input[2]))
end

function openAdminShopInventory(shopId)
    openStockManagement(shopId)
end

-- =============================================
-- ADMIN MENU
-- =============================================
function openAdminMenu(shopId)
    if not isAdmin then notify(L('no_permission'), 'error') return end
    local shop = shops[shopId]
    if not shop then return end

    local catCfg   = shop.category and Config.ShopCategories[shop.category]
    local catLabel = catCfg and catCfg.label or 'Unknown'

    lib.registerContext({
        id    = 'rde_shop_admin',
        title = '🔧 ' .. shop.name .. ' — Management',
        options = {
            {
                title       = '📦 Manage Stock',
                description = 'Add/restock items — supports drag & drop via ox_inventory stash',
                icon        = 'boxes-stacked',
                iconColor   = '#8b5cf6',
                onSelect    = function() openStockManagement(shopId) end
            },
            {
                title       = '💰 Edit Prices',
                description = 'Update prices for existing stock',
                icon        = 'dollar-sign',
                iconColor   = '#10b981',
                onSelect    = function() openPriceManagement(shopId) end
            },
            {
                title       = '✏️ Edit Shop',
                description = 'Rename, change model or blip',
                icon        = 'pen',
                iconColor   = '#3b82f6',
                onSelect    = function() openEditShopMenu(shopId) end
            },
            {
                title       = '📊 Analytics',
                description = 'Revenue, purchases, robberies',
                icon        = 'chart-line',
                iconColor   = '#f59e0b',
                onSelect    = function() openAnalytics(shopId) end
            },
            {
                title       = '💵 Check Till',
                description = 'View current register balance',
                icon        = 'cash-register',
                iconColor   = '#f59e0b',
                onSelect    = function() checkTill(shopId) end
            },
            {
                title       = '💸 Empty Till',
                description = 'Collect accumulated money',
                icon        = 'money-bill-wave',
                iconColor   = '#10b981',
                onSelect    = function() emptyTill(shopId) end
            },
            {
                title       = '🗑️ Delete Shop',
                description = 'Permanently remove this shop',
                icon        = 'trash',
                iconColor   = '#ef4444',
                onSelect    = function() deleteShopConfirm(shopId) end
            }
        }
    })
    lib.showContext('rde_shop_admin')
end

-- =============================================
-- PRICE MANAGEMENT
-- =============================================
function openPriceManagement(shopId)
    lib.callback('rde_shops:server:getShopItems', false, function(items)
        if not items or #items == 0 then
            notify('No items in stock yet! Add via Manage Stock first.', 'info')
            return
        end

        local allItems = exports.ox_inventory:Items()
        local options  = {}

        for _, itemData in ipairs(items) do
            local itemInfo = allItems and allItems[itemData.item_name]
            local label    = itemInfo and itemInfo.label or itemData.item_name
            local image    = itemInfo and itemInfo.client and itemInfo.client.image or nil

            table.insert(options, {
                title       = label,
                description = 'Current Price: $' .. itemData.price,
                icon        = 'tag',
                image       = image,
                iconColor   = '#3b82f6',
                metadata    = {
                    {label = 'Stock', value = itemData.count},
                    {label = 'Price', value = '$' .. itemData.price}
                },
                onSelect = function()
                    setPriceForItem(shopId, itemData.item_name, itemData.price, label)
                end
            })
        end

        lib.registerContext({
            id      = 'rde_shop_prices',
            title   = '💰 Edit Prices — ' .. shops[shopId].name,
            menu    = 'rde_shop_admin',
            options = options
        })
        lib.showContext('rde_shop_prices')
    end, shopId)
end

function setPriceForItem(shopId, itemName, currentPrice, itemLabel)
    local input = lib.inputDialog('💰 Set Price: ' .. itemLabel, {
        {type='number', label='New Price ($)', description='Current: $' .. currentPrice,
         icon='dollar-sign', default=currentPrice, required=true, min=1, max=999999}
    })
    if not input then return end

    lib.callback('rde_shops:server:setItemPrice', false, function(result)
        if result and result.success then
            notify('Price updated to $' .. input[1], 'success')
            Wait(300)
            openPriceManagement(shopId)
        else
            notify(result and result.message or 'Failed to update price', 'error')
        end
    end, shopId, itemName, input[1])
end

-- =============================================
-- EDIT SHOP
-- =============================================
function openEditShopMenu(shopId)
    local shop = shops[shopId]
    if not shop then return end

    local categoryOptions = {}
    for key, data in pairs(Config.ShopCategories) do
        table.insert(categoryOptions, {label = data.label, value = key})
    end

    local input = lib.inputDialog('✏️ Edit Shop — ' .. shop.name, {
        {type='input',  label='Shop Name',   description='Internal name', default=shop.name,      required=true, min=3, max=50},
        {type='input',  label='Blip Name',   description='Map label',     default=shop.blipName,  required=true, min=3, max=50},
        {type='select', label='Ped Model',   description='Shopkeeper',    options=Config.PedModels,   default=shop.pedModel,         required=true, searchable=true},
        {type='select', label='Category',    description='Shop type',     options=categoryOptions,    default=shop.category or 'general', required=true},
        {type='select', label='Blip Sprite', description='Map icon',      options=Config.BlipSprites, default=shop.blipSprite or 52, required=true, searchable=true},
        {type='select', label='Blip Color',  description='Map color',     options=Config.BlipColors,  default=shop.blipColor or 2,   required=true}
    })
    if not input then return end

    lib.callback('rde_shops:server:updateShop', false, function(result)
        if result and result.success then
            notify('Shop updated!', 'success')
        else
            notify(result and result.message or 'Failed to update shop', 'error')
        end
    end, shopId, {
        name       = input[1],
        blipName   = input[2],
        pedModel   = input[3],
        category   = input[4],
        blipSprite = tonumber(input[5]),
        blipColor  = tonumber(input[6])
    })
end

-- =============================================
-- ANALYTICS
-- =============================================
function openAnalytics(shopId)
    lib.callback('rde_shops:server:getAnalytics', false, function(data)
        if not data then notify('Failed to load analytics', 'error') return end

        local rep      = data.reputation or 0
        local repColor = rep >= 50 and '#10b981' or (rep >= 0 and '#f59e0b' or '#ef4444')

        lib.registerContext({
            id    = 'rde_shop_analytics',
            title = '📊 Analytics — ' .. (shops[shopId] and shops[shopId].name or 'Shop'),
            menu  = 'rde_shop_admin',
            options = {
                {title='💰 Total Revenue',    description='$' .. (data.totalRevenue or 0),
                 icon='dollar-sign', iconColor='#10b981',
                 progress=math.min(100, ((data.totalRevenue or 0)/10000)*100), colorScheme='green'},
                {title='🛒 Total Purchases',  description=(data.totalPurchases or 0) .. ' transactions',
                 icon='shopping-cart', iconColor='#3b82f6'},
                {title='🎭 Total Robberies',  description=(data.totalRobberies or 0) .. ' robberies',
                 icon='mask', iconColor='#ef4444'},
                {title='📈 Avg. Transaction', description='$' .. (data.avgTransaction or 0),
                 icon='receipt', iconColor='#8b5cf6'},
                {title='⭐ Reputation',       description=rep .. ' / 100',
                 icon='star', iconColor=repColor,
                 progress=math.max(0, rep), colorScheme=rep >= 50 and 'green' or 'red'},
                {title='💵 Current Till',     description='$' .. (data.tillMoney or 0),
                 icon='cash-register', iconColor='#f59e0b'}
            }
        })
        lib.showContext('rde_shop_analytics')
    end, shopId)
end

-- =============================================
-- TILL
-- =============================================
function checkTill(shopId)
    lib.callback('rde_shops:server:getTillMoney', false, function(result)
        if result and result.success then
            notify('Till balance: $' .. result.amount, 'info')
        else
            notify(result and result.message or 'Failed to check till', 'error')
        end
    end, shopId)
end

function emptyTill(shopId)
    lib.callback('rde_shops:server:emptyTill', false, function(result)
        if result and result.success then
            notify('Collected $' .. result.amount .. ' from till!', 'success')
        else
            notify(result and result.message or 'Failed to empty till', 'error')
        end
    end, shopId)
end

-- =============================================
-- DELETE SHOP
-- =============================================
function deleteShopConfirm(shopId)
    local alert = lib.alertDialog({
        header   = '⚠️ Delete Shop',
        content  = 'Are you sure you want to permanently delete this shop? This cannot be undone!',
        centered = true,
        cancel   = true
    })
    if alert ~= 'confirm' then return end

    lib.callback('rde_shops:server:deleteShop', false, function(result)
        if result and result.success then
            notify('Shop deleted successfully!', 'success')
        else
            notify(result and result.message or 'Failed to delete shop', 'error')
        end
    end, shopId)
end

-- =============================================
-- ROBBERY SYSTEM — ENHANCED & FIXED
-- =============================================
local function isHoldingAllowedWeapon()
    local ped    = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    if weapon == GetHashKey('WEAPON_UNARMED') then return false end
    for _, allowedWeapon in ipairs(Config.Robbery.weaponTypes) do
        if weapon == GetHashKey(allowedWeapon) then return true end
    end
    return false
end

local function resetPedAfterRobbery(ped)
    if not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedConfigFlag(ped, 65,  true)
    SetPedConfigFlag(ped, 166, true)
    ClearPedTasks(ped)
    if Config.Shops.ped.scenario then
        TaskStartScenarioInPlace(ped, Config.Shops.ped.scenario, 0, true)
    end
end

local function startRobbery(shopId)
    if not Config.Robbery.enabled then return end
    if currentRobbery or robberyInProgress then return end

    local ped = shopPeds[shopId]
    if not ped or not DoesEntityExist(ped) then return end
    if not IsPlayerFreeAiming(PlayerId()) then return end
    if not isHoldingAllowedWeapon() then return end

    local _, targetPed = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if targetPed ~= ped then return end

    -- Guard set BEFORE async callback to block re-entry during server round-trip
    robberyInProgress = true

    lib.callback('rde_shops:server:checkRobbery', false, function(checkResult)
        if not checkResult or not checkResult.success then
            notify(checkResult and checkResult.message or L('robbery_failed'), 'error')
            robberyInProgress = false
            return
        end

        TriggerServerEvent('rde_shops:server:startRobbery', shopId)

        currentRobbery = {
            shopId       = shopId,
            startTime    = GetGameTimer(),
            ped          = ped,
            requiredTime = checkResult.requiredTime or (Config.Robbery.aimTime * 1000),
            copsNearby   = checkResult.copsNearby or 0
        }

        notify(L('robbery_started'), 'warning')
        if checkResult.copsNearby > 0 then
            notify(string.format(L('cops_nearby') .. ' — ' .. L('difficulty_increased'), checkResult.copsNearby), 'error')
        end

        -- [FIX #3] Notify rde_aipd of crime start (client-side)
        if GetResourceState('rde_aipd') == 'started' then
            local playerCoords = GetEntityCoords(PlayerPedId())
            pcall(function()
                exports['rde_aipd']:LogCrime('ROBBERY', playerCoords, true)
            end)
        end

        -- Hands up animation on clerk
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedConfigFlag(ped, 65,  true)
            SetPedConfigFlag(ped, 166, true)
            ClearPedTasks(ped)
            lib.requestAnimDict(Config.Shops.ped.handsUpDict)
            TaskPlayAnim(ped, Config.Shops.ped.handsUpDict, Config.Shops.ped.handsUpAnim,
                8.0, -8.0, -1, 49, 0, false, false, false)
        end

        robberyThread = CreateThread(function()
            while currentRobbery do
                Wait(100)
                local elapsed = GetGameTimer() - currentRobbery.startTime

                -- Cancel if player stops aiming or swaps weapon
                if not IsPlayerFreeAiming(PlayerId()) or not isHoldingAllowedWeapon() then
                    lib.hideTextUI()
                    notify(L('robbery_failed'), 'error')
                    TriggerServerEvent('rde_shops:server:cancelRobbery', shopId)
                    resetPedAfterRobbery(ped)
                    currentRobbery    = nil
                    robberyInProgress = false
                    break
                end

                -- Cancel if player looks away from the clerk
                local _, newTarget = GetEntityPlayerIsFreeAimingAt(PlayerId())
                if newTarget ~= ped then
                    lib.hideTextUI()
                    notify(L('robbery_failed'), 'error')
                    TriggerServerEvent('rde_shops:server:cancelRobbery', shopId)
                    resetPedAfterRobbery(ped)
                    currentRobbery    = nil
                    robberyInProgress = false
                    break
                end

                -- Kill switch: clerk dies mid-robbery
                if not DoesEntityExist(ped) or IsEntityDead(ped) then
                    lib.hideTextUI()
                    notify(L('clerk_killed'), 'warning')
                    TriggerServerEvent('rde_shops:server:cancelRobbery', shopId)
                    currentRobbery    = nil
                    robberyInProgress = false
                    break
                end

                if elapsed < currentRobbery.requiredTime then
                    local timeLeft = math.ceil((currentRobbery.requiredTime - elapsed) / 1000)
                    lib.showTextUI(string.format(L('keep_aiming_hands_up'), timeLeft), {
                        position  = 'left-center',
                        icon      = 'gun',
                        iconColor = 'red'
                    })
                else
                    lib.hideTextUI()
                    completeRobbery(shopId, ped)
                    currentRobbery    = nil
                    robberyInProgress = false
                    break
                end
            end

            lib.hideTextUI()
            robberyThread = nil
        end)
    end, shopId)
end

function completeRobbery(shopId, ped)
    -- Scared/submission anim on clerk
    if DoesEntityExist(ped) then
        lib.requestAnimDict(Config.Robbery.pedAnimDict)
        TaskPlayAnim(ped, Config.Robbery.pedAnimDict, Config.Robbery.pedAnimName,
            8.0, -8.0, -1, 49, 0, false, false, false)
    end

    if Config.Robbery.screenShake then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', Config.Robbery.screenShakeIntensity)
        SetTimeout(Config.Robbery.screenShakeDuration, function()
            StopGameplayCamShaking(true)
        end)
    end

    -- Server: payout + DB update + police alert + rde_aipd notification
    TriggerServerEvent('rde_shops:server:completeRobbery', shopId)
    -- robberyComplete event from server will trigger killAndRespawnPed (no double-respawn)
end

-- Robbery detection thread (runs at 500ms — low overhead)
CreateThread(function()
    while true do
        Wait(500)
        if not Config.Robbery.enabled or currentRobbery or robberyInProgress then goto continue_robbery end
        if not IsPlayerFreeAiming(PlayerId()) or not isHoldingAllowedWeapon() then goto continue_robbery end

        local hasTarget, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
        if hasTarget and targetEntity ~= 0 and IsEntityAPed(targetEntity) then
            for shopId, ped in pairs(shopPeds) do
                if ped == targetEntity and DoesEntityExist(ped) then
                    startRobbery(shopId)
                    break
                end
            end
        end

        ::continue_robbery::
    end
end)

-- =============================================
-- CREATE SHOP COMMAND
-- =============================================
RegisterCommand('createshop', function()
    if not isAdmin then
        notify('You do not have permission to create shops!', 'error')
        return
    end

    -- ── Schritt 1: Template wählen (optional) ─────────────────────────────
    -- Templates füllen den Shop automatisch mit Items.
    -- "none" = leerer Shop, Items manuell per ⚙️-Menü hinzufügen.
    local templateChoice = lib.inputDialog('📋 Shop Template', {
        {
            type        = 'select',
            label       = 'Template',
            description = 'Items werden automatisch geladen. Wähle "Kein Template" für einen leeren Shop.',
            options     = Config.GetTemplateOptions(),
            required    = true,
        }
    })
    if not templateChoice then return end

    local selectedTemplateKey = templateChoice[1]   -- z.B. 'ammu_nation' oder 'none'
    local tpl = selectedTemplateKey ~= 'none' and Config.ShopTemplates[selectedTemplateKey] or nil

    -- ── Schritt 2: Shop-Daten eingeben ────────────────────────────────────
    -- Wenn ein Template gewählt wurde, werden Ped / Blip-Sprite / -Farbe /
    -- Kategorie als Defaults vorbelegt — der Admin kann sie aber überschreiben.
    local categoryOptions = {}
    for key, data in pairs(Config.ShopCategories) do
        table.insert(categoryOptions, {label = data.label, value = key})
    end

    -- Vorbelegte Defaults aus Template (falls vorhanden)
    local defaultPed    = tpl and tpl.pedModel   or 'mp_m_shopkeep_01'
    local defaultCat    = tpl and tpl.category   or 'general'
    local defaultSprite = tpl and tpl.blipSprite or 52
    local defaultColor  = tpl and tpl.blipColor  or 2
    local templateHint  = tpl
        and ('Template: ' .. tpl.label .. ' — ' .. #tpl.items .. ' Items werden geladen')
        or  'Kein Template — Shop startet leer'

    local input = lib.inputDialog('🏪 Create New Shop', {
        {type='input',  label='Shop Name',   description='Internal name',                          required=true, min=3, max=50},
        {type='input',  label='Blip Name',   description='Name auf der Karte',                     required=true, min=3, max=50},
        {type='select', label='Ped Model',   description='Verkäufer-Modell',    options=Config.PedModels,   required=true, searchable=true, default=defaultPed},
        {type='select', label='Category',    description='Shop-Kategorie',      options=categoryOptions,    required=true, default=defaultCat},
        {type='select', label='Blip Sprite', description='Karten-Icon',         options=Config.BlipSprites, required=true, searchable=true, default=tostring(defaultSprite)},
        {type='select', label='Blip Color',  description='Karten-Farbe',        options=Config.BlipColors,  required=true, default=tostring(defaultColor)},
        -- Info-Feld — nur zur Anzeige, kein Input
        {type='input',  label='ℹ️ Template-Info', description=templateHint, disabled=true, default=templateHint},
    })
    if not input then return end

    -- ── Schritt 3: Coords + Heading ────────────────────────────────────────
    local playerPed   = PlayerPedId()
    local rawCoords   = GetEntityCoords(playerPed)
    local heading     = GetEntityHeading(playerPed)

    -- FIX [#6]: GetEntityCoords gibt Körpermitte zurück (~1m über Boden).
    -- GetGroundZFor_3dCoord snappt auf Navmesh — korrektes Z für Ped-Spawn.
    local groundFound, groundZ = GetGroundZFor_3dCoord(rawCoords.x, rawCoords.y, rawCoords.z, false)
    local coords = vector3(rawCoords.x, rawCoords.y, groundFound and groundZ or rawCoords.z)

    -- ── Schritt 4: Shop erstellen + Template-Items laden ──────────────────
    lib.callback('rde_shops:server:createShop', false, function(result)
        if not result or not result.success then
            notify(result and result.message or 'Shop konnte nicht erstellt werden', 'error')
            return
        end

        local shopId = result.shopId
        notify('Shop #' .. shopId .. ' erstellt!', 'success', 5000)

        -- Kein Template gewählt → fertig
        if not tpl then
            notify('Leerer Shop — Items über ⚙️ Menü hinzufügen.', 'inform', 6000)
            return
        end

        -- Template-Items auf dem Server einspielen
        lib.callback('rde_shops:server:applyTemplate', false, function(tplResult)
            if tplResult and tplResult.success then
                notify(
                    ('✅ %s geladen — %d Items eingetragen'):format(tpl.label, tplResult.itemCount),
                    'success', 8000
                )
            else
                notify('Template-Items konnten nicht geladen werden: ' .. (tplResult and tplResult.message or '?'), 'error')
            end
        end, shopId, selectedTemplateKey)

    end, {
        name       = input[1],
        blipName   = input[2],
        pedModel   = input[3],
        category   = input[4],
        blipSprite = tonumber(input[5]),
        blipColor  = tonumber(input[6]),
        coords     = coords,
        heading    = heading
    })
end, false)

-- =============================================
-- NETWORK EVENTS
-- =============================================
RegisterNetEvent('rde_shops:client:syncShop', function(shopId, shopData)
    -- FIX [#6b]: coords arrive as plain table over network — convert to vector4
    -- (syncAllShops does this correctly; syncShop was missing it → ped spawn crash)
    local c = shopData.coords
    if type(c) == 'table' then
        shopData.coords = vector4(c.x, c.y, c.z, c.w or 0.0)
    end
    shops[shopId] = shopData
    CreateThread(function()
        createShopPed(shopId, shopData)
        createShopBlip(shopId, shopData)
    end)
    debugPrint('Shop synced:', shopId, shopData.name)
end)

RegisterNetEvent('rde_shops:client:syncAllShops', function(allShops)
    -- Remove shops that no longer exist
    for shopId in pairs(shops) do
        if not allShops[shopId] then deleteShop(shopId) end
    end

    local count = 0
    local shopQueue = {}
    for shopId, shopData in pairs(allShops) do
        local c = shopData.coords
        if type(c) == 'table' then
            shopData.coords = vector4(c.x, c.y, c.z, c.w or 0.0)
        end
        shops[shopId] = shopData
        count = count + 1
        table.insert(shopQueue, {id = shopId, data = shopData})
    end

    -- Spawn sequentially to avoid parallel lib.requestModel race conditions
    CreateThread(function()
        for _, entry in ipairs(shopQueue) do
            createShopPed(entry.id, entry.data)
            createShopBlip(entry.id, entry.data)
            Wait(100)
        end
    end)

    debugPrint('syncAllShops: spawning', count, 'shops')
end)

RegisterNetEvent('rde_shops:client:deleteShop', function(shopId)
    deleteShop(shopId)
    debugPrint('Shop deleted:', shopId)
end)

RegisterNetEvent('rde_shops:client:updatePermission', function(hasPerms)
    isAdmin           = hasPerms
    permissionChecked = true
    debugPrint('Permission updated. Admin:', isAdmin)
end)

-- Robbery complete → kill + respawn clerk (single path, no double-respawn)
RegisterNetEvent('rde_shops:client:robberyComplete', function(shopId)
    local ped = shopPeds[shopId]
    if not ped or not DoesEntityExist(ped) then return end

    -- After a robbery the clerk should recover (scared, then back to normal).
    -- killAndRespawnPed is ONLY for when the player actually shoots the clerk dead.
    -- Playing a scared cower anim for a few seconds, then resetting to idle.
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    lib.requestAnimDict('move_p_scared_lturn_lr', function()
        if DoesEntityExist(ped) then
            TaskPlayAnim(ped, 'move_p_scared_lturn_lr', 'walk', 8.0, -8.0, 3000, 0, 0, false, false, false)
        end
    end)
    SetTimeout(4000, function()
        if DoesEntityExist(ped) then
            resetPedAfterRobbery(ped)
            FreezeEntityPosition(ped, Config.Shops.ped.frozen)
        end
    end)
end)

RegisterNetEvent('rde_shops:client:policeAlert', function(data)
    if not data or not data.coords then return end

    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Shop Robbery')
    EndTextCommandSetBlipName(blip)

    SetTimeout(300000, function() RemoveBlip(blip) end)

    lib.notify({
        title       = '🚨 Police Alert',
        description = 'Robbery in progress at ' .. (data.shopName or 'unknown location') .. '!',
        type        = 'error',
        duration    = 15000,
        icon        = 'store',
        iconColor   = 'red',
        position    = 'top'
    })
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('rde_shops:client:syncReputation', function(shopId, reputation)
    if shops[shopId] then shops[shopId].reputation = reputation end
end)

RegisterNetEvent('rde_shops:client:showPurchaseEffect', function(shopId)
    if not shops[shopId] then return end
    if not Config.Shops.till.enableParticles then return end

    local ped = shopPeds[shopId]
    if not ped or not DoesEntityExist(ped) then return end

    local coords = GetEntityCoords(ped)
    playParticleEffect(coords, Config.Shops.till.particleDict, Config.Shops.till.particleName)
    SetTimeout(5000, clearParticleEffects)
end)

-- [NEW #5] Price prompt for newly dragged-in items
RegisterNetEvent('rde_shops:client:promptStashItemPrice', function(shopId, itemName, defaultPrice)
    local allItems = exports.ox_inventory:Items()
    local itemInfo = allItems and allItems[itemName]
    local label    = itemInfo and itemInfo.label or itemName

    local input = lib.inputDialog('💰 Set Price: ' .. label, {
        {
            type        = 'number',
            label       = 'Price per Item ($)',
            description = 'This item was just dragged into the shop stash. Set a selling price.',
            default     = defaultPrice or 10,
            required    = true,
            min         = 1,
            max         = 999999
        }
    })

    if not input then return end

    lib.callback('rde_shops:server:setDragInPrice', false, function(result)
        if result and result.success then
            notify('Price set: ' .. label .. ' → $' .. input[1], 'success')
        else
            notify(result and result.message or 'Failed to set price', 'error')
        end
    end, shopId, itemName, tonumber(input[1]))
end)

-- =============================================
-- STATEBAG LIVE-UPDATE
-- =============================================
AddStateBagChangeHandler('rde_shop_list', 'global', function(_, _, shopList)
    if type(shopList) ~= 'table' then return end
    SetTimeout(200, function()
        lib.callback('rde_shops:server:getAllShops', false, function(allShops)
            if not allShops then return end
            for shopId, shopData in pairs(allShops) do
                if not shops[shopId] then
                    local c = shopData.coords
                    if type(c) == 'table' then
                        shopData.coords = vector4(c.x, c.y, c.z, c.w or 0.0)
                    end
                    shops[shopId] = shopData
                    CreateThread(function()
                        createShopPed(shopId, shopData)
                        createShopBlip(shopId, shopData)
                    end)
                    debugPrint('StateBag live-update: spawned new shop', shopId)
                end
            end
            for shopId in pairs(shops) do
                if not allShops[shopId] then
                    deleteShop(shopId)
                    debugPrint('StateBag live-update: removed shop', shopId)
                end
            end
        end)
    end)
end)

-- =============================================
-- CLEANUP & INIT
-- =============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for shopId in pairs(shops) do deleteShop(shopId) end
    lib.hideTextUI()
    clearParticleEffects()
    debugPrint('Cleanup complete')
end)

CreateThread(function()
    -- Wait for player ped to exist (up to 30s)
    local timeout = GetGameTimer() + 30000
    while PlayerPedId() == 0 and GetGameTimer() < timeout do Wait(500) end
    Wait(500)

    -- Permission check
    lib.callback('rde_shops:server:checkAdminPermission', false, function(hasPerms)
        isAdmin           = hasPerms
        permissionChecked = true
        debugPrint('Permission check — Admin:', isAdmin)
    end)

    -- Fallback sync: wait up to 15s for server to push syncAllShops,
    -- then actively request if still empty (handles late-join / resource restart)
    local fallbackAttempts = 0
    local maxAttempts = 5
    repeat
        Wait(3000)
        fallbackAttempts = fallbackAttempts + 1
        if not next(shops) then
            debugPrint('No shops loaded yet — requesting full sync (attempt ' .. fallbackAttempts .. ')')
            lib.callback('rde_shops:server:getAllShops', false, function(allShops)
                if not allShops or not next(allShops) then
                    debugPrint('getAllShops returned empty — server may still be initialising')
                    return
                end
                local shopQueue = {}
                for shopId, shopData in pairs(allShops) do
                    local c = shopData.coords
                    if type(c) == 'table' then
                        shopData.coords = vector4(c.x, c.y, c.z, c.w or 0.0)
                    end
                    shops[shopId] = shopData
                    table.insert(shopQueue, {id = shopId, data = shopData})
                end
                -- Sequential spawn (same as syncAllShops)
                for _, entry in ipairs(shopQueue) do
                    createShopPed(entry.id, entry.data)
                    createShopBlip(entry.id, entry.data)
                    Wait(100)
                end
                debugPrint('Fallback sync: loaded', tableCount(shops), 'shops')
            end)
        end
    until next(shops) or fallbackAttempts >= maxAttempts

    if fallbackAttempts >= maxAttempts and not next(shops) then
        debugPrint('WARNING: Could not load shops after ' .. maxAttempts .. ' attempts — server may not have initialized')
    end
end)

-- =============================================
-- EXPORTS
-- =============================================
exports('GetShops',  function() return shops end)
exports('GetShop',   function(shopId) return shops[shopId] end)
exports('IsAdmin',   function() return isAdmin end)
exports('OpenShop',  function(shopId) openShopInventory(shopId) end)

print('^2[RDE | SHOPS V4.7]^7 Client loaded ✓')
