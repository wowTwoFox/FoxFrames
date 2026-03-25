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

local function AddFrameSettings(path, category, keyPrefix, prefix, parent, parentCheck, applySetting)
    assert(type(applySetting) == "function", "FoxFrames: AddFrameSettings requires applySetting callback")
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
        applySetting(settingKey)
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
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
    })
end

local function AddTextSettings(path, category, keyPrefix, prefix, applySetting, parent, parentCheck)
    assert(type(applySetting) == "function", "FoxFrames: AddTextSettings requires applySetting callback")
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
        desc = "Adjust the text size on frames.",
        prefix = prefix,
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
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
        parent = parent,
        parentCheck = parentCheck,
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
            if type(parentCheck) == "function" and parentCheck() ~= true then
                return false
            end
            return GetValue("useClassColors") ~= true
        end,
        minHeight = 36,
    })
end

local function AddCooldownTextSettings(path, category, keyPrefix, prefix, applySetting)
    assert(type(applySetting) == "function", "FoxFrames: AddCooldownTextSettings requires applySetting callback")
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

local function CreateBooleanSettings(category, prefix, options)
    local opts = type(options) == "table" and options or {}
    local key = (type(opts.key) == "string" and opts.key ~= "" and opts.key)
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local name = (type(opts.name) == "string" and opts.name ~= "" and opts.name)
    local desc = (type(opts.desc) == "string" and opts.desc ~= "" and opts.desc)
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

