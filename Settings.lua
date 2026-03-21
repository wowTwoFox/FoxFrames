local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local Constants = addon.Constants

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

local ANCHOR_POINT_LABELS = {
    [Constants.ANCHOR_POINTS.TOPLEFT] = "Top Left",
    [Constants.ANCHOR_POINTS.TOP] = "Top",
    [Constants.ANCHOR_POINTS.TOPRIGHT] = "Top Right",
    [Constants.ANCHOR_POINTS.LEFT] = "Left",
    [Constants.ANCHOR_POINTS.CENTER] = "Center",
    [Constants.ANCHOR_POINTS.RIGHT] = "Right",
    [Constants.ANCHOR_POINTS.BOTTOMLEFT] = "Bottom Left",
    [Constants.ANCHOR_POINTS.BOTTOM] = "Bottom",
    [Constants.ANCHOR_POINTS.BOTTOMRIGHT] = "Bottom Right",
}
local FRAME_ANCHOR_TARGET_LABELS = {
    [DB.FRAME_ANCHOR_TARGETS.FRAME] = "Party Frame",
    [DB.FRAME_ANCHOR_TARGETS.HEALTHBAR] = "Health Bar",
}
local PLAYER_FRAME_SHOW_TYPE_LABELS = {
    [DB.PLAYER_FRAME_SHOW_TYPES.ALWAYS] = "Always",
    [DB.PLAYER_FRAME_SHOW_TYPES.SOLO] = "Solo",
    [DB.PLAYER_FRAME_SHOW_TYPES.NEVER] = "Never",
}
local GROWTH_DIRECTION_LABELS = {
    [Constants.GROWTH_DIRECTIONS.RIGHT] = "Right",
    [Constants.GROWTH_DIRECTIONS.LEFT] = "Left",
    [Constants.GROWTH_DIRECTIONS.DOWN] = "Down",
    [Constants.GROWTH_DIRECTIONS.UP] = "Up",
}

local SPELL_BAR_ANCHOR_MODE_LABELS = {
    [DB.SPELL_BAR_ANCHOR_MODES.INSIDE] = "Inside",
    [DB.SPELL_BAR_ANCHOR_MODES.AUTO] = "Outside (Auto)",
    [DB.SPELL_BAR_ANCHOR_MODES.OUTSIDEV] = "Outside (Vertical)",
    [DB.SPELL_BAR_ANCHOR_MODES.OUTSIDEH] = "Outside (Horizontal)",
}

function FF:GetTextures()
    local alreadyAddedPaths = {}

    -- Always add built-in textures at the top in specific order
    local textures = {{
        path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        name = "Raid"
    }, {
        path = "Interface\\Buttons\\WHITE8X8",
        name = "Flat"
    }}

    -- Go through built in textures
    for _, texture in ipairs(textures) do
        if texture.path then
            alreadyAddedPaths[texture.path] = texture.name
        end
    end

    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        -- Use LibSharedMedia if available and add additional textures
        local statusBarTextures = LSM:List("statusbar")
        for _, name in pairs(statusBarTextures) do
            local path = LSM:Fetch("statusbar", name)
            if path and not alreadyAddedPaths[path] then
                alreadyAddedPaths[path] = name
                table.insert(textures, {
                    path = path,
                    name = name
                })
            end
        end
    end

    return textures
end

function FF:OpenSettings()
    if not self._rootCategory then return end
    Settings.OpenToCategory(self._rootCategory:GetID())
end

function FF:OpenIncomingCastsSettings()
    if not self._incomingCastsCategory then return end
    Settings.OpenToCategory(self._incomingCastsCategory:GetID())
end

local function SanitizePosition(value, fallback)
    return DB:SanitizeIncomingCastPosition(value, fallback)
end

local function SanitizeIncomingCastAnchorFrame(value, fallback)
    return DB:SanitizeIncomingCastAnchorFrame(value, fallback)
end

local function SanitizeStatusTextColor(value, fallback)
    return DB:SanitizeStatusTextColor(value, fallback)
end

