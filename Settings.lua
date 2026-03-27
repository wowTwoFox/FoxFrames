local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local GlobalsDB = addon.GlobalsDB
local ProfilesSettings = addon.SettingsProfiles
local SettingsCommon = addon.SettingsCommon
local Constants = addon.Constants

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

assert(ProfilesSettings and ProfilesSettings.CreateProfilesSettings, "FoxFrames: SettingsProfiles module missing (load order issue)")

assert(SettingsCommon, "FoxFrames: SettingsCommon module missing (load order issue)")
assert(type(SettingsCommon.GetTextures) == "function", "FoxFrames: SettingsCommon missing GetTextures")
assert(type(SettingsCommon.AddFrameSettings) == "function", "FoxFrames: SettingsCommon missing AddFrameSettings")
assert(type(SettingsCommon.AddTextSettings) == "function", "FoxFrames: SettingsCommon missing AddTextSettings")
assert(type(SettingsCommon.AddCooldownTextSettings) == "function", "FoxFrames: SettingsCommon missing AddCooldownTextSettings")
assert(type(SettingsCommon.CreateBooleanSettings) == "function", "FoxFrames: SettingsCommon missing CreateBooleanSettings")
assert(type(SettingsCommon.CreateAuraSettings) == "function", "FoxFrames: SettingsCommon missing CreateAuraSettings")
assert(type(SettingsCommon.GROWTH_DIRECTION_LABELS) == "table", "FoxFrames: SettingsCommon missing GROWTH_DIRECTION_LABELS")

