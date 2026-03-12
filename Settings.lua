local addonName, addon = ...
local FF = FoxFrames

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

FF.PLAYER_FRAME_SHOW_TYPES = { Always = "Always", Solo = "Solo", Never = "Never" }
FF.DEFAULT_TEXTURE = "DEFAULT"
FF.DEFAULT_SETTINGS = {
    playerFrame = {
        showType = FF.PLAYER_FRAME_SHOW_TYPES.Always
    },
    partyFrame = {
        showTitle = true,
        showTankRoleIcon = true,
        showHealerRoleIcon = true,
        showDPSRoleIcon = true,
        showInSolo = false,
        showBuffCountdown = false,
        showDebuffCountdown = false,
        healthBarTexture = FF.DEFAULT_TEXTURE,
        allowAnyAnchoring = false,
        trackIncomingCasts = false,
    },
    incomingCastBar = {
        spellCount = 3,
        position = "BOTTOMLEFT",
        growthDirection = "RIGHT",
        offsetX = 2,
        offsetY = 2,
        icon = {
            scale = 1,
            spacing = 0,
            showBorder = true,
            showSwipe = true,
            showCooldownText = true,
        },
    }
}

function FF:GetTextures()
    local alreadyAddedPaths = {}

    -- Always add built-in textures at the top in specific order
    local textures = {{
        path = FF.DEFAULT_TEXTURE,
        name = "Default"
    }, {
        path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        name = "Raid"
    }, {
        path = "Interface\\TargetingFrame\\UI-StatusBar",
        name = "Blizzard"
    }, {
        path = "Interface\\Buttons\\WHITE8X8",
        name = "Flat"
    }, {
        path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
        name = "Glossy"
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

local function ClampNumber(value, minValue, maxValue, fallback)
    local num = value
    if type(num) ~= "number" then
        num = tonumber(num)
    end
    if type(num) ~= "number" then
        num = fallback
    end
    if type(num) ~= "number" then
        num = minValue
    end
    if num < minValue then
        num = minValue
    elseif num > maxValue then
        num = maxValue
    end
    return num
end

local function SanitizePosition(value, fallback)
    if value == "TOPLEFT" or value == "BOTTOMLEFT" or value == "TOP" or value == "BOTTOM" or value == "TOPRIGHT" or value == "BOTTOMRIGHT" then
        return value
    end
    return fallback
end

local function SanitizeGrowDirection(value, fallback)
    if value == "RIGHT" or value == "LEFT" or value == "DOWN" or value == "UP" then
        return value
    end
    return fallback
end

local function SanitizeBoolean(value, fallback)
    if value == nil then
        return fallback
    end
    return value == true
end

function FF:MigrateAndSanitizeDB()
    local profile = self and self.db and self.db.profile
    if type(profile) ~= "table" then
        return
    end

    if type(profile.partyFrame) ~= "table" then
        profile.partyFrame = {}
    end
    if type(profile.incomingCastBar) ~= "table" then
        profile.incomingCastBar = {}
    end

    local defaults = self.DEFAULT_SETTINGS and self.DEFAULT_SETTINGS.incomingCastBar or {}
    local iconDefaults = defaults.icon or {}
    local partyFrameProfile = profile.partyFrame
    local incomingCastBarProfile = profile.incomingCastBar

    local position = SanitizePosition(
        incomingCastBarProfile.position,
        defaults.position or "BOTTOMLEFT"
    )

    local growthDirection = incomingCastBarProfile.growthDirection
    if growthDirection == nil then
        if position == "TOPRIGHT" or position == "BOTTOMRIGHT" then
            growthDirection = "LEFT"
        else
            growthDirection = defaults.growthDirection or "RIGHT"
        end
    end
    growthDirection = SanitizeGrowDirection(growthDirection, defaults.growthDirection or "RIGHT")

    local spellCount = ClampNumber(incomingCastBarProfile.spellCount, 1, 6, defaults.spellCount or 3)
    spellCount = math.floor(spellCount + 0.5)

    local offsetX = ClampNumber(incomingCastBarProfile.offsetX, -200, 200, defaults.offsetX or 2)
    offsetX = math.floor(offsetX + 0.5)

    local offsetY = ClampNumber(incomingCastBarProfile.offsetY, -200, 200, defaults.offsetY or 2)
    offsetY = math.floor(offsetY + 0.5)

    if type(incomingCastBarProfile.icon) ~= "table" then
        incomingCastBarProfile.icon = {}
    end
    local iconProfile = incomingCastBarProfile.icon

    local iconScale = ClampNumber(iconProfile.scale, 0.5, 3, iconDefaults.scale or 1)
    iconScale = math.floor((iconScale * 100) + 0.5) / 100

    local iconSpacing = ClampNumber(iconProfile.spacing, -10, 50, iconDefaults.spacing or 0)
    iconSpacing = math.floor(iconSpacing + 0.5)

    local iconShowBorder = SanitizeBoolean(iconProfile.showBorder, iconDefaults.showBorder ~= false)
    local iconShowSwipe = SanitizeBoolean(iconProfile.showSwipe, iconDefaults.showSwipe ~= false)
    local iconShowCooldownText = SanitizeBoolean(iconProfile.showCooldownText, iconDefaults.showCooldownText ~= false)

    incomingCastBarProfile.spellCount = spellCount
    incomingCastBarProfile.position = position
    incomingCastBarProfile.growthDirection = growthDirection
    incomingCastBarProfile.offsetX = offsetX
    incomingCastBarProfile.offsetY = offsetY

    iconProfile.scale = iconScale
    iconProfile.spacing = iconSpacing
    iconProfile.showBorder = iconShowBorder
    iconProfile.showSwipe = iconShowSwipe
    iconProfile.showCooldownText = iconShowCooldownText

    partyFrameProfile.trackIncomingCasts = (partyFrameProfile.trackIncomingCasts == true)
end

local function GetIncomingCastBarProfile()
    local profile = FF and FF.db and FF.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    if type(profile.incomingCastBar) ~= "table" then
        profile.incomingCastBar = {}
    end

    return profile.incomingCastBar
end

local function GetIncomingCastBarValue(key)
    local incomingCastBarProfile = GetIncomingCastBarProfile()
    return incomingCastBarProfile and incomingCastBarProfile[key]
end

local function SetIncomingCastBarValue(key, value)
    local incomingCastBarProfile = GetIncomingCastBarProfile()
    if incomingCastBarProfile then
        incomingCastBarProfile[key] = value
    end
end

local function GetIncomingCastBarIconValue(key)
    local incomingCastBarProfile = GetIncomingCastBarProfile()
    local iconProfile = incomingCastBarProfile and incomingCastBarProfile.icon
    if type(iconProfile) ~= "table" then
        return nil
    end
    return iconProfile[key]
end

local function SetIncomingCastBarIconValue(key, value)
    local incomingCastBarProfile = GetIncomingCastBarProfile()
    if not incomingCastBarProfile then
        return
    end

    if type(incomingCastBarProfile.icon) ~= "table" then
        incomingCastBarProfile.icon = {}
    end

    incomingCastBarProfile.icon[key] = value
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
        default = FF.DEFAULT_SETTINGS.partyFrame.showInSolo,
        get = function() return FF.db.profile.partyFrame.showInSolo end,
        set = function(value)
            FF.db.profile.partyFrame.showInSolo = value
            FF:ShowPartyFrameIfNeeded()
        end,
        desc = "Toggle the frame visibility when solo.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowTitle",
        name = "Show Title",
        default = FF.DEFAULT_SETTINGS.partyFrame.showTitle,
        get = function() 
            return FF.db.profile.partyFrame.showTitle 
        end,
        set = function(value)
            FF.db.profile.partyFrame.showTitle = value
            FF:ShowPartyFrameTitleIfNeeded()
        end,
        desc = "Toggle the title visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "UseClassColors",
        name = "Use Class Colors",
        default = FF.DEFAULT_SETTINGS.partyFrame.useClassColors,
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
        key = "ShowTankRoleIcon",
        name = "Show Tank Role Icon",
        default = FF.DEFAULT_SETTINGS.partyFrame.showTankRoleIcon,
        get = function() return FF.db.profile.partyFrame.showTankRoleIcon end,
        set = function(value) 
            FF.db.profile.partyFrame.showTankRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the Tank role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowHealerRoleIcon",
        name = "Show Healer Role Icon",
        default = FF.DEFAULT_SETTINGS.partyFrame.showHealerRoleIcon,
        get = function() return FF.db.profile.partyFrame.showHealerRoleIcon end,
        set = function(value) 
            FF.db.profile.partyFrame.showHealerRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the Healer role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowDPSRoleIcon",
        name = "Show DPS Role Icon",
        default = FF.DEFAULT_SETTINGS.partyFrame.showDPSRoleIcon,
        get = function() return FF.db.profile.partyFrame.showDPSRoleIcon end,
        set = function(value)
            FF.db.profile.partyFrame.showDPSRoleIcon = value
            FF:UpdateFrames()
        end,
        desc = "Toggle the DPS role icon visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowBuffCountdown",
        name = "Show Buff Countdown",
        default = FF.DEFAULT_SETTINGS.partyFrame.showBuffCountdown,
        get = function() return FF.db.profile.partyFrame.showBuffCountdown end,
        set = function(value)
            FF.db.profile.partyFrame.showBuffCountdown = value
            self:ShowBuffCountdownIfNeeded()
        end,
        desc = "Toggle the buff countdown visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ShowDebuffCountdown",
        name = "Show Debuff Countdown",
        default = FF.DEFAULT_SETTINGS.partyFrame.showDebuffCountdown,
        get = function() return FF.db.profile.partyFrame.showDebuffCountdown end,
        set = function(value)
            FF.db.profile.partyFrame.showDebuffCountdown = value
            self:ShowDebuffCountdownIfNeeded()
        end,
        desc = "Toggle the debuff countdown visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "AllowAnyAnchoring",
        name = "Allow Any Anchoring",
        default = FF.DEFAULT_SETTINGS.partyFrame.allowAnyAnchoring,
        get = function() return FF.db.profile.partyFrame.allowAnyAnchoring end,
        set = function(value)
            FF.db.profile.partyFrame.allowAnyAnchoring = value
            FF:SetAllowAnyAnchoring()
        end,
        desc = "By default, Blizzard's party frames will convert anchoring to top-left. This results in always top-left alignment of frames. Enabling this will allow you to use other anchor points such as center, bottom or right. You will need to re-anchor the party frames after changing this setting.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateText(
        rootCategory, 
        "You will need to re-center the party frames on the UI to set the new anchor point."
    )

    SettingsLib:CreateDropdown(rootCategory, {
        key = "ShowPlayerFrame",
        name = "Show Player Frame",
        default = FF.DEFAULT_SETTINGS.playerFrame.showType,
        values = FF.PLAYER_FRAME_SHOW_TYPES,
        get = function()
            return FF.db.profile.playerFrame.showType or FF.DEFAULT_SETTINGS.playerFrame.showType
        end,
        set = function(value)
            FF.db.profile.playerFrame.showType = value
            self:ShowPlayerFrameIfNeeded()
        end,
        desc = "Control the visibility of the player frame. 'Always' will show the player frame regardless of group status. 'Solo' will only show the player frame when not in a party or raid. 'Never' will hide the player frame regardless of group status.",
        prefix = PARTY_FRAME_PREFIX
    })

    -- Build texture list from LibSharedMedia or fallback to built-in
    local textureOrder = {}
    local textures = self:GetTextures()

    -- Go through built in textures
    for _, texture in ipairs(textures) do
        table.insert(textureOrder, texture.path)
    end

    SettingsLib:CreateScrollDropdown(rootCategory, {
        key = "HealthBarTexture",
        name = "Health Bar Texture",
        default = FF.DEFAULT_TEXTURE,
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
            return FF.db.profile.partyFrame.healthBarTexture or FF.DEFAULT_TEXTURE
        end,
        set = function(value)
            if value == FF.DEFAULT_TEXTURE then
                FF.db.profile.partyFrame.healthBarTexture = nil
            else
                FF.db.profile.partyFrame.healthBarTexture = value
            end

            FF:UpdateFrames()
        end,
        height = 220, -- scrollable menu
        prefix = PARTY_FRAME_PREFIX,
        isEnabled = function() return true end,
    })

    SettingsLib:CreateText(
    rootCategory, 
        "You need to reload the UI when setting the 'Default' texture."
    )

    SettingsLib:CreateHeader(rootCategory, {
        name = "Incoming Casts",
    })

    SettingsLib:CreateCheckboxButton(rootCategory, {
        key = "TrackIncomingCasts",
        name = "Track incoming casts",
        default = FF.DEFAULT_SETTINGS.partyFrame.trackIncomingCasts,
        get = function()
            return FF.db.profile.partyFrame.trackIncomingCasts
        end,
        set = function(value)
            FF.db.profile.partyFrame.trackIncomingCasts = value
            if not value then
                FF:SetIncomingCastIndicatorPreviewEnabled(false)
            end
        end,
        prefix = PARTY_FRAME_PREFIX,

        buttonText = "Toggle Preview",
        buttonClick = function()
            FF:ToggleIncomingCastIndicatorPreview()
        end,
        clickRequiresSet = true, -- button only active when checkbox is checked
    })

    local incomingCastBarDefaults = FF.DEFAULT_SETTINGS.incomingCastBar
    local incomingCastBarIconDefaults = incomingCastBarDefaults.icon or {}

    SettingsLib:CreateDropdown(rootCategory, {
        key = "IncomingCastIconPosition",
        name = "Targeted spell position",
        default = incomingCastBarDefaults.position,
        values = {
            BOTTOMLEFT = "Bottom left",
            TOPLEFT = "Top left",
            BOTTOMRIGHT = "Bottom right",
            TOPRIGHT = "Top right",
            BOTTOM = "Bottom center",
            TOP = "Top center",
        },
        get = function()
            local pos = GetIncomingCastBarValue("position")
            if pos ~= "TOPLEFT" and pos ~= "BOTTOMLEFT" and pos ~= "TOP" and pos ~= "BOTTOM" and pos ~= "TOPRIGHT" and pos ~= "BOTTOMRIGHT" then
                pos = incomingCastBarDefaults.position
            end
            return pos
        end,
        set = function(value)
            SetIncomingCastBarValue("position", value)
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Where to anchor targeted spell icons on the party frame.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "IncomingCastIconGrowDirection",
        name = "Grow Direction",
        default = incomingCastBarDefaults.growthDirection,
        values = {
            RIGHT = "Right",
            LEFT = "Left",
            DOWN = "Down",
            UP = "Up",
        },
        get = function()
            local pos = GetIncomingCastBarValue("position")
            if pos ~= "TOPLEFT" and pos ~= "BOTTOMLEFT" and pos ~= "TOP" and pos ~= "BOTTOM" and pos ~= "TOPRIGHT" and pos ~= "BOTTOMRIGHT" then
                pos = incomingCastBarDefaults.position
            end

            local dir = GetIncomingCastBarValue("growthDirection")

            if dir == nil then
                if pos == "TOPRIGHT" or pos == "BOTTOMRIGHT" then
                    dir = "LEFT"
                else
                    dir = incomingCastBarDefaults.growthDirection
                end
            end

            if dir ~= "RIGHT" and dir ~= "LEFT" and dir ~= "DOWN" and dir ~= "UP" then
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })
end
