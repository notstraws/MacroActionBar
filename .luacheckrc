std = "lua51"
max_line_length = false
exclude_files = { ".release/", "libs/LibStub/" }

ignore = {
	"212/self", -- unused self argument
	"432/self", -- script handlers shadowing self
}

globals = {
	"MacroSpellbookDB",
	"MacroSpellbookCharDB",
}

read_globals = {
	-- Lua / WoW utility
	"tContains", "wipe",

	-- Namespaces
	"C_Item", "C_Spell", "C_SpellBook", "C_Texture", "C_Timer",
	"C_TooltipInfo", "C_Trainer", "Enum", "EventRegistry", "EventUtil", "InputUtil", "MenuResponse", "MenuUtil",

	-- Functions
	"ClearCursor", "CreateFrame", "CreateMacro", "DeleteMacro", "EditMacro", "GetActionInfo", "GetActionText",
	"GetInventoryItemLink", "GetInventoryItemTexture", "GetItemSpell",
	"GetMacroIndexByName", "GetMacroInfo", "GetNumMacros", "GetNumShapeshiftForms",
	"GetNumSpellTabs", "GetNumTrainerServices", "GetShapeshiftFormInfo", "GetSpellBookItemInfo",
	"GetSpellBookItemName", "GetSpellBookItemTexture", "GetSpellTabInfo", "GetSpellTexture",
	"GetTrainerServiceLevelReq", "InCombatLockdown",
	"IsAltKeyDown", "IsHarmfulSpell", "IsPassiveSpell", "IsTradeskillTrainer", "LibStub", "PickupMacro", "PlaceAction", "PlaySound", "RunNextFrame",
	"SpellHasRange", "tinsert",
	"UnitClass", "UnitFactionGroup", "UnitRace",

	-- Frames / objects / constants
	"GameTooltip", "PlayerSpellsFrame", "UIErrorsFrame", "UIParent", "UISpecialFrames", "WorldFrame",
	"BOOKTYPE_SPELL", "ERR_NOT_IN_COMBAT", "ITEM_SPELL_TRIGGER_ONUSE", "MAX_ACCOUNT_MACROS", "MAX_CHARACTER_MACROS", "OKAY", "SOUNDKIT",
}
