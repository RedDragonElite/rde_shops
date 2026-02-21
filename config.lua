Config = {}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ CORE SETTINGS █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.DefaultLanguage = 'en'
Config.Debug = false

-- Admin-Berechtigungen
Config.AdminGroups = {
    'god', 'owner', 'admin', 'superadmin', 'moderator', 'mod', 'staff'
}

-- ACE-Berechtigungen (Fallback)
Config.AcePermissions = {
    'rde_shop.admin',
    'rde_orgs.admin',
    'command'
}

-- Datenbank-Präfix
Config.TablePrefix = 'rde_'

-- Shop-Inventar-Einstellungen (Admin-Stash)
Config.ShopInventory = {
    slots = 100,
    maxWeight = 100000
}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ SHOP CATEGORIES █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.ShopCategories = {
    general = {
        label = '🏪 General Store',
        defaultBlip = {sprite = 52, color = 2},
        repMultiplier = 1.0,
        icon = 'fas fa-shopping-basket'
    },
    weapons = {
        label = '🔫 Weapon Shop',
        defaultBlip = {sprite = 110, color = 1},
        repMultiplier = 1.5,
        icon = 'fas fa-gun',
        robberySeverity = 'high'
    },
    clothing = {
        label = '👔 Clothing Store',
        defaultBlip = {sprite = 73, color = 3},
        repMultiplier = 0.8,
        icon = 'fas fa-tshirt'
    },
    liquor = {
        label = '🍺 Liquor Store',
        defaultBlip = {sprite = 93, color = 5},
        repMultiplier = 1.2,
        icon = 'fas fa-wine-bottle'
    },
    electronics = {
        label = '📱 Electronics',
        defaultBlip = {sprite = 521, color = 0},
        repMultiplier = 1.3,
        icon = 'fas fa-mobile-alt'
    },
    pharmacy = {
        label = '💊 Pharmacy',
        defaultBlip = {sprite = 153, color = 4},
        repMultiplier = 1.4,
        icon = 'fas fa-pills'
    },
    custom = {
        label = '⭐ Custom Shop',
        defaultBlip = {sprite = 52, color = 2},
        repMultiplier = 1.0,
        icon = 'fas fa-store'
    }
}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ SHOP SETTINGS █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.Shops = {
    blip = {
        enabled = true,
        scale = 0.8,
        display = 4,
        shortRange = true
    },
    ped = {
        invincible = false,
        frozen = true,
        blockevents = true,         -- WICHTIG: true = NPC ignoriert alle externen Events (kein Fliehen)
        scenario = 'WORLD_HUMAN_STAND_MOBILE',

        scaredScenarios = {
            'CODE_HUMAN_COWER',
            'WORLD_HUMAN_STUPOR',
        },

        handsUpDict = 'random@arrests@busted',
        handsUpAnim = 'idle_a',

        deadPedCleanupTime = 20000,
        respawnTime = 60000,
    },
    interaction = {
        distance = 2.5,
        icon = 'fas fa-shopping-cart',
        label = nil
    },
    till = {
        moneyAccumulationRate = 0.15,   -- Anteil jedes Kaufpreises der in die Kasse geht
        maxTillMoney = 5000,
        enableParticles = true,
        particleDict = 'scr_rcbarry2',
        particleName = 'scr_clown_appears',

        -- Passives Kassengeld — simuliert NPC-Kunden auch ohne echte Spieler
        passiveIncome = {
            enabled   = true,
            interval  = 300,        -- alle X Sekunden (300 = 5 Minuten)
            minAmount = 50,         -- mind. $50 pro Tick
            maxAmount = 250,        -- max. $250 pro Tick
        },
    },
    restock = {
        enabled   = true,
        interval  = 600,            -- alle X Sekunden (600 = 10 Minuten)
        amountMin = 1,              -- mind. X Einheiten pro Item
        amountMax = 5,              -- max. X Einheiten pro Item
        maxStock  = 100,            -- Obergrenze pro Item (wird nie überschritten)
    },
    reputation = {
        enabled = true,
        maxRep = 100,
        minRep = -50,
        repGainPerPurchase = 1,
        repLossPerRobbery = 10,
        priceMultiplierMax = 0.9,
        priceMultiplierMin = 1.5
    },
    analytics = {
        enabled = true,
        trackPurchases = true,
        trackRobberies = true,
        trackRevenue = true,
        historyRetention = 30
    }
}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ ULTRA-REALISTIC ROBBERY SYSTEM █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.Robbery = {
    enabled = true,
    weaponRequired = true,
    weaponTypes = {
        'WEAPON_PISTOL', 'WEAPON_PISTOL50', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL',
        'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_ADVANCEDRIFLE',
        'WEAPON_SMG', 'WEAPON_MICROSMG', 'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN',
        'WEAPON_KNIFE', 'WEAPON_MACHETE', 'WEAPON_BAT'
    },

    -- Robbery Timing
    aimTime = 5.0,              -- Zeit zum Zielen in Sekunden
    cooldown = 600,             -- Cooldown zwischen Robberies (Sekunden)

    -- NPC Verhalten
    npc = {
        dontFlee = true,
        handsUpChance = 0.95,
        fightBackChance = 0.05,
        fightBackWeapons = {
            'WEAPON_PISTOL',
            'WEAPON_PUMPSHOTGUN'
        },
        canBeKilled = true,
        giveMoneyOnDeath = true,
    },

    -- NPC Hände-hoch / Unterwerfungs-Animation (FIX: war in Config nicht definiert)
    pedAnimDict   = 'random@arrests@busted',
    pedAnimName   = 'idle_a',

    -- Progressive Difficulty
    progressive = {
        enabled = true,
        timeIncreasePerCop = 1.0,
        fightBackChanceIncreasePerCop = 0.02
    },

    -- Police System
    policeNotify = true,
    policeJobs = {'police', 'sheriff', 'state'},
    minPolice = 0,
    dispatchRadius = 300.0,
    wantedLevel = 2,

    -- Payout
    minPayout = 100,
    maxPayout = 1000,
    payoutPercentage = 0.8,

    speedBonus = {
        enabled = true,
        maxBonus = 0.2,
        timeThreshold = 2.0
    },

    -- Animations & Effects
    screenShake = true,
    screenShakeIntensity = 0.3,
    screenShakeDuration = 1000,

    evidence = {
        enabled = true,
        dropChance = 0.3,
        items = {'fingerprint', 'bullet_casing', 'dna_sample'}
    }
}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ BLIP SPRITES & COLORS █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.BlipSprites = {
    {label = '🏪 Store',         value = 52},
    {label = '🔫 Gun Shop',      value = 110},
    {label = '👔 Clothing',      value = 73},
    {label = '🍺 Bar',           value = 93},
    {label = '💊 Pharmacy',      value = 153},
    {label = '🔧 Garage',        value = 446},
    {label = '🍔 Restaurant',    value = 106},
    {label = '📱 Electronics',   value = 521},
    {label = '💎 Jewelry',       value = 617},
    {label = '🏦 Bank',          value = 108},
    {label = '⛽ Gas Station',   value = 361},
    {label = '🛒 Supermarket',   value = 52},
    {label = '⭐ Custom',        value = 1}
}

