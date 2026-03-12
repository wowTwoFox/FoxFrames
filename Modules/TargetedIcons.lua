local addonName, addon = ...

local FF = FoxFrames
local Utils = addon and addon.Utils

local INCOMING_CAST_ICON_COUNT = 3
local INCOMING_CAST_ICON_BASE_SIZE = 22
local INCOMING_CAST_ICON_DEFAULT_SCALE = 1
local INCOMING_CAST_ICON_SPACING = 0

local INCOMING_CAST_ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local INCOMING_CAST_ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local INCOMING_CAST_ICON_SWIPE_TEXTURE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local INCOMING_CAST_ICON_SWIPE_ALPHA = 0.7

local INCOMING_CAST_ICON_BACKDROP = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local INCOMING_CAST_PREVIEW_SPELL_IDS = { 116, 133, 686 } -- Frostbolt, Fireball, Shadow Bolt
local INCOMING_CAST_PREVIEW_FALLBACK_TEXTURES = {
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Fire_FlameBolt",
    "Interface\\Icons\\Spell_Shadow_ShadowBolt",
}

local function ClampNumber(value, minValue, maxValue, fallback)
    local num = value
    if type(num) ~= "number" then
        num = tonumber(num)
    end
    if type(num) ~= "number" then
        num = fallback
    end
    if type(num) ~= "number" then
        num = minValue
    end
    if num < minValue then
        num = minValue
    elseif num > maxValue then
        num = maxValue
    end
    return num
end

local function CenterCooldownText(cooldown)
    if not (cooldown and cooldown.GetCountdownFontString) then
        return
    end

    local fontString = cooldown:GetCountdownFontString()
    if not fontString then
        return
    end

    fontString:ClearAllPoints()
    fontString:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
    if fontString.SetJustifyH then
        fontString:SetJustifyH("CENTER")
    end
    if fontString.SetJustifyV then
        fontString:SetJustifyV("MIDDLE")
    end

    -- Improve readability: enforce a thicker outline on the cooldown countdown text.
    if fontString.GetFont and fontString.SetFont then
        local fontFile, fontHeight, fontFlags = fontString:GetFont()
        if fontFile and fontHeight then
            local flags = fontFlags or ""
            if not flags:find("THICKOUTLINE", 1, true) then
                if flags:find("OUTLINE", 1, true) then
                    flags = flags:gsub("OUTLINE", "THICKOUTLINE")
                elseif flags ~= "" then
                    flags = flags .. ",THICKOUTLINE"
                else
                    flags = "THICKOUTLINE"
                end
            end
            pcall(fontString.SetFont, fontString, fontFile, fontHeight, flags)
        end
    end
end

local function ApplyIncomingCastCooldownVisualConfig(cooldown, config)
    if not cooldown then
        return
    end

    local showSwipe = config and config.showSwipe
    if showSwipe == nil then
        showSwipe = true
    end

    local showCooldownText = config and config.showCooldownText
    if showCooldownText == nil then
        showCooldownText = true
    end

    if cooldown.SetDrawSwipe then
        pcall(cooldown.SetDrawSwipe, cooldown, showSwipe)
    end

    if cooldown.SetHideCountdownNumbers then
        pcall(cooldown.SetHideCountdownNumbers, cooldown, not showCooldownText)
    end

    if showCooldownText then
        CenterCooldownText(cooldown)
    end
end

