local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local GlobalsDB = addon.GlobalsDB
local ProfilesSettings = addon.SettingsProfiles
local Constants = addon.Constants

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

assert(ProfilesSettings and ProfilesSettings.CreateProfilesSettings, "FoxFrames: SettingsProfiles module missing (load order issue)")

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
    [DB.FRAME_ANCHOR_TARGETS.FRAME] = "Unit Frame",
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
    [Constants.ANCHOR_MODES.INSIDE] = "Inside",
    [Constants.ANCHOR_MODES.AUTO] = "Outside (Auto)",
    [Constants.ANCHOR_MODES.OUTSIDEV] = "Outside (Vertical)",
    [Constants.ANCHOR_MODES.OUTSIDEH] = "Outside (Horizontal)",
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

local function ValidateSettingsPath(path)
    return DB.storage and DB.storage:ValidatePathExists(path) == true
end

local function AddFrameSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddFrameSettings requires onChanged callback")

    if not (category and path and keyPrefix) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local _, defaults = DB.storage:GetTableAtPath(path)
    local defaultAnchorTarget = Utils:SanitizeOption(defaults.anchorTarget, DB.FRAME_ANCHOR_TARGETS) or DB.FRAME_ANCHOR_TARGETS.FRAME
    local defaultPosition = Utils:SanitizeAnchorPoint(defaults.position, Constants.ANCHOR_POINTS.CENTER)
    local defaultAnchorMode = Utils:SanitizeAnchorMode(defaults.anchorMode, Constants.ANCHOR_MODES.INSIDE)
    local defaultOffsetX = Utils:ClampInteger(defaults.offsetX, -40, 40, 0)
    local defaultOffsetY = Utils:ClampInteger(defaults.offsetY, -40, 40, 0)
    local defaultUseRelativeOffsets = defaults.useRelativeOffsets ~= false

    local function GetValue(key)
        return DB.storage:GetValue(path .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(path .. "." .. key, value)
    end

    local function OnChanged(settingKey)
        onChanged(settingKey)
    end

    SettingsLib:CreateDropdown(category, {
        key = keyPrefix .. "AnchorTarget",
        name = "Anchor To",
        default = defaultAnchorTarget,
        values = FRAME_ANCHOR_TARGET_LABELS,
        get = function()
            return Utils:SanitizeOption(GetValue("anchorTarget"), DB.FRAME_ANCHOR_TARGETS) or defaultAnchorTarget
        end,
        set = function(value)
            SetValue("anchorTarget", Utils:SanitizeOption(value, DB.FRAME_ANCHOR_TARGETS) or defaultAnchorTarget)
            OnChanged("anchorTarget")
        end,
        desc = "Choose whether this element is anchored to the unit frame or to the health bar.",
        prefix = prefix,
    })

    SettingsLib:CreateDropdown(category, {
        key = keyPrefix .. "Position",
        name = "Position",
        default = defaultPosition,
        values = ANCHOR_POINT_LABELS,
        get = function()
            return Utils:SanitizeAnchorPoint(GetValue("position"), defaultPosition)
        end,
        set = function(value)
            SetValue("position", Utils:SanitizeAnchorPoint(value, defaultPosition))
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
            return Utils:SanitizeAnchorMode(GetValue("anchorMode"), defaultAnchorMode)
        end,
        set = function(value)
            SetValue("anchorMode", Utils:SanitizeAnchorMode(value, defaultAnchorMode))
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

local function AddTextSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddTextSettings requires onChanged callback")

    if not (category and path and keyPrefix) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local _, defaults = DB.storage:GetTableAtPath(path)
    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 10)
    local defaultColor = Utils:SanitizeColor(defaults.color, { r = 1, g = 1, b = 1 })
    local defaultOpacity = Utils:SanitizeOpacity(defaults.opacity, 1)
    local defaultUseClassColors = defaults.useClassColors == true

    local function GetValue(key)
        return DB.storage:GetValue(path .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(path .. "." .. key, value)
    end

    local function OnChanged(settingKey)
        onChanged(settingKey)
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
        desc = "Adjust the text size on frames.",
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
            return Utils:SanitizeOpacity(GetValue("opacity"), defaultOpacity)
        end,
        set = function(value)
            local opacity = Utils:SanitizeOpacity(value, defaultOpacity)
            SetValue("opacity", opacity)
            OnChanged("opacity")
        end,
        desc = "Adjust opacity for text on frames.",
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
            local color = Utils:SanitizeColor(GetValue("color"), defaultColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            SetValue("color", Utils:SanitizeColor({ r = r, g = g, b = b }, defaultColor))
            OnChanged("color")
        end,
        getDefaultColor = function()
            local color = Utils:SanitizeColor(defaultColor, { r = 1, g = 1, b = 1 })
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        parent = useClassColorsElement,
        parentCheck = function()
            return GetValue("useClassColors") ~= true
        end,
        minHeight = 36,
    })
end

local function AddCooldownTextSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddCooldownTextSettings requires onChanged callback")

    if not (category and path and keyPrefix) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local defaults = DB.storage:GetDefaultsTableAtPath(path)

    local defaultShow = defaults.show == true
    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 12)
    local defaultColor = Utils:SanitizeColor(defaults.color, { r = 1, g = 1, b = 1 })

    local function GetValue(key)
        return DB.storage:GetValue(path .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(path .. "." .. key, value)
    end

    local function OnChanged(settingKey)
        onChanged(settingKey)
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

    local function IsCooldownTextEnabled()
        local value = GetValue("show")
        if value == nil then
            value = defaultShow
        end
        return value == true
    end

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
        return IsCooldownTextEnabled()
    end

    SettingsLib:CreateSlider(category, sliderArgs)

    SettingsLib:CreateColorOverrides(category, {
        key = keyPrefix .. "CooldownTextColor",
        entries = {
            { key = keyPrefix, label = "Color" },
        },
        getColor = function()
            local color = Utils:SanitizeColor(GetValue("color"), defaultColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            SetValue("color", Utils:SanitizeColor({ r = r, g = g, b = b }, defaultColor))
            OnChanged("color")
        end,
        getDefaultColor = function()
            local color = Utils:SanitizeColor(defaultColor, { r = 1, g = 1, b = 1 })
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        parent = showElement,
        parentCheck = function()
            return IsCooldownTextEnabled()
        end,
        minHeight = 36,
    })
end

local function AddIncomingCastsIconSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local iconPath = (type(opts.iconPath) == "string" and opts.iconPath ~= "" and opts.iconPath)
    local barPath = (type(opts.barPath) == "string" and opts.barPath ~= "" and opts.barPath)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil
    -- NOTE: Intentionally no parent/parentCheck gating here.
    -- LibEQOL/Settings gating requires a proper parent initializer and can be fragile.

    assert(type(onChanged) == "function", "FoxFrames: AddIncomingCastsIconSettings requires onChanged callback")

    if not (category and iconPath and barPath and keyPrefix) then
        return
    end

    if not ValidateSettingsPath(iconPath) then
        return
    end

    if not ValidateSettingsPath(barPath) then
        return
    end

    SettingsLib:CreateHeader(category, {
        name = "Icons",
    })

    local iconDefaults = DB.storage:GetDefaultsTableAtPath(iconPath) or {}
    local barDefaults = DB.storage:GetDefaultsTableAtPath(barPath) or {}

    local defaultGrowthDirection = Utils:SanitizeOption(barDefaults.growthDirection, Constants.GROWTH_DIRECTIONS) or Constants.GROWTH_DIRECTIONS.RIGHT
    local defaultSpellCount = Utils:ClampInteger(barDefaults.spellCount, 1, 6, 3)

    local defaultScale = Utils:ClampNumber(iconDefaults.scale, 0.5, 2, 1)

    local defaultSpacing = Utils:ClampInteger(iconDefaults.spacing, -10, 20, 0)
    local defaultShowBorder = iconDefaults.showBorder ~= false

    local function GetValue(key)
        return DB.storage:GetValue(iconPath .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(iconPath .. "." .. key, value)
    end

    local function GetBarValue(key)
        return DB.storage:GetValue(barPath .. "." .. key)
    end

    local function SetBarValue(key, value)
        DB.storage:SetValue(barPath .. "." .. key, value)
    end

    local function OnChanged(settingKey)
        onChanged(settingKey)
    end

    SettingsLib:CreateDropdown(category, {
        key = keyPrefix .. "GrowDirection",
        name = "Grow Direction",
        default = defaultGrowthDirection,
        values = GROWTH_DIRECTION_LABELS,
        get = function()
            return Utils:SanitizeOption(GetBarValue("growthDirection"), Constants.GROWTH_DIRECTIONS) or defaultGrowthDirection
        end,
        set = function(value)
            SetBarValue("growthDirection", Utils:SanitizeOption(value, Constants.GROWTH_DIRECTIONS) or defaultGrowthDirection)
            OnChanged("growthDirection")
        end,
        desc = "Direction targeted spell icons grow when multiple are shown.",
        prefix = prefix,
    })

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "Count",
        name = "Icon Count",
        default = defaultSpellCount,
        min = 1,
        max = 6,
        step = 1,
        formatter = function(value)
            return string.format("%i", Utils:ClampInteger(value, 1, 6, defaultSpellCount))
        end,
        get = function()
            local value = GetBarValue("spellCount")
            if value == nil then
                value = defaultSpellCount
            end
            return Utils:ClampInteger(value, 1, 6, defaultSpellCount)
        end,
        set = function(value)
            SetBarValue("spellCount", Utils:ClampInteger(value, 1, 6, defaultSpellCount))
            OnChanged("spellCount")
        end,
        desc = "How many targeted spell icons to show per party member.",
        prefix = prefix,
    })

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "Scale",
        name = "Icon Scale",
        default = defaultScale,
        min = 0.5,
        max = 2,
        step = 0.10,
        formatter = function(value)
            return string.format(
                "%d%%",
                Utils:ClampInteger((value and (value * 100) or nil), 50, 200, defaultScale * 100)
            )
        end,
        get = function()
            local value = GetValue("scale")
            if value == nil then
                value = defaultScale
            end
            return Utils:ClampNumber(value, 0.5, 2, defaultScale)
        end,
        set = function(value)
            SetValue("scale", Utils:ClampNumber(value, 0.5, 2, defaultScale))
            OnChanged("scale")
        end,
        desc = "Scales each targeted spell icon without distorting borders/overlays.",
        prefix = prefix,
    })

    SettingsLib:CreateSlider(category, {
        key = keyPrefix .. "Spacing",
        name = "Icon Spacing",
        default = defaultSpacing,
        min = -10,
        max = 20,
        step = 1,
        formatter = function(value)
            return string.format("%i", Utils:ClampInteger(value, -10, 20, defaultSpacing))
        end,
        get = function()
            local value = GetValue("spacing")
            if value == nil then
                value = defaultSpacing
            end
            return Utils:ClampInteger(value, -10, 20, defaultSpacing)
        end,
        set = function(value)
            SetValue("spacing", Utils:ClampInteger(value, -10, 20, defaultSpacing))
            OnChanged("spacing")
        end,
        desc = "Space (in pixels) between targeted spell icons. Negative values allow overlap.",
        prefix = prefix,
    })

    SettingsLib:CreateCheckbox(category, {
        key = keyPrefix .. "Border",
        name = "Show Icon Border",
        default = defaultShowBorder,
        get = function()
            local value = GetValue("showBorder")
            if value == nil then
                return defaultShowBorder
            end
            return value == true
        end,
        set = function(value)
            SetValue("showBorder", value == true)
            OnChanged("showBorder")
        end,
        desc = "Toggle the border around targeted spell icons.",
        prefix = prefix,
    })

