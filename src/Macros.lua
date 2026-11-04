local addonName, smb = ...

-- Builds the page's macro list (smb.macros) from the spellbook and the player's class config, and keeps
-- the WoW macros it creates in step with it. No frames here: SpellBookTab.lua draws the page.

local ICON_QUESTION_MARK = 134400 -- Interface\Icons\INV_Misc_QuestionMark

local MAX_MACRO_NAME = 16 -- longer names are truncated by CreateMacro, so GetMacroIndexByName would miss them
local MAX_MACRO_BODY = 255
local FOCUS_SUFFIX = " @F" -- ends a focus copy's WoW macro name, keeping it apart from the spell's own
local NEAREST_SUFFIX = " @N" -- ends a nearest copy's WoW macro name, likewise
local ENEMY_SUFFIX = " @E" -- ends an enemy player copy's WoW macro name, likewise
local COMBAT_RANK_SUFFIX = " R1" -- ends a combat rank copy's WoW macro name, likewise

-- MAX_CHARACTER_MACROS and MAX_ACCOUNT_MACROS come from the load-on-demand Blizzard_MacroUI, so they
-- are nil until the macro window has been opened once.
local function maxCharacterMacros()
    return MAX_CHARACTER_MACROS or 18
end

local function maxAccountMacros()
    return MAX_ACCOUNT_MACROS or 120
end

