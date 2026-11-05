--[[ LibSpellBookTabs-1.0
Shared tab bar for addon pages in the spellbook (Blizzard_PlayerSpells).

Every addon that embeds this library shares one copy (LibStub keeps the newest), so their tabs are laid
out together and only one addon page is open at a time.

    local LSBT = LibStub("LibSpellBookTabs-1.0")
    LSBT:RegisterTab("MyAddon", {
        name = "My Addon",          -- tooltip
        icon = 134400,              -- texture path or fileID
        iconTexCoords = {0, 1, 0, 1}, -- optional (MINOR 5+): left, right, top, bottom crop of the icon
        side = true,                -- optional (MINOR 6+): always down the book's right edge, never in the top row
        onCreate = function(page) end, -- build the page's contents; called once, on first open
        onShow = function(page) end,   -- optional
        onHide = function(page) end,   -- optional
    })
    LSBT:Open("MyAddon")   -- selects the tab; it shows once the spellbook is open
    LSBT:Close()
    LSBT:IsOpen("MyAddon")

The page covers the book below its top 60px toolbar and clips its children. page.header (MINOR 2+) covers
that toolbar, shows and hides with the page, and doesn't clip, so a page can put its own controls there,
for example a settings dropdown over the native one at ("TOPRIGHT", -30, -27).

Placement: tabs line up right of the native tabs, after every tab-sized frame from other addons in that row
(MINOR 6+; before, they took the first free gap), so they always come last. Tabs that don't fit before the
search box, and tabs registered with side = true, stack down the book's right edge. A frame anchored to one
of these tabs is ignored, so an addon that places itself after them can't make them leapfrog each other.

Pages from other addons: opening a tab here closes any other addon's page, and clicking another addon's
launcher closes ours, without either addon knowing the other. To work with this, lay your page over the book
as one frame the size of PlayerSpellsFrame.SpellBookFrame (parented to PlayerSpellsFrame or UIParent), with
a child button centered on the native selected tab that closes it (as this library's return tab does). If
there's no such button, the page is just hidden. Launchers are the tab-sized buttons by the native tabs or
down the book's right edge.

Nothing Blizzard owns is written to: everything is layered over the book.
]]

local MAJOR, MINOR = "LibSpellBookTabs-1.0", 7
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- state survives library upgrades
lib.tabs = lib.tabs or {}
lib.byId = lib.byId or {}
lib.owned = lib.owned or {}
lib.hookedForeign = lib.hookedForeign or {}

local TAB_WIDTH, TAB_HEIGHT, GAP = 44, 32, 8
-- the native tab row, search box and settings dropdown sit in the book's top 60px
local HEADER_HEIGHT = 60

local skin = {
    tab = "spellbook-Tab-Frame-C60",
    tabActive = "spellbook-Tab-Frame-Glow-C60",
    tabGlow = "spellbook-Tab-Frame-glow-gradient-C60",
    pageLeft = "spellbook-Page-Left-C60",
    pageRight = "spellbook-Page-Right-C60",
}

local function own(frame)
    lib.owned[frame] = true
    return frame
end

local function hideTooltip(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function makeTab(parent, icon, texCoords)
    local button = own(CreateFrame("Button", nil, parent))
    button:SetSize(TAB_WIDTH, TAB_HEIGHT)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(34, 33)
    button.icon:SetPoint("BOTTOM", -1, 0)
    button.icon:SetTexture(icon)
    if texCoords then button.icon:SetTexCoord(unpack(texCoords)) end
    local function frameArt(atlas, y)
        local texture = button:CreateTexture(nil, "ARTWORK", nil, 1)
        texture:SetAtlas(atlas, true)
        texture:SetPoint("BOTTOM", 0, y)
        return texture
    end
    button.normal = frameArt(skin.tab, 1)
    button.active = frameArt(skin.tabActive, 1)
    button.glow = frameArt(skin.tabGlow, 0)
    return button
end

local function selectTab(button, selected)
    button.normal:SetShown(not selected)
    button.active:SetShown(selected)
    button.glow:SetShown(selected)
end

-- frames anchored to restricted or secret regions (such as PingPin) can't be measured: asking raises a
-- "Can't measure restricted regions" error that blames our addon
local function canMeasure(frame)
    if frame.IsAnchoringRestricted and frame:IsAnchoringRestricted() then return false end
    if frame.IsAnchoringSecret and frame:IsAnchoringSecret() then return false end
    return true
end

-- left, bottom, right, top in screen pixels, so frames with different scales compare
local function screenRect(frame)
    if not canMeasure(frame) then return end
    local left, bottom, width, height = frame:GetRect()
    if not left then return end
    local scale = frame:GetEffectiveScale()
    return left * scale, bottom * scale, (left + width) * scale, (bottom + height) * scale
end

-- shown, tab-sized frames we don't own: other addons' launchers
local function collectObstacles(tabScreenWidth, tabScreenHeight)
    local rects = {}
    local seen = {}
    local function scan(parent)
        if not parent then return end
        for _, child in ipairs({parent:GetChildren()}) do
            if not seen[child] and not lib.owned[child] and not child:IsForbidden() and child:IsVisible() then
                seen[child] = true
                local left, bottom, right, top = screenRect(child)
                if left then
                    local width, height = right - left, top - bottom
                    if width > tabScreenWidth * 0.4 and width < tabScreenWidth * 2
                        and height > tabScreenHeight * 0.4 and height < tabScreenHeight * 2 then
                        rects[#rects + 1] = {frame = child, left = left, bottom = bottom, right = right, top = top}
                    end
                end
            end
        end
    end
    scan(PlayerSpellsFrame)
    scan(lib.book)
    scan(UIParent)
    return rects
end

-- frames Blizzard keeps under a key on the spells frame or the book (the book itself, the talents page, the
-- close, minimize and settings buttons), so they're never taken for another addon's page or launcher
local function blizzardFrames()
    local set = {}
    for _, parent in ipairs({PlayerSpellsFrame, lib.book}) do
        for _, value in pairs(parent) do
            if type(value) == "table" then set[value] = true end
        end
    end
    return set
end

local function isAncestor(frame, child)
    while child do
        if child == frame then return true end
        child = child:GetParent()
    end
end

local function screenCenter(frame)
    if not canMeasure(frame) then return end
    local x, y = frame:GetCenter()
    if not x then return end
    local scale = frame:GetEffectiveScale()
    return x * scale, y * scale
end

-- shown frames we don't own that cover exactly the book: other addons' pages
local function findForeignPages()
    local book = lib.book
    local pages = {}
    if not book:IsVisible() then return pages end
    local bookLeft, bookBottom, bookRight, bookTop = screenRect(book)
    if not bookLeft then return pages end
    local tolerance = 4 * book:GetEffectiveScale()
    local blizzard = blizzardFrames()
    for _, parent in ipairs({PlayerSpellsFrame, UIParent}) do
        for _, child in ipairs({parent:GetChildren()}) do
            if not lib.owned[child] and not blizzard[child] and not child:IsForbidden() and child:IsVisible()
                and not isAncestor(child, book) then
                local left, bottom, right, top = screenRect(child)
                if left and math.abs(left - bookLeft) <= tolerance and math.abs(bottom - bookBottom) <= tolerance
                    and math.abs(right - bookRight) <= tolerance and math.abs(top - bookTop) <= tolerance then
                    pages[#pages + 1] = child
                end
            end
        end
    end
    return pages
end

-- click the page's own return tab (a button over the native selected tab) so its addon knows it closed;
-- hiding the page would leave the addon thinking it's open
local function closeForeignPage(page)
    local nativeTabs = lib.book.CategoryTabSystem
    local native = nativeTabs.selectedTabID and nativeTabs:GetTabButton(nativeTabs.selectedTabID)
    local nativeX, nativeY
    if native then nativeX, nativeY = screenCenter(native) end
    if nativeX then
        local tolerance = 4 * native:GetEffectiveScale()
        for _, child in ipairs({page:GetChildren()}) do
            if not child:IsForbidden() and child:IsObjectType("Button") and child:IsVisible() then
                local x, y = screenCenter(child)
                if x and math.abs(x - nativeX) <= tolerance and math.abs(y - nativeY) <= tolerance then
                    child:Click()
                    return
                end
            end
        end
    end
    page:Hide()
end

-- first free spot along one axis, pushed past every obstacle that overlaps the slot
local function nextFreeRowSlot(obstacles, x, width, bottom, top, gap)
    local moved = true
    while moved do
        moved = false
        for _, rect in ipairs(obstacles) do
            if rect.left < x + width and rect.right > x and rect.bottom < top and rect.top > bottom then
                x = rect.right + gap
                moved = true
            end
        end
    end
    return x
end

local function nextFreeColumnSlot(obstacles, y, height, left, right, gap)
    local moved = true
    while moved do
        moved = false
        for _, rect in ipairs(obstacles) do
            if rect.bottom < y and rect.top > y - height and rect.left < right and rect.right > left then
                y = rect.bottom - gap
                moved = true
            end
        end
    end
    return y
end

-- a frame placed relative to one of our tabs follows them, so moving past it would only move it again
local function anchoredToOwned(frame)
    for i = 1, frame:GetNumPoints() do
        local _, relativeTo = frame:GetPoint(i)
        if relativeTo and lib.owned[relativeTo] then return true end
    end
end

-- the right edge of the last shown native tab and the gap between native tabs, in screen pixels, so our tabs
-- continue the native row's spacing (the tab system frame itself runs past its last tab)
local function nativeRowMetrics(nativeTabs)
    local rects = {}
    for _, button in ipairs(nativeTabs.tabs or {}) do
        if button:IsShown() then
            local left, _, right = screenRect(button)
            if left then rects[#rects + 1] = {left = left, right = right} end
        end
    end
    if #rects == 0 then return end
    table.sort(rects, function(a, b) return a.left < b.left end)
    local gap
    if #rects > 1 then gap = rects[2].left - rects[1].right end
    return rects[#rects].right, gap
end

function lib:Layout()
    local book = self.book
    local nativeTabs = book.CategoryTabSystem
    local scale = book:GetEffectiveScale()
    local tabsLeft, tabsBottom, tabsRight, tabsTop = screenRect(nativeTabs)
    local bookLeft, bookBottom, bookRight, bookTop = screenRect(book)
    if not tabsLeft or not bookRight then return end
    local searchLeft = screenRect(book.SearchBox)
    local width, height, gap = TAB_WIDTH * scale, TAB_HEIGHT * scale, GAP * scale
    local lastNativeRight, nativeGap = nativeRowMetrics(nativeTabs)
    if nativeGap and nativeGap >= 0 and nativeGap < width then gap = nativeGap end
    local obstacles = collectObstacles(width, height)

    local centerY = (tabsBottom + tabsTop) / 2
    local rowBottom, rowTop = centerY - height / 2, centerY + height / 2
    -- other addons' launchers sit where these tabs go: by the native tabs (or hanging below them), or down
    -- the book's right edge
    local blizzard = blizzardFrames()
    for _, rect in ipairs(obstacles) do
        local byTabs = rect.bottom < rowTop + height and rect.top > rowBottom - height
            and rect.right > bookLeft and rect.left < bookRight
        local byEdge = rect.left > bookRight - width / 2 and rect.left < bookRight + width
            and rect.top < bookTop + height and rect.bottom > bookBottom
        if (byTabs or byEdge) and not blizzard[rect.frame] then self:HookLauncher(rect.frame) end
    end
    -- start after the last launcher in the row, so these tabs always come last
    local x = (lastNativeRight or tabsRight) + gap
    for _, rect in ipairs(obstacles) do
        if rect.bottom < rowTop and rect.top > rowBottom and rect.left >= x - gap
            and (not searchLeft or rect.right <= searchLeft) and not anchoredToOwned(rect.frame) then
            x = math.max(x, rect.right + gap)
        end
    end
    local columnTop = tabsTop
    local inRow = true
    for _, tab in ipairs(self.tabs) do
        local button = tab.button
        button:ClearAllPoints()
        if inRow and not tab.side then
            x = nextFreeRowSlot(obstacles, x, width, rowBottom, rowTop, gap)
            if searchLeft and x + width > searchLeft - gap then inRow = false end
        end
        if inRow and not tab.side then
            button:SetPoint("LEFT", nativeTabs, "RIGHT", (x - tabsRight) / scale, 0)
            x = x + width + gap
        else
            columnTop = nextFreeColumnSlot(obstacles, columnTop, height, bookRight, bookRight + width, gap)
            button:SetPoint("TOPLEFT", book, "TOPRIGHT", 0, (columnTop - bookTop) / scale)
            columnTop = columnTop - height - gap
        end
    end
end

local function ensurePage(tab)
    if tab.page then return tab.page end
    local page = own(CreateFrame("Frame", nil, lib.root.content))
    page:SetAllPoints()
    page:Hide()
    tab.page = page
    -- the page is clipped below the toolbar, so toolbar controls go on this unclipped frame instead
    local header = own(CreateFrame("Frame", nil, lib.root))
    page.header = header
    header:SetPoint("TOPLEFT", lib.root, "TOPLEFT")
    header:SetPoint("BOTTOMRIGHT", lib.root.content, "TOPRIGHT")
    header:Hide()
    if tab.onShow then page:SetScript("OnShow", tab.onShow) end
    if tab.onHide then page:SetScript("OnHide", tab.onHide) end
    page:HookScript("OnShow", function() header:Show() end)
    page:HookScript("OnHide", function() header:Hide() end)
    if tab.onCreate then tab.onCreate(page) end
    return page
end

function lib:Sync()
    local book = self.book
    if not book then return end
    local root, nativeTabs = self.root, book.CategoryTabSystem
    local gamepad = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    -- Open() ran before the spellbook loaded
    if self.active and self.shownTab == nil then self.shownTab = nativeTabs.selectedTabID end
    -- a native tab was picked (or search took over) since we opened
    if gamepad or nativeTabs.selectedTabID ~= self.shownTab or book.SearchBox:HasFocus()
        or book.SearchPreviewContainer:IsShown() then
        self.active = nil
    end
    if gamepad or not book:IsVisible() or #self.tabs == 0 then
        root:Hide()
        for _, tab in ipairs(self.tabs) do tab.button:Hide() end
        return
    end
    self:HookForeign()

    local scale = book:GetEffectiveScale() / PlayerSpellsFrame:GetEffectiveScale()
    local strata, level = PlayerSpellsFrame:GetFrameStrata(), PlayerSpellsFrame.NineSlice:GetFrameLevel() - 10
    root:SetScale(scale)
    root:SetFrameStrata(strata)
    root:SetFrameLevel(level)
    self.returnTab:SetFrameLevel(level + 5)
    for _, tab in ipairs(self.tabs) do
        local button = tab.button
        button:SetScale(scale)
        button:SetFrameStrata(strata)
        button:SetFrameLevel(level + 5)
        selectTab(button, tab == self.active)
        button:Show()
        -- above the native search box and settings dropdown, so a control placed over them takes the clicks
        if tab.page then tab.page.header:SetFrameLevel(level + 5) end
    end
    self:Layout()

    local active = self.active
    for _, tab in ipairs(self.tabs) do
        if tab.page and tab ~= active then tab.page:Hide() end
    end
    if not active then return root:Hide() end

    local content = root.content
    content.whole:SetShown(book.isMinimized)
    content.left:SetShown(not book.isMinimized)
    content.right:SetShown(not book.isMinimized)
    -- the native selected tab still looks selected underneath, so cover it with an unselected copy
    local native = nativeTabs.selectedTabID and nativeTabs:GetTabButton(nativeTabs.selectedTabID)
    local returnTab = self.returnTab
    returnTab:SetShown(native ~= nil)
    if native then
        returnTab:ClearAllPoints()
        returnTab:SetPoint("CENTER", native)
        returnTab.icon:SetTexture(native.Icon:GetTexture())
    end
    ensurePage(active):Show()
    root:Show()
end

function lib:RequestSync()
    if self.queued then return end
    self.queued = true
    RunNextFrame(function()
        lib.queued = false
        lib:Sync()
    end)
end

-- other addons lay out on the same show/resize events, so look again once they've settled
local function relayout()
    lib:RequestSync()
    C_Timer.After(0.2, function() lib:RequestSync() end)
end

-- another addon's launcher opens its page, so close ours
function lib:HookLauncher(launcher)
    if self.hookedForeign[launcher] or not launcher:HasScript("OnClick") then return end
    self.hookedForeign[launcher] = true
    launcher:HookScript("OnClick", function() lib:Close() end)
    launcher:HookScript("OnShow", relayout)
end

-- another addon's page can open some other way too (a key binding, a slash command)
function lib:HookForeign()
    for _, page in ipairs(findForeignPages()) do
        if not self.hookedForeign[page] then
            self.hookedForeign[page] = true
            page:HookScript("OnShow", function() lib:Close() end)
        end
    end
end

function lib:CreateButton(tab)
    local button = makeTab(PlayerSpellsFrame, tab.icon, tab.iconTexCoords)
    tab.button = button
    button:Hide()
    button:SetScript("OnClick", function()
        if lib.active == tab then lib:Close() else lib:Open(tab.id) end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tab.name)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnHide", hideTooltip)
end

function lib:Attach()
    if self.book then return end
    local book = PlayerSpellsFrame.SpellBookFrame
    self.book = book

    local root = own(CreateFrame("Frame", nil, PlayerSpellsFrame))
    self.root = root
    root:Hide()
    root:SetAllPoints(book)

    -- parchment that eats the mouse over the native spell pages; addon pages are its children
    local content = own(CreateFrame("Frame", nil, root))
    root.content = content
    content:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -HEADER_HEIGHT)
    content:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT")
    content:SetClipsChildren(true)
    content:EnableMouse(true)
    content:EnableMouseWheel(true)
    local art = CreateFrame("Frame", nil, content)
    art:SetAllPoints(root)
    local function pageArt(atlas, from, to)
        local texture = art:CreateTexture(nil, "BACKGROUND")
        texture:SetAtlas(atlas)
        texture:SetPoint("TOPLEFT", root, from)
        texture:SetPoint("BOTTOMRIGHT", root, to)
        return texture
    end
    content.whole = pageArt(skin.pageRight, "TOPLEFT", "BOTTOMRIGHT")
    content.left = pageArt(skin.pageLeft, "TOPLEFT", "BOTTOM")
    content.right = pageArt(skin.pageRight, "TOP", "BOTTOMRIGHT")

    local returnTab = makeTab(root)
    self.returnTab = returnTab
    selectTab(returnTab, false)
    returnTab:SetScript("OnClick", function() lib:Close() end)

    for _, tab in ipairs(self.tabs) do self:CreateButton(tab) end

    local function request() lib:RequestSync() end
    for _, event in ipairs({"SpellBookFrame.Show", "SpellBookFrame.Hide", "SpellBookFrame.DisplayedSpellsChanged"}) do
        EventRegistry:RegisterCallback("PlayerSpellsFrame." .. event, request, lib)
    end
    EventRegistry:RegisterCallback("SpellSearchBox.FocusedGained", request, lib)
    EventRegistry:RegisterCallback("SpellSearchPreview.FocusedGained", request, lib)
    book:HookScript("OnSizeChanged", relayout)
    book:HookScript("OnShow", relayout)
    book:HookScript("OnHide", function() lib:Sync() end)
    self:RequestSync()
end

function lib:RegisterTab(id, info)
    assert(type(id) == "string", "RegisterTab: id must be a string")
    assert(type(info) == "table" and info.name, "RegisterTab: info.name is required")
    if self.byId[id] then return self.byId[id] end
    local tab = {
        id = id,
        name = info.name,
        icon = info.icon or 134400, -- Interface\Icons\INV_Misc_QuestionMark
        iconTexCoords = info.iconTexCoords,
        side = info.side,
        onCreate = info.onCreate,
        onShow = info.onShow,
        onHide = info.onHide,
    }
    self.tabs[#self.tabs + 1] = tab
    self.byId[id] = tab
    if self.book then
        self:CreateButton(tab)
        self:RequestSync()
    end
    return tab
end

function lib:Open(id)
    local tab = self.byId[id]
    if not tab or self.active == tab then return end
    if self.book then
        for _, page in ipairs(findForeignPages()) do closeForeignPage(page) end
    end
    self.active = tab
    self.shownTab = self.book and self.book.CategoryTabSystem.selectedTabID
    PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    self:Sync()
end

function lib:Close()
    if not self.active then return end
    self.active = nil
    self:Sync()
end

function lib:IsOpen(id)
    return self.active ~= nil and self.active.id == id
end

if not lib.attachRequested then
    lib.attachRequested = true
    EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function() lib:Attach() end)
end
