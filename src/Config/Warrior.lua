local _, smb = ...

-- The Warrior page. See Config.lua for what each list does.
smb.classConfigs.WARRIOR = {
    categories = {
        { name = "Custom" },
        { name = "Stances", noGlow = true, spells = {
            "Battle Stance",
            "Defensive Stance",
            "Berserker Stance",
        } },
        { name = "Arms", cooldownSteps = true, spells = {
            "Heroic Strike",
            "Mortal Strike",
            "Overpower",
            "Rend",
            "Thunder Clap",
            "Sweeping Strikes",
            "Spearing Strike",
        } },
        { name = "Fury", cooldownSteps = true, spells = {
            "Bloodthirst",
            "Whirlwind",
            "Slam",
            "Cleave",
            "Execute",
            "Victory Rush",
        } },
        { name = "Protection", cooldownSteps = true, spells = {
            "Shield Slam",
            "Revenge",
            "Sunder Armor",
        } },
        { name = "Utility", spells = {
            "Charge",
            "Intercept",
            "Hamstring",
            "Piercing Howl",
            "Intimidating Shout",
            "Concussion Blow",
            "Shield Bash",
            "Pummel",
            "Taunt",
            "Mocking Blow",
            "Challenging Shout",
            "Demoralizing Shout",
            "Disarm",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Battle Shout",
            "Bloodrage",
            "Berserker Rage",
            "Death Wish",
            "Recklessness",
            "Retaliation",
            "Shield Block",
            "Shield Wall",
            "Last Stand",
        } },
    },

    mouseoverEnemy = {
        "Charge",
        "Intercept",
        "Taunt",
        "Mocking Blow",
        "Shield Bash",
        "Pummel",
    },

    mouseoverFriend = {},

    buffs = {},

    cursor = {},

    cooldowns = {
        "Death Wish",
        "Recklessness",
        "Sweeping Strikes",
    },

    -- the stances, so they can be ticked in every macro's Before Casting and After Casting menus
    offGcd = {
        "Battle Stance",
        "Defensive Stance",
        "Berserker Stance",
    },

    channeled = {},

    stealth = {},

    -- the stances each spell can be cast in
    stances = {
        ["Charge"] = { "Battle Stance" },
        ["Overpower"] = { "Battle Stance" },
        ["Mocking Blow"] = { "Battle Stance" },
        ["Thunder Clap"] = { "Battle Stance" },
        ["Retaliation"] = { "Battle Stance" },
        ["Sweeping Strikes"] = { "Battle Stance" },
        ["Hamstring"] = { "Battle Stance", "Berserker Stance" },
        ["Execute"] = { "Battle Stance", "Berserker Stance" },
        ["Rend"] = { "Battle Stance", "Defensive Stance" },
        ["Shield Bash"] = { "Defensive Stance", "Battle Stance" },
        ["Taunt"] = { "Defensive Stance" },
        ["Revenge"] = { "Defensive Stance" },
        ["Disarm"] = { "Defensive Stance" },
        ["Shield Block"] = { "Defensive Stance" },
        ["Shield Wall"] = { "Defensive Stance" },
        ["Intercept"] = { "Berserker Stance" },
        ["Whirlwind"] = { "Berserker Stance" },
        ["Pummel"] = { "Berserker Stance" },
        ["Berserker Rage"] = { "Berserker Stance" },
        ["Recklessness"] = { "Berserker Stance" },
    },

    -- the stances a spell macro can cast another spell in
    forms = {
        { name = "Battle", spells = { "Battle Stance" } },
        { name = "Defensive", spells = { "Defensive Stance" } },
        { name = "Berserker", spells = { "Berserker Stance" } },
    },

    extraSpells = {
        71, -- Defensive Stance
        355, -- Taunt
        7386, -- Sunder Armor
        2458, -- Berserker Stance
        20252, -- Intercept,
        12975, -- Last Stand
        12809, -- Concussion Blow
        23922, -- Shield Slam
        12323, -- Piercing Howl
        12328, -- Death Wish
        23881, -- Bloodthirst
        1310222, -- Spearing Strike
        12292, -- Sweeping Strikes
        12294, -- Mortal Strike
    },

    custom = {},
}
