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

local function AddIncomingCastsIconSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
        or (type(opts.iconPath) == "string" and opts.iconPath ~= "" and opts.iconPath)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil
    -- NOTE: Intentionally no parent/parentCheck gating here.
    -- LibEQOL/Settings gating requires a proper parent initializer and can be fragile.

    assert(type(onChanged) == "function", "FoxFrames: AddIncomingCastsIconSettings requires onChanged callback")

    if not (category and path) then
        return
    end

    ValidateSettingsPath(path)

    local iconDefaults = DB.storage:GetDefaultsTableAtPath(path) or {}
    local defaultScale = Utils:ClampNumber(iconDefaults.scale, 0.5, 2, 1)
    local defaultSpacing = Utils:ClampInteger(iconDefaults.spacing, -10, 20, 0)

    SettingsCommon:CreateSlider(category, {
        path = path .. ".scale",
        name = "Icon Scale",
        min = 0.5,
        max = 2,
        step = 0.10,
        formatter = function(value)
            return string.format(
                "%d%%",
                Utils:ClampInteger((value and (value * 100) or nil), 50, 200, defaultScale * 100)
            )
        end,
        sanitize = function(value, fallback)
            return Utils:ClampNumber(value, 0.5, 2, fallback)
        end,
        onChanged = function()
            onChanged("scale")
        end,
        desc = "Scales each targeted spell icon without distorting borders/overlays.",
        prefix = prefix,
    })

    SettingsCommon:CreateSlider(category, {
        path = path .. ".spacing",
        name = "Icon Spacing",
        min = -10,
        max = 20,
        step = 1,
        formatter = function(value)
            return string.format("%i", Utils:ClampInteger(value, -10, 20, defaultSpacing))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, -10, 20, fallback)
        end,
        onChanged = function()
            onChanged("spacing")
        end,
        desc = "Space (in pixels) between targeted spell icons. Negative values allow overlap.",
        prefix = prefix,
    })

    SettingsCommon:CreateCheckbox(category, {
        path = path .. ".showBorder",
        name = "Show Icon Border",
        onChanged = function(_)
            onChanged("showBorder")
        end,
        desc = "Toggle the border around targeted spell icons.",
        prefix = prefix,
    })
end

local function AddIncomingCastsCooldownSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local iconPath = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: AddIncomingCastsCooldownSettings requires onChanged callback")

    if not (category and iconPath) then
        return
    end

    ValidateSettingsPath(iconPath)

    SettingsLib:CreateHeader(category, {
        name = "Cooldown",
    })

    SettingsCommon:CreateCheckbox(category, {
        path = iconPath .. ".showSwipe",
        name = "Show Cooldown Swipe",
        onChanged = function(_)
            onChanged("showSwipe")
        end,
        desc = "Toggle the cooldown swipe overlay on targeted spell icons.",
        prefix = prefix,
    })

    AddCooldownTextSettings(category, {
        path = iconPath .. ".cooldownText",
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

    SettingsCommon:AddFrameSettings(category, {
        path = framePath,
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
    })
end

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

local function CreateGlobalIncomingCastsSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local basePath = (type(opts.basePath) == "string" and opts.basePath ~= "" and opts.basePath)
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil
    local onChanged = type(opts.onChanged) == "function" and opts.onChanged or nil

    assert(type(onChanged) == "function", "FoxFrames: CreateGlobalIncomingCastsSettings requires onChanged callback")

    if not (category and basePath) then
        return
    end

    ValidateSettingsPath(basePath)

    SettingsLib:CreateHeader(category, {
        name = "Icons",
    })

    local barDefaults = DB.storage:GetDefaultsTableAtPath(basePath) or {}
    local defaultSpellCount = Utils:ClampInteger(barDefaults.spellCount, 1, 6, 3)

    SettingsCommon:CreateDropdown(category, {
        path = basePath .. ".growthDirection",
        name = "Grow Direction",
        values = GROWTH_DIRECTION_LABELS,
        sanitize = function(value, fallback)
            return Utils:SanitizeOption(value, Constants.GROWTH_DIRECTIONS) or fallback
        end,
        onChanged = function(_)
            onChanged("growthDirection")
        end,
        desc = "Direction targeted spell icons grow when multiple are shown.",
        prefix = prefix,
    })

    SettingsCommon:CreateSlider(category, {
        path = basePath .. ".spellCount",
        name = "Icon Count",
        min = 1,
        max = 6,
        step = 1,
        formatter = function(value)
            return string.format("%i", Utils:ClampInteger(value, 1, 6, defaultSpellCount))
        end,
        sanitize = function(value, fallback)
            return Utils:ClampInteger(value, 1, 6, fallback)
        end,
        onChanged = function()
            onChanged("spellCount")
        end,
        desc = "How many targeted spell icons to show per party member.",
        prefix = prefix,
    })

    AddIncomingCastsIconSettings(category, {
        path = basePath .. ".icon",
        prefix = prefix,
        onChanged = function(_)
            onChanged("icons")
        end,
    })

    AddIncomingCastsCooldownSettings(category, {
        path = basePath .. ".icon",
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
    local incomingCastsCategory = SettingsLib:CreateCategory(rootCategory, "Party: Incoming Casts")
    FF._incomingCastsCategory = incomingCastsCategory

    local function OnChanged(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end

    SettingsLib:CreateText(
        incomingCastsCategory,
        "Incoming casts are spells that are targetting you or your teamates.\nThis is not a perfect solution as it's difficult to work around Blizzard's secrets.\nSo it won't show everything."
    )

    SettingsCommon:CreateCheckbox(incomingCastsCategory, {
        path = trackIncomingCastsPath,
        name = "Track Incoming Casts",
        onChanged = function(enabled)
            if enabled ~= true then
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
    local incomingCastsCategory = SettingsLib:CreateCategory(rootCategory, "Raid: Incoming Casts")

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

    SettingsCommon:CreateDropdown(incomingCastsCategory, {
        path = enabledTypePath,
        name = "Incoming Casts",
        values = {
            PARTY = "Use Party Settings",
            ENABLED = "Enabled",
            DISABLED = "Disabled",
        },
        sanitize = function(value, fallback)
            return Utils:SanitizeOption(value, DB.RAID_FRAME_OVERRIDE_TYPES) or fallback
        end,
        onChanged = function(_)
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

    CreatePartyIncomingCastsSettings(rootCategory)
end

function FrameSettings:CreateRaidSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    if not (rootCategory and prefix) then
        return
    end

    CreateRaidIncomingCastsSettings(rootCategory, {
        prefix = prefix,
    })

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
