local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon.Utils

function FF:InAllowedGroup()
    if PartyStatus:InRaidGroup() then return true end
    return BlizzardSettings:GetUseRaidStylePartyFrames() and PartyStatus:InPartyGroup()
end

function FF:IsPlayerUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return false
    end

    return UnitIsUnit(unit, "player")
end

function FF:IsPlayerFrame(frame)
    return self:IsPlayerUnit(frame and frame.unit)
end

function FF:SetAllowAnyAnchoring()
    if not PartyFrame then return end
    PartyFrame.alwaysUseTopLeftAnchor = not self.db.profile.partyFrame.allowAnyAnchoring
end

function FF:ShowPartyFrameIfNeeded()
    if not PartyStatus:InSoloMode() then return end
    if not CompactPartyFrame then return end
    CompactPartyFrame:SetShown(self.db.profile.partyFrame.showInSolo)
end

function FF:ShowPlayerFrameIfNeeded()
    if self.db.profile.playerFrame.showType == FF.PLAYER_FRAME_SHOW_TYPES.Solo then
        PlayerFrame:SetShown(PartyStatus:InSoloMode())
    elseif self.db.profile.playerFrame.showType == FF.PLAYER_FRAME_SHOW_TYPES.Never then
        PlayerFrame:SetShown(false)
    else
        PlayerFrame:SetShown(true)
    end
end

function FF:ShowPartyFrameTitleIfNeeded()
    if not CompactPartyFrame then return end
    CompactPartyFrame.title:SetShown(self.db.profile.partyFrame.showTitle)
end

function FF:GetAuraCountdownFontSize()
    local defaultSize = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.countdownFontSize) or 12
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local size = Utils:ClampNumber(profile and profile.countdownFontSize, 8, 32, defaultSize)

    return math.floor(size + 0.5)
end

function FF:ApplyAuraCountdownFontSizeToCooldown(cooldown)
    local fontString = Utils:GetCooldownCountdownFontString(cooldown)

    if not fontString then
        return
    end

    local fontFile, _, flags = fontString:GetFont()
    if not fontFile then
        return
    end

    pcall(fontString.SetFont, fontString, fontFile, self:GetAuraCountdownFontSize(), flags)
end

function FF:ApplyAuraCountdownFontSizeForFrame(frame)
    if not frame then
        return
    end

    if frame.buffFrames then
        for _, buffFrame in ipairs(frame.buffFrames) do
            local cooldown = buffFrame and buffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownFontSizeToCooldown(cooldown)
            end
        end
    end

    if frame.debuffFrames then
        for _, debuffFrame in ipairs(frame.debuffFrames) do
            local cooldown = debuffFrame and debuffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownFontSizeToCooldown(cooldown)
            end
        end
    end
end

function FF:UpdateAuraCountdownFontSize()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyAuraCountdownFontSizeForFrame(frame)
    end
end

local statusTextAnchorPoints = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local statusTextAnchorTargets = {
    FRAME = true,
    HEALTHBAR = true,
}

function FF:GetStatusTextAnchorTarget()
    local defaultTarget = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget) or "FRAME"
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local target = profile and profile.statusTextAnchorTarget

    if statusTextAnchorTargets[target] then
        return target
    end

    return defaultTarget
end

function FF:GetStatusTextAnchorPoint()
    local defaultPoint = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint) or "CENTER"
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local point = profile and profile.statusTextAnchorPoint

    if statusTextAnchorPoints[point] then
        return point
    end

    return defaultPoint
end

function FF:GetStatusTextAnchorOffsets()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame) or {}
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame

    local offsetX = Utils:ClampNumber(profile and profile.statusTextOffsetX, -100, 100, defaults.statusTextOffsetX or 0)
    local offsetY = Utils:ClampNumber(profile and profile.statusTextOffsetY, -100, 100, defaults.statusTextOffsetY or 0)

    return math.floor(offsetX + 0.5), math.floor(offsetY + 0.5)
end

