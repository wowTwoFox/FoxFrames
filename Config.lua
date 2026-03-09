local LSM = LibStub("LibSharedMedia-3.0", true) -- Optional, returns nil if not available

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
        healthBarTexture = FF.DEFAULT_TEXTURE,
        forceTopLeftAnchor = true,
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

    if LSM then
        -- Use LibSharedMedia if available and add additional textures
        local statusBarTextures = LSM:List("statusbar")
        for _, name in pairs(statusBarTextures) do
            local path = LSM:Fetch("statusbar", name)
            if not alreadyAddedPaths[path] then
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

function FF:SetupOptions()
    -- Build the options using LibEQOL
    local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
    local PREFIX = "FoxFrames_"
    local PARTY_FRAME_PREFIX = PREFIX .. "PartyFrame_"
    local rootCategory = SettingsLib:CreateRootCategory("Fox Frames")

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
        default = true,
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
        default = true,
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
        default = true,
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
        default = true,
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
        default = true,
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
        default = true,
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
        default = true,
        get = function() return FF.db.profile.partyFrame.showBuffCountdown end,
        set = function(value)
            FF.db.profile.partyFrame.showBuffCountdown = value
            self:ShowBuffCountdownIfNeeded()
        end,
        desc = "Toggle the buff countdown visibility on the frame.",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateCheckbox(rootCategory, {
        key = "ForceTopLeftAnchor",
        name = "Force Top Left Anchor",
        default = true,
        get = function() return FF.db.profile.partyFrame.forceTopLeftAnchor end,
        set = function(value)
            FF.db.profile.partyFrame.forceTopLeftAnchor = value
            FF:SetAlwaysUseTopLeftAnchor()
        end,
        desc = "Forces the top left anchor on the party frame. Disable this if you want anything other than left aligned party frames",
        prefix = PARTY_FRAME_PREFIX
    })

    SettingsLib:CreateText(
        rootCategory, 
        "You will need to re-center the party frames on the UI to set the new anchor point."
    )

    SettingsLib:CreateDropdown(rootCategory, {
        key = "ShowPlayerFrame",
        name = "Show Player Frame",
        default = FF.PLAYER_FRAME_SHOW_TYPES.Always,
        values = FF.PLAYER_FRAME_SHOW_TYPES,
        get = function()
            return FF.db.profile.playerFrame.showType or FF.PLAYER_FRAME_SHOW_TYPES.Always
        end,
        set = function(value)
            FF.db.profile.playerFrame.showType = value
            self:ShowPlayerFrameIfNeeded()
        end,
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
end