end

local function AddIncomingCastsCooldownSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local iconPath = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddIncomingCastsCooldownSettings requires onChanged callback")

    if not (category and iconPath and keyPrefix) then
        return
    end

    if not ValidateSettingsPath(iconPath) then
        return
    end

    local iconDefaults = DB.storage:GetDefaultsTableAtPath(iconPath) or {}
    local defaultShowSwipe = iconDefaults.showSwipe ~= false

    local function GetValue(key)
        return DB.storage:GetValue(iconPath .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(iconPath .. "." .. key, value)
    end

    SettingsLib:CreateHeader(category, {
        name = "Cooldown",
    })

    SettingsLib:CreateCheckbox(category, {
        key = keyPrefix .. "Swipe",
        name = "Show Cooldown Swipe",
        default = defaultShowSwipe,
        get = function()
            local value = GetValue("showSwipe")
            if value == nil then
                return defaultShowSwipe
            end
            return value == true
        end,
        set = function(value)
            SetValue("showSwipe", value == true)
            onChanged("showSwipe")
        end,
        desc = "Toggle the cooldown swipe overlay on targeted spell icons.",
        prefix = prefix,
    })

    AddCooldownTextSettings(category, {
        path = iconPath .. ".cooldownText",
        keyPrefix = keyPrefix,
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })
end

local function AddIncomingCastsPlacementSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local framePath = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddIncomingCastsPlacementSettings requires onChanged callback")

    if not (category and framePath and keyPrefix) then
        return
    end

    SettingsLib:CreateHeader(category, {
        name = "Placement",
    })

    AddFrameSettings(category, {
        path = framePath,
        keyPrefix = keyPrefix .. "Frame",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })
end

local function CreateBooleanSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local key = (type(opts.key) == "string" and opts.key ~= "" and opts.key)
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil
    local defaultValue = opts.default == true

    if not (key and path and name) then
        return nil
    end

    if not ValidateSettingsPath(path) then
        return nil
    end

    return SettingsLib:CreateCheckbox(category, {
        key = key,
        name = name,
        default = defaultValue,
        get = function()
            local value = DB.storage:GetValue(path)
            if value == nil then
                return defaultValue
            end
            return value == true
        end,
        set = function(value)
            if DB.storage:SetValue(path, value == true) and onChanged then
                onChanged(value == true)
            end
        end,
        desc = desc,
        prefix = prefix,
        parent = opts.parent,
        parentCheck = opts.parentCheck,
    })
end

local function CreatePlayerTextElementSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil
    local framePath = path and (path .. ".frame") or nil
    local textCustomizePath = path and (path .. ".customizeText") or nil
    local frameCustomizePath = path and (path .. ".customizeFrame") or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)
    local toggleName = (type(opts.toggleName) == "string" and opts.toggleName ~= "" and opts.toggleName) or "Customize"
    local textCustomizeDesc = (type(opts.textCustomizeDesc) == "string" and opts.textCustomizeDesc ~= "" and opts.textCustomizeDesc)
    local frameCustomizeDesc = (type(opts.frameCustomizeDesc) == "string" and opts.frameCustomizeDesc ~= "" and opts.frameCustomizeDesc)

    assert(type(onChanged) == "function", "FoxFrames: CreatePlayerTextElementSettings requires onChanged callback")

    if not (category and path and keyPrefix and prefix) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local _, defaults = DB.storage:GetTableAtPath(path)

    SettingsLib:CreateHeader(category, {
        name = "Text",
    })

    local defaultCustomize = defaults.customizeText ~= false

    CreateBooleanSettings(category, {
        key = keyPrefix .. "TextCustomize",
        path = textCustomizePath,
        name = toggleName,
        default = defaultCustomize,
        prefix = prefix,
        onChanged = function()
            onChanged("customizeText")
        end,
        desc = textCustomizeDesc,
    })

    AddTextSettings(category, {
        path = path,
        keyPrefix = keyPrefix,
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })

    if not ValidateSettingsPath(framePath) then
        return
    end

    SettingsLib:CreateHeader(category, {
        name = "Placement",
    })

    CreateBooleanSettings(category, {
        key = keyPrefix .. "FrameCustomize",
        path = frameCustomizePath,
        name = toggleName,
        default = defaultCustomize,
        prefix = prefix,
        onChanged = function()
            onChanged("customizeFrame")
        end,
        desc = frameCustomizeDesc,
    })

    AddFrameSettings(category, {
        path = framePath,
        keyPrefix = keyPrefix .. "Frame",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })
