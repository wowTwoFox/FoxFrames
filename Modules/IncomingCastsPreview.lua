local addonName, addon = ...

local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB
local Blizzard = addon.Blizzard

-- Preview-specific constants
local INCOMING_CAST_PREVIEW_STREAM_INTERVAL_SECONDS = 10
local INCOMING_CAST_PREVIEW_COOLDOWN_DURATION_SECONDS = 6
local INCOMING_CAST_PREVIEW_CASTER_UNIT_BASE = 100

local INCOMING_CAST_PREVIEW_SPELLS = {
    {
        spellID = 116,
        name = "Frostbolt",
        texture = "Interface\\Icons\\Spell_Frost_FrostBolt02",
        duration = 2.6,
    },
    {
        spellID = 133,
        name = "Fireball",
        texture = "Interface\\Icons\\Spell_Fire_FlameBolt",
        duration = 6.9,
    },
    {
        spellID = 686,
        name = "Shadow Bolt",
        texture = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
        duration = 3.4,
    },
    {
        spellID = 30451,
        name = "Arcane Blast",
        texture = "Interface\\Icons\\Spell_Arcane_Arcane02",
        duration = 8.7,
    },
    {
        spellID = 11366,
        name = "Pyroblast",
        texture = "Interface\\Icons\\Spell_Fire_Fireball02",
        duration = 10.0,
    },
    {
        spellID = 403,
        name = "Lightning Bolt",
        texture = "Interface\\Icons\\Spell_Nature_Lightning",
        duration = 2.9,
    },
    {
        spellID = 51505,
        name = "Lava Burst",
        texture = "Interface\\Icons\\Spell_Shaman_LavaBurst",
        duration = 7.6,
    },
    {
        spellID = 5176,
        name = "Wrath",
        texture = "Interface\\Icons\\Spell_Nature_AbolishMagic",
        duration = 8.2,
    },
    {
        spellID = 8092,
        name = "Mind Blast",
        texture = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
        duration = 5.7,
    },
    {
        spellID = 585,
        name = "Smite",
        texture = "Interface\\Icons\\Spell_Holy_HolySmite",
        duration = 9.4,
    },
    {
        spellID = 19434,
        name = "Aimed Shot",
        texture = "Interface\\Icons\\INV_Spear_07",
        duration = 2.2,
    },
    {
        spellID = 29722,
        name = "Incinerate",
        texture = "Interface\\Icons\\Spell_Fire_Fire",
        duration = 6.4,
    },
}

