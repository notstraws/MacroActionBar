local _, smb = ...

-- The Mage page. See Config.lua for what each list does.
smb.classConfigs.MAGE = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Frostbolt",
            "Fireball",
            "Frostfire Bolt",
            "Arcane Blast",
            "Ice Lance",
            "Fire Blast",
            "Scorch",
            "Pyroblast",
            "Arcane Missiles",
            "Arcane Explosion",
            "Flamestrike",
            "Blizzard",
            "Blast Wave",
            "Cone of Cold",
            "Frost Nova",
        } },
        { name = "Utility", spells = {
            "Polymorph*",
            "Counterspell",
            "Blink",
            "Slow Fall",
            "Remove Lesser Curse",
            "Evocation",
            "Comprehend Scroll",
            "Conjure *",
            "Teleport: *",
            "Portal: *",
            "Presence of Mind",
            "Arcane Power",
            "Combustion",
            "Cold Snap",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Arcane Intellect",
            "Arcane Brilliance",
            "Amplify Magic",
            "Dampen Magic",
            "Frost Armor",
            "Ice Armor",
            "Mage Armor",
            "Mana Shield",
            "Fire Ward",
            "Frost Ward",
            "Ice Barrier",
            "Ice Block",
        } },
    },

    mouseoverEnemy = {
        "Frostbolt",
        "Fireball",
        "Frostfire Bolt",
        "Arcane Blast",
        "Ice Lance",
        "Fire Blast",
        "Scorch",
        "Pyroblast",
        "Arcane Missiles",
        "Polymorph*",
        "Counterspell",
    },

    mouseoverFriend = {
        "Arcane Intellect",
        "Amplify Magic",
        "Dampen Magic",
        "Remove Lesser Curse",
        "Slow Fall",
    },

    buffs = {
        "Arcane Intellect",
        "Amplify Magic",
        "Dampen Magic",
    },

    cursor = {
        "Flamestrike",
        "Blizzard",
    },

    cooldowns = {
        "Presence of Mind",
        "Arcane Power",
        "Combustion",
    },

    channeled = {
        "Arcane Missiles",
        "Blizzard",
        "Evocation",
    },

    stealth = {},

    extraSpells = {
        28272, -- Polymorph: Pig
    },

    custom = {},
}
