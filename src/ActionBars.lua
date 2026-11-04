local _, smb = ...

-- Right-clicking one of the addon's macros on Blizzard's action bars opens its options menu (the page's
-- right-click menu) instead of casting it, and so does right-clicking a plain spell that has a page macro.
-- Action buttons are secure, so a secure wrap on each one cancels the click; it only does so out of combat,
-- on a button flagged as holding a macro (or a plain spell's macro) with options.

local BARS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local FLAG = "smb-menu"

-- A right-click (down or up, depending on the button's click registration) on a flagged button out of
-- combat is cancelled; the up opens the menu, so a click opens it once.
local PRE_CLICK = [[
    if button == "RightButton" and not PlayerInCombat() and self:GetAttribute("smb-menu") then
        if not down then self:CallMethod("SMBShowMenu") end
        return false
    end
]]

local buttons = {}

local function buttonSlot(button)
    return button.action or (ActionButton_GetPagedID and ActionButton_GetPagedID(button))
        or button:GetAttribute("action")
end

-- The page macro on the button's current slot, or nil. For a plain spell (one placed from Blizzard's
-- spellbook), the spell's own page macro, and true.
local function buttonMacro(button)
    local slot = buttonSlot(button)
    if not slot then return nil end
    local actionType, id, subType = GetActionInfo(slot)
    if actionType == "spell" and id then
        local spell = C_Spell.GetSpellName(id)
        return spell and smb.macroByName[spell], true
    end
    if actionType ~= "macro" then return nil end
    local name = GetActionText(slot) or (subType ~= "spell" and GetMacroInfo(id))
    return name and smb.macroByMacroName[name], false
end

-- Before the first change in a plain spell button's menu: puts the spell's macro on the button in the
-- spell's place, or a per-button copy of it when the macro is already on another button, so the change
-- applies to this button alone. Returns that macro, or nil when it couldn't be placed (smb.pickupMacro said
-- why), which skips the change.
local function placeForSpell(macro, slot)
    if InCombatLockdown() then return nil end
    local copy = smb.macroSlots()[macro.macroName] and smb.newButtonCopy(macro)
    local target = copy or macro
    if smb.placeMacro(target, slot) then return target end
    if copy then
        smb.deleteButtonCopy(copy)
        smb.collectMacros()
    end
end

local function showMenu(button)
    if InCombatLockdown() then return end
    smb.collectMacros() -- the page may never have been opened, or its spells may have changed
    local macro, plainSpell = buttonMacro(button)
    if not macro then return end
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    local slot = buttonSlot(button)
    local prepare = plainSpell and function() return placeForSpell(macro, slot) end or nil
    smb.showMacroMenu(button, macro, smb.refreshPage, slot, prepare)
end

-- Flags each wrapped button whose slot holds a page macro with options. Attributes on secure buttons can't
-- change in combat; the wrap ignores the flag then, and leaving combat updates it.
local scheduleScan

function smb.updateBarMenus()
    if smb.hasRemovedCopies() and scheduleScan then scheduleScan() end
    if InCombatLockdown() or #buttons == 0 then return end
    if #smb.macros == 0 then smb.collectMacros() end -- calls back here
    for _, button in ipairs(buttons) do
        local macro = buttonMacro(button)
        local flag = macro and smb.hasOptions(macro) or nil
        if button:GetAttribute(FLAG) ~= flag then button:SetAttribute(FLAG, flag) end
    end
end

local function wrapButtons()
    local header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    for _, bar in ipairs(BARS) do
        for i = 1, 12 do
            local button = _G[bar .. i]
            if button then
                button.SMBShowMenu = showMenu
                SecureHandlerWrapScript(button, "OnClick", header, PRE_CLICK)
                buttons[#buttons + 1] = button
            end
        end
    end
end

local pending = false

-- Slot and page events come in bursts, so the flags update once on the next frame.
local function scheduleUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        smb.updateBarMenus()
    end)
end

