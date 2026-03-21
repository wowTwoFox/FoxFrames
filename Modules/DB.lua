local addonName, addon = ...

assert(addon and addon.Utils and addon.Constants, "FoxFrames: addon table, Constants, or Utils missing (load order issue)")

local Constants = addon.Constants
local Utils = addon.Utils

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

local anchorPoints = Constants.ANCHOR_POINTS
local flipVerticalAnchorPoints = Constants.FLIP_VERTICAL_ANCHOR_POINTS
local flipHorizontalAnchorPoints = Constants.FLIP_HORIZONTAL_ANCHOR_POINTS
local growthDirections = Constants.GROWTH_DIRECTIONS
local layoutAxisValues = Constants.LAYOUT_AXIS

local spellBarAnchorModes = {
    INSIDE = "INSIDE",
    AUTO = "AUTO",
    OUTSIDEV = "OUTSIDEV",
    OUTSIDEH = "OUTSIDEH",
}

local function FlipVerticalAnchorPoint(point)
    return flipVerticalAnchorPoints[point] or point
end

local function FlipHorizontalAnchorPoint(point)
    return flipHorizontalAnchorPoints[point] or point
end

local frameAnchorTargets = {
    FRAME = "FRAME",
    HEALTHBAR = "HEALTHBAR",
}

local playerFrameShowTypes = {
    ALWAYS = "ALWAYS",
    SOLO = "SOLO",
    NEVER = "NEVER",
}

local defaultSettings = {
    playerFrame = {
        showType = playerFrameShowTypes.ALWAYS,
    },
    partyFrame = {
        showTitle = true,
        showTankRoleIcon = true,
        showHealerRoleIcon = true,
        showDPSRoleIcon = true,
        showInSolo = false,
        buffs = {
            cooldownText = {
                show = false,
                fontSize = 12,
            },
        },
        debuffs = {
            cooldownText = {
                show = false,
                fontSize = 12,
            },
        },
        statusText = {
            fontSize = 10,
            opacity = 1,
            color = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
            },
            useClassColors = false,
            frame = {
                anchorTarget = frameAnchorTargets.FRAME,
                position = anchorPoints.CENTER,
                offsetX = 0,
                offsetY = 0,
                useRelativeOffsets = true,
                anchorMode = spellBarAnchorModes.INSIDE,
            },
        },
        playerName = {
            fontSize = 10,
            opacity = 1,
            color = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
            },
            useClassColors = false,
            frame = {
                anchorTarget = frameAnchorTargets.FRAME,
                position = anchorPoints.TOP,
                offsetX = 0,
                offsetY = 6,
                useRelativeOffsets = true,
                anchorMode = spellBarAnchorModes.INSIDE,
            },
        },
        allowAnyAnchoring = false,
        trackIncomingCasts = false,
    },
    incomingCastBar = {
        spellCount = 3,
        frame = {
            anchorTarget = frameAnchorTargets.HEALTHBAR,
            position = anchorPoints.BOTTOMLEFT,
            anchorMode = spellBarAnchorModes.INSIDE,
            offsetX = 2,
            offsetY = 2,
            useRelativeOffsets = true,
        },
        growthDirection = growthDirections.RIGHT,
        icon = {
            scale = 1,
            spacing = 0,
            showBorder = true,
            showSwipe = true,
            cooldownText = {
                show = true,
                fontSize = 10,
            },
        },
    },
}

function Object:GetDBProfile()
    local dbRef = self.db
    local profile = dbRef and dbRef.profile
    if type(profile) ~= "table" then
        return nil
    end
    return profile
end

function Object:GetPartyFrameDB()
    local profile = self:GetDBProfile()
    if not profile then
        return nil
    end

    if type(profile.partyFrame) ~= "table" then
        profile.partyFrame = {}
    end

    return profile.partyFrame
end

function Object:GetBuffsDB()
    local partyFrame = self:GetPartyFrameDB()
    if not partyFrame then
        return nil
    end

    if type(partyFrame.buffs) ~= "table" then
        partyFrame.buffs = {}
    end

    return partyFrame.buffs
end

function Object:GetDebuffsDB()
    local partyFrame = self:GetPartyFrameDB()
    if not partyFrame then
        return nil
    end

    if type(partyFrame.debuffs) ~= "table" then
        partyFrame.debuffs = {}
    end

    return partyFrame.debuffs
end

function Object:GetBuffsCooldownTextDB()
    local buffs = self:GetBuffsDB()
    if not buffs then
        return nil
    end

    if type(buffs.cooldownText) ~= "table" then
        buffs.cooldownText = {}
    end

    return buffs.cooldownText
end

function Object:GetDebuffsCooldownTextDB()
    local debuffs = self:GetDebuffsDB()
    if not debuffs then
        return nil
    end

    if type(debuffs.cooldownText) ~= "table" then
        debuffs.cooldownText = {}
    end

    return debuffs.cooldownText
end

function Object:GetStatusTextDB()
    local partyFrame = self:GetPartyFrameDB()
    if not partyFrame then
        return nil
    end

    if type(partyFrame.statusText) ~= "table" then
        partyFrame.statusText = {}
    end

    return partyFrame.statusText
