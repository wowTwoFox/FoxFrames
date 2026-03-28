local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon.Utils
local Blizzard = addon.Blizzard
local DB = addon.DB

function FF:InAllowedGroup()
    if Blizzard:InRaidGroup() then return true end
    return BlizzardSettings:GetUseRaidStylePartyFrames() and Blizzard:InPartyGroup()
end

function FF:IsPlayerUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return false
    end

    return UnitIsUnit(unit, "player")
end

function FF:SetAllowAnyAnchoring()
    local alwaysUseTopLeftAnchor = not DB:GetAllowAnyAnchoring()

    if PartyFrame then
        PartyFrame.alwaysUseTopLeftAnchor = alwaysUseTopLeftAnchor
    end

    -- Raid-style party frames / raid frames use CompactRaidFrameContainer.
    if CompactRaidFrameContainer and CompactRaidFrameContainer.alwaysUseTopLeftAnchor ~= nil then
        CompactRaidFrameContainer.alwaysUseTopLeftAnchor = alwaysUseTopLeftAnchor
    end
end

function FF:ShowPartyFrameIfNeeded()
    if not Blizzard:InSoloMode() then return end
    if not CompactPartyFrame then return end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    CompactPartyFrame:SetShown(DB:GetShowInSolo())
end

function FF:ShowPlayerFrameIfNeeded()
    if not PlayerFrame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local showType = DB:GetPlayerFrameShowType()
    local shouldShow

    if showType == DB.PLAYER_FRAME_SHOW_TYPES.SOLO then
        shouldShow = Blizzard:InSoloMode()
    else
        shouldShow = showType == DB.PLAYER_FRAME_SHOW_TYPES.ALWAYS
    end

    PlayerFrame:SetAlpha(shouldShow and 1 or 0)
    PlayerFrame:EnableMouse(shouldShow)
    PlayerFrame:EnableMouseWheel(shouldShow)
    PlayerFrame:EnableKeyboard(shouldShow)
end

function FF:ShowPartyFrameTitleIfNeeded()
    if not CompactPartyFrame then return end
    CompactPartyFrame.title:SetShown(DB:GetShowPartyFrameTitle())
end

function FF:ApplyAuraCountdownFontSizeToCooldown(cooldown, fontSize)
    local fontString = Utils:GetCooldownCountdownFontString(cooldown)

    if not fontString then
        return
    end

    local fontFile, _, flags = fontString:GetFont()
    if not fontFile then
        return
    end

    local size = fontSize
    if type(size) ~= "number" then
        return
    end

    pcall(fontString.SetFont, fontString, fontFile, size, flags)
end

function FF:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
    local fontString = Utils:GetCooldownCountdownFontString(cooldown)

    if not (fontString and fontString.SetTextColor) then
        return
    end

    pcall(fontString.SetTextColor, fontString, r, g, b)
end

function FF:ApplyAuraCountdownFontSizeForFrame(frame)
    if not frame then
        return
    end

    if frame.buffFrames then
        local buffFontSize = DB:GetBuffCountdownFontSize()
        for _, buffFrame in ipairs(frame.buffFrames) do
            local cooldown = buffFrame and buffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownFontSizeToCooldown(cooldown, buffFontSize)
            end
        end
    end

    if frame.debuffFrames then
        local debuffFontSize = DB:GetDebuffCountdownFontSize()
        for _, debuffFrame in ipairs(frame.debuffFrames) do
            local cooldown = debuffFrame and debuffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownFontSizeToCooldown(cooldown, debuffFontSize)
            end
        end
    end
end

function FF:ApplyAuraCountdownColorForFrame(frame)
    if not frame then
        return
    end

    if frame.buffFrames then
        local r, g, b = DB:GetBuffCountdownColor()
        for _, buffFrame in ipairs(frame.buffFrames) do
            local cooldown = buffFrame and buffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
            end
        end
    end

    if frame.debuffFrames then
        local r, g, b = DB:GetDebuffCountdownColor()
        for _, debuffFrame in ipairs(frame.debuffFrames) do
            local cooldown = debuffFrame and debuffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
            end
        end
    end
end

function FF:UpdateAuraCountdownFontSize()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyAuraCountdownFontSizeForFrame(frame)
    end
end

function FF:UpdateAuraCountdownColor()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ApplyAuraCountdownColorForFrame(frame)
    end
