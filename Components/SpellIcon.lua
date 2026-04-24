
local addonName, addon = ...

local FF = FoxFrames
local Utils = addon.Utils

local function SetAlphaFromBooleanSafe(frame, value)
    if not frame then return end

    -- Do not coerce with comparisons (e.g. `== true`) because WoW can surface
    -- "secret boolean" values in tainted execution paths. Instead, only
    -- normalize obviously-invalid inputs (nil/non-boolean) without inspecting
    -- the boolean value itself.
    if type(value) ~= "boolean" then
        value = false
    end

    if frame.SetAlphaFromBoolean then
        pcall(frame.SetAlphaFromBoolean, frame, value, 1, 0)
        return
    end

    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local ok, alpha = pcall(C_CurveUtil.EvaluateColorValueFromBoolean, value, 0, 1)
        if ok and type(alpha) == "number" then
            frame:SetAlpha(alpha)
        else
            frame:SetAlpha(0)
        end
        return
    end

    -- Fallback for environments without SetAlphaFromBoolean; should be rare.
    -- Use pcall to avoid propagating taint-related errors.
    local ok, alpha = pcall(function()
        return value and 1 or 0
    end)
    frame:SetAlpha((ok and alpha) or 0)
end

local SPELL_ICON_BASE_SIZE = 22
local SPELL_ICON_DEFAULT_SCALE = 1
local SPELL_ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local SPELL_ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local SPELL_ICON_SWIPE_TEXTURE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local SPELL_ICON_SWIPE_ALPHA = 0.7

local function NormalizeSpellIconConfig(iconConfig)
    if type(iconConfig) ~= "table" then
        return {}
    end

    if type(iconConfig.cooldownText) ~= "table" then
        iconConfig.cooldownText = {}
    end

    -- Backward-compatible: migrate legacy flat keys into cooldownText.
    if iconConfig.cooldownText.show == nil and iconConfig.showCooldownText ~= nil then
        iconConfig.cooldownText.show = iconConfig.showCooldownText == true
    end
    if iconConfig.cooldownText.fontSize == nil and iconConfig.cooldownFontSize ~= nil then
        iconConfig.cooldownText.fontSize = iconConfig.cooldownFontSize
    end

    return iconConfig
end

local function ApplyMixinSafe(target, mixin)
    if not (target and mixin) then
        return
    end

    if Mixin then
        Mixin(target, mixin)
        return
    end

    for key, value in pairs(mixin) do
        target[key] = value
    end
end

local function GetEntryCast(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if type(entry.cast) == "table" then
        return entry.cast
    end

    return entry
end

local function GetEntryCasterUnit(entry, cast)
    if type(entry) == "table" and type(entry.casterUnit) == "string" and entry.casterUnit ~= "" then
        return entry.casterUnit
    end

    if type(cast) == "table" and type(cast.casterUnit) == "string" and cast.casterUnit ~= "" then
        return cast.casterUnit
    end

    return nil
end

local function CenterSpellIconCooldownText(cooldown, iconConfig)
    local fontString = Utils:GetCooldownCountdownFontString(cooldown)

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

    if fontString.GetFont and fontString.SetFont then
        local fontFile, fontHeight, fontFlags = fontString:GetFont()
        if fontFile and fontHeight then
            local desiredFontHeight = Utils:ClampInteger(iconConfig and iconConfig.cooldownText and iconConfig.cooldownText.fontSize, 8, 32, fontHeight)
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
            pcall(fontString.SetFont, fontString, fontFile, desiredFontHeight, flags)
        end
    end

    if fontString.SetTextColor then
        local desiredColor = iconConfig and iconConfig.cooldownText and iconConfig.cooldownText.color
        local color = Utils:SanitizeColor(desiredColor, { r = 1, g = 1, b = 1 })
        pcall(fontString.SetTextColor, fontString, color.r, color.g, color.b)
    end
end

local function ApplyCooldownVisualConfigToCooldown(cooldown, iconConfig)
    if not cooldown then
        return
    end

    iconConfig = NormalizeSpellIconConfig(iconConfig)

    local showSwipe = iconConfig.showSwipe
    if showSwipe == nil then
        showSwipe = true
    end

    local showCooldownText = iconConfig.cooldownText and iconConfig.cooldownText.show
    if showCooldownText == nil then
        showCooldownText = true
    else
        showCooldownText = showCooldownText == true
    end

    if cooldown.SetDrawSwipe then
        pcall(cooldown.SetDrawSwipe, cooldown, showSwipe)
    end

    Utils:SetHideCountdownNumbersSafe(cooldown, not showCooldownText)

    if showCooldownText then
        CenterSpellIconCooldownText(cooldown, iconConfig)
    end
end

local function ResetCooldownOnSpellFrame(spellFrame)
    local cooldown = spellFrame and spellFrame.icon and spellFrame.icon.cooldown
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

local function ApplyLayoutToSpellFrame(spellFrame, iconConfig)
    if not spellFrame then
        return
    end

    iconConfig = NormalizeSpellIconConfig(iconConfig)

    local iconSize = iconConfig.size or SPELL_ICON_BASE_SIZE

    spellFrame:SetSize(iconSize, iconSize)

    local baseSize = iconConfig.baseSize or SPELL_ICON_BASE_SIZE
    local scale = iconConfig.scale or SPELL_ICON_DEFAULT_SCALE

    local content = spellFrame.icon or spellFrame
    if content.SetScale then
        content:SetScale(scale)
    end
    if content.SetSize then
        content:SetSize(baseSize, baseSize)
    end

    local showBorder = iconConfig.showBorder
    if showBorder == nil then
        showBorder = true
    end

    if content.border then
        content.border:SetShown(showBorder)
    end

    if content.overlay then
        local overlayExpand = math.floor((baseSize * 0.15) + 0.6)
        content.overlay:ClearAllPoints()
        content.overlay:SetPoint("TOPLEFT", content, "TOPLEFT", -overlayExpand, overlayExpand)
        content.overlay:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", overlayExpand, -overlayExpand)
        content.overlay:SetShown(showBorder)
    end

    if content.texture then
        content.texture:ClearAllPoints()
        content.texture:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -0)
        content.texture:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -0, 0)
    end

    if content.cooldown then
        ApplyCooldownVisualConfigToCooldown(content.cooldown, iconConfig)
    end
