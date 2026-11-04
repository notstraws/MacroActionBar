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

-- The menu's changes apply to this button alone when other buttons hold the same macro, and a plain spell's
-- first change puts its macro on the button in the spell's place (see smb.editMacro).
local function showMenu(button)
    if InCombatLockdown() then return end
    smb.collectMacros() -- the page may never have been opened, or its spells may have changed
    local macro, plainSpell = buttonMacro(button)
    if not macro then return end
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    smb.showMacroMenu(button, macro, smb.refreshPage, buttonSlot(button), plainSpell)
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

-- A copy turned off (enemy player, nearest or combat rank) is taken off its slots for its spell's own
-- macro, and deleted with its variants. A macro on several slots stays shared until one button's menu changes
-- it (see smb.editMacro), and a variant lasts until it is deleted or merged, even off the bars. Slots left
-- holding a deleted macro (any macro, deleted anywhere) are emptied.
local SCAN_RETRY = 0.5 -- seconds to wait while something is on the cursor, e.g. a button being dragged
local LOGIN_DELAY = 2 -- seconds after entering the world, so the bars have loaded and Cleanup.lua has run

local scanReady = false
local scanPending = false

-- Puts the spell's own macro back on the slots of the copies turned off since the last scan, and deletes them.
local function replaceRemovedCopies()
    local removed = smb.takeRemovedCopies()
    for _, entry in ipairs(removed) do
        local spellMacro = smb.macroByName[entry.spell]
        for _, slot in ipairs(smb.macroSlots()[entry.macroName] or {}) do
            if not (spellMacro and smb.placeMacro(spellMacro, slot)) then smb.clearSlot(slot) end
        end
        if entry.copy.variant then
            smb.deleteVariant(entry.copy)
        else
            smb.deleteMacroNamed(entry.macroName)
        end
    end
    return #removed > 0
end

local function scan()
    if not scanReady or InCombatLockdown() then return end -- leaving combat scans again
    if GetCursorInfo() or (MacroSpellbookCharDB and MacroSpellbookCharDB.restorePending) then
        C_Timer.After(SCAN_RETRY, scheduleScan)
        return
    end
    if #smb.macros == 0 then smb.collectMacros() end
    local replaced = replaceRemovedCopies()
    if smb.clearDeletedMacroSlots() or replaced then smb.refreshPage() end
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
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" or event == "PLAYER_REGEN_ENABLED" then
        scheduleScan()
    end
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
