local addonName, addon = ...

assert(addon and addon.Utils and addon.DB and addon.GlobalsDB, "FoxFrames: addon table, Utils, DB, or GlobalsDB missing (load order issue)")

local Utils = addon.Utils
local DB = addon.DB
local GlobalsDB = addon.GlobalsDB

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local SETTINGS_PREFIX = "FoxFrames_"

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

local function WipeTable(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

function Object:CreateProfilesSettings(rootCategory, callbacks)
    if not rootCategory then
        return
    end

    assert(addon and type(addon.CreateSettingsButton) == "function", "FoxFrames: CreateSettingsButton missing (load order issue)")
    assert(addon and type(addon.RefreshSettingsLayout) == "function", "FoxFrames: RefreshSettingsLayout missing (load order issue)")
    assert(addon and type(addon.CreateSettingsFlow) == "function", "FoxFrames: CreateSettingsFlow missing (load order issue)")

    callbacks = callbacks or {}
    local onProfileActivated = callbacks.onProfileActivated

    local profilesPrefix = SETTINGS_PREFIX .. "Profiles_"
    local profilesCategory = rootCategory

    SettingsLib:CreateHeader(profilesCategory, {
        name = "Manage Profiles",
    })

    SettingsLib:CreateText(
        profilesCategory,
        "Profiles are automatically created and set based on your current Edit Mode layout.\n\nYou can reset the current layout's profile to defaults, or copy settings from another layout's profile into the current one."
    )

    local profileOrder = {}

    -- Selected profile should be local-only (not persisted).
    local selectedProfileName = nil

    local selectedProfileActionsFlow = nil

    local function GetSelectedProfileName()
        if type(selectedProfileName) == "string" and selectedProfileName ~= "" then
            return selectedProfileName
        end

        return DB.storage:GetCurrentProfile()
    end

    SettingsLib:CreateDropdown(profilesCategory, {
        key = "SelectedProfile",
        name = "Selected Profile",
        default = DB.storage:GetCurrentProfile(),
        get = function()
            return GetSelectedProfileName()
        end,
        set = function(value)
            if type(value) == "string" and value ~= "" then
                selectedProfileName = value
            else
                selectedProfileName = nil
            end

            if selectedProfileActionsFlow and type(selectedProfileActionsFlow.SetEnabled) == "function" then
                selectedProfileActionsFlow:SetEnabled(selectedProfileActionsFlow._ffEnabled ~= false)
            end

            addon:RefreshSettingsLayout()
        end,
        optionfunc = function()
            WipeTable(profileOrder)

            local options = {}
            local profiles = DB.db:GetProfiles()
            if type(profiles) ~= "table" then
                return options
            end

            table.sort(profiles)
            for i, profileName in ipairs(profiles) do
                if type(profileName) == "string" and profileName ~= "" then
                    options[profileName] = profileName
                    profileOrder[i] = profileName
                end
            end

            return options
        end,
        order = profileOrder,
        desc = "Select which profile to manage.",
        prefix = profilesPrefix,
    })

    addon:CreateSettingsRow(profilesCategory, {
        key = "SelectedProfileActions",
        label = "Actions",
        searchTags = "Actions",
        createContent = function(parent, existing)
            local flow = existing
            if not flow then
                flow = addon:CreateSettingsFlow(parent, {
                    direction = "horizontal",
                    fillParent = false,
                    autoSize = true,
                })

                flow._ffProfilesActionsKind = "profilesActions"
            end

            selectedProfileActionsFlow = flow

            flow:ResetFlow()

            flow:AddButton("Reset Current", {
            }, function()
                DB:ResetProfile()

                if type(onProfileActivated) == "function" then
                    onProfileActivated()
                end

                addon:RefreshSettingsLayout()
            end)

            flow:AddButton("Copy", {
                isEnabled = function()
                    local selectedName = GetSelectedProfileName()
                    local currentName = DB.storage:GetCurrentProfile()
                    return type(selectedName) == "string" and selectedName ~= "" and selectedName ~= currentName
                end,
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

                addon:RefreshSettingsLayout()
            end)

            return flow
        end
    })
end

local profiles = Object:New()

if addon then
    addon.SettingsProfiles = profiles
end