Config.BlipColors = {
    {label = '⚪ White',   value = 0},
    {label = '🔴 Red',     value = 1},
    {label = '🟢 Green',   value = 2},
    {label = '🔵 Blue',    value = 3},
    {label = '⚫ Dark',    value = 4},
    {label = '🟡 Yellow',  value = 5},
    {label = '🟣 Purple',  value = 27},
    {label = '🟠 Orange',  value = 47},
    {label = '🟤 Brown',   value = 54},
    {label = '💖 Pink',    value = 8}
}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ PED MODELS █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.PedModels = {
    {label = '🧑 Store Clerk',         value = 'mp_m_shopkeep_01'},
    {label = '👨 Latino Clerk',         value = 's_m_m_lathandy_01'},
    {label = '🧒 Young Seller',         value = 's_m_y_shop_mask'},
    {label = '🛡️ Armoured Clerk',       value = 's_m_m_armoured_02'},
    {label = '👳 Indian Clerk',         value = 's_m_m_ammucountry'},
    {label = '🔫 Gun Store Clerk',      value = 's_m_y_ammucity_01'},
    {label = '👔 Hipster',              value = 'a_m_y_hipster_01'},
    {label = '💼 Business Male',        value = 's_m_m_movprem_01'},
    {label = '🍺 Bartender',            value = 's_m_y_barman_01'},
    {label = '👨‍🍳 Chef',              value = 's_m_m_chef_01'},
    {label = '👩 Store Clerk Female',   value = 'mp_f_weed_01'},
    {label = '🧕 Young Seller Female',  value = 's_f_y_shop_low'},
    {label = '💼 Business Female',      value = 's_f_y_movprem_01'},
    {label = '🍸 Bartender Female',     value = 's_f_y_bartender_01'},
    {label = '👗 Sales Assistant',      value = 's_f_y_shop_mid'},
    {label = '🔧 Mechanic',             value = 's_m_y_xmech_01'},
    {label = '🔬 Scientist',            value = 's_m_m_scientist_01'},
    {label = '⚕️ Doctor',              value = 's_m_m_doctor_01'}
}

