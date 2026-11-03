local _, smb = ...

-- The Mage page. See Config.lua for what each list does.
smb.classConfigs.MAGE = {
    categories = {
        { name = "Custom" },
        { name = "Arcane", cooldownSteps = true, spells = {
            "Arcane Blast",
            "Arcane Missiles",
            "Arcane Explosion",
            "Arcane Wrath",
        } },
        { name = "Fire", cooldownSteps = true, spells = {
            "Fireball",
            "Fire Blast",
            "Scorch",
            "Pyroblast",
            "Flamestrike",
            "Blast Wave",
        } },
        { name = "Frost", cooldownSteps = true, spells = {
            "Frostbolt",
            "Frostfire Bolt",
            "Ice Lance",
            "Blizzard",
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
        { name = "Conjure", spells = {
            "Conjure *",
        } },
        { name = "Teleports & Portals", spells = {
            "Teleport: *",
            "Portal: *",
        } },
    },

    mouseoverEnemy = {
        "Frostbolt",
        "Fireball",
        "Frostfire Bolt",
        "Arcane Blast",
        "Arcane Wrath",
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

    combatRank1 = {
        "Arcane Explosion",
        "Flamestrike",
    },

    cooldowns = {
        "Presence of Mind",
        "Arcane Power",
        "Combustion",
    },

    offGcd = {
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
        1326079, -- Arcane Wrath (talent)
    },

    custom = {
        { name = "Spam Wand", icon = 132317, body = "/castsequence !Shoot,!Shoot" },
    },
}