function FF:ApplyStatusTextAnchorForFrame(frame)
    local statusText = frame and frame.statusText
    if not (statusText and statusText.ClearAllPoints and statusText.SetPoint) then
        return
    end

    local point = self:GetStatusTextAnchorPoint()
    local target = self:GetStatusTextAnchorTarget()
    local relativeTo = frame
    if target == "HEALTHBAR" and frame.healthBar then
        relativeTo = frame.healthBar
    end
    local offsetX, offsetY = self:GetStatusTextAnchorOffsets()

    local xOffset = offsetX
    local yOffset = offsetY

    if point == "TOPLEFT" or point == "LEFT" or point == "BOTTOMLEFT" then
        xOffset = -offsetX
    end

    if point == "TOPLEFT" or point == "TOP" or point == "TOPRIGHT" then
        yOffset = -offsetY
    end

    statusText:ClearAllPoints()
    pcall(statusText.SetPoint, statusText, point, relativeTo, point, xOffset, yOffset)
end

function FF:UpdateStatusTextAnchoring()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyStatusTextAnchorForFrame(frame)
    end
end

function FF:GetStatusTextColor()
    local defaultColor = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusTextColor)
        or { r = 1, g = 1, b = 1, a = 1 }
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local color = profile and profile.statusTextColor

    local r = Utils:ClampNumber(color and color.r, 0, 1, defaultColor.r or 1)
    local g = Utils:ClampNumber(color and color.g, 0, 1, defaultColor.g or 1)
    local b = Utils:ClampNumber(color and color.b, 0, 1, defaultColor.b or 1)
    local a = Utils:ClampNumber(color and color.a, 0, 1, defaultColor.a or 1)

    return r, g, b, a
end

function FF:ApplyStatusTextColorForFrame(frame)
    local statusText = frame and frame.statusText

    if not (statusText and statusText.SetTextColor) then
        return
    end

    local r, g, b, a = self:GetStatusTextColor()
    pcall(statusText.SetTextColor, statusText, r, g, b, a)
end

function FF:UpdateStatusTextColor()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyStatusTextColorForFrame(frame)
    end
end

function FF:ApplyStatusTextSettingsForFrame(frame)
    self:ApplyStatusTextAnchorForFrame(frame)
    self:ApplyStatusTextColorForFrame(frame)
    self:ApplyHealthTextFontSizeForFrame(frame)
end

function FF:ApplyStatusTextSettings()
    if not CompactPartyFrame then
        return
    end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyStatusTextSettingsForFrame(frame)
    end
end

function FF:RequestStatusTextSettingsRefresh()
    if self._ffStatusTextSettingsRefreshQueued then
        return
    end

    self._ffStatusTextSettingsRefreshQueued = true

    local function ApplyNow()
        self._ffStatusTextSettingsRefreshQueued = false
        self:ApplyStatusTextSettings()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyNow)

        -- Second pass wins races when Blizzard applies its own defaults later.
        C_Timer.After(0.15, function()
            self:ApplyStatusTextSettings()
        end)
    else
        ApplyNow()
    end
end

function FF:GetPlayerNameAnchorTarget()
    local defaultTarget = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget) or "FRAME"
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local target = profile and profile.playerNameAnchorTarget

    if statusTextAnchorTargets[target] then
        return target
    end

    return defaultTarget
end

function FF:GetPlayerNameAnchorPoint()
    local defaultPoint = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint) or "TOPLEFT"
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local point = profile and profile.playerNameAnchorPoint

    if statusTextAnchorPoints[point] then
        return point
    end

    return defaultPoint
end

function FF:GetPlayerNameAnchorOffsets()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame) or {}
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame

    local offsetX = Utils:ClampNumber(profile and profile.playerNameOffsetX, -100, 100, defaults.playerNameOffsetX or 0)
    local offsetY = Utils:ClampNumber(profile and profile.playerNameOffsetY, -100, 100, defaults.playerNameOffsetY or 0)

    return math.floor(offsetX + 0.5), math.floor(offsetY + 0.5)
