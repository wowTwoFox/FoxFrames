local addonName, addon = ...

assert(addon and addon.Utils, "FoxFrames: addon table or Utils missing (load order issue)")

local Utils = addon.Utils

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

local anchorPoints = {
    TOPLEFT = "TOPLEFT",
    TOP = "TOP",
    TOPRIGHT = "TOPRIGHT",
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOM = "BOTTOM",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

local frameAnchorTargets = {
    FRAME = "FRAME",
    HEALTHBAR = "HEALTHBAR",
}

local playerFrameShowTypes = {
    ALWAYS = "ALWAYS",
    SOLO = "SOLO",
    NEVER = "NEVER",
}

local growthDirections = {
    UP = "UP",
    DOWN = "DOWN",
    LEFT = "LEFT",
    RIGHT = "RIGHT",
}

local function IsRightAnchor(point)
    return point == anchorPoints.TOPRIGHT or point == anchorPoints.RIGHT or point == anchorPoints.BOTTOMRIGHT
end

local function IsTopAnchor(point)
    return point == anchorPoints.TOPLEFT or point == anchorPoints.TOP or point == anchorPoints.TOPRIGHT
end

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
        showBuffCountdown = false,
        showDebuffCountdown = false,
        countdownFontSize = 12,
        healthTextFontSize = 10,
        statusTextColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 1,
        },
        statusTextOpacity = 1,
        statusTextUseClassColors = false,
        statusTextAnchorTarget = frameAnchorTargets.FRAME,
        statusTextAnchorPoint = anchorPoints.CENTER,
        statusTextOffsetX = 0,
        statusTextOffsetY = 0,
        playerNameFontSize = 10,
        playerNameColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 1,
        },
        playerNameOpacity = 1,
        playerNameUseClassColors = false,
        playerNameAnchorTarget = frameAnchorTargets.FRAME,
        playerNameAnchorPoint = anchorPoints.TOP,
        playerNameOffsetX = 0,
        playerNameOffsetY = 6,
        useCustomHealthBarTexture = false,
        healthBarTexture = nil,
        allowAnyAnchoring = false,
        trackIncomingCasts = false,
    },
    incomingCastBar = {
        spellCount = 3,
        anchorFrame = frameAnchorTargets.HEALTHBAR,
        position = anchorPoints.BOTTOMLEFT,
        growthDirection = growthDirections.RIGHT,
        offsetX = 2,
        offsetY = 2,
        icon = {
            scale = 1,
            spacing = 0,
            showBorder = true,
            showSwipe = true,
            showCooldownText = true,
            cooldownFontSize = 10,
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

function Object:GetIncomingCastIndicatorRelativeAnchor()
    local fallback = defaultSettings.incomingCastBar.position

    local profile = self:GetIncomingCastBarDB()
    local value = profile and profile.position

    if value == nil then
        return fallback
    end

    return self:SanitizeIncomingCastPosition(value, fallback)
end

function Object:GetIncomingCastIndicatorSpellBarAnchor(relativeAnchor)
    local fallback = self:GetIncomingCastIndicatorRelativeAnchor()

    local value = relativeAnchor
    if value == nil then
        return fallback
    end

    return self:SanitizeIncomingCastPosition(value, fallback)
end

function Object:GetIncomingCastIndicatorAnchorFrame()
    local fallback = defaultSettings.incomingCastBar.anchorFrame

    local profile = self:GetIncomingCastBarDB()
    local value = profile and profile.anchorFrame
    if value == nil then
        return fallback
    end

    return self:SanitizeIncomingCastAnchorFrame(value, fallback)
end

function Object:GetIncomingCastIndicatorCount()
    local profile = self:GetIncomingCastBarDB()
    return Utils:ClampInteger(profile and profile.spellCount, 1, 6, defaultSettings.incomingCastBar.spellCount)
end

function Object:GetIncomingCastIndicatorIconConfig(relativeAnchor)
    local iconDefaults = defaultSettings.incomingCastBar.icon

    local profile = self:GetIncomingCastBarDB()
    local iconProfile = profile and profile.icon

    local spellIconMixin = addon and addon.SpellIconMixin
    local baseSize = tonumber(spellIconMixin and spellIconMixin.SPELL_ICON_BASE_SIZE) or 22

    local scaleFallback = iconDefaults.scale
    local scale = Utils:ClampNumber(iconProfile and iconProfile.scale, 0.5, 3, scaleFallback)
    -- Keep hash stable and avoid float jitter.
    scale = Utils:RoundToDecimals(scale, 2, scaleFallback) or scaleFallback

    -- This is the size used for layout (wrapper frame). The visual icon frame is
    -- kept at baseSize and scaled, so borders/overlays scale proportionally.
    local size = baseSize * scale

    local spacing = Utils:ClampInteger(iconProfile and iconProfile.spacing, -10, 50, iconDefaults.spacing)
    local cooldownFontSize = Utils:ClampInteger(iconProfile and iconProfile.cooldownFontSize, 8, 32, iconDefaults.cooldownFontSize)

    local showBorder = iconProfile and iconProfile.showBorder
    if showBorder == nil then
        showBorder = iconDefaults.showBorder ~= false
    else
        showBorder = showBorder == true
    end

    local showSwipe = iconProfile and iconProfile.showSwipe
    if showSwipe == nil then
        showSwipe = iconDefaults.showSwipe ~= false
    else
        showSwipe = showSwipe == true
    end

    local showCooldownText = iconProfile and iconProfile.showCooldownText
    if showCooldownText == nil then
        showCooldownText = iconDefaults.showCooldownText ~= false
    else
        showCooldownText = showCooldownText == true
    end

    local count = self:GetIncomingCastIndicatorCount()
    local growDirection = self:GetIncomingCastIndicatorGrowDirection(relativeAnchor)
    local anchorFrame = self:GetIncomingCastIndicatorAnchorFrame()

    local hash = string.format(
        "%d:%.2f:%d:%d:%d:%d:%d:%s:%s",
        count,
        scale,
        spacing,
        cooldownFontSize,
        showBorder and 1 or 0,
        showSwipe and 1 or 0,
        showCooldownText and 1 or 0,
        growDirection,
        anchorFrame
    )

    return {
        baseSize = baseSize,
        scale = scale,
        size = size,
        spacing = spacing,
        cooldownFontSize = cooldownFontSize,
        showBorder = showBorder,
        showSwipe = showSwipe,
        showCooldownText = showCooldownText,
        count = count,
        growDirection = growDirection,
        hash = hash,
    }, anchorFrame
end

function Object:GetIncomingCastIndicatorGrowDirection(relativeAnchor)
    local fallback = defaultSettings.incomingCastBar.growthDirection

    local profile = self:GetIncomingCastBarDB()
    local explicitValue = profile and rawget(profile, "growthDirection")

    if explicitValue == nil then
        local anchor = relativeAnchor
        if anchor == nil then
            anchor = self:GetIncomingCastIndicatorRelativeAnchor()
        end

        if IsRightAnchor(anchor) then
            return growthDirections.LEFT
        end

        return fallback
    end

    return self:SanitizeIncomingCastGrowDirection(explicitValue, fallback)
end

function Object:GetIncomingCastIndicatorOffsetX(relativeAnchor)
    local fallback = defaultSettings.incomingCastBar.offsetX

    local profile = self:GetIncomingCastBarDB()
    local configuredValue = profile and profile.offsetX

    local offsetX = Utils:ClampInteger(configuredValue, -200, 200, fallback)

    local anchor = relativeAnchor
    if anchor == nil then
        anchor = self:GetIncomingCastIndicatorRelativeAnchor()
    end

    if IsRightAnchor(anchor) then
        offsetX = -offsetX
    end

    return offsetX
end

function Object:GetIncomingCastIndicatorOffsetY(relativeAnchor)
    local fallback = defaultSettings.incomingCastBar.offsetY

    local profile = self:GetIncomingCastBarDB()
    local configuredValue = profile and profile.offsetY

    local offsetY = Utils:ClampInteger(configuredValue, -200, 200, fallback)

    local anchor = relativeAnchor
    if anchor == nil then
        anchor = self:GetIncomingCastIndicatorRelativeAnchor()
    end

    if IsTopAnchor(anchor) then
        offsetY = -offsetY
    end

    return offsetY
end

function Object:SanitizeIncomingCastPosition(value, fallback)
    return Utils:SanitizeOption(value, anchorPoints) or fallback
end

function Object:SanitizeIncomingCastGrowDirection(value, fallback)
    return Utils:SanitizeOption(value, growthDirections) or fallback
end

function Object:SanitizeIncomingCastAnchorFrame(value, fallback)
    return Utils:SanitizeOption(value, frameAnchorTargets) or fallback
end

function Object:SanitizeStatusTextAnchorPoint(value, fallback)
    return Utils:SanitizeOption(value, anchorPoints) or fallback
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

function Object:GetAuraCountdownFontSize()
    local defaultSize = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.countdownFontSize) or 12
    local profile = self:GetPartyFrameDB()
    return Utils:ClampInteger(profile and profile.countdownFontSize, 8, 32, defaultSize)
end

function Object:GetStatusTextAnchorTarget()
    local defaultTarget = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget)
        or frameAnchorTargets.FRAME
    local profile = self:GetPartyFrameDB()
    local target = profile and profile.statusTextAnchorTarget

    return Utils:SanitizeOption(target, frameAnchorTargets) or defaultTarget
