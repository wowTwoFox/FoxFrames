
-- Runtime-only flags (not stored in saved variables)
Object.runtime = Object.runtime or {}
Object.runtime.incomingCastsPreviewEnabled = Object.runtime.incomingCastsPreviewEnabled == true
local addonName, addon = ...

assert(addon and addon.Utils and addon.Constants, "FoxFrames: addon table, Constants, or Utils missing (load order issue)")

local Constants = addon.Constants
local Utils = addon.Utils

local Object = {}
Object.__index = Object

local anchorPoints = Constants.ANCHOR_POINTS
local growthDirections = Constants.GROWTH_DIRECTIONS
local layoutAxisValues = Constants.LAYOUT_AXIS

local anchorModes = Constants.ANCHOR_MODES

local frameAnchorTargets = {
    FRAME = "FRAME",
    HEALTHBAR = "HEALTHBAR",
}

local playerFrameShowTypes = {
    ALWAYS = "ALWAYS",
    SOLO = "SOLO",
    NEVER = "NEVER",
}

local raidFrameOverrideTypes = {
    ENABLED = "ENABLED",
    DISABLED = "DISABLED",
    PARTY = "PARTY",
}

local defaultColorSettings = { r = 1, g = 1, b = 1 }
local defaultAuraWarningColorSettings = { r = 1, g = 0.55, b = 0 }
local defaultAuraCriticalColorSettings = { r = 1, g = 0, b = 0 }

local defaultFrameSettings = {
    anchorTarget = frameAnchorTargets.FRAME,
    position = anchorPoints.CENTER,
    offsetX = 0,
    offsetY = 0,
    useRelativeOffsets = true,
    anchorMode = anchorModes.INSIDE,
}

local defaultPlayerNameTextSettings = {
    fontSize = 8,
    opacity = 1,
    color = defaultColorSettings,
    useClassColors = false,
}

local defaultPlayerStatusTextSettings = {
    fontSize = 17,
    opacity = 1,
    color = defaultColorSettings,
    useClassColors = false,
}

local defaultPlayerStatusSettings = {
    text = defaultPlayerStatusTextSettings,
    customizeFrame = true,
    customizeText = true,
    customizeFrameType = raidFrameOverrideTypes.PARTY,
    customizeTextType = raidFrameOverrideTypes.PARTY,
    frame = defaultFrameSettings
}

local defaultPlayerNameSettings = {
    text = defaultPlayerNameTextSettings,
    customizeFrame = false,
    customizeText = true,
    customizeFrameType = raidFrameOverrideTypes.PARTY,
    customizeTextType = raidFrameOverrideTypes.PARTY,
    frame = defaultFrameSettings
}

local defaultPartyPlayerStatusSettings = {
    text = defaultPlayerStatusSettings.text,
    customizeFrame = true,
    customizeText = true,
    frame = defaultPlayerStatusSettings.frame
}

local defaultPartyPlayerNameSettings = {
    text = defaultPlayerNameSettings.text,
    customizeFrame = true,
    customizeText = true,
    frame = defaultPlayerNameSettings.frame
}

local defaultRaidPlayerStatusSettings = {
    text = defaultPlayerStatusSettings.text,
    customizeFrameType = raidFrameOverrideTypes.PARTY,
    customizeTextType = raidFrameOverrideTypes.PARTY,
    frame = defaultPlayerStatusSettings.frame
}

local defaultRaidPlayerNameSettings = {
    text = defaultPlayerNameSettings.text,
    customizeFrameType = raidFrameOverrideTypes.PARTY,
    customizeTextType = raidFrameOverrideTypes.PARTY,
    frame = defaultPlayerNameSettings.frame
}

local defaultIncomingCastBarSettings = {
    spellCount = 3,
    frame = {
        anchorTarget = frameAnchorTargets.HEALTHBAR,
        position = anchorPoints.BOTTOMLEFT,
        anchorMode = anchorModes.INSIDE,
        offsetX = 0,
        offsetY = 0,
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
            fontSize = 12,
            color = {
                r = 1,
                g = 1,
                b = 1,
            },
        },
    },
}