end

function Object:GetStatusTextFrameDB()
    local statusText = self:GetStatusTextDB()
    if not statusText then
        return nil
    end

    if type(statusText.frame) ~= "table" then
        statusText.frame = {}
    end

    return statusText.frame
end

function Object:GetPlayerNameDB()
    local partyFrame = self:GetPartyFrameDB()
    if not partyFrame then
        return nil
    end

    if type(partyFrame.playerName) ~= "table" then
        partyFrame.playerName = {}
    end

    return partyFrame.playerName
end

function Object:GetPlayerNameFrameDB()
    local playerName = self:GetPlayerNameDB()
    if not playerName then
        return nil
    end

    if type(playerName.frame) ~= "table" then
        playerName.frame = {}
    end

    return playerName.frame
end

function Object:GetPlayerFrameDB()
    local profile = self:GetDBProfile()
    if not profile then
        return nil
    end

    if type(profile.playerFrame) ~= "table" then
        profile.playerFrame = {}
    end

    return profile.playerFrame
end

function Object:GetIncomingCastBarDB()
    local profile = self:GetDBProfile()
    if not profile then
        return nil
    end

    if type(profile.incomingCastBar) ~= "table" then
        profile.incomingCastBar = {}
    end

    return profile.incomingCastBar
end

function Object:GetIncomingCastBarFrameDB()
    local incomingCastBar = self:GetIncomingCastBarDB()
    if not incomingCastBar then
        return nil
    end

    if type(incomingCastBar.frame) ~= "table" then
        incomingCastBar.frame = {}
    end

    return incomingCastBar.frame
end

function Object:GetIncomingCastBarIconDB()
    local incomingCastBar = self:GetIncomingCastBarDB()
    if not incomingCastBar then
        return nil
    end

    if type(incomingCastBar.icon) ~= "table" then
        incomingCastBar.icon = {}
    end

    return incomingCastBar.icon
end

function Object:GetIncomingCastBarIconCooldownTextDB()
    local iconProfile = self:GetIncomingCastBarIconDB()
    if not iconProfile then
        return nil
    end

    if type(iconProfile.cooldownText) ~= "table" then
        iconProfile.cooldownText = {}
    end

    return iconProfile.cooldownText
end

function Object:GetIncomingCastBarProfile()
    return self:GetIncomingCastBarDB()
end

function Object:GetIncomingCastBarValue(key)
    local incomingCastBar = self:GetIncomingCastBarDB()
    return incomingCastBar and incomingCastBar[key]
end

function Object:SetIncomingCastBarValue(key, value)
    local incomingCastBar = self:GetIncomingCastBarDB()
    if incomingCastBar then
        incomingCastBar[key] = value
    end
end

function Object:GetIncomingCastBarIconValue(key)
    local iconProfile = self:GetIncomingCastBarIconDB()
    return iconProfile and iconProfile[key]
end

function Object:SetIncomingCastBarIconValue(key, value)
    local iconProfile = self:GetIncomingCastBarIconDB()
    if iconProfile then
        iconProfile[key] = value
    end
end

function Object:GetFrameAnchorsAndOffsets(frameProfile, defaults, offsetMin, offsetMax, layoutAxis)
    local sanitizedDefaults = defaults
    if type(sanitizedDefaults) ~= "table" then
        sanitizedDefaults = {}
    end

    local configured = frameProfile
    if type(configured) ~= "table" then
        configured = {}
    end

    local relativeFallback = sanitizedDefaults.position or anchorPoints.CENTER
    local relativeAnchor = Utils:SanitizeAnchorPoint(configured.position, relativeFallback)

    local frameAnchor = relativeAnchor
    local modeFallback = sanitizedDefaults.anchorMode or spellBarAnchorModes.INSIDE
    local mode = self:SanitizeIncomingCastSpellBarAnchorMode(configured.anchorMode, modeFallback)

    if mode == spellBarAnchorModes.OUTSIDEV then
        frameAnchor = FlipVerticalAnchorPoint(relativeAnchor)
    elseif mode == spellBarAnchorModes.OUTSIDEH then
        frameAnchor = FlipHorizontalAnchorPoint(relativeAnchor)
    elseif mode == spellBarAnchorModes.AUTO then
        local verticalCandidate = FlipVerticalAnchorPoint(relativeAnchor)
        local horizontalCandidate = FlipHorizontalAnchorPoint(relativeAnchor)

        layoutAxis = Utils:SanitizeLayoutAxis(layoutAxis)
        local preferred

        -- Auto chooses an outside axis based on the party frame alignment:
        -- - Frames in a column (VERTICAL) -> prefer outside horizontally (LEFT/RIGHT)
        -- - Frames in a row (HORIZONTAL) -> prefer outside vertically (TOP/BOTTOM)
        -- If the preferred axis doesn't move the anchor (e.g. TOP has no horizontal flip),
        -- fall back to the other axis.
        if layoutAxis == layoutAxisValues.VERTICAL then
            preferred = horizontalCandidate
            if preferred == relativeAnchor then
                preferred = verticalCandidate
            end
        elseif layoutAxis == layoutAxisValues.HORIZONTAL then
            preferred = verticalCandidate
            if preferred == relativeAnchor then
                preferred = horizontalCandidate
            end
        else
            preferred = verticalCandidate
            if preferred == relativeAnchor then
                preferred = horizontalCandidate
            end
        end

        if preferred ~= relativeAnchor then
            frameAnchor = preferred
        end
    end

    local fallbackX = sanitizedDefaults.offsetX or 0
    local fallbackY = sanitizedDefaults.offsetY or 0

    local min = type(offsetMin) == "number" and offsetMin or -200
    local max = type(offsetMax) == "number" and offsetMax or 200

    local offsetX = Utils:ClampInteger(configured.offsetX, min, max, fallbackX)
    local offsetY = Utils:ClampInteger(configured.offsetY, min, max, fallbackY)

    local fallbackUseRelativeOffsets = sanitizedDefaults.useRelativeOffsets ~= false
    local useRelativeOffsets = self:SanitizeBoolean(configured.useRelativeOffsets, fallbackUseRelativeOffsets)
    if useRelativeOffsets then
        offsetX, offsetY = Utils:FlipToRelativeOffsets(offsetX, offsetY, frameAnchor)
    end

    return frameAnchor, relativeAnchor, offsetX, offsetY
