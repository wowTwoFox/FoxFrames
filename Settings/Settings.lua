local addonName, addon = ...
local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local ProfileSettings = addon.ProfileSettings
local SettingsCommon = addon.SettingsCommon
local FrameSettings = addon.FrameSettings

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

assert(ProfileSettings and ProfileSettings.CreateProfilesSettings, "FoxFrames: ProfileSettings module missing (load order issue)")

assert(SettingsCommon, "FoxFrames: SettingsCommon module missing (load order issue)")
assert(type(SettingsCommon.GetTextures) == "function", "FoxFrames: SettingsCommon missing GetTextures")
assert(type(SettingsCommon.AddFrameSettings) == "function", "FoxFrames: SettingsCommon missing AddFrameSettings")
assert(type(SettingsCommon.AddTextSettings) == "function", "FoxFrames: SettingsCommon missing AddTextSettings")
assert(type(SettingsCommon.CreateCheckbox) == "function", "FoxFrames: SettingsCommon missing CreateCheckbox")
assert(type(SettingsCommon.CreateDropdown) == "function", "FoxFrames: SettingsCommon missing CreateDropdown")
assert(type(SettingsCommon.CreateSlider) == "function", "FoxFrames: SettingsCommon missing CreateSlider")

assert(FrameSettings, "FoxFrames: FrameSettings module missing (load order issue)")
assert(type(FrameSettings.CreatePartySettings) == "function", "FoxFrames: FrameSettings missing CreatePartySettings")
assert(type(FrameSettings.CreateRaidSettings) == "function", "FoxFrames: FrameSettings missing CreateRaidSettings")

local PLAYER_FRAME_SHOW_TYPE_LABELS = {
    [DB.PLAYER_FRAME_SHOW_TYPES.ALWAYS] = "Always",
    [DB.PLAYER_FRAME_SHOW_TYPES.SOLO] = "Solo",
    [DB.PLAYER_FRAME_SHOW_TYPES.NEVER] = "Never",
}

function FF:OpenSettings()
    if not self._rootCategory then return end
    Settings.OpenToCategory(self._rootCategory:GetID())
end

function FF:OpenIncomingCastsSettings()
    if not self._incomingCastsCategory then return end
    Settings.OpenToCategory(self._incomingCastsCategory:GetID())
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

    SettingsCommon:CreateDropdown(rootCategory, {
        path = "profile.playerFrame.showType",
        name = "Show Player Frame",
        values = PLAYER_FRAME_SHOW_TYPE_LABELS,
        sanitize = function(value, fallback)
            return Utils:SanitizeOption(value, DB.PLAYER_FRAME_SHOW_TYPES) or fallback
        end,
        onChanged = function(_)
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

    local useCustomHealthBarTextureElement = SettingsCommon:CreateCheckbox(rootCategory, {
        path = "profile.partyFrame.healthBar.useCustomTexture",
        name = "Use Custom Health Bar Texture",
        onChanged = function(enabled)
            if enabled == true then
                -- Default to first available texture if enabling
                local texturePath = DB.storage:GetValueAtPath("profile.partyFrame.healthBar.texture")
                if (type(texturePath) ~= "string" or texturePath == "") and textures[1] and textures[1].path then
                    DB.storage:SetValue("profile.partyFrame.healthBar.texture", textures[1].path)
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
            local texturePath = DB.storage:GetValueAtPath("profile.partyFrame.healthBar.texture")
            if type(texturePath) == "string" and texturePath ~= "" then
                return texturePath
            end
            return textures[1].path
        end,
        set = function(value)
            if type(value) ~= "string" or value == "" then
                return
            end
            DB.storage:SetValue("profile.partyFrame.healthBar.texture", value)
            FF:UpdateFrames()
        end,
        height = 220, -- scrollable menu
        prefix = prefix,
        parent = useCustomHealthBarTextureElement,
        parentCheck = function()
            return DB.storage:GetBooleanAtPath("profile.partyFrame.healthBar.useCustomTexture") == true
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

    SettingsCommon:CreateCheckbox(rootCategory, {
        path = "profile.partyFrame.roleIcons.showTankRoleIcon",
        name = "Show Tank Role Icon",
        onChanged = function(_)
            FF:UpdateFrames()
        end,
        desc = "Toggle the Tank role icon visibility on the frame.",
        prefix = prefix,
    })

    SettingsCommon:CreateCheckbox(rootCategory, {
        path = "profile.partyFrame.roleIcons.showHealerRoleIcon",
        name = "Show Healer Role Icon",
        onChanged = function(_)
            FF:UpdateFrames()
        end,
        desc = "Toggle the Healer role icon visibility on the frame.",
        prefix = prefix,
    })

    SettingsCommon:CreateCheckbox(rootCategory, {
        path = "profile.partyFrame.roleIcons.showDPSRoleIcon",
        name = "Show DPS Role Icon",
        onChanged = function(_)
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
        prefix = SETTINGS_PREFIX,
    })

    CreateRoleIconsSettings(rootCategory, {
        prefix = SETTINGS_PREFIX,
    })

    ProfileSettings:CreateProfilesSettings(rootCategory, {
        onProfileActivated = function()
            self:SetupFrames()
        end,
        prefix = SETTINGS_PREFIX,
    })

    FrameSettings:CreatePartySettings(rootCategory, {
        prefix = PARTY_FRAME_PREFIX,
    })

    FrameSettings:CreateRaidSettings(rootCategory, {
        prefix = RAID_FRAME_PREFIX,
    })
end