end

function FF:ApplyPlayerNameAnchorForFrame(frame)
    local nameText = frame and frame.name
    if not (nameText and nameText.ClearAllPoints and nameText.SetPoint) then
        return
    end

    local point = self:GetPlayerNameAnchorPoint()
    local target = self:GetPlayerNameAnchorTarget()
    local relativeTo = frame
    if target == "HEALTHBAR" and frame.healthBar then
        relativeTo = frame.healthBar
    end
    local offsetX, offsetY = self:GetPlayerNameAnchorOffsets()

    local xOffset = offsetX
    local yOffset = offsetY

    if point == "TOPLEFT" or point == "LEFT" or point == "BOTTOMLEFT" then
        xOffset = -offsetX
    end

    if point == "TOPLEFT" or point == "TOP" or point == "TOPRIGHT" then
        yOffset = -offsetY
    end

    nameText:ClearAllPoints()
    pcall(nameText.SetPoint, nameText, point, relativeTo, point, xOffset, yOffset)
end

function FF:UpdatePlayerNameAnchoring()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyPlayerNameAnchorForFrame(frame)
    end
end

function FF:GetPlayerNameColor()
    local defaultColor = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameColor)
        or { r = 1, g = 1, b = 1, a = 1 }
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local color = profile and profile.playerNameColor

    local r = Utils:ClampNumber(color and color.r, 0, 1, defaultColor.r or 1)
    local g = Utils:ClampNumber(color and color.g, 0, 1, defaultColor.g or 1)
    local b = Utils:ClampNumber(color and color.b, 0, 1, defaultColor.b or 1)
    local a = Utils:ClampNumber(color and color.a, 0, 1, defaultColor.a or 1)

    return r, g, b, a
end

function FF:ApplyPlayerNameColorForFrame(frame)
    local nameText = frame and frame.name

    if not (nameText and nameText.SetTextColor) then
        return
    end

    local r, g, b, a = self:GetPlayerNameColor()
    pcall(nameText.SetTextColor, nameText, r, g, b, a)
end

function FF:UpdatePlayerNameColor()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyPlayerNameColorForFrame(frame)
    end
end

function FF:GetPlayerNameFontSize()
    local defaultSize = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameFontSize) or 10
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local size = Utils:ClampNumber(profile and profile.playerNameFontSize, 8, 32, defaultSize)
    return math.floor(size + 0.5)
end

function FF:ApplyPlayerNameFontSizeForFrame(frame)
    local nameText = frame and frame.name

    if not (nameText and nameText.GetFont and nameText.SetFont) then
        return
    end

    local size = self:GetPlayerNameFontSize()

    local fontFile, _, flags = nameText:GetFont()
    if fontFile then
        pcall(nameText.SetFont, nameText, fontFile, size, flags)
    end
end

function FF:UpdatePlayerNameFontSize()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyPlayerNameFontSizeForFrame(frame)
    end
end

function FF:GetHealthTextFontSize()
    local defaultSize = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.healthTextFontSize) or 10
    local profile = self and self.db and self.db.profile and self.db.profile.partyFrame
    local size = Utils:ClampNumber(profile and profile.healthTextFontSize, 8, 32, defaultSize)
    return math.floor(size + 0.5)
end

function FF:ApplyHealthTextFontSizeForFrame(frame)
    local fontString = frame and frame.statusText

    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return
    end

    local size = self:GetHealthTextFontSize()

    local fontFile, _, flags = fontString:GetFont()
    if fontFile then
        pcall(fontString.SetFont, fontString, fontFile, size, flags)
    end
end

function FF:UpdateHealthTextFontSize()
    if not CompactPartyFrame then return end
    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ApplyHealthTextFontSizeForFrame(frame)
    end
end

function FF:ShowBuffCountdownIfNeededForFrame(frame)
    if not (frame and frame.buffFrames) then
        return
    end

    for _, buffFrame in ipairs(frame.buffFrames) do
        local cooldown = buffFrame and buffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not self.db.profile.partyFrame.showBuffCountdown)
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown)
        end
    end