end

function Object:GetStatusTextAnchorPoint()
    local defaultPoint = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint)
        or anchorPoints.CENTER
    local profile = self:GetPartyFrameDB()
    local point = profile and profile.statusTextAnchorPoint

    return Utils:SanitizeOption(point, anchorPoints) or defaultPoint
end

function Object:GetStatusTextAnchorOffsets()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame) or {}
    local profile = self:GetPartyFrameDB()

    local offsetX = Utils:ClampInteger(profile and profile.statusTextOffsetX, -100, 100, defaults.statusTextOffsetX or 0)
    local offsetY = Utils:ClampInteger(profile and profile.statusTextOffsetY, -100, 100, defaults.statusTextOffsetY or 0)

    return offsetX, offsetY
end

function Object:GetStatusTextColor()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame) or {}
    local defaultColor = defaults.statusTextColor or { r = 1, g = 1, b = 1, a = 1 }
    local defaultOpacity = Utils:ClampNumber(defaults.statusTextOpacity, 0, 1, defaultColor.a or 1)
    local profile = self:GetPartyFrameDB()
    local color = profile and profile.statusTextColor

    local r = Utils:ClampNumber(color and color.r, 0, 1, defaultColor.r or 1)
    local g = Utils:ClampNumber(color and color.g, 0, 1, defaultColor.g or 1)
    local b = Utils:ClampNumber(color and color.b, 0, 1, defaultColor.b or 1)
    local colorOpacity = Utils:ClampNumber(color and color.a, 0, 1, defaultOpacity)
    local a = Utils:ClampNumber(profile and profile.statusTextOpacity, 0, 1, colorOpacity)

    return r, g, b, a
