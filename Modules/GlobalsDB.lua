local addonName, addon = ...

assert(addon and addon.Utils, "FoxFrames: addon table or Utils missing (load order issue)")

local Utils = addon.Utils

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

local defaultSettings = {}

function Object:GetDBProfile()
    local dbRef = self.db
    local profile = dbRef and dbRef.profile
    if type(profile) ~= "table" then
        return nil
    end
    return profile
end

function Object:InitializeDB()
    local defaults = {
        profile = defaultSettings,
    }

    self.db = LibStub("AceDB-3.0"):New("FoxFramesGlobalsDB", defaults, true)

    -- Ensure we never persist a selected profile (local-only UI state).
    local profile = self:GetDBProfile()
    if profile and rawget(profile, "profileName") ~= nil then
        profile.profileName = nil
    end
end

local db = Object:New()
db.DEFAULT_SETTINGS = defaultSettings

if addon then
    addon.GlobalsDB = db
end