local function GetIncomingCastIndicatorConfig()
    local profile = FF and FF.db and FF.db.profile and FF.db.profile.partyFrame

    local count = ClampNumber(profile and profile.incomingCastIconCount, 1, 4, INCOMING_CAST_ICON_COUNT)
    count = math.floor(count + 0.5)

    local baseSize = INCOMING_CAST_ICON_BASE_SIZE

    -- Prefer scale, but fall back to legacy pixel size if present.
    local scale = nil
    if profile and profile.incomingCastIconScale ~= nil then
        scale = ClampNumber(profile.incomingCastIconScale, 0.5, 3, INCOMING_CAST_ICON_DEFAULT_SCALE)
    elseif profile and profile.incomingCastIconSize ~= nil then
        local legacySize = ClampNumber(profile.incomingCastIconSize, 8, 128, baseSize)
        scale = legacySize / baseSize
        scale = ClampNumber(scale, 0.5, 3, INCOMING_CAST_ICON_DEFAULT_SCALE)
    else
        scale = INCOMING_CAST_ICON_DEFAULT_SCALE
    end

    -- Keep the hash stable and avoid float jitter.
    scale = math.floor((scale * 100) + 0.5) / 100

    -- This is the size used for layout (wrapper frame). The visual icon frame is
    -- kept at baseSize and scaled, so borders/overlays scale proportionally.
    local size = baseSize * scale

    local spacing = ClampNumber(profile and profile.incomingCastIconSpacing, 0, 50, INCOMING_CAST_ICON_SPACING)
    spacing = math.floor(spacing + 0.5)

    local showBorder = true
    if profile and profile.incomingCastIconBorder ~= nil then
        showBorder = profile.incomingCastIconBorder == true
    end

    local showSwipe = true
    if profile and profile.incomingCastIconSwipe ~= nil then
        showSwipe = profile.incomingCastIconSwipe == true
    end

    local showCooldownText = true
    if profile and profile.incomingCastIconCooldownText ~= nil then
        showCooldownText = profile.incomingCastIconCooldownText == true
    end

    local hash = string.format(
        "%d:%.2f:%d:%d:%d:%d",
        count,
        scale,
        spacing,
        showBorder and 1 or 0,
        showSwipe and 1 or 0,
        showCooldownText and 1 or 0
    )

    return {
        count = count,
        baseSize = baseSize,
        scale = scale,
        size = size,
        spacing = spacing,
        showBorder = showBorder,
        showSwipe = showSwipe,
        showCooldownText = showCooldownText,
        hash = hash,
    }
end

local function GetIncomingCastPreviewIcons(count)
    local icons = {}

    local getTexture = nil
    if C_Spell and C_Spell.GetSpellTexture then
        getTexture = C_Spell.GetSpellTexture
    end

    if getTexture then
        for _, spellID in ipairs(INCOMING_CAST_PREVIEW_SPELL_IDS) do
            local ok, tex = pcall(getTexture, spellID)
            if ok and tex then
                icons[#icons + 1] = tex
            end
        end
    end

    count = ClampNumber(count, 1, 10, INCOMING_CAST_ICON_COUNT)
    count = math.floor(count + 0.5)

    for i = 1, count do
        if not icons[i] then
            icons[i] = INCOMING_CAST_PREVIEW_FALLBACK_TEXTURES[i] or "Interface\\Icons\\INV_Misc_QuestionMark"
        end
    end

    return icons
end

local function ApplyIncomingCastIconLayout(icon, config)
    if not (icon and config) then
        return
    end

    -- Wrapper (layout) size uses the scaled size.
    icon:SetSize(config.size, config.size)

    local baseSize = config.baseSize or INCOMING_CAST_ICON_BASE_SIZE
    local scale = config.scale or INCOMING_CAST_ICON_DEFAULT_SCALE

    -- The actual visual icon is a child frame scaled via SetScale().
    local content = icon.icon or icon
    if content.SetScale then
        content:SetScale(scale)
    end
    if content.SetSize then
        content:SetSize(baseSize, baseSize)
    end

    if content.border then
        content.border:SetShown(config.showBorder)
    end

    if content.overlay then
        local overlayExpand = math.floor((baseSize * 0.15) + 0.6)
        content.overlay:ClearAllPoints()
        content.overlay:SetPoint("TOPLEFT", content, "TOPLEFT", -overlayExpand, overlayExpand)
        content.overlay:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", overlayExpand, -overlayExpand)
        content.overlay:SetShown(config.showBorder)
    end

    if content.texture then
        content.texture:ClearAllPoints()
        content.texture:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -0)
        content.texture:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -0, 0)
    end

    if content.cooldown then
        ApplyIncomingCastCooldownVisualConfig(content.cooldown, config)
    end
