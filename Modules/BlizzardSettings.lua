local Object = {}
Object.__index = Object -- When a key is missing, look in BlizzardSettings

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:GetUseRaidStylePartyFrames()
    if not EditModeManagerFrame then return false end
    return EditModeManagerFrame:UseRaidStylePartyFrames() or false
end

function Object:GetPartyFramesUseHorizontalGroups()
    if not (EditModeManagerFrame and EditModeManagerFrame.GetSettingValueBool) then
        return nil
    end

    if not (Enum and Enum.EditModeSystem and Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSetting) then
        return nil
    end

    local ok, value = pcall(
        EditModeManagerFrame.GetSettingValueBool,
        EditModeManagerFrame,
        Enum.EditModeSystem.UnitFrame,
        Enum.EditModeUnitFrameSystemIndices.Party,
        Enum.EditModeUnitFrameSetting.UseHorizontalGroups
    )
    if not ok then
        return nil
    end

    if value == nil then
        return nil
    end

    return value == true
end

-- Get the current built-in class color setting
function Object:GetClassColorSetting()
    -- Check if the CompactRaidFrame setting exists
    if CompactRaidFrameManager and CompactRaidFrameManager.displayClassColor ~= nil then
        return CompactRaidFrameManager.displayClassColor
    end

    -- Fallback to CVar if available
    local cvar = GetCVar("raidFramesDisplayClassColor")
    if cvar then
        return cvar == "1"
    end

    return false
end

-- Set the built-in class color setting
function Object:SetClassColorSetting(enabled)
    -- Set through the manager if possible
    if CompactRaidFrameManager then
        CompactRaidFrameManager_SetSetting("DisplayClassColor", enabled and "1" or "0")
    end

    -- Also try setting the CVar
    if GetCVar("raidFramesDisplayClassColor") then
        SetCVar("raidFramesDisplayClassColor", enabled and "1" or "0")
    end
end

BlizzardSettings = Object:New()
