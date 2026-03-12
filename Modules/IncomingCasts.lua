local addonName, addon = ...

local FF = FoxFrames
if not FF then
    return
end

local Utils = addon and addon.Utils
function FF:RegisterIncomingCastUnitEvents()
    -- Midnight+ safe approach:
    -- - Track enemy casts by caster *unit token* (nameplateX)
    -- - Avoid using combat log
    -- - Avoid branching on UnitIsUnit() return (it can be a secret boolean)
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    -- Empower spells (common in modern content)
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")

    -- Target changes mid-cast and nameplate lifecycle
    self:RegisterEvent("UNIT_TARGET")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")

    if self.ScanAllEnemyCasts then
        self:ScanAllEnemyCasts()
    end
end

local INCOMING_CAST_MESSAGE = "FOXFRAMES_INCOMING_CASTS_UPDATED"

local CAST_PROCESS_DELAY = 0.2
local MAX_NAMEPLATES = 40

local function wipeTable(tbl)
    if not tbl then
        return
    end
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

local function IsValidCasterUnit(unit)
    if not unit or type(unit) ~= "string" then
        return false
    end
    return unit:match("^nameplate%d+$") ~= nil
end

local function ShouldTrackIncomingCasts()
    return FF.db.profile.partyFrame.trackIncomingCasts
end

function FF:InitIncomingCasts()
    if self._incomingCastsInitialized then
        return
    end

    self._incomingCastsInitialized = true
    -- Keyed by caster unit token ("nameplate7"). Avoid GUID and castGUID keys (can be secret).
    self._incomingCastsByCasterUnit = self._incomingCastsByCasterUnit or {}
    -- Used to debounce delayed processing per caster.
    self._incomingCastsPendingByCasterUnit = self._incomingCastsPendingByCasterUnit or {}
end

function FF:ClearIncomingCasts()
    self:InitIncomingCasts()
    wipeTable(self._incomingCastsByCasterUnit)
    wipeTable(self._incomingCastsPendingByCasterUnit)
end

function FF:RebuildIncomingCastUnitMap()
    -- Kept for compatibility with Core.lua call-sites.
    self:InitIncomingCasts()

    if not ShouldTrackIncomingCasts() then
        self:ClearIncomingCasts()
    end
end

function FF:PruneIncomingCasts(now)
    self:InitIncomingCasts()

    now = now or GetTime()
    for casterUnit, cast in pairs(self._incomingCastsByCasterUnit) do
        local expiresAt = cast and cast.expiresAt
        if expiresAt and expiresAt <= now then
            self._incomingCastsByCasterUnit[casterUnit] = nil
        end
    end
end

function FF:_IncomingCast_Store(casterUnit, isChannel, spellIdFromEvent)
    self:InitIncomingCasts()

    if not ShouldTrackIncomingCasts() then
        return
    end

    if not IsValidCasterUnit(casterUnit) then
        return
    end

    if not (UnitExists and UnitExists(casterUnit)) then
        return
    end

    if UnitCanAttack and not UnitCanAttack("player", casterUnit) then
        return
    end

    local name, _, icon, _, _, _, _, notInterruptible, spellId
    if isChannel and UnitChannelInfo then
        name, _, icon, _, _, _, notInterruptible, spellId = UnitChannelInfo(casterUnit)
    elseif UnitCastingInfo then
        name, _, icon, _, _, _, _, notInterruptible, spellId = UnitCastingInfo(casterUnit)
    end

    if not name then
        Utils:Log("Failed to get cast info for caster unit", {
            casterUnit = casterUnit,
            isChannel = isChannel,
            spellIdFromEvent = spellIdFromEvent,
        })
        return
    end

    spellId = spellIdFromEvent or spellId

    local now = GetTime()
    self:PruneIncomingCasts(now)

    local cast = {
        casterUnit = casterUnit,
        spellId = spellId,
        spellName = name,
        icon = icon,
        startTime = now,
        duration = nil,
        notInterruptible = notInterruptible,
        isChannel = isChannel,
    }

    -- Prefer duration objects to avoid arithmetic on potentially restricted cast-time values.
    if isChannel and UnitChannelDuration then
        local ok, value = pcall(UnitChannelDuration, casterUnit)
        if ok then
            cast.duration = value
        end
    end

    if cast.duration == nil and UnitCastingDuration then
        local ok, value = pcall(UnitCastingDuration, casterUnit)
        if ok then
            cast.duration = value
        end
    end

    -- Midnight+ can treat cast-time values as "secret numbers".
    -- Do not compare or do arithmetic that later participates in comparisons.
    -- We rely on UNIT_SPELLCAST_* stop events for correctness; this is a simple safety TTL.
    cast.endTime = nil
    cast.expiresAt = now + 240

    self._incomingCastsByCasterUnit[casterUnit] = cast
    self._incomingCastsPendingByCasterUnit[casterUnit] = nil
    self._ffIncomingCastIndicatorPreviewEnabled = false
    self:SendMessage(INCOMING_CAST_MESSAGE, casterUnit, cast)
end