local function GetRandomIncomingCastPreviewSpells(count)
    if count < 1 then
        return {}
    end

    local spellPool = INCOMING_CAST_PREVIEW_SPELLS
    local poolSize = #spellPool

    if poolSize < 1 then
        return {}
    end

    count = Utils:ClampInteger(count, 1, poolSize, poolSize)

    local availableSpells = {}
    for index, previewSpell in ipairs(spellPool) do
        availableSpells[index] = previewSpell
    end

    local result = {}
    for i = 1, count do
        local randomIndex = math.random(1, #availableSpells)
        result[i] = availableSpells[randomIndex]
        table.remove(availableSpells, randomIndex)
    end

    return result
end

local function CancelIncomingCastPreviewTimer(timer)
    if timer and timer.Cancel then
        pcall(timer.Cancel, timer)
    end
end

local function ScheduleIncomingCastPreviewStop(addonRef, casterUnit, duration)
    if not (addonRef and type(casterUnit) == "string" and casterUnit ~= "") then
        return
    end
    if not (C_Timer and C_Timer.NewTimer) then
        return
    end

    addonRef._ffIncomingCastIndicatorPreviewStopTimers = addonRef._ffIncomingCastIndicatorPreviewStopTimers or {}

    local existingTimer = addonRef._ffIncomingCastIndicatorPreviewStopTimers[casterUnit]
    if existingTimer then
        CancelIncomingCastPreviewTimer(existingTimer)
    end

    local stopDelay = tonumber(duration) or INCOMING_CAST_PREVIEW_COOLDOWN_DURATION_SECONDS
    if stopDelay < 0 then
        stopDelay = 0
    end

    local timer = C_Timer.NewTimer(stopDelay, function()
        local stopTimers = addonRef._ffIncomingCastIndicatorPreviewStopTimers
        if stopTimers then
            stopTimers[casterUnit] = nil
        end

        local activeCasterUnits = addonRef._ffIncomingCastIndicatorPreviewActiveCasterUnits
        if activeCasterUnits then
            activeCasterUnits[casterUnit] = nil
        end

        if addonRef._IncomingCast_Stop then
            addonRef:_IncomingCast_Stop(casterUnit)
        end
    end)

    addonRef._ffIncomingCastIndicatorPreviewStopTimers[casterUnit] = timer
end

function FF:ToggleIncomingCastIndicatorPreview()
    local enabled = not self._ffIncomingCastIndicatorPreviewEnabled
    self:SetIncomingCastIndicatorPreviewEnabled(enabled)
end

function FF:StartIncomingCastIndicatorPreviewStream()
    self:StopIncomingCastIndicatorPreviewStream()

    -- Get target units (party frames or fallback to player)
    local GetCurrentTargetUnits = function()
        local units = {}
        local frames = Blizzard:GetFrames()
        if frames then
            for _, frame in ipairs(frames) do
                if frame and type(frame.unit) == "string" and frame.unit ~= "" then
                    units[#units + 1] = frame.unit
                end
            end
        end
        if #units == 0 then
            units[1] = "player"
        end
        return units
    end

    if not (C_Timer and C_Timer.NewTicker) then
        return
    end

    local addonRef = self
    local nextCasterUnitOffset = 0
    addonRef._ffIncomingCastIndicatorPreviewActiveCasterUnits = {}
    addonRef._ffIncomingCastIndicatorPreviewStopTimers = {}

    local function EmitPreviewBurst()
        if not addonRef._IncomingCast_Store then
            return
        end

        -- Refresh target units on each burst to catch newly visible frames
        local currentTargets = GetCurrentTargetUnits()
        if #currentTargets == 0 then
            return
        end

        local now = GetTime()

        -- Read desired spell display count from settings
        local desiredCount = DB:GetIncomingCastIndicatorCount()

        -- For each target unit, emit N spells (with slight variance)
        for _, targetUnit in ipairs(currentTargets) do
            -- Vary the count slightly: add/subtract 0-1 spell per target
            local spellCount = desiredCount + math.random(-1, 1)
            spellCount = math.max(1, spellCount)  -- At least 1 spell per target

            -- Get random spells for this target
            local randomSpells = GetRandomIncomingCastPreviewSpells(spellCount)

            for _, previewSpell in ipairs(randomSpells) do
                if previewSpell then
                    -- Generate unique caster unit
                    nextCasterUnitOffset = nextCasterUnitOffset + 1
                    local casterUnit = "nameplate" .. (INCOMING_CAST_PREVIEW_CASTER_UNIT_BASE + nextCasterUnitOffset)

                    local duration = tonumber(previewSpell.duration) or INCOMING_CAST_PREVIEW_COOLDOWN_DURATION_SECONDS
                    local cast = {
                        casterUnit = casterUnit,
                        target = targetUnit,
                        spellId = previewSpell.spellID,
                        spellName = previewSpell.name or "Preview",
                        icon = previewSpell.texture,
                        startTime = now,
                        duration = duration,
                        notInterruptible = false,
                        isChannel = false,
                        endTime = nil,
                        expiresAt = now + duration + 1,
                    }

                    addonRef._ffIncomingCastIndicatorPreviewActiveCasterUnits[casterUnit] = true
                    addonRef:_IncomingCast_Store(casterUnit, cast)
                    ScheduleIncomingCastPreviewStop(addonRef, casterUnit, duration)
                end
            end
        end
    end

    -- Emit initial burst immediately
    EmitPreviewBurst()

    -- Set up ticker for recurring bursts
    self._ffIncomingCastIndicatorPreviewStreamTicker = C_Timer.NewTicker(INCOMING_CAST_PREVIEW_STREAM_INTERVAL_SECONDS, function()
        if not (addonRef and addonRef._ffIncomingCastIndicatorPreviewEnabled == true) then
            if addonRef and addonRef.StopIncomingCastIndicatorPreviewStream then
                addonRef:StopIncomingCastIndicatorPreviewStream()
            end
            return
        end

        EmitPreviewBurst()
    end)
end

function FF:StopIncomingCastIndicatorPreviewStream()
    if self._ffIncomingCastIndicatorPreviewStreamTicker and self._ffIncomingCastIndicatorPreviewStreamTicker.Cancel then
        pcall(self._ffIncomingCastIndicatorPreviewStreamTicker.Cancel, self._ffIncomingCastIndicatorPreviewStreamTicker)
    end
    self._ffIncomingCastIndicatorPreviewStreamTicker = nil

    local stopTimers = self._ffIncomingCastIndicatorPreviewStopTimers
    if stopTimers then
        for casterUnit, timer in pairs(stopTimers) do
            CancelIncomingCastPreviewTimer(timer)
            stopTimers[casterUnit] = nil
        end
    end

    local activeCasterUnits = self._ffIncomingCastIndicatorPreviewActiveCasterUnits
    if activeCasterUnits and self._IncomingCast_Stop then
        for casterUnit in pairs(activeCasterUnits) do
            self:_IncomingCast_Stop(casterUnit)
        end
    end

    self._ffIncomingCastIndicatorPreviewActiveCasterUnits = nil
    self._ffIncomingCastIndicatorPreviewStopTimers = nil
end

function FF:SetIncomingCastIndicatorPreviewEnabled(enabled)
    local wantEnabled = enabled == true
    if self._ffIncomingCastIndicatorPreviewEnabled == wantEnabled then
        return
    end

    self._ffIncomingCastIndicatorPreviewEnabled = wantEnabled

    if DB and DB.SetIncomingCastsPreviewEnabled then
        DB:SetIncomingCastsPreviewEnabled(wantEnabled)
    end

    if wantEnabled then
        self:StartIncomingCastIndicatorPreviewStream()
    else
        self:StopIncomingCastIndicatorPreviewStream()
    end

    if wantEnabled and self.SetupIncomingCastIndicators then
        self:SetupIncomingCastIndicators()
    end
    if self.UpdateIncomingCastIndicators then
        self:UpdateIncomingCastIndicators()
    end
end