end

local function ResetIncomingCastCooldown(iconFrame)
    local cooldown = iconFrame and iconFrame.icon and iconFrame.icon.cooldown
    if not cooldown then
        return
    end

    if cooldown.Clear then
        pcall(cooldown.Clear, cooldown)
    end
    if cooldown.Hide then
        cooldown:Hide()
    end
end

local function CreateIncomingCastIcon(container, index, config)
    local wrapper = CreateFrame("Frame", nil, container)
    wrapper:SetFrameLevel((container.GetFrameLevel and container:GetFrameLevel() or 0) + 1)
    wrapper.layoutIndex = index
    wrapper:EnableMouse(false)
    wrapper:SetHitRectInsets(10000, 10000, 10000, 10000)

    local icon = CreateFrame("Frame", nil, wrapper)
    icon:SetPoint("CENTER", wrapper, "CENTER")
    icon:SetFrameLevel((wrapper.GetFrameLevel and wrapper:GetFrameLevel() or 0) + 1)
    icon:EnableMouse(false)
    icon:SetHitRectInsets(10000, 10000, 10000, 10000)
    wrapper.icon = icon

    local border = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop(INCOMING_CAST_ICON_BACKDROP)
    border:SetFrameLevel((icon.GetFrameLevel and icon:GetFrameLevel() or 0) + 2)
    border:EnableMouse(false)
    border:SetHitRectInsets(10000, 10000, 10000, 10000)
    icon.border = border

    local tex = icon:CreateTexture(nil, "ARTWORK")
    icon.texture = tex

    if tex.AddMaskTexture and icon.CreateMaskTexture then
        local mask = icon:CreateMaskTexture()
        mask:SetAllPoints(tex)
        if mask.SetAtlas then
            mask:SetAtlas(INCOMING_CAST_ICON_MASK_ATLAS)
            tex:AddMaskTexture(mask)
            icon.mask = mask
        end
    end

    local overlay = border:CreateTexture(nil, "OVERLAY")
    if overlay.SetAtlas then
        overlay:SetAtlas(INCOMING_CAST_ICON_OVERLAY_ATLAS)
        icon.overlay = overlay
    else
        overlay:Hide()
    end

    local okCooldown, cooldown = pcall(CreateFrame, "Cooldown", nil, icon, "CooldownFrameTemplate")
    if (not okCooldown) or (not cooldown) then
        okCooldown, cooldown = pcall(CreateFrame, "Cooldown", nil, icon)
    end

    if okCooldown and cooldown then
        cooldown:SetAllPoints()
        cooldown:SetFrameLevel((icon.GetFrameLevel and icon:GetFrameLevel() or 0) + 1)
        cooldown:EnableMouse(false)
        cooldown:SetHitRectInsets(10000, 10000, 10000, 10000)

        -- Match Blizzard TargetedSpells: show countdown text even for very short durations.
        cooldown.minimumCountdownDuration = 0

        if cooldown.SetCountdownFont then
            pcall(cooldown.SetCountdownFont, cooldown, "GameFontHighlightSmallOutline")
        end

        ApplyIncomingCastCooldownVisualConfig(cooldown, config)
        if cooldown.SetDrawEdge then
            pcall(cooldown.SetDrawEdge, cooldown, false)
        end
        if cooldown.SetDrawBling then
            pcall(cooldown.SetDrawBling, cooldown, false)
        end
        if cooldown.SetSwipeTexture then
            pcall(cooldown.SetSwipeTexture, cooldown, INCOMING_CAST_ICON_SWIPE_TEXTURE)
        end
        if cooldown.SetSwipeColor then
            pcall(cooldown.SetSwipeColor, cooldown, 0, 0, 0, INCOMING_CAST_ICON_SWIPE_ALPHA)
        end
        if cooldown.Clear then
            pcall(cooldown.Clear, cooldown)
        end

        icon.cooldown = cooldown
    end

    icon.ignoreInLayout = true

    wrapper.ignoreInLayout = true
    wrapper:SetAlpha(0)
    wrapper:Hide()

    ApplyIncomingCastIconLayout(wrapper, config)
    return wrapper
