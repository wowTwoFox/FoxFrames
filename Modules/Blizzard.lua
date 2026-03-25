local addonName, addon = ...

local Constants = addon.Constants
local Utils = addon.Utils

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

local function NormalizeMemberUnitFrames(frames)
    if type(frames) ~= "table" then
        return {}
    end

    -- Most Blizzard unit frame containers use a 1-indexed array.
    -- If not, normalize into an array for consistent iteration.
    if rawget(frames, 1) ~= nil then
        -- return frames
    end

    local normalized = {}
    for _, frame in pairs(frames) do
        -- Raid frames also contain strings 'linebreak' in the array
        -- We need to filter out only raid frame objects
        if frame and frame.frameType and frame.frameType == "raid" then
            normalized[#normalized + 1] = frame
        end
    end
    return normalized
end

local function GetPartyMemberUnitFrames()
    if not (CompactPartyFrame and CompactPartyFrame.memberUnitFrames) then
        return {}
    end

    return NormalizeMemberUnitFrames(CompactPartyFrame.memberUnitFrames)
end

local function GetRaidMemberUnitFrames()
    if not (CompactRaidFrameContainer and CompactRaidFrameContainer.flowFrames) then
        Utils:Log("ERROR: Raid frames not found", CompactRaidFrameContainer)
        return {}
    end

    local frames = NormalizeMemberUnitFrames(CompactRaidFrameContainer.flowFrames)
    return frames
end

function Object:GetFrames()
    if self:InRaidGroup() then
        return GetRaidMemberUnitFrames()
    end

    if self:InPartyGroup() then
        local settings = BlizzardSettings
        local useRaidStylePartyFrames = settings and settings.GetUseRaidStylePartyFrames and settings:GetUseRaidStylePartyFrames()
        if useRaidStylePartyFrames then
            return GetRaidMemberUnitFrames()
        end

        return GetPartyMemberUnitFrames()
    end

    -- Solo: default to party frames (they can optionally be shown in solo).
    return GetPartyMemberUnitFrames()
end

local function GetFrameCenterSafe(frame)
    if not (frame and frame.GetCenter) then
        return nil
    end

    local ok, x, y = pcall(frame.GetCenter, frame)
    if not ok then
        return nil
    end

    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    return x, y
end

function Object:GetPartyFramesLayoutAxis()
    local settings = BlizzardSettings
    if settings and settings.GetPartyFramesUseHorizontalGroups and (not self:InRaidGroup()) then
        local useRaidStylePartyFrames = settings.GetUseRaidStylePartyFrames and settings:GetUseRaidStylePartyFrames()
        if not useRaidStylePartyFrames then
            local isHorizontal = settings:GetPartyFramesUseHorizontalGroups()
            if isHorizontal ~= nil then
                return isHorizontal and Constants.LAYOUT_AXIS.HORIZONTAL or Constants.LAYOUT_AXIS.VERTICAL
            end
        end
    end

    local frames = self:GetFrames()

    local x1, y1, x2, y2
    for _, frame in ipairs(frames) do
        local x, y = GetFrameCenterSafe(frame)
        if x and y then
            if not x1 then
                x1, y1 = x, y
            else
                x2, y2 = x, y
                break
            end
        end
    end

    if not (x1 and y1 and x2 and y2) then
        return nil
    end

    local ok, dx, dy = pcall(function()
        return math.abs(x2 - x1), math.abs(y2 - y1)
    end)
    if not ok or type(dx) ~= "number" or type(dy) ~= "number" then
        return nil
    end

    if dx == 0 and dy == 0 then
        return nil
    end

    if dy > dx then
        return Constants.LAYOUT_AXIS.VERTICAL
    end

    return Constants.LAYOUT_AXIS.HORIZONTAL
end

function Object:InRaidGroup()
    return IsInRaid()
end

function Object:InPartyGroup()
    return IsInGroup() and (not IsInRaid())
end

function Object:InSoloMode()
    return not IsInGroup()
end

function Object:InPVPGroup()
    if not (IsInGroup() or IsInRaid()) then
        return false
    end

    return C_PvP.IsBattleground()
end

function Object:IsManagedPartyFrame(frame)
    if not frame then
        return false
    end

    local partyFrames = CompactPartyFrame and CompactPartyFrame.memberUnitFrames
    if type(partyFrames) == "table" then
        for _, memberFrame in pairs(partyFrames) do
            if frame == memberFrame then
                return true
            end
        end
    end

    local raidFrames = CompactRaidFrameContainer and CompactRaidFrameContainer.memberUnitFrames
    if type(raidFrames) == "table" then
        for _, memberFrame in pairs(raidFrames) do
            if frame == memberFrame then
                return true
            end
        end
    end

    return false
end

function Object:GetClassColorForUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    if type(UnitClass) ~= "function" then
        return nil
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end

    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classToken)
        if color then
            return color.r, color.g, color.b
        end
    end

    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local color = RAID_CLASS_COLORS[classToken]
        return color.r, color.g, color.b
    end

    return nil
end

local function GetBuiltInEditModeLayoutName(layoutIndex)
    if layoutIndex == 1 then
        return rawget(_G, "LAYOUT_STYLE_MODERN") or "Modern"
    end
    if layoutIndex == 2 then
        return rawget(_G, "LAYOUT_STYLE_CLASSIC") or "Classic"
    end
    return nil
end

function Object:GetCurrentEditModeLayoutIndex()
    if not (C_EditMode and C_EditMode.GetLayouts) then
        return nil
    end

    local ok, layouts = pcall(C_EditMode.GetLayouts)
    if not ok or type(layouts) ~= "table" then
        return nil
    end

    local index = layouts.activeLayout
    if type(index) ~= "number" then
        return nil
    end

    return index
end

function Object:GetEditModeLayout(layoutIndex)
    if type(layoutIndex) ~= "number" then
        return nil
    end

    local builtInName = GetBuiltInEditModeLayoutName(layoutIndex)
    if builtInName then
        return {
            layoutIndex = layoutIndex,
            layoutName = builtInName,
        }
    end

    if not (C_EditMode and C_EditMode.GetLayouts) then
        return nil
    end

    local ok, layouts = pcall(C_EditMode.GetLayouts)
    if not ok or type(layouts) ~= "table" then
        return nil
    end

    Utils:Log("Layouts", layouts)

    local customIndex = layoutIndex - 2
    return layouts.layouts and layouts.layouts[customIndex]
end

function Object:GetCurrentEditModeLayout()
    if not (C_EditMode and C_EditMode.GetLayouts) then
        return nil
    end

    local ok, layouts = pcall(C_EditMode.GetLayouts)
    if not ok or type(layouts) ~= "table" then
        return nil
    end

    if type(layouts.activeLayout) ~= "number" then
        return nil
    end

    local builtInName = GetBuiltInEditModeLayoutName(layouts.activeLayout)
    if builtInName then
        return {
            layoutIndex = layouts.activeLayout,
            layoutName = builtInName,
        }
    end

    local customIndex = layouts.activeLayout - 2
    return layouts.layouts and layouts.layouts[customIndex]
end

addon.Blizzard = Object:New()