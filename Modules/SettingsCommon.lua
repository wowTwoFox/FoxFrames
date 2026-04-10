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

function SettingsCommon:RefreshSettingsLayout()
	if SettingsInbound and SettingsInbound.RepairDisplay then
		SettingsInbound.RepairDisplay()
		return
	end
	if SettingsPanel and SettingsPanel.RepairDisplay then
		SettingsPanel:RepairDisplay()
		return
	end
end

function SettingsCommon:AddFrameSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddFrameSettings requires onChanged callback")

    if not (category and path) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local _, defaults = DB.storage:GetValueAndDefaultAtPath(path)
    local defaultAnchorTarget = Utils:SanitizeOption(defaults.anchorTarget, DB.FRAME_ANCHOR_TARGETS) or DB.FRAME_ANCHOR_TARGETS.FRAME
    local defaultPosition = Utils:SanitizeAnchorPoint(defaults.position, Constants.ANCHOR_POINTS.CENTER)
    local defaultAnchorMode = Utils:SanitizeAnchorMode(defaults.anchorMode, Constants.ANCHOR_MODES.INSIDE)
    local defaultOffsetX = Utils:ClampInteger(defaults.offsetX, -40, 40, 0)
    local defaultOffsetY = Utils:ClampInteger(defaults.offsetY, -40, 40, 0)
    local defaultUseRelativeOffsets = defaults.useRelativeOffsets ~= false

    local function OnChanged(settingKey)
        onChanged(settingKey)
    end

    self:CreateDropdown(category, {
        path = path .. ".anchorTarget",
        name = "Anchor To",
        default = defaultAnchorTarget,
        values = SettingsCommon.FRAME_ANCHOR_TARGET_LABELS,
        sanitize = function(value, fallback)
            return Utils:SanitizeOption(value, DB.FRAME_ANCHOR_TARGETS) or fallback
        end,
        onChanged = function()
            OnChanged("anchorTarget")
        end,
        desc = "Choose whether this element is anchored to the unit frame or to the health bar.",
        prefix = prefix,
    })

    self:CreateDropdown(category, {
        path = path .. ".position",
        name = "Position",
        default = defaultPosition,
        values = SettingsCommon.ANCHOR_POINT_LABELS,
        sanitize = function(value, fallback)
            return Utils:SanitizeAnchorPoint(value, fallback or defaultPosition)
        end,
        onChanged = function()
            OnChanged("position")
        end,
        desc = "Anchor point used for this element.",
        prefix = prefix,
    })

    self:CreateDropdown(category, {
        path = path .. ".anchorMode",
        name = "Anchor Mode",
        default = defaultAnchorMode,
        values = SettingsCommon.SPELL_BAR_ANCHOR_MODE_LABELS,
        sanitize = function(value, fallback)
            return Utils:SanitizeAnchorMode(value, fallback or defaultAnchorMode)
        end,
        onChanged = function()
            OnChanged("anchorMode")
        end,
        desc = "Inside uses the same anchor point as Position.\nOutside (Vertical) flips Top <-> Bottom.\nOutside (Horizontal) flips Left <-> Right.\nOutside (Auto) picks Vertical/Horizontal based on the party frame orientation (horizontal vs vertical layout).\nExample: party frames stacked top-to-bottom -> Auto uses Outside (Horizontal).",
        prefix = prefix,
    })

    self:CreateSlider(category, {
        path = path .. ".offsetX",
        name = "X Offset",
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", Utils:ClampInteger(value, -40, 40, defaultOffsetX))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, -40, 40, fallback)
        end,
        onChanged = function()
            OnChanged("offsetX")
        end,
        desc = "Horizontal offset for anchoring.",
        prefix = prefix,
    })

    self:CreateSlider(category, {
        path = path .. ".offsetY",
        name = "Y Offset",
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", Utils:ClampInteger(value, -40, 40, defaultOffsetY))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, -40, 40, fallback)
        end,
        onChanged = function()
            OnChanged("offsetY")
        end,
        desc = "Vertical offset for anchoring.",
        prefix = prefix,
    })

    self:CreateCheckbox(category, {
        path = path .. ".useRelativeOffsets",
        name = "Use Relative Offsets",
        default = defaultUseRelativeOffsets,
        onChanged = function()
            OnChanged("useRelativeOffsets")
        end,
        desc = "When enabled, X/Y offsets are flipped based on anchor point.",
        prefix = prefix,
    })
end

