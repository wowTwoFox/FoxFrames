local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local SettingsCommon = addon.SettingsCommon

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")

local AuraSettings = {}
addon.AuraSettings = AuraSettings

assert(SettingsCommon, "FoxFrames: SettingsCommon module missing (load order issue)")
assert(type(SettingsCommon.CreateCheckbox) == "function", "FoxFrames: SettingsCommon missing CreateCheckbox")
assert(type(SettingsCommon.CreateSlider) == "function", "FoxFrames: SettingsCommon missing CreateSlider")
assert(type(SettingsCommon.CreateCheckboxSlider) == "function", "FoxFrames: SettingsCommon missing CreateCheckboxSlider")

local function ValidateSettingsPath(path)
    if DB.storage and type(path) == "string" and path ~= "" then
        DB.storage:ValidatePathExists(path)
    end
end

function AuraSettings:AddCooldownTextSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddCooldownTextSettings requires onChanged callback")

    if not (category and path) then
        return nil
    end

    ValidateSettingsPath(path)

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

    local showElement = SettingsCommon:CreateCheckbox(category, {
        path = path .. ".show",
        name = "Show Text",
        desc = "Toggle cooldown countdown text visibility.",
        prefix = prefix,
        onChanged = function()
            OnChanged("show")
        end,
    })

    SettingsCommon:CreateSlider(category, {
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
    })

    return showElement
end

local function CreateAuraSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local basePath = (type(opts.basePath) == "string" and opts.basePath ~= "" and opts.basePath)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: CreateAuraSettings requires onChanged callback")

    if not (category and basePath) then
        return nil
    end

    ValidateSettingsPath(basePath)

    local cooldownTextPath = basePath .. ".cooldownText"

    SettingsLib:CreateHeader(category, {
        name = "Cooldown",
    })

    local showElement = AuraSettings:AddCooldownTextSettings(category, {
        path = cooldownTextPath,
        prefix = prefix,
        onChanged = onChanged,
    })

    return showElement
end

