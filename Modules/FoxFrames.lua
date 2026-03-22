local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon.Utils
local Blizzard = addon.Blizzard
local DB = addon.DB
local Constants = addon.Constants

local function GetStatusBarTexturePath(healthBar)
    if not (healthBar and healthBar.GetStatusBarTexture) then
        return nil
    end

    local textureObject = healthBar:GetStatusBarTexture()
    if not (textureObject and textureObject.GetTexture) then
        return nil
    end

    local ok, textureRef = pcall(textureObject.GetTexture, textureObject)
    if not ok then
        return nil
    end

    if type(textureRef) == "number" then
        return textureRef
    end

    if type(textureRef) == "string" and textureRef ~= "" then
        return textureRef
    end

    return nil
end

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

function FF:IsPlayerFrame(frame)
    return self:IsPlayerUnit(frame and frame.unit)
end

function FF:SetAllowAnyAnchoring()
    if not PartyFrame then return end
    PartyFrame.alwaysUseTopLeftAnchor = not DB:GetAllowAnyAnchoring()
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
        size = DB:GetAuraCountdownFontSize()
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
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyAuraCountdownFontSizeForFrame(frame)
    end
end

function FF:UpdateAuraCountdownColor()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyAuraCountdownColorForFrame(frame)
    end
end

function FF:IsManagedPartyFrame(frame)
    return Blizzard:IsManagedPartyFrame(frame)
end

function FF:ApplyPlayerStatusAnchorForFrame(frame)
    if not self:IsManagedPartyFrame(frame) then
        return
    end

    local statusText = frame and frame.statusText
    if not (statusText and statusText.ClearAllPoints and statusText.SetPoint) then
        return
    end

    if not DB:GetPlayerStatusFrameCustomize() then
        if statusText._ffPointCustomized then
            Utils:RevertCustomPoint(statusText)
        end
        return
    end

    local layoutAxis = Blizzard:GetPartyFramesLayoutAxis()
    local point, relativePoint, target, offsetX, offsetY = DB:GetPlayerStatusAnchorsAndOffsets(layoutAxis)
    local relativeTo = frame
    if target == DB.FRAME_ANCHOR_TARGETS.HEALTHBAR and frame.healthBar then
        relativeTo = frame.healthBar
    end

    Utils:RevertingClearAllPoints(statusText)
    Utils:SetRevertingPoint(statusText, point, relativeTo, relativePoint, offsetX, offsetY)
end

function FF:UpdatePlayerStatusAnchoring()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerStatusAnchorForFrame(frame)
    end
end

function FF:ApplyPlayerStatusColorForFrame(frame)
    if not self:IsManagedPartyFrame(frame) then
        return
    end

    local statusText = frame and frame.statusText

    if not (statusText and statusText.SetTextColor) then
        return
    end

    if not DB:GetPlayerStatusTextCustomize() then
        if statusText._ffFontColorCustomized then
            Utils:RevertCustomFontColor(statusText)
        end
        return
    end

    if DB:GetPlayerStatusUseClassColors() then
        local classR, classG, classB = Blizzard:GetClassColorForUnit(frame and frame.unit)
        if classR and classG and classB then
            local _, _, _, alpha = DB:GetPlayerStatusColor()
            Utils:SetRevertingTextColor(statusText, classR, classG, classB, alpha)
            return
        end
    end

    local r, g, b, a = DB:GetPlayerStatusColor()
    Utils:SetRevertingTextColor(statusText, r, g, b, a)
end

function FF:UpdatePlayerStatusColor()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerStatusColorForFrame(frame)
    end
end

function FF:ApplyPlayerStatusSettingsForFrame(frame)
    self:ApplyPlayerStatusAnchorForFrame(frame)
    self:ApplyPlayerStatusColorForFrame(frame)
    self:ApplyPlayerStatusFontSizeForFrame(frame)
end

function FF:ApplyPlayerStatusSettings()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerStatusSettingsForFrame(frame)
    end
end

function FF:GetPlayerNameFontString(frame)
    if not self:IsManagedPartyFrame(frame) then
        return nil
    end

    local nameText = frame and frame.name
    if not nameText then
        return nil
    end

    if nameText.IsObjectType then
        local ok, isFontString = pcall(nameText.IsObjectType, nameText, "FontString")
        if ok and isFontString then
            return nameText
        end

        return nil
    end

    if nameText.GetObjectType then
        local ok, objectType = pcall(nameText.GetObjectType, nameText)
        if ok and objectType == "FontString" then
            return nameText
        end
    end

    return nil
end