local function SanitizeIncomingCastSpellBarAnchorMode(value, fallback)
    return DB:SanitizeIncomingCastSpellBarAnchorMode(value, fallback)
end

local function SanitizeOpacity(value, fallback)
    return DB:SanitizeOpacity(value, fallback)
end

local function PartyFrameProfile()
    return DB:GetPartyFrameDB()
end

local function PlayerFrameProfile()
    return DB:GetPlayerFrameDB()
end

local function GetIncomingCastBarValue(key)
    return DB:GetIncomingCastBarValue(key)
end

local function SetIncomingCastBarValue(key, value)
    DB:SetIncomingCastBarValue(key, value)
end

local function EnsureSubTable(parent, key)
    if type(parent) ~= "table" then
        return nil
    end

    local value = parent[key]
    if type(value) ~= "table" then
        value = {}
        parent[key] = value
    end

    return value
end

local function NormalizePath(path)
    if type(path) == "table" then
        return path
    end

    if type(path) ~= "string" or path == "" then
        return nil
    end

    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end
    return parts
end

local function GetTableAtPath(root, pathParts)
    local current = root
    for _, key in ipairs(pathParts) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[key]
    end
    return current
end

local function EnsureTableAtPath(root, pathParts)
    local current = root
    for _, key in ipairs(pathParts) do
        current = EnsureSubTable(current, key)
        if not current then
            return nil
        end
    end
    return current
end

local function GetProfileTableAtPath(pathParts)
    local profile = DB:GetDBProfile()
    return EnsureTableAtPath(profile, pathParts)
end

local function GetDefaultsTableAtPath(pathParts)
    local defaults = GetTableAtPath(DB.DEFAULT_SETTINGS, pathParts)
    if type(defaults) ~= "table" then
        defaults = {}
    end
    return defaults
end

