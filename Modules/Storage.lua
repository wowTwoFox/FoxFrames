local addonName, addon = ...
local Utils = addon.Utils

local Object = {}
Object.__index = Object

local ACCEPTED_ROOT_KEYS = {
    char = true,
    realm = true,
    class = true,
    race = true,
    faction = true,
    factionrealm = true,
    locale = true,
    global = true,
    profile = true,
}

local function GetTableAtPath(root, pathParts)
    if type(root) ~= "table" then
        return nil
    end

    local current = root
    for _, key in ipairs(pathParts) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[key]
    end

    return current
end

local function GetParentTableAtPath(root, pathParts)
    if type(pathParts) ~= "table" then
        return nil, nil
    end

    local lastIndex = #pathParts
    local lastKey = pathParts[lastIndex]
    if lastIndex == 0 or type(lastKey) ~= "string" or lastKey == "" then
        return nil, nil
    end

    if lastIndex == 1 then
        return root, lastKey
    end

    local parentParts = {}
    for index = 1, lastIndex - 1 do
        parentParts[index] = pathParts[index]
    end

    return GetTableAtPath(root, parentParts), lastKey
end

local function LogInvalidPath(storage, path)
    local dbRoot = storage and storage.db

    Utils:Log("ERROR: INVALID_PATH", {
        path = path,
        defaults = dbRoot and dbRoot.defaults,
        storage = dbRoot,
    })
end

local function LogInvalidValueType(storage, path, value, currentValue, defaultValue)
    Utils:Log("ERROR: INVALID_VALUE_TYPE", {
        path = path,
        expectedType = type(currentValue ~= nil and currentValue or defaultValue),
        actualType = type(value),
        value = value,
        currentValue = currentValue,
        defaultValue = defaultValue,
        defaults = storage and storage.db and storage.db.defaults,
        storage = storage and storage.db,
    })
end

local function HasValidRootPath(storage, pathParts)
    local firstKey = type(pathParts) == "table" and pathParts[1] or nil
    local dbRoot = storage and storage.db
    local defaultsRoot = dbRoot and dbRoot.defaults

    if type(firstKey) ~= "string" or firstKey == "" or ACCEPTED_ROOT_KEYS[firstKey] ~= true then
        return false
    end

    local dbValue = type(dbRoot) == "table" and dbRoot[firstKey] or nil
    local defaultsValue = type(defaultsRoot) == "table" and defaultsRoot[firstKey] or nil
    return dbValue ~= nil or defaultsValue ~= nil
end

local function LogNormalizedPathRoot(storage, path, pathParts)
    if HasValidRootPath(storage, pathParts) then
        return
    end

    LogInvalidPath(storage, path)
end

function Object:New(dbName, defaults)
    assert(type(dbName) == "string" and dbName ~= "", "Storage: dbName must be a non-empty string")

    local instance = setmetatable({}, Object)
    local dbDefaults = type(defaults) == "table" and defaults or {}

    instance.dbName = dbName
    instance.db = LibStub("AceDB-3.0"):New(dbName, dbDefaults, true)
    instance.normalizedPathCache = {}
    Utils:Log("FF_INITIALIZED_DB", { db = instance.db, defaults = instance.db and instance.db.defaults })

    return instance
end

function Object:NormalizePath(path)
    if type(path) == "table" then
        LogNormalizedPathRoot(self, path, path)
        return path
    end

    if type(path) ~= "string" or path == "" then
        return nil
    end

    local cache = self.normalizedPathCache
    local cached = cache[path]
    if cached ~= nil then
        LogNormalizedPathRoot(self, path, cached)
        return cached
    end

    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end

    cache[path] = parts
    LogNormalizedPathRoot(self, path, parts)
    return parts
end

function Object:ValidatePathExists(path)
    local pathParts = self:NormalizePath(path)
    if not pathParts then
        LogInvalidPath(self, path)
        return false
    end

    if not HasValidRootPath(self, pathParts) then
        return false
    end

    local values = GetTableAtPath(self.db, pathParts)
    local defaults = GetTableAtPath(self.db and self.db.defaults, pathParts)
    if values ~= nil or defaults ~= nil then
        return true
    end

    LogInvalidPath(self, path)
    return false