end

local function UpdateCooldownOnSpellFrame(entry, spellFrame, iconConfig)
    local cooldown = spellFrame and spellFrame.icon and spellFrame.icon.cooldown
    if not cooldown then
        return
    end

    iconConfig = NormalizeSpellIconConfig(iconConfig)

    local showSwipe = iconConfig.showSwipe
    if showSwipe == nil then
        showSwipe = true
    end

    local showCooldownText = iconConfig.cooldownText and iconConfig.cooldownText.show
    if showCooldownText == nil then
        showCooldownText = true
    else
        showCooldownText = showCooldownText == true
    end

    local wantCooldown = showSwipe or showCooldownText

    ApplyCooldownVisualConfigToCooldown(cooldown, iconConfig)

    if not wantCooldown then
        ResetCooldownOnSpellFrame(spellFrame)
        return
    end

    local cast = GetEntryCast(entry)
    if not cast then
        ResetCooldownOnSpellFrame(spellFrame)
        return
    end

    local duration = cast.duration
    local casterUnit = GetEntryCasterUnit(entry, cast)
    if duration == nil and casterUnit then
        if UnitCastingDuration then
            local ok, value = pcall(UnitCastingDuration, casterUnit)
            if ok then
                duration = value
            end
        end

        if duration == nil and UnitChannelDuration then
            local ok, value = pcall(UnitChannelDuration, casterUnit)
            if ok then
                duration = value
            end
        end
    end

    if cooldown.Show then
        cooldown:Show()
    end

    if duration == nil then
        ResetCooldownOnSpellFrame(spellFrame)
        return
    end

    if type(duration) == "number" then
        local startTime = cast.startTime or GetTime()
        if cooldown.SetCooldown then
            pcall(cooldown.SetCooldown, cooldown, startTime, duration)
            if showCooldownText then
                CenterSpellIconCooldownText(cooldown, iconConfig)
            end
        end
        return
    end

    if cooldown.SetCooldownFromDurationObject then
        pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
        if showCooldownText then
            CenterSpellIconCooldownText(cooldown, iconConfig)
        end
        return
    end

    if duration.GetRemainingDuration and cooldown.SetCooldown then
        local ok, remaining = pcall(duration.GetRemainingDuration, duration)
        if ok and type(remaining) == "number" then
            pcall(cooldown.SetCooldown, cooldown, GetTime(), remaining)
            if showCooldownText then
                CenterSpellIconCooldownText(cooldown, iconConfig)
            end
        end
    end
end

