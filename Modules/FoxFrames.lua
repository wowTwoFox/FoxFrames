local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon.Utils
local Blizzard = addon.Blizzard
local DB = addon.DB

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
    CompactPartyFrame:SetShown(DB:GetShowInSolo())
end

function FF:ShowPlayerFrameIfNeeded()
    if not PlayerFrame then
        return
    end

    local showType = DB:GetPlayerFrameShowType()

    if showType == DB.PLAYER_FRAME_SHOW_TYPES.SOLO then
        PlayerFrame:SetShown(Blizzard:InSoloMode())
    else
        PlayerFrame:SetShown(showType == DB.PLAYER_FRAME_SHOW_TYPES.ALWAYS)
    end
end

function FF:ShowPartyFrameTitleIfNeeded()
    if not CompactPartyFrame then return end
    CompactPartyFrame.title:SetShown(DB:GetShowPartyFrameTitle())
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

    local fontSize = DB:GetAuraCountdownFontSize()
    pcall(fontString.SetFont, fontString, fontFile, fontSize, flags)
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
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyAuraCountdownFontSizeForFrame(frame)
    end
end

function FF:IsManagedPartyFrame(frame)
    return Blizzard:IsManagedPartyFrame(frame)
end

function FF:ApplyStatusTextAnchorForFrame(frame)
    if not self:IsManagedPartyFrame(frame) then
        return
    end

    local statusText = frame and frame.statusText
    if not (statusText and statusText.ClearAllPoints and statusText.SetPoint) then
        return
    end

    local point = DB:GetStatusTextAnchorPoint()
    local target = DB:GetStatusTextAnchorTarget()
    local relativeTo = frame
    if target == DB.FRAME_ANCHOR_TARGETS.HEALTHBAR and frame.healthBar then
        relativeTo = frame.healthBar
    end
    local offsetX, offsetY = DB:GetStatusTextAnchorOffsets()

    local xOffset = offsetX
    local yOffset = offsetY

    if point == DB.ANCHOR_POINTS.TOPLEFT or point == DB.ANCHOR_POINTS.LEFT or point == DB.ANCHOR_POINTS.BOTTOMLEFT then
        xOffset = -offsetX
    end

    if point == DB.ANCHOR_POINTS.TOPLEFT or point == DB.ANCHOR_POINTS.TOP or point == DB.ANCHOR_POINTS.TOPRIGHT then
        yOffset = -offsetY
    end

    statusText:ClearAllPoints()
    pcall(statusText.SetPoint, statusText, point, relativeTo, point, xOffset, yOffset)
end

function FF:UpdateStatusTextAnchoring()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyStatusTextAnchorForFrame(frame)
    end
end

function FF:ApplyStatusTextColorForFrame(frame)
    if not self:IsManagedPartyFrame(frame) then
        return
    end

    local statusText = frame and frame.statusText

    if not (statusText and statusText.SetTextColor) then
        return
    end

    if DB:GetStatusTextUseClassColors() then
        local classR, classG, classB = Blizzard:GetClassColorForUnit(frame and frame.unit)
        if classR and classG and classB then
            local _, _, _, alpha = DB:GetStatusTextColor()
            pcall(statusText.SetTextColor, statusText, classR, classG, classB, alpha)
            return
        end
    end

    local r, g, b, a = DB:GetStatusTextColor()
    pcall(statusText.SetTextColor, statusText, r, g, b, a)
end

function FF:UpdateStatusTextColor()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyStatusTextColorForFrame(frame)
    end
end

function FF:ApplyStatusTextSettingsForFrame(frame)
    self:ApplyStatusTextAnchorForFrame(frame)
    self:ApplyStatusTextColorForFrame(frame)
    self:ApplyHealthTextFontSizeForFrame(frame)
end

function FF:ApplyStatusTextSettings()
    for _, frame in ipairs(self:GetFrames()) do
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

    local point = DB:GetPlayerNameAnchorPoint()
    local target = DB:GetPlayerNameAnchorTarget()
    local relativeTo = frame
    if target == DB.FRAME_ANCHOR_TARGETS.HEALTHBAR and frame.healthBar then
        relativeTo = frame.healthBar
    end
    local offsetX, offsetY = DB:GetPlayerNameAnchorOffsets()

    local xOffset = offsetX
    local yOffset = offsetY

    if point == DB.ANCHOR_POINTS.TOPLEFT or point == DB.ANCHOR_POINTS.LEFT or point == DB.ANCHOR_POINTS.BOTTOMLEFT then
        xOffset = -offsetX
    end

    if point == DB.ANCHOR_POINTS.TOPLEFT or point == DB.ANCHOR_POINTS.TOP or point == DB.ANCHOR_POINTS.TOPRIGHT then
        yOffset = -offsetY
    end

    pcall(nameText.ClearAllPoints, nameText)
    pcall(nameText.SetPoint, nameText, point, relativeTo, point, xOffset, yOffset)
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

    if DB:GetPlayerNameUseClassColors() then
        local classR, classG, classB = Blizzard:GetClassColorForUnit(frame and frame.unit)
        if classR and classG and classB then
            local _, _, _, alpha = DB:GetPlayerNameColor()
            pcall(nameText.SetTextColor, nameText, classR, classG, classB, alpha)
            return
        end
    end

    local r, g, b, a = DB:GetPlayerNameColor()
    pcall(nameText.SetTextColor, nameText, r, g, b, a)
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

    local size = DB:GetPlayerNameFontSize()

    local fontFile, _, flags = nameText:GetFont()
    if fontFile then
        pcall(nameText.SetFont, nameText, fontFile, size, flags)
    end
end

function FF:UpdatePlayerNameFontSize()
    for _, frame in ipairs(self:GetFrames()) do
        self:ApplyPlayerNameFontSizeForFrame(frame)
    end
end

function FF:ApplyHealthTextFontSizeForFrame(frame)
    if not self:IsManagedPartyFrame(frame) then
        return
    end

    local fontString = frame and frame.statusText

    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return
    end

    local size = DB:GetHealthTextFontSize()

    local fontFile, _, flags = fontString:GetFont()
    if fontFile then
        pcall(fontString.SetFont, fontString, fontFile, size, flags)
    end
end

function FF:UpdateHealthTextFontSize()
    for _, frame in ipairs(self:GetFrames()) do
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
            Utils:SetHideCountdownNumbersSafe(cooldown, not DB:GetShowBuffCountdown())
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown)
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

    for _, debuffFrame in ipairs(frame.debuffFrames) do
        local cooldown = debuffFrame and debuffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not DB:GetShowDebuffCountdown())
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown)
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

    self:ApplyPlayerNameAnchorForFrame(frame)
    self:ApplyPlayerNameColorForFrame(frame)
    self:ApplyPlayerNameFontSizeForFrame(frame)
    self:ApplyStatusTextSettingsForFrame(frame)
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