local defaultRaidIncomingCastsSettings = {
    enabledType = raidFrameOverrideTypes.PARTY,
    spellCount = defaultIncomingCastBarSettings.spellCount,
    frame = defaultIncomingCastBarSettings.frame,
    growthDirection = defaultIncomingCastBarSettings.growthDirection,
    icon = defaultIncomingCastBarSettings.icon,
}

local defaultPartyIncomingCastsSettings = {
    enabled = false,
    spellCount = defaultIncomingCastBarSettings.spellCount,
    frame = defaultIncomingCastBarSettings.frame,
    growthDirection = defaultIncomingCastBarSettings.growthDirection,
    icon = defaultIncomingCastBarSettings.icon,
}

local defaultAuraSettings = {
    thresholds = {
        warning = {
            enabled = true,
            thresholdSeconds = 10,
            color = defaultAuraWarningColorSettings,
        },
        critical = {
            enabled = true,
            thresholdSeconds = 5,
            color = defaultAuraCriticalColorSettings,
        },
    },
    cooldownText = {
        show = true,
        -- When > 0, countdown text is only shown if remaining duration is <= this many seconds.
        -- 0 means no limit (always show when cooldownText.show is enabled).
        showUnderSeconds = 0,
        fontSize = 12,
        color = defaultColorSettings,
    },
}

local defaultSettings = {
    playerFrame = {
        showType = playerFrameShowTypes.NEVER,
    },
    partyFrame = {
        healthBar = {
            useCustomTexture = false,
            texture = "",
        },
        showTitle = false,
        roleIcons = {
            showTankRoleIcon = true,
            showHealerRoleIcon = true,
            showDPSRoleIcon = false,
        },
        showInSolo = true,
        buffs = defaultAuraSettings,
        debuffs = defaultAuraSettings,
        playerStatus = defaultPartyPlayerStatusSettings,
        playerName = defaultPartyPlayerNameSettings,
        allowAnyAnchoring = true,
        incomingCasts = defaultPartyIncomingCastsSettings,
    },
    raidFrame = {
        playerStatus = defaultRaidPlayerStatusSettings,
        playerName = defaultRaidPlayerNameSettings,
        incomingCasts = defaultRaidIncomingCastsSettings,
    },
}

local function GetFrameAnchorsAndOffsets(frameProfile, defaults, offsetMin, offsetMax, layoutAxis)
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
    local modeFallback = sanitizedDefaults.anchorMode or anchorModes.INSIDE
    local mode = Utils:SanitizeAnchorMode(configured.anchorMode, modeFallback)

    if mode == anchorModes.OUTSIDEV then
        frameAnchor = Utils:FlipVerticalAnchorPoint(relativeAnchor)
    elseif mode == anchorModes.OUTSIDEH then
        frameAnchor = Utils:FlipHorizontalAnchorPoint(relativeAnchor)
    elseif mode == anchorModes.AUTO then
        local verticalCandidate = Utils:FlipVerticalAnchorPoint(relativeAnchor)
        local horizontalCandidate = Utils:FlipHorizontalAnchorPoint(relativeAnchor)

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
    local useRelativeOffsets = Utils:SanitizeBoolean(configured.useRelativeOffsets, fallbackUseRelativeOffsets)
    if useRelativeOffsets then
        offsetX, offsetY = Utils:FlipToRelativeOffsets(offsetX, offsetY, frameAnchor)
    end

    return frameAnchor, relativeAnchor, offsetX, offsetY
end


local function GetTextColorAndOpacity(profile)
    local color = profile.color
    local r = Utils:ClampNumber(color and color.r, 0, 1, 1)
    local g = Utils:ClampNumber(color and color.g, 0, 1, 1)
    local b = Utils:ClampNumber(color and color.b, 0, 1, 1)
    local a = Utils:ClampNumber(profile.opacity, 0, 1, 1)
    return r, g, b, a
end

local function GetTextProfile(parentProfile)
    local profile = parentProfile
    if type(profile) ~= "table" then
        profile = {}
    end

    local textProfile = profile.text
    if type(textProfile) ~= "table" then
        textProfile = {}
    end

    return textProfile
end