local function CreateThresholdSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc) or nil
    local sliderDesc = (type(opts.sliderDesc) == "string" and opts.sliderDesc ~= "" and opts.sliderDesc) or nil
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    local defaultThresholdSeconds = type(opts.defaultThresholdSeconds) == "number" and opts.defaultThresholdSeconds or 0
    local defaultColor = type(opts.defaultColor) == "table" and opts.defaultColor or { r = 1, g = 1, b = 1 }

    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil
    local enabledKey = (type(opts.enabledKey) == "string" and opts.enabledKey ~= "" and opts.enabledKey) or nil
    local secondsKey = (type(opts.secondsKey) == "string" and opts.secondsKey ~= "" and opts.secondsKey) or nil
    local colorKey = (type(opts.colorKey) == "string" and opts.colorKey ~= "" and opts.colorKey) or nil

    assert(type(onChanged) == "function", "FoxFrames: CreateThresholdSettings requires onChanged callback")

    if not (category and path and name and enabledKey and secondsKey and colorKey) then
        return nil
    end

    local enabledPath = path .. ".enabled"
    local secondsPath = path .. ".thresholdSeconds"
    local colorPath = path .. ".color"

    ValidateSettingsPath(enabledPath)
    ValidateSettingsPath(secondsPath)
    ValidateSettingsPath(colorPath)

    local enabledElement = SettingsCommon:CreateCheckboxSlider(category, {
        path = enabledPath,
        sliderPath = secondsPath,
        name = name,
        desc = desc,
        sliderName = "Seconds",
        sliderDesc = sliderDesc,
        min = 0,
        max = 60,
        step = 1,
        formatter = function(value)
            return string.format("%is", Utils:ClampInteger(value, 0, 60, defaultThresholdSeconds))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 0, 60, fallback)
        end,
        onCheckboxChanged = function()
            onChanged(enabledKey)
        end,
        onSliderChanged = function()
            onChanged(secondsKey)
        end,
        prefix = prefix,
    })

    SettingsLib:CreateColorOverrides(category, {
        key = colorPath,
        entries = {
            { key = path, label = "Color" },
        },
        getColor = function()
            local color = Utils:SanitizeColor(DB.storage:GetValueAtPath(colorPath), defaultColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            DB.storage:SetValue(colorPath, Utils:SanitizeColor({ r = r, g = g, b = b }, defaultColor))
            onChanged(colorKey)
        end,
        getDefaultColor = function()
            local color = Utils:SanitizeColor(defaultColor, { r = 1, g = 1, b = 1 })
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        parent = enabledElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(enabledPath) == true
        end,
    })

    return enabledElement
end

function AuraSettings:CreateBuffsSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)

    if not (rootCategory and path and keyPrefix) then
        return
    end

    local buffsCategory = SettingsLib:CreateCategory(rootCategory, "Buffs")

    local function OnChanged(settingKey)
        if settingKey == "show" or settingKey == "showUnderSeconds" then
            FF:ShowBuffCountdownIfNeeded()
        elseif settingKey == "fontSize" then
            FF:UpdateAuraCountdownFontSize()
        else
            FF:UpdateAuraCountdownDynamicColor()
        end
    end

    local showElement = CreateAuraSettings(buffsCategory, {
        basePath = path,
        prefix = prefix,
        keyPrefix = keyPrefix,
        onChanged = OnChanged,
    })

    local cooldownTextPath = path .. ".cooldownText"
    local cooldownDefaults = DB.storage:GetDefaultsTableAtPath(cooldownTextPath) or {}
    local defaultShowUnderSeconds = Utils:ClampInteger(cooldownDefaults.showUnderSeconds, 0, 60, 0)

    SettingsCommon:CreateSlider(buffsCategory, {
        path = cooldownTextPath .. ".showUnderSeconds",
        name = "Seconds",
        min = 0,
        max = 60,
        step = 1,
        formatter = function(value)
            local v = Utils:ClampInteger(value, 0, 60, defaultShowUnderSeconds)
            if v == 0 then
                return "Always"
            end
            return string.format("%is", v)
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 0, 60, fallback)
        end,
        onChanged = function()
            OnChanged("showUnderSeconds")
        end,
        desc = "When set, countdown text is only shown if remaining duration is at or below this value.",
        prefix = prefix,
        parent = showElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath(cooldownTextPath .. ".show") == true
        end,
    })

    local thresholdsPath = path .. ".thresholds"

    local defaults = DB.storage:GetDefaultsTableAtPath(path) or {}
    local thresholdsDefaults = type(defaults.thresholds) == "table" and defaults.thresholds or {}

    local warningDefaults = type(thresholdsDefaults.warning) == "table" and thresholdsDefaults.warning or {}
    local criticalDefaults = type(thresholdsDefaults.critical) == "table" and thresholdsDefaults.critical or {}

    local defaultWarningThresholdSeconds = Utils:ClampInteger(warningDefaults.thresholdSeconds, 0, 60, 10)
    local defaultCriticalThresholdSeconds = Utils:ClampInteger(criticalDefaults.thresholdSeconds, 0, 60, 5)

    local defaultWarningColor = Utils:SanitizeColor(warningDefaults.color, { r = 1, g = 0.55, b = 0 })
    local defaultCriticalColor = Utils:SanitizeColor(criticalDefaults.color, { r = 1, g = 0, b = 0 })

    SettingsLib:CreateHeader(buffsCategory, {
        name = "Thresholds",
    })

    CreateThresholdSettings(buffsCategory, {
        path = thresholdsPath .. ".warning",
        name = "Warning",
        desc = "Enable Warning threshold coloring for this countdown.",
        sliderDesc = "When remaining duration is at or below this value, countdown text uses the Warning color.",
        defaultThresholdSeconds = defaultWarningThresholdSeconds,
        defaultColor = defaultWarningColor,
        enabledKey = "warningEnabled",
        secondsKey = "warningThresholdSeconds",
        colorKey = "warningColor",
        onChanged = OnChanged,
        prefix = prefix,
    })

    CreateThresholdSettings(buffsCategory, {
        path = thresholdsPath .. ".critical",
        name = "Critical",
        desc = "Enable Critical threshold coloring for this countdown.",
        sliderDesc = "When remaining duration is at or below this value, countdown text uses the Critical color.",
        defaultThresholdSeconds = defaultCriticalThresholdSeconds,
        defaultColor = defaultCriticalColor,
        enabledKey = "criticalEnabled",
        secondsKey = "criticalThresholdSeconds",
        colorKey = "criticalColor",
        onChanged = OnChanged,
        prefix = prefix,
    })
end

function AuraSettings:CreateDebuffsSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)

    if not (rootCategory and path and keyPrefix) then
        return
    end

    local debuffsCategory = SettingsLib:CreateCategory(rootCategory, "Debuffs")

    CreateAuraSettings(debuffsCategory, {
        basePath = path,
        prefix = prefix,
        keyPrefix = keyPrefix,
        onChanged = function(settingKey)
            if settingKey == "show" then
                FF:ShowDebuffCountdownIfNeeded()
            elseif settingKey == "fontSize" then
                FF:UpdateAuraCountdownFontSize()
            else
                FF:UpdateAuraCountdownDynamicColor()
            end
        end,
    })
end
