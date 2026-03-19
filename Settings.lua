local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

FF.PLAYER_FRAME_SHOW_TYPES = { Always = "Always", Solo = "Solo", Never = "Never" }
FF.STATUS_TEXT_ANCHOR_POINTS = {
    TOPLEFT = "Top left",
    TOP = "Top",
    TOPRIGHT = "Top right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom right",
}
FF.STATUS_TEXT_ANCHOR_TARGETS = {
    FRAME = "Party frame",
    HEALTHBAR = "Health bar",
}
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
        countdownFontSize = 12,
        healthTextFontSize = 10,
        statusTextColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 1,
        },
        statusTextAnchorTarget = "FRAME",
        statusTextAnchorPoint = "CENTER",
        statusTextOffsetX = 0,
        statusTextOffsetY = 0,
        playerNameFontSize = 10,
        playerNameColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 1,
        },
        playerNameAnchorTarget = "FRAME",
        playerNameAnchorPoint = "CENTER",
        playerNameOffsetX = 0,
        playerNameOffsetY = 0,
        healthBarTexture = FF.DEFAULT_TEXTURE,
        allowAnyAnchoring = false,
        trackIncomingCasts = false,
    },
    incomingCastBar = {
        spellCount = 3,
        anchorFrame = "HEALTHBAR",
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
            cooldownFontSize = 10,
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

local function SanitizeIncomingCastAnchorFrame(value, fallback)
    if value == "FRAME" or value == "HEALTHBAR" then
        return value
    end
    return fallback
end

local function SanitizeStatusTextAnchorPoint(value, fallback)
    if value == "TOPLEFT" or value == "TOP" or value == "TOPRIGHT"
        or value == "LEFT" or value == "CENTER" or value == "RIGHT"
        or value == "BOTTOMLEFT" or value == "BOTTOM" or value == "BOTTOMRIGHT" then
        return value
    end
    return fallback
end

local function SanitizeStatusTextColor(value, fallback)
    local fallbackColor = fallback
    if type(fallbackColor) ~= "table" then
        fallbackColor = { r = 1, g = 1, b = 1, a = 1 }
    end

    local color = value
    if type(color) ~= "table" then
        color = fallbackColor
    end

    return {
        r = Utils:ClampNumber(color.r, 0, 1, fallbackColor.r or 1),
        g = Utils:ClampNumber(color.g, 0, 1, fallbackColor.g or 1),
        b = Utils:ClampNumber(color.b, 0, 1, fallbackColor.b or 1),
        a = Utils:ClampNumber(color.a, 0, 1, fallbackColor.a or 1),
    }
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

    local anchorFrame = SanitizeIncomingCastAnchorFrame(
        incomingCastBarProfile.anchorFrame,
        defaults.anchorFrame or "HEALTHBAR"
    )

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

    local spellCount = Utils:ClampNumber(incomingCastBarProfile.spellCount, 1, 6, defaults.spellCount or 3)
    spellCount = math.floor(spellCount + 0.5)

    local offsetX = Utils:ClampNumber(incomingCastBarProfile.offsetX, -200, 200, defaults.offsetX or 2)
    offsetX = math.floor(offsetX + 0.5)

    local offsetY = Utils:ClampNumber(incomingCastBarProfile.offsetY, -200, 200, defaults.offsetY or 2)
    offsetY = math.floor(offsetY + 0.5)

    if type(incomingCastBarProfile.icon) ~= "table" then
        incomingCastBarProfile.icon = {}
    end
    local iconProfile = incomingCastBarProfile.icon

    local iconScale = Utils:ClampNumber(iconProfile.scale, 0.5, 3, iconDefaults.scale or 1)
    iconScale = math.floor((iconScale * 100) + 0.5) / 100

    local iconSpacing = Utils:ClampNumber(iconProfile.spacing, -10, 50, iconDefaults.spacing or 0)
    iconSpacing = math.floor(iconSpacing + 0.5)

    local iconCooldownFontSize = Utils:ClampNumber(iconProfile.cooldownFontSize, 8, 32, iconDefaults.cooldownFontSize or 10)
    iconCooldownFontSize = math.floor(iconCooldownFontSize + 0.5)

    local iconShowBorder = SanitizeBoolean(iconProfile.showBorder, iconDefaults.showBorder ~= false)
    local iconShowSwipe = SanitizeBoolean(iconProfile.showSwipe, iconDefaults.showSwipe ~= false)
    local iconShowCooldownText = SanitizeBoolean(iconProfile.showCooldownText, iconDefaults.showCooldownText ~= false)

    incomingCastBarProfile.spellCount = spellCount
    incomingCastBarProfile.anchorFrame = anchorFrame
    incomingCastBarProfile.position = position
    incomingCastBarProfile.growthDirection = growthDirection
    incomingCastBarProfile.offsetX = offsetX
    incomingCastBarProfile.offsetY = offsetY

    iconProfile.scale = iconScale
    iconProfile.spacing = iconSpacing
    iconProfile.cooldownFontSize = iconCooldownFontSize
    iconProfile.showBorder = iconShowBorder
    iconProfile.showSwipe = iconShowSwipe
    iconProfile.showCooldownText = iconShowCooldownText

    partyFrameProfile.trackIncomingCasts = (partyFrameProfile.trackIncomingCasts == true)
    partyFrameProfile.countdownFontSize = math.floor(Utils:ClampNumber(
        partyFrameProfile.countdownFontSize,
        8,
        32,
        self.DEFAULT_SETTINGS.partyFrame.countdownFontSize or 12
    ) + 0.5)
    partyFrameProfile.healthTextFontSize = math.floor(Utils:ClampNumber(
        partyFrameProfile.healthTextFontSize,
        8,
        32,
        self.DEFAULT_SETTINGS.partyFrame.healthTextFontSize or 10
    ) + 0.5)
    partyFrameProfile.statusTextColor = SanitizeStatusTextColor(
        partyFrameProfile.statusTextColor,
        self.DEFAULT_SETTINGS.partyFrame.statusTextColor
    )
    partyFrameProfile.statusTextOffsetX = math.floor(Utils:ClampNumber(
        partyFrameProfile.statusTextOffsetX,
        -100,
        100,
        self.DEFAULT_SETTINGS.partyFrame.statusTextOffsetX or 0
    ) + 0.5)
    partyFrameProfile.statusTextOffsetY = math.floor(Utils:ClampNumber(
        partyFrameProfile.statusTextOffsetY,
        -100,
        100,
        self.DEFAULT_SETTINGS.partyFrame.statusTextOffsetY or 0
    ) + 0.5)
    partyFrameProfile.statusTextAnchorTarget = SanitizeIncomingCastAnchorFrame(
        partyFrameProfile.statusTextAnchorTarget,
        self.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget or "FRAME"
    )
    partyFrameProfile.statusTextAnchorPoint = SanitizeStatusTextAnchorPoint(
        partyFrameProfile.statusTextAnchorPoint,
        self.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint or "CENTER"
    )
    partyFrameProfile.playerNameFontSize = math.floor(Utils:ClampNumber(
        partyFrameProfile.playerNameFontSize,
        8,
        32,
        self.DEFAULT_SETTINGS.partyFrame.playerNameFontSize or 10
    ) + 0.5)
    partyFrameProfile.playerNameColor = SanitizeStatusTextColor(
        partyFrameProfile.playerNameColor,
        self.DEFAULT_SETTINGS.partyFrame.playerNameColor
    )
    partyFrameProfile.playerNameOffsetX = math.floor(Utils:ClampNumber(
        partyFrameProfile.playerNameOffsetX,
        -100,
        100,
        self.DEFAULT_SETTINGS.partyFrame.playerNameOffsetX or 0
    ) + 0.5)
    partyFrameProfile.playerNameOffsetY = math.floor(Utils:ClampNumber(
        partyFrameProfile.playerNameOffsetY,
        -100,
        100,
        self.DEFAULT_SETTINGS.partyFrame.playerNameOffsetY or 0
    ) + 0.5)
    partyFrameProfile.playerNameAnchorTarget = SanitizeIncomingCastAnchorFrame(
        partyFrameProfile.playerNameAnchorTarget,
        self.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget or "FRAME"
    )
    partyFrameProfile.playerNameAnchorPoint = SanitizeStatusTextAnchorPoint(
        partyFrameProfile.playerNameAnchorPoint,
        self.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint or "TOPLEFT"
    )
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

    SettingsLib:CreateHeader(rootCategory, {
        name = "General",
    })

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
        name = "Status Text",
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "StatusTextAnchorTarget",
        name = "Anchor to",
        default = FF.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget,
        values = FF.STATUS_TEXT_ANCHOR_TARGETS,
        get = function()
            return SanitizeIncomingCastAnchorFrame(
                FF.db.profile.partyFrame.statusTextAnchorTarget,
                FF.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget
            )
        end,
        set = function(value)
            FF.db.profile.partyFrame.statusTextAnchorTarget = SanitizeIncomingCastAnchorFrame(
                value,
                FF.DEFAULT_SETTINGS.partyFrame.statusTextAnchorTarget
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
        default = FF.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint,
        values = FF.STATUS_TEXT_ANCHOR_POINTS,
        get = function()
            return SanitizeStatusTextAnchorPoint(
                FF.db.profile.partyFrame.statusTextAnchorPoint,
                FF.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint
            )
        end,
        set = function(value)
            FF.db.profile.partyFrame.statusTextAnchorPoint = SanitizeStatusTextAnchorPoint(
                value,
                FF.DEFAULT_SETTINGS.partyFrame.statusTextAnchorPoint
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
        default = FF.DEFAULT_SETTINGS.partyFrame.statusTextOffsetX,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.statusTextOffsetX
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.statusTextOffsetX
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.statusTextOffsetX = math.floor((value) + 0.5)
            FF:UpdateStatusTextAnchoring()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Horizontal offset for status text anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "StatusTextOffsetY",
        name = "Status text Y offset",
        default = FF.DEFAULT_SETTINGS.partyFrame.statusTextOffsetY,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.statusTextOffsetY
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.statusTextOffsetY
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.statusTextOffsetY = math.floor((value) + 0.5)
            FF:UpdateStatusTextAnchoring()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Vertical offset for status text anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "HealthTextFontSize",
        name = "Status text size",
        default = FF.DEFAULT_SETTINGS.partyFrame.healthTextFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.healthTextFontSize
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.healthTextFontSize
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.healthTextFontSize = math.floor((value) + 0.5)
            FF:UpdateHealthTextFontSize()
            FF:RequestStatusTextSettingsRefresh()
        end,
        desc = "Adjust the status text size on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateColorOverrides(rootCategory, {
        key = "StatusTextColor",
        entries = {
            { key = "StatusText", label = "Status text color" },
        },
        getColor = function()
            local color = SanitizeStatusTextColor(
                FF.db.profile.partyFrame.statusTextColor,
                FF.DEFAULT_SETTINGS.partyFrame.statusTextColor
            )
            return color.r, color.g, color.b, color.a
        end,
        setColor = function(_, r, g, b, a)
            FF.db.profile.partyFrame.statusTextColor = SanitizeStatusTextColor(
                { r = r, g = g, b = b, a = a },
                FF.DEFAULT_SETTINGS.partyFrame.statusTextColor
            )
            FF:UpdateStatusTextColor()
        end,
        getDefaultColor = function()
            local color = SanitizeStatusTextColor(
                FF.DEFAULT_SETTINGS.partyFrame.statusTextColor,
                { r = 1, g = 1, b = 1, a = 1 }
            )
            return color.r, color.g, color.b, color.a
        end,
        hasOpacity = true,
        minHeight = 36,
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Player Name",
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "PlayerNameAnchorTarget",
        name = "Anchor to",
        default = FF.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget,
        values = FF.STATUS_TEXT_ANCHOR_TARGETS,
        get = function()
            return SanitizeIncomingCastAnchorFrame(
                FF.db.profile.partyFrame.playerNameAnchorTarget,
                FF.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget
            )
        end,
        set = function(value)
            FF.db.profile.partyFrame.playerNameAnchorTarget = SanitizeIncomingCastAnchorFrame(
                value,
                FF.DEFAULT_SETTINGS.partyFrame.playerNameAnchorTarget
            )
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Choose whether player name is anchored to the party frame or health bar.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateDropdown(rootCategory, {
        key = "PlayerNameAnchorPoint",
        name = "Player name anchor",
        default = FF.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint,
        values = FF.STATUS_TEXT_ANCHOR_POINTS,
        get = function()
            return SanitizeStatusTextAnchorPoint(
                FF.db.profile.partyFrame.playerNameAnchorPoint,
                FF.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint
            )
        end,
        set = function(value)
            FF.db.profile.partyFrame.playerNameAnchorPoint = SanitizeStatusTextAnchorPoint(
                value,
                FF.DEFAULT_SETTINGS.partyFrame.playerNameAnchorPoint
            )
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Anchor point used for player name on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameOffsetX",
        name = "Player name X offset",
        default = FF.DEFAULT_SETTINGS.partyFrame.playerNameOffsetX,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.playerNameOffsetX
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.playerNameOffsetX
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.playerNameOffsetX = math.floor((value) + 0.5)
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Horizontal offset for player name anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameOffsetY",
        name = "Player name Y offset",
        default = FF.DEFAULT_SETTINGS.partyFrame.playerNameOffsetY,
        min = -40,
        max = 40,
        step = 1,
        formatter = function(value)
            return string.format("%ipx", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.playerNameOffsetY
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.playerNameOffsetY
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.playerNameOffsetY = math.floor((value) + 0.5)
            FF:UpdatePlayerNameAnchoring()
        end,
        desc = "Vertical offset for player name anchoring.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "PlayerNameFontSize",
        name = "Player name size",
        default = FF.DEFAULT_SETTINGS.partyFrame.playerNameFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.playerNameFontSize
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.playerNameFontSize
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.playerNameFontSize = math.floor((value) + 0.5)
            FF:UpdatePlayerNameFontSize()
        end,
        desc = "Adjust the player name text size on party frames.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateColorOverrides(rootCategory, {
        key = "PlayerNameColor",
        entries = {
            { key = "PlayerName", label = "Player name color" },
        },
        getColor = function()
            local color = SanitizeStatusTextColor(
                FF.db.profile.partyFrame.playerNameColor,
                FF.DEFAULT_SETTINGS.partyFrame.playerNameColor
            )
            return color.r, color.g, color.b, color.a
        end,
        setColor = function(_, r, g, b, a)
            FF.db.profile.partyFrame.playerNameColor = SanitizeStatusTextColor(
                { r = r, g = g, b = b, a = a },
                FF.DEFAULT_SETTINGS.partyFrame.playerNameColor
            )
            FF:UpdatePlayerNameColor()
        end,
        getDefaultColor = function()
            local color = SanitizeStatusTextColor(
                FF.DEFAULT_SETTINGS.partyFrame.playerNameColor,
                { r = 1, g = 1, b = 1, a = 1 }
            )
            return color.r, color.g, color.b, color.a
        end,
        hasOpacity = true,
        minHeight = 36,
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Role Icons",
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

    SettingsLib:CreateHeader(rootCategory, {
        name = "Buff/Debuffs",
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

    SettingsLib:CreateSlider(rootCategory, {
        key = "CountdownFontSize",
        name = "Buff/debuff countdown text size",
        default = FF.DEFAULT_SETTINGS.partyFrame.countdownFontSize,
        min = 8,
        max = 32,
        step = 1,
        formatter = function(value)
            return string.format("%ipt", math.floor((value) + 0.5))
        end,
        get = function()
            local value = FF.db.profile.partyFrame.countdownFontSize
            if value == nil then
                value = FF.DEFAULT_SETTINGS.partyFrame.countdownFontSize
            end
            return value
        end,
        set = function(value)
            FF.db.profile.partyFrame.countdownFontSize = math.floor((value) + 0.5)
            self:UpdateAuraCountdownFontSize()
        end,
        desc = "Adjust the buff/debuff countdown text size on party frames.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateHeader(rootCategory, {
        name = "Incoming Casts",
    })

    local trackIncomingCastsElement = SettingsLib:CreateCheckbox(rootCategory, {
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
        desc = "Track incoming enemy casts for party frame indicators.",
    })

    SettingsLib:CreateCheckbox(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
        parent = trackIncomingCastsElement,
        parentCheck = function()
            return FF.db.profile.partyFrame.trackIncomingCasts == true
        end,
    })

    local incomingCastBarDefaults = FF.DEFAULT_SETTINGS.incomingCastBar
    local incomingCastBarIconDefaults = incomingCastBarDefaults.icon or {}

    SettingsLib:CreateDropdown(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
    })

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

    local incomingCastIconCooldownTextElement = SettingsLib:CreateCheckbox(rootCategory, {
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

    SettingsLib:CreateSlider(rootCategory, {
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
        prefix = PARTY_FRAME_PREFIX,
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