function FF:ApplyPlayerNameAnchorForFrame(frame)
    local nameText = self:GetPlayerNameFontString(frame)
    if not (nameText and nameText.ClearAllPoints and nameText.SetPoint) then
        return
    end

    if not DB:GetPlayerNameFrameCustomize() then
        if nameText._ffPointCustomized then
            Utils:RevertCustomPoint(nameText)
        end
        return
    end

    local layoutAxis = Blizzard:GetPartyFramesLayoutAxis()
    local point, relativePoint, target, offsetX, offsetY = DB:GetPlayerNameAnchorsAndOffsets(layoutAxis)
    local relativeTo = frame
    if target == DB.FRAME_ANCHOR_TARGETS.HEALTHBAR and frame.healthBar then
        relativeTo = frame.healthBar
    end

    Utils:RevertingClearAllPoints(nameText)
    Utils:SetRevertingPoint(nameText, point, relativeTo, relativePoint, offsetX, offsetY)
end

function FF:UpdatePlayerNameAnchoring()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerNameAnchorForFrame(frame)
    end
end

function FF:ApplyPlayerNameColorForFrame(frame)
    local nameText = self:GetPlayerNameFontString(frame)

    if not (nameText and nameText.SetTextColor) then
        return
    end

    if not DB:GetPlayerNameTextCustomize() then
        if nameText._ffFontColorCustomized then
            Utils:RevertCustomFontColor(nameText)
        end
        return
    end

    if DB:GetPlayerNameUseClassColors() then
        local classR, classG, classB = Blizzard:GetClassColorForUnit(frame and frame.unit)
        if classR and classG and classB then
            local _, _, _, alpha = DB:GetPlayerNameColor()
            Utils:SetRevertingTextColor(nameText, classR, classG, classB, alpha)
            return
        end
    end

    local r, g, b, a = DB:GetPlayerNameColor()
    Utils:SetRevertingTextColor(nameText, r, g, b, a)
end

function FF:UpdatePlayerNameColor()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerNameColorForFrame(frame)
    end
end

function FF:ApplyPlayerNameFontSizeForFrame(frame)
    local nameText = self:GetPlayerNameFontString(frame)

    if not (nameText and nameText.GetFont and nameText.SetFont) then
        return
    end

    if not DB:GetPlayerNameTextCustomize() then
        if nameText._ffFontCustomized then
            Utils:RevertCustomFont(nameText)
        end
        return
    end

    local size = DB:GetPlayerNameFontSize()
    local fontFile, _, flags = nameText:GetFont()
    if flags ~= nil then
        Utils:SetRevertingFont(nameText, fontFile, size, flags)
    else
        Utils:SetRevertingFont(nameText, fontFile, size)
    end
end

function FF:UpdatePlayerNameFontSize()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerNameFontSizeForFrame(frame)
    end
end

function FF:ApplyPlayerNameSettingsForFrame(frame)
    self:ApplyPlayerNameAnchorForFrame(frame)
    self:ApplyPlayerNameColorForFrame(frame)
    self:ApplyPlayerNameFontSizeForFrame(frame)
end

function FF:ApplyPlayerNameSettings()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerNameSettingsForFrame(frame)
    end
end

function FF:ApplyPlayerStatusFontSizeForFrame(frame)
    if not self:IsManagedPartyFrame(frame) then
        return
    end

    local fontString = frame and frame.statusText

    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return
    end

    if not DB:GetPlayerStatusTextCustomize() then
        if fontString._ffFontCustomized then
            Utils:RevertCustomFont(fontString)
        end
        return
    end

    local size = DB:GetPlayerStatusFontSize()
    local fontFile, _, flags = fontString:GetFont()
    if flags ~= nil then
        Utils:SetRevertingFont(fontString, fontFile, size, flags)
    else
        Utils:SetRevertingFont(fontString, fontFile, size)
    end
end

function FF:UpdatePlayerStatusFontSize()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerStatusFontSizeForFrame(frame)
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
    for _, frame in ipairs(self:GetFrames()) do
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
    for _, frame in ipairs(self:GetFrames()) do
        self:ShowDebuffCountdownIfNeededForFrame(frame)
    end
end

function FF:UpdateRoleIcon(frame)
    local role = UnitGroupRolesAssigned(frame.unit)
    if not frame.roleIcon and role then
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
        local currentTexture = GetStatusBarTexturePath(healthBar)
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
    if frame:IsShown() then
        self:UpdateRoleIcon(frame)
    end

    self:ApplyPlayerStatusSettingsForFrame(frame)
    self:ApplyPlayerNameSettingsForFrame(frame)
    self:UpdateTextures(frame)
end

function FF:GetFrames()
    return Blizzard:GetFrames()
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
    self:ApplyPlayerStatusSettings()
    self:ApplyPlayerNameSettings()
    self:ShowPartyFrameTitleIfNeeded()
    self:ShowPlayerFrameIfNeeded()
    self:UpdateFrames()

    self:SetupIncomingCastIndicators()
    self:UpdateIncomingCastIndicators()
end
