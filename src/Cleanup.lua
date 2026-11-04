local addonName, smb = ...

-- Keeps the addon's general macros from piling up in every character's General tab: while playing, it records
-- the ones on this character's action bars, and a fresh login (not a /reload) that finds the General tab full
-- clears them all and puts this character's back (Macros.lua). Also owns the "macros full" popup.

-- The popup: built on first use, a plain dialog so it can carry a "Don't show this again" box.
local popup

local function hidesPopup()
    return MacroActionBarDB ~= nil and MacroActionBarDB.hideMacrosFullPopup == true
end

local function buildPopup()
    local frame = CreateFrame("Frame", "MacroActionBarMacrosFullPopup", UIParent, "BackdropTemplate")
    frame:SetSize(340, 130)
    frame:SetPoint("TOP", 0, -135)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11},
    })
    tinsert(UISpecialFrames, frame:GetName()) -- Escape closes it

    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, -20)
    frame.text:SetWidth(300)

    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("BOTTOMLEFT", 20, 44)
    check:SetScript("OnClick", function(self)
        MacroActionBarDB = MacroActionBarDB or {}
        MacroActionBarDB.hideMacrosFullPopup = self:GetChecked() or nil
    end)
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText("Don't show this again")
    frame.check = check

    local okay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    okay:SetSize(110, 22)
    okay:SetPoint("BOTTOM", 0, 16)
    okay:SetText(OKAY)
    okay:SetScript("OnClick", function() frame:Hide() end)
    return frame
end

-- Shows the popup telling the player there is no free macro slot, unless they ticked "Don't show this again".
-- Equipment macros only fit in General, so for them only that tab is full.
function smb.showMacrosFull(equipment)
    if hidesPopup() then return end
    popup = popup or buildPopup()
    popup.text:SetText(addonName .. ": " .. (equipment and "the General macro tab is full."
        or "both macro tabs are full.") .. " Delete some macros to make room.")
    popup.check:SetChecked(false)
    popup:Show()
end

local frame = CreateFrame("Frame")

-- Re-records the bars once per burst of changes (placing a macro fires several events).
local recordPending = false
local function scheduleRecord()
    if recordPending then return end
    recordPending = true
    C_Timer.After(0, function()
        recordPending = false
        smb.recordGeneralMacros()
    end)
end

-- Starts keeping the record up to date. Only after the login reset: before it, the bars still hold the
-- last session's macros (or none yet), and recording them would overwrite the record the reset restores from.
local function startRecording()
    frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    frame:RegisterEvent("UPDATE_MACROS")
    scheduleRecord()
end

local RESTORE_DELAY = 1 -- seconds; a just created macro may not be ready to pick up at once
local RESTORE_TRIES = 5

-- Macros can't be deleted, created or placed in combat, so a step that finds combat waits for it to end.
local afterCombat
local function outOfCombat(step)
    if InCombatLockdown() then
        afterCombat = step
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end
    return true
end

-- Puts the recreated macros back on the bars, retrying until every slot holds its macro.
local tries = 0
local function restore()
    if not outOfCombat(restore) then return end
    tries = tries + 1
    if smb.restoreGeneralMacroSlots() or tries >= RESTORE_TRIES then
        MacroActionBarCharDB.restorePending = nil
        startRecording() -- the bars are this session's now
    else
        C_Timer.After(RESTORE_DELAY, restore)
    end
end

local function reset()
    if not outOfCombat(reset) then return end
    smb.resetGeneralMacros()
    C_Timer.After(RESTORE_DELAY, restore)
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" then
        scheduleRecord()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local step = afterCombat
        afterCombat = nil
        if step then step() end
    else
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        -- the flag stays saved until the macros are back on the bars, so a /reload before then (in combat, or
        -- during the retries) runs the cleanup again instead of recording the bars without them. It is not
        -- checked for a full tab again: the cleanup's deletes have already freed slots.
        MacroActionBarCharDB = MacroActionBarCharDB or {}
        if MacroActionBarCharDB.restorePending then
            C_Timer.After(0, reset)
        elseif isInitialLogin and not isReloadingUi then
            C_Timer.After(0, function() -- once the macros and action bars have loaded
                if smb.isGeneralFull() then
                    MacroActionBarCharDB.restorePending = true
                    reset()
                else
                    startRecording() -- room left: nothing to clean
                end
            end)
        else
            startRecording() -- a /reload: nothing to clean, the bars are this session's
        end
    end
end)
