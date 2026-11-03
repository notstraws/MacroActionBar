local _, smb = ...

-- The Hunter page. See Config.lua for what each list does.
smb.classConfigs.HUNTER = {
    categories = {
        { name = "Custom" },
        { name = "Damage", cooldownSteps = true, spells = {
            "Auto Shot",
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
            "Summon Hawk",
        } },
        { name = "Traps", cooldownSteps = true, spells = {
            "Immolation Trap",
            "Explosive Trap",
            "Freezing Trap",
            "Frost Trap",
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
            "Scare Beast",
            "Flare",
            "Eagle Eye",
        } },
        { name = "Buffs & Defence", sequence = true, spells = {
            "Trueshot Aura",
            "Rapid Fire",
            "Deterrence",
        } },
        { name = "Aspects", spells = {
            "Aspect of *",
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
            "Intimidation",
            "Bestial Wrath",
        } },
        { name = "Tracking", spells = {
            "Track *",
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

    offGcd = {
        "Rapid Fire",
    },

    channeled = {
        "Volley",
        "Eyes of the Beast",
        "Eagle Eye",
        "Mend Pet",
    },

    stealth = {},

    toggle = {
        "Auto Shot",
        "Aspect of *",
    },

    extraSpells = {
        1515, -- Tame Beast
        5149, -- Beast Training
        883, -- Call Pet
        2641, -- Dismiss Pet
        6991, -- Feed Pet
        982, -- Revive Pet
    },

    custom = {
        -- turns on the Track spell for the target's creature type; does nothing with no target
        { name = "One Button Tracking", icon = "Interface\\Icons\\Ability_Tracking",
          description = "Tracks your target's creature type, e.g. Track Beasts on a beast. Does nothing with no target.",
          body = "/run local c=UnitCreatureType(\"target\")if c then for i=1,C_Minimap.GetNumTrackingTypes()do "
              .. "local t=C_Minimap.GetTrackingInfo(i)if t and t.name:find(c,1,true)then "
              .. "C_Minimap.SetTracking(i,true)break end end end" },
        -- recalls the pet if it has a target, otherwise sends it at yours
        { name = "Pet Attack/Recall",
          description = "Sends your pet to attack your target. If your pet is already attacking, calls it back to you instead. Works in combat.",
          body = "#showtooltip Attack\n/petfollow [@pettarget,exists]\n/petattack [@pettarget,noexists]" },
    },
}
