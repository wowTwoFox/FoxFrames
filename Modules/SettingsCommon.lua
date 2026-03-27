local addonName, addon = ...

local Constants = addon.Constants
local DB = addon.DB
local Utils = addon.Utils

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")

local SettingsCommon = {}
addon.SettingsCommon = SettingsCommon

SettingsCommon.ANCHOR_POINT_LABELS = {
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

SettingsCommon.SPELL_BAR_ANCHOR_MODE_LABELS = {
    [Constants.ANCHOR_MODES.INSIDE] = "Inside",
    [Constants.ANCHOR_MODES.AUTO] = "Outside (Auto)",
    [Constants.ANCHOR_MODES.OUTSIDEV] = "Outside (Vertical)",
    [Constants.ANCHOR_MODES.OUTSIDEH] = "Outside (Horizontal)",
}

SettingsCommon.FRAME_ANCHOR_TARGET_LABELS = {
    [DB.FRAME_ANCHOR_TARGETS.FRAME] = "Unit Frame",
    [DB.FRAME_ANCHOR_TARGETS.HEALTHBAR] = "Health Bar",
}

SettingsCommon.GROWTH_DIRECTION_LABELS = {
    [Constants.GROWTH_DIRECTIONS.RIGHT] = "Right",
    [Constants.GROWTH_DIRECTIONS.LEFT] = "Left",
    [Constants.GROWTH_DIRECTIONS.DOWN] = "Down",
    [Constants.GROWTH_DIRECTIONS.UP] = "Up",
}

local function ValidateSettingsPath(path)
    return DB.storage and DB.storage:ValidatePathExists(path) == true
end

function SettingsCommon:GetTextures()
    local alreadyAddedPaths = {}

    local textures = {{
        path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        name = "Raid",
    }, {
        path = "Interface\\Buttons\\WHITE8X8",
        name = "Flat",
    }}

    for _, texture in ipairs(textures) do
        if texture.path then
            alreadyAddedPaths[texture.path] = texture.name
        end
    end

    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local statusBarTextures = LSM:List("statusbar")
        for _, name in pairs(statusBarTextures) do
            local path = LSM:Fetch("statusbar", name)
            if path and not alreadyAddedPaths[path] then
                alreadyAddedPaths[path] = name
                table.insert(textures, {
                    path = path,
                    name = name,
                })
            end
        end
    end

    return textures
end

function SettingsCommon:AddFrameSettings(category, options)
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
        values = SettingsCommon.FRAME_ANCHOR_TARGET_LABELS,
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
        values = SettingsCommon.ANCHOR_POINT_LABELS,
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
        values = SettingsCommon.SPELL_BAR_ANCHOR_MODE_LABELS,
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

function SettingsCommon:AddTextSettings(category, options)
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
        hasOpacity = false
        ,
        parent = useClassColorsElement,
        parentCheck = function()
            return GetValue("useClassColors") ~= true
        end,
        minHeight = 36,
    })
end

function SettingsCommon:AddCooldownTextSettings(category, options)
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
        parent = showElement,
        parentCheck = function()
            return IsCooldownTextEnabled()
        end,
    }

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

function SettingsCommon:CreateBooleanSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local key = (type(opts.key) == "string" and opts.key ~= "" and opts.key)
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    if not (key and path and name) then
        return nil
    end

    if not ValidateSettingsPath(path) then
        return nil
    end

    local defaults = DB.storage:GetDefaultsTableAtPath(path)
    local defaultValue = defaults == true

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

function SettingsCommon:CreateAuraSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local basePath = (type(opts.basePath) == "string" and opts.basePath ~= "" and opts.basePath)
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: CreateAuraSettings requires onChanged callback")

    if not (category and basePath and keyPrefix) then
        return
    end

    if not ValidateSettingsPath(basePath) then
        return
    end

    local cooldownTextPath = basePath .. ".cooldownText"
    local cooldownKeyPrefix = keyPrefix .. "CooldownText"

    SettingsLib:CreateHeader(category, {
        name = "Cooldown",
    })

    self:AddCooldownTextSettings(category, {
        path = cooldownTextPath,
        keyPrefix = cooldownKeyPrefix,
        prefix = prefix,
        onChanged = onChanged,
    })
end

return SettingsCommon