local PLAYER_FRAME_SHOW_TYPE_LABELS = {
    [DB.PLAYER_FRAME_SHOW_TYPES.ALWAYS] = "Always",
    [DB.PLAYER_FRAME_SHOW_TYPES.SOLO] = "Solo",
    [DB.PLAYER_FRAME_SHOW_TYPES.NEVER] = "Never",
}
local GROWTH_DIRECTION_LABELS = SettingsCommon.GROWTH_DIRECTION_LABELS

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

    SettingsCommon:AddCooldownTextSettings(category, {
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

    SettingsCommon:AddFrameSettings(category, {
        path = framePath,
        keyPrefix = keyPrefix .. "Frame",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
        end,
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

    SettingsCommon:CreateBooleanSettings(category, {
        key = keyPrefix .. "TextCustomize",
        path = textCustomizePath,
        name = toggleName,
        prefix = prefix,
        onChanged = function()
            onChanged("customizeText")
        end,
        desc = textCustomizeDesc,
    })

    SettingsCommon:AddTextSettings(category, {
        path = path .. ".text",
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

    SettingsCommon:CreateBooleanSettings(category, {
        key = keyPrefix .. "FrameCustomize",
        path = frameCustomizePath,
        name = toggleName,
        prefix = prefix,
        onChanged = function()
            onChanged("customizeFrame")
        end,
        desc = frameCustomizeDesc,
    })

    SettingsCommon:AddFrameSettings(category, {
        path = framePath,
        keyPrefix = keyPrefix .. "Frame",
        prefix = prefix,
        onChanged = function(settingKey)
            onChanged(settingKey)
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

    local buffsCategory = SettingsLib:CreateCategory(rootCategory, "Buffs")

    SettingsCommon:CreateAuraSettings(buffsCategory, {
        basePath = path,
        prefix = prefix,
        keyPrefix = keyPrefix,
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

    local debuffsCategory = SettingsLib:CreateCategory(rootCategory, "Debuffs")

    SettingsCommon:CreateAuraSettings(debuffsCategory, {
        basePath = path,
        prefix = prefix,
        keyPrefix = keyPrefix,
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

    local trackIncomingCastsDefaults = DB.storage:GetDefaultsTableAtPath(trackIncomingCastsPath)
    local defaultTrackIncomingCasts = trackIncomingCastsDefaults == true

    local function IsTrackingEnabled()
        local value = DB.storage:GetValue(trackIncomingCastsPath)
        if value == nil then
            return defaultTrackIncomingCasts
        end
        return value == true
    end

    SettingsLib:CreateCheckbox(incomingCastsCategory, {
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

    SettingsLib:CreateDropdown(incomingCastsCategory, {
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

local function CreatePartySettings(rootCategory, options)
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

    SettingsLib:CreateCheckbox(category, {
        key = "ShowInSolo",
        name = "Show In Solo",
        default = DB.DEFAULT_SETTINGS.partyFrame.showInSolo,
        get = function() return DB:GetPartyFrameDB().showInSolo end,
        set = function(value)
            DB:GetPartyFrameDB().showInSolo = value
            FF:ShowPartyFrameIfNeeded()
        end,
        desc = "Toggle the frame visibility when solo.",
        prefix = prefix,
    })

    SettingsLib:CreateCheckbox(category, {
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
        prefix = prefix,
    })

    SettingsLib:CreateCheckbox(category, {
        key = "AllowAnyAnchoring",
        name = "Allow Any Anchoring",
        default = DB.DEFAULT_SETTINGS.partyFrame.allowAnyAnchoring,
        get = function() return DB:GetPartyFrameDB().allowAnyAnchoring end,
        set = function(value)
            DB:GetPartyFrameDB().allowAnyAnchoring = value
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

    local playerNameCategory = SettingsLib:CreateCategory(category, "Party: Player Name")
    CreatePlayerTextElementSettings(playerNameCategory, {
        prefix = prefix .. "PlayerName_",
        path = basePath .. ".playerName",
        keyPrefix = "PlayerName",
        toggleName = "Customize",
        textCustomizeDesc = "Toggle FoxFrames text customization for Player Name.",
        frameCustomizeDesc = "Toggle FoxFrames placement customization for Player Name.",
        onChanged = function(_)
            FF:ApplyPlayerNameSettings()
        end,
    })

    local playerStatusCategory = SettingsLib:CreateCategory(category, "Party: Player Status")
    CreatePlayerTextElementSettings(playerStatusCategory, {
        prefix = prefix .. "PlayerStatus_",
        path = basePath .. ".playerStatus",
        keyPrefix = "PlayerStatus",
        toggleName = "Customize",
        textCustomizeDesc = "Toggle FoxFrames text customization for Player Status.",
        frameCustomizeDesc = "Toggle FoxFrames placement customization for Player Status.",
        onChanged = function(_)
            FF:ApplyPlayerStatusSettings()
        end,
    })

    CreatePartyIncomingCastsSettings(category)
end

local function CreateRaidSettings(category, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    if not (category and prefix) then
        return
    end

    local raidCategory = SettingsLib:CreateCategory(category, "Raid")
    CreateRaidIncomingCastsSettings(raidCategory, {
        prefix = prefix,
    })

    local basePath = "profile.raidFrame"

    local raidPlayerNameCategory = SettingsLib:CreateCategory(raidCategory, "Raid: Player Name")
    CreatePlayerTextElementSettings(raidPlayerNameCategory, {
        prefix = prefix .. "PlayerName_",
        path = basePath .. ".playerName",
        keyPrefix = "RaidPlayerName",
        toggleName = "Override",
        textCustomizeDesc = "Override text settings for Raid Player Name when in a raid. When disabled, uses Party settings.",
        frameCustomizeDesc = "Override placement settings for Raid Player Name when in a raid. When disabled, uses Party settings.",
        onChanged = function(_)
            FF:ApplyPlayerNameSettings()
        end,
    })

    local raidPlayerStatusCategory = SettingsLib:CreateCategory(raidCategory, "Raid: Player Status")
    CreatePlayerTextElementSettings(raidPlayerStatusCategory, {
        prefix = prefix .. "PlayerStatus_",
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

local function CreateFramesSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    if not (rootCategory and prefix) then
        return
    end

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
            FF:ShowPlayerFrameIfNeeded()
        end,
        desc = "Control the visibility of the player frame. 'Always' will show the player frame regardless of group status. 'Solo' will only show the player frame when not in a party or raid. 'Never' will hide the player frame regardless of group status.",
        prefix = prefix,
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
        desc = "Toggle class colors on Blizzard raid frames.",
        prefix = prefix,
    })

    -- Build texture list from LibSharedMedia or fallback to built-in
    local textureOrder = {}
    local textures = SettingsCommon:GetTextures()

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
        prefix = prefix,
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
        prefix = prefix,
        parent = useCustomHealthBarTextureElement,
        parentCheck = function()
            return DB:GetPartyFrameDB().useCustomHealthBarTexture == true
        end,
    })
end

local function CreateRoleIconsSettings(rootCategory, options)
    local opts = type(options) == "table" and options or {}
    local prefix = (type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix) or nil

    if not (rootCategory and prefix) then
        return
    end

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
        prefix = prefix,
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
        prefix = prefix,
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
        prefix = prefix,
    })
end

function FF:SetupOptions()
    -- Build the options using LibEQOL
    local PARTY_FRAME_PREFIX = SETTINGS_PREFIX .. "PartyFrame_"
    local RAID_FRAME_PREFIX = SETTINGS_PREFIX .. "RaidFrame_"
    local rootCategory = SettingsLib:CreateRootCategory("Fox Frames")
    self._rootCategory = rootCategory

    CreateFramesSettings(rootCategory, {
        prefix = PARTY_FRAME_PREFIX,
    })

    CreateRoleIconsSettings(rootCategory, {
        prefix = PARTY_FRAME_PREFIX,
    })

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

    ProfilesSettings:CreateProfilesSettings(rootCategory, {
        onProfileActivated = function()
            self:SetupFrames()
        end,
    })

    CreatePartySettings(rootCategory, {
        prefix = PARTY_FRAME_PREFIX,
    })

    CreateRaidSettings(rootCategory, {
        prefix = RAID_FRAME_PREFIX,
    })
end
