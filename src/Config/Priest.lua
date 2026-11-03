local _, smb = ...

-- The Priest page. See Config.lua for what each list does.
smb.classConfigs.PRIEST = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Smite",
            "Holy Fire",
            "Mind Blast",
            "Shadow Word: Pain",
            "Shadow Word: Death",
            "Mind Flay",
            "Devouring Plague",
            "Starshards",
            "Chastise",
            "Hex of Weakness",
            "Touch of Weakness",
            "Mana Burn",
            "Vampiric Embrace",
        } },
        { name = "Healing", cooldownSteps = true, spells = {
            "Lesser Heal",
            "Heal",
            "Greater Heal",
            "Flash Heal",
            "Renew",
            "Power Word: Shield",
            "Binding Heal",
            "Prayer of Mending",
            "Penance",
            "Prayer of Healing",
            "Holy Nova",
            "Desperate Prayer",
            "Lightwell",
        } },
        { name = "Utility", spells = {
            "Dispel Magic",
            "Cure Disease",
            "Abolish Disease",
            "Psychic Scream",
            "Shackle Undead",
            "Mind Control",
            "Mind Soothe",
            "Mind Vision",
            "Fade",
            "Silence",
            "Resurrection",
            "Levitate",
            "Confounding Flash",
            "Dark Sacrifice",
            "Contingency Plan",
            "Divine Grace",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Power Word: Fortitude",
            "Prayer of Fortitude",
            "Divine Spirit",
            "Prayer of Spirit",
            "Shadow Protection",
            "Prayer of Shadow Protection",
            "Fear Ward",
            "Inner Fire",
            "Inner Focus",
            "Power Infusion",
            "Shadowform",
            "Shadowguard",
            "Feedback",
            "Elune's Grace",
        } },
    },

    mouseoverEnemy = {
        "Smite",
        "Holy Fire",
        "Mind Blast",
        "Shadow Word: Pain",
        "Shadow Word: Death",
        "Mind Flay",
        "Devouring Plague",
        "Starshards",
        "Chastise",
        "Hex of Weakness",
        "Mana Burn",
        "Vampiric Embrace",
        "Shackle Undead",
        "Mind Control",
        "Mind Soothe",
        "Silence",
    },

    mouseoverFriend = {
        "Lesser Heal",
        "Heal",
        "Greater Heal",
        "Flash Heal",
        "Renew",
        "Power Word: Shield",
        "Binding Heal",
        "Prayer of Mending",
        "Penance",
        "Dispel Magic",
        "Cure Disease",
        "Abolish Disease",
        "Resurrection",
        "Levitate",
        "Power Word: Fortitude",
        "Prayer of Fortitude",
        "Divine Spirit",
        "Prayer of Spirit",
        "Shadow Protection",
        "Prayer of Shadow Protection",
        "Fear Ward",
        "Power Infusion",
    },

    dispels = {
        "Dispel Magic",
    },

    buffs = {
        "Power Word: Fortitude",
        "Divine Spirit",
        "Shadow Protection",
        "Fear Ward",
        "Power Infusion",
    },

    cursor = {},

    cooldowns = {
        "Inner Focus",
        "Power Infusion",
    },

    offGcd = {
        "Inner Focus",
        "Power Infusion",
        "Shadowform",
    },

    channeled = {
        "Mind Flay",
        "Mind Control",
        "Penance",
    },

    stealth = {},

    toggle = {
        "Shadowform",
    },

    extraSpells = {
        10060, -- Power Infusion
        14751, -- Inner Focus
        15473, -- Shadowform
        15286, -- Vampiric Embrace
    },

    custom = {
        { name = "Spam Wand", icon = 132317, body = "/castsequence !Shoot,!Shoot" },
    },
}
