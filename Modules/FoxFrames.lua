local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon and addon.Utils

local function GetAuraCountdownFontString(cooldown)
    if not (cooldown and cooldown.GetCountdownFontString) then
        return nil
    end

    local fontString = cooldown:GetCountdownFontString()
    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return nil
    end

    return fontString
end

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
    local size = profile and profile.countdownFontSize

    if type(size) ~= "number" then
        size = tonumber(size)
    end
    if type(size) ~= "number" then
        size = defaultSize
    end

    if size < 8 then
        size = 8
    elseif size > 32 then
        size = 32
    end

    return math.floor(size + 0.5)
end

function FF:ApplyAuraCountdownFontSizeToCooldown(cooldown)
    local fontString = GetAuraCountdownFontString(cooldown)
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

function FF:ShowBuffCountdownIfNeededForFrame(frame)
    if not (frame and frame.buffFrames) then
        return
    end

    for _, buffFrame in ipairs(frame.buffFrames) do
        local cooldown = buffFrame and buffFrame.cooldown
        if cooldown then
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(not self.db.profile.partyFrame.showBuffCountdown)
            end
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
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(not self.db.profile.partyFrame.showDebuffCountdown)
            end
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
    self:ShowPartyFrameTitleIfNeeded()
    self:ShowPlayerFrameIfNeeded()
    self:UpdateFrames()

    self:SetupIncomingCastIndicators()
    self:UpdateIncomingCastIndicators()
end
