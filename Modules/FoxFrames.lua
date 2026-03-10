local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames

function FF:InAllowedGroup()
    if PartyStatus:InRaidGroup() then return true end
    return BlizzardSettings:GetUseRaidStylePartyFrames() and PartyStatus:InPartyGroup()
end

function FF:IsPlayerFrame(frame)
    if not (frame and frame.unit) then
        return false
    end

    return UnitIsUnit(frame.unit, "player")
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
    if not input or input:trim() == "" then
        --LibStub("AceConfigDialog-3.0"):Open("FoxFrames")
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
    Utils:Log("FF:UpdateFrames", partyFrames)

    for _, frame in ipairs(partyFrames) do
        self:UpdateFrame(frame)
    end
end

function FF:SetupFrames()
    self:SetAlwaysUseTopLeftAnchor()
    self:ShowBuffCountdownIfNeeded()
    self:ShowPartyFrameTitleIfNeeded()
    self:ShowPlayerFrameIfNeeded()
    self:UpdateFrames()
end