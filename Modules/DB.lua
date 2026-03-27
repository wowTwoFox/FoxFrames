
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

local raidIncomingCastsEnabledTypes = {
    ENABLED = "ENABLED",
    DISABLED = "DISABLED",
    PARTY = "PARTY",
}

local defaultPlayerStatus = {
    text = {
        fontSize = 17,
        opacity = 1,
        color = {
            r = 1,
            g = 1,
            b = 1,
        },
        useClassColors = false,
    },
    customizeFrame = true,
    customizeText = true,
    frame = {
        anchorTarget = frameAnchorTargets.FRAME,
        position = anchorPoints.CENTER,
        offsetX = 0,
        offsetY = 0,
        useRelativeOffsets = true,
        anchorMode = anchorModes.INSIDE,
    }
}

local defaultPlayerName = {
    text = {
        fontSize = 8,
        opacity = 1,
        color = {
            r = 1,
            g = 1,
            b = 1,
        },
        useClassColors = false,
    },
    customizeFrame = true,
    customizeText = true,
    frame = {
        anchorTarget = frameAnchorTargets.FRAME,
        position = anchorPoints.CENTER,
        offsetX = 0,
        offsetY = -14,
        useRelativeOffsets = true,
        anchorMode = anchorModes.INSIDE,
    }
}

