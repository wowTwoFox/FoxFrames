local addonName, addon = ...

local FF = assert(FoxFrames, "FoxFrames: global FoxFrames missing (load order issue)")

local Utils = addon.Utils
local Blizzard = addon.Blizzard
local DB = addon.DB

function FF:ApplyPlayerStatusAnchorForFrame(frame)
    local fontString = Utils:EnsureFontString(frame and frame.statusText)
    if not (fontString and fontString.ClearAllPoints and fontString.SetPoint) then
        return
    end

    local isRaid = Blizzard:InRaidGroup() == true

    if not DB:GetEffectivePlayerStatusFrameCustomize(isRaid) then
        if fontString._ffPointCustomized then
            Utils:RevertCustomPoint(fontString)
        end
        return
    end

    local layoutAxis = Blizzard:GetPartyFramesLayoutAxis()
    local point, relativePoint, target, offsetX, offsetY = DB:GetEffectivePlayerStatusAnchorsAndOffsets(layoutAxis, isRaid)

    local relativeTo = frame
    if target == DB.FRAME_ANCHOR_TARGETS.HEALTHBAR and frame.healthBar then
        relativeTo = frame.healthBar
    end

    Utils:RevertingClearAllPoints(fontString)
    Utils:SetRevertingPoint(fontString, point, relativeTo, relativePoint, offsetX, offsetY)
end

function FF:UpdatePlayerStatusAnchoring()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        Utils:Log("Updating player status anchoring for frame", frame)
        self:ApplyPlayerStatusAnchorForFrame(frame)
    end
end

function FF:ApplyPlayerStatusColorForFrame(frame)
    local fontString = Utils:EnsureFontString(frame and frame.statusText)
    if not (fontString and fontString.SetTextColor) then
        return
    end

    local isRaid = Blizzard:InRaidGroup() == true

    if not DB:GetEffectivePlayerStatusTextCustomize(isRaid) then
        if fontString._ffFontColorCustomized then
            Utils:RevertCustomFontColor(fontString)
        end
        return
    end

    local useClassColors = DB:GetEffectivePlayerStatusUseClassColors(isRaid)
    if useClassColors then
        local classR, classG, classB = Blizzard:GetClassColorForUnit(frame and frame.unit)
        if classR and classG and classB then
            local _, _, _, alpha = DB:GetEffectivePlayerStatusColor(isRaid)
            Utils:SetRevertingTextColor(fontString, classR, classG, classB, alpha)
            return
        end
    end

    local r, g, b, a = DB:GetEffectivePlayerStatusColor(isRaid)
    Utils:SetRevertingTextColor(fontString, r, g, b, a)
end

function FF:UpdatePlayerStatusColor()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerStatusColorForFrame(frame)
    end
end

function FF:ApplyPlayerStatusFontSizeForFrame(frame)
    local fontString = Utils:EnsureFontString(frame and frame.statusText)
    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return
    end

    local isRaid = Blizzard:InRaidGroup() == true

    if not DB:GetEffectivePlayerStatusTextCustomize(isRaid) then
        if fontString._ffFontCustomized then
            Utils:RevertCustomFont(fontString)
        end
        return
    end

    local size = DB:GetEffectivePlayerStatusFontSize(isRaid)
    local fontFile, _, flags = fontString:GetFont()
    if flags ~= nil then
        Utils:SetRevertingFont(fontString, fontFile, size, flags)
    else
        Utils:SetRevertingFont(fontString, fontFile, size)
    end
end

function FF:UpdatePlayerStatusFontSize()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerStatusFontSizeForFrame(frame)
    end
end

function FF:ApplyPlayerStatusSettingsForFrame(frame)
    self:ApplyPlayerStatusAnchorForFrame(frame)
    self:ApplyPlayerStatusColorForFrame(frame)
    self:ApplyPlayerStatusFontSizeForFrame(frame)
end

function FF:ApplyPlayerStatusSettings()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerStatusSettingsForFrame(frame)
    end
end

function FF:ApplyPlayerNameAnchorForFrame(frame)
    local fontString = Utils:EnsureFontString(frame and frame.name)
    if not (fontString and fontString.ClearAllPoints and fontString.SetPoint) then
        Utils:Log("ERROR: NOT_VALID_FRAME", frame)
        return
    end

    local isRaid = Blizzard:InRaidGroup() == true

    if not DB:GetEffectivePlayerNameFrameCustomize(isRaid) then
        if fontString._ffPointCustomized then
            Utils:RevertCustomPoint(fontString)
        end
        return
    end

    local layoutAxis = Blizzard:GetPartyFramesLayoutAxis()
    local point, relativePoint, target, offsetX, offsetY = DB:GetEffectivePlayerNameAnchorsAndOffsets(layoutAxis, isRaid)

    local relativeTo = frame
    if target == DB.FRAME_ANCHOR_TARGETS.HEALTHBAR and frame.healthBar then
        relativeTo = frame.healthBar
    end

    Utils:RevertingClearAllPoints(fontString)
    Utils:SetRevertingPoint(fontString, point, relativeTo, relativePoint, offsetX, offsetY)
end

function FF:UpdatePlayerNameAnchoring()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerNameAnchorForFrame(frame)
    end
end

function FF:ApplyPlayerNameColorForFrame(frame)
    local fontString = Utils:EnsureFontString(frame and frame.name)
    if not (fontString and fontString.SetTextColor) then
        return
    end

    local isRaid = Blizzard:InRaidGroup() == true

    if not DB:GetEffectivePlayerNameTextCustomize(isRaid) then
        if fontString._ffFontColorCustomized then
            Utils:RevertCustomFontColor(fontString)
        end
        return
    end

    local useClassColors = DB:GetEffectivePlayerNameUseClassColors(isRaid)
    if useClassColors then
        local classR, classG, classB = Blizzard:GetClassColorForUnit(frame and frame.unit)
        if classR and classG and classB then
            local _, _, _, alpha = DB:GetEffectivePlayerNameColor(isRaid)
            Utils:SetRevertingTextColor(fontString, classR, classG, classB, alpha)
            return
        end
    end

    local r, g, b, a = DB:GetEffectivePlayerNameColor(isRaid)
    Utils:SetRevertingTextColor(fontString, r, g, b, a)
end

function FF:UpdatePlayerNameColor()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerNameColorForFrame(frame)
    end
end

function FF:ApplyPlayerNameFontSizeForFrame(frame)
    local fontString = Utils:EnsureFontString(frame and frame.name)
    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return
    end

    local isRaid = Blizzard:InRaidGroup() == true

    if not DB:GetEffectivePlayerNameTextCustomize(isRaid) then
        if fontString._ffFontCustomized then
            Utils:RevertCustomFont(fontString)
        end
        return
    end

    local size = DB:GetEffectivePlayerNameFontSize(isRaid)
    local fontFile, _, flags = fontString:GetFont()
    if flags ~= nil then
        Utils:SetRevertingFont(fontString, fontFile, size, flags)
    else
        Utils:SetRevertingFont(fontString, fontFile, size)
    end
end

function FF:UpdatePlayerNameFontSize()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerNameFontSizeForFrame(frame)
    end
end

function FF:ApplyPlayerNameSettingsForFrame(frame)
    self:ApplyPlayerNameAnchorForFrame(frame)
    self:ApplyPlayerNameColorForFrame(frame)
    self:ApplyPlayerNameFontSizeForFrame(frame)
end

function FF:ApplyPlayerNameSettings()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyPlayerNameSettingsForFrame(frame)
    end
end