end

function Object:GetIncomingCastIndicatorAnchorsAndOffsets(layoutAxis)
    local profile = self:GetIncomingCastBarFrameDB()
    local spellBarAnchor, relativeAnchor, offsetX, offsetY = self:GetFrameAnchorsAndOffsets(
        profile,
        defaultSettings.incomingCastBar.frame,
        -200,
        200,
        layoutAxis
    )

    return relativeAnchor, spellBarAnchor, offsetX, offsetY
end

function Object:GetIncomingCastIndicatorAnchorFrame()
    local fallback = defaultSettings.incomingCastBar.frame.anchorTarget

    local profile = self:GetIncomingCastBarFrameDB()
    local value = profile and profile.anchorTarget
    if value == nil then
        return fallback
    end

    return self:SanitizeIncomingCastAnchorFrame(value, fallback)
end

function Object:GetIncomingCastIndicatorCount()
    local profile = self:GetIncomingCastBarDB()
    return Utils:ClampInteger(profile and profile.spellCount, 1, 6, defaultSettings.incomingCastBar.spellCount)
end

function Object:GetIncomingCastIndicatorIconCooldownTextShow()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.incomingCastBar and self.DEFAULT_SETTINGS.incomingCastBar.icon and self.DEFAULT_SETTINGS.incomingCastBar.icon.cooldownText) or {}
    local profile = self:GetIncomingCastBarIconCooldownTextDB()
    return self:GetCooldownTextShow(profile, defaults)
end

function Object:GetIncomingCastIndicatorIconCooldownTextFontSize()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.incomingCastBar and self.DEFAULT_SETTINGS.incomingCastBar.icon and self.DEFAULT_SETTINGS.incomingCastBar.icon.cooldownText) or {}
    local profile = self:GetIncomingCastBarIconCooldownTextDB()
    return self:GetTextFontSize(profile, defaults, 8, 32)
end

function Object:GetIncomingCastIndicatorGrowDirection(relativeAnchor)
    local fallback = defaultSettings.incomingCastBar.growthDirection

    local profile = self:GetIncomingCastBarDB()
    local explicitValue = profile and rawget(profile, "growthDirection")

    if explicitValue == nil then
        local anchor = relativeAnchor
        if anchor == nil then
            anchor = self:GetIncomingCastIndicatorAnchorsAndOffsets()
        end

        if Utils:IsAnchorRightAligned(anchor) then
            return growthDirections.LEFT
        end

        return fallback
    end

    return self:SanitizeIncomingCastGrowDirection(explicitValue, fallback)
end

function Object:SanitizeIncomingCastPosition(value, fallback)
    return Utils:SanitizeAnchorPoint(value, fallback)
end

function Object:SanitizeIncomingCastSpellBarAnchorMode(value, fallback)
    -- Compatibility: old "OUTSIDE" mode was renamed to AUTO.
    if value == "OUTSIDE" then
        value = spellBarAnchorModes.AUTO
    end

    return Utils:SanitizeOption(value, spellBarAnchorModes) or fallback
end

function Object:SanitizeIncomingCastGrowDirection(value, fallback)
    return Utils:SanitizeGrowthDirection(value, fallback)
end

function Object:SanitizeIncomingCastAnchorFrame(value, fallback)
    return Utils:SanitizeOption(value, frameAnchorTargets) or fallback
end

function Object:SanitizeStatusTextAnchorPoint(value, fallback)
    return Utils:SanitizeAnchorPoint(value, fallback)
end

function Object:SanitizeStatusTextColor(value, fallback)
    local fallbackColor = fallback
    if type(fallbackColor) ~= "table" then
        fallbackColor = { r = 1, g = 1, b = 1, a = 1 }
    end

    local color = value
    if type(color) ~= "table" then
        color = fallbackColor
    end

    return {
        r = Utils:ClampNumber(color.r, 0, 1, fallbackColor.r or 1),
        g = Utils:ClampNumber(color.g, 0, 1, fallbackColor.g or 1),
        b = Utils:ClampNumber(color.b, 0, 1, fallbackColor.b or 1),
        a = Utils:ClampNumber(color.a, 0, 1, fallbackColor.a or 1),
    }