end

local function CreatePartyPlayerSettings(rootCategory, framePrefix, basePath)
    if type(basePath) ~= "string" or basePath == "" then
        return
    end

    local playerNameCategory = SettingsLib:CreateCategory(rootCategory, "Player Name")
    CreatePlayerTextElementSettings(playerNameCategory, {
        prefix = framePrefix .. "PlayerName_",
        path = basePath .. ".playerName",
        keyPrefix = "PlayerName",
        toggleName = "Customize",
        textCustomizeDesc = "Toggle FoxFrames text customization for Player Name.",
        frameCustomizeDesc = "Toggle FoxFrames placement customization for Player Name.",
        onChanged = function(_)
            FF:ApplyPlayerNameSettings()
        end,
    })

    local playerStatusCategory = SettingsLib:CreateCategory(rootCategory, "Player Status")
    CreatePlayerTextElementSettings(playerStatusCategory, {
        prefix = framePrefix .. "PlayerStatus_",
        path = basePath .. ".playerStatus",
        keyPrefix = "PlayerStatus",
        toggleName = "Customize",
        textCustomizeDesc = "Toggle FoxFrames text customization for Player Status.",
        frameCustomizeDesc = "Toggle FoxFrames placement customization for Player Status.",
        onChanged = function(_)
            FF:ApplyPlayerStatusSettings()
        end,
    })
