local _, smb = ...

-- The Druid page. See Config.lua for what each list does.
smb.classConfigs.DRUID = {
    categories = {
        { name = "Custom" },
        { name = "Forms", menuLast = true, spells = {
            "Cat Form",
            "Bear Form",
            "Dire Bear Form",
            "Travel Form",
            "Aquatic Form",
            "Moonkin Form",
        } },
        { name = "Damage", cooldownSteps = true, spells = {
            "Wrath",
            "Starfire",
            "Moonfire",
            "Insect Swarm",
            "Hurricane",
            "Faerie Fire",
        } },
        { name = "Cat", cooldownSteps = true, spells = {
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
            "Shifting Power",
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

    buffs = {
        "Mark of the Wild",
        "Thorns",
    },

    cursor = {
        "Hurricane",
    },

    cooldowns = {
        "Nature's Swiftness",
        "Berserk",
    },

    offGcd = {
        "Nature's Swiftness",
    },

    channeled = {
        "Tranquility",
        "Hurricane",
    },

    stealth = {
        "Prowl",
    },

    forms = {
        { name = "Caster", section = "Damage" },
        { name = "Cat", spells = { "Cat Form" } },
        { name = "Bear", spells = { "Dire Bear Form", "Bear Form" } },
        { name = "Travel", spells = { "Travel Form" } },
        { name = "Aquatic", spells = { "Aquatic Form" } },
    },

    extraSpells = {
        5487, -- Bear Form
        768, -- Cat Form
        1066, -- Aquatic Form
        8946, -- Cure Poison
        18960, -- Teleport: Moonglade
        1322605, -- Shifting Power
    },

    custom = {
        -- no icon, so the page and action bar show Dash's icon and tooltip from #showtooltip
        { name = "Smart Travel",
          body = "#showtooltip Dash\n/cast [indoors,noform:2] Cat Form\n"
              .. "/cast [indoors,form:2] Dash\n/cast [swimming] !Aquatic Form\n/cast !Travel Form" },
    },
}
