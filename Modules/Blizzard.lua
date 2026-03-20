local addonName, addon = ...

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:GetFrames()
    if not (CompactPartyFrame and CompactPartyFrame.memberUnitFrames) then
        return {}
    end

    return CompactPartyFrame.memberUnitFrames
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

    for _, memberFrame in ipairs(self:GetFrames()) do
        if frame == memberFrame then
            return true
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

addon.Blizzard = Object:New()