function SettingsCommon:AddTextSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddTextSettings requires onChanged callback")

    if not (category and path) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local _, defaults = DB.storage:GetValueAndDefaultAtPath(path)
    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 10)
    local defaultColor = Utils:SanitizeColor(defaults.color, { r = 1, g = 1, b = 1 })
    local defaultOpacity = Utils:SanitizeOpacity(defaults.opacity, 1)

    local function GetValue(key)
        return DB.storage:GetValueAtPath(path .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(path .. "." .. key, value)
    end

    local function OnChanged(settingKey)
        onChanged(settingKey)
    end

    self:CreateSlider(category, {
        path = path .. ".fontSize",
        name = "Size",
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", Utils:ClampInteger(value, 8, 32, defaultFontSize))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 8, 32, fallback)
        end,
        onChanged = function()
            OnChanged("fontSize")
        end,
        desc = "Adjust the text size on frames.",
        prefix = prefix,
    })

    self:CreateSlider(category, {
        path = path .. ".opacity",
        name = "Opacity",
        min = 0,
        max = 1,
        step = 0.01,
        formatter = function(value)
            return string.format(
                "%d%%",
                Utils:ClampInteger((value and (value * 100) or nil), 0, 100, (defaultOpacity or 1) * 100)
            )
        end,
        sanitize = function(value, fallback)
            return Utils:SanitizeOpacity(value, fallback)
        end,
        onChanged = function()
            OnChanged("opacity")
        end,
        desc = "Adjust opacity for text on frames.",
        prefix = prefix,
    })

    local useClassColorsElement = self:CreateCheckbox(category, {
        path = path .. ".useClassColors",
        name = "Use Class Colors",
        desc = "Use class colors instead of the configured static text color.",
        prefix = prefix,
        onChanged = function()
            OnChanged("useClassColors")
        end,
    })

    SettingsLib:CreateColorOverrides(category, {
        key = path .. ".color",
        entries = {
            { key = path, label = "Color" },
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
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddCooldownTextSettings requires onChanged callback")

    if not (category and path) then
        return
    end

    if not ValidateSettingsPath(path) then
        return
    end

    local defaults = DB.storage:GetDefaultsTableAtPath(path)

    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 12)
    local defaultColor = Utils:SanitizeColor(defaults.color, { r = 1, g = 1, b = 1 })

    local function GetValue(key)
        return DB.storage:GetValueAtPath(path .. "." .. key)
    end

    local function SetValue(key, value)
        DB.storage:SetValue(path .. "." .. key, value)
    end

    local function OnChanged(settingKey)
        onChanged(settingKey)
    end

    local showElement = self:CreateCheckbox(category, {
        path = path .. ".show",
        name = "Show Text",
        desc = "Toggle cooldown countdown text visibility.",
        prefix = prefix,
        onChanged = function()
            OnChanged("show")
        end,
    })

    self:CreateSlider(category, {
        path = path .. ".fontSize",
        name = "Text Size",
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", Utils:ClampInteger(value, 8, 32, defaultFontSize))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 8, 32, fallback)
        end,
        onChanged = function()
            OnChanged("fontSize")
        end,
        desc = "Adjust cooldown countdown text size.",
        prefix = prefix,
        parent = showElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(path .. ".show") == true
        end,
    })

    SettingsLib:CreateColorOverrides(category, {
        key = path .. ".color",
        entries = {
            { key = path, label = "Color" },
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
            return DB.storage:GetBooleanAtPath(path .. ".show") == true
        end,
        minHeight = 36,
    })

    return showElement
end

function SettingsCommon:CreateCheckbox(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    if not (path and name) then
        return nil
    end

    if not ValidateSettingsPath(path) then
        return nil
    end

    local defaultCandidate = DB.storage:GetDefaultAtPath(path)
    if defaultCandidate == nil then
        defaultCandidate = DB.storage:GetValueAtPath(path)
    end

    local defaultValue = defaultCandidate == true

    return SettingsLib:CreateCheckbox(category, {
        key = path,
        name = name,
        default = defaultValue,
        get = function()
            local value = DB.storage:GetValueAtPath(path)
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

function SettingsCommon:CreateDropdown(category, options)
    local opts = type(options) == "table" and options or {}
    local key = (type(opts.key) == "string" and opts.key ~= "" and opts.key) or nil
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local values = (type(opts.values) == "table" and opts.values) or (type(opts.options) == "table" and opts.options)
    local optionfunc = type(opts.optionfunc) == "function" and opts.optionfunc or nil
    local sanitize = type(opts.sanitize) == "function" and opts.sanitize or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    -- Non-storage mode: allow callers to centralize dropdown creation without DB.storage.
    -- Requires a unique key plus explicit get/set functions.
    if not path then
        if not (key and name and (values or optionfunc)) then
            return nil
        end

        if not (type(opts.get) == "function" and type(opts.set) == "function") then
            return nil
        end

        return SettingsLib:CreateDropdown(category, {
            key = key,
            name = name,
            default = opts.default,
            values = values,
            order = opts.order,
            optionfunc = optionfunc,
            get = opts.get,
            set = opts.set,
            desc = desc,
            prefix = prefix,
            parent = opts.parent,
            parentCheck = opts.parentCheck,
        })
    end

    if not (path and name and (values or optionfunc)) then
        return nil
    end

    if not ValidateSettingsPath(path) then
        return nil
    end

    local defaultCandidate = DB.storage:GetDefaultAtPath(path)
    if defaultCandidate == nil then
        defaultCandidate = DB.storage:GetValueAtPath(path)
    end

    if defaultCandidate == nil then
        return nil
    end

    local defaultValue = defaultCandidate
    if sanitize then
        defaultValue = sanitize(defaultValue, defaultCandidate) or defaultCandidate
    end

    if defaultValue == nil then
        return nil
    end

    return SettingsLib:CreateDropdown(category, {
        key = path,
        name = name,
        default = defaultValue,
        values = values,
        order = opts.order,
        optionfunc = optionfunc,
        get = function()
            local value = DB.storage:GetValueAtPath(path)
            if value == nil then
                return defaultValue
            end

            if sanitize then
                value = sanitize(value, defaultValue)
            end

            if value == nil then
                return defaultValue
            end

            return value
        end,
        set = function(value)
            local newValue = value
            if sanitize then
                newValue = sanitize(newValue, defaultValue)
            end
            if newValue == nil then
                newValue = defaultValue
            end

            if DB.storage:SetValue(path, newValue) and onChanged then
                onChanged(newValue)
            end
        end,
        desc = desc,
        prefix = prefix,
        parent = opts.parent,
        parentCheck = opts.parentCheck,
    })
end

function SettingsCommon:CreateSlider(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local min = type(opts.min) == "number" and opts.min or nil
    local max = type(opts.max) == "number" and opts.max or nil
    local step = type(opts.step) == "number" and opts.step or nil
    local formatter = type(opts.formatter) == "function" and opts.formatter or nil
    local sanitize = type(opts.sanitize) == "function" and opts.sanitize or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    if not (path and name and min and max and step) then
        return nil
    end

    if not ValidateSettingsPath(path) then
        return nil
    end

    local defaultCandidate = DB.storage:GetDefaultAtPath(path)
    if defaultCandidate == nil then
        defaultCandidate = DB.storage:GetValueAtPath(path)
    end
    if defaultCandidate == nil then
        defaultCandidate = min
    end

    local defaultValue = defaultCandidate
    if sanitize then
        defaultValue = sanitize(defaultValue, defaultCandidate)
    end
    if defaultValue == nil then
        defaultValue = defaultCandidate
    end

    return SettingsLib:CreateSlider(category, {
        key = path,
        name = name,
        default = defaultValue,
        min = min,
        max = max,
        step = step,
        formatter = formatter,
        get = function()
            local value = DB.storage:GetValueAtPath(path)
            if value == nil then
                return defaultValue
            end

            if sanitize then
                value = sanitize(value, defaultValue)
            end

            if value == nil then
                return defaultValue
            end

            return value
        end,
        set = function(value)
            local newValue = value
            if sanitize then
                newValue = sanitize(newValue, defaultValue)
            end
            if newValue == nil then
                newValue = defaultValue
            end

            if DB.storage:SetValue(path, newValue) and onChanged then
                onChanged(newValue)
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
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: CreateAuraSettings requires onChanged callback")

    if not (category and basePath) then
        return
    end

    if not ValidateSettingsPath(basePath) then
        return
    end

    local cooldownTextPath = basePath .. ".cooldownText"

    SettingsLib:CreateHeader(category, {
        name = "Cooldown",
    })

    local showElement = self:AddCooldownTextSettings(category, {
        path = cooldownTextPath,
        prefix = prefix,
        onChanged = onChanged,
    })

    local defaults = DB.storage:GetDefaultsTableAtPath(cooldownTextPath) or {}

    local warningDefaults = type(defaults.warning) == "table" and defaults.warning or {}
    local criticalDefaults = type(defaults.critical) == "table" and defaults.critical or {}

    local defaultWarningThresholdSeconds = Utils:ClampInteger(warningDefaults.thresholdSeconds, 0, 60, 10)
    local defaultCriticalThresholdSeconds = Utils:ClampInteger(criticalDefaults.thresholdSeconds, 0, 60, 5)

    local defaultWarningColor = Utils:SanitizeColor(warningDefaults.color, { r = 1, g = 0.55, b = 0 })
    local defaultCriticalColor = Utils:SanitizeColor(criticalDefaults.color, { r = 1, g = 0, b = 0 })

    SettingsLib:CreateHeader(category, {
        name = "Thresholds",
    })

    local warningEnabledElement = self:CreateCheckbox(category, {
        path = cooldownTextPath .. ".warning.enabled",
        name = "Warning",
        desc = "Enable Warning threshold coloring for this countdown.",
        prefix = prefix,
        onChanged = function()
            onChanged("warningEnabled")
        end,
    })

    local warningThresholdElement = self:CreateSlider(category, {
        path = cooldownTextPath .. ".warning.thresholdSeconds",
        name = "Seconds",
        min = 0,
        max = 60,
        step = 1,
        formatter = function(value)
            return string.format("%is", Utils:ClampInteger(value, 0, 60, defaultWarningThresholdSeconds))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 0, 60, fallback)
        end,
        onChanged = function()
            onChanged("warningThresholdSeconds")
        end,
        desc = "When remaining duration is at or below this value, countdown text uses the Warning color.",
        prefix = prefix,
        parent = warningEnabledElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(cooldownTextPath .. ".show") == true
                and DB.storage:GetBooleanAtPath(cooldownTextPath .. ".warning.enabled") == true
        end,
    })

    SettingsLib:CreateColorOverrides(category, {
        key = cooldownTextPath .. ".warning.color",
        entries = {
            { key = cooldownTextPath .. ".warning", label = "Color" },
        },
        getColor = function()
            local color = Utils:SanitizeColor(DB.storage:GetValueAtPath(cooldownTextPath .. ".warning.color"), defaultWarningColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            DB.storage:SetValue(cooldownTextPath .. ".warning.color", Utils:SanitizeColor({ r = r, g = g, b = b }, defaultWarningColor))
            onChanged("warningColor")
        end,
        getDefaultColor = function()
            local color = Utils:SanitizeColor(defaultWarningColor, { r = 1, g = 1, b = 1 })
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        parent = warningThresholdElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(cooldownTextPath .. ".show") == true
                and DB.storage:GetBooleanAtPath(cooldownTextPath .. ".warning.enabled") == true
        end,
        minHeight = 36,
    })

    local criticalEnabledElement = self:CreateCheckbox(category, {
        path = cooldownTextPath .. ".critical.enabled",
        name = "Critical",
        desc = "Enable Critical threshold coloring for this countdown.",
        prefix = prefix,
        onChanged = function()
            onChanged("criticalEnabled")
        end,
    })

    local criticalThresholdElement = self:CreateSlider(category, {
        path = cooldownTextPath .. ".critical.thresholdSeconds",
        name = "Seconds",
        min = 0,
        max = 60,
        step = 1,
        formatter = function(value)
            return string.format("%is", Utils:ClampInteger(value, 0, 60, defaultCriticalThresholdSeconds))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 0, 60, fallback)
        end,
        onChanged = function()
            onChanged("criticalThresholdSeconds")
        end,
        desc = "When remaining duration is at or below this value, countdown text uses the Critical color.",
        prefix = prefix,
        parent = criticalEnabledElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(cooldownTextPath .. ".show") == true
                and DB.storage:GetBooleanAtPath(cooldownTextPath .. ".critical.enabled") == true
        end,
    })

    SettingsLib:CreateColorOverrides(category, {
        key = cooldownTextPath .. ".critical.color",
        entries = {
            { key = cooldownTextPath .. ".critical", label = "Color" },
        },
        getColor = function()
            local color = Utils:SanitizeColor(DB.storage:GetValueAtPath(cooldownTextPath .. ".critical.color"), defaultCriticalColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            DB.storage:SetValue(cooldownTextPath .. ".critical.color", Utils:SanitizeColor({ r = r, g = g, b = b }, defaultCriticalColor))
            onChanged("criticalColor")
        end,
        getDefaultColor = function()
            local color = Utils:SanitizeColor(defaultCriticalColor, { r = 1, g = 1, b = 1 })
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        parent = criticalThresholdElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(cooldownTextPath .. ".show") == true
                and DB.storage:GetBooleanAtPath(cooldownTextPath .. ".critical.enabled") == true
        end,
        minHeight = 36,
    })
end

return SettingsCommon
