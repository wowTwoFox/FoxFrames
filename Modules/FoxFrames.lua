local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon and addon.Utils

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

function FF:SetAlwaysUseTopLeftAnchor()
    if not PartyFrame then return end
    PartyFrame.alwaysUseTopLeftAnchor = self.db.profile.partyFrame.forceTopLeftAnchor
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

function FF:ShowBuffCountdownIfNeededForFrame(frame)
    if not (frame and frame.buffFrames) then
        return
    end

    for _, buffFrame in ipairs(frame.buffFrames) do
        buffFrame.cooldown:SetHideCountdownNumbers(not self.db.profile.partyFrame.showBuffCountdown)
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
        if debuffFrame and debuffFrame.cooldown and debuffFrame.cooldown.SetHideCountdownNumbers then
            debuffFrame.cooldown:SetHideCountdownNumbers(not self.db.profile.partyFrame.showDebuffCountdown)
        end
    end
end

function FF:ShowDebuffCountdownIfNeeded()
    if not CompactPartyFrame then return end

    for _, frame in ipairs(CompactPartyFrame.memberUnitFrames) do
        self:ShowDebuffCountdownIfNeededForFrame(frame)
    end
end

local function NormalizeSpellRuleSpellId(value)
    local num = tonumber(value)
    if type(num) ~= "number" then
        return nil
    end

    num = math.floor(num + 0.5)
    if num <= 0 then
        return nil
    end

    return tostring(num)
end

local function GetAuraFrameSpellId(unit, auraFrame)
    if not auraFrame then
        return nil
    end

    local directSpellId = auraFrame.spellID or auraFrame.spellId or auraFrame.auraSpellID
    if type(directSpellId) == "number" and directSpellId > 0 then
        return directSpellId
    end

    local auraInstanceID = auraFrame.auraInstanceID or auraFrame.displayedAuraInstanceID or auraFrame.AuraInstanceID
    if auraInstanceID and type(unit) == "string" and unit ~= "" and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
        local auraSpellId = auraData and auraData.spellId
        if type(auraSpellId) == "number" and auraSpellId > 0 then
            return auraSpellId
        end
    end

    return nil
end

local function ApplySpellRuleVisibilityToAuraFrame(auraFrame, shouldHide)
    if not auraFrame then
        return
    end

    if shouldHide then
        auraFrame.ffSpellRuleHidden = true
        if auraFrame.Hide then
            auraFrame:Hide()
        end
        return
    end

    if auraFrame.ffSpellRuleHidden then
        auraFrame.ffSpellRuleHidden = nil
        if auraFrame.Show and auraFrame.icon and auraFrame.icon.GetTexture and auraFrame.icon:GetTexture() then
            auraFrame:Show()
        end
    end
end

function FF:GetSpellRuleForSpellId(spellId)
    local normalizedSpellId = NormalizeSpellRuleSpellId(spellId)
    if not normalizedSpellId then
        return nil
    end

    local profile = self and self.db and self.db.profile
    local spellRulesProfile = profile and profile.spellRules
    local rules = spellRulesProfile and spellRulesProfile.rules
    if type(rules) ~= "table" then
        return nil
    end

    local rule = rules[normalizedSpellId]
    if type(rule) ~= "table" then
        return nil
    end

    return rule
end

function FF:ShouldHideSpellForRuleType(spellId, ruleKey)
    if type(ruleKey) ~= "string" or ruleKey == "" then
        return false
    end

    local rule = self:GetSpellRuleForSpellId(spellId)
    if type(rule) ~= "table" then
        return false
    end

    return rule[ruleKey] == true
end

function FF:ApplySpellRuleFiltersForFrame(frame)
    if not frame then
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if type(unit) ~= "string" or unit == "" then
        return
    end

    if frame.buffFrames then
        for _, auraFrame in ipairs(frame.buffFrames) do
            local spellId = GetAuraFrameSpellId(unit, auraFrame)
            local shouldHide = spellId and self:ShouldHideSpellForRuleType(spellId, "hideBuffs") or false
            ApplySpellRuleVisibilityToAuraFrame(auraFrame, shouldHide)
        end
    end

    if frame.debuffFrames then
        for _, auraFrame in ipairs(frame.debuffFrames) do
            local spellId = GetAuraFrameSpellId(unit, auraFrame)
            local shouldHide = spellId and self:ShouldHideSpellForRuleType(spellId, "hideDebuffs") or false
            ApplySpellRuleVisibilityToAuraFrame(auraFrame, shouldHide)
        end
    end
end

function FF:RefreshSpellRuleAuraFilters()
    local frames = self:GetFrames()
    for _, frame in ipairs(frames) do
        self:ApplySpellRuleFiltersForFrame(frame)
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
    self:SetAlwaysUseTopLeftAnchor()
    self:ShowBuffCountdownIfNeeded()
    self:ShowDebuffCountdownIfNeeded()
    self:ShowPartyFrameTitleIfNeeded()
    self:ShowPlayerFrameIfNeeded()
    self:UpdateFrames()
    self:RefreshSpellRuleAuraFilters()

    self:SetupIncomingCastIndicators()
    self:UpdateIncomingCastIndicators()
end
