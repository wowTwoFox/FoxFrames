local addonName, addon = ...

local FF = FoxFrames
if not FF then
    return
end

local Utils = addon.Utils
local DB = addon.DB
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
    return DB:GetTrackIncomingCasts()
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

function FF:_IncomingCast_ExtractCast(casterUnit, isChannel, spellIdFromEvent)
    self:InitIncomingCasts()

    if not ShouldTrackIncomingCasts() then
        return nil
    end

    if not IsValidCasterUnit(casterUnit) then
        return nil
    end

    if not (UnitExists and UnitExists(casterUnit)) then
        return nil
    end

    if UnitCanAttack and not UnitCanAttack("player", casterUnit) then
        return nil
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
        return nil
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

    return cast
end

function FF:_IncomingCast_Store(casterUnit, cast)
    self:InitIncomingCasts()

    if not casterUnit or type(casterUnit) ~= "string" then
        return
    end

    if not cast or type(cast) ~= "table" then
        return
    end

    if cast.casterUnit == nil then
        cast.casterUnit = casterUnit
    end

    self._incomingCastsByCasterUnit[casterUnit] = cast
    self._incomingCastsPendingByCasterUnit[casterUnit] = nil
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

            local cast = self:_IncomingCast_ExtractCast(casterUnit, isChannel, spellIdFromEvent)
            if not cast then
                self._incomingCastsPendingByCasterUnit[casterUnit] = nil
                return
            end

            if self.SetIncomingCastIndicatorPreviewEnabled then
                self:SetIncomingCastIndicatorPreviewEnabled(false)
            else
                self._ffIncomingCastIndicatorPreviewEnabled = false
            end

            self:_IncomingCast_Store(casterUnit, cast)
        end)
        return
    end

    -- Fallback (should not happen in modern clients)
    local cast = self:_IncomingCast_ExtractCast(casterUnit, isChannel, spellIdFromEvent)
    if not cast then
        self._incomingCastsPendingByCasterUnit[casterUnit] = nil
        return
    end

    if self.SetIncomingCastIndicatorPreviewEnabled then
        self:SetIncomingCastIndicatorPreviewEnabled(false)
    else
        self._ffIncomingCastIndicatorPreviewEnabled = false
    end

    self:_IncomingCast_Store(casterUnit, cast)
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

local function GetSpellIconBaseSize()
    local spellIconMixin = addon and addon.SpellIconMixin
    return tonumber(spellIconMixin and spellIconMixin.SPELL_ICON_BASE_SIZE) or 22
end

local function GetIncomingCastIndicatorIconConfig(incomingCastBarProfile, incomingCastBarDefaults)
    local incomingCastBarIconProfile = incomingCastBarProfile and incomingCastBarProfile.icon
    local incomingCastBarIconDefaults = incomingCastBarDefaults.icon or {}

    local baseSize = GetSpellIconBaseSize()

    local scale = Utils:ClampNumber(incomingCastBarIconProfile and incomingCastBarIconProfile.scale, 0.5, 3, incomingCastBarIconDefaults.scale or 1)

    -- Keep the hash stable and avoid float jitter.
    scale = math.floor((scale * 100) + 0.5) / 100

    -- This is the size used for layout (wrapper frame). The visual icon frame is
    -- kept at baseSize and scaled, so borders/overlays scale proportionally.
    local size = baseSize * scale

    local spacing = Utils:ClampNumber(incomingCastBarIconProfile and incomingCastBarIconProfile.spacing, -10, 50, incomingCastBarIconDefaults.spacing or 0)
    spacing = math.floor(spacing + 0.5)

    local cooldownFontSize = Utils:ClampNumber(incomingCastBarIconProfile and incomingCastBarIconProfile.cooldownFontSize, 8, 32, incomingCastBarIconDefaults.cooldownFontSize or 10)
    cooldownFontSize = math.floor(cooldownFontSize + 0.5)

    local showBorder = incomingCastBarIconProfile and incomingCastBarIconProfile.showBorder
    if showBorder == nil then
        showBorder = incomingCastBarIconDefaults.showBorder ~= false
    else
        showBorder = showBorder == true
    end

    local showSwipe = incomingCastBarIconProfile and incomingCastBarIconProfile.showSwipe
    if showSwipe == nil then
        showSwipe = incomingCastBarIconDefaults.showSwipe ~= false
    else
        showSwipe = showSwipe == true
    end

    local showCooldownText = incomingCastBarIconProfile and incomingCastBarIconProfile.showCooldownText
    if showCooldownText == nil then
        showCooldownText = incomingCastBarIconDefaults.showCooldownText ~= false
    else
        showCooldownText = showCooldownText == true
    end

    return {
        baseSize = baseSize,
        scale = scale,
        size = size,
        spacing = spacing,
        cooldownFontSize = cooldownFontSize,
        showBorder = showBorder,
        showSwipe = showSwipe,
        showCooldownText = showCooldownText,
    }