end

local function CreateRaidPlayerSettings(rootCategory, framePrefix)
    local basePath = "profile.raidFrame"

    local raidPlayerNameCategory = SettingsLib:CreateCategory(rootCategory, "Raid Player Name")
    CreatePlayerTextElementSettings(raidPlayerNameCategory, {
        prefix = framePrefix .. "PlayerName_",
        path = basePath .. ".playerName",
        keyPrefix = "RaidPlayerName",
        toggleName = "Override",
        textCustomizeDesc = "Override text settings for Raid Player Name when in a raid. When disabled, uses Party settings.",
        frameCustomizeDesc = "Override placement settings for Raid Player Name when in a raid. When disabled, uses Party settings.",
        onChanged = function(_)
            FF:ApplyPlayerNameSettings()
        end,
    })

    local raidPlayerStatusCategory = SettingsLib:CreateCategory(rootCategory, "Raid Player Status")
    CreatePlayerTextElementSettings(raidPlayerStatusCategory, {
        prefix = framePrefix .. "PlayerStatus_",
        path = basePath .. ".playerStatus",
        keyPrefix = "RaidPlayerStatus",
        toggleName = "Override",
        textCustomizeDesc = "Override text settings for Raid Player Status when in a raid. When disabled, uses Party settings.",
        frameCustomizeDesc = "Override placement settings for Raid Player Status when in a raid. When disabled, uses Party settings.",
        onChanged = function(_)
            FF:ApplyPlayerStatusSettings()
        end,
    })
