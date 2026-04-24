local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local SettingsCommon = addon.SettingsCommon
local Constants = addon.Constants

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

local FrameSettings = {}
addon.FrameSettings = FrameSettings

assert(SettingsCommon, "FoxFrames: SettingsCommon module missing (load order issue)")
assert(type(SettingsCommon.AddFrameSettings) == "function", "FoxFrames: SettingsCommon missing AddFrameSettings")
assert(type(SettingsCommon.AddTextSettings) == "function", "FoxFrames: SettingsCommon missing AddTextSettings")
assert(type(SettingsCommon.CreateCheckbox) == "function", "FoxFrames: SettingsCommon missing CreateCheckbox")
assert(type(SettingsCommon.CreateDropdown) == "function", "FoxFrames: SettingsCommon missing CreateDropdown")
assert(type(SettingsCommon.CreateSlider) == "function", "FoxFrames: SettingsCommon missing CreateSlider")

local GROWTH_DIRECTION_LABELS = SettingsCommon.GROWTH_DIRECTION_LABELS
assert(type(GROWTH_DIRECTION_LABELS) == "table", "FoxFrames: SettingsCommon missing GROWTH_DIRECTION_LABELS")

local function AddCooldownTextSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddCooldownTextSettings requires onChanged callback")

    if not (category and path) then
        return nil
    end

    if DB.storage and type(path) == "string" and path ~= "" then
        DB.storage:ValidatePathExists(path)
    end

    local defaults = DB.storage:GetDefaultsTableAtPath(path) or {}
    local defaultFontSize = Utils:ClampInteger(defaults.fontSize, 8, 32, 12)
    local defaultColor = Utils:SanitizeColor(defaults.color, { r = 1, g = 1, b = 1 })

    local showElement = SettingsCommon:CreateCheckbox(category, {
        path = path .. ".show",
        name = "Show Text",
        desc = "Toggle cooldown countdown text visibility.",
        prefix = prefix,
        onChanged = function()
            onChanged("show")
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
            onChanged("fontSize")
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
            local color = Utils:SanitizeColor(DB.storage:GetValueAtPath(path .. ".color"), defaultColor)
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            DB.storage:SetValue(path .. ".color", Utils:SanitizeColor({ r = r, g = g, b = b }, defaultColor))
            onChanged("color")
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

local function ValidateSettingsPath(path)
    if DB.storage and type(path) == "string" and path ~= "" then
        DB.storage:ValidatePathExists(path)
    end
end

-- Incoming Casts / Targetted Spells settings were removed.

local function CreatePartyPlayerTextElementSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: CreatePlayerTextElementSettings requires onChanged callback")

    if not (category and path and prefix) then
        return
    end

    ValidateSettingsPath(path)

    SettingsLib:CreateHeader(category, {
        name = "Text",
    })

    SettingsCommon:CreateCheckbox(category, {
        path = path .. ".customizeText",
        name = "Customize",
        prefix = prefix,
        onChanged = function()
            onChanged("customizeText")
        end,
        desc = "Toggle text customization for this element.",
    })

    SettingsCommon:AddTextSettings(category, {
        path = path .. ".text",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })

    SettingsLib:CreateHeader(category, {
        name = "Placement",
    })

    SettingsCommon:CreateCheckbox(category, {
        path = path .. ".customizeFrame",
        name = "Customize",
        prefix = prefix,
        onChanged = function()
            onChanged("customizeFrame")
        end,
        desc = "Toggle frame customization for this element.",
    })

    SettingsCommon:AddFrameSettings(category, {
        path = path .. ".frame",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })
end

local function CreateRaidPlayerTextElementSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)

    assert(type(onChanged) == "function", "FoxFrames: CreatePlayerTextElementSettings requires onChanged callback")

    if not (category and path and keyPrefix and prefix) then
        return
    end

    ValidateSettingsPath(path)

    SettingsLib:CreateHeader(category, {
        name = "Text",
    })

    local customizeTextPath = path .. ".customizeTextType"

    SettingsCommon:CreateDropdown(category, {
        path = customizeTextPath,
        name = "Customize",
        values = {
            PARTY = "Use Party Settings",
            ENABLED = "Enabled",
            DISABLED = "Disabled",
        },
        sanitize = function(value, fallback)
            return Utils:SanitizeOption(value, DB.RAID_FRAME_OVERRIDE_TYPES) or fallback
        end,
        onChanged = function(_)
            onChanged("customizeTextType")
        end,
        prefix = prefix,
        desc = "Enable customizations for this text, disable them, or reuse Party settings.",
    })

    SettingsCommon:AddTextSettings(category, {
        path = path .. ".text",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })

    SettingsLib:CreateHeader(category, {
        name = "Placement",
    })

    SettingsCommon:CreateDropdown(category, {
        path = path .. ".customizeFrameType",
        name = "Customize",
        values = {
            PARTY = "Use Party Settings",
            ENABLED = "Enabled",
            DISABLED = "Disabled",
        },
        sanitize = function(value, fallback)
            return Utils:SanitizeOption(value, DB.RAID_FRAME_OVERRIDE_TYPES) or fallback
        end,
        onChanged = function(_)
            onChanged("customizeFrameType")
        end,
        prefix = prefix,
        desc = "Enable customizations for this frame, disable them, or reuse Party settings.",
    })

    SettingsCommon:AddFrameSettings(category, {
        path = path .. ".frame",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })
end

function FrameSettings:CreatePartySettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    if not (rootCategory and prefix) then
        return
    end

    local category = SettingsLib:CreateCategory(rootCategory, "Party")

    SettingsLib:CreateHeader(category, {
        name = "Frame Settings",
    })

    SettingsLib:CreateText(
        category,
        "You need to enable 'Raid Style Party Frames' in 'Edit Mode' to benefit from these settings."
    )

    SettingsCommon:CreateCheckbox(category, {
        path = "profile.partyFrame.showInSolo",
        name = "Show In Solo",
        onChanged = function(_)
            FF:ShowPartyFrameIfNeeded()
        end,
        desc = "Toggle the frame visibility when solo.",
        prefix = prefix,
    })

    SettingsCommon:CreateCheckbox(category, {
        path = "profile.partyFrame.showTitle",
        name = "Show Title",
        onChanged = function(_)
            FF:ShowPartyFrameTitleIfNeeded()
        end,
        desc = "Toggle the title visibility on the frame.",
        prefix = prefix,
    })

    SettingsCommon:CreateCheckbox(category, {
        path = "profile.partyFrame.allowAnyAnchoring",
        name = "Allow Any Anchoring",
        onChanged = function(_)
            FF:SetAllowAnyAnchoring()
        end,
        desc = "By default, Blizzard's party frames will convert anchoring to top-left. This results in always top-left alignment of frames. Enabling this will allow you to use other anchor points such as center, bottom or right. You will need to re-anchor the party frames after changing this setting.",
        prefix = prefix,
    })

    SettingsLib:CreateText(
        category,
        "You will need to re-center the party frames on the UI to set the new anchor point."
    )

    local basePath = "profile.partyFrame"

    local playerNameCategory = SettingsLib:CreateCategory(rootCategory, "Party: Player Name")
    CreatePartyPlayerTextElementSettings(playerNameCategory, {
        prefix = prefix .. "PlayerName_",
        path = basePath .. ".playerName",
        onChanged = function(_)
            FF:ApplyPlayerNameSettings()
        end,
    })

    local playerStatusCategory = SettingsLib:CreateCategory(rootCategory, "Party: Player Status")
    CreatePartyPlayerTextElementSettings(playerStatusCategory, {
        prefix = prefix .. "PlayerStatus_",
        path = basePath .. ".playerStatus",
        onChanged = function(_)
            FF:ApplyPlayerStatusSettings()
        end,
    })
end

function FrameSettings:CreateRaidSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    if not (rootCategory and prefix) then
        return
    end

    local basePath = "profile.raidFrame"

    local raidPlayerNameCategory = SettingsLib:CreateCategory(rootCategory, "Raid: Player Name")
    CreateRaidPlayerTextElementSettings(raidPlayerNameCategory, {
        prefix = prefix .. "PlayerName_",
        path = basePath .. ".playerName",
        keyPrefix = "RaidPlayerName",
        onChanged = function(_)
            FF:ApplyPlayerNameSettings()
        end,
    })

    local raidPlayerStatusCategory = SettingsLib:CreateCategory(rootCategory, "Raid: Player Status")
    CreateRaidPlayerTextElementSettings(raidPlayerStatusCategory, {
        prefix = prefix .. "PlayerStatus_",
        path = basePath .. ".playerStatus",
        keyPrefix = "RaidPlayerStatus",
        onChanged = function(_)
            FF:ApplyPlayerStatusSettings()
        end,
    })
end
