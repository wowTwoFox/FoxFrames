local addonName, addon = ...

local Object = {}
Object.__index = Object -- When a key is missing, look in BlizzardSettings

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:Log(title, logObject)
    local DevTool = _G.DevTool
    local titleWithDate = date("%H:%M:%S") .. " " .. title
    logObject = logObject or title

    if DevTool then
        DevTool:AddData(logObject, titleWithDate)
    end
end

function Object:LogBlockedAddon(event, blockedAddon, blockedFunction)
    -- Taint attribution can point at whichever embedded Ace3/CallbackHandler copy is active.
    -- Filter by addon name *or* by stack containing FoxFrames, to avoid missing the signal.
    local stack
    if debugstack then
        stack = debugstack(2, 20, 20)
    end

    local isRelevant = (blockedAddon == addonName)
        or (blockedAddon == "DevTool")
        or (stack and stack:find("Interface/AddOns/FoxFrames/", 1, true) ~= nil)

    if not isRelevant then return end

    self._ffBlockedActionsSeen = self._ffBlockedActionsSeen or {}
    local key = tostring(event) .. ":" .. tostring(blockedAddon) .. ":" .. tostring(blockedFunction)
    if self._ffBlockedActionsSeen[key] then return end
    self._ffBlockedActionsSeen[key] = true

    local payload = {
        event = event,
        blockedAddon = blockedAddon,
        blockedFunction = blockedFunction,
        inCombat = InCombatLockdown and InCombatLockdown() or nil,
    }

    if stack then
        payload.stack = stack
    end

    -- Prevent recursive loops if DevTool logging itself triggers another blocked action.
    if not self._ffBlockedActionsLogging then return end
    self._ffBlockedActionsLogging = true
    local title = "ADDON_ACTION_BLOCKED: " .. tostring(blockedAddon) .. " -> " .. tostring(blockedFunction)
    if payload.inCombat ~= nil then
        title = title .. " (combat=" .. tostring(payload.inCombat) .. ")"
    end
    self:Log(title, payload)
    self._ffBlockedActionsLogging = false
end

function Object:GetRect(frame)
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs,
    }
end

function Object:ClampNumber(value, minValue, maxValue, fallback)
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

function Object:GetCooldownCountdownFontString(cooldown)
    if not (cooldown and cooldown.GetCountdownFontString) then
        return nil
    end

    local fontString = cooldown:GetCountdownFontString()
    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return nil
    end

    return fontString
end

function Object:SetHideCountdownNumbersSafe(cooldown, hideCountdownNumbers)
    if not (cooldown and cooldown.SetHideCountdownNumbers) then
        return false
    end

    return pcall(cooldown.SetHideCountdownNumbers, cooldown, hideCountdownNumbers)
end

function Object:C(hex, text)
    local value = tostring(text or "")
    local color = type(hex) == "string" and hex or "ffffff"

    color = color:gsub("^#", "")

    if #color == 8 then
        return ("|c%s%s|r"):format(color, value)
    end

    if #color == 6 then
        return ("|cff%s%s|r"):format(color, value)
    end

    return value
end

local utils = Object:New()

if addon then
    addon.Utils = utils
end
