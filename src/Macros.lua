local addonName, smb = ...

-- Builds the page's macro list (smb.macros) from the spellbook and the player's class config, and keeps
-- the WoW macros it creates in step with it. No frames here: SpellBookTab.lua draws the page.

local ICON_QUESTION_MARK = 134400 -- Interface\Icons\INV_Misc_QuestionMark

local MAX_MACRO_NAME = 16 -- longer names are truncated by CreateMacro, so GetMacroIndexByName would miss them
local MAX_MACRO_BODY = 255
local FOCUS_SUFFIX = " @F" -- ends a focus copy's WoW macro name, keeping it apart from the spell's own

-- MAX_CHARACTER_MACROS and MAX_ACCOUNT_MACROS come from the load-on-demand Blizzard_MacroUI, so they
-- are nil until the macro window has been opened once.
local function maxCharacterMacros()
    return MAX_CHARACTER_MACROS or 18
end

local function maxAccountMacros()
    return MAX_ACCOUNT_MACROS or 120
end

-- Per-account sets of spell names, keyed by setting: "mouseover" (macro casts on the mouseover unit
-- first), "cursor" (macro casts a ground-targeted spell where the cursor points), "focus" (the page
-- also lists a copy of the macro that casts on the focus target), "pet" (a summon macro casts the
-- pet's ability while that pet is out), "raidRank1" (the macro casts rank 1 in a raid group), "spam"
-- (the macro does nothing while its channelled spell is channelling, or its stealth spell is on), "stance" (the macro switches to a
-- stance the spell can be cast in first), "petAttack" (the macro also sends
-- the pet to attack), "stopCast" (the macro stops the current cast first) or "startAttack" (the macro
-- starts melee auto-attack after the cast). For petAttack, stopCast and startAttack, true or false overrides the
-- setting's default (optionDefault), nil follows it. "startAttackBefore" also adds /startattack before the
-- cast (see smb.isLineOn); an old "stopCastAfter" is ignored. "useItems" and "useItemsAfter" hold a list of equipment
-- slots instead of a flag: the macro uses each slot's item, in that order, before (or after) the cast. "racials" and
-- "racialsAfter" hold a set of racial names: the macro casts each one before (or after) the cast. "order" and
-- "orderAfter" hold the order the player ticked a side's lines in, as a list of ids ("stopCast", "startAttack",
-- a racial's name or a slot number); it only orders the lines the settings above turn on (see sideEntries).
-- "equipStopAttack" and "equipStopCast" are keyed by inventory slot rather than spell name: the equipment macro
-- for that slot starts with /stopattack (or /stopcasting) before using the item. "modifiers" holds a table
-- per spell name, {shift = name, ctrl = name, alt = name}: the macro casts that spell while the key is held,
-- on the focus target when shiftFocus (ctrlFocus, altFocus) is true (see smb.modifierSpell). "sequence" holds a
-- list of spell names per spell: the macro /castsequences its own spell, then those, in that order. "forms"
-- holds a table per spell name, {[form name] = spell name}: the macro casts that spell while in that form of
-- the class config's forms (see smb.formSpell).
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

-- The settings with a default; each spell macro stores one only where it differs from the default.
local DEFAULTED = { petAttack = true, stopCast = true, startAttack = true }

-- The equipment macros' settings, keyed by the macro's slot (see settings).
local EQUIPMENT_OPTIONS = { equipStopAttack = true, equipStopCast = true }

-- The default of a setting that has one ("petAttack", "stopCast" or "startAttack"), or nil.
local function optionDefault(key)
    if key == "petAttack" then return smb.petAttacksByDefault() end
    if key == "stopCast" then return smb.stopsCastingByDefault() end
    if key == "startAttack" then return smb.startsAttackByDefault() end
end

local function toggleSetting(key, name)
    local set = settings(key)
    set[name] = not set[name] or nil
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
        isChanneledSpell = nameMatcher(source.channeled),
        isStealthSpell = nameMatcher(source.stealth),
        isCooldownSpell = nameMatcher(source.cooldowns),
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

-- Enemy spell macros offer "petAttack" when the class does. A focus copy shares its spell's setting.
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
-- "startAttack" on a stealth spell: attacking would break the stealth. A focus copy shares its spell's
-- setting. Custom and equipment macros offer neither.
function smb.offersStopCast(macro)
    return not macro.custom and not macro.equipment and smb.classOffersStopCast()
end

function smb.offersStartAttack(macro)
    return not macro.custom and not macro.equipment and not macro.stealth and smb.classOffersStartAttack()
end

-- Whether a macro offers an option ("mouseover", "cursor", "focus", "pet", "raidRank1", "spam", "stance",
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
        local on = settings(key)[macro.name]
        if on == nil then return optionDefault(key) end
        return on
    end
    local offered
    if key == "cursor" then
        offered = macro.cursor
    elseif key == "pet" then
        offered = macro.petAbility ~= nil
    elseif key == "raidRank1" then
        offered = macro.raidRank1
    elseif key == "spam" then
        offered = macro.spam ~= nil
    elseif key == "stance" then
        offered = macro.stances ~= nil
    else
        offered = macro.target ~= nil
    end
    return offered and settings(key)[macro.name] == true
end

-- The side of the cast the stopCast and startAttack settings themselves (with their defaults) put the line
-- on, and the setting that adds it on the other side too. stopCast has no other side: stopping a cast after
-- casting would cancel the spell just cast.
local PLACEMENT = {
    stopCast = {main = "before"},
    startAttack = {main = "after", other = "before", setting = "startAttackBefore"},
}

-- Whether a macro has its "stopCast" or "startAttack" line on a side ("before" or "after") of the cast;
-- startAttack can be on either, both or neither, stopCast only before. A focus copy shares its spell's
-- settings.
function smb.isLineOn(macro, key, side)
    local placement = PLACEMENT[key]
    if side == placement.main then return smb.isOptionOn(macro, key) end
    if side ~= placement.other then return false end
    return smb.offersStartAttack(macro) and settings(placement.setting)[macro.name] == true
end

-- Whether a macro offers a way to cast other than the plain spell's (any option but stopCast and
-- startAttack).
function smb.hasCastOptions(macro)
    return macro.target ~= nil or macro.cursor or macro.petAbility ~= nil or macro.raidRank1 or macro.spam ~= nil
        or macro.stances ~= nil or smb.hasSequenceOn(macro)
end

-- Every spell macro offers using equipped items before and after the cast. A focus copy shares its spell's
-- slots.
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
    return settings(USE_SETTING[side or "before"])[macro.name] or NO_SLOTS
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

-- the setting holding a macro's racials for each side of the cast
local RACIAL_SETTING = {before = "racials", after = "racialsAfter"}

-- Whether a macro casts a racial on a side ("before" or "after") of the cast. Every spell macro offers its
-- race's learned racials. A focus copy shares its spell's racials.
function smb.isRacialOn(macro, racial, side)
    local set = settings(RACIAL_SETTING[side])[macro.name]
    if not (set and set[racial] and smb.offersUseItems(macro)) then return false end
    return tContains(smb.offeredRacials(), racial)
end

-- The racials a macro casts on a side of the cast, in config order.
local function racialsOn(macro, side)
    local on = {}
    local set = smb.offersUseItems(macro) and settings(RACIAL_SETTING[side])[macro.name]
    if not set then return on end
    for _, racial in ipairs(smb.offeredRacials()) do
        if set[racial] then on[#on + 1] = racial end
    end
    return on
end

-- Whether a macro casts any racial on either side of the cast.
function smb.hasRacialOn(macro)
    return racialsOn(macro, "before")[1] ~= nil or racialsOn(macro, "after")[1] ~= nil
end

-- The modifier keys a spell macro can cast another spell with, in the order their clauses are tried: with
-- several keys held, the first wins.
smb.MODIFIERS = {"shift", "ctrl", "alt"}

-- Every spell macro but a focus copy offers a spell for each modifier key.
function smb.offersModifiers(macro)
    return not macro.custom and not macro.equipment and not macro.focus
end

-- The spell a macro casts while a modifier key ("shift", "ctrl" or "alt") is held, or nil, and whether it
-- casts it on the focus target, like that spell's focus copy.
function smb.modifierSpell(macro, mod)
    if not smb.offersModifiers(macro) then return nil, false end
    local spells = settings("modifiers")[macro.name]
    if not (spells and spells[mod]) then return nil, false end
    return spells[mod], spells[mod .. "Focus"] == true
end

-- Whether a macro has a spell set for any modifier key.
function smb.hasModifierOn(macro)
    for _, mod in ipairs(smb.MODIFIERS) do
        if smb.modifierSpell(macro, mod) then return true end
    end
    return false
end

-- The class config's forms' names, in config order: Druids' Caster, Cat, Bear, Travel and Aquatic.
function smb.formNames()
    local names = {}
    for i, form in ipairs(classConfig().forms) do names[i] = form.name end
    return names
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
    local spells = settings("forms")[macro.name]
    return spells and spells[form]
end

-- Whether a page macro's spell can be cast in a form (a form's name from the class config): not when it sits
-- in a section named after another form, so Cat offers no Bear spells, Bear no Cat spells, and Caster neither.
function smb.formAllows(form, other)
    return other.category == form or not tContains(smb.formNames(), other.category)
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

-- A spell macro in a sequence section, or a cooldown spell in any section (see Config.lua), offers a cast
-- sequence, unless it casts its pet's ability: a summon can't be sequenced. A focus copy shares its spell's
-- sequence.
function smb.offersSequence(macro)
    return (macro.sequence or macro.cooldown) and smb.offersUseItems(macro) and not smb.isOptionOn(macro, "pet")
end

-- Whether a macro's sequence can cast another page macro after its own spell: a learned spell in a sequence
-- section, or, for a cooldown spell, also one in a cooldownSteps section (see Config.lua).
function smb.canSequence(macro, other)
    if other.unlearned or other.name == macro.name then return false end
    return other.sequence or (macro.cooldown and other.cooldownStep)
end

-- The spells a macro casts after its own, in order. Don't modify it.
function smb.sequenceSpells(macro)
    if not smb.offersSequence(macro) then return NO_SLOTS end
    return settings("sequence")[macro.name] or NO_SLOTS
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

-- Whether a macro has an options menu: every spell macro does, for stopCast or startAttack, and every
-- equipment macro, for equipStopAttack and equipStopCast.
function smb.hasOptions(macro)
    return smb.hasCastOptions(macro) or smb.offersStopCast(macro) or smb.offersStartAttack(macro)
        or smb.offersUseItems(macro) or macro.equipment == true
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

-- A /cast of name that tries each target conditional in turn ("" for none), with a rank 1 cast in a raid
-- group before each one. prefix ("" for none) goes before the clauses: the modifier clauses.
local function raidRank1Cast(name, targets, spam, prefix)
    local clauses = {}
    for _, target in ipairs(targets) do
        clauses[#clauses + 1] = cond(spam, target, "group:raid") .. " " .. name .. "(Rank 1)"
        local plain = cond(spam, target)
        clauses[#clauses + 1] = (plain ~= "" and plain .. " " or "") .. name
    end
    return "/cast " .. prefix .. table.concat(clauses, "; ")
end

-- The page's spell macros by spell name (not focus copies, custom or equipment macros), for the modifier
-- clauses. Rebuilt with smb.macros.
smb.macroByName = {}

-- A clause casting another page macro's spell under a condition (e.g. "mod:shift"), followed by "; ", the
-- way that spell's own page macro targets: at the mouseover or the cursor when that option is on there.
local function targetedClause(condition, other)
    local conditional = "[" .. condition .. "]"
    if smb.isOptionOn(other, "cursor") then
        conditional = "[" .. condition .. ",@cursor]"
    elseif smb.isOptionOn(other, "mouseover") then
        conditional = "[" .. condition .. ",@mouseover," .. other.target .. ",nodead]" .. conditional
    end
    return conditional .. " " .. other.name .. "; "
end

-- The clauses that cast a macro's modifier spells, each followed by "; ", ready to go before its own, e.g.
-- "[mod:shift] Fear; [mod:alt,@mouseover,help,nodead][mod:alt] Flash Heal; ", or "". Each spell is cast the
-- way its own page macro targets: at the mouseover or the cursor when that option is on there. A focus
-- pick casts like the spell's focus copy, on the focus target or else the target, but without switching
-- target back after. A spell that isn't learned is left out, keeping its setting. So is a focus pick whose
-- spell has no focus copy, which only old saved data can hold: removing the copy clears its picks.
local function modifierClauses(macro)
    local clauses = {}
    for _, mod in ipairs(smb.MODIFIERS) do
        local name, onFocus = smb.modifierSpell(macro, mod)
        local other = smb.macroByName[name or ""]
        if other and not other.unlearned and (not onFocus or smb.isOptionOn(other, "focus")) then
            if onFocus then
                local held = "[mod:" .. mod
                clauses[#clauses + 1] = held .. ",@focus," .. other.target .. ",nodead]" .. held .. "] "
                    .. other.name .. "; "
            else
                clauses[#clauses + 1] = targetedClause("mod:" .. mod, other)
            end
        end
    end
    return table.concat(clauses)
end

-- A focus copy switches back to the previous target after the cast.
local FOCUS_FOOTER = "\n/script TargetLastTarget()"

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

-- A line switching to the first of a spell's stances unless already in one of them, e.g.
-- "/cast [nostance:1/3] Battle Stance\n", or "" when the first stance's slot is unknown.
local function stanceLine(stances)
    if not stanceSlot(stances[1]) then return "" end
    local slots = {}
    for _, stance in ipairs(stances) do
        slots[#slots + 1] = stanceSlot(stance)
    end
    return "/cast [nostance:" .. table.concat(slots, "/") .. "] " .. stances[1] .. "\n"
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

-- The clauses that cast a macro's form spells, each followed by "; ", ready to go after its modifier
-- clauses, e.g. "[form:3] Shred; [form:1,@mouseover,harm,nodead][form:1] Faerie Fire (Feral); ", or "". Each
-- spell is cast the way its own page macro targets, like a modifier spell. A pick that isn't learned, whose
-- form isn't, or that the form doesn't allow (see smb.formAllows), is left out, keeping its setting.
local function formClauses(macro)
    if not smb.offersForms(macro) then return "" end
    local clauses = {}
    for _, form in ipairs(classConfig().forms) do
        local other = smb.macroByName[smb.formSpell(macro, form.name) or ""]
        local condition = other and not other.unlearned and smb.formAllows(form.name, other) and formCondition(form)
        if condition then clauses[#clauses + 1] = targetedClause(condition, other) end
    end
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

-- The stances a spell can be cast in, the one to switch to first, or nil for a spell that needs none. The
-- tooltip says which stances, so the list matches this client's rules; the class config's list fills in
-- when the tooltip names none, and its order picks the stance to switch to.
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

-- A macro's "/stopcasting" or "/startattack" line on a side of the cast, with the spam condition on
-- /stopcasting, or nil when it is off on that side.
local function placedLine(macro, key, side, spam)
    if not smb.isLineOn(macro, key, side) then return nil end
    if key == "startAttack" then return "/startattack" end
    return "/stopcasting" .. (spam and " [" .. spam .. "]" or "")
end

-- the setting holding the order a macro's lines were ticked in for each side of the cast
local ORDER_SETTING = {before = "order", after = "orderAfter"}

-- The lines a macro has on a side of the cast, as {id, text}, in the order the player ticked them. Lines
-- the order list doesn't name (on by a default, or ticked before it existed) come first, in menu order:
-- stopCast, startAttack, racials, then slots.
local function sideEntries(macro, side, spam)
    local entries = {}
    for _, key in ipairs({"stopCast", "startAttack"}) do
        local line = placedLine(macro, key, side, spam)
        if line then entries[#entries + 1] = {key, line} end
    end
    for _, racial in ipairs(racialsOn(macro, side)) do entries[#entries + 1] = {racial, "/cast " .. racial} end
    for _, slot in ipairs(smb.useItemSlots(macro, side)) do entries[#entries + 1] = {slot, "/use " .. slot} end
    local rank = {}
    for i, id in ipairs(settings(ORDER_SETTING[side])[macro.name] or NO_SLOTS) do rank[id] = i end
    -- table.sort isn't stable, so ties keep menu order through each entry's index
    for i, entry in ipairs(entries) do entry.rank, entry.index = rank[entry[1]] or 0, i end
    table.sort(entries, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.index < b.index
    end)
    return entries
end

-- A line's place among a macro's lines on a side of the cast, or nil when it is off there. id is "stopCast",
-- "startAttack", a racial's name or a slot number.
function smb.sidePosition(macro, id, side)
    for i, entry in ipairs(sideEntries(macro, side)) do
        if entry[1] == id then return i end
    end
end

-- Moves a line to the end of a macro's tick order for a side when it is turned on, or drops it when off.
local function noteTick(macro, side, id, on)
    local set = settings(ORDER_SETTING[side])
    local order = {}
    for _, ticked in ipairs(set[macro.name] or NO_SLOTS) do
        if ticked ~= id then order[#order + 1] = ticked end
    end
    if on then order[#order + 1] = id end
    set[macro.name] = #order > 0 and order or nil
end

local function castBody(macro)
    -- the spam option adds [nochanneling:<spell>] (or [nostealth]) to every cast clause, so a press while
    -- the spell is channelling (or stealth is on) can't restart (or cancel) it; the before-cast lines come
    -- first, in the order the player ticked them (see sideEntries): the stopCast option stops the current
    -- cast (but, with spam on, not this spell's own channel), the startAttack option starts auto-attack,
    -- racials are cast and useItems slots used; the petAttack option then sends the pet at the current
    -- target before the cast; the stance option switches stance before the cast. With racials, items, a
    -- stance or /startattack first, #showtooltip names the spell so the button doesn't show the item or the
    -- stance. It names the spell with spam on too, unless modifier or form clauses pick the icon: while
    -- stealthed (or channelling) no clause matches, and a bare #showtooltip would show a question mark
    local spam = smb.isOptionOn(macro, "spam") and macro.spam or nil
    local stance = smb.isOptionOn(macro, "stance") and stanceLine(macro.stances) or ""
    -- the modifier spells' clauses go first, so a held key wins over the form spells, and those over the
    -- macro's own
    local mods = modifierClauses(macro) .. formClauses(macro)
    local namesSpell = stance ~= "" or (spam ~= nil and mods == "")
    local before = {}
    for _, entry in ipairs(sideEntries(macro, "before", spam)) do
        before[#before + 1] = entry[2] .. "\n"
        if entry[1] ~= "stopCast" then namesSpell = true end
    end
    local header = "#showtooltip" .. (namesSpell and " " .. macro.name or "") .. "\n" .. table.concat(before)
        .. (smb.isOptionOn(macro, "petAttack") and "/petattack\n" or "") .. stance
    -- with a sequence, every step is cast like the macro's own spell
    local steps = sequenceSteps(macro)
    -- "/cast <conditional> name", or "/cast name" when there is no conditional; with a sequence,
    -- "/castsequence <conditional> reset=2 name, step 2, ..."
    local function cast(conditional)
        local prefix = (conditional ~= "" and conditional .. " " or "")
        if steps then
            return "/castsequence " .. mods .. prefix .. SEQUENCE_RESET .. table.concat(steps, ", ")
        end
        return "/cast " .. mods .. prefix .. macro.name
    end
    -- a sequence can't downrank: a rank 1 clause per target would repeat every step
    if smb.isOptionOn(macro, "raidRank1") and not steps then
        local targets = {""}
        if macro.focus then
            targets = {"@focus," .. macro.target .. ",nodead", ""}
        elseif smb.isOptionOn(macro, "mouseover") then
            targets = {"@mouseover," .. macro.target .. ",nodead", ""}
        end
        return header .. raidRank1Cast(macro.name, targets, spam, mods) .. (macro.focus and FOCUS_FOOTER or "")
    end
    if macro.focus then
        return header .. cast(cond(spam, "@focus," .. macro.target .. ",nodead") .. "[" .. (spam or "") .. "]")
            .. FOCUS_FOOTER
    end
    if smb.isOptionOn(macro, "pet") then
        -- [pet:X] matches the pet's creature family, so another demon being out still summons this one
        local family = macro.name:match("^Summon (.+)$") or macro.name
        return header .. "/cast " .. mods .. cond(spam, "pet:" .. family) .. " " .. macro.petAbility .. "; "
            .. (spam and cond(spam) .. " " or "") .. macro.name
    end
    if smb.isOptionOn(macro, "cursor") then
        return header .. cast(cond(spam, "@cursor"))
    end
    if smb.isOptionOn(macro, "mouseover") then
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

-- The after-cast lines (racials, useItemsAfter slots and the startAttack option placed after the cast), in
-- the order the player ticked them, end the macro.
-- #showtooltip still shows the spell: its /cast comes first.
local function macroBody(macro)
    if macro.equipment then return equipmentBody(macro) end
    local body = castBody(macro)
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
-- off when cast again, so a stealth spell casts only while not stealthed.
local function spamCondition(name)
    local c = classConfig()
    if c.isStealthSpell(name) then return "nostealth" end
    if c.isChanneledSpell(name) then return "nochanneling:" .. name end
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
        spam = spamCondition(name),
        stealth = classConfig().isStealthSpell(name) ~= nil,
        stances = stancesOf(name, id),
        -- the question mark icon lets #showtooltip show the spell's own icon on the action bar
        macroName = name:sub(1, MAX_MACRO_NAME),
        macroIcon = ICON_QUESTION_MARK,
        icon = icon or ICON_QUESTION_MARK,
    }
    return macro -- smb.collectMacros sets the body once every macro exists
end

-- A copy of a spell macro that casts on the focus target, falling back to the current target. Its menu
-- offers only the focus option, which removes it.
local function makeFocusMacro(macro)
    local copy = {}
    for key, value in pairs(macro) do copy[key] = value end
    copy.focus = true
    copy.cursor = false
    copy.petAbility = nil
    copy.macroName = macro.name:sub(1, MAX_MACRO_NAME - #FOCUS_SUFFIX) .. FOCUS_SUFFIX
    return copy
end

local getSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture

-- The icon of the spell named by a leading "#showtooltip <spell>" line, or nil.
local function showtooltipIcon(body)
    local spell = body:match("^#showtooltip[ \t]+([^\n]*%S)")
    if spell and getSpellTexture then return getSpellTexture(spell) end
end

-- A config custom entry as a page macro. Its body is used as written, and it has no options menu.
local function makeCustomMacro(entry, index, categoryRank)
    return {
        name = entry.name,
        categoryRank = categoryRank,
        priority = index,
        category = entry.category or "Custom",
        custom = true,
        cursor = false,
        macroName = entry.name:sub(1, MAX_MACRO_NAME),
        macroIcon = entry.icon or ICON_QUESTION_MARK,
        icon = entry.icon or showtooltipIcon(entry.body) or ICON_QUESTION_MARK,
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

-- Rebuilds smb.macros: the learned spells (from the spellbook), the class config's custom macros and the
-- equipped items with a "Use:" effect, plus the spells not learned yet when smb.showsUnlearned().
function smb.collectMacros()
    wipe(smb.macros)
    local taken, seen = {}, {}
    local function add(name, icon, unlearned, id)
        local macro = makeMacro(name, icon, unlearned, id)
        if unlearned and taken[macro.macroName] then return end -- a custom macro already uses the name
        taken[macro.macroName] = true
        smb.macros[#smb.macros + 1] = macro
        if smb.isOptionOn(macro, "focus") then
            local copy = makeFocusMacro(macro)
            taken[copy.macroName] = true
            smb.macros[#smb.macros + 1] = copy
        end
    end
    forEachClassSpell(function(name, icon, id)
        if name and not seen[name] then -- older books list each rank separately
            seen[name] = true
            add(name, icon, nil, id)
        end
    end)
    addCustomMacros(taken)
    addEquipmentMacros(taken)
    if smb.showsUnlearned() then
        forEachUnlearnedSpell(function(name, icon, id) add(name, icon, true, id) end, seen)
    end
    -- by section; within one, spells before custom macros, then config order, then by name, each focus
    -- copy right after its spell
    table.sort(smb.macros, function(a, b)
        if a.categoryRank ~= b.categoryRank then return a.categoryRank < b.categoryRank end
        if (not a.custom) ~= (not b.custom) then return not a.custom end
        if a.priority ~= b.priority then return a.priority < b.priority end
        if a.name ~= b.name then return a.name < b.name end
        return not a.focus and b.focus == true
    end)
    -- a body can name other spell macros (its modifier spells), so the bodies come once they all exist
    wipe(smb.macroByName)
    for _, macro in ipairs(smb.macros) do
        if not (macro.custom or macro.equipment or macro.focus) then smb.macroByName[macro.name] = macro end
    end
    for _, macro in ipairs(smb.macros) do
        if not macro.custom then setBody(macro) end
    end
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
    if macro.custom or macro.equipment or macro.focus or not bars.spells[macro.name] then return false end
    return smb.countsSpellsOnBars() or macro.body == bareBody(macro.name)
end

-- Flips a setting ("mouseover", "cursor", "focus", "pet", "raidRank1", "spam", "stance", "petAttack",
-- "stopCast" or "startAttack", or "equipStopAttack" or "equipStopCast" on an equipment macro) and rewrites
-- the macro if it already exists. In combat the rewrite waits until the next pickup. The focus setting adds or removes a page entry and raidRank1, spam, stance, petAttack,
-- stopCast and startAttack also change the focus copy, and mouseover and cursor the macros that cast this
-- spell with a modifier key, so the page must be rebuilt after any of them. Turning focus off also clears
-- the modifier picks that cast the spell on the focus target.
-- Stores a defaulted setting only where it differs from the default, so the rest follow a change of default.
local function setDefaulted(macro, key, on)
    if on == optionDefault(key) then
        settings(key)[macro.name] = nil
    else
        settings(key)[macro.name] = on
    end
end

local function rewrite(macro)
    setBody(macro)
    if InCombatLockdown() then return end
    syncMacro(macro, GetMacroIndexByName(macro.macroName))
end

-- smb.toggleOption without the rewrite.
local function flipOption(macro, key)
    if EQUIPMENT_OPTIONS[key] then
        toggleSetting(key, macro.slot)
    elseif DEFAULTED[key] then
        setDefaulted(macro, key, not smb.isOptionOn(macro, key))
    else
        toggleSetting(key, macro.name)
    end
    -- turning focus off removes the focus copy, so the modifier picks casting it go too
    if key == "focus" and not smb.isOptionOn(macro, "focus") then
        local set = settings("modifiers")
        for name, spells in pairs(set) do
            for _, mod in ipairs(smb.MODIFIERS) do
                if spells[mod] == macro.name and spells[mod .. "Focus"] then
                    spells[mod], spells[mod .. "Focus"] = nil, nil
                end
            end
            if not next(spells) then set[name] = nil end
        end
    end
end

function smb.toggleOption(macro, key)
    flipOption(macro, key)
    rewrite(macro)
end

-- Flips a macro's "stopCast" or "startAttack" line on one side ("before" or "after") of the cast, moving it
-- to the end of that side's order when it turns on, then rewrites the macro like smb.toggleOption. The focus
-- copy changes too, so the page must be rebuilt after.
function smb.toggleLine(macro, key, side)
    local placement = PLACEMENT[key]
    if side == placement.main then
        flipOption(macro, key)
    else
        toggleSetting(placement.setting, macro.name)
    end
    noteTick(macro, side, key, smb.isLineOn(macro, key, side))
    rewrite(macro)
end

-- Adds an equipment slot to the end of the macro's list and order for a side ("before", the default, or
-- "after") of the cast, or removes it, then rewrites the macro like smb.toggleOption. The focus copy changes
-- too, so the page must be rebuilt after.
function smb.toggleUseSlot(macro, slot, side)
    local slots = {}
    local at = smb.isUsingSlot(macro, slot, side)
    for i, used in ipairs(smb.useItemSlots(macro, side)) do
        if i ~= at then slots[#slots + 1] = used end
    end
    if not at then slots[#slots + 1] = slot end
    settings(USE_SETTING[side or "before"])[macro.name] = #slots > 0 and slots or nil
    noteTick(macro, side or "before", slot, not at)
    rewrite(macro)
end

-- Turns a racial on or off on a side ("before" or "after") of the cast, moving it to the end of that side's
-- order when on, then rewrites the macro like smb.toggleOption. The focus copy changes too, so the page must
-- be rebuilt after.
function smb.toggleRacial(macro, racial, side)
    local set = settings(RACIAL_SETTING[side])
    local racials = set[macro.name] or {}
    racials[racial] = not racials[racial] or nil
    set[macro.name] = next(racials) and racials or nil
    noteTick(macro, side, racial, racials[racial] == true)
    rewrite(macro)
end

-- Sets the spell a macro casts while a modifier key ("shift", "ctrl" or "alt") is held, on the focus target
-- when onFocus, or clears it with nil, then rewrites the macro like smb.toggleOption.
function smb.setModifierSpell(macro, mod, name, onFocus)
    local set = settings("modifiers")
    local spells = set[macro.name] or {}
    spells[mod] = name
    spells[mod .. "Focus"] = name and onFocus or nil
    set[macro.name] = next(spells) and spells or nil
    rewrite(macro)
end

-- Sets the spell a macro casts while in a form (a form's name from the class config), or clears it with nil,
-- then rewrites the macro like smb.toggleOption.
function smb.setFormSpell(macro, form, name)
    local set = settings("forms")
    local spells = set[macro.name] or {}
    spells[form] = name
    set[macro.name] = next(spells) and spells or nil
    rewrite(macro)
end

-- Adds a spell to the end of a macro's sequence, or removes it, then rewrites the macro like
-- smb.toggleOption. The focus copy changes too, so the page must be rebuilt after.
function smb.toggleSequenceSpell(macro, name)
    local spells = {}
    local at = smb.sequencePosition(macro, name)
    for _, picked in ipairs(smb.sequenceSpells(macro)) do
        if picked ~= name then spells[#spells + 1] = picked end
    end
    if not at then spells[#spells + 1] = name end
    settings("sequence")[macro.name] = #spells > 0 and spells or nil
    rewrite(macro)
end

-- Removes every spell from a macro's sequence, then rewrites the macro like smb.toggleOption.
function smb.clearSequence(macro)
    settings("sequence")[macro.name] = nil
    rewrite(macro)
end