end

local function ApplyIncomingCastContainerLayout(container, config)
    if not (container and config) then
        return
    end

    container.isHorizontal = true
    container.stride = config.count
    container.layoutFramesGoingRight = true
    container.layoutFramesGoingUp = false
    container.childXPadding = config.spacing
    container.childYPadding = 0
    container.alwaysUpdateLayout = true

    local containerWidth = (config.size * config.count) + (config.spacing * (config.count - 1))
    container:SetSize(containerWidth, config.size)

    container.icons = container.icons or {}
    for i = 1, config.count do
        local icon = container.icons[i]
        if not icon then
            icon = CreateIncomingCastIcon(container, i, config)
            container.icons[i] = icon
        else
            icon.layoutIndex = i
            ApplyIncomingCastIconLayout(icon, config)
        end
    end

    for i = (config.count + 1), #container.icons do
        local icon = container.icons[i]
        if icon then
            if icon.icon and icon.icon.texture then
                icon.icon.texture:SetTexture(nil)
            end

            ResetIncomingCastCooldown(icon)

            icon:SetAlpha(0)
            icon:Hide()
            icon.ignoreInLayout = true
        end
    end

    container._ffIncomingCastConfigHash = config.hash

    if container._ffUsesGridLayout and container.MarkDirty then
        pcall(container.MarkDirty, container)
    end
    if container._ffUsesGridLayout and container.Layout then
        pcall(container.Layout, container)
    end
end

local function SetAlphaFromBooleanSafe(frame, value)
    if not frame then return end

    if frame.SetAlphaFromBoolean then
        frame:SetAlphaFromBoolean(value, 1, 0)
        return
    end

    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(value, 0, 1)
        frame:SetAlpha(alpha)
        return
    end

    frame:SetAlpha(0)
end

local function SetShownFromBooleanSafe(frame, value)
    if not frame then return false end

    if frame.SetShownFromBoolean then
        frame:SetShownFromBoolean(value, true, false)
        return true
    end

    -- Some clients may allow SetShown(secretBool) directly.
    -- If it errors, swallow it and fall back to alpha-only behavior.
    if frame.SetShown then
        local ok = pcall(frame.SetShown, frame, value)
        if ok then
            return true
        end
    end

    return false
end

local function UpdateIncomingCastCooldown(entry, iconFrame, config)
    local cooldown = iconFrame and iconFrame.icon and iconFrame.icon.cooldown
    if not cooldown then
        return
    end

    local showSwipe = config and config.showSwipe
    if showSwipe == nil then
        showSwipe = true
    end

    local showCooldownText = config and config.showCooldownText
    if showCooldownText == nil then
        showCooldownText = true
    end

    local wantCooldown = showSwipe or showCooldownText

    ApplyIncomingCastCooldownVisualConfig(cooldown, config)

    if not wantCooldown then
        ResetIncomingCastCooldown(iconFrame)
        return
    end

    if not (entry and entry.cast) then
        ResetIncomingCastCooldown(iconFrame)
        return
    end

    local duration = entry.cast.duration
    if duration == nil and entry.casterUnit then
        if UnitCastingDuration then
            local ok, value = pcall(UnitCastingDuration, entry.casterUnit)
            if ok then
                duration = value
            end
        end

        if duration == nil and UnitChannelDuration then
            local ok, value = pcall(UnitChannelDuration, entry.casterUnit)
            if ok then
                duration = value
            end
        end
    end

    if cooldown.Show then
        cooldown:Show()
    end

    if duration == nil then
        ResetIncomingCastCooldown(iconFrame)
        return
    end

    if type(duration) == "number" then
        local startTime = (entry.cast and entry.cast.startTime) or GetTime()
        if cooldown.SetCooldown then
            pcall(cooldown.SetCooldown, cooldown, startTime, duration)
            if showCooldownText then
                CenterCooldownText(cooldown)
            end
        end
        return
    end

    if cooldown.SetCooldownFromDurationObject then
        pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
        if showCooldownText then
            CenterCooldownText(cooldown)
        end
        return
    end

    if duration.GetRemainingDuration and cooldown.SetCooldown then
        local ok, remaining = pcall(duration.GetRemainingDuration, duration)
        if ok and type(remaining) == "number" then
            pcall(cooldown.SetCooldown, cooldown, GetTime(), remaining)
            if showCooldownText then
                CenterCooldownText(cooldown)
            end
        end
    end
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
        self:_EnsureIncomingCastIndicatorForFrame(frame, config)
    end