end

local function GetIncomingCastIndicatorAnchorFrame(incomingCastBarProfile, incomingCastBarDefaults)
    local anchorFrame = incomingCastBarDefaults.anchorFrame or "HEALTHBAR"
    local configuredAnchorFrame = incomingCastBarProfile and incomingCastBarProfile.anchorFrame
    if configuredAnchorFrame == "HEALTHBAR" or configuredAnchorFrame == "FRAME" then
        anchorFrame = configuredAnchorFrame
    end
    return anchorFrame
end

local function GetIncomingCastIndicatorConfig()
    local incomingCastBarProfile = DB:GetIncomingCastBarDB()
    local incomingCastBarDefaults = DB.DEFAULT_SETTINGS.incomingCastBar
    local iconConfig = GetIncomingCastIndicatorIconConfig(incomingCastBarProfile, incomingCastBarDefaults)
    local anchorFrame = GetIncomingCastIndicatorAnchorFrame(incomingCastBarProfile, incomingCastBarDefaults)

    local count = Utils:ClampNumber(incomingCastBarProfile and incomingCastBarProfile.spellCount, 1, 6, incomingCastBarDefaults.spellCount or 3)
    count = math.floor(count + 0.5)

    local position = incomingCastBarDefaults.position or "BOTTOMLEFT"
    local configuredPosition = incomingCastBarProfile and incomingCastBarProfile.position
    if configuredPosition ~= nil then
        local value = configuredPosition
        if value == "UP" then
            value = "TOP"
        elseif value == "DOWN" then
            value = "BOTTOM"
        end

        if value == "TOPLEFT" or value == "TOP" or value == "TOPRIGHT"
            or value == "LEFT" or value == "CENTER" or value == "RIGHT"
            or value == "BOTTOMLEFT" or value == "BOTTOM" or value == "BOTTOMRIGHT" then
            position = value
        end
    end

    local growDirection = incomingCastBarDefaults.growthDirection or "RIGHT"
    do
        -- Backward-friendly behavior: if the user hasn't explicitly chosen a grow direction,
        -- keep the old behavior where right-anchored positions grow left.
        local explicitValue = incomingCastBarProfile and rawget(incomingCastBarProfile, "growthDirection")

        if explicitValue == nil then
            if position == "TOPRIGHT" or position == "RIGHT" or position == "BOTTOMRIGHT" then
                growDirection = "LEFT"
            else
                growDirection = incomingCastBarDefaults.growthDirection or "RIGHT"
            end
        else
            if explicitValue == "RIGHT" or explicitValue == "LEFT" or explicitValue == "DOWN" or explicitValue == "UP" then
                growDirection = explicitValue
            end
        end
    end

    local offsetX = incomingCastBarDefaults.offsetX or 2
    local configuredOffsetX = incomingCastBarProfile and incomingCastBarProfile.offsetX
    if configuredOffsetX ~= nil then
        offsetX = Utils:ClampNumber(configuredOffsetX, -200, 200, incomingCastBarDefaults.offsetX or 2)
    end
    offsetX = math.floor(offsetX + 0.5)

    local offsetY = incomingCastBarDefaults.offsetY or 2
    local configuredOffsetY = incomingCastBarProfile and incomingCastBarProfile.offsetY
    if configuredOffsetY ~= nil then
        offsetY = Utils:ClampNumber(configuredOffsetY, -200, 200, incomingCastBarDefaults.offsetY or 2)
    end
    offsetY = math.floor(offsetY + 0.5)

    local hash = string.format(
        "%d:%.2f:%d:%d:%d:%d:%d:%s:%s",
        count,
        iconConfig.scale,
        iconConfig.spacing,
        iconConfig.cooldownFontSize,
        iconConfig.showBorder and 1 or 0,
        iconConfig.showSwipe and 1 or 0,
        iconConfig.showCooldownText and 1 or 0,
        growDirection,
        anchorFrame
    )

    iconConfig.count = count
    iconConfig.growDirection = growDirection
    iconConfig.hash = hash

    return {
        icon = iconConfig,
        anchorFrame = anchorFrame,
        position = position,
        offsetX = offsetX,
        offsetY = offsetY,
    }
end

local function GetIncomingCastHostFrame(unitFrame, config)
    if not unitFrame then
        return nil
    end

    if config and config.anchorFrame == "FRAME" then
        return unitFrame
    end

    if unitFrame.healthBar then
        return unitFrame.healthBar
    end

    return unitFrame
end