-- Every action button gets its own macro: when one of the page's spell macros is on several slots, each slot
-- but one gets a per-button copy of it (see smb.newButtonCopy), so the buttons can be set up differently. A
-- per-button copy on no slot is deleted, and a copy turned off is taken off its slots for its spell's own macro.
-- Custom and equipment macros can stay on several slots: they have no per-button settings.
local SCAN_RETRY = 0.5 -- seconds to wait while something is on the cursor, e.g. a button being dragged
local LOGIN_DELAY = 2 -- seconds after entering the world, so the bars have loaded and Cleanup.lua has run

local scanReady = false
local scanPending = false
local lastSlots = {} -- {[macro name] = {[slot] = true}} from the previous scan, to tell which slot is new
local fullAt -- the macro count when a per-button copy found no free macro slot, so it isn't retried until it changes

local function macroCount()
    local account, character = GetNumMacros()
    return account + character
end

-- Puts the spell's own macro back on the slots of the copies turned off since the last scan, and deletes them.
local function replaceRemovedCopies()
    local removed = smb.takeRemovedCopies()
    for _, entry in ipairs(removed) do
        local spellMacro = smb.macroByName[entry.spell]
        for _, slot in ipairs(smb.macroSlots()[entry.macroName] or {}) do
            if not (spellMacro and smb.placeMacro(spellMacro, slot)) then smb.clearSlot(slot) end
        end
        if entry.copy.buttonCopy then
            smb.deleteButtonCopy(entry.copy)
        else
            smb.deleteMacroNamed(entry.macroName)
        end
    end
    return #removed > 0
end

-- Deletes this character's per-button copies that are on no slot.
local function deleteUnplacedCopies(slots)
    local changed = false
    for _, macro in ipairs(smb.macros) do
        if macro.buttonCopy and not slots[macro.macroName] then
            smb.deleteButtonCopy(macro)
            changed = true
        end
    end
    return changed
end

-- Gives each slot but one of a spell macro on several slots a per-button copy. The slot that held it at the
-- last scan keeps it, else the lowest.
local function splitSharedButtons(slots)
    local changed = false
    for name, list in pairs(slots) do
        local macro = smb.macroByMacroName[name]
        if fullAt == macroCount() then break end
        if macro and #list > 1 and not macro.custom and not macro.equipment then
            local keep = list[1]
            for _, slot in ipairs(list) do
                if lastSlots[name] and lastSlots[name][slot] then
                    keep = slot
                    break
                end
            end
            for _, slot in ipairs(list) do
                if slot ~= keep and fullAt ~= macroCount() then
                    local copy = smb.newButtonCopy(macro)
                    if copy and smb.placeMacro(copy, slot) then
                        changed = true
                    else
                        if copy then
                            smb.deleteButtonCopy(copy)
                            smb.collectMacros()
                        end
                        fullAt = macroCount() -- smb.pickupMacro said why
                    end
                end
            end
        end
    end
    return changed
end

local function scan()
    if not scanReady or InCombatLockdown() then return end -- leaving combat scans again
    if GetCursorInfo() or (MacroSpellbookCharDB and MacroSpellbookCharDB.restorePending) then
        C_Timer.After(SCAN_RETRY, scheduleScan)
        return
    end
    if #smb.macros == 0 then smb.collectMacros() end
    local changed = replaceRemovedCopies()
    if changed then smb.collectMacros() end
    local slots, any = smb.macroSlots()
    if not any then return end -- the bars haven't loaded
    if deleteUnplacedCopies(slots) then
        changed = true
        smb.collectMacros()
    end
    if fullAt and fullAt ~= macroCount() then fullAt = nil end
    changed = splitSharedButtons(slots) or changed
    lastSlots = {}
    for name, list in pairs(smb.macroSlots()) do
        lastSlots[name] = {}
        for _, slot in ipairs(list) do lastSlots[name][slot] = true end
    end
    if changed then smb.refreshPage() end
end

function scheduleScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0, function()
        scanPending = false
        scan()
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(LOGIN_DELAY, function()
            scanReady = true
            scheduleScan()
        end)
        return
    end
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_REGEN_ENABLED" then scheduleScan() end
    -- wrapping needs no combat lockdown, which a /reload in combat has; then it waits for combat to end
    if #buttons == 0 and InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if #buttons == 0 then
        wrapButtons()
        self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
        self:RegisterEvent("UPDATE_MACROS")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    scheduleUpdate()
end)