end

function Object:SanitizeBoolean(value, fallback)
    if value == nil then
        return fallback
    end
    return value == true
end

function Object:SanitizeOpacity(value, fallback)
    local sanitizedFallback = Utils:ClampNumber(fallback, 0, 1, 1)
    local opacity = Utils:ClampNumber(value, 0, 1, sanitizedFallback)
    return Utils:RoundToDecimals(opacity, 2, sanitizedFallback)
end

function Object:GetTextColorAndOpacity(textProfile, defaults)
    local sanitizedDefaults = defaults
    if type(sanitizedDefaults) ~= "table" then
        sanitizedDefaults = {}
    end

    local profile = textProfile
    if type(profile) ~= "table" then
        profile = {}
    end

    local defaultColor = sanitizedDefaults.color
    if type(defaultColor) ~= "table" then
        defaultColor = { r = 1, g = 1, b = 1, a = 1 }
    end

    local defaultOpacity = Utils:ClampNumber(sanitizedDefaults.opacity, 0, 1, defaultColor.a or 1)

    local color = profile.color
    local r = Utils:ClampNumber(color and color.r, 0, 1, defaultColor.r or 1)
    local g = Utils:ClampNumber(color and color.g, 0, 1, defaultColor.g or 1)
    local b = Utils:ClampNumber(color and color.b, 0, 1, defaultColor.b or 1)

    local colorOpacity = Utils:ClampNumber(color and color.a, 0, 1, defaultOpacity)
    local a = Utils:ClampNumber(profile.opacity, 0, 1, colorOpacity)

    return r, g, b, a
end

function Object:GetTextUseClassColors(textProfile, defaults)
    local sanitizedDefaults = defaults
    if type(sanitizedDefaults) ~= "table" then
        sanitizedDefaults = {}
    end

    local defaultEnabled = sanitizedDefaults.useClassColors == true

    local profile = textProfile
    if type(profile) ~= "table" then
        profile = {}
    end

    local enabled = profile.useClassColors
    if enabled == nil then
        return defaultEnabled
    end

    return enabled == true
end

function Object:GetTextFontSize(textProfile, defaults, minValue, maxValue)
    local sanitizedDefaults = defaults
    if type(sanitizedDefaults) ~= "table" then
        sanitizedDefaults = {}
    end

    local profile = textProfile
    if type(profile) ~= "table" then
        profile = {}
    end

    local min = type(minValue) == "number" and minValue or 8
    local max = type(maxValue) == "number" and maxValue or 32
    local defaultSize = sanitizedDefaults.fontSize or 10

    return Utils:ClampInteger(profile.fontSize, min, max, defaultSize)
end

function Object:GetCooldownTextShow(cooldownTextProfile, defaults)
    local sanitizedDefaults = defaults
    if type(sanitizedDefaults) ~= "table" then
        sanitizedDefaults = {}
    end

    local defaultEnabled = sanitizedDefaults.show == true

    local profile = cooldownTextProfile
    if type(profile) ~= "table" then
        profile = {}
    end

    local enabled = profile.show
    if enabled == nil then
        return defaultEnabled
    end

    return enabled == true
end

function Object:GetBuffCountdownFontSize()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.buffs and self.DEFAULT_SETTINGS.partyFrame.buffs.cooldownText) or {}
    local profile = self:GetBuffsCooldownTextDB()
    return self:GetTextFontSize(profile, defaults, 8, 32)
end

function Object:GetDebuffCountdownFontSize()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.debuffs and self.DEFAULT_SETTINGS.partyFrame.debuffs.cooldownText) or {}
    local profile = self:GetDebuffsCooldownTextDB()
    return self:GetTextFontSize(profile, defaults, 8, 32)
end

function Object:GetAuraCountdownFontSize()
    -- Backward-compatible fallback: historically there was one shared countdown font size.
    -- Now buffs/debuffs have independent font size settings.
    return self:GetBuffCountdownFontSize()
end

function Object:GetStatusTextAnchorsAndOffsets(layoutAxis)
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusText and self.DEFAULT_SETTINGS.partyFrame.statusText.frame) or {}
    local profile = self:GetStatusTextFrameDB()

    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget

    local point, relativePoint, offsetX, offsetY = self:GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetStatusTextColor()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusText) or {}
    local profile = self:GetStatusTextDB()
    return self:GetTextColorAndOpacity(profile, defaults)
end

function Object:GetStatusTextUseClassColors()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusText) or {}
    local profile = self:GetStatusTextDB()
    return self:GetTextUseClassColors(profile, defaults)
end

function Object:GetPlayerNameAnchorsAndOffsets(layoutAxis)
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerName and self.DEFAULT_SETTINGS.partyFrame.playerName.frame) or {}
    local profile = self:GetPlayerNameFrameDB()

    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget

    local point, relativePoint, offsetX, offsetY = self:GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetPlayerNameColor()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerName) or {}
    local profile = self:GetPlayerNameDB()
    return self:GetTextColorAndOpacity(profile, defaults)
