local addonName, addon = ...

assert(addon and addon.Utils and addon.DB, "FoxFrames: addon table, Utils, or DB missing (load order issue)")

local Utils = addon.Utils
local DB = addon.DB

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:CreateProfilesSettings(rootCategory, options)
    if not rootCategory then
        return
    end

    local SettingsCommon = addon and addon.SettingsCommon
    assert(SettingsCommon and type(SettingsCommon.CreateDropdown) == "function", "FoxFrames: SettingsCommon missing CreateDropdown (load order issue)")
    assert(SettingsCommon and type(SettingsCommon.RefreshSettingsLayout) == "function", "FoxFrames: SettingsCommon missing RefreshSettingsLayout (load order issue)")
    assert(addon and type(addon.CreateSettingsFlow) == "function", "FoxFrames: CreateSettingsFlow missing (load order issue)")

    options = options or {}
    local onProfileActivated = options.onProfileActivated

    local settingsPrefix = SETTINGS_PREFIX
    if type(options.prefix) == "string" and options.prefix ~= "" then
        settingsPrefix = options.prefix
    end

    local profilesPrefix = settingsPrefix .. "Profiles_"
    local profilesCategory = rootCategory

    SettingsLib:CreateHeader(profilesCategory, {
        name = "Manage Profiles",
    })

    SettingsLib:CreateText(
        profilesCategory,
        "Profiles are automatically created and set based on your current Edit Mode layout.\n\nBut you can copy settings from another layout's profile into the current one."
    )

    local profileOrder = {}
    local dropdownOptions = {}
    local profiles = DB.db:GetProfiles()
    if type(profiles) ~= "table" then
        return dropdownOptions
    end

    table.sort(profiles)
    for i, profileName in ipairs(profiles) do
        if type(profileName) == "string" and profileName ~= "" then
            dropdownOptions[profileName] = profileName
            profileOrder[i] = profileName
        end
    end

    -- Selected profile should be local-only (not persisted).
    local selectedProfileName = nil

    local function GetSelectedProfileName()
        if type(selectedProfileName) == "string" and selectedProfileName ~= "" then
            return selectedProfileName
        end

        return DB.storage:GetCurrentProfile()
    end

    local selectProfile = SettingsLib:CreateDropdown(profilesCategory, {
        key = "SelectedProfile",
        name = "Selected Profile",
        default = DB.storage:GetCurrentProfile(),
        get = function()
            return GetSelectedProfileName()
        end,
        set = function(value)
            selectedProfileName = Utils:SanitizeString(value)
            SettingsCommon:RefreshSettingsLayout()
        end,
        optionfunc = function()
            return dropdownOptions
        end,
        order = profileOrder,
        desc = "Select which profile to manage.",
        prefix = profilesPrefix,
    })

    local function IsRowEnabled()
        local selectedName = GetSelectedProfileName()
        return selectedName ~= DB.storage:GetCurrentProfile()
    end

    local row = addon:CreateSettingsRow(profilesCategory, {
        key = "SelectedProfileActions",
        name = "Actions",
        label = "Actions",
        searchTags = "Actions",
        parent = selectProfile,
        tooltip = "Copy settings from the selected profile into the current profile.",
        isEnabled = IsRowEnabled,
        createContent = function(parent)
            local flow = addon:CreateSettingsFlow(parent, {
                direction = "horizontal",
                fillParent = false,
                autoSize = true,
            })

            flow:AddButton("Copy", {
                isEnabled = IsRowEnabled,
            }, function()
                local selectedName = GetSelectedProfileName()
                local currentName = DB.storage:GetCurrentProfile()
                if type(selectedName) ~= "string" or selectedName == "" or selectedName == currentName then
                    return
                end

                DB:CopyProfile(selectedName, {
                    silent = true,
                })

                if type(onProfileActivated) == "function" then
                    onProfileActivated()
                end

                SettingsCommon:RefreshSettingsLayout()
            end)

            return flow
        end
    })

    Utils:Log("FF_ROW", row)
end

local profiles = Object:New()

if addon then
    addon.ProfileSettings = profiles
end