local function AddFrameSettings(path, category, keyPrefix, prefix, applySetting)
    local pathParts = NormalizePath(path)
    if not (pathParts and category and keyPrefix) then
        return
    end

    assert(type(applySetting) == "function", "FoxFrames: AddFrameSettings requires applySetting callback")

    local defaults = GetDefaultsTableAtPath(pathParts)

    local defaultAnchorTarget = SanitizeIncomingCastAnchorFrame(defaults.anchorTarget, DB.FRAME_ANCHOR_TARGETS.FRAME)
    local defaultPosition = SanitizePosition(defaults.position, Constants.ANCHOR_POINTS.CENTER)
    local defaultAnchorMode = SanitizeIncomingCastSpellBarAnchorMode(defaults.anchorMode, DB.SPELL_BAR_ANCHOR_MODES.INSIDE)
    local defaultOffsetX = Utils:ClampInteger(defaults.offsetX, -40, 40, 0)
    local defaultOffsetY = Utils:ClampInteger(defaults.offsetY, -40, 40, 0)
    local defaultUseRelativeOffsets = defaults.useRelativeOffsets ~= false

    local function Profile()
        return GetProfileTableAtPath(pathParts)
    end

    local function GetValue(key)
        local profile = Profile()
        return profile and profile[key]
    end

    local function SetValue(key, value)
        local profile = Profile()
        if profile then
            profile[key] = value
        end
    end

    local function OnChanged(settingKey)
        applySetting(settingKey)
    end

    SettingsLib:CreateDropdown(category, {
        key = keyPrefix .. "AnchorTarget",
        name = "Anchor To",
        default = defaultAnchorTarget,
        values = FRAME_ANCHOR_TARGET_LABELS,
        get = function()
            return SanitizeIncomingCastAnchorFrame(GetValue("anchorTarget"), defaultAnchorTarget)
        end,
        set = function(value)
            SetValue("anchorTarget", SanitizeIncomingCastAnchorFrame(value, defaultAnchorTarget))
            OnChanged("anchorTarget")
        end,
        desc = "Choose whether this element is anchored to the party frame or to the health bar.",
        prefix = prefix,
    })

    SettingsLib:CreateDropdown(category, {
        key = keyPrefix .. "Position",
        name = "Position",
        default = defaultPosition,
        values = ANCHOR_POINT_LABELS,
        get = function()
            return SanitizePosition(GetValue("position"), defaultPosition)
        end,
        set = function(value)
            SetValue("position", SanitizePosition(value, defaultPosition))
            OnChanged("position")
        end,
        desc = "Anchor point used for this element.",
        prefix = prefix,
    })

    SettingsLib:CreateDropdown(category, {
        key = keyPrefix .. "AnchorMode",
        name = "Anchor Mode",
        default = defaultAnchorMode,
        values = SPELL_BAR_ANCHOR_MODE_LABELS,
        get = function()
            return SanitizeIncomingCastSpellBarAnchorMode(GetValue("anchorMode"), defaultAnchorMode)
        end,
        set = function(value)
            SetValue("anchorMode", SanitizeIncomingCastSpellBarAnchorMode(value, defaultAnchorMode))
            OnChanged("anchorMode")
        end,
        desc = "Inside uses the same anchor point as Position.\nOutside (Vertical) flips Top <-> Bottom.\nOutside (Horizontal) flips Left <-> Right.\nOutside (Auto) picks Vertical/Horizontal based on the party frame orientation (horizontal vs vertical layout).\nExample: party frames stacked top-to-bottom -> Auto uses Outside (Horizontal).",
        prefix = prefix,
    })

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "OffsetX",
        name = "X Offset",
        default = defaultOffsetX,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", Utils:ClampInteger(value, -40, 40, defaultOffsetX))
        end,
        get = function()
            local value = GetValue("offsetX")
            if value == nil then
                value = defaultOffsetX
            end
            return Utils:ClampInteger(value, -40, 40, defaultOffsetX)
        end,
        set = function(value)
            SetValue("offsetX", Utils:ClampInteger(value, -40, 40, defaultOffsetX))
            OnChanged("offsetX")
        end,
        desc = "Horizontal offset for anchoring.",
        prefix = prefix,
    })

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "OffsetY",
        name = "Y Offset",
        default = defaultOffsetY,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", Utils:ClampInteger(value, -40, 40, defaultOffsetY))
        end,
        get = function()
            local value = GetValue("offsetY")
            if value == nil then
                value = defaultOffsetY
            end
            return Utils:ClampInteger(value, -40, 40, defaultOffsetY)
        end,
        set = function(value)
            SetValue("offsetY", Utils:ClampInteger(value, -40, 40, defaultOffsetY))
            OnChanged("offsetY")
        end,
        desc = "Vertical offset for anchoring.",
        prefix = prefix,
    })

    SettingsLib:CreateCheckbox(category, {
        key = keyPrefix .. "UseRelativeOffsets",
        name = "Use Relative Offsets",
        default = defaultUseRelativeOffsets,
        get = function()
            local value = GetValue("useRelativeOffsets")
            if value == nil then
                return defaultUseRelativeOffsets
            end
            return value == true
        end,
        set = function(value)
            SetValue("useRelativeOffsets", value == true)
            OnChanged("useRelativeOffsets")
        end,
        desc = "When enabled, X/Y offsets are flipped based on anchor point.",
        prefix = prefix,
    })
end