end

function Object:GetPlayerNameUseClassColors()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerName) or {}
    local profile = self:GetPlayerNameDB()
    return self:GetTextUseClassColors(profile, defaults)
end

function Object:GetPlayerNameFontSize()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerName) or {}
    local profile = self:GetPlayerNameDB()
    return self:GetTextFontSize(profile, defaults, 8, 32)
end

function Object:GetHealthTextFontSize()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusText) or {}
    local profile = self:GetStatusTextDB()
    return self:GetTextFontSize(profile, defaults, 8, 32)
end

function Object:GetAllowAnyAnchoring()
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.allowAnyAnchoring) == true
    local profile = self:GetPartyFrameDB()
    local value = profile and profile.allowAnyAnchoring

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetShowInSolo()
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.showInSolo) == true
    local profile = self:GetPartyFrameDB()
    local value = profile and profile.showInSolo

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetPlayerFrameShowType()
    local configuredTypes = self.PLAYER_FRAME_SHOW_TYPES or playerFrameShowTypes
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.playerFrame and self.DEFAULT_SETTINGS.playerFrame.showType)
        or configuredTypes.ALWAYS

    local profile = self:GetPlayerFrameDB()
    local value = profile and profile.showType

    return Utils:SanitizeOption(value, configuredTypes) or defaultValue
end

function Object:GetShowPartyFrameTitle()
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.showTitle) ~= false
    local profile = self:GetPartyFrameDB()
    local value = profile and profile.showTitle

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetShowBuffCountdown()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.buffs and self.DEFAULT_SETTINGS.partyFrame.buffs.cooldownText) or {}
    local profile = self:GetBuffsCooldownTextDB()
    return self:GetCooldownTextShow(profile, defaults)
end

function Object:GetShowDebuffCountdown()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.debuffs and self.DEFAULT_SETTINGS.partyFrame.debuffs.cooldownText) or {}
    local profile = self:GetDebuffsCooldownTextDB()
    return self:GetCooldownTextShow(profile, defaults)
end

function Object:GetShowRoleIcon(role)
    local keyMap = {
        TANK = "showTankRoleIcon",
        HEALER = "showHealerRoleIcon",
        DAMAGER = "showDPSRoleIcon",
    }

    local key = keyMap[role]
    if not key then
        return false
    end

    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame[key]) ~= false
    local profile = self:GetPartyFrameDB()
    local value = profile and profile[key]

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetHealthBarTexture()
    local profile = self:GetPartyFrameDB()
    if not profile or profile.useCustomHealthBarTexture ~= true then
        return nil
    end

    local texture = profile.healthBarTexture
    if type(texture) ~= "string" or texture == "" then
        return nil
    end

    return texture
end

