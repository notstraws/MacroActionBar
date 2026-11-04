local addonName, smb = ...

-- A minimap button that opens the Macro Action Bar page (SpellBookTab.lua), and the addon's page under
-- Options > AddOns, which turns the button on and off. Both settings are account-wide.

local DEFAULT_ANGLE = 225 -- degrees around the minimap, counterclockwise from the right: bottom left

local button

-- Read lazily: saved variables are not loaded until ADDON_LOADED, after this file runs.
function smb.minimapIconShown()
    return MacroActionBarDB == nil or MacroActionBarDB.minimapHide ~= true
end

function smb.setMinimapIconShown(on)
    MacroActionBarDB = MacroActionBarDB or {}
    MacroActionBarDB.minimapHide = (not on) or nil
    if button then button:SetShown(on) end
end

local function angle()
    return MacroActionBarDB and MacroActionBarDB.minimapAngle or DEFAULT_ANGLE
end

local function updatePosition()
    local radians = math.rad(angle())
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

-- follows the cursor around the minimap's edge while dragged
local function onDragUpdate()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    MacroActionBarDB = MacroActionBarDB or {}
    MacroActionBarDB.minimapAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX)) % 360
    updatePosition()
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Macro Action Bar")
    GameTooltip:AddLine("Left-click: Open", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Options", 1, 1, 1)
    GameTooltip:Show()
end

local function hideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function createButton()
    button = CreateFrame("Button", "MacroActionBarMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(smb.ICON_MACRO)
    icon:SetTexCoord(unpack(smb.ICON_MACRO_COORDS))
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            hideTooltip(self)
            MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                rootDescription:CreateTitle("Macro Action Bar")
                rootDescription:CreateButton("Hide minimap icon", function()
                    smb.setMinimapIconShown(false)
                    print(addonName .. ": minimap icon hidden. Turn it back on in Options > AddOns > Macro Action Bar.")
                end)
            end)
        else
            smb.openPage()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        hideTooltip(self)
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)

    updatePosition()
    button:SetShown(smb.minimapIconShown())
end

-- Options > AddOns > Macro Action Bar
local function createOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Macro Action Bar"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Macro Action Bar")

    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -12)
    check:SetScript("OnClick", function(self) smb.setMinimapIconShown(self:GetChecked()) end)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText("Show minimap icon")

    -- the right-click menu can hide the icon while the panel is closed
    panel:SetScript("OnShow", function() check:SetChecked(smb.minimapIconShown()) end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    createButton()
    createOptionsPanel()
end)
