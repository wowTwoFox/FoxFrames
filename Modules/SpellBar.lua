local addonName, addon = ...

local Utils = addon.Utils

local SPELL_BAR_DEFAULT_GROW_DIRECTION = "RIGHT"
local SPELL_BAR_DEFAULT_POSITION = "BOTTOMLEFT"
local SPELL_BAR_DEFAULT_OFFSET_X = 2
local SPELL_BAR_DEFAULT_OFFSET_Y = 2

local function IsSecretNumberError(err)
    return type(err) == "string" and err:find("secret number value", 1, true) ~= nil
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

local function GetSpellBarIconConfig(config)
    if type(config) ~= "table" then
        return nil
    end
    if type(config.icon) == "table" then
        return config.icon
    end
    return config
end

local function ResetSpellFrame(spellFrame)
    if not spellFrame then
        return
    end

    if spellFrame.icon and spellFrame.icon.texture then
        spellFrame.icon.texture:SetTexture(nil)
    end

    if spellFrame.ResetCooldown then
        spellFrame:ResetCooldown()
    end

    spellFrame:SetAlpha(0)
    spellFrame:Hide()
    spellFrame.ignoreInLayout = true
end

local SpellBarMixin = {
    DEFAULT_GROW_DIRECTION = SPELL_BAR_DEFAULT_GROW_DIRECTION,
    DEFAULT_POSITION = SPELL_BAR_DEFAULT_POSITION,
    DEFAULT_OFFSET_X = SPELL_BAR_DEFAULT_OFFSET_X,
    DEFAULT_OFFSET_Y = SPELL_BAR_DEFAULT_OFFSET_Y,
}

local function CreateSpellBarFrame(frame)
    if not frame then return nil end
    Utils:Log("CreateSpellBarFrame for", frame)

    local ok, container = pcall(CreateFrame, "Frame", nil, frame, "GridLayoutFrame")
    if not ok or not container then return nil end

    ApplyMixinSafe(container, SpellBarMixin)

    container._ffUsesGridLayout = true
    -- Avoid automatic (OnUpdate-driven) layout passes which can run outside our pcalls.
    -- We'll explicitly call Layout() when we update the container.
    -- container.alwaysUpdateLayout = false
    container:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 20)
    container:EnableMouse(false)
    container:SetHitRectInsets(10000, 10000, 10000, 10000)
    return container
end

function SpellBarMixin:ApplyContainerPosition(frame, config)
    local container = self
    if not (container and frame) then
        return
    end

    local position = (config and config.position) or SPELL_BAR_DEFAULT_POSITION
    if position == "UP" then
        position = "TOP"
    elseif position == "DOWN" then
        position = "BOTTOM"
    end

    if position ~= "TOPLEFT" and position ~= "TOP" and position ~= "TOPRIGHT"
        and position ~= "LEFT" and position ~= "CENTER" and position ~= "RIGHT"
        and position ~= "BOTTOMLEFT" and position ~= "BOTTOM" and position ~= "BOTTOMRIGHT" then
        position = SPELL_BAR_DEFAULT_POSITION
    end

    local offsetX = Utils:ClampNumber(config and config.offsetX, -200, 200, SPELL_BAR_DEFAULT_OFFSET_X)
    offsetX = math.floor(offsetX + 0.5)

    local offsetY = Utils:ClampNumber(config and config.offsetY, -200, 200, SPELL_BAR_DEFAULT_OFFSET_Y)
    offsetY = math.floor(offsetY + 0.5)

    local xOffset = offsetX
    local yOffset = offsetY
    if position == "TOPRIGHT" or position == "RIGHT" or position == "BOTTOMRIGHT" then
        xOffset = -offsetX
    end

    if position == "TOPLEFT" or position == "TOP" or position == "TOPRIGHT" then
        yOffset = -offsetY
    end

    local anchorHash = string.format("%s:%d:%d", position, offsetX, offsetY)
    if container._ffSpellBarAnchorHash == anchorHash then
        return
    end

    container:ClearAllPoints()
    container:SetPoint(position, frame, position, xOffset, yOffset)
    container._ffSpellBarAnchorHash = anchorHash