local function CreatePlayerTextElementSettings(category, framePrefix, options, applySetting)
    local opts = type(options) == "table" and options or {}
    local path = (type(opts.path) == "string" and opts.path ~= "" and opts.path)
    local framePath = path and (path .. ".frame") or nil
    local textCustomizePath = path and (path .. ".customizeText") or nil
    local frameCustomizePath = path and (path .. ".customizeFrame") or nil
    local keyPrefix = (type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" and opts.keyPrefix)
    local toggleName = (type(opts.toggleName) == "string" and opts.toggleName ~= "" and opts.toggleName) or "Customize"
    local textCustomizeDesc = (type(opts.textCustomizeDesc) == "string" and opts.textCustomizeDesc ~= "" and opts.textCustomizeDesc)
    local frameCustomizeDesc = (type(opts.frameCustomizeDesc) == "string" and opts.frameCustomizeDesc ~= "" and opts.frameCustomizeDesc)

    if not (category and path and keyPrefix) then
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
    local function IsTextCustomized()
        local value = DB.storage:GetValue(textCustomizePath)
        if value == nil then
            return defaultCustomize
        end
        return value == true
    end

    local textCustomizeElement = CreateBooleanSettings(category, framePrefix, {
        key = keyPrefix .. "TextCustomize",
        path = textCustomizePath,
        name = toggleName,
        default = defaultCustomize,
        onChanged = function()
            applySetting("customizeText")
        end,
        desc = textCustomizeDesc,
    })

    AddTextSettings(path, category, keyPrefix, framePrefix, function(settingKey)
        applySetting(settingKey)
    end, textCustomizeElement, IsTextCustomized)

    if not ValidateSettingsPath(framePath) then
        return
    end

    SettingsLib:CreateHeader(category, {
        name = "Placement",
    })

    local function IsFrameCustomized()
        local value = DB.storage:GetValue(frameCustomizePath)
        if value == nil then
            return defaultCustomize
        end
        return value == true
    end

    local frameCustomizeElement = CreateBooleanSettings(category, framePrefix, {
        key = keyPrefix .. "FrameCustomize",
        path = frameCustomizePath,
        name = toggleName,
        default = defaultCustomize,
        onChanged = function()
            applySetting("customizeFrame")
        end,
        desc = frameCustomizeDesc,
    })

    AddFrameSettings(framePath, category, keyPrefix .. "Frame", framePrefix, frameCustomizeElement, IsFrameCustomized, function(settingKey)
        applySetting(settingKey)
    end)
end

local function CreatePartyPlayerSettings(rootCategory, framePrefix, basePath)
    if type(basePath) ~= "string" or basePath == "" then
        return
    end

    local playerNameCategory = SettingsLib:CreateCategory(rootCategory, "Player Name")
    CreatePlayerTextElementSettings(playerNameCategory, framePrefix .. "PlayerName_", {
        path = basePath .. ".playerName",
        keyPrefix = "PlayerName",
        toggleName = "Customize",
        textCustomizeDesc = "Toggle FoxFrames text customization for Player Name.",
        frameCustomizeDesc = "Toggle FoxFrames placement customization for Player Name.",
    }, function(settingKey)
        FF:ApplyPlayerNameSettings()
    end)

    local playerStatusCategory = SettingsLib:CreateCategory(rootCategory, "Player Status")
    CreatePlayerTextElementSettings(playerStatusCategory, framePrefix .. "PlayerStatus_", {
        path = basePath .. ".playerStatus",
        keyPrefix = "PlayerStatus",
        toggleName = "Customize",
        textCustomizeDesc = "Toggle FoxFrames text customization for Player Status.",
        frameCustomizeDesc = "Toggle FoxFrames placement customization for Player Status.",
    }, function(settingKey)
        FF:ApplyPlayerStatusSettings()
    end)
end

local function CreateRaidPlayerSettings(rootCategory, framePrefix, basePath)
    if type(basePath) ~= "string" or basePath == "" then
        return
    end

    local raidPlayerNameCategory = SettingsLib:CreateCategory(rootCategory, "Raid Player Name")
    CreatePlayerTextElementSettings(raidPlayerNameCategory, framePrefix .. "PlayerName_", {
        path = basePath .. ".playerName",
        keyPrefix = "RaidPlayerName",
        toggleName = "Override",
        textCustomizeDesc = "Override text settings for Raid Player Name when in a raid. When disabled, uses Party settings.",
        frameCustomizeDesc = "Override placement settings for Raid Player Name when in a raid. When disabled, uses Party settings.",
    }, function(settingKey)
        FF:ApplyPlayerNameSettings()
    end)

    local raidPlayerStatusCategory = SettingsLib:CreateCategory(rootCategory, "Raid Player Status")
    CreatePlayerTextElementSettings(raidPlayerStatusCategory, framePrefix .. "PlayerStatus_", {
        path = basePath .. ".playerStatus",
        keyPrefix = "RaidPlayerStatus",
        toggleName = "Override",
        textCustomizeDesc = "Override text settings for Raid Player Status when in a raid. When disabled, uses Party settings.",
        frameCustomizeDesc = "Override placement settings for Raid Player Status when in a raid. When disabled, uses Party settings.",
    }, function(settingKey)
        FF:ApplyPlayerStatusSettings()
    end)
end

local function CreateBuffsSettings(rootCategory, partyFramePrefix)
    local buffsCategory = SettingsLib:CreateCategory(rootCategory, "Buffs")

    SettingsLib:CreateHeader(buffsCategory, {
        name = "Cooldown",
    })

    AddCooldownTextSettings("profile.partyFrame.buffs.cooldownText", buffsCategory, "Buff", partyFramePrefix, function(settingKey)
        if settingKey == "show" then
            FF:ShowBuffCountdownIfNeeded()
        elseif settingKey == "fontSize" then
            FF:UpdateAuraCountdownFontSize()
        else
            FF:UpdateAuraCountdownColor()
        end
    end)
end

local function CreateDebuffsSettings(rootCategory, partyFramePrefix)
    local debuffsCategory = SettingsLib:CreateCategory(rootCategory, "Debuffs")

    SettingsLib:CreateHeader(debuffsCategory, {
        name = "Cooldown",
    })

    AddCooldownTextSettings("profile.partyFrame.debuffs.cooldownText", debuffsCategory, "Debuff", partyFramePrefix, function(settingKey)
        if settingKey == "show" then
            FF:ShowDebuffCountdownIfNeeded()
        elseif settingKey == "fontSize" then
            FF:UpdateAuraCountdownFontSize()
        else
            FF:UpdateAuraCountdownColor()
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
            return DB:GetPartyFrameDB().trackIncomingCasts
        end,
        set = function(value)
            DB:GetPartyFrameDB().trackIncomingCasts = value
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
            return DB:GetPartyFrameDB().trackIncomingCasts == true
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
            DB:SetIncomingCastBarValue("growthDirection", value)
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
            local value = DB:GetIncomingCastBarValue("spellCount")
            if value == nil then
                value = incomingCastBarDefaults.spellCount
            end
            return value
        end,
        set = function(value)
            DB:SetIncomingCastBarValue("spellCount", Utils:ClampInteger(value, 1, 6, incomingCastBarDefaults.spellCount))
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
            local value = DB:GetIncomingCastBarIconValue("scale")
            if value ~= nil then
                return value
            end

            return incomingCastBarIconDefaults.scale
        end,
        set = function(value)
            DB:SetIncomingCastBarIconValue("scale", value)
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
            local value = DB:GetIncomingCastBarIconValue("spacing")
            if value == nil then
                value = incomingCastBarIconDefaults.spacing
            end
            return value
        end,
        set = function(value)
            DB:SetIncomingCastBarIconValue("spacing", Utils:ClampInteger(value, -10, 20, incomingCastBarIconDefaults.spacing))
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
            local value = DB:GetIncomingCastBarIconValue("showBorder")
            if value == nil then
                value = incomingCastBarIconDefaults.showBorder
            end
            return value
        end,
        set = function(value)
            DB:SetIncomingCastBarIconValue("showBorder", value)
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
            local value = DB:GetIncomingCastBarIconValue("showSwipe")
            if value == nil then
                value = incomingCastBarIconDefaults.showSwipe
            end
            return value
        end,
        set = function(value)
            DB:SetIncomingCastBarIconValue("showSwipe", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the cooldown swipe overlay on targeted spell icons.",
        prefix = incomingCastsPrefix,
    })

    AddCooldownTextSettings("profile.incomingCastBar.icon.cooldownText", incomingCastsCategory, "IncomingCastIcon", incomingCastsPrefix, function(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end)

    SettingsLib:CreateHeader(incomingCastsCategory, {
        name = "Placement",
    })

    AddFrameSettings("profile.incomingCastBar.frame", incomingCastsCategory, "IncomingCastFrame", incomingCastsPrefix, nil, nil, function(_)
        FF:SetupIncomingCastIndicators()
        FF:UpdateIncomingCastIndicators()
    end)
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
    CreateRaidPlayerSettings(rootCategory, RAID_FRAME_PREFIX, "profile.raidFrame")

    CreateBuffsSettings(rootCategory, PARTY_FRAME_PREFIX)
    CreateDebuffsSettings(rootCategory, PARTY_FRAME_PREFIX)
    CreateIncomingCastsSettings(rootCategory)
end