end

function Object:GetValue(path)
    if not self:ValidatePathExists(path) then
        return nil
    end

    local pathParts = self:NormalizePath(path)
    return GetTableAtPath(self.db, pathParts)
end

function Object:SetValue(path, value)
    if not self:ValidatePathExists(path) then
        return false
    end

    local pathParts = self:NormalizePath(path)
    local currentValue = GetTableAtPath(self.db, pathParts)
    local defaultValue = GetTableAtPath(self.db and self.db.defaults, pathParts)
    local referenceValue = currentValue ~= nil and currentValue or defaultValue

    if referenceValue ~= nil and type(value) ~= type(referenceValue) then
        LogInvalidValueType(self, path, value, currentValue, defaultValue)
        return false
    end

    local parentTable, key = GetParentTableAtPath(self.db, pathParts)
    if type(parentTable) ~= "table" or key == nil then
        LogInvalidPath(self, path)
        return false
    end

    parentTable[key] = value
    return true
end

function Object:GetDefaultsTableAtPath(path)
    local pathParts = self:NormalizePath(path)
    if not pathParts then
        return {}
    end

    local defaults = GetTableAtPath(self.db and self.db.defaults, pathParts)
    if type(defaults) ~= "table" then
        defaults = {}
    end

    return defaults
end

function Object:GetValuesTableAtPath(path)
    local pathParts = self:NormalizePath(path)
    if not pathParts then
        return nil
    end

    return GetTableAtPath(self.db, pathParts)
end

function Object:GetTableAtPath(path)
    local pathParts = self:NormalizePath(path)
    if not pathParts then
        LogInvalidPath(self, path)
        return nil, nil
    end

    local values = GetTableAtPath(self.db, pathParts)
    local defaults = GetTableAtPath(self.db and self.db.defaults, pathParts)

    return values, defaults
end

if addon then
    addon.Storage = Object
end

-- Profile management methods
function Object:CopyProfile(fromProfile, isSilent)
    assert(type(fromProfile) == "string" and fromProfile ~= "", "Storage: fromProfile must be a non-empty string")

    local currentProfileName = self:GetCurrentProfile()
    if fromProfile == currentProfileName then
        return false
    end

    -- Avoid AceDB's silent mode resetting to defaults when the source profile doesn't exist.
    local profileStore = self.db.profiles
    if not (profileStore and rawget(profileStore, fromProfile) ~= nil) then
        return false
    end

    if self.db and self.db.CopyProfile then
        self.db:CopyProfile(fromProfile, isSilent == true)
    end
end

function Object:SetProfile(profileName)
    assert(type(profileName) == "string" and profileName ~= "", "Storage: profileName must be a non-empty string")
    if self.db and self.db.SetProfile then
        self.db:SetProfile(profileName)
    end
end

function Object:ResetProfile(noChildren, noCallbacks)
    if self.db and self.db.ResetProfile then
        self.db:ResetProfile(noChildren, noCallbacks)
    end
end

function Object:DeleteProfile(profileName)
    assert(type(profileName) == "string" and profileName ~= "", "Storage: profileName must be a non-empty string")

    -- Ensure the active profile table exists before AceDB resets/copies into it.
    local _ = self.db.profile

    if self.db and self.db.DeleteProfile then
        self.db:DeleteProfile(profileName)
    end
end

function Object:GetCurrentProfile()
    if self.db and self.db.GetCurrentProfile then
        return self.db:GetCurrentProfile()
    end
    return nil
end

function Object:HasProfile(profileName)
    assert(type(profileName) == "string" and profileName ~= "", "Storage: profileName must be a non-empty string")
    local profileStore = self.db and self.db.profiles
    return profileStore and rawget(profileStore, profileName) ~= nil
end
