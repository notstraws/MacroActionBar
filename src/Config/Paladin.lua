local _, smb = ...

-- The Paladin page. See Config.lua for what each list does.
smb.classConfigs.PALADIN = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Judgement",
            "Swift Judgement",
            "Holy Strike",
            "Exorcism",
            "Hammer of Wrath",
            "Consecration",
            "Holy Wrath",
            "Holy Shield",
        } },
        { name = "Healing", cooldownSteps = true, spells = {
            "Holy Light",
            "Flash of Light",
            "Holy Shock",
            "Lay on Hands",
            "Divine Favor",
            "Light's Vigil",
        } },
        { name = "Utility", spells = {
            "Hammer of Justice",
            "Repentance",
            "Turn Undead",
            "Purify",
            "Cleanse",
            "Redemption",
            "Divine Intervention",
            "Sense Undead",
            "Summon Warhorse",
            "Summon Charger",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Seal of *",
            "Salvation",
            "Mass Salvation",
            "Righteous Fury",
            "Divine Protection",
            "Divine Shield",
            "Voice of Truth",
            "Templar's Bulwark",
        } },
        { name = "Blessings", sequence = true, spells = {
            "Blessing of *",
            "Greater Blessing of *",
        } },
        { name = "Auras", noGlow = true, spells = {
            "Devotion Aura",
            "Retribution Aura",
            "Concentration Aura",
            "Sanctity Aura",
            "Shadow Resistance Aura",
            "Frost Resistance Aura",
            "Fire Resistance Aura",
        } },
    },

    mouseoverEnemy = {
        "Judgement",
        "Exorcism",
        "Hammer of Wrath",
        "Hammer of Justice",
        "Repentance",
        "Turn Undead",
        "Swift Judgement",
        "Light's Vigil",
    },

    mouseoverFriend = {
        "Holy Light",
        "Flash of Light",
        "Holy Shock",
        "Lay on Hands",
        "Blessing of *",
        "Greater Blessing of *",
        "Purify",
        "Cleanse",
        "Redemption",
        "Divine Intervention",
        "Light's Vigil",
        "Salvation",
        "Mass Salvation",
    },

    buffs = {
        "Blessing of *",
        "Greater Blessing of *",
    },

    cursor = {},

    cooldowns = {
        "Divine Favor",
    },

    offGcd = {},

    channeled = {},

    stealth = {},

    extraSpells = {
        7328, -- Redemption
        5502, -- Sense Undead
        13819, -- Summon Warhorse
        23214, -- Summon Charger,
        1311015, -- Templar's Bulwark
        1310994, -- Swift Judgement
        1310911, -- Light's Vigil
    },

    custom = {
        { name = "Swift Judge", icon = 135959,
          body = "#showtooltip Judgement\n/cast Swift Judgement\n/cast Judgement" },
    },
}
