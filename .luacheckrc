std = "lua51"
max_line_length = false
exclude_files = { ".release/", "libs/LibStub/" }

ignore = {
	"212/self", -- unused self argument
	"432/self", -- script handlers shadowing self
}

globals = {
	"MacroActionBarDB",
	"MacroActionBarCharDB",
}

read_globals = {
	-- Lua / WoW utility
	"tContains", "wipe",

	-- Namespaces
	"C_Item", "C_Spell", "C_SpellBook", "C_Texture", "C_Timer",
	"C_TooltipInfo", "C_Trainer", "Enum", "EventRegistry", "EventUtil", "InputUtil", "MenuResponse", "MenuUtil",

	-- Functions
	"ActionButton_GetPagedID", "ClearCursor", "CreateFrame", "CreateMacro", "DeleteMacro", "EditMacro", "GetActionInfo", "GetActionText",
	"GetInventoryItemLink", "GetInventoryItemTexture", "GetItemSpell",
	"GetMacroIndexByName", "GetMacroInfo", "GetNumMacros", "GetNumShapeshiftForms",
	"GetNumSpellTabs", "GetNumTrainerServices", "GetShapeshiftFormInfo", "GetSpellBookItemInfo",
	"GetSpellBookItemName", "GetSpellBookItemTexture", "GetSpellTabInfo", "GetSpellTexture",
	"GetCursorInfo", "GetCursorPosition", "GetRealmName", "GetTrainerServiceLevelReq", "HideUIPanel", "InCombatLockdown", "InterfaceOptions_AddCategory",
	"IsAltKeyDown", "IsHarmfulSpell", "IsPassiveSpell", "IsTradeskillTrainer", "LibStub", "PickupAction", "PickupMacro", "PlaceAction", "PlaySound", "RunNextFrame",
	"SecureHandlerWrapScript", "SpellHasRange", "tinsert", "ToggleSpellBook",
	"UnitClass", "UnitName", "UnitFactionGroup", "UnitRace",

	-- Frames / objects / constants
	"GameTooltip", "Minimap", "PlayerSpellsFrame", "PlayerSpellsUtil", "Settings", "UIErrorsFrame", "UIParent", "UISpecialFrames", "WorldFrame",
	"BOOKTYPE_SPELL", "ERR_NOT_IN_COMBAT", "ITEM_SPELL_TRIGGER_ONUSE", "MAX_ACCOUNT_MACROS", "MAX_CHARACTER_MACROS", "OKAY", "SOUNDKIT",
}