function FF:_IncomingCast_ProcessCast(casterUnit, isChannel, spellIdFromEvent)
    self:InitIncomingCasts()
    if not ShouldTrackIncomingCasts() then
        return
    end

    if not IsValidCasterUnit(casterUnit) then
        return
    end

    if not (UnitExists and UnitExists(casterUnit)) then
        return
    end

    if UnitCanAttack and not UnitCanAttack("player", casterUnit) then
        return
    end

    if self._incomingCastsPendingByCasterUnit[casterUnit] then
        return
    end

    self._incomingCastsPendingByCasterUnit[casterUnit] = true

    if C_Timer and C_Timer.After then
        C_Timer.After(CAST_PROCESS_DELAY, function()
            -- Validate cast is still active after delay.
            if isChannel and UnitChannelInfo then
                if not UnitChannelInfo(casterUnit) then
                    self._incomingCastsPendingByCasterUnit[casterUnit] = nil
                    return
                end
            elseif UnitCastingInfo then
                if not UnitCastingInfo(casterUnit) then
                    self._incomingCastsPendingByCasterUnit[casterUnit] = nil
                    return
                end
            end

            self:_IncomingCast_Store(casterUnit, isChannel, spellIdFromEvent)
        end)
        return
    end

    -- Fallback (should not happen in modern clients)
    self:_IncomingCast_Store(casterUnit, isChannel, spellIdFromEvent)
end

function FF:_IncomingCast_Stop(casterUnit)
    self:InitIncomingCasts()

    if not casterUnit then
        return
    end

    if not IsValidCasterUnit(casterUnit) then
        return
    end

    if self._incomingCastsByCasterUnit and self._incomingCastsByCasterUnit[casterUnit] then
        self._incomingCastsByCasterUnit[casterUnit] = nil
        self._incomingCastsPendingByCasterUnit[casterUnit] = nil
        self:SendMessage(INCOMING_CAST_MESSAGE, casterUnit)
    end
end

function FF:ScanAllEnemyCasts()
    self:InitIncomingCasts()

    if not ShouldTrackIncomingCasts() then
        return
    end

    for i = 1, MAX_NAMEPLATES do
        local unit = "nameplate" .. i
        if UnitExists and UnitExists(unit) then
            local castName = UnitCastingInfo and UnitCastingInfo(unit)
            if castName then
                self:_IncomingCast_ProcessCast(unit, false)
            else
                local channelName = UnitChannelInfo and UnitChannelInfo(unit)
                if channelName then
                    self:_IncomingCast_ProcessCast(unit, true)
                end
            end
        end
    end
end

function FF:GetIncomingCasts(now)
    self:InitIncomingCasts()
    self:PruneIncomingCasts(now)
    return self._incomingCastsByCasterUnit
end

function FF:GetIncomingCastByCasterUnit(casterUnit, now)
    self:InitIncomingCasts()
    self:PruneIncomingCasts(now)
    if not casterUnit then
        return nil
    end
    return self._incomingCastsByCasterUnit and self._incomingCastsByCasterUnit[casterUnit]
end

-- ============================================================
-- Events
-- ============================================================

function FF:UNIT_SPELLCAST_START(event, unit, castGUID, spellId)
    Utils:Log("UNIT_SPELLCAST_START", { 
        unit = unit,
        castGUID = castGUID,
        spellId = spellId
    })
    return self:_IncomingCast_ProcessCast(unit, false, spellId)
end

function FF:UNIT_SPELLCAST_CHANNEL_START(event, unit, castGUID, spellId)
    return self:_IncomingCast_ProcessCast(unit, true, spellId)
end

function FF:UNIT_SPELLCAST_EMPOWER_START(event, unit, castGUID, spellId)
    return self:_IncomingCast_ProcessCast(unit, false, spellId)
end

function FF:UNIT_SPELLCAST_STOP(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:UNIT_SPELLCAST_FAILED(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:UNIT_SPELLCAST_INTERRUPTED(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:UNIT_SPELLCAST_SUCCEEDED(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:UNIT_SPELLCAST_EMPOWER_STOP(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:UNIT_TARGET(event, unit)
    if not IsValidCasterUnit(unit) then
        return
    end
    local cast = self._incomingCastsByCasterUnit and self._incomingCastsByCasterUnit[unit]
    if cast then
        -- Target can change mid-cast; consumers should re-evaluate UnitIsUnit(caster.."target", unit)
        -- using SetAlphaFromBoolean (do not branch on it).
        self:SendMessage(INCOMING_CAST_MESSAGE, unit, cast)
    end
end

function FF:NAME_PLATE_UNIT_ADDED(event, unit)
    if not IsValidCasterUnit(unit) then
        return
    end

    local castName = UnitCastingInfo and UnitCastingInfo(unit)
    if castName then
        return self:_IncomingCast_ProcessCast(unit, false)
    end

    local channelName = UnitChannelInfo and UnitChannelInfo(unit)
    if channelName then
        return self:_IncomingCast_ProcessCast(unit, true)
    end
end

function FF:NAME_PLATE_UNIT_REMOVED(event, unit)
    return self:_IncomingCast_Stop(unit)
end

function FF:PLAYER_TARGET_CHANGED()
    return self:ScanAllEnemyCasts()
end

function FF:PLAYER_FOCUS_CHANGED()
    return self:ScanAllEnemyCasts()
end