local function UpdateSpellFrameFromEntry(entry, spellFrame, unit, iconConfig)
    if not spellFrame then
        return
    end

    local cast = GetEntryCast(entry)

    if spellFrame.icon and spellFrame.icon.texture then
        spellFrame.icon.texture:SetTexture(cast and cast.icon or nil)
    end

    local cooldown = spellFrame.icon and spellFrame.icon.cooldown

    iconConfig = NormalizeSpellIconConfig(iconConfig)

    local showSwipe = iconConfig.showSwipe
    if showSwipe == nil then
        showSwipe = true
    end

    local showCooldownText = iconConfig.cooldownText and iconConfig.cooldownText.show
    if showCooldownText == nil then
        showCooldownText = true
    else
        showCooldownText = showCooldownText == true
    end

    local wantCooldown = showSwipe or showCooldownText

    UpdateCooldownOnSpellFrame(entry, spellFrame, iconConfig)

    spellFrame:SetAlpha(1)
    local showInLayout = false

    if UnitIsUnit and cast and type(unit) == "string" and unit ~= "" then
        local target = nil
        if type(entry) == "table" then
            target = entry.target
        end
        if target == nil then
            target = cast.target
        end
        if target ~= nil and type(target) ~= "string" then
            target = nil
        end
        if target == nil then
            local casterUnit = GetEntryCasterUnit(entry, cast)
            if casterUnit then
                target = casterUnit .. "target"
            end
        end

        local isTargeted = false
        if target == unit then
            isTargeted = true
        elseif target then
            isTargeted = UnitIsUnit(target, unit)
        end

        -- Keep frame visibility stable for GridLayoutFrame; changing shown state
        -- from secret booleans can leak into size calculations.
        spellFrame:Show()
        SetAlphaFromBooleanSafe(spellFrame, isTargeted)
        showInLayout = true
    elseif cast then
        spellFrame:Show()
        spellFrame:SetAlpha(1)
        showInLayout = true
    else
        ResetCooldownOnSpellFrame(spellFrame)
        spellFrame:Hide()
        spellFrame:SetAlpha(0)
    end

    if cooldown then
        if wantCooldown and showInLayout then
            cooldown:SetAlpha(spellFrame:GetAlpha() or 1)
        else
            -- The cooldown swipe can ignore parent display state;
            -- clearing it ensures it never lingers.
            ResetCooldownOnSpellFrame(spellFrame)
        end
    end

    spellFrame.ignoreInLayout = not showInLayout
end

local SpellIconMixin = {
    SPELL_ICON_BASE_SIZE = SPELL_ICON_BASE_SIZE,
}

local function CreateSpellIconFrame(container, index, iconConfig)
    if not container then
        return nil
    end

    local wrapper = CreateFrame("Frame", nil, container)
    wrapper:SetFrameLevel((container.GetFrameLevel and container:GetFrameLevel() or 0) + 1)
    wrapper.layoutIndex = index
    wrapper:EnableMouse(false)
    wrapper:SetHitRectInsets(10000, 10000, 10000, 10000)

    ApplyMixinSafe(wrapper, SpellIconMixin)

    local icon = CreateFrame("Frame", nil, wrapper)
    icon:SetPoint("CENTER", wrapper, "CENTER")
    icon:SetFrameLevel((wrapper.GetFrameLevel and wrapper:GetFrameLevel() or 0) + 1)
    icon:EnableMouse(false)
    icon:SetHitRectInsets(10000, 10000, 10000, 10000)
    wrapper.icon = icon

    local border = CreateFrame("Frame", nil, icon)
    border:SetAllPoints()
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
            mask:SetAtlas(SPELL_ICON_MASK_ATLAS)
            tex:AddMaskTexture(mask)
            icon.mask = mask
        end
    end

    local overlay = border:CreateTexture(nil, "OVERLAY")
    if overlay.SetAtlas then
        overlay:SetAtlas(SPELL_ICON_OVERLAY_ATLAS)
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

        cooldown.minimumCountdownDuration = 0

        if cooldown.SetCountdownFont then
            pcall(cooldown.SetCountdownFont, cooldown, "GameFontHighlightSmallOutline")
        end

        ApplyCooldownVisualConfigToCooldown(cooldown, iconConfig)
        if cooldown.SetDrawEdge then
            pcall(cooldown.SetDrawEdge, cooldown, false)
        end
        if cooldown.SetDrawBling then
            pcall(cooldown.SetDrawBling, cooldown, false)
        end
        if cooldown.SetSwipeTexture then
            pcall(cooldown.SetSwipeTexture, cooldown, SPELL_ICON_SWIPE_TEXTURE)
        end
        if cooldown.SetSwipeColor then
            pcall(cooldown.SetSwipeColor, cooldown, 0, 0, 0, SPELL_ICON_SWIPE_ALPHA)
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

    wrapper:ApplyLayout(iconConfig)

    return wrapper
end

function SpellIconMixin:ApplyCooldownVisualConfig(iconConfig)
    local cooldown = self and self.icon and self.icon.cooldown
    ApplyCooldownVisualConfigToCooldown(cooldown, iconConfig)
end

function SpellIconMixin:ApplyLayout(iconConfig)
    ApplyLayoutToSpellFrame(self, iconConfig)
end

function SpellIconMixin:ResetCooldown()
    ResetCooldownOnSpellFrame(self)
end

function SpellIconMixin:UpdateCooldown(entry, iconConfig)
    UpdateCooldownOnSpellFrame(entry, self, iconConfig)
end

function SpellIconMixin:UpdateFromEntry(entry, unit, iconConfig)
    UpdateSpellFrameFromEntry(entry, self, unit, iconConfig)
end

if addon then
    addon.SpellIconMixin = SpellIconMixin
    addon.CreateSpellIconFrame = CreateSpellIconFrame
end