end

function FF:_EnsureIncomingCastIndicatorForFrame(frame, config)
    if not frame or frame.ffIncomingCastContainerFailed then
        return
    end

    config = config or GetIncomingCastIndicatorConfig()

    local container = frame.ffIncomingCastContainer
    if not container then
        local ok, newContainer = pcall(CreateFrame, "Frame", nil, frame, "GridLayoutFrame")
        if not ok and not newContainer then
            frame.ffIncomingCastContainerFailed = true
            Utils:Log("Failed to create GridLayoutFrame for incoming cast indicators.")
            return
        end

        container = newContainer
        container._ffUsesGridLayout = true
        container:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
        container:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 20)
        container:EnableMouse(false)
        container:SetHitRectInsets(10000, 10000, 10000, 10000)

        frame.ffIncomingCastContainer = container
    end

    if container._ffIncomingCastConfigHash ~= config.hash then
        ApplyIncomingCastContainerLayout(container, config)
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

function FF:SetIncomingCastIndicatorPreviewEnabled(enabled)
    local wantEnabled = enabled == true
    if self._ffIncomingCastIndicatorPreviewEnabled == wantEnabled then
        return
    end

    self._ffIncomingCastIndicatorPreviewEnabled = wantEnabled

    if wantEnabled and self.SetupIncomingCastIndicators then
        self:SetupIncomingCastIndicators()
    end
    if self.UpdateIncomingCastIndicators then
        self:UpdateIncomingCastIndicators()
    end
end

local function UpdateTargetedIcon(entry, iconFrame, previewEnabled, frame, config)
    if iconFrame.icon and iconFrame.icon.texture then
        iconFrame.icon.texture:SetTexture(entry.cast.icon)
    end

    local cooldown = iconFrame.icon and iconFrame.icon.cooldown

    local showSwipe = config and config.showSwipe
    if showSwipe == nil then
        showSwipe = true
    end

    local showCooldownText = config and config.showCooldownText
    if showCooldownText == nil then
        showCooldownText = true
    end

    local wantCooldown = showSwipe or showCooldownText

    if cooldown then
        ApplyIncomingCastCooldownVisualConfig(cooldown, config)
    end

    if not (previewEnabled or entry.isPreview) then
        UpdateIncomingCastCooldown(entry, iconFrame, config)
    end

    iconFrame:SetAlpha(1)

    -- Prefer secret-safe show/hide to enable left-packing
    -- with GridLayoutFrame. Fall back to alpha-only behavior
    -- when SetShownFromBoolean isn't available.
    local usedShown = false

    if previewEnabled or entry.isPreview then
        iconFrame:Show()
        iconFrame:SetAlpha(1)
        if cooldown then
            if not wantCooldown then
                ResetIncomingCastCooldown(iconFrame)
            else
                if cooldown.Clear then
                    pcall(cooldown.Clear, cooldown)
                end
                cooldown:Show()
                cooldown:SetAlpha(1)

                local duration = 6
                local index = iconFrame.layoutIndex or 1
                local offset = (index - 1) * 0.75
                if cooldown.SetCooldown then
                    pcall(cooldown.SetCooldown, cooldown, GetTime() - offset, duration)
                    if showCooldownText then
                        CenterCooldownText(cooldown)
                    end
                end
            end
        end
    elseif UnitIsUnit then
        local target = entry.casterUnit .. "target"
        local isTargeted = UnitIsUnit(target, frame.unit)
        usedShown = SetShownFromBooleanSafe(iconFrame, isTargeted)

        if not usedShown then
            iconFrame:Show()
            SetAlphaFromBooleanSafe(iconFrame, isTargeted)
        else
            -- If we successfully used SetShownFromBoolean, keep
            -- targeted icons fully visible when shown.
            iconFrame:SetAlpha(1)
        end
    else
        ResetIncomingCastCooldown(iconFrame)
        iconFrame:Hide()
        iconFrame:SetAlpha(0)
    end

    if cooldown then
        if wantCooldown and iconFrame:IsShown() then
            cooldown:SetAlpha(iconFrame:GetAlpha() or 1)
        else
            -- The cooldown swipe can ignore parent display state;
            -- clearing it ensures it never lingers.
            ResetIncomingCastCooldown(iconFrame)
        end
    end

    iconFrame.ignoreInLayout = not iconFrame:IsShown()