end

function FF:ShowBuffCountdownIfNeeded()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ShowBuffCountdownIfNeededForFrame(frame)
    end
end

function FF:ShowDebuffCountdownIfNeededForFrame(frame)
    if not (frame and frame.debuffFrames) then
        return
    end

    for _, debuffFrame in ipairs(frame.debuffFrames) do
        local cooldown = debuffFrame and debuffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not self.db.profile.partyFrame.showDebuffCountdown)
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown)
        end
    end
end

function FF:ShowDebuffCountdownIfNeeded()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ShowDebuffCountdownIfNeededForFrame(frame)
    end
end

function FF:UpdateRoleIcon(frame)
    local role = UnitGroupRolesAssigned(frame.unit)
    if not frame.roleIcon and role then
        return
    end

    local show = (role == "TANK" and self.db.profile.partyFrame.showTankRoleIcon)
        or (role == "HEALER" and self.db.profile.partyFrame.showHealerRoleIcon)
        or (role == "DAMAGER" and self.db.profile.partyFrame.showDPSRoleIcon)

    if show then
        -- print("Hiding DPS role icon for frame:", frame:GetName(), "unit:", frame.unit, "role:", role)
        frame.roleIcon:Show()
    else
        -- print("Showing role icon for frame:", frame:GetName(), "unit:", frame.unit, "role:", role)
        frame.roleIcon:Hide()
    end
end

function FF:SlashCommand(input)
    local trimmedInput = input and input:trim()

    if not trimmedInput or trimmedInput == "" then
        FF:OpenSettings()
    elseif trimmedInput == "preview" or trimmedInput == "p" then
        FF:OpenSettings()
        FF:ToggleIncomingCastIndicatorPreview()
    else
        self:Print("Usage: /ff - open config")
    end
end

function FF:UpdateHealthBarTexture(healthBar)
    if not healthBar then
        Utils:Log("NO HEALTH BAR")
        return
    end
    local texture = self.db.profile.partyFrame.healthBarTexture
    if not texture or texture == FF.DEFAULT_TEXTURE then return end

    Utils:Log("FF:UpdateHealthBarTexture", healthBar)
    healthBar:SetStatusBarTexture(texture)
end

function FF:UpdateTextures(frame)
    self:UpdateHealthBarTexture(frame.healthBar)
end

function FF:UpdateFrame(frame)
    if frame:IsShown() then
        self:UpdateRoleIcon(frame)
    end

    self:ApplyPlayerNameAnchorForFrame(frame)
    self:ApplyPlayerNameColorForFrame(frame)
    self:ApplyPlayerNameFontSizeForFrame(frame)
    self:ApplyStatusTextSettingsForFrame(frame)
    self:UpdateTextures(frame)
end

function FF:GetFrames()
    if not CompactPartyFrame then return {} end
    return CompactPartyFrame.memberUnitFrames
end

function FF:UpdateFrames()
    local partyFrames = self:GetFrames()
    -- Utils:Log("FF:UpdateFrames", partyFrames)

    for _, frame in ipairs(partyFrames) do
        self:UpdateFrame(frame)
    end
end

function FF:SetupFrames()
    self:SetAllowAnyAnchoring()
    self:ShowBuffCountdownIfNeeded()
    self:ShowDebuffCountdownIfNeeded()
    self:UpdateAuraCountdownFontSize()
    self:UpdatePlayerNameAnchoring()
    self:UpdatePlayerNameColor()
    self:UpdatePlayerNameFontSize()
    self:ApplyStatusTextSettings()
    self:RequestStatusTextSettingsRefresh()
    self:ShowPartyFrameTitleIfNeeded()
    self:ShowPlayerFrameIfNeeded()
    self:UpdateFrames()

    self:SetupIncomingCastIndicators()
    self:UpdateIncomingCastIndicators()
end
