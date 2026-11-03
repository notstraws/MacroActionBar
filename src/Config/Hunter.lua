local _, smb = ...

-- The Hunter page. See Config.lua for what each list does.
smb.classConfigs.HUNTER = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Arcane Shot",
            "Aimed Shot",
            "Multi-Shot",
            "Sniper Shot",
            "Serpent Sting",
            "Volley",
            "Raptor Strike",
            "Mongoose Bite",
            "Counterattack",
            "Strider Kick",
            "Immolation Trap",
            "Explosive Trap",
        } },
        { name = "Utility", spells = {
            "Hunter's Mark",
            "Concussive Shot",
            "Distracting Shot",
            "Scatter Shot",
            "Scorpid Sting",
            "Viper Sting",
            "Wyvern Sting",
            "Wing Clip",
            "Disengage",
            "Feign Death",
            "Freezing Trap",
            "Frost Trap",
            "Track *",
            "Flare",
            "Eagle Eye",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Aspect of *",
            "Trueshot Aura",
            "Rapid Fire",
            "Deterrence",
        } },
        { name = "Pets", spells = {
            "Call Pet",
            "Dismiss Pet",
            "Revive Pet",
            "Mend Pet",
            "Feed Pet",
            "Tame Beast",
            "Beast Training",
            "Beast Lore",
            "Eyes of the Beast",
            "Scare Beast",
            "Intimidation",
            "Bestial Wrath",
            "Summon Hawk",
        } },
    },

    mouseoverEnemy = {
        "Arcane Shot",
        "Aimed Shot",
        "Multi-Shot",
        "Sniper Shot",
        "Concussive Shot",
        "Distracting Shot",
        "Scatter Shot",
        "Serpent Sting",
        "Scorpid Sting",
        "Viper Sting",
        "Wyvern Sting",
        "Hunter's Mark",
        "Scare Beast",
        "Beast Lore",
    },

    mouseoverFriend = {},

    buffs = {},

    cursor = {
        "Volley",
        "Flare",
    },

    cooldowns = {
        "Rapid Fire",
        "Bestial Wrath",
    },

    channeled = {
        "Volley",
        "Eyes of the Beast",
        "Eagle Eye",
        "Mend Pet",
    },

    stealth = {},

    extraSpells = {
        1515, -- Tame Beast
        5149, -- Beast Training
        883, -- Call Pet
        2641, -- Dismiss Pet
        6991, -- Feed Pet
        982, -- Revive Pet
    },

    custom = {},
}