end

function FF:UpdateTargetedCastIconsForFrame(frame, castList, previewEnabled, config)
    local inCombat = InCombatLockdown and InCombatLockdown()
    local desiredCount = config.count

    if frame and frame.unit then
        local container = frame.ffIncomingCastContainer
        if not container then
            if not inCombat then
                self:_EnsureIncomingCastIndicatorForFrame(frame, config)
            end
            container = frame.ffIncomingCastContainer
        elseif not inCombat then
            local existingCount = (container.icons and #container.icons) or 0
            if existingCount < desiredCount or container._ffIncomingCastConfigHash ~= config.hash then
                self:_EnsureIncomingCastIndicatorForFrame(frame, config)
            end
        end

        if container and container.icons then
            local existingCount = #container.icons
            local loopCount = math.max(desiredCount, existingCount)

            for i = 1, loopCount do
                local iconFrame = container.icons[i]
                local entry = castList[i]

                if iconFrame then
                    if i > desiredCount then
                        if iconFrame.icon and iconFrame.icon.texture then
                            iconFrame.icon.texture:SetTexture(nil)
                        end

                        ResetIncomingCastCooldown(iconFrame)

                        iconFrame:SetAlpha(0)
                        iconFrame:Hide()
                        iconFrame.ignoreInLayout = true
                    elseif entry and entry.cast then
                        UpdateTargetedIcon(entry, iconFrame, previewEnabled, frame, config)
                    else
                        if iconFrame.icon and iconFrame.icon.texture then
                            iconFrame.icon.texture:SetTexture(nil)
                        end

                        ResetIncomingCastCooldown(iconFrame)

                        iconFrame:SetAlpha(0)
                        iconFrame:Hide()
                        iconFrame.ignoreInLayout = true
                    end
                end
            end

            if container.MarkDirty then
                pcall(container.MarkDirty, container)
            end
            if container.Layout then
                pcall(container.Layout, container)
            end
        end
    end
end

function FF:UpdateIncomingCastIndicators()
    if not (CompactPartyFrame and CompactPartyFrame.memberUnitFrames) then
        return
    end

    if not self.GetIncomingCasts then return end

    local config = GetIncomingCastIndicatorConfig()
    local desiredCount = config.count

    local previewEnabled = self._ffIncomingCastIndicatorPreviewEnabled == true
    local castList = {}

    if previewEnabled then
        local previewIcons = GetIncomingCastPreviewIcons(desiredCount)
        for i = 1, desiredCount do
            castList[i] = { cast = { icon = previewIcons[i] }, isPreview = true }
        end
    else
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
            return (a.cast.startTime or 0) > (b.cast.startTime or 0)
        end)
    end

    local frames = self:GetFrames()
    for _, frame in ipairs(frames) do
        self:UpdateTargetedCastIconsForFrame(frame, castList, previewEnabled, config)
    end
end