local function AddTextSettings(path, category, keyPrefix, prefix, applySetting)
    local pathParts = NormalizePath(path)
    if not (pathParts and category and keyPrefix) then
        return
    end

    assert(type(applySetting) == "function", "FoxFrames: AddTextSettings requires applySetting callback")

    local defaults = GetDefaultsTableAtPath(pathParts)

    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 10)
    local defaultColor = SanitizeStatusTextColor(defaults.color, { r = 1, g = 1, b = 1, a = 1 })
    local defaultOpacity = SanitizeOpacity(defaults.opacity, defaultColor.a)
    local defaultUseClassColors = defaults.useClassColors == true

    local function Profile()
        return GetProfileTableAtPath(pathParts)
    end

    local function GetValue(key)
        local profile = Profile()
        return profile and profile[key]
    end

    local function SetValue(key, value)
        local profile = Profile()
        if profile then
            profile[key] = value
        end
    end

    local function OnChanged(settingKey)
        applySetting(settingKey)
    end

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "FontSize",
        name = "Size",
        default = defaultFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", Utils:ClampInteger(value, 8, 32, defaultFontSize))
        end,
        get = function()
            local value = GetValue("fontSize")
            if value == nil then
                value = defaultFontSize
            end
            return Utils:ClampInteger(value, 8, 32, defaultFontSize)
        end,
        set = function(value)
            SetValue("fontSize", Utils:ClampInteger(value, 8, 32, defaultFontSize))
            OnChanged("fontSize")
        end,
        desc = "Adjust the text size on party frames.",
        prefix = prefix,
    })

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "Opacity",
        name = "Opacity",
        default = defaultOpacity,
        min = 0,
        max = 1,
        step = 0.01,
        formatter = function(value)
            return string.format(
                "%d%%",
                Utils:ClampInteger((value and (value * 100) or nil), 0, 100, (defaultOpacity or 1) * 100)
            )
        end,
        get = function()
            local value = GetValue("opacity")
            if value == nil then
                local color = SanitizeStatusTextColor(GetValue("color"), defaultColor)
                value = color.a
            end
            return SanitizeOpacity(value, defaultOpacity)
        end,
        set = function(value)
            local opacity = SanitizeOpacity(value, defaultOpacity)
            SetValue("opacity", opacity)

            local color = SanitizeStatusTextColor(GetValue("color"), defaultColor)
            color.a = opacity
            SetValue("color", color)

            OnChanged("opacity")
        end,
        desc = "Adjust opacity for text on party frames.",
        prefix = prefix,
    })

    local useClassColorsElement = SettingsLib:CreateCheckbox(category, {
        key = keyPrefix .. "UseClassColors",
        name = "Use Class Colors",
        default = defaultUseClassColors,
        get = function()
            local value = GetValue("useClassColors")
            if value == nil then
                return defaultUseClassColors
            end
            return value == true
        end,
        set = function(value)
            SetValue("useClassColors", (value == true))
            OnChanged("useClassColors")
        end,
        desc = "Use class colors instead of the configured static text color.",
        prefix = prefix,
    })

    SettingsLib:CreateColorOverrides(category, {
        key = keyPrefix .. "Color",
        entries = {
            { key = keyPrefix, label = "Color" },
        },
        getColor = function()
            local color = SanitizeStatusTextColor(GetValue("color"), defaultColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            local currentColor = SanitizeStatusTextColor(GetValue("color"), defaultColor)
            local opacity = SanitizeOpacity(GetValue("opacity"), currentColor.a)

            SetValue("color", SanitizeStatusTextColor({ r = r, g = g, b = b, a = opacity }, defaultColor))
            SetValue("opacity", opacity)
            OnChanged("color")
        end,
        getDefaultColor = function()
            local color = SanitizeStatusTextColor(defaultColor, { r = 1, g = 1, b = 1, a = 1 })
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        isEnabled = function()
            return GetValue("useClassColors") ~= true
        end,
        parent = useClassColorsElement,
        parentCheck = function()
            return GetValue("useClassColors") ~= true
        end,
        minHeight = 36,
    })
end

local function AddCooldownTextSettings(path, category, keyPrefix, prefix, applySetting)
    local pathParts = NormalizePath(path)
    if not (pathParts and category and keyPrefix) then
        return
    end

    assert(type(applySetting) == "function", "FoxFrames: AddCooldownTextSettings requires applySetting callback")

    local defaults = GetDefaultsTableAtPath(pathParts)

    local defaultShow = defaults.show == true
    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 12)

    local function Profile()
        return GetProfileTableAtPath(pathParts)
    end

    local function GetValue(key)
        local profile = Profile()
        return profile and profile[key]
    end

    local function SetValue(key, value)
        local profile = Profile()
        if profile then
            profile[key] = value
        end
    end

    local function OnChanged(settingKey)
        applySetting(settingKey)
    end

    local showElement = SettingsLib:CreateCheckbox(category, {
        key = keyPrefix .. "CooldownText",
        name = "Show Text",
        default = defaultShow,
        get = function()
            local value = GetValue("show")
            if value == nil then
                return defaultShow
            end
            return value == true
        end,
        set = function(value)
            SetValue("show", value == true)
            OnChanged("show")
        end,
        desc = "Toggle cooldown countdown text visibility.",
        prefix = prefix,
    })

    local sliderArgs = {
        key = keyPrefix .. "CooldownFontSize",
        name = "Text Size",
        default = defaultFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", Utils:ClampInteger(value, 8, 32, defaultFontSize))
        end,
        get = function()
            local value = GetValue("fontSize")
            if value == nil then
                value = defaultFontSize
            end
            return Utils:ClampInteger(value, 8, 32, defaultFontSize)
        end,
        set = function(value)
            SetValue("fontSize", Utils:ClampInteger(value, 8, 32, defaultFontSize))
            OnChanged("fontSize")
        end,
        desc = "Adjust cooldown countdown text size.",
        prefix = prefix,
    }

    sliderArgs.parent = showElement
    sliderArgs.parentCheck = function()
        local value = GetValue("show")
        if value == nil then
            value = defaultShow
        end
        return value == true
    end

    SettingsLib:CreateSlider(category, sliderArgs)
