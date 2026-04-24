local addonName, addon = ...
local Utils = addon.Utils

local wipe = wipe or function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    instance._units = {}
    return instance
end

local function GetUnitCache(self, unit)
    local cache = self._units[unit]
    if not cache then
        cache = {
            byAuraInstanceID = {},
            updatedAt = nil,
        }
        self._units[unit] = cache
    end
    return cache
end

local function AddAura(aura, cache, seen)
    if not aura then
        return
    end

    local auraInstanceID = aura.auraInstanceID
    if auraInstanceID then
        cache[auraInstanceID] = aura

        if seen[auraInstanceID] then
            Utils:Log("FF_AURA", aura)
        end

        seen[auraInstanceID] = true
    end
end


function Object:RefreshUnit(unit)
    if not unit then
        return
    end

    local cache = GetUnitCache(self, unit)
    cache.seenAuras = cache.seenAuras or {}
    wipe(cache.byAuraInstanceID)

    local index = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
        if not aura then break end
        AddAura(aura, cache.byAuraInstanceID, cache.seenAuras)
        index = index + 1
    end

    index = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HARMFUL")
        if not aura then break end
        AddAura(aura, cache.byAuraInstanceID, cache.seenAuras)
        index = index + 1
    end

    cache.updatedAt = GetTime()
end

function Object:RefreshFromFrames(frames)
    local units = {}
    for _, frame in ipairs(frames) do
        local unit = frame.unit
        if unit then
            units[unit] = true
        end
    end

    for unit in pairs(units) do
        self:RefreshUnit(unit)
    end
end

function Object:GetRemainingSeconds(unit, auraInstanceID)
    if not (unit and auraInstanceID) then
        return nil
    end

    local cache = self._units[unit]
    if not cache then
        return nil
    end

    local aura = cache.byAuraInstanceID[auraInstanceID]
    if not aura or not aura.expirationTime then
        return nil
    end

    local remaining = aura.expirationTime - GetTime()
    if remaining < 0 or remaining > 60 * 3 then
        return nil
    end

    return remaining
end

function Object:GetAura(unit, auraInstanceID)
    if not (unit and auraInstanceID) then
        return nil
    end

    local cache = self._units[unit]
    if not cache then
        return nil
    end

    return cache.byAuraInstanceID[auraInstanceID]
end

function Object:CanApplyAura(unit, auraInstanceID)
    local aura = self:GetAura(unit, auraInstanceID)
    return aura and aura.canApplyAura == true
end

local auras = Object:New()

if addon then
    addon.Auras = auras
end