-- Per-account sets of spell names, keyed by setting: "castOn" (where the macro casts, see smb.castOn:
-- "mouseover", on the mouseover unit first, or "cursor", a ground-targeted spell where the cursor points; it
-- replaced the old "mouseover" and "cursor" sets, see migrate, which are kept but no longer read), "focus" (the page
-- also lists a copy of the macro that casts on the focus target), "enemyPlayer" (the page also lists a
-- copy of a dispels spell's macro that casts on the nearest enemy player), "nearest" (the page also lists
-- a copy of a buffs spell's macro that casts on the nearest friendly player), "combatRank1" (the page also
-- lists a copy of a combatRank1 spell's macro that casts rank 1 out of combat), "pet" (a summon macro casts the
-- pet's ability while that pet is out), "raidRank1" (the macro casts rank 1 in a raid group), "spam"
-- (the macro does nothing while its channelled spell is channelling, its stealth spell is on, or you are in
-- its shapeshift form, and casts a toggle spell as "!<spell>" so it doesn't toggle off), "petAttack" (the macro also sends
-- the pet to attack before the cast), "stopCast" (the macro stops the current cast first) or "startAttack" (the macro
-- starts melee auto-attack after the cast). For petAttack, stopCast and startAttack, true or false overrides the
-- setting's default (optionDefault), nil follows it. "startAttackBefore" also adds /startattack before the
-- cast, and "petAttackAfter" /petattack after it (see smb.isLineOn); an old "stopCastAfter" is ignored. "autoShotBefore" and "autoShotAfter" add
-- "/cast !Auto Shot" before (or after) the cast (see smb.offersAutoShot); for autoShotAfter, true or false
-- overrides its default (autoShotDefault), nil follows it. "petFollowBefore" and "petFollowAfter" add /petfollow
-- before (or after) the cast (see smb.offersPetFollow), and "stopAttackBefore" and "stopAttackAfter" /stopattack
-- (offered with startAttack). "cancelIceBlockBefore" adds /cancelaura Ice Block before the cast (see
-- smb.offersCancelIceBlock). "clearDeadBefore" adds /cleartarget [dead] and "targetEnemyBefore" /targetenemy
-- [noharm][dead] before the cast (see smb.offersRetarget); true or false overrides their defaults (clearDeadDefault,
-- targetEnemyDefault), nil follows them. "useItems" and "useItemsAfter" hold a list of equipment
-- slots instead of a flag: the macro uses each slot's item, in that order, before (or after) the cast. "racials" and
-- "racialsAfter" hold a set of racial and offGcd spell names: the macro casts each one before (or after) the cast. "order" and
-- "orderAfter" hold the order the player ticked a side's lines in, as a list of ids ("stopCast", "startAttack",
-- "autoShot", "stopAttack", "petFollow", "petAttack", "cancelIceBlock", "clearDead", "targetEnemy", a racial's name or a slot number); it only orders the lines the settings above turn on (see sideEntries).
-- "equipStopAttack" and "equipStopCast" are keyed by inventory slot rather than spell name: the equipment macro
-- for that slot starts with /stopattack (or /stopcasting) before using the item. "modifiers" holds a table
-- per spell name, {shift = name, ctrl = name, alt = name}: the macro casts that spell while the key is held,
-- on the focus target when shiftFocus (ctrlFocus, altFocus) is true (see smb.modifierSpell), or uses the item in
-- equipment slot shiftSlot (ctrlSlot, altSlot) instead (see smb.modifierSlot). "sequence" holds a
-- list of spell names per spell: the macro /castsequences its own spell, then those, in that order. "followUp"
-- holds a cooldown spell's one spell name: the macro casts it on the same press, after its own. "forms"
-- holds a table per spell name, {[form name] = spell name}: the macro casts that spell while in that form of
-- the class config's forms (see smb.formSpell). A focus, enemy player, nearest or combat rank copy stores its
-- own settings under its spell's name plus the copy's suffix, e.g. "Polymorph @F" (see settingKey), and a
-- per-button copy under the key of the macro it came from plus " #<n>", e.g. "Fireball #2" (see buttonCopies).
-- Read lazily: saved variables are not loaded until ADDON_LOADED, after this file runs.
local function settings(key)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB[key] = MacroSpellbookDB[key] or {}
    return MacroSpellbookDB[key]
end

-- Whether the page also lists the class spells not learned yet, in their sections among the learned ones.
function smb.showsUnlearned()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.showUnlearned == true
end

function smb.setShowUnlearned(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.showUnlearned = on or nil
end

-- Whether a plain spell on an action bar counts as its macro being placed even when the macro has options
-- on (see smb.isOnActionBars). Macros with no options on always count it.
function smb.countsSpellsOnBars()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.countSpellsOnBars == true
end

function smb.setCountSpellsOnBars(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.countSpellsOnBars = on or nil
end

-- Whether "petAttack" is on for every enemy spell macro that has no setting of its own.
function smb.petAttacksByDefault()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.petAttackDefault == true
end

function smb.setPetAttacksByDefault(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.petAttackDefault = on or nil
end

-- Whether "stopCast" is on for every spell macro that has no setting of its own.
function smb.stopsCastingByDefault()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.stopCastDefault == true
end

function smb.setStopsCastingByDefault(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.stopCastDefault = on or nil
end

-- Whether "startAttack" is on for every spell macro that has no setting of its own.
function smb.startsAttackByDefault()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.startAttackDefault == true
end

function smb.setStartsAttackByDefault(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.startAttackDefault = on or nil
end

-- Whether "autoShotAfter" is on for every spell macro that has no setting of its own.
function smb.autoShotsByDefault()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.autoShotDefault == true
end

function smb.setAutoShotsByDefault(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.autoShotDefault = on or nil
end

-- Whether "clearDeadBefore" is on for every enemy spell macro that has no setting of its own.
function smb.clearsDeadByDefault()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.clearDeadDefault == true
end

function smb.setClearsDeadByDefault(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.clearDeadDefault = on or nil
end

-- Whether "targetEnemyBefore" is on for every enemy spell macro that has no setting of its own.
function smb.targetsEnemyByDefault()
    return MacroSpellbookDB ~= nil and MacroSpellbookDB.targetEnemyDefault == true
end

function smb.setTargetsEnemyByDefault(on)
    MacroSpellbookDB = MacroSpellbookDB or {}
    MacroSpellbookDB.targetEnemyDefault = on or nil
end

-- The settings with a default; each spell macro stores one only where it differs from the default.
local DEFAULTED = { petAttack = true, stopCast = true, startAttack = true }

-- The equipment macros' settings, keyed by the macro's slot (see settings).
local EQUIPMENT_OPTIONS = { equipStopAttack = true, equipStopCast = true }

-- The default of a setting that has one ("petAttack", "stopCast", "startAttack", "autoShotAfter",
-- "clearDeadBefore" or "targetEnemyBefore"), or nil.
local function optionDefault(key)
    if key == "petAttack" then return smb.petAttacksByDefault() end
    if key == "stopCast" then return smb.stopsCastingByDefault() end
    if key == "startAttack" then return smb.startsAttackByDefault() end
    if key == "autoShotAfter" then return smb.autoShotsByDefault() end
    if key == "clearDeadBefore" then return smb.clearsDeadByDefault() end
    if key == "targetEnemyBefore" then return smb.targetsEnemyByDefault() end
end

-- This character's per-button copies (see smb.newButtonCopy): {[key] = {[n] = true}}, by the settingKey of the
-- macro each came from. MacroSpellbookDB.buttonCopyOwners ({["Fireball #2"] = "<realm>-<name>"}) holds every
-- character's, so the numbers, which name the copies' settings and WoW macros, stay unique on the account.
local function buttonCopies()
    MacroSpellbookCharDB = MacroSpellbookCharDB or {}
    MacroSpellbookCharDB.buttonCopies = MacroSpellbookCharDB.buttonCopies or {}
    return MacroSpellbookCharDB.buttonCopies
end

local function toggleSetting(key, name)
    local set = settings(key)
    set[name] = not set[name] or nil
end

-- The options that add a copy of a spell macro. A copy stores them under its spell's name, like the spell's
-- own macro, so unticking one in the copy's menu removes the copy.
local COPY_OPTIONS = { focus = true, enemyPlayer = true, nearest = true, combatRank1 = true }

-- The key a spell macro stores a setting (key, optional) under: its spell's name, or, for a focus, enemy
-- player, nearest or combat rank copy, the name with the copy's suffix, so each copy has its own options apart
-- from its spell's macro. A per-button copy (see smb.newButtonCopy) adds " #<n>" to the key of the macro it
-- came from, e.g. "Fireball #2" or "Polymorph @F #2". COPY_OPTIONS are always stored under the spell's name.
local function settingKey(macro, key)
    if COPY_OPTIONS[key] then return macro.name end
    local base = macro.name
    if macro.focus then
        base = macro.name .. FOCUS_SUFFIX
    elseif macro.enemyPlayer then
        base = macro.name .. ENEMY_SUFFIX
    elseif macro.nearest then
        base = macro.name .. NEAREST_SUFFIX
    elseif macro.combatCopy then
        base = macro.name .. COMBAT_RANK_SUFFIX
    end
    if macro.buttonCopy then return base .. " #" .. macro.buttonCopy end
    return base
end

-- Turns a config list into a function returning a spell name's position in it, or nil. Entries ending
-- in * match by prefix.
local function nameMatcher(list)
    local exact, prefixes = {}, {}
    for i, entry in ipairs(list or {}) do
        local prefix = entry:match("^(.-)%*$")
        if prefix then
            prefixes[#prefixes + 1] = {prefix = prefix, index = i}
        elseif not exact[entry] then
            exact[entry] = i
        end
    end
    return function(name)
        if exact[name] then return exact[name] end
        for _, p in ipairs(prefixes) do
            if name:sub(1, #p.prefix) == p.prefix then return p.index end
        end
    end
end

local UNLISTED = math.huge -- spells in no category sort after everything else
local PET_CLASSES = { HUNTER = true, WARLOCK = true } -- classes with a combat pet; only they get pet settings
-- classes that fight with auto-attack; they get "startAttack" in place of "stopCast"
local MELEE_CLASSES = { WARRIOR = true, HUNTER = true, ROGUE = true }
-- hybrid classes that both cast and melee; they get "stopCast" and "startAttack"
local HYBRID_CLASSES = { DRUID = true, PALADIN = true, SHAMAN = true }

local config -- the player's class config with its matchers, built on first use

-- The player's class config (Config/<Class>.lua), with its lists compiled into matchers. Built lazily so
-- every config file has loaded first.
local function classConfig()
    if config then return config end
    local class = select(2, UnitClass("player"))
    local source = smb.classConfigs[class] or {}
    local hasPet = PET_CLASSES[class] == true
    config = {
        categories = source.categories or {},
        custom = source.custom or {},
        extraSpells = source.extraSpells or {},
        petAbilities = hasPet and source.petAbilities or {},
        stances = source.stances or {},
        forms = source.forms or {},
        hasStances = source.stances ~= nil,
        petAttack = hasPet,
        stopCast = MELEE_CLASSES[class] ~= true,
        startAttack = MELEE_CLASSES[class] == true or HYBRID_CLASSES[class] == true,
        categoryMatchers = {},
        categoryRankByName = {},
        isEnemySpell = nameMatcher(source.mouseoverEnemy),
        isFriendSpell = nameMatcher(source.mouseoverFriend),
        isCursorSpell = nameMatcher(source.cursor),
        isRaidRank1Spell = nameMatcher(source.raidRank1),
        isCombatRank1Spell = nameMatcher(source.combatRank1),
        isChanneledSpell = nameMatcher(source.channeled),
        isStealthSpell = nameMatcher(source.stealth),
        isToggleSpell = nameMatcher(source.toggle),
        isCooldownSpell = nameMatcher(source.cooldowns),
        isOffGcdSpell = nameMatcher(source.offGcd),
        isBuffSpell = nameMatcher(source.buffs),
        isDispelSpell = nameMatcher(source.dispels),
    }
    for rank, category in ipairs(config.categories) do
        config.categoryMatchers[rank] = nameMatcher(category.spells)
        config.categoryRankByName[category.name] = config.categoryRankByName[category.name] or rank
    end
    return config
end

-- A spell's section rank, section name and position within it. The first matching category wins.
local function categoryOf(name)
    local c = classConfig()
    for rank, matches in ipairs(c.categoryMatchers) do
        local priority = matches(name)
        if priority then return rank, c.categories[rank].name, priority end
    end
    return UNLISTED, "Unsorted", UNLISTED
end

-- Whether a spell is cast on an enemy unit: harmful and with a range. Self-centred AoE such as Arcane
-- Explosion or Hellfire has no range, so it is left out. The C_Spell functions take the spell's id; the
-- older globals take its name (a number would be read as a spellbook slot).
local function targetsEnemy(name, id)
    if C_Spell and C_Spell.IsSpellHarmful and C_Spell.SpellHasRange then
        return id ~= nil and C_Spell.IsSpellHarmful(id) == true and C_Spell.SpellHasRange(id) == true
    end
    if IsHarmfulSpell and SpellHasRange then
        return IsHarmfulSpell(name) == true and SpellHasRange(name) == true
    end
    return false
end

-- The macro conditional a spell's mouseover option uses, or nil for spells without one. Enemy spells are
-- the mouseoverEnemy list plus every spell targetsEnemy finds, except cursor spells. A spell that is both
-- an enemy and a friend spell casts on any unit.
local function targetOf(name, id)
    local c = classConfig()
    local enemy = c.isEnemySpell(name) or (not c.isCursorSpell(name) and targetsEnemy(name, id))
    local friend = c.isFriendSpell(name)
    if enemy and friend then return "exists" end
    if enemy then return "harm" end
    if friend then return "help" end
end

-- Whether the player's class has a combat pet, which turns on the "petAttack" option.
function smb.classOffersPetAttack()
    return classConfig().petAttack
end

-- Enemy spell macros offer "petAttack" when the class does.
function smb.offersPetAttack(macro)
    return smb.classOffersPetAttack() and macro.target == "harm" and not macro.custom
end

-- Whether the player's class offers "stopCast": every class but a melee one.
function smb.classOffersStopCast()
    return classConfig().stopCast
end

-- Whether the player's class offers "startAttack": melee and hybrid classes.
function smb.classOffersStartAttack()
    return classConfig().startAttack
end

-- Every spell macro offers "stopCast" (casters and hybrids) and "startAttack" (melee and hybrids), but not
-- "startAttack" on a stealth spell: attacking would break the stealth.
-- Custom and equipment macros offer neither.
function smb.offersStopCast(macro)
    return not macro.custom and not macro.equipment and smb.classOffersStopCast()
end

function smb.offersStartAttack(macro)
    return not macro.custom and not macro.equipment and not macro.stealth and smb.classOffersStartAttack()
end

-- A Hunter's spell macros, but Auto Shot's own, offer an "autoShot" line on either side of the cast once
-- Auto Shot is learned. Custom and equipment macros don't offer it.
function smb.offersAutoShot(macro)
    return smb.classOffersAutoShot() and macro.name ~= "Auto Shot" and not macro.custom and not macro.equipment
end

-- Whether the player is a Hunter who has learned Auto Shot.
function smb.classOffersAutoShot()
    if select(2, UnitClass("player")) ~= "HUNTER" then return false end
    local autoShot = smb.macroByName["Auto Shot"]
    return autoShot ~= nil and not autoShot.unlearned
end

-- Whether a macro offers an option ("focus", "enemyPlayer", "nearest", "combatRank1", "pet", "raidRank1", "spam",
-- "petAttack", "stopCast" or "startAttack", or an equipment macro's "equipStopAttack" or "equipStopCast") and
-- the player turned it on.
function smb.isOptionOn(macro, key)
    if EQUIPMENT_OPTIONS[key] then
        return macro.equipment == true and settings(key)[macro.slot] == true
    end
    if DEFAULTED[key] then
        local offered
        if key == "petAttack" then
            offered = smb.offersPetAttack(macro)
        elseif key == "stopCast" then
            offered = smb.offersStopCast(macro)
        else
            offered = smb.offersStartAttack(macro)
        end
        if not offered then return false end
        local on = settings(key)[settingKey(macro)]
        if on == nil then return optionDefault(key) end
        return on
    end
    local offered
    if key == "nearest" then
        offered = macro.buff
    elseif key == "enemyPlayer" then
        offered = macro.dispel
    elseif key == "combatRank1" then
        offered = macro.combatRank1
    elseif key == "pet" then
        offered = macro.petAbility ~= nil
    elseif key == "raidRank1" then
        offered = macro.raidRank1
    elseif key == "spam" then
        offered = macro.spam ~= nil
    else
        offered = macro.target ~= nil
    end
    return offered and settings(key)[settingKey(macro, key)] == true
end

-- The saved settings' format: 2 stores where a macro casts as one "castOn" setting instead of the old
-- "mouseover" and "cursor" flags.
local SCHEMA = 2

-- Brings the account's saved settings up to SCHEMA, once. Every "mouseover" spell casts on the mouseover,
-- then every "cursor" spell at the cursor, so a spell that had both keeps casting at the cursor, as castBody
-- did. The old sets stay in the saved variables but are no longer read.
local function migrate()
    MacroSpellbookDB = MacroSpellbookDB or {}
    if (MacroSpellbookDB.schema or 1) >= SCHEMA then return end
    local castOn = settings("castOn")
    for _, mode in ipairs({"mouseover", "cursor"}) do
        for key, on in pairs(MacroSpellbookDB[mode] or {}) do
            if on == true then castOn[key] = mode end
        end
    end
    MacroSpellbookDB.schema = SCHEMA
end

-- The "castOn" settings, migrated first.
local function castOnSettings()
    migrate()
    return settings("castOn")
end

-- Whether a macro offers a "castOn" mode: nil (Target, the plain cast) always, "mouseover" when its spell has
-- a mouseover conditional (macro.target) and "cursor" for a ground-targeted spell (macro.cursor). A focus,
-- enemy player or nearest copy casts on its own target, so it offers neither, nor do custom and equipment
-- macros.
function smb.offersCastOn(macro, mode)
    if mode == nil then return true end
    if macro.custom or macro.equipment or macro.focus or macro.enemyPlayer or macro.nearest then return false end
    if mode == "mouseover" then return macro.target ~= nil end
    if mode == "cursor" then return macro.cursor == true end
    return false
end

-- Where a macro casts: nil (on the target), "mouseover" or "cursor". A summon macro casting its pet's ability
-- (the "pet" option) casts on neither, so it is nil while that is on, keeping the setting. A copy has its own
-- (see settingKey).
function smb.castOn(macro)
    if smb.isOptionOn(macro, "pet") then return nil end
    local mode = castOnSettings()[settingKey(macro)]
    if mode ~= nil and smb.offersCastOn(macro, mode) then return mode end
end

-- The side of the cast the stopCast, startAttack and petAttack settings themselves (with their defaults) put
-- the line on, the setting that adds it on the other side too, and the function saying whether a macro
-- offers the line. stopCast has no other side: stopping a cast after casting would cancel the spell just cast.
local PLACEMENT = {
    stopCast = {main = "before", offered = smb.offersStopCast},
    startAttack = {main = "after", other = "before", setting = "startAttackBefore", offered = smb.offersStartAttack},
    petAttack = {main = "before", other = "after", setting = "petAttackAfter", offered = smb.offersPetAttack},
}

-- Hunters' and Warlocks' spell macros offer a "petFollow" line on either side of the cast, calling the pet
-- back. Custom and equipment macros don't offer it.
function smb.offersPetFollow(macro)
    return smb.classOffersPetAttack() and not macro.custom and not macro.equipment
end

-- A Mage's spell macros, but Ice Block's own, offer a "cancelIceBlock" line before the cast once Ice Block
-- is learned: /cancelaura Ice Block, so the cast isn't blocked while Ice Block is on. Custom and equipment
-- macros don't offer it.
function smb.offersCancelIceBlock(macro)
    if macro.name == "Ice Block" or macro.custom or macro.equipment then return false end
    local iceBlock = smb.macroByName["Ice Block"]
    return iceBlock ~= nil and not iceBlock.unlearned
end

-- An enemy spell's macro offers a "clearDead" line before the cast, /cleartarget [dead], dropping a dead
-- target, and a "targetEnemy" line, /targetenemy [noharm][dead], targeting the nearest enemy when you have no
-- live hostile target. Focus and enemy player copies cast on their own target, so they offer neither, nor do
-- custom and equipment macros.
function smb.offersRetarget(macro)
    return macro.target == "harm" and not macro.custom and not macro.equipment and not macro.focus
        and not macro.enemyPlayer
end

-- The lines with no default and no main side: a setting per side, each on or off by itself, and the
-- function saying whether a macro offers the line. A line with no setting for a side is never on there.
local SIDE_SETTINGS = {
    autoShot = {before = "autoShotBefore", after = "autoShotAfter", offered = smb.offersAutoShot},
    petFollow = {before = "petFollowBefore", after = "petFollowAfter", offered = smb.offersPetFollow},
    stopAttack = {before = "stopAttackBefore", after = "stopAttackAfter", offered = smb.offersStartAttack},
    cancelIceBlock = {before = "cancelIceBlockBefore", offered = smb.offersCancelIceBlock},
    clearDead = {before = "clearDeadBefore", offered = smb.offersRetarget},
    targetEnemy = {before = "targetEnemyBefore", offered = smb.offersRetarget},
}

-- Whether a macro has its "stopCast", "startAttack", "stopAttack", "autoShot", "petFollow", "petAttack",
-- "cancelIceBlock", "clearDead" or "targetEnemy" line on a side ("before" or "after") of the cast; all but stopCast,
-- cancelIceBlock, clearDead and targetEnemy can be on either, both or neither, those four only before. A copy has its own (see settingKey).
function smb.isLineOn(macro, key, side)
    if SIDE_SETTINGS[key] then
        if not SIDE_SETTINGS[key].offered(macro) then return false end
        local setting = SIDE_SETTINGS[key][side]
        if not setting then return false end
        local on = settings(setting)[settingKey(macro)]
        if on == nil then return optionDefault(setting) == true end
        return on
    end
    local placement = PLACEMENT[key]
    if side == placement.main then return smb.isOptionOn(macro, key) end
    if side ~= placement.other then return false end
    return placement.offered(macro) and settings(placement.setting)[settingKey(macro)] == true
end

-- Whether a macro offers a way to cast other than the plain spell's (any option but stopCast and
-- startAttack).
function smb.hasCastOptions(macro)
    return macro.target ~= nil or macro.buff or macro.cursor or macro.petAbility ~= nil or macro.raidRank1
        or macro.combatRank1 or macro.spam ~= nil or smb.hasSequenceOn(macro) or smb.hasFollowUpOn(macro)
end

-- Every spell macro offers using equipped items before and after the cast.
function smb.offersUseItems(macro)
    return not macro.custom and not macro.equipment
end

local NO_SLOTS = {}
-- the setting holding a macro's slots for each side of the cast
local USE_SETTING = {before = "useItems", after = "useItemsAfter"}

-- The equipment slots a macro uses on a side ("before", the default, or "after") of its cast, in the order
-- the player ticked them. Don't modify it.
function smb.useItemSlots(macro, side)
    if not smb.offersUseItems(macro) then return NO_SLOTS end
    return settings(USE_SETTING[side or "before"])[settingKey(macro)] or NO_SLOTS
end

-- A slot's place in a macro's useItemSlots for a side, or nil when the macro doesn't use it there.
function smb.isUsingSlot(macro, slot, side)
    for i, used in ipairs(smb.useItemSlots(macro, side)) do
        if used == slot then return i end
    end
end

-- Calls fn(name, icon, id) for every learned, castable spell in the spellbook's skill lines first to last
-- (nil for the last one), in skill line order.
local function forEachSpellInLines(first, last, fn)
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for line = first, last or C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide and not info.offSpecID then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive
                            and not item.isOffSpec then
                        fn(item.name, item.iconID, item.spellID or item.actionID)
                    end
                end
            end
        end
    else
        for line = first, last or GetNumSpellTabs() do
            local _, _, offset, numSlots = GetSpellTabInfo(line)
            for slot = offset + 1, offset + numSlots do
                local itemType, id = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
                if itemType == "SPELL" and not IsPassiveSpell(slot, BOOKTYPE_SPELL) then
                    fn(GetSpellBookItemName(slot, BOOKTYPE_SPELL), GetSpellBookItemTexture(slot, BOOKTYPE_SPELL), id)
                end
            end
        end
    end
end

-- The player's racials from smb.racials (Config.lua) that are learned: in the spellbook's General skill
-- line. In config order.
function smb.offeredRacials()
    local wanted = smb.racials[select(2, UnitRace("player"))]
    if not wanted then return NO_SLOTS end
    local learned = {}
    forEachSpellInLines(1, 1, function(name) learned[name] = true end)
    local racials = {}
    for _, name in ipairs(wanted) do
        if learned[name] then racials[#racials + 1] = name end
    end
    return racials
end

-- Whether a cast line spell can go on a side of a macro's cast: a stance before the cast only when the
-- macro's spell can be cast in it (see stancesOf), so Whirlwind offers no Defensive Stance before it.
local function fitsSide(macro, name, side)
    if side ~= "before" or not macro.stances or not smb.isStance(name) then return true end
    return tContains(macro.stances, name)
end

-- The learned offGcd spells (see Config.lua) a macro offers on a side of its cast, or either side when side
-- is nil, in page order: all but its own spell, and before the cast only the stances it can be cast in.
function smb.offeredOffGcd(macro, side)
    local offered = {}
    if not smb.offersUseItems(macro) then return offered end
    local isOffGcd = classConfig().isOffGcdSpell
    for _, other in ipairs(smb.macros) do
        if smb.macroByName[other.name] == other and not other.unlearned and other.name ~= macro.name
            and isOffGcd(other.name) and fitsSide(macro, other.name, side) then
            offered[#offered + 1] = other.name
        end
    end
    return offered
end

-- The spells a macro offers as /cast lines on either side of its cast: the offGcd spells, then its race's
-- learned racials. Both are stored in the racials settings.
local function castLineSpells(macro)
    local spells = {}
    for _, name in ipairs(smb.offeredOffGcd(macro)) do spells[#spells + 1] = name end
    for _, racial in ipairs(smb.offeredRacials()) do spells[#spells + 1] = racial end
    return spells
end

-- the setting holding a macro's racials and offGcd spells for each side of the cast
local RACIAL_SETTING = {before = "racials", after = "racialsAfter"}

-- Whether a macro casts a racial (or an offGcd spell) on a side ("before" or "after") of the cast. Every
-- spell macro offers its race's learned racials and the learned offGcd spells.
function smb.isRacialOn(macro, racial, side)
    local set = settings(RACIAL_SETTING[side])[settingKey(macro)]
    if not (set and set[racial] and smb.offersUseItems(macro) and fitsSide(macro, racial, side)) then return false end
    return tContains(castLineSpells(macro), racial)
end

-- The offGcd spells and racials a macro casts on a side of the cast, offGcd spells first, each in config order.
-- A stance ticked before a spell that can't be cast in it is left out, keeping its setting.
local function racialsOn(macro, side)
    local on = {}
    local set = smb.offersUseItems(macro) and settings(RACIAL_SETTING[side])[settingKey(macro)]
    if not set then return on end
    for _, racial in ipairs(castLineSpells(macro)) do
        if set[racial] and fitsSide(macro, racial, side) then on[#on + 1] = racial end
    end
    return on
end

-- Whether a macro casts any of the given spells on either side of the cast.
local function anyCastLineOn(macro, spells)
    for _, side in ipairs({"before", "after"}) do
        for _, name in ipairs(spells) do
            if smb.isRacialOn(macro, name, side) then return true end
        end
    end
    return false
end

-- Whether a macro casts any racial on either side of the cast.
function smb.hasRacialOn(macro)
    return anyCastLineOn(macro, smb.offeredRacials())
end

-- Whether a macro casts any offGcd spell on either side of the cast.
function smb.hasOffGcdOn(macro)
    return anyCastLineOn(macro, smb.offeredOffGcd(macro))
end

-- The modifier keys a spell macro can cast another spell with, in the order their clauses are tried: with
-- several keys held, the first wins.
smb.MODIFIERS = {"shift", "ctrl", "alt"}

-- Whether a page macro is a focus, enemy player, nearest or combat rank copy of a spell macro.
local function isCopy(macro)
    return macro.focus == true or macro.enemyPlayer == true or macro.nearest == true or macro.combatCopy == true
end

-- Every spell macro but a copy offers a spell for each modifier key.
function smb.offersModifiers(macro)
    return not macro.custom and not macro.equipment and not isCopy(macro)
end

-- The spell a macro casts while a modifier key ("shift", "ctrl" or "alt") is held, or nil, and whether it
-- casts it on the focus target, like that spell's focus copy.
function smb.modifierSpell(macro, mod)
    if not smb.offersModifiers(macro) then return nil, false end
    local spells = settings("modifiers")[settingKey(macro)]
    if not (spells and spells[mod]) then return nil, false end
    return spells[mod], spells[mod .. "Focus"] == true
end

-- The equipment slot a macro uses while a modifier key is held instead of casting a spell, or nil.
function smb.modifierSlot(macro, mod)
    if not smb.offersModifiers(macro) then return nil end
    local spells = settings("modifiers")[settingKey(macro)]
    return spells and spells[mod .. "Slot"]
end

-- Whether a macro has a spell or an equipment slot set for any modifier key.
function smb.hasModifierOn(macro)
    for _, mod in ipairs(smb.MODIFIERS) do
        if smb.modifierSpell(macro, mod) or smb.modifierSlot(macro, mod) then return true end
    end
    return false
end

-- The class config's forms' names, in config order: Druids' Caster, Cat, Bear, Travel and Aquatic.
function smb.formNames()
    local names = {}
    for i, form in ipairs(classConfig().forms) do names[i] = form.name end
    return names
end

-- What the class config's forms are called in the menus: "Stance" for a stance-using class (Warriors),
-- else "Form".
function smb.formNoun()
    return classConfig().hasStances and "Stance" or "Form"
end

-- The section a form's submenu lists first: the form config's section, else the one named after the form.
function smb.formSection(form)
    for _, entry in ipairs(classConfig().forms) do
        if entry.name == form then return entry.section or form end
    end
end

-- Whether a section (a category's name) is listed last in the right-click submenus: menuLast = true.
function smb.menuLast(category)
    for _, section in ipairs(classConfig().categories) do
        if section.name == category then return section.menuLast == true end
    end
    return false
end

-- Every spell macro but a focus copy offers a spell for each of the class config's forms.
function smb.offersForms(macro)
    return smb.offersModifiers(macro) and classConfig().forms[1] ~= nil
end

-- The spell a macro casts while in a form (a form's name from the class config), or nil.
function smb.formSpell(macro, form)
    if not smb.offersForms(macro) then return nil end
    local spells = settings("forms")[settingKey(macro)]
    return spells and spells[form]
end

-- Whether a page macro's spell can be cast in a form (a form's name from the class config): not when it sits
-- in a section named after another form, so Cat offers no Bear spells, Bear no Cat spells, and Caster neither.
-- A spell that needs a stance (Warriors) is only allowed in a form whose spells include one of its stances,
-- so Battle offers no Whirlwind.
function smb.formAllows(form, other)
    if other.category ~= form and tContains(smb.formNames(), other.category) then return false end
    if not other.stances then return true end
    for _, entry in ipairs(classConfig().forms) do
        if entry.name == form then
            for _, spell in ipairs(entry.spells or NO_SLOTS) do
                if tContains(other.stances, spell) then return true end
            end
            return false
        end
    end
    return true
end

-- Whether a macro has a spell set for any form.
function smb.hasFormOn(macro)
    for _, form in ipairs(smb.formNames()) do
        if smb.formSpell(macro, form) then return true end
    end
    return false
end

-- Every sequence starts over after 2 seconds without a press.
local SEQUENCE_RESET = "reset=2 "

-- A spell macro in a sequence section offers a cast sequence, unless it is a cooldown spell (see Config.lua),
-- which offers a follow-up instead (see smb.offersFollowUp), or casts its pet's ability: a summon can't be
-- sequenced. A copy has its own sequence (see settingKey), so e.g. buffing the nearest player can cast
-- different spells from the spell's own macro. A combat rank copy has none: a sequence can't downrank (see castBody).
function smb.offersSequence(macro)
    return macro.sequence and not macro.cooldown and smb.offersUseItems(macro) and not smb.isOptionOn(macro, "pet")
        and not macro.combatCopy
end

-- Whether a macro's sequence can cast another page macro after its own spell: a learned spell in a sequence
-- section.
function smb.canSequence(macro, other)
    if other.unlearned or other.name == macro.name then return false end
    return other.sequence
end

-- A cooldown spell's macro (see Config.lua) offers one follow-up spell, cast on the same press right after
-- its own, unless it casts its pet's ability. A combat rank copy has none, like a sequence.
function smb.offersFollowUp(macro)
    return macro.cooldown and smb.offersUseItems(macro) and not smb.isOptionOn(macro, "pet")
        and not macro.combatCopy
end

-- Whether a cooldown macro can follow up with another page macro's spell: a learned spell in a sequence or
-- cooldownSteps section, or in Unsorted (see Config.lua).
function smb.canFollowUp(macro, other)
    if other.unlearned or other.name == macro.name then return false end
    return other.sequence or other.cooldownStep or other.categoryRank == UNLISTED
end

-- The spell a cooldown macro casts after its own, or nil.
function smb.followUpSpell(macro)
    if not smb.offersFollowUp(macro) then return nil end
    return settings("followUp")[settingKey(macro)]
end

-- The page macro a macro's follow-up casts, or nil when none is picked, or the pick is unlearned or no longer
-- in a section it can be picked from (its setting is kept).
local function followUpMacro(macro)
    local other = smb.macroByName[smb.followUpSpell(macro) or ""]
    if other and smb.canFollowUp(macro, other) then return other end
end

-- Whether a macro casts a follow-up spell.
function smb.hasFollowUpOn(macro)
    return followUpMacro(macro) ~= nil
end

-- The spells a macro casts after its own, in order. Don't modify it.
function smb.sequenceSpells(macro)
    if not smb.offersSequence(macro) then return NO_SLOTS end
    return settings("sequence")[settingKey(macro)] or NO_SLOTS
end

-- A spell's step in a macro's sequence (2 or later: the macro's own spell is step 1), or nil.
function smb.sequencePosition(macro, name)
    for i, picked in ipairs(smb.sequenceSpells(macro)) do
        if picked == name then return i + 1 end
    end
end

-- The steps a macro's /castsequence casts: its own spell, then its learned sequence spells. Nil when no
-- sequence spell is learned, so the macro casts plainly. A pick that is unlearned, or no longer in a section
-- it can be picked from (see smb.canSequence), is left out, keeping its setting.
local function sequenceSteps(macro)
    local steps = {macro.name}
    for _, name in ipairs(smb.sequenceSpells(macro)) do
        local other = smb.macroByName[name]
        if other and smb.canSequence(macro, other) then steps[#steps + 1] = name end
    end
    return steps[2] and steps or nil
end

-- Whether a macro casts a sequence.
function smb.hasSequenceOn(macro)
    return sequenceSteps(macro) ~= nil
end

-- Whether a macro has an options menu: every spell macro does, for stopCast, startAttack, autoShot or petFollow, and every
-- equipment macro, for equipStopAttack and equipStopCast.
function smb.hasOptions(macro)
    return smb.hasCastOptions(macro) or smb.offersStopCast(macro) or smb.offersStartAttack(macro)
        or smb.offersAutoShot(macro)
        or smb.offersUseItems(macro) or macro.equipment == true
end

-- The spam option's value for a toggle spell: instead of a condition, the spell is cast as "!<spell>",
-- which starts it but never toggles it off.
local NO_TOGGLE = "!"

-- The name a spell macro's /cast uses: "!<spell>" for a toggle spell with its spam option on.
function smb.castName(macro)
    if macro.spam == NO_TOGGLE and smb.isOptionOn(macro, "spam") then return NO_TOGGLE .. macro.name end
    return macro.name
end

-- A macro conditional joining the given conditions (nil or "" ones are skipped) behind the always-present
-- spam condition (nil or ""), e.g. "[nochanneling:Drain Life,@mouseover,harm,nodead]". Returns "" when
-- there is nothing to check, so a plain cast stays "/cast Name".
local function cond(spam, ...)
    local parts = {}
    if spam and spam ~= "" then parts[1] = spam end
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c and c ~= "" then parts[#parts + 1] = c end
    end
    return #parts > 0 and "[" .. table.concat(parts, ",") .. "]" or ""
end

-- A /cast of name that tries each target conditional in turn ("" for none), with a rank 1 cast under when
-- (e.g. "group:raid") before each one. prefix ("" for none) goes before the clauses: the modifier clauses.
local function rank1Cast(name, targets, spam, prefix, when)
    local clauses = {}
    for _, target in ipairs(targets) do
        clauses[#clauses + 1] = cond(spam, target, when) .. " " .. name .. "(Rank 1)"
        local plain = cond(spam, target)
        clauses[#clauses + 1] = (plain ~= "" and plain .. " " or "") .. name
    end
    return "/cast " .. prefix .. table.concat(clauses, "; ")
end

-- The page's spell macros by spell name (not focus copies, custom or equipment macros), for the modifier
-- clauses. Rebuilt with smb.macros.
smb.macroByName = {}

-- Every page macro by its WoW macro name, for finding the one on an action button (see ActionBars.lua).
-- Rebuilt with smb.macros.
smb.macroByMacroName = {}

-- A clause casting another page macro's spell under a condition (e.g. "mod:shift"), followed by "; ", the
-- way that spell's own page macro targets: at the mouseover or the cursor when that option is on there. With
-- noToggle, a toggle spell, such as an aspect, is always cast as "!<spell>", whatever its own page macro's
-- spam option. With no condition (nil), the clause has none of its own, e.g. "[@cursor] Blizzard; ", or
-- "Fireball; " for a plain cast.
local function targetedClause(condition, other, noToggle)
    local name = noToggle and other.spam == NO_TOGGLE and NO_TOGGLE .. other.name or smb.castName(other)
    local conditional = condition and "[" .. condition .. "]" or ""
    local castOn = smb.castOn(other)
    if castOn == "cursor" then
        conditional = cond(nil, condition, "@cursor")
    elseif castOn == "mouseover" then
        conditional = cond(nil, condition, "@mouseover," .. other.target .. ",nodead") .. "[" .. (condition or "") .. "]"
    end
    return (conditional ~= "" and conditional .. " " or "") .. name .. "; "
end

-- The line casting a cooldown macro's follow-up spell (see smb.offersFollowUp), starting with a newline, the
-- way that spell's own page macro targets, like a modifier spell; "" when it has none.
local function followUpLine(macro)
    local other = followUpMacro(macro)
    if not other then return "" end
    return "\n/cast " .. targetedClause(nil, other, true):sub(1, -3)
end

-- The clauses that cast a macro's modifier spells, each followed by "; ", ready to go before its own, e.g.
-- "[mod:shift] Fear; [mod:alt,@mouseover,help,nodead][mod:alt] Flash Heal; ", or "". Each spell is cast the
-- way its own page macro targets: at the mouseover or the cursor when that option is on there. A toggle
-- spell, such as an aspect, is always cast as "!<spell>", so holding the key and pressing again never
-- toggles it off. A focus pick casts like the spell's focus copy, on the focus target or else the target,
-- but without switching target back after. A spell that isn't learned is left out, keeping its setting. So is a focus pick whose
-- spell has no focus copy, which only old saved data can hold: removing the copy clears its picks. An
-- equipment pick uses whatever is in its slot, e.g. "[mod:ctrl] 13; ", like the useItems lines.
local function modifierClauses(macro)
    local clauses = {}
    for _, mod in ipairs(smb.MODIFIERS) do
        local name, onFocus = smb.modifierSpell(macro, mod)
        local other = smb.macroByName[name or ""]
        local slot = smb.modifierSlot(macro, mod)
        if slot then
            clauses[#clauses + 1] = "[mod:" .. mod .. "] " .. slot .. "; "
        elseif other and not other.unlearned and (not onFocus or smb.isOptionOn(other, "focus")) then
            if onFocus then
                local held = "[mod:" .. mod
                clauses[#clauses + 1] = held .. ",@focus," .. other.target .. ",nodead]" .. held .. "] "
                    .. other.name .. "; "
            else
                clauses[#clauses + 1] = targetedClause("mod:" .. mod, other, true)
            end
        end
    end
    return table.concat(clauses)
end

-- A focus copy switches back to the previous target after the cast. The slash command, not
-- /script TargetLastTarget(): the function is protected, so a /script call is blocked as tainted.
local FOCUS_FOOTER = "\n/targetlasttarget"

-- A nearest copy first targets the nearest friendly player. Clearing the target first keeps the cast off an NPC (or any unit already targeted) when no friendly
-- player is near: with no target, the cast falls back to you.
local NEAREST_LINE = "/cleartarget\n/targetfriendplayer\n"

-- An enemy player copy first targets the nearest enemy player. Clearing the target first keeps the cast
-- off an NPC (or any unit already targeted) when no enemy player is near: with no target, nothing is cast.
-- It then switches back like a focus copy (FOCUS_FOOTER).
local ENEMY_LINE = "/cleartarget\n/targetenemyplayer\n"

-- The body macroBody gives a spell macro with no options on, which does just what the plain spell does.
local function bareBody(name)
    return "#showtooltip\n/cast " .. name
end

-- The slot a Warrior stance always takes on the stance bar, for one not learned yet: they are learned in
-- this order.
local WARRIOR_STANCE_SLOTS = { ["Battle Stance"] = 1, ["Defensive Stance"] = 2, ["Berserker Stance"] = 3 }

-- A stance's slot on the stance bar (the n of [stance:n]), or nil when unknown.
local function stanceSlot(stance)
    for i = 1, GetNumShapeshiftForms() do
        local spellID = select(4, GetShapeshiftFormInfo(i))
        if spellID and C_Spell.GetSpellName(spellID) == stance then return i end
    end
    return WARRIOR_STANCE_SLOTS[stance]
end

-- Whether a spell is one of a stance-using class's (Warriors') stances.
function smb.isStance(name)
    return classConfig().hasStances and stanceSlot(name) ~= nil
end

-- A form's macro condition: "noform" for one with no spells (caster form), else "form:n" for the slot of its
-- first learned spell, or nil when none is learned.
local function formCondition(form)
    if not form.spells then return "noform" end
    for _, spell in ipairs(form.spells) do
        for i = 1, GetNumShapeshiftForms() do
            local spellID = select(4, GetShapeshiftFormInfo(i))
            if spellID and C_Spell.GetSpellName(spellID) == spell then return "form:" .. i end
        end
    end
end

-- The form picks a macro casts, as {condition, page macro}, in config order. A pick that isn't learned, whose
-- form isn't, or that the form doesn't allow (see smb.formAllows), is left out, keeping its setting.
local function formPicks(macro)
    local picks = {}
    if not smb.offersForms(macro) then return picks end
    for _, form in ipairs(classConfig().forms) do
        local other = smb.macroByName[smb.formSpell(macro, form.name) or ""]
        local condition = other and not other.unlearned and smb.formAllows(form.name, other) and formCondition(form)
        if condition then picks[#picks + 1] = {condition, other} end
    end
    return picks
end

-- The clauses that cast a macro's form spells, each followed by "; ", ready to go after its modifier
-- clauses, e.g. "[form:3] Shred; [form:1,@mouseover,harm,nodead][form:1] Faerie Fire (Feral); ", or "". Each
-- spell is cast the way its own page macro targets, like a modifier spell.
local function formClauses(macro)
    local clauses = {}
    for _, pick in ipairs(formPicks(macro)) do clauses[#clauses + 1] = targetedClause(pick[1], pick[2]) end
    return table.concat(clauses)
end

-- The stances a stance-using class can be in: the Warrior stances and whatever is on the stance bar.
local function knownStances()
    local names = {}
    for name in pairs(WARRIOR_STANCE_SLOTS) do names[#names + 1] = name end
    for i = 1, GetNumShapeshiftForms() do
        local spellID = select(4, GetShapeshiftFormInfo(i))
        local name = spellID and C_Spell.GetSpellName(spellID)
        if name and not WARRIOR_STANCE_SLOTS[name] then names[#names + 1] = name end
    end
    return names
end

local scanTooltip -- hidden tooltip for clients without C_TooltipInfo

-- The text of a tooltip's lines, left and right. infoGetter is the C_TooltipInfo function and setter the
-- GameTooltip method that fill it (e.g. "GetSpellByID" and "SetSpellByID"), both called with the rest.
local function scanLines(infoGetter, setter, ...)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo[infoGetter] then
        local data = C_TooltipInfo[infoGetter](...)
        for _, line in ipairs(data and data.lines or {}) do
            lines[#lines + 1] = line.leftText
            lines[#lines + 1] = line.rightText
        end
        return lines
    end
    local name = addonName .. "ScanTooltip"
    scanTooltip = scanTooltip or CreateFrame("GameTooltip", name, nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip[setter](scanTooltip, ...)
    for i = 1, scanTooltip:NumLines() do
        for _, side in ipairs({"Left", "Right"}) do
            local text = _G[name .. "Text" .. side .. i]
            lines[#lines + 1] = text and text:GetText()
        end
    end
    scanTooltip:Hide()
    return lines
end

-- The text of a spell's tooltip lines, left and right.
local function tooltipLines(id)
    return scanLines("GetSpellByID", "SetSpellByID", id)
end

-- The stances a spell's tooltip says it requires ("Requires Battle Stance, Defensive Stance"), in the
-- tooltip's order, or nil when it names none or isn't loaded.
local function tooltipStances(id)
    for _, text in ipairs(tooltipLines(id)) do
        if type(text) == "string" and text:find("Requires", 1, true) then
            local found = {}
            for _, stance in ipairs(knownStances()) do
                local at = text:find(stance, 1, true)
                if at then found[#found + 1] = {stance = stance, at = at} end
            end
            if #found > 0 then
                table.sort(found, function(a, b) return a.at < b.at end)
                local stances = {}
                for i, f in ipairs(found) do stances[i] = f.stance end
                return stances
            end
        end
    end
end

-- The stances a spell can be cast in, or nil for a spell that needs none, so the stance picks only offer it
-- in one of them (see smb.formAllows). The tooltip says which stances, so the list matches this client's
-- rules; the class config's list fills in when the tooltip names none.
local function stancesOf(name, id)
    local c = classConfig()
    if not c.hasStances then return nil end
    local configured = c.stances[name]
    local allowed = id and tooltipStances(id)
    if not allowed then return configured end
    local target = allowed[1]
    for _, stance in ipairs(configured or {}) do
        if tContains(allowed, stance) then
            target = stance
            break
        end
    end
    local stances = {target}
    for _, stance in ipairs(allowed) do
        if stance ~= target then stances[#stances + 1] = stance end
    end
    return stances
end

-- A macro's "/stopcasting", "/startattack", "/stopattack", "/cast !Auto Shot", "/petfollow", "/petattack",
-- "/cancelaura Ice Block", "/cleartarget [dead]" or "/targetenemy [noharm][dead]" line on a side of the cast, with the
-- spam condition on /stopcasting, or nil when it is off on that side. The "!" keeps a press while Auto Shot
-- is already repeating from toggling it off, so the macro can be spammed.
local function placedLine(macro, key, side, spam)
    if not smb.isLineOn(macro, key, side) then return nil end
    if key == "startAttack" then return "/startattack" end
    if key == "stopAttack" then return "/stopattack" end
    if key == "autoShot" then return "/cast " .. NO_TOGGLE .. "Auto Shot" end
    if key == "petFollow" then return "/petfollow" end
    if key == "petAttack" then return "/petattack" end
    if key == "cancelIceBlock" then return "/cancelaura Ice Block" end
    if key == "clearDead" then return "/cleartarget [dead]" end
    if key == "targetEnemy" then return "/targetenemy [noharm][dead]" end
    return "/stopcasting" .. (spam and " [" .. spam .. "]" or "")
end

-- the setting holding the order a macro's lines were ticked in for each side of the cast
local ORDER_SETTING = {before = "order", after = "orderAfter"}

-- The lines a macro has on a side of the cast, as {id, text}, in the order the player ticked them. Lines
-- the order list doesn't name (on by a default, or ticked before it existed) come first: clearDead and
-- targetEnemy, then stopCast and cancelIceBlock, then the rest in menu order (autoShot, startAttack, stopAttack,
-- petAttack, petFollow), racials, then slots.
local function sideEntries(macro, side, spam)
    local entries = {}
    for _, key in ipairs({"clearDead", "targetEnemy", "stopCast", "cancelIceBlock", "autoShot", "startAttack", "stopAttack", "petAttack", "petFollow"}) do
        local line = placedLine(macro, key, side, spam)
        if line then entries[#entries + 1] = {key, line} end
    end
    for _, racial in ipairs(racialsOn(macro, side)) do
        -- a stance (an offGcd spell for Warriors) isn't cast while already in it
        local slot = smb.isStance(racial) and stanceSlot(racial)
        entries[#entries + 1] = {racial, "/cast " .. (slot and "[nostance:" .. slot .. "] " or "") .. racial}
    end
    for _, slot in ipairs(smb.useItemSlots(macro, side)) do entries[#entries + 1] = {slot, "/use " .. slot} end
    local rank = {}
    for i, id in ipairs(settings(ORDER_SETTING[side])[settingKey(macro)] or NO_SLOTS) do rank[id] = i end
    -- table.sort isn't stable, so ties keep menu order through each entry's index
    for i, entry in ipairs(entries) do entry.rank, entry.index = rank[entry[1]] or 0, i end
    table.sort(entries, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.index < b.index
    end)
    return entries
end

-- A line's place among a macro's lines on a side of the cast, or nil when it is off there. id is "stopCast",
-- "startAttack", "stopAttack", "autoShot", "petFollow", "petAttack", "cancelIceBlock", "clearDead", "targetEnemy", a
-- racial's name or a slot number.
function smb.sidePosition(macro, id, side)
    for i, entry in ipairs(sideEntries(macro, side)) do
        if entry[1] == id then return i end
    end
end

-- Moves a line to the end of a macro's tick order for a side when it is turned on, or drops it when off.
local function noteTick(macro, side, id, on)
    local set = settings(ORDER_SETTING[side])
    local order = {}
    for _, ticked in ipairs(set[settingKey(macro)] or NO_SLOTS) do
        if ticked ~= id then order[#order + 1] = ticked end
    end
    if on then order[#order + 1] = id end
    set[settingKey(macro)] = #order > 0 and order or nil
end

local function castBody(macro)
    -- the spam option adds [nochanneling:<spell>] (or [nostealth], or [noform:n]) to every cast clause, so a
    -- press while the spell is channelling (or stealth or the form is on) can't restart (or cancel) it; the before-cast lines come
    -- first, in the order the player ticked them (see sideEntries): the stopCast option stops the current
    -- cast (but, with spam on, not this spell's own channel), the startAttack option starts auto-attack,
    -- the petAttack option sends the pet at the current target, racials are cast and useItems slots used.
    -- With racials, items or /startattack first, #showtooltip names the spell so the button doesn't show the
    -- item. It names the spell with spam on too, unless modifier or form clauses pick the icon: while
    -- stealthed (or channelling, or in the form) no clause matches, and a bare #showtooltip would show a question mark
    local spam = smb.isOptionOn(macro, "spam") and macro.spam or nil
    -- a toggle spell's spam option renames the cast (see smb.castName) rather than adding a condition
    local name = smb.castName(macro)
    local noToggle = spam == NO_TOGGLE
    if noToggle then spam = nil end
    -- the modifier spells' clauses go first, so a held key wins over the form spells, and those over the
    -- macro's own
    local mods = modifierClauses(macro) .. formClauses(macro)
    local namesSpell = noToggle or (spam ~= nil and mods == "")
    local before = {}
    for _, entry in ipairs(sideEntries(macro, "before", spam)) do
        before[#before + 1] = entry[2] .. "\n"
        -- /stopcasting, /stopattack, /petattack, /cancelaura, /cleartarget and /targetenemy don't change the button's icon
        if entry[1] ~= "stopCast" and entry[1] ~= "stopAttack" and entry[1] ~= "petAttack"
            and entry[1] ~= "cancelIceBlock" and entry[1] ~= "clearDead" and entry[1] ~= "targetEnemy" then
            namesSpell = true
        end
    end
    local header = "#showtooltip" .. (namesSpell and " " .. macro.name or "") .. "\n" .. table.concat(before)
    -- with a sequence, every step is cast like the macro's own spell
    local steps = sequenceSteps(macro)
    if steps then steps[1] = name end
    -- "/cast <conditional> name", or "/cast name" when there is no conditional; with a sequence,
    -- "/castsequence <conditional> reset=2 name, step 2, ..."
    local function cast(conditional)
        local prefix = (conditional ~= "" and conditional .. " " or "")
        if steps then
            return "/castsequence " .. mods .. prefix .. SEQUENCE_RESET .. table.concat(steps, ", ")
        end
        return "/cast " .. mods .. prefix .. name
    end
    local castOn = smb.castOn(macro)
    -- a combat rank copy casts rank 1 out of combat and the highest rank in it, targeted like a spell's own
    -- macro; it offers no sequence, raid downrank or modifiers
    if macro.combatCopy then
        local targets = {""}
        if castOn == "cursor" then
            targets = {"@cursor"}
        elseif castOn == "mouseover" then
            targets = {"@mouseover," .. macro.target .. ",nodead", ""}
        end
        return header .. rank1Cast(name, targets, spam, "", "nocombat")
    end
    -- a sequence can't downrank: a rank 1 clause per target would repeat every step
    if smb.isOptionOn(macro, "raidRank1") and not steps then
        local targets = {""}
        if macro.nearest then
            targets = {"help,nodead", "@player"}
        elseif macro.enemyPlayer then
            targets = {"harm,nodead"}
        elseif macro.focus then
            targets = {"@focus," .. macro.target .. ",nodead", ""}
        elseif castOn == "mouseover" then
            targets = {"@mouseover," .. macro.target .. ",nodead", ""}
        end
        return header .. (macro.nearest and NEAREST_LINE or "") .. (macro.enemyPlayer and ENEMY_LINE or "")
            .. rank1Cast(name, targets, spam, mods, "group:raid") .. ((macro.focus or macro.enemyPlayer) and FOCUS_FOOTER or "")
    end
    -- a nearest copy casts on the player it just targeted, or on you when no friendly player is near
    if macro.nearest then
        return header .. NEAREST_LINE .. cast(cond(spam, "help,nodead") .. cond(spam, "@player"))
    end
    -- an enemy player copy casts on the enemy player it just targeted, then switches back
    if macro.enemyPlayer then
        return header .. ENEMY_LINE .. cast(cond(spam, "harm,nodead")) .. FOCUS_FOOTER
    end
    if macro.focus then
        return header .. cast(cond(spam, "@focus," .. macro.target .. ",nodead") .. "[" .. (spam or "") .. "]")
            .. FOCUS_FOOTER
    end
    if smb.isOptionOn(macro, "pet") then
        -- [pet:X] matches the pet's creature family, so another demon being out still summons this one
        local family = macro.name:match("^Summon (.+)$") or macro.name
        return header .. "/cast " .. mods .. cond(spam, "pet:" .. family) .. " " .. macro.petAbility .. "; "
            .. (spam and cond(spam) .. " " or "") .. name
    end
    if castOn == "cursor" then
        return header .. cast(cond(spam, "@cursor"))
    end
    if castOn == "mouseover" then
        return header .. cast(cond(spam, "@mouseover," .. macro.target .. ",nodead") .. "[" .. (spam or "") .. "]")
    end
    return header .. cast(cond(spam))
end

-- An equipment macro uses its slot, after /stopattack and /stopcasting when those options are on. A bare
-- #showtooltip skips them and shows the item.
local function equipmentBody(macro)
    return "#showtooltip\n" .. (smb.isOptionOn(macro, "equipStopAttack") and "/stopattack\n" or "")
        .. (smb.isOptionOn(macro, "equipStopCast") and "/stopcasting\n" or "") .. "/use " .. macro.slot
end

-- A cooldown macro's follow-up cast comes right after its own, then the after-cast lines (racials,
-- useItemsAfter slots and the lines placed after the cast), in the order the player ticked them, end the macro.
-- #showtooltip still shows the spell: its /cast comes first.
local function macroBody(macro)
    if macro.equipment then return equipmentBody(macro) end
    local body = castBody(macro) .. followUpLine(macro)
    for _, entry in ipairs(sideEntries(macro, "after")) do body = body .. "\n" .. entry[2] end
    return body
end

-- Sets a page macro's body, and tooLong when it is over WoW's limit: such a macro is never created or
-- rewritten (see smb.pickupMacro and syncMacro).
local function setBody(macro)
    macro.body = macroBody(macro)
    macro.tooLong = #macro.body > MAX_MACRO_BODY
end

-- One macro per learned class spell (and unlearned one, when shown) plus the class config's custom macros,
-- in page order. Rebuilt each time the page opens.
smb.macros = {}

-- The condition a spell's spam option adds to its casts, or nil for spells without one. Stealth toggles
-- off when cast again, so a stealth spell casts only while not stealthed. For a class with forms (Druids),
-- a shapeshift spell on the stance bar casts only while not in that form, since casting it again shifts
-- back out. A Warrior stance gets none: casting it again does nothing. A toggle spell, such as Auto Shot or
-- an aspect, gets NO_TOGGLE: it toggles off when cast again.
local function spamCondition(name)
    local c = classConfig()
    if c.isToggleSpell(name) then return NO_TOGGLE end
    if c.isStealthSpell(name) then return "nostealth" end
    if c.isChanneledSpell(name) then return "nochanneling:" .. name end
    local slot = c.forms[1] and not c.hasStances and stanceSlot(name)
    if slot then return "noform:" .. slot end
end

local function makeMacro(name, icon, unlearned, id)
    local categoryRank, category, priority = categoryOf(name)
    local macro = {
        name = name,
        unlearned = unlearned,
        categoryRank = categoryRank,
        priority = priority,
        category = category,
        noGlow = categoryRank ~= UNLISTED and classConfig().categories[categoryRank].noGlow == true,
        sequence = categoryRank ~= UNLISTED and classConfig().categories[categoryRank].sequence == true,
        cooldownStep = categoryRank ~= UNLISTED and classConfig().categories[categoryRank].cooldownSteps == true,
        cooldown = classConfig().isCooldownSpell(name) ~= nil,
        target = targetOf(name, id),
        cursor = classConfig().isCursorSpell(name) ~= nil,
        petAbility = classConfig().petAbilities[name],
        raidRank1 = classConfig().isRaidRank1Spell(name) ~= nil,
        combatRank1 = classConfig().isCombatRank1Spell(name) ~= nil,
        buff = classConfig().isBuffSpell(name) ~= nil,
        dispel = classConfig().isDispelSpell(name) ~= nil,
        spam = spamCondition(name),
        stealth = classConfig().isStealthSpell(name) ~= nil,
        stances = stancesOf(name, id),
        spellID = id,
        -- the question mark icon lets #showtooltip show the spell's own icon on the action bar
        macroName = name:sub(1, MAX_MACRO_NAME),
        macroIcon = ICON_QUESTION_MARK,
        icon = icon or ICON_QUESTION_MARK,
    }
    return macro -- smb.collectMacros sets the body once every macro exists
end

-- The suffix ending a copy's WoW macro name, or "" for a spell's own macro. A per-button copy adds " #<n>".
local function copySuffix(macro)
    local suffix = ""
    if macro.focus then
        suffix = FOCUS_SUFFIX
    elseif macro.enemyPlayer then
        suffix = ENEMY_SUFFIX
    elseif macro.nearest then
        suffix = NEAREST_SUFFIX
    elseif macro.combatCopy then
        suffix = COMBAT_RANK_SUFFIX
    end
    if macro.buttonCopy then suffix = suffix .. " #" .. macro.buttonCopy end
    return suffix
end

-- A spell name cut to limit characters but keeping its last word, e.g. "Greater B Wisdom" for "Greater
-- Blessing of Wisdom", or nil when the last word leaves no room for the rest.
local function keepLastWord(name, limit)
    local last = name:match("(%S+)$")
    if not last or #last + 2 > limit then return nil end
    return name:sub(1, limit - #last - 1):gsub("%s+$", "") .. " " .. last
end

-- A spell macro's WoW macro name: its spell's name cut to fit, plus its copy's suffix. With keepLast, the cut
-- keeps the spell's last word (see resolveNameClashes).
local function spellMacroName(macro, keepLast)
    local suffix = copySuffix(macro)
    local limit = MAX_MACRO_NAME - #suffix
    local base = #macro.name > limit and keepLast and keepLastWord(macro.name, limit) or macro.name:sub(1, limit)
    return base .. suffix
end

-- A copy of a spell macro that casts on the focus target, falling back to the current target. Its menu
-- has its own options (see settingKey); unticking its focus option removes it.
local function makeFocusMacro(macro)
    local copy = {}
    for key, value in pairs(macro) do copy[key] = value end
    copy.focus = true
    copy.cursor = false
    copy.petAbility = nil
    copy.macroName = spellMacroName(copy)
    return copy
end

-- A copy of a dispels spell macro that targets the nearest enemy player, casts on them, then switches back to
-- the previous target. Like a focus copy, it has its own options; unticking enemyPlayer removes it.
local function makeEnemyPlayerMacro(macro)
    local copy = {}
    for key, value in pairs(macro) do copy[key] = value end
    copy.enemyPlayer = true
    copy.cursor = false
    copy.petAbility = nil
    copy.macroName = spellMacroName(copy)
    return copy
end

-- A copy of a buffs spell macro that targets the nearest friendly player, casts on them (or on you when no
-- friendly player is near), leaving them targeted. Like a focus copy, it has its own options; unticking nearest
-- removes it.
local function makeNearestMacro(macro)
    local copy = {}
    for key, value in pairs(macro) do copy[key] = value end
    copy.nearest = true
    copy.cursor = false
    copy.petAbility = nil
    copy.macroName = spellMacroName(copy)
    return copy
end

-- A copy of a combatRank1 spell macro that casts rank 1 out of combat and the highest rank in combat. Unlike
-- the other copies it keeps its spell's targeting options (mouseover, cursor), set on the copy itself. Like a
-- focus copy, it has its own options; unticking combatRank1 removes it.
local function makeCombatRankMacro(macro)
    local copy = {}
    for key, value in pairs(macro) do copy[key] = value end
    copy.combatCopy = true
    copy.raidRank1 = false
    copy.petAbility = nil
    copy.macroName = spellMacroName(copy)
    return copy
end

-- A per-button copy of a page macro (see smb.newButtonCopy): the same macro under its own WoW macro name and
-- its own settings, so one action button can differ from the others holding that macro. A per-button copy of a
-- per-button copy is numbered among the copies of the macro they both came from.
local function makeButtonCopy(macro, n)
    local copy = {}
    for key, value in pairs(macro) do copy[key] = value end
    copy.buttonBase = macro.buttonBase or settingKey(macro)
    copy.buttonCopy = n
    copy.macroName = spellMacroName(copy)
    return copy
end

local getSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture

-- The spell named by a leading "#showtooltip <spell>" line, or nil.
local function showtooltipSpell(body)
    return body:match("^#showtooltip[ \t]+([^\n]*%S)")
end

-- The icon of the spell named by a leading "#showtooltip <spell>" line, or nil.
local function showtooltipIcon(body)
    local spell = showtooltipSpell(body)
    if spell and getSpellTexture then return getSpellTexture(spell) end
end

-- The icon as CreateMacro takes it: a file ID, or a bare texture name in Interface\Icons. A full texture
-- path (as the config allows) is reduced to its file name.
local function macroIconName(icon)
    if type(icon) ~= "string" then return icon end
    return icon:match("[^\\/]+$")
end

-- A config custom entry as a page macro. Its body is used as written, and it has no options menu.
local function makeCustomMacro(entry, index, categoryRank)
    return {
        name = entry.name,
        categoryRank = categoryRank,
        priority = index,
        category = entry.category or "Custom",
        custom = true,
        first = entry.first and true or nil,
        description = type(entry.description) == "string" and entry.description or nil,
        cursor = false,
        macroName = entry.name:sub(1, MAX_MACRO_NAME),
        macroIcon = macroIconName(entry.icon) or ICON_QUESTION_MARK,
        icon = entry.icon or showtooltipIcon(entry.body) or ICON_QUESTION_MARK,
        tooltipSpell = showtooltipSpell(entry.body),
        body = entry.body,
    }
end

local warned = {}

-- Prints a config problem once per session.
local function warn(message)
    if warned[message] then return end
    warned[message] = true
    print(addonName .. ": " .. message)
end

-- Appends the valid custom entries to smb.macros. taken holds the macro names already in use.
local function addCustomMacros(taken)
    local c = classConfig()
    local categoryRanks = {}
    for i, entry in ipairs(c.custom) do
        local name, body = type(entry) == "table" and entry.name, type(entry) == "table" and entry.body
        if type(name) ~= "string" or name == "" or type(body) ~= "string" or body == "" then
            warn("custom macro #" .. i .. " in your class config needs a name and a body.")
        elseif #body > MAX_MACRO_BODY then
            warn("custom macro \"" .. name .. "\" is " .. #body .. " characters; macros allow " .. MAX_MACRO_BODY .. ".")
        elseif taken[name:sub(1, MAX_MACRO_NAME)] then
            warn("custom macro \"" .. name .. "\" has the same name (first " .. MAX_MACRO_NAME
                .. " characters) as another macro on the page.")
        else
            taken[name:sub(1, MAX_MACRO_NAME)] = true
            local category = entry.category or "Custom"
            -- a config category keeps its place; others follow them in order of first use
            categoryRanks[category] = categoryRanks[category] or c.categoryRankByName[category] or #c.categories + i
            smb.macros[#smb.macros + 1] = makeCustomMacro(entry, i, categoryRanks[category])
        end
    end
end

local getItemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell

-- The names equipment macros show and take, by inventory slot.
local SLOT_LABELS = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs",
    [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1",
    [14] = "Trinket 2", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged", [19] = "Tabard",
}

-- Whether the item in an equipment slot has a "Use:" effect. The tooltip check catches effects added to the
-- item, such as engineering tinkers, which GetItemSpell on the item itself may not see.
local function hasUseEffect(slot, link)
    if getItemSpell and getItemSpell(link) then return true end
    local prefix = ITEM_SPELL_TRIGGER_ONUSE or "Use:"
    for _, text in ipairs(scanLines("GetInventoryItem", "SetInventoryItem", "player", slot)) do
        if type(text) == "string" and text:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- A macro that uses whatever is in an equipment slot, so it keeps working when the item is swapped. Its menu
-- offers only equipStopAttack and equipStopCast.
local function makeEquipmentMacro(slot, link, categoryRank)
    local label = SLOT_LABELS[slot]
    local macro = {
        name = link:match("%[(.-)%]") or label,
        equipment = true,
        slot = slot,
        slotLabel = label,
        categoryRank = categoryRank,
        priority = slot,
        category = "Equipment",
        cursor = false,
        macroName = ("Use " .. label):sub(1, MAX_MACRO_NAME),
        macroIcon = ICON_QUESTION_MARK,
        icon = GetInventoryItemTexture("player", slot) or ICON_QUESTION_MARK,
    }
    return macro
end

-- The equipped items with a "Use:" effect, in slot order, as {slot = 13, link = ...}.
function smb.usableSlots()
    local usable = {}
    for slot = 1, #SLOT_LABELS do
        local link = GetInventoryItemLink("player", slot)
        if link and hasUseEffect(slot, link) then
            usable[#usable + 1] = {slot = slot, link = link}
        end
    end
    return usable
end

-- The name a slot shows in menus: its label, plus the equipped item's name when there is one.
function smb.slotLabel(slot)
    local link = GetInventoryItemLink("player", slot)
    local item = link and link:match("%[(.-)%]")
    return SLOT_LABELS[slot] .. (item and ": " .. item or "")
end

-- Appends a macro for each equipped item with a "Use:" effect to smb.macros. taken holds the macro names
-- already in use. The section follows the custom macros unless the class config places an "Equipment"
-- category.
local function addEquipmentMacros(taken)
    local c = classConfig()
    local categoryRank = c.categoryRankByName.Equipment or #c.categories + #c.custom + 1
    for _, usable in ipairs(smb.usableSlots()) do
        local macro = makeEquipmentMacro(usable.slot, usable.link, categoryRank)
        if not taken[macro.macroName] then
            taken[macro.macroName] = true
            smb.macros[#smb.macros + 1] = macro
        end
    end
end

-- Calls fn(name, icon, id) for every learned, castable spell outside the General skill line, in skill line
-- order.
local function forEachClassSpell(fn)
    forEachSpellInLines(2, nil, fn)
end

local isSpellPassive = C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell

local requested = {} -- spell ids asked for once, so an id that never loads can't keep the page redrawing

-- A spell's name, or nil while its data isn't loaded (it is then requested).
local function spellName(id)
    local name = C_Spell.GetSpellName(id)
    if not name and not requested[id] then
        requested[id] = true
        C_Spell.RequestLoadSpellData(id)
    end
    return name
end

-- The rank in a spell's subtext ("Rank 2"), or nil for a spell without ranks.
local function rankOf(id)
    local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    return subtext and tonumber(subtext:match("%d+"))
end

-- Whether a spell isn't rank 1: its subtext says a higher rank, or it requires its own previous rank. Nil
-- while a required spell's name isn't loaded.
local function isHigherRank(spell, name)
    if (rankOf(spell.id) or 1) > 1 then return true end
    for _, id in ipairs(spell.requires or {}) do
        local required = spellName(id)
        if not required then return nil end
        if required == name then return true end
    end
    return false
end

-- Calls fn(name, icon, id) for the rank 1 of every class trainer spell whose name isn't in learned: the
-- bundled ones (Data/) by level, then the ones this character's trainers offered (Trainer.lua), then the
-- class config's extraSpells. Data/ includes the rank 1 of each talent that has trainer ranks, so those
-- talents show until learned; talents without trainer ranks need an extraSpells entry.
-- Spells whose data isn't loaded yet are skipped: SpellBookTab.lua refreshes on SPELL_DATA_LOAD_RESULT.
local function forEachUnlearnedSpell(fn, learned)
    local faction, race = UnitFactionGroup("player"), select(3, UnitRace("player"))
    local seen = {}
    local spells = {}
    for _, list in ipairs({smb.trainerSpells[select(2, UnitClass("player"))] or {}, smb.recordedTrainerSpells()}) do
        for _, spell in ipairs(list) do spells[#spells + 1] = spell end
    end
    for _, id in ipairs(classConfig().extraSpells) do spells[#spells + 1] = {id = id} end
    for _, spell in ipairs(spells) do
        if (not spell.faction or spell.faction == faction) and (not spell.race or spell.race == race) then
            local name = spellName(spell.id)
            if name and not seen[name] then
                local higherRank = isHigherRank(spell, name)
                if higherRank == false then
                    seen[name] = true -- the lowest level entry is rank 1
                    if not learned[name] and not isSpellPassive(spell.id) then
                        fn(name, C_Spell.GetSpellTexture(spell.id), spell.id)
                    end
                end
            end
        end
    end
end

-- A page macro's place among its spell's entries: the spell, then its focus copy, then its enemy player copy,
-- then its nearest copy, then its combat rank copy, each followed by its per-button copies in number order.
local function copyRank(macro)
    local rank = 0
    if macro.combatCopy then
        rank = 4
    elseif macro.nearest then
        rank = 3
    elseif macro.enemyPlayer then
        rank = 2
    elseif macro.focus then
        rank = 1
    end
    return rank * 1000 + (macro.buttonCopy or 0)
end

-- A spell macro's name ending in a number instead of its last characters (before its copy's suffix), for a
-- clash keepLastWord can't settle.
local function numberedMacroName(macro, n)
    local suffix = copySuffix(macro)
    local base = spellMacroName(macro, true):sub(1, MAX_MACRO_NAME - #suffix)
    return base:sub(1, MAX_MACRO_NAME - #suffix - #tostring(n)) .. n .. suffix
end

-- Gives spell macros whose names cut to the same WoW macro name (e.g. every "Greater Blessing of *") names
-- of their own, so they don't share one WoW macro. Names that don't clash are left as they are, so the macros
-- already on the action bars keep theirs. A clashing name keeps its spell's last word ("Greater Bl Might"),
-- and failing that ends in a number.
local function resolveNameClashes(macros)
    local count = {}
    for _, macro in ipairs(macros) do count[macro.macroName] = (count[macro.macroName] or 0) + 1 end
    local renamed = {}
    for i, macro in ipairs(macros) do
        if count[macro.macroName] > 1 then renamed[i] = spellMacroName(macro, true) end
    end
    local used = {}
    for i, macro in ipairs(macros) do
        local name = renamed[i] or macro.macroName
        local n = 1
        while used[name] do
            n = n + 1
            name = numberedMacroName(macro, n)
        end
        used[name] = true
        macro.macroName = name
    end
end

-- A free WoW macro name for an unlearned spell macro (taken holds the ones in use): its usual one, else one
-- keeping its spell's last word, or nil when both are taken.
local function freeMacroName(macro, taken)
    if not taken[macro.macroName] then return macro.macroName end
    local name = spellMacroName(macro, true)
    if not taken[name] then return name end
end

-- Rebuilds smb.macros: the learned spells (from the spellbook), the class config's custom macros and the
-- equipped items with a "Use:" effect, plus the spells not learned yet when smb.showsUnlearned().
function smb.collectMacros()
    wipe(smb.macros)
    local taken, seen = {}, {}
    -- appends a spell's macro and the copies its options turn on. An unlearned one takes only free names
    -- (see freeMacroName), so it never shares a WoW macro with a learned or custom one; learned ones are
    -- sorted out together afterwards (see resolveNameClashes).
    local function add(name, icon, unlearned, id)
        local macro = makeMacro(name, icon, unlearned, id)
        local group = {macro}
        if smb.isOptionOn(macro, "focus") then group[#group + 1] = makeFocusMacro(macro) end
        if smb.isOptionOn(macro, "enemyPlayer") then group[#group + 1] = makeEnemyPlayerMacro(macro) end
        if smb.isOptionOn(macro, "nearest") then group[#group + 1] = makeNearestMacro(macro) end
        if smb.isOptionOn(macro, "combatRank1") then group[#group + 1] = makeCombatRankMacro(macro) end
        local mine = buttonCopies()
        for i = 1, #group do
            local numbers = {}
            for n in pairs(mine[settingKey(group[i])] or NO_SLOTS) do numbers[#numbers + 1] = n end
            table.sort(numbers)
            for _, n in ipairs(numbers) do group[#group + 1] = makeButtonCopy(group[i], n) end
        end
        for i, entry in ipairs(group) do
            if unlearned then
                entry.macroName = freeMacroName(entry, taken)
                if not entry.macroName then
                    if i == 1 then return end -- no name for the spell's own macro, so none for its copies
                else
                    taken[entry.macroName] = true
                end
            end
            if entry.macroName then smb.macros[#smb.macros + 1] = entry end
        end
    end
    forEachClassSpell(function(name, icon, id)
        if name and not seen[name] then -- older books list each rank separately
            seen[name] = true
            add(name, icon, nil, id)
        end
    end)
    resolveNameClashes(smb.macros)
    for _, macro in ipairs(smb.macros) do taken[macro.macroName] = true end
    addCustomMacros(taken)
    addEquipmentMacros(taken)
    if smb.showsUnlearned() then
        forEachUnlearnedSpell(function(name, icon, id) add(name, icon, true, id) end, seen)
    end
    -- by section; within one, first = true custom macros, then spells, then other custom macros, then config
    -- order, then by name, each focus copy right after its spell, then its enemy player, nearest and combat
    -- rank copies
    table.sort(smb.macros, function(a, b)
        if a.categoryRank ~= b.categoryRank then return a.categoryRank < b.categoryRank end
        if (not a.first) ~= (not b.first) then return a.first == true end
        if (not a.custom) ~= (not b.custom) then return not a.custom end
        if a.priority ~= b.priority then return a.priority < b.priority end
        if a.name ~= b.name then return a.name < b.name end
        return copyRank(a) < copyRank(b)
    end)
    -- a body can name other spell macros (its modifier spells), so the bodies come once they all exist
    wipe(smb.macroByName)
    for _, macro in ipairs(smb.macros) do
        if not (macro.custom or macro.equipment or isCopy(macro)) then smb.macroByName[macro.name] = macro end
    end
    for _, macro in ipairs(smb.macros) do
        if not macro.custom then setBody(macro) end
    end
    wipe(smb.macroByMacroName)
    for _, macro in ipairs(smb.macros) do
        smb.macroByMacroName[macro.macroName] = smb.macroByMacroName[macro.macroName] or macro
    end
    if smb.updateBarMenus then smb.updateBarMenus() end
end

-- The id of the highest rank of a spell the player knows, looked up by name, or nil.
local function knownSpellID(name)
    local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
    return info and info.spellID
end

-- The spell whose own tooltip a page macro shows: its highest known rank, or a custom macro's known
-- #showtooltip spell. Nil for equipment macros and custom macros without one.
local function tooltipSpellID(macro)
    if macro.equipment then return nil end
    if macro.custom then return macro.tooltipSpell and knownSpellID(macro.tooltipSpell) end
    return knownSpellID(macro.name) or macro.spellID
end

-- What a page macro's game tooltip describes: "item" (the equipped item), "spell", or nil when it has none.
function smb.gameTooltipKind(macro)
    if macro.equipment then return "item" end
    return tooltipSpellID(macro) and "spell" or nil
end

-- Fills GameTooltip with the game's own tooltip for what a page macro casts or uses. False when there is
-- none (see smb.gameTooltipKind).
function smb.setGameTooltip(macro)
    if macro.equipment then
        GameTooltip:SetInventoryItem("player", macro.slot)
        return true
    end
    local id = tooltipSpellID(macro)
    if not id then return false end
    GameTooltip:SetSpellByID(id)
    return true
end

-- Rewrites the WoW macro at index if its body differs from the page's. Index 0 means it does not exist.
local function syncMacro(macro, index)
    if index ~= 0 and not macro.tooLong and select(3, GetMacroInfo(index)) ~= macro.body then
        EditMacro(index, nil, nil, macro.body)
    end
end

-- Whether every General macro slot is used. The login cleanup only runs then (see Cleanup.lua).
function smb.isGeneralFull()
    return (GetNumMacros()) >= maxAccountMacros()
end

-- Per-account set of the general macros this addon created, by WoW macro name. Login clears them out of the
-- General tab (see smb.resetGeneralMacros), so one character's overflow does not clutter the others'.
local function generalMacros()
    return settings("generalMacros")
end

-- Creates a WoW macro: character specific, or general once those slots are full. Equipment macros are always
-- general. Returns its index, or nil when no slot is free (see reportMacrosFull).
local function createMacro(name, icon, body, equipment)
    local numAccount, numCharacter = GetNumMacros()
    local perCharacter = not equipment and numCharacter < maxCharacterMacros()
    if not perCharacter and numAccount >= maxAccountMacros() then return nil end
    if not perCharacter then generalMacros()[name] = true end
    return CreateMacro(name, icon, body, perCharacter)
end

-- Tells the player createMacro found no free slot: an error line, and the popup unless they turned it off.
local function reportMacrosFull(equipment)
    UIErrorsFrame:AddMessage(addonName .. ": no free " .. (equipment and "general " or "")
        .. "macro slots.", 1, 0.1, 0.1)
    if smb.showMacrosFull then smb.showMacrosFull(equipment) end
end

-- Creates the macro on first use, then puts it on the cursor so it can be dropped on an action bar. Equipment
-- macros are always general: their body names only the slot, so every character shares them.
function smb.pickupMacro(macro)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
        return
    end
    if macro.tooLong then
        UIErrorsFrame:AddMessage(addonName .. ": " .. macro.name .. " is " .. #macro.body
            .. " characters; macros allow " .. MAX_MACRO_BODY .. ".", 1, 0.1, 0.1)
        return
    end
    local index = GetMacroIndexByName(macro.macroName)
    if index == 0 then
        index = createMacro(macro.macroName, macro.macroIcon, macro.body, macro.equipment)
        if not index then
            reportMacrosFull(macro.equipment)
            return
        end
    elseif macro.custom then
        -- also rewrites the icon, which the config can change and which older versions saved as a full path
        -- (such a macro would not pick up)
        index = EditMacro(index, nil, macro.macroIcon, macro.body) or index
    else
        syncMacro(macro, index)
    end
    PickupMacro(index)
end

-- Rewrites the existing WoW macros whose body no longer matches the page (a setting or config changed).
function smb.syncAllMacros()
    if InCombatLockdown() then return end
    for _, macro in ipairs(smb.macros) do
        syncMacro(macro, GetMacroIndexByName(macro.macroName))
    end
end

local MAX_ACTION_SLOTS = 180 -- Classic has 120; empty or missing slots return nil

-- What is on the action bars: {macros = {[macro name] = true}, spells = {[spell name] = true}}. For a
-- macro that shows a spell, GetActionInfo gives the spell's id (subtype "spell") rather than the macro's
-- index, so macros are matched by the name GetActionText gives.
function smb.scanActionBars()
    local bars = {macros = {}, spells = {}}
    for slot = 1, MAX_ACTION_SLOTS do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "macro" then
            local name = GetActionText(slot) or (subType ~= "spell" and GetMacroInfo(id))
            if name then bars.macros[name] = true end
        elseif actionType == "spell" and id then
            local name = C_Spell.GetSpellName(id)
            if name then bars.spells[name] = true end
        end
    end
    return bars
end

-- Whether the general macro at index is one this addon made: createMacro recorded its name, or it has a page
-- macro's name and body (a macro made before that record existed; the body check spares a hand-made macro
-- that happens to share a spell's name). Also returns whether it is an equipment macro.
local function isAddonGeneralMacro(index)
    local name, _, body = GetMacroInfo(index)
    if not name then return false end
    for _, macro in ipairs(smb.macros) do
        if macro.macroName == name and (generalMacros()[name] or macro.body == body) then
            return true, macro.equipment == true
        end
    end
    return generalMacros()[name] == true, false
end

-- isAddonGeneralMacro needs the page macros, which are otherwise only built when the page is first shown.
local function ensureMacros()
    if #smb.macros == 0 then smb.collectMacros() end
end

-- Saves which of the addon's general macros are on this character's action bars, and where, to
-- MacroSpellbookCharDB.generalMacros ({[name] = {icon, body, equipment, slots}}), so smb.resetGeneralMacros
-- can put them back at the next login. Run while playing, whenever the bars or macros change: by logout the
-- action bars may already be gone.
function smb.recordGeneralMacros()
    ensureMacros()
    local numAccount = GetNumMacros()
    local recorded = {}
    for slot = 1, MAX_ACTION_SLOTS do
        local actionType, id, subType = GetActionInfo(slot)
        local name = actionType == "macro" and (GetActionText(slot) or (subType ~= "spell" and GetMacroInfo(id)))
        local index = name and GetMacroIndexByName(name) or 0 -- general indices come first
        if recorded[name] then
            local slots = recorded[name].slots
            slots[#slots + 1] = slot
        elseif index ~= 0 and index <= numAccount then
            local isAddon, equipment = isAddonGeneralMacro(index)
            if isAddon then
                local _, icon, body = GetMacroInfo(index)
                recorded[name] = {icon = icon, body = body, equipment = equipment or nil, slots = {slot}}
            end
        end
    end
    MacroSpellbookCharDB = MacroSpellbookCharDB or {}
    MacroSpellbookCharDB.generalMacros = recorded
end

-- The name of the macro in an action slot, or nil when the slot holds no macro (or one that no longer exists).
-- Also returns whether the slot holds something else: a spell, an item, or a live macro.
local function slotMacro(slot)
    local actionType, id, subType = GetActionInfo(slot)
    if actionType ~= "macro" then return nil, actionType ~= nil end
    local name = GetActionText(slot) or (subType ~= "spell" and GetMacroInfo(id))
    if not name or GetMacroIndexByName(name) == 0 then return nil, false end -- left by a deleted macro
    return name, true
end

-- Called at login: deletes the addon's general macros (any character's), so another character's overflow
-- does not clutter this one's General tab, then recreates the ones this character had on its action bars (in
-- the character tab when there is room). smb.restoreGeneralMacroSlots puts them back on the bars after.
function smb.resetGeneralMacros()
    if InCombatLockdown() then return end
    ensureMacros()
    for index = GetNumMacros(), 1, -1 do -- backwards: a delete shifts the later indices down
        if isAddonGeneralMacro(index) then DeleteMacro(index) end
    end
    wipe(generalMacros())

    local recorded = MacroSpellbookCharDB and MacroSpellbookCharDB.generalMacros or {}
    local full, fullEquipment = false, false
    for name, saved in pairs(recorded) do
        if GetMacroIndexByName(name) == 0 and not createMacro(name, saved.icon, saved.body, saved.equipment) then
            full, fullEquipment = true, fullEquipment or saved.equipment == true
        end
    end
    if full then reportMacrosFull(fullEquipment) end -- once, not for each macro left out
end

-- Puts the macros smb.resetGeneralMacros recreated back in their recorded action slots: the empty ones, and the
-- ones still pointing at the deleted macro, never one holding something else. A just created macro may not
-- be ready to pick up yet, so this is retried until it returns true: every slot holds its macro (or can't).
function smb.restoreGeneralMacroSlots()
    if InCombatLockdown() then return false end
    local recorded = MacroSpellbookCharDB and MacroSpellbookCharDB.generalMacros or {}
    local done = true
    for name, saved in pairs(recorded) do
        local index = GetMacroIndexByName(name)
        if index ~= 0 then
            for _, slot in ipairs(saved.slots) do
                local current, occupied = slotMacro(slot)
                if current ~= name and not occupied then
                    PickupMacro(index)
                    PlaceAction(slot)
                    ClearCursor()
                    done = false -- checked on the next try
                end
            end
        end
    end
    return done
end

-- Whether a page macro is on the action bars, scanned by smb.scanActionBars. A spell macro with no
-- options on also counts when its plain spell is on a bar, and with smb.countsSpellsOnBars() any spell
-- macro does.
function smb.isOnActionBars(macro, bars)
    if bars.macros[macro.macroName] then return true end
    if macro.custom or macro.equipment or isCopy(macro) or not bars.spells[macro.name] then return false end
    return smb.countsSpellsOnBars() or macro.body == bareBody(macro.name)
end

-- Flips a setting ("focus", "enemyPlayer", "nearest", "combatRank1", "pet","raidRank1", "spam", "petAttack",
-- "stopCast" or "startAttack", or "equipStopAttack" or "equipStopCast" on an equipment macro) and rewrites
-- the macro if it already exists. In combat the rewrite waits until the next pickup. The focus, enemyPlayer, nearest and combatRank1 settings add or remove a page entry, so the page must be rebuilt after any of them. Turning focus off also clears
-- the modifier picks that cast the spell on the focus target.
-- Stores a defaulted setting only where it differs from the default, so the rest follow a change of default.
local function setDefaulted(macro, key, on)
    if on == optionDefault(key) then
        settings(key)[settingKey(macro)] = nil
    else
        settings(key)[settingKey(macro)] = on
    end
end

local function rewrite(macro)
    setBody(macro)
    if InCombatLockdown() then return end
    syncMacro(macro, GetMacroIndexByName(macro.macroName))
end

-- Clears the modifier picks that cast a spell on the focus target, once its focus copy is gone.
local function clearFocusPicks(spell)
    local set = settings("modifiers")
    for name, spells in pairs(set) do
        for _, mod in ipairs(smb.MODIFIERS) do
            if spells[mod] == spell and spells[mod .. "Focus"] then
                spells[mod], spells[mod .. "Focus"] = nil, nil
            end
        end
        if not next(spells) then set[name] = nil end
    end
end

local removedCopies = {} -- the WoW macro names of copies turned off since smb.takeRemovedCopies

-- Notes that turning COPY_OPTIONS key off on macro (a spell's macro or one of its copies) removes that copy
-- and its per-button copies, so the action bars can put the spell's own macro back (see ActionBars.lua).
local function noteRemovedCopy(macro, key)
    for _, other in ipairs(smb.macros) do
        local matches = other.name == macro.name and (key == "focus" and other.focus or key == "enemyPlayer"
            and other.enemyPlayer or key == "nearest" and other.nearest or key == "combatRank1" and other.combatCopy)
        if matches then removedCopies[#removedCopies + 1] = {macroName = other.macroName, spell = macro.name, copy = other} end
    end
end

-- smb.toggleOption without the rewrite.
local function flipOption(macro, key)
    if EQUIPMENT_OPTIONS[key] then
        toggleSetting(key, macro.slot)
    elseif DEFAULTED[key] then
        setDefaulted(macro, key, not smb.isOptionOn(macro, key))
    else
        toggleSetting(key, settingKey(macro, key))
    end
    -- turning focus off removes the focus copy, so the modifier picks casting it go too
    if key == "focus" and not smb.isOptionOn(macro, "focus") then clearFocusPicks(macro.name) end
end

function smb.toggleOption(macro, key)
    if COPY_OPTIONS[key] and smb.isOptionOn(macro, key) then noteRemovedCopy(macro, key) end
    flipOption(macro, key)
    rewrite(macro)
end

-- Sets where a macro casts (nil for Target, "mouseover" or "cursor", see smb.offersCastOn), then rewrites
-- it like smb.toggleOption. It changes the macros that cast this spell with a modifier key or as a follow-up
-- too, so the page must be rebuilt after.
function smb.setCastOn(macro, mode)
    if not smb.offersCastOn(macro, mode) then return end
    castOnSettings()[settingKey(macro)] = mode
    rewrite(macro)
end

-- Flips a macro's "stopCast", "startAttack", "stopAttack", "autoShot", "petFollow", "petAttack", "cancelIceBlock",
-- "clearDead" or "targetEnemy" line on one side ("before" or "after") of the cast,
-- moving it to the end of that side's order when it turns on, then rewrites the macro like smb.toggleOption.
function smb.toggleLine(macro, key, side)
    local placement = PLACEMENT[key]
    if SIDE_SETTINGS[key] then
        local setting = SIDE_SETTINGS[key][side]
        if optionDefault(setting) ~= nil then
            setDefaulted(macro, setting, not smb.isLineOn(macro, key, side))
        else
            toggleSetting(setting, settingKey(macro))
        end
    elseif side == placement.main then
        flipOption(macro, key)
    else
        toggleSetting(placement.setting, settingKey(macro))
    end
    noteTick(macro, side, key, smb.isLineOn(macro, key, side))
    rewrite(macro)
end

-- Adds an equipment slot to the end of the macro's list and order for a side ("before", the default, or
-- "after") of the cast, or removes it, then rewrites the macro like smb.toggleOption.
function smb.toggleUseSlot(macro, slot, side)
    local slots = {}
    local at = smb.isUsingSlot(macro, slot, side)
    for i, used in ipairs(smb.useItemSlots(macro, side)) do
        if i ~= at then slots[#slots + 1] = used end
    end
    if not at then slots[#slots + 1] = slot end
    settings(USE_SETTING[side or "before"])[settingKey(macro)] = #slots > 0 and slots or nil
    noteTick(macro, side or "before", slot, not at)
    rewrite(macro)
end

-- Turns a racial on or off on a side ("before" or "after") of the cast, moving it to the end of that side's
-- order when on, then rewrites the macro like smb.toggleOption.
function smb.toggleRacial(macro, racial, side)
    local set = settings(RACIAL_SETTING[side])
    local racials = set[settingKey(macro)] or {}
    racials[racial] = not racials[racial] or nil
    set[settingKey(macro)] = next(racials) and racials or nil
    noteTick(macro, side, racial, racials[racial] == true)
    rewrite(macro)
end

-- Sets the spell a macro casts while a modifier key ("shift", "ctrl" or "alt") is held, on the focus target
-- when onFocus, or clears it with nil, then rewrites the macro like smb.toggleOption.
function smb.setModifierSpell(macro, mod, name, onFocus)
    local set = settings("modifiers")
    local spells = set[settingKey(macro)] or {}
    spells[mod] = name
    spells[mod .. "Focus"] = name and onFocus or nil
    spells[mod .. "Slot"] = nil
    set[settingKey(macro)] = next(spells) and spells or nil
    rewrite(macro)
end

-- Sets the equipment slot a macro uses while a modifier key is held, replacing any spell set for that key,
-- then rewrites the macro like smb.toggleOption.
function smb.setModifierSlot(macro, mod, slot)
    local set = settings("modifiers")
    local spells = set[settingKey(macro)] or {}
    spells[mod], spells[mod .. "Focus"], spells[mod .. "Slot"] = nil, nil, slot
    set[settingKey(macro)] = next(spells) and spells or nil
    rewrite(macro)
end

-- Sets the spell a macro casts while in a form (a form's name from the class config), or clears it with nil,
-- then rewrites the macro like smb.toggleOption.
function smb.setFormSpell(macro, form, name)
    local set = settings("forms")
    local spells = set[settingKey(macro)] or {}
    spells[form] = name
    set[settingKey(macro)] = next(spells) and spells or nil
    rewrite(macro)
end

-- Adds a spell to the end of a macro's sequence, or removes it, then rewrites the macro like
-- smb.toggleOption.
function smb.toggleSequenceSpell(macro, name)
    local spells = {}
    local at = smb.sequencePosition(macro, name)
    for _, picked in ipairs(smb.sequenceSpells(macro)) do
        if picked ~= name then spells[#spells + 1] = picked end
    end
    if not at then spells[#spells + 1] = name end
    settings("sequence")[settingKey(macro)] = #spells > 0 and spells or nil
    rewrite(macro)
end

-- Sets the spell a cooldown macro casts after its own, or clears it with nil, then rewrites the macro like
-- smb.toggleOption.
function smb.setFollowUpSpell(macro, name)
    settings("followUp")[settingKey(macro)] = name
    rewrite(macro)
end

-- Removes every spell from a macro's sequence, then rewrites the macro like smb.toggleOption.
function smb.clearSequence(macro)
    settings("sequence")[settingKey(macro)] = nil
    rewrite(macro)
end

-- The settings a spell macro stores under its settingKey, and an equipment macro under its slot.
local SPELL_SETTINGS = {
    "castOn", "focus", "enemyPlayer", "nearest", "combatRank1", "pet", "raidRank1", "spam",
    "petAttack", "stopCast", "startAttack", "startAttackBefore", "petAttackAfter", "autoShotBefore",
    "autoShotAfter", "petFollowBefore", "petFollowAfter",
    "stopAttackBefore", "stopAttackAfter", "cancelIceBlockBefore", "clearDeadBefore", "targetEnemyBefore", "useItems", "useItemsAfter", "racials", "racialsAfter", "order", "orderAfter", "modifiers", "forms",
    "sequence", "followUp",
}
local EQUIPMENT_SETTINGS = {"equipStopAttack", "equipStopCast"}

-- Every spell macro, copies included, and every equipment macro can be reset to its defaults.
function smb.offersReset(macro)
    return macro.equipment == true or smb.offersUseItems(macro)
end

-- The keys a macro's settings are stored under, as {setting, key} pairs.
local function storedSettings(macro)
    local stored = {}
    if macro.equipment then
        for _, setting in ipairs(EQUIPMENT_SETTINGS) do stored[#stored + 1] = {setting, macro.slot} end
        return stored
    end
    for _, setting in ipairs(SPELL_SETTINGS) do
        -- a copy's own settings, without the COPY_OPTIONS stored under its spell's name: resetting a copy
        -- keeps it
        if not ((isCopy(macro) or macro.buttonCopy) and COPY_OPTIONS[setting]) then
            stored[#stored + 1] = {setting, settingKey(macro, setting)}
        end
    end
    return stored
end

-- Whether a macro has any setting that differs from its defaults.
function smb.hasCustomSettings(macro)
    for _, pair in ipairs(storedSettings(macro)) do
        if settings(pair[1])[pair[2]] ~= nil then return true end
    end
    return false
end

-- Clears every setting of a macro, so it follows the defaults again, then rewrites it like smb.toggleOption.
-- Resetting a spell's macro turns focus, enemyPlayer, nearest and combatRank1 off, removing the copies along
-- with their own settings, so the page must be rebuilt after.
function smb.resetMacro(macro)
    if not smb.offersReset(macro) then return end
    local noCopies = macro.equipment or isCopy(macro) or macro.buttonCopy -- has no copies of its own to remove
    local hadFocus = not noCopies and smb.isOptionOn(macro, "focus")
    if not noCopies then
        for key in pairs(COPY_OPTIONS) do
            if smb.isOptionOn(macro, key) then noteRemovedCopy(macro, key) end
        end
    end
    local stored = storedSettings(macro)
    if not noCopies then
        for _, copy in ipairs({{focus = true}, {enemyPlayer = true}, {nearest = true}, {combatCopy = true}}) do
            copy.name = macro.name
            for _, pair in ipairs(storedSettings(copy)) do stored[#stored + 1] = pair end
        end
    end
    for _, pair in ipairs(stored) do settings(pair[1])[pair[2]] = nil end
    if hadFocus then clearFocusPicks(macro.name) end
    rewrite(macro)
end

-- Every action slot holding each WoW macro, as {[macro name] = {slot, ...}} in slot order, and whether any
-- slot holds anything at all (false while the bars haven't loaded).
function smb.macroSlots()
    local slots, any = {}, false
    for slot = 1, MAX_ACTION_SLOTS do
        local name, occupied = slotMacro(slot)
        any = any or occupied
        if name then
            slots[name] = slots[name] or {}
            table.insert(slots[name], slot)
        end
    end
    return slots, any
end

-- Puts a page macro on an action slot, creating its WoW macro if needed, and drops whatever the slot held.
-- Returns false when it couldn't (in combat, too long, or no free macro slot; smb.pickupMacro reports why).
function smb.placeMacro(macro, slot)
    if InCombatLockdown() then return false end
    smb.pickupMacro(macro)
    if GetCursorInfo() ~= "macro" then
        ClearCursor()
        return false
    end
    PlaceAction(slot)
    ClearCursor()
    return true
end

-- Empties an action slot.
function smb.clearSlot(slot)
    if InCombatLockdown() then return end
    PickupAction(slot)
    ClearCursor()
end

-- Deletes the WoW macro with this name, if there is one.
function smb.deleteMacroNamed(name)
    if InCombatLockdown() then return end
    local index = GetMacroIndexByName(name)
    if index ~= 0 then DeleteMacro(index) end
    generalMacros()[name] = nil
end

-- A spell's copy turned on by a COPY_OPTIONS key ("focus", "enemyPlayer", "nearest" or "combatRank1"), from
-- smb.macros, or nil.
function smb.copyOf(spell, key)
    for _, macro in ipairs(smb.macros) do
        if macro.name == spell and not macro.buttonCopy and (key == "focus" and macro.focus
            or key == "enemyPlayer" and macro.enemyPlayer or key == "nearest" and macro.nearest
            or key == "combatRank1" and macro.combatCopy) then
            return macro
        end
    end
end

-- Whether copies were turned off since the last smb.takeRemovedCopies.
function smb.hasRemovedCopies()
    return #removedCopies > 0
end

-- Returns the copies turned off since the last call (see noteRemovedCopy), as {macroName, spell, copy}.
function smb.takeRemovedCopies()
    local removed = removedCopies
    removedCopies = {}
    return removed
end

local function copyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = copyValue(v) end
    return copy
end

local function characterKey()
    return (GetRealmName() or "") .. "-" .. (UnitName("player") or "")
end

-- Makes a per-button copy of a page macro: the lowest number from 2 free on the account, starting with the
-- macro's own settings. Rebuilds smb.macros and returns the copy from it.
function smb.newButtonCopy(macro)
    local base = macro.buttonBase or settingKey(macro)
    local owners = settings("buttonCopyOwners")
    local n = 2
    while owners[base .. " #" .. n] do n = n + 1 end
    owners[base .. " #" .. n] = characterKey()
    local mine = buttonCopies()
    mine[base] = mine[base] or {}
    mine[base][n] = true
    local copy = makeButtonCopy(macro, n)
    for _, setting in ipairs(SPELL_SETTINGS) do
        if not COPY_OPTIONS[setting] then
            settings(setting)[settingKey(copy, setting)] = copyValue(settings(setting)[settingKey(macro, setting)])
        end
    end
    smb.collectMacros()
    for _, other in ipairs(smb.macros) do
        if other.buttonCopy == n and other.buttonBase == base then return other end
    end
end

-- Deletes a per-button copy: its settings, its record and its WoW macro. Rebuild smb.macros after.
function smb.deleteButtonCopy(copy)
    local key = copy.buttonBase .. " #" .. copy.buttonCopy
    for _, setting in ipairs(SPELL_SETTINGS) do
        if not COPY_OPTIONS[setting] then settings(setting)[key] = nil end
    end
    settings("buttonCopyOwners")[key] = nil
    local mine = buttonCopies()
    if mine[copy.buttonBase] then
        mine[copy.buttonBase][copy.buttonCopy] = nil
        if not next(mine[copy.buttonBase]) then mine[copy.buttonBase] = nil end
    end
    smb.deleteMacroNamed(copy.macroName)
end
