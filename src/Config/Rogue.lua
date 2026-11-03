local _, smb = ...

-- The Rogue page. See Config.lua for what each list does.
smb.classConfigs.ROGUE = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Sinister Strike",
            "Backstab",
            "Mutilate",
            "Hemorrhage",
            "Ghostly Strike",
            "Riposte",
            "Ambush",
            "Garrote",
            "Eviscerate",
            "Rupture",
            "Slice and Dice",
            "Venom",
            "Expose Armor",
        } },
        { name = "Utility", spells = {
            "Kick",
            "Gouge",
            "Blind",
            "Sap",
            "Cheap Shot",
            "Kidney Shot",
            "Distract",
            "Feint",
            "Stealth",
            "Vanish",
            "Sprint",
            "Pick Pocket",
            "Pick Lock",
            "Detect Traps",
            "Disarm Trap",
            "Poisons",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Evasion",
            "Cold Blood",
            "Blade Flurry",
            "Adrenaline Rush",
            "Preparation",
            "Premeditation",
        } },
    },

    mouseoverEnemy = {
        "Kick",
        "Gouge",
        "Blind",
        "Sap",
        "Pick Pocket",
    },

    mouseoverFriend = {},

    buffs = {},

    cursor = {
        "Distract",
    },

    cooldowns = {
        "Cold Blood",
        "Blade Flurry",
        "Adrenaline Rush",
    },

    channeled = {},

    stealth = {
        "Stealth",
    },

    extraSpells = {
        14278, -- Ghostly Strike
        14183, -- Premeditation
        16511, -- Hemorrhage
        14185, -- Preparation
        14251, -- Riposte
        13877, -- Blade Flurry
        13750, -- Adrenaline Rush
        14166, -- Cold Blood
        1310707, -- Mutilate
        1310703, -- Venom
    },

    custom = {},
}