end

function FF:ShowBuffCountdownIfNeededForFrame(frame)
    if not (frame and frame.buffFrames) then
        return
    end

    local show = DB:GetShowBuffCountdown()
    local fontSize = DB:GetBuffCountdownFontSize()
    local r, g, b = DB:GetBuffCountdownColor()

    for _, buffFrame in ipairs(frame.buffFrames) do
        local cooldown = buffFrame and buffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not show)
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown, fontSize)
            self:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
        end
    end
end

function FF:ShowBuffCountdownIfNeeded()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ShowBuffCountdownIfNeededForFrame(frame)
    end
end

function FF:ShowDebuffCountdownIfNeededForFrame(frame)
    if not (frame and frame.debuffFrames) then
        return
    end

    local show = DB:GetShowDebuffCountdown()
    local fontSize = DB:GetDebuffCountdownFontSize()
    local r, g, b = DB:GetDebuffCountdownColor()

    for _, debuffFrame in ipairs(frame.debuffFrames) do
        local cooldown = debuffFrame and debuffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not show)
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown, fontSize)
            self:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
        end
    end
end

function FF:ShowDebuffCountdownIfNeeded()
    for _, frame in ipairs(Blizzard:GetFrames()) do
        self:ShowDebuffCountdownIfNeededForFrame(frame)
    end
end

function FF:UpdateRoleIcon(frame)
    if not (frame and type(frame.unit) == "string" and frame.unit ~= "") then
        return
    end

    local role = UnitGroupRolesAssigned(frame.unit)
    if not frame.roleIcon then
        return
    end

    if DB:GetShowRoleIcon(role) then
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
        FF:ToggleIncomingCastIndicatorPreview()
    elseif trimmedInput == "c" or trimmedInput == "casts" then
        FF:OpenIncomingCastsSettings()
    else
        self:Print(
            Utils:C("ffd100", "Usage: \n") ..
            Utils:C("80c0ff", "/ff") .. " open config,\n" ..
            Utils:C("80c0ff", "/ff c") .. " or " .. Utils:C("80c0ff", "casts") .. " incoming casts settings, \n" ..
            Utils:C("80c0ff", "/ff p") .. " or " .. Utils:C("80c0ff", "preview") .. " preview incoming casts"
        )
    end
end

function FF:UpdateHealthBarTexture(healthBar)
    if not healthBar then
        Utils:Log("NO HEALTH BAR")
        return
    end

    local texture = DB:GetHealthBarTexture()
    if not texture then
        local originalTexture = healthBar._ffOriginalTexturePath
        if originalTexture then
            healthBar:SetStatusBarTexture(originalTexture)
            healthBar._ffOriginalTexturePath = nil
        end
        return
    end

    if not healthBar._ffOriginalTexturePath then
        local currentTexture = Utils:EnsureTexturePath(healthBar)
        if currentTexture and currentTexture ~= texture then
            healthBar._ffOriginalTexturePath = currentTexture
        end
    end

    healthBar:SetStatusBarTexture(texture)
end

function FF:UpdateTextures(frame)
    self:UpdateHealthBarTexture(frame.healthBar)
end

function FF:UpdateFrame(frame)
    -- Utils:Log("FF_UPDATE_FRAME", frame)
    if frame:IsShown() then
        self:UpdateRoleIcon(frame)
    end

    self:ApplyPlayerStatusSettingsForFrame(frame)
    self:ApplyPlayerNameSettingsForFrame(frame)
    self:UpdateTextures(frame)
end

function FF:UpdateFrames()
    local partyFrames = Blizzard:GetFrames()
    Utils:Log("FF:UpdateFrames", partyFrames)

    for _, frame in ipairs(partyFrames) do
        self:UpdateFrame(frame)
    end
end

function FF:SetupFrames()
    self:SetAllowAnyAnchoring()
    self:ShowBuffCountdownIfNeeded()
    self:ShowDebuffCountdownIfNeeded()
    self:UpdateAuraCountdownFontSize()
    self:ApplyPlayerStatusSettings()
    self:ApplyPlayerNameSettings()
    self:ShowPartyFrameTitleIfNeeded()
    self:ShowPlayerFrameIfNeeded()
    self:UpdateFrames()

    self:SetupIncomingCastIndicators()
    self:UpdateIncomingCastIndicators()
end
