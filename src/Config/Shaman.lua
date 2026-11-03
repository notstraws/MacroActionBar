local _, smb = ...

-- The Shaman page. See Config.lua for what each list does.
smb.classConfigs.SHAMAN = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Lightning Bolt",
            "Chain Lightning",
            "Lava Burst",
            "Earth Shock",
            "Flame Shock",
            "Frost Shock",
            "Fire Nova",
            "Stormstrike",
            "Elemental Mastery",
        } },
        { name = "Healing", cooldownSteps = true, spells = {
            "Healing Wave",
            "Lesser Healing Wave",
            "Chain Heal",
            "Riptide",
            "Nature's Swiftness",
            "Ancestral Spirit",
            "Reincarnation",
        } },
        { name = "Utility", spells = {
            "Purge",
            "Cure Poison",
            "Cure Disease",
            "Ghost Wolf",
            "Far Sight",
            "Astral Recall",
            "Call of the *",
            "Totemic Recall",
            "Totemic Projection",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Rockbiter Weapon",
            "Flametongue Weapon",
            "Frostbrand Weapon",
            "Windfury Weapon",
            "Lightning Shield",
            "Water Shield",
            "Water Breathing",
            "Water Walking",
            "Rage of the Farseer",
        } },
        { name = "Earth Totems", spells = {
            "Earthbind Totem",
            "Stoneclaw Totem",
            "Stoneskin Totem",
            "Strength of Earth Totem",
            "Tremor Totem",
        } },
        { name = "Fire Totems", spells = {
            "Searing Totem",
            "Magma Totem",
            "Flametongue Totem",
            "Frost Resistance Totem",
        } },
        { name = "Water Totems", spells = {
            "Healing Stream Totem",
            "Mana Spring Totem",
            "Mana Tide Totem",
            "Poison Cleansing Totem",
            "Disease Cleansing Totem",
            "Fire Resistance Totem",
        } },
        { name = "Air Totems", spells = {
            "Grounding Totem",
            "Windfury Totem",
            "Grace of Air Totem",
            "Windwall Totem",
            "Nature Resistance Totem",
            "Sentry Totem",
            "Tranquil Air Totem",
        } },
    },

    mouseoverEnemy = {
        "Lightning Bolt",
        "Chain Lightning",
        "Lava Burst",
        "Earth Shock",
        "Flame Shock",
        "Frost Shock",
        "Purge",
    },

    mouseoverFriend = {
        "Healing Wave",
        "Lesser Healing Wave",
        "Chain Heal",
        "Riptide",
        "Ancestral Spirit",
        "Cure Poison",
        "Cure Disease",
        "Water Breathing",
        "Water Walking",
    },

    dispels = {
        "Purge",
    },

    buffs = {
        "Water Breathing",
        "Water Walking",
    },

    cursor = {
        "Totemic Projection",
    },

    cooldowns = {
        "Rage of the Farseer",
        "Elemental Mastery",
        "Nature's Swiftness",
    },

    offGcd = {
        "Nature's Swiftness",
    },

    channeled = {},

    stealth = {},

    extraSpells = {
        8071, -- Stoneskin Totem
        3599, -- Searing Totem
        5394, -- Healing Stream Totem
    },

    custom = {},
}