end

function SpellBarMixin:ApplyIconContainerLayout(iconConfig)
    local container = self
    if not (container and iconConfig) then
        return
    end

    iconConfig = GetSpellBarIconConfig(iconConfig)
    if not iconConfig then
        return
    end

    local spellIconMixin = addon and addon.SpellIconMixin
    local createSpellIconFrame = addon and addon.CreateSpellIconFrame
    if not (spellIconMixin and createSpellIconFrame) then
        if Utils and Utils.Log then
            Utils:Log("SpellIconMixin or CreateSpellIconFrame is unavailable for incoming cast indicators.")
        end
        return
    end

    local iconBaseSize = tonumber(spellIconMixin.SPELL_ICON_BASE_SIZE) or tonumber(iconConfig.baseSize) or 1

    local iconSize = iconConfig.size or iconBaseSize
    local iconSpacing = iconConfig.spacing or 0

    local iconCount = tonumber(iconConfig.count)
    if type(iconCount) ~= "number" then
        iconCount = 1
    end
    iconCount = math.floor(iconCount + 0.5)
    if iconCount < 1 then
        iconCount = 1
    end

    local growDirection = iconConfig.growDirection or SPELL_BAR_DEFAULT_GROW_DIRECTION
    if growDirection ~= "RIGHT" and growDirection ~= "LEFT" and growDirection ~= "DOWN" and growDirection ~= "UP" then
        growDirection = SPELL_BAR_DEFAULT_GROW_DIRECTION
    end

    local isVertical = growDirection == "DOWN" or growDirection == "UP"

    container.isHorizontal = true
    container.stride = isVertical and 1 or iconCount
    container.layoutFramesGoingRight = true
    container.layoutFramesGoingUp = false
    container.childXPadding = isVertical and 0 or iconSpacing
    container.childYPadding = isVertical and iconSpacing or 0
    container.alwaysUpdateLayout = true

    -- Don't rely on LayoutFrame's automatic Update loop.
    -- container.alwaysUpdateLayout = false

    if isVertical then
        local containerHeight = (iconSize * iconCount) + (iconSpacing * (iconCount - 1))
        container:SetSize(iconSize, containerHeight)
    else
        local containerWidth = (iconSize * iconCount) + (iconSpacing * (iconCount - 1))
        container:SetSize(containerWidth, iconSize)
    end

    container.spells = container.spells or {}
    for i = 1, iconCount do
        local spell = container.spells[i]
        if not spell then
            spell = createSpellIconFrame(container, i, iconConfig)
            container.spells[i] = spell
        else
            spell.layoutIndex = i
            spell:ApplyLayout(iconConfig)
        end
    end

    for i = (iconCount + 1), #container.spells do
        local spell = container.spells[i]
        if spell then
            ResetSpellFrame(spell)
        end
    end

    container._ffSpellBarConfigHash = iconConfig.hash

    if container._ffUsesGridLayout and container.Layout then
        local ok, err = pcall(container.Layout, container)
        if (not ok) and IsSecretNumberError(err) then
            -- Layout failed due to a secret value; keep the UI usable and stop error spam.
            container.alwaysUpdateLayout = false
        end
    end
end