end

function Object:GetStatusTextUseClassColors()
    local defaultEnabled = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.statusTextUseClassColors) == true
    local profile = self:GetPartyFrameDB()
    local enabled = profile and profile.statusTextUseClassColors

    if enabled == nil then
        return defaultEnabled
    end

    return enabled == true
end

function Object:GetPlayerNameAnchorTarget()
    local defaultTarget = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget)
        or frameAnchorTargets.FRAME
    local profile = self:GetPartyFrameDB()
    local target = profile and profile.playerNameAnchorTarget

    return Utils:SanitizeOption(target, frameAnchorTargets) or defaultTarget
end

function Object:GetPlayerNameAnchorPoint()
    local defaultPoint = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint)
        or anchorPoints.TOPLEFT
    local profile = self:GetPartyFrameDB()
    local point = profile and profile.playerNameAnchorPoint

    return Utils:SanitizeOption(point, anchorPoints) or defaultPoint
end

function Object:GetPlayerNameAnchorOffsets()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame) or {}
    local profile = self:GetPartyFrameDB()

    local offsetX = Utils:ClampInteger(profile and profile.playerNameOffsetX, -100, 100, defaults.playerNameOffsetX or 0)
    local offsetY = Utils:ClampInteger(profile and profile.playerNameOffsetY, -100, 100, defaults.playerNameOffsetY or 0)

    return offsetX, offsetY
end

function Object:GetPlayerNameColor()
    local defaults = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame) or {}
    local defaultColor = defaults.playerNameColor or { r = 1, g = 1, b = 1, a = 1 }
    local defaultOpacity = Utils:ClampNumber(defaults.playerNameOpacity, 0, 1, defaultColor.a or 1)
    local profile = self:GetPartyFrameDB()
    local color = profile and profile.playerNameColor

    local r = Utils:ClampNumber(color and color.r, 0, 1, defaultColor.r or 1)
    local g = Utils:ClampNumber(color and color.g, 0, 1, defaultColor.g or 1)
    local b = Utils:ClampNumber(color and color.b, 0, 1, defaultColor.b or 1)
    local colorOpacity = Utils:ClampNumber(color and color.a, 0, 1, defaultOpacity)
    local a = Utils:ClampNumber(profile and profile.playerNameOpacity, 0, 1, colorOpacity)

    return r, g, b, a
end

function Object:GetPlayerNameUseClassColors()
    local defaultEnabled = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameUseClassColors) == true
    local profile = self:GetPartyFrameDB()
    local enabled = profile and profile.playerNameUseClassColors

    if enabled == nil then
        return defaultEnabled
    end

    return enabled == true
end

function Object:GetPlayerNameFontSize()
    local defaultSize = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.playerNameFontSize) or 10
    local profile = self:GetPartyFrameDB()
    return Utils:ClampInteger(profile and profile.playerNameFontSize, 8, 32, defaultSize)
end

function Object:GetHealthTextFontSize()
    local defaultSize = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.healthTextFontSize) or 10
    local profile = self:GetPartyFrameDB()
    return Utils:ClampInteger(profile and profile.healthTextFontSize, 8, 32, defaultSize)
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
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.showBuffCountdown) == true
    local profile = self:GetPartyFrameDB()
    local value = profile and profile.showBuffCountdown

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetShowDebuffCountdown()
    local defaultValue = (self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.partyFrame and self.DEFAULT_SETTINGS.partyFrame.showDebuffCountdown) == true
    local profile = self:GetPartyFrameDB()
    local value = profile and profile.showDebuffCountdown

    if value == nil then
        return defaultValue
    end

    return value == true
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
db.FRAME_ANCHOR_TARGETS = frameAnchorTargets
db.PLAYER_FRAME_SHOW_TYPES = playerFrameShowTypes
db.GROWTH_DIRECTIONS = growthDirections

if addon then
    addon.DB = db
end
