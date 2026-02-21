-- RDE Advanced Shop System V1.0.0 - Client
-- Framework: ox_core v2 + ox_inventory
-- FIXES: All callback name mismatches, Lua syntax errors, robbery system, police alert

local shops       = {}   -- All shops (ID as key)
local shopPeds    = {}   -- Shop peds (ID as key)
local shopBlips   = {}   -- Shop blips (ID as key)

local currentRobbery  = nil   -- Active robbery state
local robberyThread   = nil   -- Robbery progress thread
local isAdmin         = false
local permissionChecked = false

local particleEffects = {}  -- Active looped particle handles

-- =============================================
-- UTILITY
-- =============================================
local function debugPrint(...)
    if Config.Debug then
        print('[RDE Shops - Client]', ...)
    end
end

local function notify(message, nType, duration)
    lib.notify({
        title    = 'Shop System',
        description = message,
        type     = nType or 'info',
        position = 'top',
        duration = duration or 4000
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
        while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < timeout do
            Wait(0)
        end
    end
    if not HasNamedPtfxAssetLoaded(dict) then return end
    UseParticleFxAssetNextCall(dict)
    local effect = StartParticleFxLoopedAtCoord(name, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
    table.insert(particleEffects, effect)
    return effect
end

local function clearParticleEffects()
    for _, effect in ipairs(particleEffects) do
        StopParticleFxLooped(effect, false)
    end
    particleEffects = {}
end

-- =============================================
-- PED MANAGEMENT
-- =============================================
local function createShopPed(shopId, shop)
    if not shop then return end

    -- Remove existing ped
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

    local ped = CreatePed(
        4,
        pedModel,
        shop.coords.x,
        shop.coords.y,
        shop.coords.z - 1.0,
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

    -- ── Anti-Flee / Anti-Combat flags ─────────────────────────────────────
    -- BlockEvents = true: NPC ignoriert alle ambient events (Schüsse, Panik etc.)
    SetBlockingOfNonTemporaryEvents(ped, true)
    -- FleeAttributes = 0: NPC hat keinerlei Flucht-Attribute
    SetPedFleeAttributes(ped, 0, false)
    -- CombatAttributes: NPC kämpft nicht zurück im Normalzustand
    SetPedCombatAttributes(ped, 46, true)    -- flag 46 = kann Deckung benutzen (für später)
    SetPedCombatAttributes(ped, 5,  false)   -- flag 5  = flieht nicht wenn überwältigt
    -- Kein Panic-flee
    SetPedConfigFlag(ped, 65, true)          -- PCFLAG_NOT_SCARED
    SetPedConfigFlag(ped, 166, true)         -- PCFLAG_DISABLE_FLEE
    SetPedConfigFlag(ped, 229, true)         -- PCFLAG_CAN_CHOKE_FLEE → disabled
    -- Waffe zieht NPC nicht automatisch
    SetPedConfigFlag(ped, 17, false)         -- kann Waffe ziehen, aber nur wenn wir es triggern
    -- ──────────────────────────────────────────────────────────────────────

    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, Config.Shops.ped.frozen)
    SetPedRelationshipGroupHash(ped, GetHashKey('CIVMALE'))

    if Config.Shops.ped.scenario then
        TaskStartScenarioInPlace(ped, Config.Shops.ped.scenario, 0, true)
    end

    shopPeds[shopId] = ped

    -- Category icon
    local catCfg = shop.category and Config.ShopCategories[shop.category]
    local icon   = catCfg and catCfg.icon or Config.Shops.interaction.icon

    exports.ox_target:addLocalEntity(ped, {
        {
            name     = 'rde_shop_browse_' .. shopId,
            icon     = icon,
            label    = '🛒 ' .. shop.blipName,
            distance = Config.Shops.interaction.distance,
            onSelect = function()
                openShopInventory(shopId)
            end
        },
        {
            name     = 'rde_shop_manage_' .. shopId,
            icon     = 'fas fa-toolbox',
            label    = '⚙️ Shop Management',
            distance = Config.Shops.interaction.distance,
            canInteract = function()
                return isAdmin
            end,
            onSelect = function()
                openAdminMenu(shopId)
            end
        }
    })

    debugPrint('Created ped for shop:', shopId, 'Model:', shop.pedModel)
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

    -- Step 1: Cleanup corpse after deadPedCleanupTime
    SetTimeout(Config.Shops.ped.deadPedCleanupTime, function()
        if DoesEntityExist(ped) then
            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
        end
        shopPeds[shopId] = nil
        debugPrint('Ped corpse cleaned up for shop:', shopId)

        -- Step 2: Respawn after remaining respawnTime
        local remainingTime = math.max(0, Config.Shops.ped.respawnTime - Config.Shops.ped.deadPedCleanupTime)
        SetTimeout(remainingTime, function()
            if shops[shopId] and not shopPeds[shopId] then
                createShopPed(shopId, shops[shopId])
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

    if shopBlips[shopId] then
        RemoveBlip(shopBlips[shopId])
    end

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
-- SHOP BROWSING — CUSTOMER OPEN (CRITICAL FIX)
-- =============================================
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
        -- Server triggers rde_shops:client:doOpenShop which opens the UI
    end, shopId)
end

-- Server tells this client to open a specific ox_inventory shop.
-- openInventory('shop', { type = id }) is the only working method for dynamic shops.
-- No 'locations' registered on the server = no distance check = no "kein Zugang".
RegisterNetEvent('rde_shops:client:doOpenShop', function(oxShopId)
    exports.ox_inventory:openInventory('shop', { type = oxShopId })
end)

-- =============================================
-- STOCK MANAGEMENT (DB-based, no stash needed)
-- =============================================

-- Main stock screen — lists all items, add/edit/remove
function openStockManagement(shopId)
    if not isAdmin then notify(L('no_permission'), 'error') return end

    lib.callback('rde_shops:server:getShopItems', false, function(items)
        local allItems = exports.ox_inventory:Items()
        local options  = {}

        table.insert(options, {
            title       = '➕ Add Item',
            description = 'Add a new item with stock quantity and price',
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
                        {label = 'Item ID', value = itemData.item_name},
                        {label = 'In Stock', value = itemData.count},
                        {label = 'Price', value = '$' .. itemData.price}
                    },
                    onSelect = function()
                        editShopItemDialog(shopId, itemData.item_name, itemData.count, itemData.price, label)
                    end
                })
            end
        else
            table.insert(options, {
                title       = '📭 No items yet',
                description = 'Press "Add Item" to start stocking this shop',
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
        {
            type        = 'input',
            label       = 'Item Name (internal ID)',
            description = 'Exact ox_inventory item name, e.g. water, bread, pistol_ammo',
            placeholder = 'item_name',
            required    = true,
            min         = 1,
            max         = 50
        },
        {
            type        = 'number',
            label       = 'Quantity in Stock',
            description = 'How many units available to buy',
            default     = 50,
            required    = true,
            min         = 1,
            max         = 999999
        },
        {
            type        = 'number',
            label       = 'Price per Item ($)',
            default     = 10,
            required    = true,
            min         = 1,
            max         = 999999
        }
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
        {
            type        = 'number',
            label       = 'Quantity in Stock',
            description = 'Set to 0 to hide from customers',
            default     = currentQty,
            required    = true,
            min         = 0,
            max         = 999999
        },
        {
            type        = 'number',
            label       = 'Price ($)',
            default     = currentPrice,
            required    = true,
            min         = 0,
            max         = 999999
        }
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
                notify(result and result.success and (itemLabel .. ' removed!') or 'Failed to remove', result and result.success and 'success' or 'error')
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

-- Alias so admin menu "Manage Stock" still works
function openAdminShopInventory(shopId)
    openStockManagement(shopId)
end

-- =============================================
-- ADMIN MENU
-- =============================================
function openAdminMenu(shopId)
    if not isAdmin then
        notify(L('no_permission'), 'error')
        return
    end

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
                description = 'Add / restock / remove items — set price inline',
                icon        = 'boxes-stacked',
                iconColor   = '#8b5cf6',
                onSelect    = function() openStockManagement(shopId) end
            },
            {
                title       = '💰 Edit Prices',
                description = 'Quickly update prices for existing stock',
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
            notify('No items in stock yet! Add items via Manage Stock first.', 'info')
            return
        end

        -- FIX: Use 'and' instead of Lua-invalid '?.' syntax
        local allItems = exports.ox_inventory:Items()
        local options  = {}

        for _, itemData in ipairs(items) do
            local itemInfo = allItems and allItems[itemData.item_name]
            local label    = itemInfo and itemInfo.label or itemData.item_name

            -- FIX: itemInfo.client?.image → itemInfo.client and itemInfo.client.image
            local image = itemInfo and itemInfo.client and itemInfo.client.image or nil

            table.insert(options, {
                title     = label,
                description = 'Current Price: $' .. itemData.price,
                icon      = 'tag',
                image     = image,
                iconColor = '#3b82f6',
                metadata  = {
                    {label = 'Stock', value = itemData.count},
                    {label = 'Price', value = '$' .. itemData.price}
                },
                onSelect  = function()
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
        {
            type        = 'number',
            label       = 'New Price ($)',
            description = 'Current: $' .. currentPrice,
            icon        = 'dollar-sign',
            default     = currentPrice,
            required    = true,
            min         = 1,
            max         = 999999
        }
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
        {type='input',  label='Shop Name',   description='Internal name', default=shop.name,           required=true, min=3, max=50},
        {type='input',  label='Blip Name',   description='Map label',     default=shop.blipName,       required=true, min=3, max=50},
        {type='select', label='Ped Model',   description='Shopkeeper',    options=Config.PedModels,    default=shop.pedModel,       required=true, searchable=true},
        {type='select', label='Category',    description='Shop type',     options=categoryOptions,     default=shop.category or 'general', required=true},
        {type='select', label='Blip Sprite', description='Map icon',      options=Config.BlipSprites,  default=shop.blipSprite or 52, required=true, searchable=true},
        {type='select', label='Blip Color',  description='Map color',     options=Config.BlipColors,   default=shop.blipColor or 2, required=true}
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
        if not data then
            notify('Failed to load analytics', 'error')
            return
        end

        local rep      = data.reputation or 0
        local repColor = rep >= 50 and '#10b981' or (rep >= 0 and '#f59e0b' or '#ef4444')

        lib.registerContext({
            id    = 'rde_shop_analytics',
            title = '📊 Analytics — ' .. (shops[shopId] and shops[shopId].name or 'Shop'),
            menu  = 'rde_shop_admin',
            options = {
                {
                    title       = '💰 Total Revenue',
                    description = '$' .. (data.totalRevenue or 0),
                    icon        = 'dollar-sign',
                    iconColor   = '#10b981',
                    progress    = math.min(100, ((data.totalRevenue or 0) / 10000) * 100),
                    colorScheme = 'green'
                },
                {
                    title       = '🛒 Total Purchases',
                    description = (data.totalPurchases or 0) .. ' transactions',
                    icon        = 'shopping-cart',
                    iconColor   = '#3b82f6'
                },
                {
                    title       = '🎭 Total Robberies',
                    description = (data.totalRobberies or 0) .. ' robberies',
                    icon        = 'mask',
                    iconColor   = '#ef4444'
                },
                {
                    title       = '📈 Avg. Transaction',
                    description = '$' .. (data.avgTransaction or 0),
                    icon        = 'receipt',
                    iconColor   = '#8b5cf6'
                },
                {
                    title       = '⭐ Reputation',
                    description = rep .. ' / 100',
                    icon        = 'star',
                    iconColor   = repColor,
                    progress    = math.max(0, rep),
                    colorScheme = rep >= 50 and 'green' or 'red'
                },
                {
                    title       = '💵 Current Till',
                    description = '$' .. (data.tillMoney or 0),
                    icon        = 'cash-register',
                    iconColor   = '#f59e0b'
                }
            }
        })
        lib.showContext('rde_shop_analytics')
    end, shopId)
end

-- =============================================
-- TILL
-- =============================================
function checkTill(shopId)
    -- FIX: Was calling 'checkTill' but name didn't match — now server has both
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
        header  = '⚠️ Delete Shop',
        content = 'Are you sure you want to permanently delete this shop? This cannot be undone!',
        centered = true,
        cancel  = true
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
-- ROBBERY SYSTEM (FIXED)
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

local function startRobbery(shopId)
    if not Config.Robbery.enabled then return end
    if currentRobbery then return end

    local ped = shopPeds[shopId]
    if not ped or not DoesEntityExist(ped) then return end
    if not IsPlayerFreeAiming(PlayerId()) then return end
    if not isHoldingAllowedWeapon() then return end

    local _, targetPed = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if targetPed ~= ped then return end

    -- FIX: Server callback 'checkRobbery' is now properly registered
    lib.callback('rde_shops:server:checkRobbery', false, function(checkResult)
        if not checkResult or not checkResult.success then
            notify(checkResult and checkResult.message or L('robbery_failed'), 'error')
            return
        end

        -- Notify server robbery started
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

        -- Hände hoch + einfrieren + Flucht-Schutz nochmal forcieren
        -- (GTA kann ped-flags unter bestimmten Umständen resetten)
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedConfigFlag(ped, 65, true)
            SetPedConfigFlag(ped, 166, true)
            ClearPedTasks(ped)
            lib.requestAnimDict(Config.Shops.ped.handsUpDict)
            TaskPlayAnim(ped, Config.Shops.ped.handsUpDict, Config.Shops.ped.handsUpAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
        end

        -- Robbery progress thread
        robberyThread = CreateThread(function()
            while currentRobbery do
                Wait(100)
                local elapsed = GetGameTimer() - currentRobbery.startTime

                -- Cancel if player stops aiming or switches weapon
                if not IsPlayerFreeAiming(PlayerId()) or not isHoldingAllowedWeapon() then
                    lib.hideTextUI()
                    notify(L('robbery_failed'), 'error')
                    TriggerServerEvent('rde_shops:server:cancelRobbery', shopId)
                    currentRobbery = nil
                    -- Make NPC resume normal behaviour
                    if DoesEntityExist(ped) then
                        FreezeEntityPosition(ped, false)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        SetPedFleeAttributes(ped, 0, false)
                        SetPedConfigFlag(ped, 65, true)
                        SetPedConfigFlag(ped, 166, true)
                        ClearPedTasks(ped)
                        if Config.Shops.ped.scenario then
                            TaskStartScenarioInPlace(ped, Config.Shops.ped.scenario, 0, true)
                        end
                    end
                    break
                end

                local _, newTarget = GetEntityPlayerIsFreeAimingAt(PlayerId())
                if newTarget ~= ped then
                    lib.hideTextUI()
                    notify(L('robbery_failed'), 'error')
                    TriggerServerEvent('rde_shops:server:cancelRobbery', shopId)
                    currentRobbery = nil
                    if DoesEntityExist(ped) then
                        FreezeEntityPosition(ped, false)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        SetPedFleeAttributes(ped, 0, false)
                        SetPedConfigFlag(ped, 65, true)
                        SetPedConfigFlag(ped, 166, true)
                        ClearPedTasks(ped)
                        if Config.Shops.ped.scenario then
                            TaskStartScenarioInPlace(ped, Config.Shops.ped.scenario, 0, true)
                        end
                    end
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
                    currentRobbery = nil
                    break
                end
            end

            lib.hideTextUI()
            robberyThread = nil
        end)
    end, shopId)
end

function completeRobbery(shopId, ped)
    -- Make NPC do scared animation before triggering respawn
    if DoesEntityExist(ped) then
        -- FIX: Config.Robbery.pedAnimDict and pedAnimName are now properly defined in config
        lib.requestAnimDict(Config.Robbery.pedAnimDict)
        TaskPlayAnim(ped, Config.Robbery.pedAnimDict, Config.Robbery.pedAnimName, 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    if Config.Robbery.screenShake then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', Config.Robbery.screenShakeIntensity)
        SetTimeout(Config.Robbery.screenShakeDuration, function()
            StopGameplayCamShaking(true)
        end)
    end

    -- FIX: Server completeRobbery now sends ox_lib:notify directly, no need for client callback return parsing
    TriggerServerEvent('rde_shops:server:completeRobbery', shopId)

    -- Notify server the ped was killed (server handles respawn timer)
    TriggerServerEvent('rde_shops:server:pedKilled', shopId)

    -- Trigger local respawn logic
    killAndRespawnPed(shopId, shops[shopId])
end

-- Robbery detection thread
CreateThread(function()
    while true do
        Wait(500)
        if not Config.Robbery.enabled or currentRobbery then goto continue_robbery end

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

    local categoryOptions = {}
    for key, data in pairs(Config.ShopCategories) do
        table.insert(categoryOptions, {label = data.label, value = key})
    end

    local input = lib.inputDialog('🏪 Create New Shop', {
        {type='input',  label='Shop Name',   description='Internal name',     required=true, min=3, max=50},
        {type='input',  label='Blip Name',   description='Name on the map',   required=true, min=3, max=50},
        {type='select', label='Ped Model',   description='Shopkeeper model',  options=Config.PedModels,   required=true, searchable=true},
        {type='select', label='Category',    description='Shop category',     options=categoryOptions,    required=true},
        {type='select', label='Blip Sprite', description='Map icon',          options=Config.BlipSprites, required=true, searchable=true},
        {type='select', label='Blip Color',  description='Map marker color',  options=Config.BlipColors,  required=true}
    })

    if not input then return end

    local playerPed = PlayerPedId()
    local coords    = GetEntityCoords(playerPed)
    local heading   = GetEntityHeading(playerPed)

    lib.callback('rde_shops:server:createShop', false, function(result)
        if result and result.success then
            notify('Shop #' .. result.shopId .. ' created! Add stock via the ⚙️ menu.', 'success', 8000)
        else
            notify(result and result.message or 'Failed to create shop', 'error')
        end
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
    shops[shopId] = shopData
    createShopPed(shopId, shopData)
    createShopBlip(shopId, shopData)
    debugPrint('Shop synced:', shopId, shopData.name)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- syncAllShops — the ONLY reliable init path.
-- Server sends this on ox:playerSpawned so data arrives after character load.
-- coords come as plain tables over the network → convert back to vector4 here.
-- createShopPed uses lib.requestModel (internally calls Wait), so all spawning
-- MUST run inside a CreateThread — otherwise it silently does nothing.
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('rde_shops:client:syncAllShops', function(allShops)
    -- Clean up any shops that were removed while we were away
    for shopId in pairs(shops) do
        if not allShops[shopId] then
            deleteShop(shopId)
        end
    end

    -- Spawn each shop in its own thread so lib.requestModel can Wait safely
    local count = 0
    for shopId, shopData in pairs(allShops) do
        -- Convert coords table → vector4 (lost during network serialisation)
        local c = shopData.coords
        if type(c) == 'table' then
            shopData.coords = vector4(c.x, c.y, c.z, c.w or 0.0)
        end

        shops[shopId] = shopData
        count = count + 1

        -- Each ped gets its own thread so a slow model load doesn't block others
        local sid = shopId
        local sd  = shopData
        CreateThread(function()
            createShopPed(sid, sd)
            createShopBlip(sid, sd)
        end)
    end

    debugPrint('syncAllShops: spawning', count, 'shops')
end)

RegisterNetEvent('rde_shops:client:deleteShop', function(shopId)
    deleteShop(shopId)
    debugPrint('Shop deleted:', shopId)
end)

RegisterNetEvent('rde_shops:client:updatePermission', function(hasPerms)
    isAdmin         = hasPerms
    permissionChecked = true
    debugPrint('Permission updated. Admin:', isAdmin)
end)

RegisterNetEvent('rde_shops:client:robberyComplete', function(shopId)
    local ped = shopPeds[shopId]
    if ped and DoesEntityExist(ped) then
        killAndRespawnPed(shopId, shops[shopId])
    end
end)

-- FIX: Police alert now receives a single table {coords, shopName}
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
    if shops[shopId] then
        shops[shopId].reputation = reputation
    end
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

-- =============================================
-- STATEBAG LIVE-UPDATE HANDLER
-- =============================================
-- Only used for LIVE updates while in-game (new shop created, deleted, updated).
-- NOT used for initial load — that is handled by rde_shops:client:syncAllShops
-- which the server sends on ox:playerSpawned.
AddStateBagChangeHandler('rde_shop_list', 'global', function(_, _, shopList)
    if type(shopList) ~= 'table' then return end
    -- A shop was added or removed — request a fresh full sync from server
    -- Using a short delay so all individual shop StateBags have time to populate
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
            -- Remove shops that no longer exist
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

-- Init thread: only handles permission check.
-- Shop spawning happens via rde_shops:client:syncAllShops sent by the server.
-- We also add a fallback poll in case ox:playerSpawned fires before this
-- resource is fully started (e.g. resource restart while in-game).
CreateThread(function()
    -- Wait until the local player ped exists (character is loaded)
    local timeout = GetGameTimer() + 30000  -- max 30s wait
    while PlayerPedId() == 0 and GetGameTimer() < timeout do
        Wait(500)
    end
    Wait(500) -- small settle buffer

    -- Permission check
    lib.callback('rde_shops:server:checkAdminPermission', false, function(hasPerms)
        isAdmin           = hasPerms
        permissionChecked = true
        debugPrint('Permission check — Admin:', isAdmin)
    end)

    -- Fallback: if syncAllShops hasn't populated any shops yet, ask server directly.
    -- This covers: resource restart while in-game, or servers using a different spawn event.
    Wait(1000)
    if not next(shops) then
        debugPrint('No shops loaded yet — requesting full sync from server (fallback)')
        lib.callback('rde_shops:server:getAllShops', false, function(allShops)
            if not allShops then
                debugPrint('getAllShops returned nil — server may still be initialising')
                return
            end
            for shopId, shopData in pairs(allShops) do
                local c = shopData.coords
                if type(c) == 'table' then
                    shopData.coords = vector4(c.x, c.y, c.z, c.w or 0.0)
                end
                shops[shopId] = shopData
                local sid = shopId
                local sd  = shopData
                CreateThread(function()
                    createShopPed(sid, sd)
                    createShopBlip(sid, sd)
                end)
            end
            debugPrint('Fallback sync: loaded', tableCount(shops), 'shops')
        end)
    end
end)

-- =============================================
-- EXPORTS
-- =============================================
exports('GetShops',  function() return shops end)
exports('GetShop',   function(shopId) return shops[shopId] end)
exports('IsAdmin',   function() return isAdmin end)
exports('OpenShop',  function(shopId) openShopInventory(shopId) end)


print('^2[RDE | SHOPS V1.0.0]^7 Client loaded — all critical bugs fixed ✓')