function Object:GetTrackIncomingCasts()
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.trackIncomingCasts) == true
    local profile = self:GetPartyFrameDB()
    local value = profile and profile.trackIncomingCasts

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:MigrateAndSanitizeDB()
    local playerProfile = self:GetPlayerFrameDB()
    if playerProfile then
        -- Migrate old playerFrameShowTypes from lowercase to uppercase
        local showType = playerProfile.showType
        if showType == "Always" then
            playerProfile.showType = playerFrameShowTypes.ALWAYS
        elseif showType == "Solo" then
            playerProfile.showType = playerFrameShowTypes.SOLO
        elseif showType == "Never" then
            playerProfile.showType = playerFrameShowTypes.NEVER
        end
    end

    local partyProfile = self:GetPartyFrameDB()
    if partyProfile then
        -- Migrate old healthBarTexture = "DEFAULT" to nil
        if partyProfile.healthBarTexture == "DEFAULT" then
            partyProfile.healthBarTexture = nil
        end
        
        -- Migrate old UseCustomHealthBarTexture setting to useCustomHealthBarTexture
        if partyProfile.UseCustomHealthBarTexture == true then
            partyProfile.useCustomHealthBarTexture = true
            partyProfile.UseCustomHealthBarTexture = nil
        elseif partyProfile.UseCustomHealthBarTexture == false then
            partyProfile.useCustomHealthBarTexture = false
            partyProfile.UseCustomHealthBarTexture = nil
        end

        -- Migrate legacy flat frame settings into partyFrame.statusText.frame
        if type(partyProfile.statusText) ~= "table" then
            partyProfile.statusText = {}
        end
        if type(partyProfile.statusText.frame) ~= "table" then
            partyProfile.statusText.frame = {}
        end

        local statusTextFrame = partyProfile.statusText.frame
        local statusTextDefaults = defaultSettings.partyFrame.statusText and defaultSettings.partyFrame.statusText.frame or {}

        if partyProfile.statusTextAnchorTarget ~= nil then
            if statusTextFrame.anchorTarget == nil or statusTextFrame.anchorTarget == statusTextDefaults.anchorTarget then
                statusTextFrame.anchorTarget = partyProfile.statusTextAnchorTarget
            end
            partyProfile.statusTextAnchorTarget = nil
        end

        local oldStatusTextPosition = partyProfile.statusTextPosition
        if oldStatusTextPosition == nil and partyProfile.statusTextAnchorPoint ~= nil then
            oldStatusTextPosition = partyProfile.statusTextAnchorPoint
        end
        if oldStatusTextPosition ~= nil then
            if statusTextFrame.position == nil or statusTextFrame.position == statusTextDefaults.position then
                statusTextFrame.position = oldStatusTextPosition
            end
        end
        partyProfile.statusTextPosition = nil
        partyProfile.statusTextAnchorPoint = nil

        if partyProfile.statusTextOffsetX ~= nil then
            if statusTextFrame.offsetX == nil or statusTextFrame.offsetX == statusTextDefaults.offsetX then
                statusTextFrame.offsetX = partyProfile.statusTextOffsetX
            end
            partyProfile.statusTextOffsetX = nil
        end
        if partyProfile.statusTextOffsetY ~= nil then
            if statusTextFrame.offsetY == nil or statusTextFrame.offsetY == statusTextDefaults.offsetY then
                statusTextFrame.offsetY = partyProfile.statusTextOffsetY
            end
            partyProfile.statusTextOffsetY = nil
        end
        if partyProfile.statusTextUseRelativeOffsets ~= nil then
            if statusTextFrame.useRelativeOffsets == nil or statusTextFrame.useRelativeOffsets == statusTextDefaults.useRelativeOffsets then
                statusTextFrame.useRelativeOffsets = partyProfile.statusTextUseRelativeOffsets
            end
            partyProfile.statusTextUseRelativeOffsets = nil
        end

        -- Migrate legacy flat status text settings into partyFrame.statusText
        local statusTextProfile = partyProfile.statusText
        local statusTextTextDefaults = defaultSettings.partyFrame.statusText or {}

        local legacyStatusTextFontSize = partyProfile.healthTextFontSize
        if legacyStatusTextFontSize == nil then
            legacyStatusTextFontSize = partyProfile.statusTextFontSize
        end
        if legacyStatusTextFontSize ~= nil then
            if statusTextProfile.fontSize == nil or statusTextProfile.fontSize == statusTextTextDefaults.fontSize then
                statusTextProfile.fontSize = legacyStatusTextFontSize
            end
        end
        partyProfile.healthTextFontSize = nil
        partyProfile.statusTextFontSize = nil

        if partyProfile.statusTextOpacity ~= nil then
            if statusTextProfile.opacity == nil or statusTextProfile.opacity == statusTextTextDefaults.opacity then
                statusTextProfile.opacity = partyProfile.statusTextOpacity
            end
            partyProfile.statusTextOpacity = nil
        elseif statusTextProfile.opacity == nil and type(partyProfile.statusTextColor) == "table" and partyProfile.statusTextColor.a ~= nil then
            statusTextProfile.opacity = partyProfile.statusTextColor.a
        end

        if partyProfile.statusTextUseClassColors ~= nil then
            if statusTextProfile.useClassColors == nil or statusTextProfile.useClassColors == statusTextTextDefaults.useClassColors then
                statusTextProfile.useClassColors = partyProfile.statusTextUseClassColors
            end
            partyProfile.statusTextUseClassColors = nil
        end

        if partyProfile.statusTextColor ~= nil then
            if rawget(statusTextProfile, "color") == nil then
                statusTextProfile.color = partyProfile.statusTextColor
            end
            partyProfile.statusTextColor = nil
        end

        -- Migrate legacy flat frame settings into partyFrame.playerName.frame
        if type(partyProfile.playerName) ~= "table" then
            partyProfile.playerName = {}
        end
        if type(partyProfile.playerName.frame) ~= "table" then
            partyProfile.playerName.frame = {}
        end

        local playerNameFrame = partyProfile.playerName.frame
        local playerNameDefaults = defaultSettings.partyFrame.playerName and defaultSettings.partyFrame.playerName.frame or {}

        if partyProfile.playerNameAnchorTarget ~= nil then
            if playerNameFrame.anchorTarget == nil or playerNameFrame.anchorTarget == playerNameDefaults.anchorTarget then
                playerNameFrame.anchorTarget = partyProfile.playerNameAnchorTarget
            end
            partyProfile.playerNameAnchorTarget = nil
        end

        local oldPlayerNamePosition = partyProfile.playerNamePosition
        if oldPlayerNamePosition == nil and partyProfile.playerNameAnchorPoint ~= nil then
            oldPlayerNamePosition = partyProfile.playerNameAnchorPoint
        end
        if oldPlayerNamePosition ~= nil then
            if playerNameFrame.position == nil or playerNameFrame.position == playerNameDefaults.position then
                playerNameFrame.position = oldPlayerNamePosition
            end
        end
        partyProfile.playerNamePosition = nil
        partyProfile.playerNameAnchorPoint = nil

        if partyProfile.playerNameOffsetX ~= nil then
            if playerNameFrame.offsetX == nil or playerNameFrame.offsetX == playerNameDefaults.offsetX then
                playerNameFrame.offsetX = partyProfile.playerNameOffsetX
            end
            partyProfile.playerNameOffsetX = nil
        end
        if partyProfile.playerNameOffsetY ~= nil then
            if playerNameFrame.offsetY == nil or playerNameFrame.offsetY == playerNameDefaults.offsetY then
                playerNameFrame.offsetY = partyProfile.playerNameOffsetY
            end
            partyProfile.playerNameOffsetY = nil
        end
        if partyProfile.playerNameUseRelativeOffsets ~= nil then
            if playerNameFrame.useRelativeOffsets == nil or playerNameFrame.useRelativeOffsets == playerNameDefaults.useRelativeOffsets then
                playerNameFrame.useRelativeOffsets = partyProfile.playerNameUseRelativeOffsets
            end
            partyProfile.playerNameUseRelativeOffsets = nil
        end

        -- Migrate legacy flat player name settings into partyFrame.playerName
        local playerNameProfile = partyProfile.playerName
        local playerNameTextDefaults = defaultSettings.partyFrame.playerName or {}

        if partyProfile.playerNameFontSize ~= nil then
            if playerNameProfile.fontSize == nil or playerNameProfile.fontSize == playerNameTextDefaults.fontSize then
                playerNameProfile.fontSize = partyProfile.playerNameFontSize
            end
            partyProfile.playerNameFontSize = nil
        end

        if partyProfile.playerNameOpacity ~= nil then
            if playerNameProfile.opacity == nil or playerNameProfile.opacity == playerNameTextDefaults.opacity then
                playerNameProfile.opacity = partyProfile.playerNameOpacity
            end
            partyProfile.playerNameOpacity = nil
        elseif playerNameProfile.opacity == nil and type(partyProfile.playerNameColor) == "table" and partyProfile.playerNameColor.a ~= nil then
            playerNameProfile.opacity = partyProfile.playerNameColor.a
        end

        if partyProfile.playerNameUseClassColors ~= nil then
            if playerNameProfile.useClassColors == nil or playerNameProfile.useClassColors == playerNameTextDefaults.useClassColors then
                playerNameProfile.useClassColors = partyProfile.playerNameUseClassColors
            end
            partyProfile.playerNameUseClassColors = nil
        end

        if partyProfile.playerNameColor ~= nil then
            if rawget(playerNameProfile, "color") == nil then
                playerNameProfile.color = partyProfile.playerNameColor
            end
            partyProfile.playerNameColor = nil
        end

        -- Migrate legacy buff/debuff cooldown text settings into partyFrame.buffs.cooldownText / partyFrame.debuffs.cooldownText
        if type(partyProfile.buffs) ~= "table" then
            partyProfile.buffs = {}
        end
        if type(partyProfile.debuffs) ~= "table" then
            partyProfile.debuffs = {}
        end

        local buffsProfile = partyProfile.buffs
        local debuffsProfile = partyProfile.debuffs
        if type(buffsProfile.cooldownText) ~= "table" then
            buffsProfile.cooldownText = {}
        end
        if type(debuffsProfile.cooldownText) ~= "table" then
            debuffsProfile.cooldownText = {}
        end

        local buffsCooldownText = buffsProfile.cooldownText
        local debuffsCooldownText = debuffsProfile.cooldownText
        local buffsDefaults = (defaultSettings.partyFrame.buffs and defaultSettings.partyFrame.buffs.cooldownText) or {}
        local debuffsDefaults = (defaultSettings.partyFrame.debuffs and defaultSettings.partyFrame.debuffs.cooldownText) or {}

        -- Previous schema: partyFrame.buffs/showCountdown + fontSize
        local legacyBuffsShowCountdown = rawget(buffsProfile, "showCountdown")
        if legacyBuffsShowCountdown ~= nil and rawget(buffsCooldownText, "show") == nil then
            buffsCooldownText.show = legacyBuffsShowCountdown == true
        end
        buffsProfile.showCountdown = nil

        local legacyBuffsFontSize = rawget(buffsProfile, "fontSize")
        if legacyBuffsFontSize ~= nil and rawget(buffsCooldownText, "fontSize") == nil then
            buffsCooldownText.fontSize = legacyBuffsFontSize
        end
        buffsProfile.fontSize = nil

        local legacyDebuffsShowCountdown = rawget(debuffsProfile, "showCountdown")
        if legacyDebuffsShowCountdown ~= nil and rawget(debuffsCooldownText, "show") == nil then
            debuffsCooldownText.show = legacyDebuffsShowCountdown == true
        end
        debuffsProfile.showCountdown = nil

        local legacyDebuffsFontSize = rawget(debuffsProfile, "fontSize")
        if legacyDebuffsFontSize ~= nil and rawget(debuffsCooldownText, "fontSize") == nil then
            debuffsCooldownText.fontSize = legacyDebuffsFontSize
        end
        debuffsProfile.fontSize = nil

        if partyProfile.showBuffCountdown ~= nil then
            if rawget(buffsCooldownText, "show") == nil or buffsCooldownText.show == buffsDefaults.show then
                buffsCooldownText.show = partyProfile.showBuffCountdown == true
            end
            partyProfile.showBuffCountdown = nil
        end

        if partyProfile.showDebuffCountdown ~= nil then
            if rawget(debuffsCooldownText, "show") == nil or debuffsCooldownText.show == debuffsDefaults.show then
                debuffsCooldownText.show = partyProfile.showDebuffCountdown == true
            end
            partyProfile.showDebuffCountdown = nil
        end

        if partyProfile.countdownFontSize ~= nil then
            local legacyFontSize = partyProfile.countdownFontSize

            if rawget(buffsCooldownText, "fontSize") == nil or buffsCooldownText.fontSize == buffsDefaults.fontSize then
                buffsCooldownText.fontSize = legacyFontSize
            end

            if rawget(debuffsCooldownText, "fontSize") == nil or debuffsCooldownText.fontSize == debuffsDefaults.fontSize then
                debuffsCooldownText.fontSize = legacyFontSize
            end

            partyProfile.countdownFontSize = nil
        end
    end

    local incomingCastProfile = self:GetIncomingCastBarDB()
    if incomingCastProfile then
        if type(incomingCastProfile.frame) ~= "table" then
            incomingCastProfile.frame = {}
        end

        local incomingCastFrame = incomingCastProfile.frame
        local incomingCastDefaults = defaultSettings.incomingCastBar.frame or {}

        if incomingCastProfile.anchorFrame ~= nil then
            if incomingCastFrame.anchorTarget == nil or incomingCastFrame.anchorTarget == incomingCastDefaults.anchorTarget then
                incomingCastFrame.anchorTarget = incomingCastProfile.anchorFrame
            end
            incomingCastProfile.anchorFrame = nil
        end
        if incomingCastProfile.position ~= nil then
            if incomingCastFrame.position == nil or incomingCastFrame.position == incomingCastDefaults.position then
                incomingCastFrame.position = incomingCastProfile.position
            end
            incomingCastProfile.position = nil
        end
        if incomingCastProfile.anchorMode ~= nil then
            if incomingCastFrame.anchorMode == nil or incomingCastFrame.anchorMode == incomingCastDefaults.anchorMode then
                incomingCastFrame.anchorMode = incomingCastProfile.anchorMode
            end
            incomingCastProfile.anchorMode = nil
        end
        if incomingCastProfile.offsetX ~= nil then
            if incomingCastFrame.offsetX == nil or incomingCastFrame.offsetX == incomingCastDefaults.offsetX then
                incomingCastFrame.offsetX = incomingCastProfile.offsetX
            end
            incomingCastProfile.offsetX = nil
        end
        if incomingCastProfile.offsetY ~= nil then
            if incomingCastFrame.offsetY == nil or incomingCastFrame.offsetY == incomingCastDefaults.offsetY then
                incomingCastFrame.offsetY = incomingCastProfile.offsetY
            end
            incomingCastProfile.offsetY = nil
        end
        if incomingCastProfile.useRelativeOffsets ~= nil then
            if incomingCastFrame.useRelativeOffsets == nil or incomingCastFrame.useRelativeOffsets == incomingCastDefaults.useRelativeOffsets then
                incomingCastFrame.useRelativeOffsets = incomingCastProfile.useRelativeOffsets
            end
            incomingCastProfile.useRelativeOffsets = nil
        end

        if type(incomingCastProfile.icon) ~= "table" then
            incomingCastProfile.icon = {}
        end

        local iconProfile = incomingCastProfile.icon
        if type(iconProfile.cooldownText) ~= "table" then
            iconProfile.cooldownText = {}
        end

        local iconDefaults = (defaultSettings.incomingCastBar and defaultSettings.incomingCastBar.icon and defaultSettings.incomingCastBar.icon.cooldownText) or {}
        local cooldownTextProfile = iconProfile.cooldownText

        local legacyShowCooldownText = rawget(iconProfile, "showCooldownText")
        if legacyShowCooldownText ~= nil then
            if rawget(cooldownTextProfile, "show") == nil or cooldownTextProfile.show == iconDefaults.show then
                cooldownTextProfile.show = legacyShowCooldownText == true
            end
            iconProfile.showCooldownText = nil
        end

        local legacyCooldownFontSize = rawget(iconProfile, "cooldownFontSize")
        if legacyCooldownFontSize ~= nil then
            if rawget(cooldownTextProfile, "fontSize") == nil or cooldownTextProfile.fontSize == iconDefaults.fontSize then
                cooldownTextProfile.fontSize = legacyCooldownFontSize
            end
            iconProfile.cooldownFontSize = nil
        end
    end
end

function Object:InitializeDB()
    local defaults = {
        profile = self.DEFAULT_SETTINGS or {},
    }

    self.db = LibStub("AceDB-3.0"):New("FoxFramesDB", defaults, true)
    self:MigrateAndSanitizeDB()
end

local db = Object:New()
db.DEFAULT_SETTINGS = defaultSettings
db.ANCHOR_POINTS = anchorPoints
db.SPELL_BAR_ANCHOR_MODES = spellBarAnchorModes
db.FRAME_ANCHOR_TARGETS = frameAnchorTargets
db.PLAYER_FRAME_SHOW_TYPES = playerFrameShowTypes
db.GROWTH_DIRECTIONS = growthDirections

if addon then
    addon.DB = db
end
