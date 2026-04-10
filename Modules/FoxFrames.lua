local addonName, addon = ...

FoxFrames = LibStub("AceAddon-3.0"):NewAddon("FoxFrames", "AceConsole-3.0", "AceEvent-3.0")
local FF = FoxFrames
local Utils = addon.Utils
local Blizzard = addon.Blizzard
local DB = addon.DB
local Auras = addon.Auras

local AURA_COUNTDOWN_COLOR_UPDATE_INTERVAL_SECONDS = 0.10

local AURA_COUNTDOWN_COLOR_TYPE_NORMAL = 1
local AURA_COUNTDOWN_COLOR_TYPE_WARNING = 2
local AURA_COUNTDOWN_COLOR_TYPE_CRITICAL = 3

function FF:ApplyAuraCountdownDynamicColorToCooldown(cooldown, remainingSeconds, config)
    assert(cooldown, "FoxFrames: cooldown missing")
    assert(type(config) == "table", "FoxFrames: aura countdown config must be a table")

    local normalColor = assert(config.normalColor, "FoxFrames: aura countdown config.normalColor missing")
    local warningColor = assert(config.warningColor, "FoxFrames: aura countdown config.warningColor missing")
    local criticalColor = assert(config.criticalColor, "FoxFrames: aura countdown config.criticalColor missing")

    local warningThresholdSeconds = assert(config.warningThresholdSeconds, "FoxFrames: aura countdown config.warningThresholdSeconds missing")
    local criticalThresholdSeconds = assert(config.criticalThresholdSeconds, "FoxFrames: aura countdown config.criticalThresholdSeconds missing")

    local warningEnabled = assert(config.warningEnabled, "FoxFrames: aura countdown config.warningEnabled missing")
    local criticalEnabled = assert(config.criticalEnabled, "FoxFrames: aura countdown config.criticalEnabled missing")

    assert(type(normalColor) == "table", "FoxFrames: aura countdown config.normalColor must be a table")
    assert(type(warningColor) == "table", "FoxFrames: aura countdown config.warningColor must be a table")
    assert(type(criticalColor) == "table", "FoxFrames: aura countdown config.criticalColor must be a table")

    assert(type(warningThresholdSeconds) == "number", "FoxFrames: aura countdown config.warningThresholdSeconds must be a number")
    assert(type(criticalThresholdSeconds) == "number", "FoxFrames: aura countdown config.criticalThresholdSeconds must be a number")

    assert(type(warningEnabled) == "boolean", "FoxFrames: aura countdown config.warningEnabled must be a boolean")
    assert(type(criticalEnabled) == "boolean", "FoxFrames: aura countdown config.criticalEnabled must be a boolean")

    local colorType
    local r, g, b

    if type(remainingSeconds) ~= "number" then
        colorType = AURA_COUNTDOWN_COLOR_TYPE_NORMAL
        r, g, b = normalColor.r, normalColor.g, normalColor.b
    elseif criticalEnabled and remainingSeconds <= criticalThresholdSeconds then
        colorType = AURA_COUNTDOWN_COLOR_TYPE_CRITICAL
        r, g, b = criticalColor.r, criticalColor.g, criticalColor.b
    elseif warningEnabled and remainingSeconds <= warningThresholdSeconds then
        colorType = AURA_COUNTDOWN_COLOR_TYPE_WARNING
        r, g, b = warningColor.r, warningColor.g, warningColor.b
    else
        colorType = AURA_COUNTDOWN_COLOR_TYPE_NORMAL
        r, g, b = normalColor.r, normalColor.g, normalColor.b
    end

    if cooldown._ffCountdownColorType ~= colorType then
        self:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
        cooldown._ffCountdownColorType = colorType
    end
end

function FF:ApplyAuraCountdownDynamicColorToAuraFrames(unit, auraFrames, config)
    assert(type(auraFrames) == "table", "FoxFrames: auraFrames must be a table")
    assert(type(config) == "table", "FoxFrames: config must be a table")
    local normalColor = assert(config.normalColor, "FoxFrames: config.normalColor missing")
    assert(type(normalColor) == "table", "FoxFrames: config.normalColor must be a table")

    for _, auraFrame in ipairs(auraFrames) do
        local cooldown = auraFrame.cooldown or auraFrame.Cooldown

        if auraFrame:IsShown() then
            local auraInstanceID = auraFrame.auraInstanceID
            local remainingSeconds = Auras:GetRemainingSeconds(unit, auraInstanceID)
            self:ApplyAuraCountdownDynamicColorToCooldown(cooldown, remainingSeconds, config)
        else
            assert(cooldown, "FoxFrames: cooldown missing for hidden auraFrame")
            if cooldown._ffCountdownColorType ~= AURA_COUNTDOWN_COLOR_TYPE_NORMAL then
                self:ApplyAuraCountdownColorToCooldown(cooldown, normalColor.r, normalColor.g, normalColor.b)
            end
            cooldown._ffCountdownColorType = AURA_COUNTDOWN_COLOR_TYPE_NORMAL
        end
    end
end

function FF:UpdateAuraCountdownDynamicColorForFrame(frame)
    local unit = frame.unit

    -- Buffs
    if frame.buffFrames then
        local buffConfig = DB:GetBuffCountdownDynamicColorConfig()
        self:ApplyAuraCountdownDynamicColorToAuraFrames(unit, frame.buffFrames, buffConfig)
    end

    -- Debuffs
    if frame.debuffFrames then
        local debuffConfig = DB:GetDebuffCountdownDynamicColorConfig()
        self:ApplyAuraCountdownDynamicColorToAuraFrames(unit, frame.debuffFrames, debuffConfig)
    end
end

function FF:UpdateAuraCountdownDynamicColor()
    local frames = Blizzard:GetFrames()
    for _, frame in ipairs(frames) do
        self:UpdateAuraCountdownDynamicColorForFrame(frame)
    end
end

function FF:StartAuraCountdownDynamicColorTicker()
    self:StopAuraCountdownDynamicColorTicker()

    self._ffAuraCountdownDynamicColorTicker = C_Timer.NewTicker(AURA_COUNTDOWN_COLOR_UPDATE_INTERVAL_SECONDS, function()
        FF:UpdateAuraCountdownDynamicColor()
    end)
end

function FF:StopAuraCountdownDynamicColorTicker()
    local ticker = self._ffAuraCountdownDynamicColorTicker
    if ticker then
        ticker:Cancel()
    end
    self._ffAuraCountdownDynamicColorTicker = nil
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
        local color = DB:GetBuffCountdownColor()
        local r, g, b = color.r, color.g, color.b
        for _, buffFrame in ipairs(frame.buffFrames) do
            local cooldown = buffFrame and buffFrame.cooldown
            if cooldown then
                self:ApplyAuraCountdownColorToCooldown(cooldown, r, g, b)
            end
        end
    end

    if frame.debuffFrames then
        local color = DB:GetDebuffCountdownColor()
        local r, g, b = color.r, color.g, color.b
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

    for _, buffFrame in ipairs(frame.buffFrames) do
        local cooldown = buffFrame and buffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not show)
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown, fontSize)
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

    for _, debuffFrame in ipairs(frame.debuffFrames) do
        local cooldown = debuffFrame and debuffFrame.cooldown
        if cooldown then
            Utils:SetHideCountdownNumbersSafe(cooldown, not show)
            self:ApplyAuraCountdownFontSizeToCooldown(cooldown, fontSize)
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