end

local function GetIncomingCastBarIconValue(key)
    return DB:GetIncomingCastBarIconValue(key)
end

local function SetIncomingCastBarIconValue(key, value)
    DB:SetIncomingCastBarIconValue(key, value)
end

local function CreateStatusTextSettings(rootCategory, partyFramePrefix)
    local statusTextCategory = SettingsLib:CreateCategory(rootCategory, "Status Text")

    SettingsLib:CreateHeader(statusTextCategory, {
        name = "Text",
    })

    AddTextSettings("partyFrame.statusText", statusTextCategory, "StatusText", partyFramePrefix, function(settingKey)
        if settingKey == "fontSize" then
            FF:UpdateHealthTextFontSize()
        else
            FF:UpdateStatusTextColor()
        end
    end)

    SettingsLib:CreateHeader(statusTextCategory, {
        name = "Placement",
    })

    AddFrameSettings("partyFrame.statusText.frame", statusTextCategory, "StatusTextFrame", partyFramePrefix, function(_)
        FF:UpdateStatusTextAnchoring()
    end)
end

local function CreatePlayerNameSettings(rootCategory, partyFramePrefix)
    local playerNameCategory = SettingsLib:CreateCategory(rootCategory, "Player Name")

    SettingsLib:CreateHeader(playerNameCategory, {
        name = "Text",
    })

    AddTextSettings("partyFrame.playerName", playerNameCategory, "PlayerName", partyFramePrefix, function(settingKey)
        if settingKey == "fontSize" then
            FF:UpdatePlayerNameFontSize()
        else
            FF:UpdatePlayerNameColor()
        end
    end)

    SettingsLib:CreateHeader(playerNameCategory, {
        name = "Placement",
    })

    AddFrameSettings("partyFrame.playerName.frame", playerNameCategory, "PlayerNameFrame", partyFramePrefix, function(_)
        FF:UpdatePlayerNameAnchoring()
    end)
end

local function CreateBuffsSettings(rootCategory, partyFramePrefix)
    local buffsCategory = SettingsLib:CreateCategory(rootCategory, "Buffs")

    SettingsLib:CreateHeader(buffsCategory, {
        name = "Cooldown",
    })

    AddCooldownTextSettings("partyFrame.buffs.cooldownText", buffsCategory, "Buff", partyFramePrefix, function(settingKey)
        if settingKey == "show" then
            FF:ShowBuffCountdownIfNeeded()
        else
            FF:UpdateAuraCountdownFontSize()
        end
    end)
end

local function CreateDebuffsSettings(rootCategory, partyFramePrefix)
    local debuffsCategory = SettingsLib:CreateCategory(rootCategory, "Debuffs")

    SettingsLib:CreateHeader(debuffsCategory, {
        name = "Cooldown",
    })

    AddCooldownTextSettings("partyFrame.debuffs.cooldownText", debuffsCategory, "Debuff", partyFramePrefix, function(settingKey)
        if settingKey == "show" then
            FF:ShowDebuffCountdownIfNeeded()
        else
            FF:UpdateAuraCountdownFontSize()
        end
    end)
