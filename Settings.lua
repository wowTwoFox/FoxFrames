local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

local ANCHOR_POINT_LABELS = {
    [DB.ANCHOR_POINTS.TOPLEFT] = "Top Left",
    [DB.ANCHOR_POINTS.TOP] = "Top",
    [DB.ANCHOR_POINTS.TOPRIGHT] = "Top Right",
    [DB.ANCHOR_POINTS.LEFT] = "Left",
    [DB.ANCHOR_POINTS.CENTER] = "Center",
    [DB.ANCHOR_POINTS.RIGHT] = "Right",
    [DB.ANCHOR_POINTS.BOTTOMLEFT] = "Bottom Left",
    [DB.ANCHOR_POINTS.BOTTOM] = "Bottom",
    [DB.ANCHOR_POINTS.BOTTOMRIGHT] = "Bottom Right",
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
    [DB.GROWTH_DIRECTIONS.RIGHT] = "Right",
    [DB.GROWTH_DIRECTIONS.LEFT] = "Left",
    [DB.GROWTH_DIRECTIONS.DOWN] = "Down",
    [DB.GROWTH_DIRECTIONS.UP] = "Up",
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

local function SanitizeStatusTextAnchorPoint(value, fallback)
    return DB:SanitizeStatusTextAnchorPoint(value, fallback)
end

local function SanitizeStatusTextColor(value, fallback)
    return DB:SanitizeStatusTextColor(value, fallback)
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

local function GetIncomingCastBarIconValue(key)
    return DB:GetIncomingCastBarIconValue(key)
end

local function SetIncomingCastBarIconValue(key, value)
    DB:SetIncomingCastBarIconValue(key, value)
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
        name = "Track incoming casts",
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
        name = "Preview incoming casts",
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

    local incomingCastBarDefaults = DB.DEFAULT_SETTINGS.incomingCastBar
    local incomingCastBarIconDefaults = incomingCastBarDefaults.icon or {}

    SettingsLib:CreateDropdown(incomingCastsCategory, {
        key = "IncomingCastAnchorFrame",
        name = "Anchor to",
        default = incomingCastBarDefaults.anchorFrame,
        values = {
            HEALTHBAR = "Health bar",
            FRAME = "Party frame",
        },
        get = function()
            local value = GetIncomingCastBarValue("anchorFrame")
            if value ~= "HEALTHBAR" and value ~= "FRAME" then
                value = incomingCastBarDefaults.anchorFrame
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarValue("anchorFrame", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Choose whether incoming cast icons are anchored to the party frame or to the frame health bar.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateDropdown(incomingCastsCategory, {
        key = "IncomingCastIconPosition",
        name = "Targeted spell position",
        default = incomingCastBarDefaults.position,
        values = ANCHOR_POINT_LABELS,
        get = function()
            return SanitizePosition(
                GetIncomingCastBarValue("position"),
                incomingCastBarDefaults.position
            )
        end,
        set = function(value)
            SetIncomingCastBarValue(
                "position",
                SanitizePosition(value, incomingCastBarDefaults.position)
            )
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Where to anchor targeted spell icons on the party frame.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateDropdown(incomingCastsCategory, {
        key = "IncomingCastIconGrowDirection",
        name = "Grow Direction",
        default = incomingCastBarDefaults.growthDirection,
        values = GROWTH_DIRECTION_LABELS,
        get = function()
            local pos = SanitizePosition(
                GetIncomingCastBarValue("position"),
                incomingCastBarDefaults.position
            )

            local dir = GetIncomingCastBarValue("growthDirection")

            if dir == nil then
                if pos == "TOPRIGHT" or pos == "RIGHT" or pos == "BOTTOMRIGHT" then
                    dir = DB.GROWTH_DIRECTIONS.LEFT
                else
                    dir = incomingCastBarDefaults.growthDirection
                end
            end

            if not DB.GROWTH_DIRECTIONS[dir] then
                dir = incomingCastBarDefaults.growthDirection
            end

            return dir
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
        key = "IncomingCastIconOffsetX",
        name = "X offset",
        default = incomingCastBarDefaults.offsetX,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = GetIncomingCastBarValue("offsetX")
            if value == nil then
                value = incomingCastBarDefaults.offsetX
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarValue("offsetX", value)

            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Horizontal offset (in pixels). Negative allows going outside the frame.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconOffsetY",
        name = "Y offset",
        default = incomingCastBarDefaults.offsetY,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = GetIncomingCastBarValue("offsetY")
            if value == nil then
                value = incomingCastBarDefaults.offsetY
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarValue("offsetY", value)

            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Vertical offset (in pixels). Negative allows going outside the frame.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconCount",
        name = "Targeted spell icon count",
        default = incomingCastBarDefaults.spellCount,
        min = 1,
        max = 6,
        step = 1,
        formatter = function(value)
            return string.format("%i", math.floor((value) + 0.5))
        end,
        get = function()
            local value = GetIncomingCastBarValue("spellCount")
            if value == nil then
                value = incomingCastBarDefaults.spellCount
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarValue("spellCount", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "How many targeted spell icons to show per party member.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconScale",
        name = "Icon scale",
        default = incomingCastBarIconDefaults.scale,
        min = 0.5,
        max = 2,
        step = 0.10,
        formatter = function(value)
            return string.format("%d%%", math.floor((value * 100) + 0.5))
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
        name = "Icon spacing",
        default = incomingCastBarIconDefaults.spacing,
        min = -10,
        max = 20,
        step = 1,
        formatter = function(value)
            return string.format("%i", math.floor((value) + 0.5))
        end,
        get = function()
            local value = GetIncomingCastBarIconValue("spacing")
            if value == nil then
                value = incomingCastBarIconDefaults.spacing
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarIconValue("spacing", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Space (in pixels) between targeted spell icons. Negative values allow overlap.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "IncomingCastIconBorder",
        name = "Show icon border",
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

    SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "IncomingCastIconSwipe",
        name = "Show cooldown swipe",
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

    local incomingCastIconCooldownTextElement = SettingsLib:CreateCheckbox(incomingCastsCategory, {
        key = "IncomingCastIconCooldownText",
        name = "Show cooldown text",
        default = incomingCastBarIconDefaults.showCooldownText,
        get = function()
            local value = GetIncomingCastBarIconValue("showCooldownText")
            if value == nil then
                value = incomingCastBarIconDefaults.showCooldownText
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarIconValue("showCooldownText", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the cooldown countdown text on targeted spell icons.",
        prefix = incomingCastsPrefix,
    })

    SettingsLib:CreateSlider(incomingCastsCategory, {
        key = "IncomingCastIconCooldownFontSize",
        name = "Cooldown text size",
        default = incomingCastBarIconDefaults.cooldownFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = GetIncomingCastBarIconValue("cooldownFontSize")
            if value == nil then
                value = incomingCastBarIconDefaults.cooldownFontSize
            end
            return value
        end,
        set = function(value)
            SetIncomingCastBarIconValue("cooldownFontSize", math.floor((value) + 0.5))
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Adjust the cooldown countdown text size on targeted spell icons.",
        prefix = incomingCastsPrefix,
        parent = incomingCastIconCooldownTextElement,
        parentCheck = function()
            local value = GetIncomingCastBarIconValue("showCooldownText")
            if value == nil then
                value = incomingCastBarIconDefaults.showCooldownText
            end
            return value == true
        end,
    })
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
        name = "Show in Solo",
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
        name = "Status Text",
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "StatusTextAnchorTarget",
        name = "Anchor to",
        default = DB.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget,
        values = FRAME_ANCHOR_TARGET_LABELS,
        get = function()
            return SanitizeIncomingCastAnchorFrame(
                PartyFrameProfile().statusTextAnchorTarget,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget
            )
        end,
        set = function(value)
            PartyFrameProfile().statusTextAnchorTarget = SanitizeIncomingCastAnchorFrame(
                value,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget
            )
            FF:UpdateStatusTextAnchoring()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Choose whether status text is anchored to the party frame or health bar.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "StatusTextAnchorPoint",
        name = "Status text anchor",
        default = DB.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint,
        values = ANCHOR_POINT_LABELS,
        get = function()
            return SanitizeStatusTextAnchorPoint(
                PartyFrameProfile().statusTextAnchorPoint,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint
            )
        end,
        set = function(value)
            PartyFrameProfile().statusTextAnchorPoint = SanitizeStatusTextAnchorPoint(
                value,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint
            )
            FF:UpdateStatusTextAnchoring()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Anchor point used for status text on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "StatusTextOffsetX",
        name = "Status text X offset",
        default = DB.DEFAULT_SETTINGS.partyFrame.statusTextOffsetX,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().statusTextOffsetX
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.statusTextOffsetX
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().statusTextOffsetX = math.floor((value) + 0.5)
            FF:UpdateStatusTextAnchoring()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Horizontal offset for status text anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "StatusTextOffsetY",
        name = "Status text Y offset",
        default = DB.DEFAULT_SETTINGS.partyFrame.statusTextOffsetY,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().statusTextOffsetY
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.statusTextOffsetY
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().statusTextOffsetY = math.floor((value) + 0.5)
            FF:UpdateStatusTextAnchoring()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Vertical offset for status text anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "HealthTextFontSize",
        name = "Status text size",
        default = DB.DEFAULT_SETTINGS.partyFrame.healthTextFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().healthTextFontSize
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.healthTextFontSize
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().healthTextFontSize = math.floor((value) + 0.5)
            FF:UpdateHealthTextFontSize()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Adjust the status text size on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "StatusTextOpacity",
        name = "Status text opacity",
        default = DB.DEFAULT_SETTINGS.partyFrame.statusTextOpacity,
        min = 0,
        max = 1,
        step = 0.01,
        formatter = function(value)
            return string.format("%d%%", math.floor((value * 100) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().statusTextOpacity
            if value == nil then
                local color = SanitizeStatusTextColor(
                    PartyFrameProfile().statusTextColor,
                    DB.DEFAULT_SETTINGS.partyFrame.statusTextColor
                )
                value = color.a
            end

            return SanitizeOpacity(value, DB.DEFAULT_SETTINGS.partyFrame.statusTextOpacity)
        end,
        set = function(value)
            local opacity = SanitizeOpacity(value, DB.DEFAULT_SETTINGS.partyFrame.statusTextOpacity)
            PartyFrameProfile().statusTextOpacity = opacity

            local color = SanitizeStatusTextColor(
                PartyFrameProfile().statusTextColor,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextColor
            )
            color.a = opacity
            PartyFrameProfile().statusTextColor = color

            FF:UpdateStatusTextColor()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Adjust opacity for status text on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    local statusTextUseClassColorsElement = SettingsLib:CreateCheckbox(rootCategory, {
        key = "StatusTextUseClassColors",
        name = "Use class colors",
        default = DB.DEFAULT_SETTINGS.partyFrame.statusTextUseClassColors,
        get = function()
            return PartyFrameProfile().statusTextUseClassColors == true
        end,
        set = function(value)
            PartyFrameProfile().statusTextUseClassColors = (value == true)
            FF:UpdateStatusTextColor()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Use class colors for status text instead of the configured static text color.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateColorOverrides(rootCategory, {
        key = "StatusTextColor",
        entries = {
            { key = "StatusText", label = "Status text color" },
        },
        getColor = function()
            local color = SanitizeStatusTextColor(
                PartyFrameProfile().statusTextColor,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextColor
            )
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            local currentColor = SanitizeStatusTextColor(
                PartyFrameProfile().statusTextColor,
                DB.DEFAULT_SETTINGS.partyFrame.statusTextColor
            )
            local opacity = SanitizeOpacity(
                PartyFrameProfile().statusTextOpacity,
                currentColor.a
            )
            PartyFrameProfile().statusTextColor = SanitizeStatusTextColor(
                { r = r, g = g, b = b, a = opacity },
                DB.DEFAULT_SETTINGS.partyFrame.statusTextColor
            )
            PartyFrameProfile().statusTextOpacity = opacity
            FF:UpdateStatusTextColor()
            FF:RequestStatusTextSettingsRefresh()
        end,
        getDefaultColor = function()
            local color = SanitizeStatusTextColor(
                DB.DEFAULT_SETTINGS.partyFrame.statusTextColor,
                { r = 1, g = 1, b = 1, a = 1 }
            )
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        isEnabled = function()
            return PartyFrameProfile().statusTextUseClassColors ~= true
        end,
        parent = statusTextUseClassColorsElement,
        parentCheck = function()
            return PartyFrameProfile().statusTextUseClassColors ~= true
        end,
        minHeight = 36,
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Player Name",
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "PlayerNameAnchorTarget",
        name = "Anchor to",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget,
        values = FRAME_ANCHOR_TARGET_LABELS,
        get = function()
            return SanitizeIncomingCastAnchorFrame(
                PartyFrameProfile().playerNameAnchorTarget,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget
            )
        end,
        set = function(value)
            PartyFrameProfile().playerNameAnchorTarget = SanitizeIncomingCastAnchorFrame(
                value,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget
            )
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Choose whether player name is anchored to the party frame or health bar.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "PlayerNameAnchorPoint",
        name = "Player name anchor",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint,
        values = ANCHOR_POINT_LABELS,
        get = function()
            return SanitizeStatusTextAnchorPoint(
                PartyFrameProfile().playerNameAnchorPoint,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint
            )
        end,
        set = function(value)
            PartyFrameProfile().playerNameAnchorPoint = SanitizeStatusTextAnchorPoint(
                value,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint
            )
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Anchor point used for player name on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameOffsetX",
        name = "Player name X offset",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameOffsetX,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().playerNameOffsetX
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.playerNameOffsetX
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().playerNameOffsetX = math.floor((value) + 0.5)
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Horizontal offset for player name anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameOffsetY",
        name = "Player name Y offset",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameOffsetY,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().playerNameOffsetY
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.playerNameOffsetY
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().playerNameOffsetY = math.floor((value) + 0.5)
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Vertical offset for player name anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameFontSize",
        name = "Player name size",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().playerNameFontSize
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.playerNameFontSize
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().playerNameFontSize = math.floor((value) + 0.5)
            FF:UpdatePlayerNameFontSize()
        end,
        desc = "Adjust the player name text size on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameOpacity",
        name = "Player name opacity",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameOpacity,
        min = 0,
        max = 1,
        step = 0.01,
        formatter = function(value)
            return string.format("%d%%", math.floor((value * 100) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().playerNameOpacity
            if value == nil then
                local color = SanitizeStatusTextColor(
                    PartyFrameProfile().playerNameColor,
                    DB.DEFAULT_SETTINGS.partyFrame.playerNameColor
                )
                value = color.a
            end

            return SanitizeOpacity(value, DB.DEFAULT_SETTINGS.partyFrame.playerNameOpacity)
        end,
        set = function(value)
            local opacity = SanitizeOpacity(value, DB.DEFAULT_SETTINGS.partyFrame.playerNameOpacity)
            PartyFrameProfile().playerNameOpacity = opacity

            local color = SanitizeStatusTextColor(
                PartyFrameProfile().playerNameColor,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameColor
            )
            color.a = opacity
            PartyFrameProfile().playerNameColor = color

            FF:UpdatePlayerNameColor()
        end,
        desc = "Adjust opacity for player name text on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    local playerNameUseClassColorsElement = SettingsLib:CreateCheckbox(rootCategory, {
        key = "PlayerNameUseClassColors",
        name = "Use class colors",
        default = DB.DEFAULT_SETTINGS.partyFrame.playerNameUseClassColors,
        get = function()
            return PartyFrameProfile().playerNameUseClassColors == true
        end,
        set = function(value)
            PartyFrameProfile().playerNameUseClassColors = (value == true)
            FF:UpdatePlayerNameColor()
        end,
        desc = "Use class colors for player name instead of the configured static text color.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateColorOverrides(rootCategory, {
        key = "PlayerNameColor",
        entries = {
            { key = "PlayerName", label = "Player name color" },
        },
        getColor = function()
            local color = SanitizeStatusTextColor(
                PartyFrameProfile().playerNameColor,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameColor
            )
            return color.r, color.g, color.b
        end,
        setColor = function(_, r, g, b)
            local currentColor = SanitizeStatusTextColor(
                PartyFrameProfile().playerNameColor,
                DB.DEFAULT_SETTINGS.partyFrame.playerNameColor
            )
            local opacity = SanitizeOpacity(
                PartyFrameProfile().playerNameOpacity,
                currentColor.a
            )
            PartyFrameProfile().playerNameColor = SanitizeStatusTextColor(
                { r = r, g = g, b = b, a = opacity },
                DB.DEFAULT_SETTINGS.partyFrame.playerNameColor
            )
            PartyFrameProfile().playerNameOpacity = opacity
            FF:UpdatePlayerNameColor()
        end,
        getDefaultColor = function()
            local color = SanitizeStatusTextColor(
                DB.DEFAULT_SETTINGS.partyFrame.playerNameColor,
                { r = 1, g = 1, b = 1, a = 1 }
            )
            return color.r, color.g, color.b
        end,
        hasOpacity = false,
        isEnabled = function()
            return PartyFrameProfile().playerNameUseClassColors ~= true
        end,
        parent = playerNameUseClassColorsElement,
        parentCheck = function()
            return PartyFrameProfile().playerNameUseClassColors ~= true
        end,
        minHeight = 36,
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
        name = "Buff/Debuffs",
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowBuffCountdown",
        name = "Show Buff Countdown",
        default = DB.DEFAULT_SETTINGS.partyFrame.showBuffCountdown,
        get = function() return PartyFrameProfile().showBuffCountdown end,
        set = function(value)
            PartyFrameProfile().showBuffCountdown = value
            self:ShowBuffCountdownIfNeeded()
        end,
        desc = "Toggle the buff countdown visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowDebuffCountdown",
        name = "Show Debuff Countdown",
        default = DB.DEFAULT_SETTINGS.partyFrame.showDebuffCountdown,
        get = function() return PartyFrameProfile().showDebuffCountdown end,
        set = function(value)
            PartyFrameProfile().showDebuffCountdown = value
            self:ShowDebuffCountdownIfNeeded()
        end,
        desc = "Toggle the debuff countdown visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "CountdownFontSize",
        name = "Countdown Text Size",
        default = DB.DEFAULT_SETTINGS.partyFrame.countdownFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = PartyFrameProfile().countdownFontSize
            if value == nil then
                value = DB.DEFAULT_SETTINGS.partyFrame.countdownFontSize
            end
            return value
        end,
        set = function(value)
            PartyFrameProfile().countdownFontSize = math.floor((value) + 0.5)
            self:UpdateAuraCountdownFontSize()
        end,
        desc = "Adjust the buff/debuff countdown text size on party frames.",
        prefix = PARTY_FRAME_PREFIX
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

    CreateIncomingCastsSettings(rootCategory)
end
