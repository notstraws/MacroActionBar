local addonName, smb = ...

-- Adds a "Macro Spellbook" tab to the spellbook. LibSpellBookTabs owns the tab, its placement and
-- the parchment page; this file only draws smb.macros (built by Macros.lua) onto the page.

local ICON_MACRO = "Interface\\MacroFrame\\MacroFrame-Icon" -- the "M" key shown on Blizzard's macro window
-- the icon is a round portrait; crop to the square inside its border so the tab shows just the "M"
local ICON_MACRO_COORDS = {0.15, 0.85, 0.15, 0.85}

local function hideTooltip(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local setMacro, refresh

local MODIFIER_LABELS = {shift = "Shift", ctrl = "Ctrl", alt = "Alt"}

-- A spam option's menu label and button subtext, by the kind of condition it adds (see spamCondition in
-- Macros.lua).
local SPAM_LABELS = {
    nostealth = {"Stay In Stealth On Recast", "Stay stealthed"},
    noform = {"Stay In Form On Recast", "Stay in form"},
    nochanneling = {"Don't Recast While Channeling", "No recast"},
}

local function spamLabels(macro)
    return SPAM_LABELS[macro.spam:match("^[^:]+")]
end

-- A section's name in the right-click submenus: "Cat Spells" for one named after a form (see smb.formNames),
-- so it isn't mistaken for the form itself.
local function sectionLabel(name)
    return tContains(smb.formNames(), name) and name .. " Spells" or name
end