end

local function CreateBuffsSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)

    if not (rootCategory and path and keyPrefix) then
        return
    end

    local cooldownTextPath = path .. ".cooldownText"
    local cooldownKeyPrefix = keyPrefix .. "CooldownText"

    local buffsCategory = SettingsLib:CreateCategory(rootCategory, "Buffs")

    SettingsLib:CreateHeader(buffsCategory, {
        name = "Cooldown",
    })

    AddCooldownTextSettings(buffsCategory, {
        path = cooldownTextPath,
        keyPrefix = cooldownKeyPrefix,
        prefix = prefix,
        onChanged = function(settingKey)
            if settingKey == "show" then
                FF:ShowBuffCountdownIfNeeded()
            elseif settingKey == "fontSize" then
                FF:UpdateAuraCountdownFontSize()
            else
                FF:UpdateAuraCountdownColor()
            end
        end,
    })
end

local function CreateDebuffsSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)

    if not (rootCategory and path and keyPrefix) then
        return
    end

    local cooldownTextPath = path .. ".cooldownText"
    local cooldownKeyPrefix = keyPrefix .. "CooldownText"

    local debuffsCategory = SettingsLib:CreateCategory(rootCategory, "Debuffs")

    SettingsLib:CreateHeader(debuffsCategory, {
        name = "Cooldown",
    })

    AddCooldownTextSettings(debuffsCategory, {
        path = cooldownTextPath,
        keyPrefix = cooldownKeyPrefix,
        prefix = prefix,
        onChanged = function(settingKey)
            if settingKey == "show" then
                FF:ShowDebuffCountdownIfNeeded()
            elseif settingKey == "fontSize" then
                FF:UpdateAuraCountdownFontSize()
            else
                FF:UpdateAuraCountdownColor()
            end
        end,
    })
end

local function CreateGlobalIncomingCastsSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local basePath = (type(opts.basePath) == "string" and opts.basePath ~= "" and opts.basePath)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: CreateGlobalIncomingCastsSettings requires onChanged callback")

    if not (category and basePath) then
        return
    end

    if not ValidateSettingsPath(basePath) then
        return
    end

    local iconPath = basePath .. ".icon"

    AddIncomingCastsIconSettings(category, {
        iconPath = iconPath,
        barPath = basePath,
        keyPrefix = "IncomingCastIcon",
        prefix = prefix,
        onChanged = function(_)
            onChanged("icons")
        end,
    })

    AddIncomingCastsCooldownSettings(category, {
        path = iconPath,
        keyPrefix = "IncomingCastIcon",
        prefix = prefix,
        onChanged = function(_)
            onChanged("cooldown")
        end,
    })

    AddIncomingCastsPlacementSettings(category, {
        path = basePath .. ".frame",
        keyPrefix = "IncomingCast",
        prefix = prefix,
        onChanged = function(_)
            onChanged("placement")
        end,
    })
