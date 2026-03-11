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

local utils = Object:New()

if addon then
    addon.Utils = utils
end