-- A submenu's sections ({name = ...} tables, in page order) in the order it lists them: the one named first
-- (optional) at the top, then the rest in page order, then the menuLast ones (see smb.menuLast).
local function menuOrder(sections, first)
    local ordered, last = {}, {}
    for _, section in ipairs(sections) do
        if section.name == first then
            table.insert(ordered, 1, section)
        elseif smb.menuLast(section.name) then
            last[#last + 1] = section
        else
            ordered[#ordered + 1] = section
        end
    end
    for _, section in ipairs(last) do ordered[#ordered + 1] = section end
    return ordered
end

-- Every spell macro has a menu; custom macros don't. A focus copy's menu only removes it; a nearest copy's
-- also offers its own sequence.
local function showMacroMenu(button)
    local macro = button.macro
    if not smb.hasOptions(macro) then return end
    MenuUtil.CreateContextMenu(button, function(_, rootDescription)
        -- an equipment macro's menu is titled by its one section instead
        if not macro.equipment then rootDescription:CreateTitle(macro.name) end
        local function addOption(label, key)
            return rootDescription:CreateCheckbox(label,
                function() return smb.isOptionOn(macro, key) end,
                function()
                    smb.toggleOption(macro, key)
                    -- adds, removes or rewrites the focus copy, and rewrites the macros casting this spell
                    -- with a modifier key
                    refresh(button:GetParent())
                end)
        end
        -- the Sequence submenu: the spells cast after the macro's own, ticked in order: the ones
        -- smb.canSequence allows, under their section's title
        local function addSequenceMenu()
            if not smb.offersSequence(macro) then return end
            local function changed()
                refresh(button:GetParent()) -- rewrites the macro, its focus copy and its subtext
            end
            local picked = smb.sequenceSpells(macro)
            local submenu = rootDescription:CreateButton("Sequence: "
                .. (#picked > 0 and (#picked + 1) .. " spells" or "None"))
            submenu:CreateTitle("Cast In Sequence (resets after 2 sec)")
            submenu:CreateButton("Clear", function()
                smb.clearSequence(macro)
                changed()
            end)
            local function addPick(name, suffix)
                local pos = smb.sequencePosition(macro, name)
                submenu:CreateCheckbox(name .. (pos and " (" .. pos .. ")" or "") .. (suffix or ""),
                    function() return smb.sequencePosition(macro, name) ~= nil end,
                    function()
                        smb.toggleSequenceSpell(macro, name)
                        changed()
                    end)
            end
            -- the menuLast sections (see smb.menuLast) go after the rest
            local listed, section = {}, nil
            for _, lastPass in ipairs({false, true}) do
                for _, other in ipairs(smb.macros) do
                    if smb.macroByName[other.name] == other and smb.canSequence(macro, other)
                        and smb.menuLast(other.category) == lastPass then
                        if other.category ~= section then
                            section = other.category
                            submenu:CreateTitle(sectionLabel(section))
                        end
                        listed[other.name] = true
                        addPick(other.name)
                    end
                end
            end
            -- a pick no longer learned (e.g. after a respec) or moved out of a sequence section stays listed,
            -- so it can be unticked
            for _, name in ipairs(picked) do
                if not listed[name] then addPick(name, " (unavailable)") end
            end
        end
        if macro.focus then
            addOption("Cast On Focus", "focus")
            return
        end
        -- a nearest copy has its own sequence (see sequenceKey in Macros.lua)
        if macro.nearest then
            addOption("Cast On Nearest Player", "nearest")
            addSequenceMenu()
            return
        end
        if macro.equipment then
            rootDescription:CreateTitle("Before Using")
            addOption("Stop Attacking", "equipStopAttack")
            addOption("Stop Casting", "equipStopCast")
            return
        end
        if macro.target then addOption("Cast On Mouseover", "mouseover") end
        if macro.cursor then addOption("Cast At Cursor", "cursor") end
        if macro.petAbility then addOption("Cast " .. macro.petAbility .. " If Summoned", "pet") end
        if macro.raidRank1 then
            -- a sequence can't downrank (see castBody in Macros.lua)
            addOption("Downrank In Raids", "raidRank1"):SetEnabled(function() return not smb.hasSequenceOn(macro) end)
        end
        if macro.spam then addOption(spamLabels(macro)[1], "spam") end
        if macro.stances then addOption("Switch To " .. macro.stances[1], "stance") end
        if macro.target then addOption("Cast On Focus", "focus") end
        if macro.buff then addOption("Cast On Nearest Player", "nearest") end
        if smb.offersPetAttack(macro) then addOption("Enable Pet Attack", "petAttack") end
        -- one submenu per side of the cast: /startattack, the race's racials and the equipped on-use items,
        -- each on either side, both or neither, and /stopcasting before only
        local function addSide(side)
            -- each line as {label, id, isOn, toggle}, the id naming it for smb.sidePosition
            local lines = {}
            local function addLine(key, label)
                lines[#lines + 1] = {label, key,
                    function() return smb.isLineOn(macro, key, side) end,
                    function() smb.toggleLine(macro, key, side) end}
            end
            if smb.offersStartAttack(macro) then addLine("startAttack", "Start Attack") end
            if side == "before" and smb.offersStopCast(macro) then addLine("stopCast", "Stop Casting") end
            if smb.offersUseItems(macro) then
                for _, racial in ipairs(smb.offeredRacials()) do
                    lines[#lines + 1] = {"Racial: " .. racial, racial,
                        function() return smb.isRacialOn(macro, racial, side) end,
                        function() smb.toggleRacial(macro, racial, side) end}
                end
            end
            -- a ticked line's label ends with its place in the macro, in the order the player ticked them
            local function placed(label, id)
                local at = smb.sidePosition(macro, id, side)
                return label .. (at and " (" .. at .. ")" or "")
            end
            -- rewrites the label on every refresh, so its place updates while the menu stays open
            local function livePlaced(checkbox, label, id)
                checkbox:AddInitializer(function(frame)
                    frame.fontString:SetText(placed(label, id))
                end)
            end
            -- the equipped on-use items, plus any slot already ticked so it can be unticked after a gear swap
            local slots, listed = {}, {}
            if smb.offersUseItems(macro) then
                for _, usable in ipairs(smb.usableSlots()) do
                    slots[#slots + 1], listed[usable.slot] = usable.slot, true
                end
                for _, slot in ipairs(smb.useItemSlots(macro, side)) do
                    if not listed[slot] then slots[#slots + 1] = slot end
                end
            end
            if #lines == 0 and #slots == 0 then return end
            local title = side == "before" and "Before Casting" or "After Casting"
            local submenu = rootDescription:CreateButton(title)
            submenu:CreateTitle(title)
            for _, line in ipairs(lines) do
                local label, id, isOn, toggle = line[1], line[2], line[3], line[4]
                livePlaced(submenu:CreateCheckbox(placed(label, id), isOn, function()
                    toggle()
                    refresh(button:GetParent()) -- rewrites the focus copy too
                    return MenuResponse.Refresh -- renumbers the other labels
                end), label, id)
            end
            if #lines > 0 and #slots > 0 then submenu:CreateDivider() end
            for _, slot in ipairs(slots) do
                local label = smb.slotLabel(slot)
                livePlaced(submenu:CreateCheckbox(placed(label, slot),
                    function() return smb.isUsingSlot(macro, slot, side) ~= nil end,
                    function()
                        smb.toggleUseSlot(macro, slot, side)
                        refresh(button:GetParent()) -- rewrites the focus copy too
                        return MenuResponse.Refresh -- renumbers the other labels
                    end), label, slot)
            end
        end
        addSide("before")
        addSide("after")
        addSequenceMenu()
        if not smb.offersModifiers(macro) then return end
        -- one submenu per modifier key, picking the spell cast while it is held from the page's learned
        -- spells, grouped by section, as {name, onFocus}. A spell with a focus copy also offers casting it on
        -- the focus target, the macro's own spell included
        local sections = {}
        for _, other in ipairs(smb.macros) do
            local isSpell = smb.macroByName[other.name] == other
            if not other.unlearned and ((isSpell and other.name ~= macro.name) or other.focus) then
                local section = sections[#sections]
                if not section or section.name ~= other.category then
                    section = {name = other.category}
                    sections[#sections + 1] = section
                end
                section[#section + 1] = {name = other.name, onFocus = other.focus == true}
            end
        end
        local function pickLabel(name, onFocus)
            return name .. (onFocus and " (Focus)" or "")
        end
        rootDescription:CreateDivider()
        for _, mod in ipairs(smb.MODIFIERS) do
            local label = MODIFIER_LABELS[mod]
            local function isPicked(name, onFocus)
                local pickedName, pickedFocus = smb.modifierSpell(macro, mod)
                return pickedName == name and pickedFocus == onFocus
            end
            local function pick(name, onFocus)
                smb.setModifierSpell(macro, mod, name, onFocus)
                refresh(button:GetParent()) -- rewrites the macro and its subtext
            end
            local current, currentFocus = smb.modifierSpell(macro, mod)
            local submenu = rootDescription:CreateButton(label .. ": "
                .. (current and pickLabel(current, currentFocus) or "None"))
            submenu:CreateTitle("Cast While " .. label .. " Is Held")
            submenu:CreateRadio("None", function() return smb.modifierSpell(macro, mod) == nil end,
                function() pick(nil) end)
            local listed = false
            for _, section in ipairs(menuOrder(sections)) do
                local sectionMenu = submenu:CreateButton(sectionLabel(section.name))
                for _, entry in ipairs(section) do
                    local name, onFocus = entry.name, entry.onFocus
                    listed = listed or (name == current and onFocus == currentFocus)
                    sectionMenu:CreateRadio(pickLabel(name, onFocus), function() return isPicked(name, onFocus) end,
                        function() pick(name, onFocus) end)
                end
            end
            -- a pick no longer learned (e.g. after a respec), or a focus pick without a focus copy (only
            -- from old saved data), stays listed, so the player sees why it does nothing
            if current and not listed then
                local why = smb.macroByName[current] and not smb.macroByName[current].unlearned and "no focus macro"
                    or "not learned"
                submenu:CreateRadio(pickLabel(current, currentFocus) .. " (" .. why .. ")",
                    function() return isPicked(current, currentFocus) end,
                    function() pick(current, currentFocus) end)
            end
        end
        if not smb.offersForms(macro) then return end
        -- one submenu per form, picking the spell cast while in it from the same sections, without the
        -- focus picks or the sections of other forms (see smb.formAllows)
        rootDescription:CreateDivider()
        for _, form in ipairs(smb.formNames()) do
            local function pick(name)
                smb.setFormSpell(macro, form, name)
                refresh(button:GetParent()) -- rewrites the macro and its subtext
            end
            local current = smb.formSpell(macro, form)
            local submenu = rootDescription:CreateButton(form .. ": " .. (current or "None"))
            submenu:CreateTitle("Cast In " .. form .. " Form")
            submenu:CreateRadio("None", function() return smb.formSpell(macro, form) == nil end,
                function() pick(nil) end)
            local listed = false
            -- the form's own section first (see smb.formSection)
            for _, section in ipairs(menuOrder(sections, smb.formSection(form))) do
                local sectionMenu
                for _, entry in ipairs(section) do
                    if not entry.onFocus and entry.name ~= macro.name
                        and smb.formAllows(form, smb.macroByName[entry.name]) then
                        local name = entry.name
                        listed = listed or name == current
                        sectionMenu = sectionMenu or submenu:CreateButton(sectionLabel(section.name))
                        sectionMenu:CreateRadio(name, function() return smb.formSpell(macro, form) == name end,
                            function() pick(name) end)
                    end
                end
            end
            -- a pick no longer learned (e.g. after a respec), or from another form's section, stays listed, so
            -- the player sees why it does nothing
            if current and not listed then
                local other = smb.macroByName[current]
                local why = other and not other.unlearned and "other form" or "not learned"
                submenu:CreateRadio(current .. " (" .. why .. ")",
                    function() return smb.formSpell(macro, form) == current end,
                    function() pick(current) end)
            end
        end
    end)
end

-- Native spellbook geometry (Camelot's Blizzard_SpellBookTemplates.xml): each page's spell view is 680
-- wide, 95 below the book's top, 85 from its left (left page) or 50 from its right (right page). Our page
-- frame starts 60 below the book's top.
local VIEW_WIDTH, VIEW_TOP, VIEW_LEFT, VIEW_RIGHT, VIEW_BOTTOM = 680, -35, 85, 50, 75
local COLUMNS, CELL_HEIGHT, CATEGORY_GAP = 3, 52, 12
local FOOTER_BOTTOM = 46 -- the footer's bottom edge, roughly level with the paging arrows (40 up)
-- the book can be narrower than the native views: a minimized book's single page keeps this much off each
-- edge, and an open book's pages keep this much off the spine
local MIN_MARGIN, SPINE_GAP = 30, 30
local ICON_SIZE = 36

-- parchment ink, matching the native spell names and subtext
local INK_COLOR = {0.18, 0.106, 0.059}
local MOUSEOVER_COLOR = {0.10, 0.38, 0.05}

-- The native spell item's atlases and layout (Camelot's SpellBookItemTemplate, read in game). The item is
-- 217x60 with a 40x40 icon button at its left; our button is the item, so the native button's anchors
-- become offsets from the 36x36 icon, which sits 2 inside it. Each falls back to an old file texture,
-- sized from the icon, if this build lacks the atlas.
local ITEM_WIDTH = 217
local ATLAS_FRAME = "spellbook-item-iconframe"
local ATLAS_FRAME_INACTIVE = "spellbook-item-iconframe-inactive"
local ATLAS_FRAME_HOVER = "spellbook-item-iconframe-hover"
local ATLAS_GLOW = "spellbook-item-unassigned-glow"
local ATLAS_MASK = "spellbook-item-spellicon-mask"

local function hasAtlas(atlas)
    return C_Texture.GetAtlasInfo(atlas) ~= nil
end

-- Stretches texture over the icon, grown by the given insets (left, top, right, bottom).
local function setAroundIcon(texture, icon, left, top, right, bottom)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", icon, "TOPLEFT", -left, top)
    texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", right, -bottom)
end

-- Returns true when the atlas was used.
local function setAtlasOr(texture, atlas, file, scale, icon)
    if hasAtlas(atlas) then
        texture:SetAtlas(atlas, false)
        return true
    end
    if file then
        texture:SetTexture(file)
        texture:SetSize(ICON_SIZE * scale, ICON_SIZE * scale)
        texture:SetPoint("CENTER", icon)
    end
    return false
end

-- Cells are reused across refreshes; setMacro points one at a macro.
local function createMacroButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(ITEM_WIDTH, ICON_SIZE + 4)
    button.icon = button:CreateTexture(nil, "ARTWORK", nil, -1)
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.icon:SetPoint("LEFT", 2, 0)
    if hasAtlas(ATLAS_MASK) then
        local mask = button:CreateMaskTexture()
        mask:SetAtlas(ATLAS_MASK, false)
        mask:SetAllPoints(button.icon)
        button.icon:AddMaskTexture(mask)
    end
    -- the frame's curl hangs off the icon's bottom left
    button.border = button:CreateTexture(nil, "OVERLAY", nil, 1)
    if setAtlasOr(button.border, ATLAS_FRAME, "Interface\\Buttons\\UI-Quickslot2", 1.6, button.icon) then
        setAroundIcon(button.border, button.icon, 13, 3, 3, 9)
    end
    -- glow on a macro that isn't on the action bars yet, like the native page's unassigned spells
    button.glow = button:CreateTexture(nil, "OVERLAY", nil, 5)
    if setAtlasOr(button.glow, ATLAS_GLOW, "Interface\\Buttons\\UI-ActionButton-Border", 1.8, button.icon) then
        setAroundIcon(button.glow, button.icon, 6, 5, 5, 5)
    else
        button.glow:SetBlendMode("ADD")
        button.glow:SetVertexColor(1, 0.82, 0) -- the texture is white; Blizzard tints it per use
    end
    button.glow:Hide()
    -- fades in and out like the spellbook's glow on new spells; updateGlow starts it
    button.pulse = button.glow:CreateAnimationGroup()
    button.pulse:SetLooping("BOUNCE")
    local fade = button.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.2)
    fade:SetDuration(0.5)
    fade:SetSmoothing("IN_OUT")
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    if hasAtlas(ATLAS_FRAME_HOVER) then
        highlight:SetAtlas(ATLAS_FRAME_HOVER, false)
    else
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
    end
    setAroundIcon(highlight, button.icon, 2, 2, 2, 2)

    local text = CreateFrame("Frame", nil, button)
    text:SetHeight(29.5)
    text:SetPoint("LEFT", 50, -1)
    text:SetPoint("RIGHT", 0, -1)
    button.name = text:CreateFontString(nil, "ARTWORK", "SystemFont_Large")
    button.name:SetPoint("TOPLEFT")
    button.name:SetPoint("TOPRIGHT")
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.name:SetTextColor(unpack(INK_COLOR))
    button.subText = text:CreateFontString(nil, "ARTWORK", "SystemFont_Med1")
    button.subText:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -2)
    button.subText:SetPoint("TOPRIGHT", button.name, "BOTTOMRIGHT", 0, -2)
    button.subText:SetJustifyH("LEFT")
    button.subText:SetWordWrap(false)

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self) smb.pickupMacro(self.macro) end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            showMacroMenu(self)
        else
            smb.pickupMacro(self.macro)
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.macro.name)
        GameTooltip:AddLine(self.macro.body, 1, 1, 1, true)
        if self.macro.tooLong then
            GameTooltip:AddLine("Too long: " .. #self.macro.body .. "/255 characters. Turn off some options.",
                1, 0.1, 0.1, true)
        end
        if self.macro.unlearned then
            GameTooltip:AddLine("Not learned yet.", 1, 0.1, 0.1, true)
        elseif self.glow:IsShown() then
            GameTooltip:AddLine("Not on your action bars.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:AddLine("Click or drag to place on an action bar.", 0.5, 0.5, 0.5, true)
        if smb.hasOptions(self.macro) then
            GameTooltip:AddLine("Right-click for options.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnHide", hideTooltip)
    return button
end

-- Shows the glow when the button's macro is learned but not on the bars (from smb.scanActionBars).
-- Custom macros and those in a noGlow category never glow.
local function updateGlow(button, bars)
    local macro = button.macro
    local shown = not macro.custom and not macro.noGlow and not macro.unlearned
        and not smb.isOnActionBars(macro, bars)
    button.glow:SetShown(shown)
    if not shown then
        button.pulse:Stop()
    elseif not button.pulse:IsPlaying() then
        button.pulse:Play()
    end
end

-- bars is a smb.scanActionBars() result, scanned here when nil.
function setMacro(button, macro, bars)
    button.macro = macro
    updateGlow(button, bars or smb.scanActionBars())
    button.icon:SetTexture(macro.icon)
    button.icon:SetDesaturated(macro.unlearned == true)
    local frameAtlas = macro.unlearned and ATLAS_FRAME_INACTIVE or ATLAS_FRAME
    if hasAtlas(frameAtlas) then button.border:SetAtlas(frameAtlas, false) end
    button.name:SetText(macro.name)
    if macro.custom then
        button.subText:SetText("Custom")
        button.subText:SetTextColor(unpack(INK_COLOR))
    elseif macro.equipment then
        button.subText:SetText(macro.slotLabel)
        button.subText:SetTextColor(unpack(INK_COLOR))
    elseif macro.focus then
        button.subText:SetText("Focus")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif macro.nearest then
        button.subText:SetText("Nearest")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "pet") then
        button.subText:SetText("Pet")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "cursor") then
        button.subText:SetText("Cursor")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "mouseover") then
        button.subText:SetText("Mouseover")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "stance") then
        button.subText:SetText("Stance")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.hasSequenceOn(macro) then
        button.subText:SetText("Sequence")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.hasFormOn(macro) then
        button.subText:SetText("Forms")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.hasModifierOn(macro) then
        button.subText:SetText("Modifiers")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.useItemSlots(macro, "before")[1] or smb.useItemSlots(macro, "after")[1] then
        button.subText:SetText("Use items")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.hasRacialOn(macro) then
        button.subText:SetText("Racial")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "petAttack") then
        button.subText:SetText("Pet attack")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "raidRank1") then
        button.subText:SetText("Raid R1")
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    elseif smb.isOptionOn(macro, "spam") then
        button.subText:SetText(spamLabels(macro)[2])
        button.subText:SetTextColor(unpack(MOUSEOVER_COLOR))
    else
        button.subText:SetText(smb.hasCastOptions(macro) and "Macro" or "Self")
        button.subText:SetTextColor(unpack(INK_COLOR))
    end
end

-- The same category bar the native page draws over each skill line.
local function createHeader(parent)
    return CreateFrame("Frame", nil, parent, "SpellBookHeaderTemplate")
end

local function setHeader(header, text, width)
    header:SetWidth(width)
    header.Text:SetText(text)
    header.Backplate:SetWidth(math.min(width + 85, math.max(416, header.Text:GetStringWidth() * 2.5)))
end

-- Acquire hands out pooled frames in order; ReleaseAll hides the ones from the last layout.
local function framePool(create)
    local pool = {used = 0}
    function pool:Acquire()
        self.used = self.used + 1
        local frame = self[self.used] or create()
        self[self.used] = frame
        frame:ClearAllPoints()
        frame:Show()
        return frame
    end
    function pool:ReleaseAll()
        for i = 1, #self do self[i]:Hide() end
        self.used = 0
    end
    return pool
end

-- A macro matches the search when its name or section contains the (lowercased) filter; no filter matches all.
local function matches(macro, filter)
    if not filter or filter == "" then return true end
    return macro.name:lower():find(filter, 1, true) ~= nil
        or (macro.category or ""):lower():find(filter, 1, true) ~= nil
end

-- Splits the macros matching filter into page halves of {header = text, y} and {macro, column, y} entries. A
-- category flows top to bottom and repeats its header when it carries over to the next half. Returns no
-- halves when nothing matches.
local function paginate(height, headerHeight, columns, filter)
    local shown = {}
    for _, macro in ipairs(smb.macros) do
        if matches(macro, filter) then shown[#shown + 1] = macro end
    end
    if #shown == 0 then return {} end
    local halves, half, y = {}, nil, 0
    local function newHalf()
        half, y = {}, 0
        halves[#halves + 1] = half
    end
    local function addHeader(text)
        half[#half + 1] = {header = text, y = y}
        y = y + headerHeight
    end
    newHalf()
    local category, column
    for _, macro in ipairs(shown) do
        if macro.category ~= category then
            category, column = macro.category, 0
            if y > 0 then
                y = y + CELL_HEIGHT + CATEGORY_GAP -- close the previous category's last row
                if y + headerHeight + CELL_HEIGHT > height then newHalf() end
            end
            addHeader(category)
        elseif column == columns then
            column = 0
            y = y + CELL_HEIGHT
            if y + CELL_HEIGHT > height then
                newHalf()
                addHeader(category)
            end
        end
        half[#half + 1] = {macro = macro, column = column, y = y}
        column = column + 1
    end
    return halves
end

-- Draws the current spread: two pages side by side, or one when the book is minimized.
local function layout(page)
    page.headers:ReleaseAll()
    page.buttons:ReleaseAll()
    local controls = page.pagingControls
    local width, height = page:GetWidth(), page:GetHeight()
    -- the book's own minimize/maximize state, so a two-page book narrower than two native views still
    -- gets both pages; the width check is a fallback for a build without the flag
    local minimized = PlayerSpellsFrame.SpellBookFrame.isMinimized
    if minimized == nil then minimized = width < 2 * VIEW_WIDTH end
    local spread = minimized and 1 or 2
    -- a minimized book shows one page, centred; an open one uses the native left and right pages. Each is
    -- narrowed to fit, with fewer columns when it's too narrow for three
    local viewWidth = spread == 2 and math.min(VIEW_WIDTH, width / 2 - VIEW_LEFT - SPINE_GAP)
        or math.min(VIEW_WIDTH, width - 2 * MIN_MARGIN)
    local columns = math.max(1, math.min(COLUMNS, math.floor(viewWidth / ITEM_WIDTH)))
    local cellWidth = viewWidth / columns
    local origins = spread == 2 and {VIEW_LEFT, width - VIEW_RIGHT - viewWidth} or {(width - viewWidth) / 2}
    page.footer:ClearAllPoints()
    page.footer:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", origins[1] + 8, FOOTER_BOTTOM)
    -- stops short of the paging arrows, wrapping upward when the page is narrow
    page.footer:SetWidth(spread == 2 and viewWidth - 16 or viewWidth - 180)
    local headerHeight = math.max(page.headers:Acquire():GetHeight(), 30) + 8
    page.headers:ReleaseAll()

    local halves = paginate(height + VIEW_TOP - VIEW_BOTTOM, headerHeight, columns, page.filter)
    if #halves == 0 then
        local header = page.headers:Acquire()
        header:SetPoint("TOPLEFT", page, "TOPLEFT", origins[1], VIEW_TOP)
        setHeader(header, "Macro Spellbook", viewWidth)
        page.empty:SetText(#smb.macros == 0 and "No macros found."
            or "No macros match \"" .. page.search:GetText() .. "\".")
        page.empty:ClearAllPoints()
        page.empty:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -12)
        page.empty:Show()
        controls:Hide()
        return
    end
    page.empty:Hide()
    local maxPages = math.ceil(#halves / spread)
    page.paging = true
    controls:SetMaxPages(maxPages)
    page.paging = false
    controls:SetShown(maxPages > 1)
    local current = math.min(controls:GetCurrentPage(), maxPages)
    local bars = smb.scanActionBars()
    for side = 1, spread do
        local x = origins[side]
        for _, entry in ipairs(halves[(current - 1) * spread + side] or {}) do
            if entry.header then
                local header = page.headers:Acquire()
                header:SetPoint("TOPLEFT", page, "TOPLEFT", x, VIEW_TOP - entry.y)
                setHeader(header, entry.header, viewWidth)
            else
                local button = page.buttons:Acquire()
                button:SetPoint("TOPLEFT", page, "TOPLEFT", x + entry.column * cellWidth + 8, VIEW_TOP - entry.y - 4)
                setMacro(button, entry.macro, bars)
            end
        end
    end
end

-- Rebuilds the list from the spellbook and the class config, updates changed macros, then redraws.
function refresh(page)
    smb.collectMacros()
    smb.syncAllMacros()
    layout(page)
end

local function buildPage(page)
    page.headers = framePool(function() return createHeader(page) end)
    page.buttons = framePool(function() return createMacroButton(page) end)

    page.empty = page:CreateFontString(nil, "OVERLAY", "SystemFont_Med3")
    page.empty:SetTextColor(unpack(INK_COLOR))

    -- usage hint along the bottom of the left page, level with the paging arrows; layout places it
    page.footer = page:CreateFontString(nil, "OVERLAY", "SystemFont_Med1")
    page.footer:SetTextColor(unpack(INK_COLOR))
    page.footer:SetJustifyH("LEFT")
    page.footer:SetText("Right click macro to edit; Change global settings via dropdown next to the search;")

    -- the native settings cog, laid over the native one in the toolbar; its menu
    -- holds the page-wide settings
    local options = CreateFrame("DropdownButton", nil, page.header, "SpellBookSettingsDropdownTemplate")
    page.options = options
    options:ClearAllPoints()
    -- pinned to the native cog so it follows the native toolbar's layout; the offset is a fallback
    local native = PlayerSpellsFrame.SpellBookFrame.SettingsDropdown
    if native then
        options:SetAllPoints(native)
    else
        options:SetPoint("TOPRIGHT", page.header, "TOPRIGHT", -30, -27)
    end
    options:SetupMenu(function(_, rootDescription)
        rootDescription:CreateTitle("Settings")
        rootDescription:CreateCheckbox("Show unlearned spells", smb.showsUnlearned, function()
            smb.setShowUnlearned(not smb.showsUnlearned())
            if page.pagingControls.SetCurrentPage then
                page.paging = true
                page.pagingControls:SetCurrentPage(1)
                page.paging = false
            end
            refresh(page)
        end)
        rootDescription:CreateCheckbox("Count spells on bars as placed", smb.countsSpellsOnBars, function()
            smb.setCountSpellsOnBars(not smb.countsSpellsOnBars())
            layout(page)
        end)
        if smb.classOffersPetAttack() then
            rootDescription:CreateCheckbox("Enable Pet attacks before spell cast", smb.petAttacksByDefault, function()
                smb.setPetAttacksByDefault(not smb.petAttacksByDefault())
                refresh(page) -- rewrites the macros that follow the default
            end)
        end
        if smb.classOffersStopCast() or smb.classOffersStartAttack() then
            rootDescription:CreateDivider()
            rootDescription:CreateTitle("Global Macro Settings")
        end
        if smb.classOffersStopCast() then
            rootDescription:CreateCheckbox("Stop casting before spell cast", smb.stopsCastingByDefault, function()
                smb.setStopsCastingByDefault(not smb.stopsCastingByDefault())
                refresh(page) -- rewrites the macros that follow the default
            end)
        end
        if smb.classOffersStartAttack() then
            rootDescription:CreateCheckbox("Start attack after spell cast", smb.startsAttackByDefault, function()
                smb.setStartsAttackByDefault(not smb.startsAttackByDefault())
                refresh(page) -- rewrites the macros that follow the default
            end)
        end
    end)

    -- a search box laid over the native one, which only searches spells; it filters the page by macro or
    -- section name. Covering the native box also keeps it from taking focus, which would close the page
    local search = CreateFrame("EditBox", nil, page.header, "SearchBoxTemplate")
    page.search = search
    search:SetAutoFocus(false)
    -- no "Search" placeholder; the template reshows the font string as the text empties, so blank it instead
    if search.Instructions then search.Instructions:SetText("") end
    local nativeSearch = PlayerSpellsFrame.SpellBookFrame.SearchBox
    if nativeSearch then
        search:SetAllPoints(nativeSearch)
        -- the native box's text and art show through ours, so fade it out while the page is open; its text
        -- and search are left alone for when the player goes back to a native tab
        page:HookScript("OnShow", function()
            page.nativeSearchAlpha = page.nativeSearchAlpha or nativeSearch:GetAlpha()
            nativeSearch:SetAlpha(0)
        end)
        page:HookScript("OnHide", function()
            nativeSearch:SetAlpha(page.nativeSearchAlpha or 1)
            page.nativeSearchAlpha = nil
        end)
    else
        search:SetSize(200, 20)
        search:SetPoint("RIGHT", options, "LEFT", -10, 0)
    end
    search:HookScript("OnHide", function(self) self:ClearFocus() end)
    search:HookScript("OnTextChanged", function(self)
        local filter = self:GetText():lower():match("^%s*(.-)%s*$")
        if filter == (page.filter or "") then return end
        page.filter = filter
        if page.pagingControls.SetCurrentPage then
            page.paging = true
            page.pagingControls:SetCurrentPage(1)
            page.paging = false
        end
        layout(page)
    end)

    -- the native page's "Page 1/2" arrows, bottom right of the book
    local controls = CreateFrame("Frame", nil, page, "PagingControlsHorizontalTemplate")
    page.pagingControls = controls
    controls:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -75, 40)
    controls.PageText:SetFontObject("SystemFont_Med3")
    controls.PageText:SetTextColor(unpack(INK_COLOR))
    controls.spacing = 8
    controls.prevPageSound, controls.nextPageSound = SOUNDKIT.IG_ABILITY_PAGE_TURN, SOUNDKIT.IG_ABILITY_PAGE_TURN
    function page:OnPageChanged()
        if not self.paging then layout(self) end
    end
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        if controls:IsShown() then controls:OnMouseWheel(delta) end
    end)

    -- the minimize button resizes the book; lay out a frame later, once the book's isMinimized has caught up
    page:SetScript("OnSizeChanged", function(self)
        if self.resizePending then return end
        self.resizePending = true
        C_Timer.After(0, function()
            self.resizePending = false
            if self:IsVisible() then layout(self) end
        end)
    end)
    page:RegisterEvent("SPELLS_CHANGED")
    page:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- the Equipment section follows the gear worn
    -- unlearned spells whose names weren't loaded were skipped; redraw once a burst of them arrives
    page:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    -- placing or removing an action only changes the glows; redraw them once per burst
    page:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    page:RegisterEvent("UPDATE_MACROS")
    page:SetScript("OnEvent", function(self, event)
        if not self:IsVisible() then return end
        if event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" then
            if self.glowsPending then return end
            self.glowsPending = true
            C_Timer.After(0, function()
                self.glowsPending = false
                if not self:IsVisible() then return end
                local bars = smb.scanActionBars()
                for i = 1, self.buttons.used do updateGlow(self.buttons[i], bars) end
            end)
        elseif event ~= "SPELL_DATA_LOAD_RESULT" then
            refresh(self)
        elseif smb.showsUnlearned() and not self.refreshPending then
            self.refreshPending = true
            C_Timer.After(0, function()
                self.refreshPending = false
                if self:IsVisible() then refresh(self) end
            end)
        end
    end)
end

LibStub("LibSpellBookTabs-1.0"):RegisterTab(addonName, {
    name = "Macro Spellbook",
    icon = ICON_MACRO,
    iconTexCoords = ICON_MACRO_COORDS,
    onCreate = buildPage,
    onShow = refresh,
})

