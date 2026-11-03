local _, smb = ...

-- The Warlock page. See Config.lua for what each list does.
smb.classConfigs.WARLOCK = {
    categories = {
        { name = "Custom" },
        { name = "Affliction", cooldownSteps = true, spells = {
            "Corruption",
            "Wrack",
            "Bane of *",
            "Curse of *",
            "Siphon Life",
            "Drain Life",
            "Drain Soul",
            "Amplify Curse",
        } },
        { name = "Destruction", cooldownSteps = true, spells = {
            "Shadow Bolt",
            "Immolate",
            "Incinerate",
            "Searing Pain",
            "Shadowburn",
            "Conflagrate",
            "Soul Fire",
            "Hellfire",
            "Rain of Fire",
        } },
        { name = "Utility", spells = {
            "Fel Domination",
            "Fear",
            "Howl of Terror",
            "Death Coil",
            "Banish",
            "Subjugate Demon",
            "Life Tap",
            "Dark Pact",
            "Drain Mana",
            "Health Funnel",
            "Summon Felsteed",
            "Summon Dreadsteed",
            "Create *",
            "Ritual of *",
            "Eye of Kilrogg",
            "Sense Demons",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Demon Skin",
            "Demon Armor",
            "Soul Link",
            "Demonic Sacrifice",
            "Shadow Ward",
            "Unending Breath",
            "Detect *",
        } },
        { name = "Pets", spells = {
            "Summon Imp",
            "Summon Voidwalker",
            "Summon Succubus",
            "Summon Incubus",
            "Summon Felhunter",
            "Ritual of Doom",
            "Inferno",
        } },
    },

    mouseoverEnemy = {
        "Shadow Bolt",
        "Immolate",
        "Incinerate",
        "Corruption",
        "Wrack",
        "Curse of *",
        "Bane of *",
        "Drain Life",
        "Drain Soul",
        "Drain Mana",
        "Fear",
        "Searing Pain",
        "Shadowburn",
        "Conflagrate",
        "Siphon Life",
        "Death Coil",
        "Soul Fire",
        "Banish",
        "Subjugate Demon",
    },

    mouseoverFriend = {
        "Unending Breath",
        "Detect Invisibility",
    },

    buffs = {
        "Unending Breath",
        "Detect Invisibility",
    },

    cursor = {
        "Rain of Fire",
        "Inferno",
    },

    raidRank1 = {
        "Curse of *",
    },

    cooldowns = {
        "Amplify Curse",
    },

    offGcd = {},

    channeled = {
        "Drain Life",
        "Drain Mana",
        "Drain Soul",
        "Health Funnel",
        "Hellfire",
        "Rain of Fire",
    },

    stealth = {},

    petAbilities = {
        ["Summon Imp"] = "Fire Shield",
        ["Summon Voidwalker"] = "Sacrifice",
        ["Summon Succubus"] = "Seduction",
        ["Summon Incubus"] = "Seduction",
        ["Summon Felhunter"] = "Spell Lock",
    },

    extraSpells = {
        18288, -- Amplify Curse
        18223, -- Curse of Exhaustion
        1316697, -- Wrack
        18788, -- Demonic Sacrifice
        18708, -- Fel Domination
        19028, -- Soul Link
        1225228, --  Bane of Havoc
        688, -- Summon Imp
        697, -- Summon Voidwalker
        712, -- Summon Succubus
        713, -- Summon Incubus
        691, -- Summon Felhunter
        1122, -- Inferno,
        18540, -- Ritual of Doom
    },

    custom = {
        { name = "Spam Wand", icon = 132317, body = "/castsequence !Shoot,!Shoot" },
        { name = "Devour Magic", icon = 136075, body = "#showtooltip \n/cast [@mouseover, exists] [@target, help] [@player] Devour Magic" },
        { name = "Pet Ability", icon = 618980,
          body = "#showtooltip\n/cast Fire Shield\n/cast Sacrifice\n/cast Spell Lock\n/cast Seduction" },
        { name = "Pet Ability (Mouseover)", icon = 618980,
          body = "#showtooltip\n/cast [pet:Voidwalker] Sacrifice; [pet:imp] Fire shield; [pet:succubus,@mouseover,exists,nodead][pet:succubus,@target] Seduction; [pet:felhunter,@mouseover,exists,nodead][pet:felhunter,@target] Devour Magic;" },
        -- recalls the pet if it has a target, otherwise sends it at yours
        { name = "Pet Attack/Recall",
          description = "Sends your pet to attack your target. If your pet is already attacking, calls it back to you instead. Works in combat.",
          body = "#showtooltip Attack\n/petfollow [@pettarget,exists]\n/petattack [@pettarget,noexists]" },
    },
}