end

local function CreatePartyIncomingCastsSettings(rootCategory)
    if not rootCategory then
        return
    end

    local trackIncomingCastsPath = "profile.partyFrame.incomingCasts.enabled"
    local incomingCastsBasePath = "profile.partyFrame.incomingCasts"

    local incomingCastsPrefix = SETTINGS_PREFIX .. "IncomingCasts_"
    local incomingCastsCategory = SettingsLib:CreateCategory(rootCategory, "Incoming Casts")
    FF._incomingCastsCategory = incomingCastsCategory

    local function OnChanged(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end

    SettingsLib:CreateText(
        incomingCastsCategory,
        "Incoming casts are spells that are targetting you or your teamates.\nThis is not a perfect solution as it's difficult to work around Blizzard's secrets.\nSo it won't show everything."
    )

    local trackIncomingCastsDefaults = DB.storage:GetDefaultsTableAtPath(trackIncomingCastsPath)
    local defaultTrackIncomingCasts = trackIncomingCastsDefaults == true

    local function IsTrackingEnabled()
        local value = DB.storage:GetValue(trackIncomingCastsPath)
        if value == nil then
            return defaultTrackIncomingCasts
        end
        return value == true
    end

    local trackIncomingCastsElement = SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "TrackIncomingCasts",
        name = "Track Incoming Casts",
        default = defaultTrackIncomingCasts,
        get = function()
            return IsTrackingEnabled()
        end,
        set = function(value)
            DB.storage:SetValue(trackIncomingCastsPath, value == true)
            if not value then
                FF:SetIncomingCastIndicatorPreviewEnabled(false)
            end
            OnChanged("trackIncomingCasts")
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
    })

    CreateGlobalIncomingCastsSettings(incomingCastsCategory, {
        basePath = incomingCastsBasePath,
        prefix = incomingCastsPrefix,
        onChanged = OnChanged,
    })
end

local function CreateRaidIncomingCastsSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    local enabledTypePath = "profile.raidFrame.incomingCasts.enabledType"
    local incomingCastsBasePath = "profile.raidFrame.incomingCasts"
    local incomingCastsPrefix = prefix and (prefix .. "IncomingCasts_") or nil
    local incomingCastsCategory = SettingsLib:CreateCategory(rootCategory, "Incoming Casts")

    if not prefix then
        return
    end

    local function OnChanged(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end

    SettingsLib:CreateText(
        incomingCastsCategory,
        "Incoming casts are spells that are targetting you or your teamates.\nThis is not a perfect solution as it's difficult to work around Blizzard's secrets.\nSo it won't show everything."
    )

    local enabledTypeDefaults = DB.storage:GetDefaultsTableAtPath(enabledTypePath)
    local defaultEnabledType = type(enabledTypeDefaults) == "string" and enabledTypeDefaults or "PARTY"

    local function GetEnabledType()
        local value = DB.storage:GetValue(enabledTypePath)
        if value == nil then
            return defaultEnabledType
        end

        value = Utils:SanitizeOption(value, { ENABLED = "ENABLED", DISABLED = "DISABLED", PARTY = "PARTY" })
        return value or defaultEnabledType
    end

    local function IsEnabledForRaid()
        local enabledType = GetEnabledType()
        return enabledType == "ENABLED"
    end

    local trackIncomingCastsElement = SettingsLib:CreateDropdown(incomingCastsCategory, {
        key = "IncomingCastsEnabledType",
        name = "Incoming Casts",
        default = defaultEnabledType,
        values = {
            ENABLED = "Enabled",
            DISABLED = "Disabled",
            PARTY = "Use Party Settings",
        },
        get = function()
            return GetEnabledType()
        end,
        set = function(value)
            value = Utils:SanitizeOption(value, { ENABLED = "ENABLED", DISABLED = "DISABLED", PARTY = "PARTY" }) or defaultEnabledType
            DB.storage:SetValue(enabledTypePath, value)
            if value == "DISABLED" then
                FF:SetIncomingCastIndicatorPreviewEnabled(false)
            end
            OnChanged("enabledType")
        end,
        prefix = incomingCastsPrefix,
        desc = "Enable raid incoming casts, disable them, or reuse Party settings.",
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
    })

    CreateGlobalIncomingCastsSettings(incomingCastsCategory, {
        basePath = incomingCastsBasePath,
        prefix = incomingCastsPrefix,
        onChanged = OnChanged,
    })
end

function FF:SetupOptions()
    -- Build the options using LibEQOL
    local PARTY_FRAME_PREFIX = SETTINGS_PREFIX .. "PartyFrame_"
    local RAID_FRAME_PREFIX = SETTINGS_PREFIX .. "RaidFrame_"
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
        get = function() return DB:GetPartyFrameDB().showInSolo end,
        set = function(value)
            DB:GetPartyFrameDB().showInSolo = value
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
            return DB:GetPartyFrameDB().showTitle
        end,
        set = function(value)
            DB:GetPartyFrameDB().showTitle = value
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
        get = function() return DB:GetPartyFrameDB().allowAnyAnchoring end,
        set = function(value)
            DB:GetPartyFrameDB().allowAnyAnchoring = value
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
            return DB:GetPartyFrameDB().useCustomHealthBarTexture == true
        end,
        set = function(value)
            DB:GetPartyFrameDB().useCustomHealthBarTexture = value
            if value then
                -- Default to first available texture if enabling
                if not DB:GetPartyFrameDB().healthBarTexture and textures[1] then
                    DB:GetPartyFrameDB().healthBarTexture = textures[1].path
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
            return DB:GetPartyFrameDB().healthBarTexture or textures[1].path
        end,
        set = function(value)
            DB:GetPartyFrameDB().healthBarTexture = value
            FF:UpdateFrames()
        end,
        height = 220, -- scrollable menu
        prefix = PARTY_FRAME_PREFIX,
        parent = useCustomHealthBarTextureElement,
        parentCheck = function()
            return DB:GetPartyFrameDB().useCustomHealthBarTexture == true
        end,
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Role Icons",
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowTankRoleIcon",
        name = "Show Tank Role Icon",
        default = DB.DEFAULT_SETTINGS.partyFrame.showTankRoleIcon,
        get = function() return DB:GetPartyFrameDB().showTankRoleIcon end,
        set = function(value) 
            DB:GetPartyFrameDB().showTankRoleIcon = value
            FF:UpdateFrames()
        end,
        
        desc = "Toggle the Tank role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowHealerRoleIcon",
        name = "Show Healer Role Icon",
        default = DB.DEFAULT_SETTINGS.partyFrame.showHealerRoleIcon,
        get = function() return DB:GetPartyFrameDB().showHealerRoleIcon end,
        set = function(value) 
            DB:GetPartyFrameDB().showHealerRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the Healer role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowDPSRoleIcon",
        name = "Show DPS Role Icon",
        default = DB.DEFAULT_SETTINGS.partyFrame.showDPSRoleIcon,
        get = function() return DB:GetPartyFrameDB().showDPSRoleIcon end,
        set = function(value)
            DB:GetPartyFrameDB().showDPSRoleIcon = value
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
            return DB:GetPlayerFrameDB().showType or DB.DEFAULT_SETTINGS.playerFrame.showType
        end,
        set = function(value)
            DB:GetPlayerFrameDB().showType = value
            self:ShowPlayerFrameIfNeeded()
        end,
        desc = "Control the visibility of the player frame. 'Always' will show the player frame regardless of group status. 'Solo' will only show the player frame when not in a party or raid. 'Never' will hide the player frame regardless of group status.",
        prefix = PARTY_FRAME_PREFIX
    })

    ProfilesSettings:CreateProfilesSettings(rootCategory, {
        onProfileActivated = function()
            self:SetupFrames()
        end,
    })

    CreatePartyPlayerSettings(rootCategory, PARTY_FRAME_PREFIX, "profile.partyFrame")

    CreateBuffsSettings(rootCategory, {
        path = "profile.partyFrame.buffs",
        prefix = PARTY_FRAME_PREFIX,
        keyPrefix = "Buff",
    })

    CreateDebuffsSettings(rootCategory, {
        path = "profile.partyFrame.debuffs",
        prefix = PARTY_FRAME_PREFIX,
        keyPrefix = "Debuff",
    })

    CreatePartyIncomingCastsSettings(rootCategory)

    local raidCategory = SettingsLib:CreateCategory(rootCategory, "Raid")
    CreateRaidIncomingCastsSettings(raidCategory, {
        prefix = RAID_FRAME_PREFIX,
    })
    CreateRaidPlayerSettings(raidCategory, RAID_FRAME_PREFIX)
end
