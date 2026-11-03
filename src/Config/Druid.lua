local _, smb = ...

-- The Druid page. See Config.lua for what each list does.
smb.classConfigs.DRUID = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Wrath",
            "Starfire",
            "Moonfire",
            "Insect Swarm",
            "Hurricane",
            "Faerie Fire",
        } },
        { name = "Cat", cooldownSteps = true, spells = {
            "Cat Form",
            "Prowl",
            "Shred",
            "Rake",
            "Rip",
            "Ferocious Bite",
            "Primal Bite",
            "Ravage",
            "Pounce",
            "Claw",
            "Tiger's Fury",
            "Berserk",
            "Dash",
            "Cower",
        } },
        { name = "Bear", cooldownSteps = true, spells = {
            "Bear Form",
            "Dire Bear Form",
            "Maul",
            "Swipe",
            "Lacerate",
            "Faerie Fire (Feral)",
            "Growl",
            "Challenging Roar",
            "Demoralizing Roar",
            "Enrage",
            "Bash",
            "Feral Charge",
            "Frenzied Regeneration",
        } },
        { name = "Healing", cooldownSteps = true, spells = {
            "Healing Touch",
            "Regrowth",
            "Rejuvenation",
            "Wild Growth",
            "Swiftmend",
            "Tranquility",
            "Nature's Swiftness",
            "Rebirth",
            "Revive",
        } },
        { name = "Utility", spells = {
            "Entangling Roots",
            "Hibernate",
            "Soothe Animal",
            "Remove Curse",
            "Abolish Poison",
            "Cure Poison",
            "Innervate",
            "Teleport: Moonglade",
            "Track Humanoids",
            "Travel Form",
            "Aquatic Form",
            "Moonkin Form",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Mark of the Wild",
            "Gift of the Wild",
            "Thorns",
            "Omen of Clarity",
            "Nature's Grasp",
            "Barkskin",
        } },
    },

    mouseoverEnemy = {
        "Wrath",
        "Starfire",
        "Moonfire",
        "Insect Swarm",
        "Entangling Roots",
        "Faerie Fire",
        "Faerie Fire (Feral)",
        "Hibernate",
        "Soothe Animal",
    },

    mouseoverFriend = {
        "Healing Touch",
        "Regrowth",
        "Rejuvenation",
        "Wild Growth",
        "Swiftmend",
        "Rebirth",
        "Revive",
        "Remove Curse",
        "Abolish Poison",
        "Cure Poison",
        "Innervate",
        "Mark of the Wild",
        "Gift of the Wild",
        "Thorns",
    },

    cursor = {
        "Hurricane",
    },

    cooldowns = {
        "Nature's Swiftness",
        "Berserk",
    },

    channeled = {
        "Tranquility",
        "Hurricane",
    },

    stealth = {
        "Prowl",
    },

    extraSpells = {
        5487, -- Bear Form
        768, -- Cat Form
        1066, -- Aquatic Form
        8946, -- Cure Poison
        18960, -- Teleport: Moonglade
    },

    custom = {},
}