local function GetInactiveIncomingCastHostFrame(unitFrame, activeHostFrame)
    if not unitFrame then
        return nil
    end

    if activeHostFrame == unitFrame then
        return unitFrame.healthBar
    end

    if activeHostFrame == unitFrame.healthBar then
        return unitFrame
    end

    return nil
end

local function SetSpellBarContainerEnabled(frame, enabled)
    if not frame then
        return
    end

    local container = frame.ffSpellBar
    if not container then
        return
    end

    if enabled then
        if container.Show then
            container:Show()
        end
        if container.SetAlpha then
            container:SetAlpha(1)
        end
        return
    end

    if container.Hide then
        container:Hide()
    end
end

local function EnsureSpellBarForFrame(frame, config)
    if not (frame and config) then
        return nil
    end

    if frame.ffSpellBarCreationFailed then
        return nil
    end

    local iconConfig = type(config.icon) == "table" and config.icon or config
    if type(iconConfig) ~= "table" then
        return nil
    end

    local container = frame.ffSpellBar
    if not container then
        local CreateSpellBarFrame = addon.CreateSpellBarFrame
        if not CreateSpellBarFrame then return end
        container = CreateSpellBarFrame(frame)

        if not container then
            frame.ffSpellBarCreationFailed = true
            Utils:Log("Failed to create frame for incoming cast indicators.")
            return nil
        end

        frame.ffSpellBar = container
    end

    SetSpellBarContainerEnabled(frame, true)

    if container.ApplyContainerPosition then
        container:ApplyContainerPosition(frame, config)
    end

    local desiredHash = iconConfig.hash or config.hash
    if container._ffSpellBarConfigHash ~= desiredHash and container.ApplyIconContainerLayout then
        container:ApplyIconContainerLayout(iconConfig)
    end

    return container
end

function FF:SetupIncomingCastIndicators()
    if InCombatLockdown and InCombatLockdown() then
        self._ffIncomingCastIndicatorsPendingSetup = true
        if self.RegisterEvent then
            pcall(self.RegisterEvent, self, "PLAYER_REGEN_ENABLED")
        end
        return
    end

    local config = GetIncomingCastIndicatorConfig()

    local frames = self:GetFrames()
    for _, frame in ipairs(frames) do
        local hostFrame = GetIncomingCastHostFrame(frame, config)
        local container = EnsureSpellBarForFrame(hostFrame, config)
        if container then
            local inactiveHostFrame = GetInactiveIncomingCastHostFrame(frame, hostFrame)
            SetSpellBarContainerEnabled(inactiveHostFrame, false)
        end
    end
end

function FF:PLAYER_REGEN_ENABLED()
    if not self._ffIncomingCastIndicatorsPendingSetup then
        return
    end

    self._ffIncomingCastIndicatorsPendingSetup = false
    if self.UnregisterEvent then
        pcall(self.UnregisterEvent, self, "PLAYER_REGEN_ENABLED")
    end

    if self.SetupIncomingCastIndicators then
        self:SetupIncomingCastIndicators()
    end
    if self.UpdateIncomingCastIndicators then
        self:UpdateIncomingCastIndicators()
    end
end

function FF:UpdateIncomingCastIndicators()
    if not (CompactPartyFrame and CompactPartyFrame.memberUnitFrames) then
        return
    end

    if not self.GetIncomingCasts then return end

    local config = GetIncomingCastIndicatorConfig()
    local frames = self:GetFrames()
    local castList = {}
    local inCombat = InCombatLockdown and InCombatLockdown()

    local castsByCaster = self:GetIncomingCasts(GetTime())

    for casterUnit, cast in pairs(castsByCaster or {}) do
        if cast then
            table.insert(castList, {
                casterUnit = casterUnit,
                cast = cast,
            })
        end
    end

    table.sort(castList, function(a, b)
        local aStart = (a.cast and a.cast.startTime) or 0
        local bStart = (b.cast and b.cast.startTime) or 0
        if aStart == bStart then
            return (a.casterUnit or "") < (b.casterUnit or "")
        end
        return aStart > bStart
    end)

    for _, frame in ipairs(frames) do
        if frame and frame.unit then
            local hostFrame = GetIncomingCastHostFrame(frame, config)
            local container = hostFrame and hostFrame.ffSpellBar
            local targetUnit = frame.unit

            if not inCombat then
                container = EnsureSpellBarForFrame(hostFrame, config) or container
            end

            if container and container.UpdateSpellBarForFrame then
                local inactiveHostFrame = GetInactiveIncomingCastHostFrame(frame, hostFrame)
                SetSpellBarContainerEnabled(inactiveHostFrame, false)
                container:UpdateSpellBarForFrame(targetUnit, castList, config)
            end
        end
    end
end
