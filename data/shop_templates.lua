-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  RDE Shops — Shop Templates                                             │
-- │  Shared (client + server) — geladen über shared_scripts                │
-- │                                                                         │
-- │  Templates werden NICHT als Shops gespawnt.                             │
-- │  Sie erscheinen nur im /createshop-Menü als optionaler Item-Preset.    │
-- │                                                                         │
-- │  Jedes Template-Item:                                                   │
-- │    name     – ox_inventory item name                                    │
-- │    price    – Standardpreis ($)                                         │
-- │    quantity – Startmenge (default 50 wenn nicht gesetzt)               │
-- │    metadata – optional (z.B. {registered=true} für Waffen)             │
-- └─────────────────────────────────────────────────────────────────────────┘

Config.ShopTemplates = {

    -- ══════════════════════════════════════════════════════════════════
    --  🔫  AMMU-NATION  (ox_inventory original prices)
    -- ══════════════════════════════════════════════════════════════════
    ammu_nation = {
        label       = '🔫 Ammu-Nation (Komplett)',
        description = 'Munition, Nahkampf, Pistolen, SMGs, Schrotflinten, Aufsätze — alles drin.',
        category    = 'weapons',
        pedModel    = 's_m_y_ammucity_01',
        blipSprite  = 110,
        blipColor   = 69,

        items = {
            -- Munition
            { name = 'ammo-flare',        price = 3,     quantity = 200 },
            { name = 'ammo-9',            price = 5,     quantity = 500 },
            { name = 'ammo-22',           price = 6,     quantity = 500 },
            { name = 'ammo-38',           price = 6,     quantity = 500 },
            { name = 'ammo-shotgun',      price = 6,     quantity = 300 },
            { name = 'ammo-44',           price = 7,     quantity = 400 },
            { name = 'ammo-45',           price = 8,     quantity = 400 },
            { name = 'ammo-50',           price = 10,    quantity = 300 },
            { name = 'ammo-rifle',        price = 12,    quantity = 300 },
            { name = 'ammo-rifle2',       price = 15,    quantity = 200 },
            { name = 'ammo-sniper',       price = 21,    quantity = 100 },

            -- Erste Hilfe
            { name = 'medikit',           price = 250,   quantity = 50  },

            -- Nahkampf
            { name = 'WEAPON_KNUCKLE',        price = 65,    quantity = 20 },
            { name = 'WEAPON_SWITCHBLADE',    price = 110,   quantity = 20 },
            { name = 'WEAPON_KNIFE',          price = 80,    quantity = 20 },
            { name = 'WEAPON_BAT',            price = 120,   quantity = 20 },
            { name = 'WEAPON_MACHETE',        price = 220,   quantity = 15 },
            { name = 'WEAPON_FLAREGUN',       price = 290,   quantity = 15 },

            -- Pistolen (Waffenschein)
            { name = 'WEAPON_PISTOL',             price = 1300,  quantity = 10, metadata = { registered = true } },
            { name = 'WEAPON_CERAMICPISTOL',      price = 2300,  quantity = 10, metadata = { registered = true } },
            { name = 'WEAPON_COMBATPISTOL',       price = 2650,  quantity = 10, metadata = { registered = true } },
            { name = 'WEAPON_HEAVYPISTOL',        price = 3420,  quantity = 8,  metadata = { registered = true } },
            { name = 'WEAPON_MARKSMANPISTOL',     price = 2780,  quantity = 8,  metadata = { registered = true } },
            { name = 'WEAPON_REVOLVER',           price = 3100,  quantity = 8,  metadata = { registered = true } },
            { name = 'WEAPON_PISTOL50',           price = 3240,  quantity = 8,  metadata = { registered = true } },
            { name = 'WEAPON_NAVYREVOLVER',       price = 3920,  quantity = 5,  metadata = { registered = true } },
            { name = 'WEAPON_MACHINEPISTOL',      price = 5200,  quantity = 5,  metadata = { registered = true } },
            { name = 'WEAPON_MINISMG',            price = 5350,  quantity = 5,  metadata = { registered = true } },
            { name = 'WEAPON_MICROSMG',           price = 5860,  quantity = 5,  metadata = { registered = true } },

            -- Schrotflinten (Waffenschein)
            { name = 'WEAPON_DBSHOTGUN',          price = 4680,  quantity = 8,  metadata = { registered = true } },
            { name = 'WEAPON_SAWNOFFSHOTGUN',     price = 4870,  quantity = 8,  metadata = { registered = true } },
            { name = 'WEAPON_PUMPSHOTGUN',        price = 6220,  quantity = 5,  metadata = { registered = true } },

            -- Sniper / Marksman (Waffenschein)
            { name = 'WEAPON_MARKSMANRIFLE_MK2',  price = 12360, quantity = 3,  metadata = { registered = true } },

            -- Aufsätze (Waffenschein)
            { name = 'at_flashlight',             price = 150,   quantity = 20, metadata = { registered = true } },
            { name = 'at_suppressor_light',       price = 500,   quantity = 15, metadata = { registered = true } },
            { name = 'at_suppressor_heavy',       price = 1000,  quantity = 10, metadata = { registered = true } },
            { name = 'at_grip',                   price = 350,   quantity = 20, metadata = { registered = true } },
            { name = 'at_barrel',                 price = 420,   quantity = 20, metadata = { registered = true } },
            { name = 'at_compensator',            price = 380,   quantity = 20, metadata = { registered = true } },

            -- Extended Clips (Waffenschein)
            { name = 'at_clip_extended_pistol',   price = 230,   quantity = 20, metadata = { registered = true } },
            { name = 'at_clip_extended_smg',      price = 320,   quantity = 15, metadata = { registered = true } },
            { name = 'at_clip_extended_shotgun',  price = 340,   quantity = 15, metadata = { registered = true } },
            { name = 'at_clip_extended_rifle',    price = 500,   quantity = 10, metadata = { registered = true } },
            { name = 'at_clip_extended_mg',       price = 750,   quantity = 8,  metadata = { registered = true } },
            { name = 'at_clip_extended_sniper',   price = 920,   quantity = 5,  metadata = { registered = true } },

            -- Drum Clips (Waffenschein)
            { name = 'at_clip_drum_smg',          price = 845,   quantity = 10, metadata = { registered = true } },
            { name = 'at_clip_drum_shotgun',      price = 875,   quantity = 10, metadata = { registered = true } },
            { name = 'at_clip_drum_rifle',        price = 1130,  quantity = 8,  metadata = { registered = true } },

            -- Scopes (Waffenschein)
            { name = 'at_scope_small',            price = 1445,  quantity = 10, metadata = { registered = true } },
            { name = 'at_scope_medium',           price = 1780,  quantity = 8,  metadata = { registered = true } },
            { name = 'at_scope_advanced',         price = 2355,  quantity = 5,  metadata = { registered = true } },
            { name = 'at_scope_zoom',             price = 875,   quantity = 10, metadata = { registered = true } },
            { name = 'at_scope_nv',               price = 895,   quantity = 8,  metadata = { registered = true } },
            { name = 'at_scope_thermal',          price = 1115,  quantity = 5,  metadata = { registered = true } },

            -- Muzzles (Waffenschein)
            { name = 'at_muzzle_squared',         price = 560,   quantity = 15, metadata = { registered = true } },
            { name = 'at_muzzle_bell',            price = 590,   quantity = 15, metadata = { registered = true } },
            { name = 'at_muzzle_flat',            price = 715,   quantity = 15, metadata = { registered = true } },
            { name = 'at_muzzle_tactical',        price = 815,   quantity = 10, metadata = { registered = true } },
            { name = 'at_muzzle_fat',             price = 845,   quantity = 10, metadata = { registered = true } },
            { name = 'at_muzzle_precision',       price = 875,   quantity = 10, metadata = { registered = true } },
            { name = 'at_muzzle_heavy',           price = 985,   quantity = 8,  metadata = { registered = true } },
            { name = 'at_muzzle_slanted',         price = 965,   quantity = 8,  metadata = { registered = true } },
            { name = 'at_muzzle_split',           price = 935,   quantity = 8,  metadata = { registered = true } },

            -- Skins (Waffenschein)
            { name = 'at_skin_pearl',             price = 10000, quantity = 3,  metadata = { registered = true } },

            -- Schutzwesten
            { name = 'light_vest',   price = 500,   quantity = 30 },
            { name = 'heavy_vest',   price = 500,   quantity = 20 },
        }
    },

    -- ══════════════════════════════════════════════════════════════════
    --  🏪  24/7 SUPERMARKT
    -- ══════════════════════════════════════════════════════════════════
    supermarket_247 = {
        label       = '🏪 24/7 Supermarkt',
        description = 'Snacks, Getränke, Erste Hilfe, Alltagsgegenstände.',
        category    = 'general',
        pedModel    = 'mp_m_shopkeep_01',
        blipSprite  = 52,
        blipColor   = 2,

        items = {
            { name = 'water',            price = 2,   quantity = 200 },
            { name = 'coffee',           price = 3,   quantity = 150 },
            { name = 'beer',             price = 4,   quantity = 100 },
            { name = 'taco',             price = 5,   quantity = 100 },
            { name = 'sandwich',         price = 6,   quantity = 100 },
            { name = 'burger',           price = 8,   quantity = 80  },
            { name = 'chips',            price = 3,   quantity = 150 },
            { name = 'energy_drink',     price = 5,   quantity = 100 },
            { name = 'bandage',          price = 15,  quantity = 80  },
            { name = 'medikit',          price = 250, quantity = 20  },
            { name = 'lighter',          price = 5,   quantity = 50  },
            { name = 'cigarettes',       price = 8,   quantity = 60  },
            { name = 'phone',            price = 150, quantity = 10  },
        }
    },

    -- ══════════════════════════════════════════════════════════════════
    --  💊  APOTHEKE / PHARMACY
    -- ══════════════════════════════════════════════════════════════════
    pharmacy = {
        label       = '💊 Apotheke',
        description = 'Verbandsmaterial, Medikamente, Erste-Hilfe-Sets.',
        category    = 'pharmacy',
        pedModel    = 's_m_m_doctor_01',
        blipSprite  = 153,
        blipColor   = 4,

        items = {
            { name = 'bandage',          price = 15,  quantity = 100 },
            { name = 'medikit',          price = 250, quantity = 30  },
            { name = 'painkillers',      price = 30,  quantity = 80  },
            { name = 'antidote',         price = 75,  quantity = 40  },
            { name = 'adrenaline',       price = 120, quantity = 20  },
            { name = 'defibrillator',    price = 500, quantity = 5   },
            { name = 'vitamins',         price = 20,  quantity = 100 },
        }
    },

    -- ══════════════════════════════════════════════════════════════════
    --  ⛽  TANKSTELLE / GAS STATION
    -- ══════════════════════════════════════════════════════════════════
    gas_station = {
        label       = '⛽ Tankstelle',
        description = 'Benzin, Snacks, Reparatur-Basics.',
        category    = 'general',
        pedModel    = 'mp_m_shopkeep_01',
        blipSprite  = 361,
        blipColor   = 5,

        items = {
            { name = 'water',            price = 2,   quantity = 150 },
            { name = 'coffee',           price = 3,   quantity = 100 },
            { name = 'chips',            price = 3,   quantity = 100 },
            { name = 'energy_drink',     price = 5,   quantity = 80  },
            { name = 'lighter',          price = 5,   quantity = 50  },
            { name = 'jerrycan',         price = 25,  quantity = 30  },
            { name = 'rag',              price = 5,   quantity = 50  },
            { name = 'bandage',          price = 15,  quantity = 30  },
        }
    },

    -- ══════════════════════════════════════════════════════════════════
    --  🍺  LIQUOR STORE
    -- ══════════════════════════════════════════════════════════════════
    liquor_store = {
        label       = '🍺 Liquor Store',
        description = 'Bier, Wein, Schnaps und mehr.',
        category    = 'liquor',
        pedModel    = 's_m_y_barman_01',
        blipSprite  = 93,
        blipColor   = 5,

        items = {
            { name = 'beer',             price = 4,   quantity = 200 },
            { name = 'wine',             price = 15,  quantity = 80  },
            { name = 'vodka',            price = 25,  quantity = 50  },
            { name = 'whiskey',          price = 30,  quantity = 50  },
            { name = 'rum',              price = 22,  quantity = 50  },
            { name = 'cocktail',         price = 12,  quantity = 60  },
            { name = 'water',            price = 2,   quantity = 100 },
            { name = 'energy_drink',     price = 5,   quantity = 60  },
        }
    },
}

-- Hilfsfunktion: gibt Template-Optionen als ox_lib select-Liste zurück
function Config.GetTemplateOptions()
    local opts = {
        { label = '❌ Kein Template — leerer Shop', value = 'none' }
    }
    for key, tpl in pairs(Config.ShopTemplates) do
        table.insert(opts, {
            label = tpl.label,
            value = key
        })
    end
    -- alphabetisch sortieren (none immer oben)
    table.sort(opts, function(a, b)
        if a.value == 'none' then return true end
        if b.value == 'none' then return false end
        return a.label < b.label
    end)
    return opts
end