end

local function CreateIncomingCastsSettings(rootCategory)
    local incomingCastsPrefix = SETTINGS_PREFIX .. "IncomingCasts_"
    local incomingCastsCategory = SettingsLib:CreateCategory(rootCategory, "Incoming Casts")
    FF._incomingCastsCategory = incomingCastsCategory

    SettingsLib:CreateText(
        incomingCastsCategory,
        "Incoming casts are spells that are targetting you or your teamates.\nThis is not a perfect solution as it's difficult to work around Blizzard's secrets.\nSo it won't show everything."
    )

    local trackIncomingCastsElement = SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "TrackIncomingCasts",
        name = "Track Incoming Casts",
        default = DB.DEFAULT_SETTINGS.partyFrame.trackIncomingCasts,
        get = function()
            return PartyFrameProfile().trackIncomingCasts
        end,
        set = function(value)
            PartyFrameProfile().trackIncomingCasts = value
            if not value then
                FF:SetIncomingCastIndicatorPreviewEnabled(false)
            end
        end,
        prefix = incomingCastsPrefix,
        desc = "Track incoming enemy casts for party frame indicators.",
    })

    SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "IncomingCastPreview",
        name = "Preview Incoming Casts",
        default = false,
        get = function()
            return FF._ffIncomingCastIndicatorPreviewEnabled == true
        end,
        set = function(value)
            FF:SetIncomingCastIndicatorPreviewEnabled(value)
        end,
        desc = "Show preview incoming cast icons for layout tuning.",
        prefix = incomingCastsPrefix,
        parent = trackIncomingCastsElement,
        parentCheck = function()
            return PartyFrameProfile().trackIncomingCasts == true
        end,
    })

    local incomingCastBarDefaults = DB.DEFAULT_SETTINGS.incomingCastBar or {}
    local incomingCastBarIconDefaults = incomingCastBarDefaults.icon or {}

    SettingsLib:CreateDropdown(incomingCastsCategory, {
        key = "IncomingCastIconGrowDirection",
        name = "Grow Direction",
        default = incomingCastBarDefaults.growthDirection,
        values = GROWTH_DIRECTION_LABELS,
        get = function()
            return DB:GetIncomingCastIndicatorGrowDirection()
        end,
        set = function(value)
            SetIncomingCastBarValue("growthDirection", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Direction targeted spell icons grow when multiple are shown.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconCount",
        name = "Targeted Spell Icon Count",
        default = incomingCastBarDefaults.spellCount,
        min = 1,
        max = 6,
        step = 1,
        formatter = function(value)
            return string.format("%i", Utils:ClampInteger(value, 1, 6, incomingCastBarDefaults.spellCount))
        end,
        get = function()
            local value = GetIncomingCastBarValue("spellCount")
            if value == nil then
                value = incomingCastBarDefaults.spellCount
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarValue("spellCount", Utils:ClampInteger(value, 1, 6, incomingCastBarDefaults.spellCount))
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "How many targeted spell icons to show per party member.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconScale",
        name = "Icon Scale",
        default = incomingCastBarIconDefaults.scale,
        min = 0.5,
        max = 2,
        step = 0.10,
        formatter = function(value)
            return string.format(
                "%d%%",
                Utils:ClampInteger((value and (value * 100) or nil), 50, 200, (incomingCastBarIconDefaults.scale or 1) * 100)
            )
        end,
        get = function()
            local value = GetIncomingCastBarIconValue("scale")
            if value ~= nil then
                return value
            end

            return incomingCastBarIconDefaults.scale
        end,
        set = function(value)
            SetIncomingCastBarIconValue("scale", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Scales each targeted spell icon without distorting borders/overlays.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconSpacing",
        name = "Icon Spacing",
        default = incomingCastBarIconDefaults.spacing,
        min = -10,
        max = 20,
        step = 1,
        formatter = function(value)
            return string.format("%i", Utils:ClampInteger(value, -10, 20, incomingCastBarIconDefaults.spacing))
        end,
        get = function()
            local value = GetIncomingCastBarIconValue("spacing")
            if value == nil then
                value = incomingCastBarIconDefaults.spacing
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarIconValue("spacing", Utils:ClampInteger(value, -10, 20, incomingCastBarIconDefaults.spacing))
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Space (in pixels) between targeted spell icons. Negative values allow overlap.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "IncomingCastIconBorder",
        name = "Show Icon Border",
        default = incomingCastBarIconDefaults.showBorder,
        get = function()
            local value = GetIncomingCastBarIconValue("showBorder")
            if value == nil then
                value = incomingCastBarIconDefaults.showBorder
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarIconValue("showBorder", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the border around targeted spell icons.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateHeader(incomingCastsCategory, {
        name = "Cooldown",
    })

    SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "IncomingCastIconSwipe",
        name = "Show Cooldown Swipe",
        default = incomingCastBarIconDefaults.showSwipe,
        get = function()
            local value = GetIncomingCastBarIconValue("showSwipe")
            if value == nil then
                value = incomingCastBarIconDefaults.showSwipe
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarIconValue("showSwipe", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the cooldown swipe overlay on targeted spell icons.",
        prefix = incomingCastsPrefix,
    })

    AddCooldownTextSettings("incomingCastBar.icon.cooldownText", incomingCastsCategory, "IncomingCastIcon", incomingCastsPrefix, function(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end)

    SettingsLib:CreateHeader(incomingCastsCategory, {
        name = "Placement",
    })

    AddFrameSettings("incomingCastBar.frame", incomingCastsCategory, "IncomingCastFrame", incomingCastsPrefix, function(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end)
end

function FF:SetupOptions()
    -- Build the options using LibEQOL
    local PARTY_FRAME_PREFIX = SETTINGS_PREFIX .. "PartyFrame_"
    local rootCategory = SettingsLib:CreateRootCategory("Fox Frames")
    self._rootCategory = rootCategory

    SettingsLib:CreateHeader(rootCategory, {
        name = "Party Frame Settings",
    })

    SettingsLib:CreateText(
        rootCategory, 
        "You need to enable 'Raid Style Party Frames' in 'Edit Mode' to benefit from these settings."
    )

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowInSolo",
        name = "Show In Solo",
        default = DB.DEFAULT_SETTINGS.partyFrame.showInSolo,
        get = function() return PartyFrameProfile().showInSolo end,
        set = function(value)
            PartyFrameProfile().showInSolo = value
            FF:ShowPartyFrameIfNeeded()
        end,
        desc = "Toggle the frame visibility when solo.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowTitle",
        name = "Show Title",
        default = DB.DEFAULT_SETTINGS.partyFrame.showTitle,
        get = function() 
            return PartyFrameProfile().showTitle
        end,
        set = function(value)
            PartyFrameProfile().showTitle = value
            FF:ShowPartyFrameTitleIfNeeded()
        end,
        desc = "Toggle the title visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "UseClassColors",
        name = "Use Class Colors",
        default = DB.DEFAULT_SETTINGS.partyFrame.useClassColors,
        get = function() 
            return BlizzardSettings:GetClassColorSetting()
        end,
        set = function(value)
            BlizzardSettings:SetClassColorSetting(value)
        end,
        desc = "Toggle class colors raid frames",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "AllowAnyAnchoring",
        name = "Allow Any Anchoring",
        default = DB.DEFAULT_SETTINGS.partyFrame.allowAnyAnchoring,
        get = function() return PartyFrameProfile().allowAnyAnchoring end,
        set = function(value)
            PartyFrameProfile().allowAnyAnchoring = value
            FF:SetAllowAnyAnchoring()
        end,
        desc = "By default, Blizzard's party frames will convert anchoring to top-left. This results in always top-left alignment of frames. Enabling this will allow you to use other anchor points such as center, bottom or right. You will need to re-anchor the party frames after changing this setting.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateText(
        rootCategory, 
        "You will need to re-center the party frames on the UI to set the new anchor point."
    )

    -- Build texture list from LibSharedMedia or fallback to built-in
    local textureOrder = {}
    local textures = self:GetTextures()

    -- Go through built in textures
    for _, texture in ipairs(textures) do
        table.insert(textureOrder, texture.path)
    end

    local useCustomHealthBarTextureElement = SettingsLib:CreateCheckbox(rootCategory, {
        key = "UseCustomHealthBarTexture",
        name = "Use Custom Health Bar Texture",
        default = false,
        get = function()
            return PartyFrameProfile().useCustomHealthBarTexture == true
        end,
        set = function(value)
            PartyFrameProfile().useCustomHealthBarTexture = value
            if value then
                -- Default to first available texture if enabling
                if not PartyFrameProfile().healthBarTexture and textures[1] then
                    PartyFrameProfile().healthBarTexture = textures[1].path
                end
            end
            FF:UpdateFrames()
        end,
        desc = "Enable to use a custom health bar texture instead of the default.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateScrollDropdown(rootCategory, {
        key = "HealthBarTexture",
        name = "Health Bar Texture",
        default = textures[1].path,
        optionfunc = function()
            -- Return values in the order they were added
            local orderedValues = {}
            for _, texture in ipairs(textures) do
                orderedValues[texture.path] = texture.name
            end
            return orderedValues
        end,
        order = textureOrder,
        get = function()
            return PartyFrameProfile().healthBarTexture or textures[1].path
        end,
        set = function(value)
            PartyFrameProfile().healthBarTexture = value
            FF:UpdateFrames()
        end,
        height = 220, -- scrollable menu
        prefix = PARTY_FRAME_PREFIX,
        parent = useCustomHealthBarTextureElement,
        parentCheck = function()
            return PartyFrameProfile().useCustomHealthBarTexture == true
        end,
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Role Icons",
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowTankRoleIcon",
        name = "Show Tank Role Icon",
        default = DB.DEFAULT_SETTINGS.partyFrame.showTankRoleIcon,
        get = function() return PartyFrameProfile().showTankRoleIcon end,
        set = function(value) 
            PartyFrameProfile().showTankRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the Tank role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowHealerRoleIcon",
        name = "Show Healer Role Icon",
        default = DB.DEFAULT_SETTINGS.partyFrame.showHealerRoleIcon,
        get = function() return PartyFrameProfile().showHealerRoleIcon end,
        set = function(value) 
            PartyFrameProfile().showHealerRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the Healer role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowDPSRoleIcon",
        name = "Show DPS Role Icon",
        default = DB.DEFAULT_SETTINGS.partyFrame.showDPSRoleIcon,
        get = function() return PartyFrameProfile().showDPSRoleIcon end,
        set = function(value)
            PartyFrameProfile().showDPSRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the DPS role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Frames",
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "ShowPlayerFrame",
        name = "Show Player Frame",
        default = DB.DEFAULT_SETTINGS.playerFrame.showType,
        values = PLAYER_FRAME_SHOW_TYPE_LABELS,
        get = function()
            return PlayerFrameProfile().showType or DB.DEFAULT_SETTINGS.playerFrame.showType
        end,
        set = function(value)
            PlayerFrameProfile().showType = value
            self:ShowPlayerFrameIfNeeded()
        end,
        desc = "Control the visibility of the player frame. 'Always' will show the player frame regardless of group status. 'Solo' will only show the player frame when not in a party or raid. 'Never' will hide the player frame regardless of group status.",
        prefix = PARTY_FRAME_PREFIX
    })

    CreateStatusTextSettings(rootCategory, PARTY_FRAME_PREFIX)
    CreatePlayerNameSettings(rootCategory, PARTY_FRAME_PREFIX)
    CreateBuffsSettings(rootCategory, PARTY_FRAME_PREFIX)
    CreateDebuffsSettings(rootCategory, PARTY_FRAME_PREFIX)
    CreateIncomingCastsSettings(rootCategory)
end
