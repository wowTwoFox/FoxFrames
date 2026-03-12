local addonName, addon = ...
local FF = FoxFrames

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
        forceTopLeftAnchor = true,
        trackIncomingCasts = false,

        -- Incoming cast ("targeted spell") indicator icon layout
        incomingCastIconCount = 3,
        incomingCastIconScale = 1,
        incomingCastIconSpacing = 0,
        incomingCastIconBorder = true,
        incomingCastIconSwipe = true,
        incomingCastIconCooldownText = true,
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

function FF:SetupOptions()
    -- Build the options using LibEQOL
    local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
    local PREFIX = "FoxFrames_"
    local PARTY_FRAME_PREFIX = PREFIX .. "PartyFrame_"
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
        key = "ForceTopLeftAnchor",
        name = "Force Top Left Anchor",
        default = FF.DEFAULT_SETTINGS.partyFrame.forceTopLeftAnchor,
        get = function() return FF.db.profile.partyFrame.forceTopLeftAnchor end,
        set = function(value)
            FF.db.profile.partyFrame.forceTopLeftAnchor = value
            FF:SetAlwaysUseTopLeftAnchor()
        end,
        desc = "By default, Blizzard's party frames will convert anchoring to top-left. This results in always top-left alignment of frames. Disabling this will allow you to use other anchor points such as center, bottom or right. You will need to re-anchor the party frames after changing this setting.",
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
            FF:SetIncomingCastIndicatorPreviewEnabled(not self._ffIncomingCastIndicatorPreviewEnabled)
        end,
        clickRequiresSet = true, -- button only active when checkbox is checked
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "IncomingCastIconCount",
        name = "Targeted spell icon count",
        default = FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconCount,
        min = 1,
        max = 5,
        step = 1,
        formatter = function(value)
            return string.format("%i", math.floor((value) + 0.5))
        end,
        get = function()
            return FF.db.profile.partyFrame.incomingCastIconCount
        end,
        set = function(value)
            FF.db.profile.partyFrame.incomingCastIconCount = value
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "How many targeted spell icons to show per party member.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "IncomingCastIconScale",
        name = "Icon scale",
        default = FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconScale,
        min = 0.5,
        max = 2,
        step = 0.10,
        formatter = function(value)
            return string.format("%d%%", math.floor((value * 100) + 0.5))
        end,
        get = function()
            local profile = FF.db.profile.partyFrame
            if profile.incomingCastIconScale ~= nil then
                return profile.incomingCastIconScale
            end

            -- Backward compatibility: convert legacy pixel size to a scale.
            local legacySize = profile.incomingCastIconSize
            if type(legacySize) ~= "number" then
                legacySize = tonumber(legacySize)
            end
            if type(legacySize) == "number" and legacySize > 0 then
                return legacySize / 22
            end

            return FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconScale
        end,
        set = function(value)
            local profile = FF.db.profile.partyFrame
            profile.incomingCastIconScale = value
            -- Prefer scale going forward.
            profile.incomingCastIconSize = nil
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Scales each targeted spell icon without distorting borders/overlays.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateSlider(rootCategory, {
        key = "IncomingCastIconSpacing",
        name = "Icon spacing",
        default = FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconSpacing,
        min = 0,
        max = 4,
        step = 1,
        formatter = function(value)
            return string.format("%i", math.floor((value) + 0.5))
        end,
        get = function()
            return FF.db.profile.partyFrame.incomingCastIconSpacing
        end,
        set = function(value)
            FF.db.profile.partyFrame.incomingCastIconSpacing = value
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Horizontal space (in pixels) between targeted spell icons.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "IncomingCastIconBorder",
        name = "Show icon border",
        default = FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconBorder,
        get = function()
            return FF.db.profile.partyFrame.incomingCastIconBorder
        end,
        set = function(value)
            FF.db.profile.partyFrame.incomingCastIconBorder = value
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the border around targeted spell icons.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "IncomingCastIconSwipe",
        name = "Show cooldown swipe",
        default = FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconSwipe,
        get = function()
            return FF.db.profile.partyFrame.incomingCastIconSwipe
        end,
        set = function(value)
            FF.db.profile.partyFrame.incomingCastIconSwipe = value
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the cooldown swipe overlay on targeted spell icons.",
        prefix = PARTY_FRAME_PREFIX,
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "IncomingCastIconCooldownText",
        name = "Show cooldown text",
        default = FF.DEFAULT_SETTINGS.partyFrame.incomingCastIconCooldownText,
        get = function()
            return FF.db.profile.partyFrame.incomingCastIconCooldownText
        end,
        set = function(value)
            FF.db.profile.partyFrame.incomingCastIconCooldownText = value
            FF:SetupIncomingCastIndicators()
            FF:UpdateIncomingCastIndicators()
        end,
        desc = "Toggle the cooldown countdown text on targeted spell icons.",
        prefix = PARTY_FRAME_PREFIX,
    })
end