local defaultIncomingCastBar = {
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

local defaultRaidIncomingCasts = {
    enabledType = "PARTY",
    spellCount = defaultIncomingCastBar.spellCount,
    frame = defaultIncomingCastBar.frame,
    growthDirection = defaultIncomingCastBar.growthDirection,
    icon = defaultIncomingCastBar.icon,
}

local defaultPartyIncomingCasts = {
    enabled = false,
    spellCount = defaultIncomingCastBar.spellCount,
    frame = defaultIncomingCastBar.frame,
    growthDirection = defaultIncomingCastBar.growthDirection,
    icon = defaultIncomingCastBar.icon,
}

local defaultAura = {
    cooldownText = {
        show = true,
        fontSize = 12,
        color = {
            r = 1,
            g = 1,
            b = 1,
        },
    },
}

local defaultSettings = {
    playerFrame = {
        showType = playerFrameShowTypes.NEVER,
    },
    partyFrame = {
        showTitle = false,
        showTankRoleIcon = true,
        showHealerRoleIcon = true,
        showDPSRoleIcon = false,
        showInSolo = true,
        buffs = defaultAura,
        debuffs = defaultAura,
        playerStatus = defaultPlayerStatus,
        playerName = defaultPlayerName,
        allowAnyAnchoring = true,
        incomingCasts = defaultPartyIncomingCasts,
    },
    raidFrame = {
        playerStatus = defaultPlayerStatus,
        playerName = defaultPlayerName,
        incomingCasts = defaultRaidIncomingCasts,
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

local function GetTextFontSize(textProfile, minValue, maxValue)
    local profile = textProfile
    if type(profile) ~= "table" then
        profile = {}
    end

    local min = type(minValue) == "number" and minValue or 8
    local max = type(maxValue) == "number" and maxValue or 32
    return Utils:ClampInteger(profile.fontSize, min, max, 10)
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

local function GetTextUseClassColors(textProfile)
    local profile = textProfile
    if type(profile) ~= "table" then
        return false
    end

    return profile.useClassColors and profile.useClassColors == true
end

local function GetCooldownTextShow(cooldownTextProfile)
    local profile = cooldownTextProfile
    if type(profile) ~= "table" then
        return false
    end

    return profile.show and  profile.show == true
end

local function GetCooldownTextColor(cooldownTextProfile)
    local profile = cooldownTextProfile
    local defaultColor = { r = 1, g = 1, b = 1 }
    if type(profile) ~= "table" then
        return defaultColor
    end

    local color = Utils:SanitizeColor(profile.color, defaultColor)
    return color.r, color.g, color.b
end

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:GetDBProfile()
    return self.storage:GetValuesTableAtPath("profile")
end

function Object:GetPartyFrameDB()
    return self.storage:GetValuesTableAtPath("profile.partyFrame")
end

function Object:GetPlayerFrameDB()
    return self.storage:GetValuesTableAtPath("profile.playerFrame")
end

function Object:GetIncomingCastBarDB()
    return self.storage:GetValuesTableAtPath("profile.partyFrame.incomingCasts")
end

function Object:GetRaidIncomingCastsDB()
    return self.storage:GetValuesTableAtPath("profile.raidFrame.incomingCasts")
end

function Object:GetIncomingCastBarIconDB()
    return self.storage:GetValuesTableAtPath("profile.partyFrame.incomingCasts.icon")
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

function Object:GetIncomingCastIndicatorAnchorsAndOffsets(layoutAxis, useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.frame" or "profile.partyFrame.incomingCasts.frame"
    local profile, defaults = self.storage:GetTableAtPath(path)
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
    local profile, defaults = self.storage:GetTableAtPath(path)
    local fallback = defaults.anchorTarget or frameAnchorTargets.HEALTHBAR
    return Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or fallback
end

function Object:GetIncomingCastIndicatorCount(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts" or "profile.partyFrame.incomingCasts"
    local profile, defaults = self.storage:GetTableAtPath(path)
    return Utils:ClampInteger(profile and profile.spellCount, 1, 6, defaults.spellCount)
end

function Object:GetIncomingCastIndicatorIconCooldownTextShow(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.icon.cooldownText" or "profile.partyFrame.incomingCasts.icon.cooldownText"
    local profile = self.storage:GetTableAtPath(path)
    return GetCooldownTextShow(profile)
end

function Object:GetIncomingCastIndicatorIconCooldownTextFontSize(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.icon.cooldownText" or "profile.partyFrame.incomingCasts.icon.cooldownText"
    local profile = self.storage:GetValuesTableAtPath(path)
    return GetTextFontSize(profile, 8, 32)
end

function Object:GetIncomingCastIndicatorIconCooldownTextColor(useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts.icon.cooldownText" or "profile.partyFrame.incomingCasts.icon.cooldownText"
    local profile, defaults = self.storage:GetTableAtPath(path)
    return GetCooldownTextColor(profile)
end

function Object:GetIncomingCastIndicatorGrowDirection(relativeAnchor, useRaid)
    local path = useRaid == true and "profile.raidFrame.incomingCasts" or "profile.partyFrame.incomingCasts"
    local profile, defaults = self.storage:GetTableAtPath(path)
    local fallback = defaults.growthDirection or growthDirections.RIGHT
    local explicitValue = profile and rawget(profile, "growthDirection")

    if explicitValue == nil then
        local anchor = relativeAnchor
        if anchor == nil then
            anchor = self:GetIncomingCastIndicatorAnchorsAndOffsets(nil, useRaid)
        end

        if Utils:IsAnchorRightAligned(anchor) then
            return growthDirections.LEFT
        end

        return fallback
    end

    return Utils:SanitizeGrowthDirection(explicitValue, fallback)
end

function Object:GetRaidIncomingCastsEnabledType()
    local profile, defaults = self.storage:GetTableAtPath("profile.raidFrame.incomingCasts")
    local defaultValue = defaults.enabledType or raidIncomingCastsEnabledTypes.PARTY
    local value = profile and profile.enabledType
    return Utils:SanitizeOption(value, raidIncomingCastsEnabledTypes) or defaultValue
end

function Object:GetRaidTrackIncomingCasts()
    local enabledType = self:GetRaidIncomingCastsEnabledType()
    if enabledType == raidIncomingCastsEnabledTypes.DISABLED then
        return false
    end
    if enabledType == raidIncomingCastsEnabledTypes.PARTY then
        return self:GetTrackIncomingCasts()
    end
    return true
end

function Object:ShouldUsePartyIncomingCastsSettingsForRaid()
    local enabledType = self:GetRaidIncomingCastsEnabledType()
    return enabledType == raidIncomingCastsEnabledTypes.PARTY
end

function Object:GetBuffCountdownFontSize()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.buffs.cooldownText")
    return GetTextFontSize(profile, 8, 32)
end

function Object:GetDebuffCountdownFontSize()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.debuffs.cooldownText")
    return GetTextFontSize(profile, 8, 32)
end

function Object:GetBuffCountdownColor()
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.buffs.cooldownText")
    return GetCooldownTextColor(profile)
end

function Object:GetDebuffCountdownColor()
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.debuffs.cooldownText")
    return GetCooldownTextColor(profile)
end

function Object:GetPlayerStatusAnchorsAndOffsets(layoutAxis)
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.playerStatus.frame")
    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget

    local point, relativePoint, offsetX, offsetY = GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetRaidPlayerStatusAnchorsAndOffsets(layoutAxis)
    local profile, defaults = self.storage:GetTableAtPath("profile.raidFrame.playerStatus.frame")
    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget

    local point, relativePoint, offsetX, offsetY = GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetPlayerStatusFrameCustomize()
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.playerStatus")
    local defaultValue = defaults.customizeFrame ~= false
    local value = profile and profile.customizeFrame

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetPlayerStatusTextCustomize()
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.playerStatus")
    local defaultValue = defaults.customizeText ~= false
    local value = profile and profile.customizeText

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetPlayerStatusColor()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerStatus")
    return GetTextColorAndOpacity(GetTextProfile(profile))
end

function Object:GetRaidPlayerStatusColor()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerStatus")
    return GetTextColorAndOpacity(GetTextProfile(profile))
end

function Object:GetPlayerStatusUseClassColors()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerStatus")
    return GetTextUseClassColors(GetTextProfile(profile))
end

function Object:GetRaidPlayerStatusUseClassColors()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerStatus")
    return GetTextUseClassColors(GetTextProfile(profile))
end

function Object:GetPlayerNameAnchorsAndOffsets(layoutAxis)
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.playerName.frame")
    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget

    local point, relativePoint, offsetX, offsetY = GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetRaidPlayerNameAnchorsAndOffsets(layoutAxis)
    local profile, defaults = self.storage:GetTableAtPath("profile.raidFrame.playerName.frame")
    local defaultTarget = defaults.anchorTarget or frameAnchorTargets.FRAME
    local target = Utils:SanitizeOption(profile and profile.anchorTarget, frameAnchorTargets) or defaultTarget

    local point, relativePoint, offsetX, offsetY = GetFrameAnchorsAndOffsets(profile, defaults, -100, 100, layoutAxis)
    return point, relativePoint, target, offsetX, offsetY
end

function Object:GetPlayerNameFrameCustomize()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerName")
    local defaultValue = false
    local value = profile and profile.customizeFrame

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetPlayerNameTextCustomize()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerName")
    local defaultValue = false
    local value = profile and profile.customizeText

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetPlayerNameColor()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerName")
    return GetTextColorAndOpacity(GetTextProfile(profile))
end

function Object:GetRaidPlayerNameColor()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerName")
    return GetTextColorAndOpacity(GetTextProfile(profile))
end

function Object:GetPlayerNameUseClassColors()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerName")
    return GetTextUseClassColors(GetTextProfile(profile))
end

function Object:GetRaidPlayerNameUseClassColors()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerName")
    return GetTextUseClassColors(GetTextProfile(profile))
end

function Object:GetPlayerNameFontSize()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerName")
    return GetTextFontSize(GetTextProfile(profile), 8, 32)
end

function Object:GetRaidPlayerNameFontSize()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerName")
    return GetTextFontSize(GetTextProfile(profile), 8, 32)
end

function Object:GetPlayerStatusFontSize()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.playerStatus")
    return GetTextFontSize(GetTextProfile(profile), 8, 32)
end

function Object:GetRaidPlayerStatusFontSize()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerStatus")
    return GetTextFontSize(GetTextProfile(profile), 8, 32)
end

function Object:GetRaidPlayerStatusTextOverrideEnabled()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerStatus")
    return profile and profile.customizeText == true
end

function Object:GetRaidPlayerStatusFrameOverrideEnabled()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerStatus")
    return profile and profile.customizeFrame == true
end

function Object:GetRaidPlayerNameTextOverrideEnabled()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerName")
    return profile and profile.customizeText == true
end

function Object:GetRaidPlayerNameFrameOverrideEnabled()
    local profile = self.storage:GetValuesTableAtPath("profile.raidFrame.playerName")
    return profile and profile.customizeFrame == true
end

function Object:GetAllowAnyAnchoring()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame")
    local defaultValue = true
    local value = profile and profile.allowAnyAnchoring

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetShowInSolo()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame")
    local defaultValue = true
    local value = profile and profile.showInSolo

    if value == nil then
        return defaultValue
    end

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
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame")
    local defaultValue = false
    local value = profile and profile.showTitle

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetShowBuffCountdown()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.buffs.cooldownText")
    return GetCooldownTextShow(profile)
end

function Object:GetShowDebuffCountdown()
    local profile = self.storage:GetValuesTableAtPath("profile.partyFrame.debuffs.cooldownText")
    return GetCooldownTextShow(profile)
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

    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame")
    local defaultValue = defaults[key] ~= false
    local value = profile and profile[key]

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:GetHealthBarTexture()
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame")
    local useCustom = profile and profile.useCustomHealthBarTexture

    if useCustom == nil then
        useCustom = defaults.useCustomHealthBarTexture == true
    end

    if useCustom ~= true then
        return nil
    end

    local texture = profile and profile.healthBarTexture
    if texture == nil then
        texture = defaults.healthBarTexture
    end
    if type(texture) ~= "string" or texture == "" then
        return nil
    end

    return texture
end

function Object:GetTrackIncomingCasts()
    local profile, defaults = self.storage:GetTableAtPath("profile.partyFrame.incomingCasts")
    local defaultValue = defaults.enabled == true
    local value = profile and profile.enabled

    if value == nil then
        return defaultValue
    end

    return value == true
end

function Object:IsIncomingCastsPreviewEnabled()
    return self.runtime and self.runtime.incomingCastsPreviewEnabled == true
end

function Object:SetIncomingCastsPreviewEnabled(enabled)
    self.runtime = self.runtime or {}
    self.runtime.incomingCastsPreviewEnabled = enabled == true
end

function Object:SetProfile(profileName, options)
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

local db = Object:New()
db.DEFAULT_SETTINGS = defaultSettings
db.ANCHOR_POINTS = anchorPoints
db.FRAME_ANCHOR_TARGETS = frameAnchorTargets
db.PLAYER_FRAME_SHOW_TYPES = playerFrameShowTypes
db.GROWTH_DIRECTIONS = growthDirections

if addon then
    addon.DB = db
end