-- ████████████████████████████████████████████████████████████████
-- █▀▀▀▀▀█ LOCALIZATION █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
-- ████████████████████████████████████████████████████████████████
Config.Locales = {
    en = {
        press_to_interact      = 'Press ~INPUT_CONTEXT~ to interact',
        shop_name              = 'Shop',
        shop_keeper            = 'Shop Keeper',
        menu_main_title        = 'Shop Management',
        menu_main_desc         = 'Manage your shop',
        menu_create_title      = 'Create New Shop',
        menu_edit_title        = 'Edit Shop',
        menu_analytics         = 'Shop Analytics',
        create_shop            = 'Create New Shop',
        edit_shop              = 'Edit Shop',
        delete_shop            = 'Delete Shop',
        manage_inventory       = 'Manage Inventory',
        browse_shop            = 'Browse Shop',
        check_till             = 'Check Register',
        empty_till             = 'Empty Register',
        view_analytics         = 'View Analytics',
        input_shop_name        = 'Shop Name',
        input_shop_name_desc   = 'Enter a unique name',
        input_ped_model        = 'Ped Model',
        input_ped_model_desc   = 'Select shop keeper',
        input_blip_name        = 'Blip Name',
        input_blip_name_desc   = 'Name on map',
        input_blip_sprite      = 'Blip Icon',
        input_blip_sprite_desc = 'Choose map icon',
        input_blip_color       = 'Blip Color',
        input_blip_color_desc  = 'Choose map color',
        input_category         = 'Shop Category',
        input_category_desc    = 'Select category',
        shop_created           = 'Shop created successfully!',
        shop_deleted           = 'Shop deleted!',
        shop_updated           = 'Shop updated!',
        item_added             = 'Item added to shop',
        item_removed           = 'Item removed',
        item_purchased         = 'Purchased %s x%s for $%s',
        not_enough_money       = 'Not enough money!',
        shop_empty             = 'This shop has no items yet',
        till_empty             = 'Register is empty',
        till_info              = 'Register: $%s',
        money_collected        = 'Collected $%s',
        rep_increased          = 'Reputation increased! (+%s)',
        rep_decreased          = 'Reputation decreased! (-%s)',
        rep_current            = 'Current reputation: %s',
        no_permission          = 'No permission!',
        admin_only             = 'Admin only',
        robbery_started        = 'Robbery in progress!',
        robbery_success        = 'Stole $%s!',
        robbery_failed         = 'Robbery failed!',
        robbery_cooldown       = 'This shop was recently robbed',
        keep_aiming            = 'Keep aiming... (%ss)',
        keep_aiming_hands_up   = 'Clerk has hands up... (%ss)',
        police_alert           = '10-90 - Store Robbery',
        police_alert_desc      = 'Location: %s',
        not_enough_police      = 'Not enough police on duty',
        cops_nearby            = 'Cops nearby: %s',
        difficulty_increased   = 'Difficulty increased!',
        clerk_fighting_back    = 'Clerk is fighting back!',
        clerk_killed           = 'Clerk eliminated',
        total_revenue          = 'Total Revenue',
        total_purchases        = 'Total Purchases',
        total_robberies        = 'Total Robberies',
        avg_transaction        = 'Avg Transaction',
        shop_reputation        = 'Reputation',
        error_occurred         = 'An error occurred',
        invalid_amount         = 'Invalid amount',
        inventory_full         = 'Inventory full'
    },
    de = {
        press_to_interact      = 'Drücke ~INPUT_CONTEXT~',
        shop_name              = 'Laden',
        shop_keeper            = 'Verkäufer',
        menu_main_title        = 'Laden Verwaltung',
        menu_main_desc         = 'Verwalte deinen Laden',
        menu_create_title      = 'Neuen Laden erstellen',
        menu_edit_title        = 'Laden bearbeiten',
        menu_analytics         = 'Shop Statistiken',
        create_shop            = 'Laden erstellen',
        edit_shop              = 'Laden bearbeiten',
        delete_shop            = 'Laden löschen',
        manage_inventory       = 'Inventar',
        browse_shop            = 'Durchsuchen',
        check_till             = 'Kasse prüfen',
        empty_till             = 'Kasse leeren',
        view_analytics         = 'Statistiken',
        input_shop_name        = 'Ladenname',
        input_shop_name_desc   = 'Name eingeben',
        input_ped_model        = 'Ped Model',
        input_ped_model_desc   = 'Verkäufer wählen',
        input_blip_name        = 'Blip Name',
        input_blip_name_desc   = 'Name auf Karte',
        input_blip_sprite      = 'Blip Icon',
        input_blip_sprite_desc = 'Karten-Icon wählen',
        input_blip_color       = 'Blip Farbe',
        input_blip_color_desc  = 'Karten-Farbe wählen',
        input_category         = 'Kategorie',
        input_category_desc    = 'Kategorie wählen',
        shop_created           = 'Laden erstellt!',
        shop_deleted           = 'Laden gelöscht!',
        shop_updated           = 'Laden aktualisiert!',
        item_added             = 'Item hinzugefügt',
        item_removed           = 'Item entfernt',
        item_purchased         = '%s x%s für $%s gekauft',
        not_enough_money       = 'Nicht genug Geld!',
        shop_empty             = 'Laden hat noch keine Items',
        till_empty             = 'Kasse ist leer',
        till_info              = 'Kasse: $%s',
        money_collected        = '$%s genommen',
        rep_increased          = 'Ruf gestiegen! (+%s)',
        rep_decreased          = 'Ruf gesunken! (-%s)',
        rep_current            = 'Aktueller Ruf: %s',
        no_permission          = 'Keine Berechtigung!',
        admin_only             = 'Nur für Admins',
        robbery_started        = 'Überfall läuft!',
        robbery_success        = '$%s gestohlen!',
        robbery_failed         = 'Überfall fehlgeschlagen!',
        robbery_cooldown       = 'Dieser Laden wurde kürzlich überfallen',
        keep_aiming            = 'Weiter zielen... (%ss)',
        keep_aiming_hands_up   = 'Verkäufer hat Hände oben... (%ss)',
        police_alert           = '10-90 - Ladenüberfall',
        police_alert_desc      = 'Ort: %s',
        not_enough_police      = 'Nicht genug Polizei im Dienst',
        cops_nearby            = 'Cops in der Nähe: %s',
        difficulty_increased   = 'Schwierigkeit erhöht!',
        clerk_fighting_back    = 'Verkäufer wehrt sich!',
        clerk_killed           = 'Verkäufer ausgeschaltet',
        total_revenue          = 'Gesamtumsatz',
        total_purchases        = 'Gesamt Käufe',
        total_robberies        = 'Gesamt Überfälle',
        avg_transaction        = 'Ø Transaktion',
        shop_reputation        = 'Ruf',
        error_occurred         = 'Fehler aufgetreten',
        invalid_amount         = 'Ungültige Menge',
        inventory_full         = 'Inventar voll'
    }
}

function L(key)
    local locale = Config.Locales[Config.DefaultLanguage]
    return locale and (locale[key] or key) or key
end