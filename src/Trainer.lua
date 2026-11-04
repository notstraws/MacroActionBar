local _, smb = ...

-- Records the spells class trainers offer, per character, so the page can list unlearned spells that the
-- bundled data (Data/) misses. Trainer lists live on the server, so a trainer window is the only place the
-- game shows them.

-- MacroActionBarCharDB.trainerSpells: spell id -> required level, for each spell a trainer offered (every
-- rank: Macros.lua keeps rank 1). Read lazily: saved variables are not loaded until ADDON_LOADED, after this
-- file runs.
local function recorded()
    MacroActionBarCharDB = MacroActionBarCharDB or {}
    MacroActionBarCharDB.trainerSpells = MacroActionBarCharDB.trainerSpells or {}
    return MacroActionBarCharDB.trainerSpells
end

-- The recorded trainer spells as Data/ style entries ({level, id}), lowest level first.
function smb.recordedTrainerSpells()
    local spells = {}
    for id, level in pairs(recorded()) do
        spells[#spells + 1] = {level = level, id = id}
    end
    table.sort(spells, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.id < b.id
    end)
    return spells
end

local function isClassTrainer()
    if IsTradeskillTrainer and IsTradeskillTrainer() then return false end
    if C_Trainer and C_Trainer.GetTrainerType and Enum.TrainerType then
        local trainerType = C_Trainer.GetTrainerType()
        if Enum.TrainerType.Class then return trainerType == Enum.TrainerType.Class end
        return trainerType ~= Enum.TrainerType.Pet
    end
    return true
end

-- Records the services the trainer window lists (with its current filters: by default the available and
-- unavailable ones, which are the unlearned spells).
local function recordServices()
    if not (C_TooltipInfo and C_TooltipInfo.GetTrainerService) or not isClassTrainer() then return end
    local spells = recorded()
    for index = 1, GetNumTrainerServices() or 0 do
        local tooltip = C_TooltipInfo.GetTrainerService(index)
        local id = tooltip and tooltip.id
        if id then
            spells[id] = GetTrainerServiceLevelReq(index) or spells[id] or 0
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("TRAINER_SHOW")
frame:RegisterEvent("TRAINER_UPDATE") -- also fires when the window's filters change
frame:SetScript("OnEvent", recordServices)