local function GetEntryTargetUnit(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local cast = type(entry.cast) == "table" and entry.cast or nil

    local target = entry.target
    if target == nil and cast then
        target = cast.target
    end

    if type(target) ~= "string" or target == "" then
        return nil
    end

    return target
end

local function EntryTargetsFrameUnit(entry, frameUnit)
    if type(frameUnit) ~= "string" or frameUnit == "" then
        return false
    end

    local target = GetEntryTargetUnit(entry)
    if not target then
        return false
    end

    -- Avoid branching on UnitIsUnit() in this path (can be secret boolean).
    return target == frameUnit
end

function SpellBarMixin:UpdateFromCastList(targetUnit, castList, config)
    local iconConfig = GetSpellBarIconConfig(config)
    if not iconConfig then
        return
    end

    local container = self
    if not (container and type(targetUnit) == "string" and targetUnit ~= "") then
        return
    end

    local desiredCount = iconConfig.count or (config and config.count) or 0

    local growDirection = iconConfig.growDirection or (config and config.growDirection)
    if growDirection ~= "RIGHT" and growDirection ~= "LEFT" and growDirection ~= "DOWN" and growDirection ~= "UP" then
        growDirection = SPELL_BAR_DEFAULT_GROW_DIRECTION
    end

    local isVertical = growDirection == "DOWN" or growDirection == "UP"
    local reverseIcons = growDirection == "LEFT" or growDirection == "UP"

    local targetedCastList = {}
    local untargetedCastList = {}
    if castList then
        for _, entry in ipairs(castList) do
            if EntryTargetsFrameUnit(entry, targetUnit) then
                targetedCastList[#targetedCastList + 1] = entry
            elseif GetEntryTargetUnit(entry) == nil then
                untargetedCastList[#untargetedCastList + 1] = entry
            end
        end
    end

    if container and container.spells then
        local existingCount = #container.spells
        local loopCount = math.max(desiredCount, existingCount)

        for i = 1, loopCount do
            local iconIndex = i
            if reverseIcons and i <= desiredCount then
                iconIndex = desiredCount - i + 1
            end

            local spellFrame = container.spells[iconIndex]
            local entry = nil
            if i <= desiredCount then
                entry = targetedCastList[i]
                if not entry then
                    local fallbackIndex = i - #targetedCastList
                    if fallbackIndex > 0 then
                        entry = untargetedCastList[fallbackIndex]
                    end
                end
            end

            if spellFrame then
                if i > desiredCount then
                    ResetSpellFrame(spellFrame)
                elseif entry and entry.cast then
                    spellFrame:UpdateFromEntry(entry, targetUnit, iconConfig)
                else
                    ResetSpellFrame(spellFrame)
                end
            end
        end

        local shownCount = 0
        for i = 1, desiredCount do
            local spellFrame = container.spells[i]
            if spellFrame and spellFrame.ignoreInLayout ~= true then
                shownCount = shownCount + 1
            end
        end

        local spellIconMixin = addon and addon.SpellIconMixin
        local iconBaseSize = tonumber(iconConfig.baseSize) or tonumber(spellIconMixin and spellIconMixin.SPELL_ICON_BASE_SIZE) or 0
        local iconSize = iconConfig.size or iconBaseSize
        local iconSpacing = iconConfig.spacing or 0

        local width = iconSize
        local height = iconSize
        if isVertical then
            height = shownCount > 0 and ((iconSize * shownCount) + (iconSpacing * (shownCount - 1))) or 0
            if height < 0 then
                height = 0
            end
        else
            width = shownCount > 0 and ((iconSize * shownCount) + (iconSpacing * (shownCount - 1))) or 0
            if width < 0 then
                width = 0
            end
        end

        local sizeHash = string.format("%d:%d", math.floor(width + 0.5), math.floor(height + 0.5))
        if container._ffSpellBarDesiredSizeHash ~= sizeHash then
            container._ffSpellBarDesiredSizeHash = sizeHash
            if container.SetSize then
                pcall(container.SetSize, container, width, height)
            end
        end

        if container.MarkDirty then
            -- MarkDirty schedules an OnUpdate-driven Layout() (which we can't pcall).
            -- Avoid it and call Layout() directly.
        end
        if container.Layout then
            local ok, err = pcall(container.Layout, container)
            if (not ok) and IsSecretNumberError(err) then
                container.alwaysUpdateLayout = false
            end
        end
    end
end

function SpellBarMixin:UpdateSpellBarForFrame(targetUnit, castList, config)
    local container = self
    if not (container and type(targetUnit) == "string" and targetUnit ~= "") then
        return
    end

    if container and container.UpdateFromCastList then
        container:UpdateFromCastList(targetUnit, castList, config)
    end
end

if addon then
    addon.SpellBarMixin = SpellBarMixin
    addon.CreateSpellBarFrame = CreateSpellBarFrame
end