local function NewDBInstance()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:GetIncomingCastBarDB(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts" or "profile.partyFrame.incomingCasts"
    return self.storage:GetValuesTableAtPath(path)
end

function Object:GetIncomingCastIndicatorAnchorsAndOffsets(layoutAxis, useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.frame" or "profile.partyFrame.incomingCasts.frame"
    local profile, defaults = self.storage:GetValueAndDefaultAtPath(path)
    local spellBarAnchor, relativeAnchor, offsetX, offsetY = GetFrameAnchorsAndOffsets(
        profile,
        defaults,
        -200,
        200,
        layoutAxis
    )

    return relativeAnchor, spellBarAnchor, offsetX, offsetY
end

function Object:GetIncomingCastIndicatorAnchorFrame(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.frame" or "profile.partyFrame.incomingCasts.frame"
    local profile, defaults = self.storage:GetValueAndDefaultAtPath(path)
    local fallback = defaults.anchorTarget or frameAnchorTargets.HEALTHBAR
    return Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or fallback
end

function Object:GetIncomingCastIndicatorCount(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts" or "profile.partyFrame.incomingCasts"
    local profile, defaults = self.storage:GetValueAndDefaultAtPath(path)
    return Utils:ClampInteger(profile and profile.spellCount, 1, 6, defaults.spellCount)
end

function Object:GetIncomingCastIndicatorIconCooldownTextShow(useRaid)
    local path = useRaid == true
        and "profile.raidFrame.incomingCasts.icon.cooldownText.show"
        or "profile.partyFrame.incomingCasts.icon.cooldownText.show"

    local show = self.storage:GetBooleanAtPath(path)
    return show == true
end

function Object:GetIncomingCastIndicatorIconCooldownTextFontSize(useRaid)
    local path = useRaid == true
        and "profile.raidFrame.incomingCasts.icon.cooldownText.fontSize"
        or "profile.partyFrame.incomingCasts.icon.cooldownText.fontSize"

    local value = self.storage:GetIntegerAtPath(path, 8, 32)
    return value or 10
end

function Object:GetIncomingCastIndicatorIconCooldownTextColor(useRaid)
    local path = useRaid == true
        and "profile.raidFrame.incomingCasts.icon.cooldownText.color"
        or "profile.partyFrame.incomingCasts.icon.cooldownText.color"

    local color = self.storage:GetColorAtPath(path) or { r = 1, g = 1, b = 1 }
    return color.r, color.g, color.b
end

function Object:GetIncomingCastIndicatorGrowDirection(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.growthDirection" or "profile.partyFrame.incomingCasts.growthDirection"
    local value = self.storage:GetOptionAtPath(path, growthDirections)
    return value or growthDirections.RIGHT
end

local function GetRaidIncomingCastsEnabledType(self)
    local profile, defaults = self.storage:GetValueAndDefaultAtPath("profile.raidFrame.incomingCasts")
    local defaultValue = defaults.enabledType or raidFrameOverrideTypes.PARTY
    local value = profile and profile.enabledType
    return Utils:SanitizeOption(value, raidFrameOverrideTypes) or defaultValue
end

function Object:GetRaidTrackIncomingCasts()
    local enabledType = GetRaidIncomingCastsEnabledType(self)
    if enabledType == raidFrameOverrideTypes.DISABLED then
        return false
    end
    if enabledType == raidFrameOverrideTypes.PARTY then
        return self:GetTrackIncomingCasts()
    end
    return true
end

function Object:ShouldUsePartyIncomingCastsSettingsForRaid()
    local enabledType = GetRaidIncomingCastsEnabledType(self)
    return enabledType == raidFrameOverrideTypes.PARTY
end

function Object:GetBuffCountdownFontSize()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.buffs.cooldownText.fontSize", 8, 32)
    return value or 10
end

function Object:GetDebuffCountdownFontSize()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.debuffs.cooldownText.fontSize", 8, 32)
    return value or 10
end

function Object:GetBuffCountdownColor()
    local color = self.storage:GetColorAtPath("profile.partyFrame.buffs.cooldownText.color")
    return color or { r = 1, g = 1, b = 1 }
end

function Object:GetBuffCountdownShowUnderSeconds()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.buffs.cooldownText.showUnderSeconds", 0, 60)
    return value or 0
end

function Object:GetDebuffCountdownColor()
    local color = self.storage:GetColorAtPath("profile.partyFrame.debuffs.cooldownText.color")
    return color or { r = 1, g = 1, b = 1 }
end

function Object:GetBuffCountdownWarningThresholdSeconds()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.buffs.thresholds.warning.thresholdSeconds", 0, 60)
    return value or 10
end

function Object:GetBuffCountdownWarningEnabled()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.buffs.thresholds.warning.enabled")
    return value == true
end

function Object:GetBuffCountdownWarningColor()
    local color = self.storage:GetColorAtPath("profile.partyFrame.buffs.thresholds.warning.color")
    return color or { r = 1, g = 0.55, b = 0 }
end

function Object:GetBuffCountdownCriticalThresholdSeconds()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.buffs.thresholds.critical.thresholdSeconds", 0, 60)
    return value or 5
end

function Object:GetBuffCountdownCriticalEnabled()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.buffs.thresholds.critical.enabled")
    return value == true
end

function Object:GetBuffCountdownCriticalColor()
    local color = self.storage:GetColorAtPath("profile.partyFrame.buffs.thresholds.critical.color")
    return color or { r = 1, g = 0, b = 0 }
end

function Object:GetDebuffCountdownWarningThresholdSeconds()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.debuffs.thresholds.warning.thresholdSeconds", 0, 60)
    return value or 10
end

function Object:GetDebuffCountdownWarningEnabled()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.debuffs.thresholds.warning.enabled")
    return value == true
end

function Object:GetDebuffCountdownWarningColor()
    local color = self.storage:GetColorAtPath("profile.partyFrame.debuffs.thresholds.warning.color")
    return color or { r = 1, g = 0.55, b = 0 }
end

function Object:GetDebuffCountdownCriticalThresholdSeconds()
    local value = self.storage:GetIntegerAtPath("profile.partyFrame.debuffs.thresholds.critical.thresholdSeconds", 0, 60)
    return value or 5
end

function Object:GetDebuffCountdownCriticalEnabled()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.debuffs.thresholds.critical.enabled")
    return value == true
end

function Object:GetDebuffCountdownCriticalColor()
    local color = self.storage:GetColorAtPath("profile.partyFrame.debuffs.thresholds.critical.color")
    return color or { r = 1, g = 0, b = 0 }
end

function Object:GetBuffCountdownDynamicColorConfig()
    return {
        normalColor = self:GetBuffCountdownColor(),
        warningEnabled = self:GetBuffCountdownWarningEnabled(),
        warningThresholdSeconds = self:GetBuffCountdownWarningThresholdSeconds(),
        warningColor = self:GetBuffCountdownWarningColor(),
        criticalEnabled = self:GetBuffCountdownCriticalEnabled(),
        criticalThresholdSeconds = self:GetBuffCountdownCriticalThresholdSeconds(),
        criticalColor = self:GetBuffCountdownCriticalColor(),
    }
end

function Object:GetDebuffCountdownDynamicColorConfig()
    return {
        normalColor = self:GetDebuffCountdownColor(),
        warningEnabled = self:GetDebuffCountdownWarningEnabled(),
        warningThresholdSeconds = self:GetDebuffCountdownWarningThresholdSeconds(),
        warningColor = self:GetDebuffCountdownWarningColor(),
        criticalEnabled = self:GetDebuffCountdownCriticalEnabled(),
        criticalThresholdSeconds = self:GetDebuffCountdownCriticalThresholdSeconds(),
        criticalColor = self:GetDebuffCountdownCriticalColor(),
    }
end

local function GetRaidPlayerStatusTextOverrideType(self)
    local value = self.storage:GetOptionAtPath("profile.raidFrame.playerStatus.customizeTextType", raidFrameOverrideTypes)
    return value or raidFrameOverrideTypes.PARTY
end

local function GetRaidPlayerStatusFrameOverrideType(self)
    local value = self.storage:GetOptionAtPath("profile.raidFrame.playerStatus.customizeFrameType", raidFrameOverrideTypes)
    return value or raidFrameOverrideTypes.PARTY
end

local function GetRaidPlayerNameTextOverrideType(self)
    local value = self.storage:GetOptionAtPath("profile.raidFrame.playerName.customizeTextType", raidFrameOverrideTypes)
    return value or raidFrameOverrideTypes.PARTY
end

local function GetRaidPlayerNameFrameOverrideType(self)
    local value = self.storage:GetOptionAtPath("profile.raidFrame.playerName.customizeFrameType", raidFrameOverrideTypes)
    return value or raidFrameOverrideTypes.PARTY
end

local function GetFrameBasePath(isRaid, overrideType)
    if isRaid == true and overrideType == raidFrameOverrideTypes.ENABLED then
        return "profile.raidFrame"
    end
    return "profile.partyFrame"
end

function Object:GetEffectivePlayerStatusFrameCustomize(isRaid)
    if isRaid == true then
        local overrideType = GetRaidPlayerStatusFrameOverrideType(self)
        if overrideType == raidFrameOverrideTypes.DISABLED then
            return false
        end
        if overrideType == raidFrameOverrideTypes.ENABLED then
            return true
        end
    end

    local value = self.storage:GetBooleanAtPath("profile.partyFrame.playerStatus.customizeFrame")
    return value == true
end

function Object:GetEffectivePlayerStatusTextCustomize(isRaid)
    if isRaid == true then
        local overrideType = GetRaidPlayerStatusTextOverrideType(self)
        if overrideType == raidFrameOverrideTypes.DISABLED then
            return false
        end
        if overrideType == raidFrameOverrideTypes.ENABLED then
            return true
        end
    end

    local value = self.storage:GetBooleanAtPath("profile.partyFrame.playerStatus.customizeText")
    return value == true
end

function Object:GetEffectivePlayerNameFrameCustomize(isRaid)
    if isRaid == true then
        local overrideType = GetRaidPlayerNameFrameOverrideType(self)
        if overrideType == raidFrameOverrideTypes.DISABLED then
            return false
        end
        if overrideType == raidFrameOverrideTypes.ENABLED then
            return true
        end
    end

    local value = self.storage:GetBooleanAtPath("profile.partyFrame.playerName.customizeFrame")
    return value == true
end

function Object:GetEffectivePlayerNameTextCustomize(isRaid)
    if isRaid == true then
        local overrideType = GetRaidPlayerNameTextOverrideType(self)
        if overrideType == raidFrameOverrideTypes.DISABLED then
            return false
        end
        if overrideType == raidFrameOverrideTypes.ENABLED then
            return true
        end
    end

    local value = self.storage:GetBooleanAtPath("profile.partyFrame.playerName.customizeText")
    return value == true
end

local function GetEffectivePlayerAnchorsAndOffsets(self, path, layoutAxis)
    local profile, defaults = self.storage:GetValueAndDefaultAtPath(path)
    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget
    local point, relativePoint, offsetX, offsetY = GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetEffectivePlayerStatusAnchorsAndOffsets(layoutAxis, isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerStatusFrameOverrideType(self))
    return GetEffectivePlayerAnchorsAndOffsets(self, basePath .. ".playerStatus.frame", layoutAxis)
end

function Object:GetEffectivePlayerNameAnchorsAndOffsets(layoutAxis, isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerNameFrameOverrideType(self))
    return GetEffectivePlayerAnchorsAndOffsets(self, basePath .. ".playerName.frame", layoutAxis)
end

function Object:GetEffectivePlayerStatusColor(isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerStatusTextOverrideType(self))
    local profile = self.storage:GetValuesTableAtPath(basePath .. ".playerStatus")
    return GetTextColorAndOpacity(GetTextProfile(profile))
end

function Object:GetEffectivePlayerStatusUseClassColors(isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerStatusTextOverrideType(self))
    local value = self.storage:GetBooleanAtPath(basePath .. ".playerStatus.text.useClassColors")
    return value == true
end

function Object:GetEffectivePlayerStatusFontSize(isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerStatusTextOverrideType(self))
    local value = self.storage:GetIntegerAtPath(basePath .. ".playerStatus.text.fontSize", 8, 32)
    return value or 10
end

function Object:GetEffectivePlayerNameColor(isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerNameTextOverrideType(self))
    local profile = self.storage:GetValuesTableAtPath(basePath .. ".playerName")
    return GetTextColorAndOpacity(GetTextProfile(profile))
end

function Object:GetEffectivePlayerNameUseClassColors(isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerNameTextOverrideType(self))
    local value = self.storage:GetBooleanAtPath(basePath .. ".playerName.text.useClassColors")
    return value == true
end

function Object:GetEffectivePlayerNameFontSize(isRaid)
    local basePath = GetFrameBasePath(isRaid, GetRaidPlayerNameTextOverrideType(self))
    local value = self.storage:GetIntegerAtPath(basePath .. ".playerName.text.fontSize", 8, 32)
    return value or 10
end

function Object:GetAllowAnyAnchoring()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.allowAnyAnchoring")
    return value == true
end

function Object:GetShowInSolo()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.showInSolo")
    return value == true
end

function Object:GetPlayerFrameShowType()
    local configuredTypes = self.PLAYER_FRAME_SHOW_TYPES or playerFrameShowTypes
    local profile = self.storage:GetValuesTableAtPath("profile.playerFrame")
    local defaultValue = configuredTypes.ALWAYS
    local value = profile and profile.showType

    return Utils:SanitizeOption(value, configuredTypes) or defaultValue
end

function Object:GetShowPartyFrameTitle()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.showTitle")
    return value == true
end

function Object:GetShowBuffCountdown()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.buffs.cooldownText.show")
    return value == true
end

function Object:GetShowDebuffCountdown()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.debuffs.cooldownText.show")
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

    local value = self.storage:GetBooleanAtPath("profile.partyFrame.roleIcons." .. key)
    return value == true
end

function Object:GetHealthBarTexture()
    local useCustom = self.storage:GetBooleanAtPath("profile.partyFrame.healthBar.useCustomTexture")
    if useCustom ~= true then
        return nil
    end

    local texture = self.storage:GetStringAtPath("profile.partyFrame.healthBar.texture")
    if type(texture) ~= "string" or texture == "" then
        return nil
    end
    return texture
end

function Object:GetTrackIncomingCasts()
    local value = self.storage:GetBooleanAtPath("profile.partyFrame.incomingCasts.enabled")
    return value == true
end

function Object:SetIncomingCastsPreviewEnabled(enabled)
    self.runtime = self.runtime or {}
    self.runtime.incomingCastsPreviewEnabled = enabled == true
end

function Object:SetProfile(profileName)
    local storage = self.storage
    local previousProfileName = storage:GetCurrentProfile()
    local profileAlreadyExists = storage:HasProfile(profileName)

    storage:SetProfile(profileName)

    if not profileAlreadyExists and previousProfileName and previousProfileName ~= profileName then
        -- Copy from previous profile if new and not the same name
        storage:CopyProfile(previousProfileName, profileName)
    end

    Utils:Log("FF_SET_PROFILE", storage:GetCurrentProfile())
    self:MigrateAndSanitizeDB()

    -- Remove AceDB's "Default" profile if it exists and is not the current profile.
    local currentProfile = storage:GetCurrentProfile()
    if currentProfile ~= "Default" and storage:HasProfile("Default") then
        storage:DeleteProfile("Default")
    end
    return true
end

function Object:ResetProfile()
    -- Ensure the active profile table exists before AceDB mutates it.
    local _ = self.storage and self.storage.db and self.storage.db.profile

    self.storage:ResetProfile()
    Utils:Log("FF_RESET_PROFILE", self.storage:GetCurrentProfile())
    self:MigrateAndSanitizeDB()
    return true
end

function Object:CopyProfile(sourceProfileName, isSilent)
    self.storage:CopyProfile(sourceProfileName, isSilent)
    self:MigrateAndSanitizeDB()

    Utils:Log("FF_COPY_PROFILE", {
        from = sourceProfileName,
        to = self.storage:GetCurrentProfile(),
    })
end

function Object:InitializeDB()
    local defaults = {
        profile = self.DEFAULT_SETTINGS or {},
    }

    local Storage = addon and addon.Storage
    assert(Storage, "FoxFrames: Storage object missing (load order issue)")

    self.storage = Storage:New("FoxFramesDB", defaults)
    self.db = self.storage.db
    Utils:Log("FF_LOADED_PROFILE", self.storage:GetCurrentProfile())
    self:MigrateAndSanitizeDB()
end

local db = NewDBInstance()
db.DEFAULT_SETTINGS = defaultSettings
db.FRAME_ANCHOR_TARGETS = frameAnchorTargets
db.PLAYER_FRAME_SHOW_TYPES = playerFrameShowTypes
db.RAID_FRAME_OVERRIDE_TYPES = raidFrameOverrideTypes

if addon then
    addon.DB = db
end
