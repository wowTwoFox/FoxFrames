local addonName, addon = ...

assert(addon and addon.Constants, "FoxFrames: addon table or Constants missing (load order issue)")

local Constants = addon.Constants
local anchorPoints = Constants.ANCHOR_POINTS
local flipVerticalAnchorPoints = Constants.FLIP_VERTICAL_ANCHOR_POINTS
local flipHorizontalAnchorPoints = Constants.FLIP_HORIZONTAL_ANCHOR_POINTS

local Object = {}
Object.__index = Object -- When a key is missing, look in BlizzardSettings

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

function Object:Log(title, logObject)
    local DevTool = rawget(_G, "DevTool")
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

    -- Prevent recursive loops if logging itself triggers another blocked action.
    if self._ffBlockedActionsLogging then return end
    self._ffBlockedActionsLogging = true
    local title = "ADDON_ACTION_BLOCKED: " .. tostring(blockedAddon) .. " -> " .. tostring(blockedFunction)
    if payload.inCombat ~= nil then
        title = title .. " (combat=" .. tostring(payload.inCombat) .. ")"
    end

    local hasDevTool = rawget(_G, "DevTool") ~= nil
    self:Log(title, payload)
    if not hasDevTool then
        local msg = self:C("ff6b6b", "FoxFrames") .. " " .. title
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        else
            print(msg)
        end
    end
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

local function CapturePointDefaults(frame)
    if not (frame and frame.GetPoint) then
        return nil
    end

    local defaults = {}

    if frame.GetNumPoints then
        local okNum, numPoints = pcall(frame.GetNumPoints, frame)
        if okNum and type(numPoints) == "number" and numPoints > 0 then
            local points = {}
            for i = 1, numPoints do
                local okPoint, point, relativeTo, relativePoint, xOfs, yOfs = pcall(frame.GetPoint, frame, i)
                if okPoint and point then
                    local args = { n = 5, point, relativeTo, relativePoint, xOfs, yOfs }
                    points[#points + 1] = args
                end
            end

            if #points > 0 then
                defaults.points = points
                return defaults
            end
        end
    end

    local okPoint, point, relativeTo, relativePoint, xOfs, yOfs = pcall(frame.GetPoint, frame, 1)
    if okPoint and point then
        local args = { n = 5, point, relativeTo, relativePoint, xOfs, yOfs }
        defaults.points = {
            args,
        }
        return defaults
    end
    return nil
end

local function InstallSafeFrameAnchoringHooks(frame)
    if type(hooksecurefunc) ~= "function" then
        return
    end

    if not (frame and frame.SetPoint and frame.ClearAllPoints) then
        return
    end

    if frame._ffSafeAnchoringHooksInstalled == true then
        return
    end
    frame._ffSafeAnchoringHooksInstalled = true

    hooksecurefunc(frame, "ClearAllPoints", function(self)
        if self._ffSafeAnchoringInternal == true then
            return
        end

        local defaults = self._ffPointDefaults
        if type(defaults) ~= "table" then
            defaults = {}
            self._ffPointDefaults = defaults
        end

        defaults.points = {}
    end)

    hooksecurefunc(frame, "SetPoint", function(self, ...)
        if self._ffSafeAnchoringInternal == true then
            return
        end

        local defaults = self._ffPointDefaults
        if type(defaults) ~= "table" then
            defaults = {}
            self._ffPointDefaults = defaults
        end

        if type(defaults.points) ~= "table" then
            defaults.points = {}
        end

        local n = select("#", ...)
        if n <= 0 then
            return
        end

        local args = { n = n, ... }
        local point = args[1]
        if point == nil then
            return
        end

        -- Deduplicate per anchor point, but preserve call order:
        -- if a point is set again, move it to the end.
        for i = #defaults.points, 1, -1 do
            local existing = defaults.points[i]
            local existingPoint = existing and existing[1]
            if existingPoint == point then
                table.remove(defaults.points, i)
            end
        end

        defaults.points[#defaults.points + 1] = args

    end)
end

local function EnsureRevertingPointState(frame)
    if not frame then
        return
    end

    if frame._ffSafeAnchoringHooksInstalled ~= true then
        local defaults = CapturePointDefaults(frame)
        if type(defaults) ~= "table" then
            defaults = {}
        end
        if type(defaults.points) ~= "table" then
            defaults.points = {}
        end
        frame._ffPointDefaults = defaults
        InstallSafeFrameAnchoringHooks(frame)
    elseif type(frame._ffPointDefaults) ~= "table" then
        frame._ffPointDefaults = { points = {} }
    elseif type(frame._ffPointDefaults.points) ~= "table" then
        frame._ffPointDefaults.points = {}
    end
end

function Object:RevertingClearAllPoints(frame)
    if not (frame and frame.ClearAllPoints and frame.SetPoint) then
        return false
    end

    EnsureRevertingPointState(frame)

    frame._ffSafeAnchoringInternal = true
    local ok = pcall(frame.ClearAllPoints, frame)
    frame._ffSafeAnchoringInternal = false

    if ok then
        frame._ffPointCustomized = true
    end

    return ok == true
end

function Object:SetRevertingPoint(frame, ...)
    if not (frame and frame.ClearAllPoints and frame.SetPoint) then
        return false
    end

    EnsureRevertingPointState(frame)

    frame._ffSafeAnchoringInternal = true
    local ok = pcall(frame.SetPoint, frame, ...)
    frame._ffSafeAnchoringInternal = false

    if ok then
        frame._ffPointCustomized = true
    end

    return ok == true
end

local function CaptureFontDefaults(fontString)
    if not (fontString and fontString.GetFont) then
        return nil
    end

    local okFont, fontFile, size, flags = pcall(fontString.GetFont, fontString)
    if not okFont then
        return nil
    end

    local n = flags ~= nil and 3 or 2
    return { n = n, fontFile, size, flags }
end

local function CaptureFontColorDefaults(fontString)
    if not (fontString and fontString.GetTextColor) then
        return nil
    end

    local okColor, r, g, b, a = pcall(fontString.GetTextColor, fontString)
    if not okColor then
        return nil
    end

    local n = a ~= nil and 4 or 3
    return { n = n, r, g, b, a }
end

local function InstallRevertingFontHooks(fontString)
    if type(hooksecurefunc) ~= "function" then
        return
    end

    if not fontString then
        return
    end

    if fontString._ffSafeFontHooksInstalled == true then
        return
    end
    fontString._ffSafeFontHooksInstalled = true

    if not fontString.SetFont then
        return
    end

    hooksecurefunc(fontString, "SetFont", function(self, ...)
        if self._ffSafeFontInternal == true then
            return
        end
        local n = select("#", ...)
        if n < 2 then
            return
        end

        self._ffFontDefaults = { n = n, ... }
    end)

    hooksecurefunc(fontString, "SetFontHeight", function(self, ...)
        if self._ffSafeFontInternal == true then
            return
        end

        if self.GetFont then
            local defaults = CaptureFontDefaults(self)
            if type(defaults) == "table" then
                self._ffFontDefaults = defaults
            end
        end
    end)
end

local function InstallRevertingFontColorHooks(fontString)
    if type(hooksecurefunc) ~= "function" then
        return
    end

    if not fontString then
        return
    end

    if fontString._ffSafeFontColorHooksInstalled == true then
        return
    end
    fontString._ffSafeFontColorHooksInstalled = true

    if not fontString.SetTextColor then
        return
    end

    hooksecurefunc(fontString, "SetTextColor", function(self, ...)
        if self._ffSafeFontInternal == true then
            return
        end

        local n = select("#", ...)
        if n <= 0 then
            return
        end

        self._ffFontColorDefaults = { n = n, ... }
    end)
end

function Object:SetRevertingFont(fontString, ...)
    if not (fontString and fontString.SetFont) then
        return false
    end

    if fontString._ffSafeFontHooksInstalled ~= true then
        if fontString.GetFont then
            local defaults = CaptureFontDefaults(fontString)
            if type(defaults) == "table" then
                fontString._ffFontDefaults = defaults
            end
        end
        InstallRevertingFontHooks(fontString)
    end

    fontString._ffSafeFontInternal = true
    local ok = pcall(fontString.SetFont, fontString, ...)
    fontString._ffSafeFontInternal = false

    if ok then
        fontString._ffFontCustomized = true
    end

    return ok == true
end

function Object:RevertCustomFont(fontString)
    if not (fontString and fontString.SetFont) then
        return false
    end

    local args = fontString._ffFontDefaults
    if type(args) ~= "table" then
        return false
    end

    local n = args.n
    if type(n) ~= "number" or n <= 0 then
        return false
    end

    fontString._ffSafeFontInternal = true
    pcall(fontString.SetFont, fontString, unpack(args, 1, n))
    fontString._ffSafeFontInternal = false

    fontString._ffFontCustomized = false
    return true
end

function Object:SetRevertingTextColor(fontString, ...)
    if not (fontString and fontString.SetTextColor) then
        return false
    end

    if fontString._ffSafeFontColorHooksInstalled ~= true then
        if fontString.GetTextColor then
            local defaults = CaptureFontColorDefaults(fontString)
            if type(defaults) == "table" then
                fontString._ffFontColorDefaults = defaults
            end
        end
        InstallRevertingFontColorHooks(fontString)
    end

    fontString._ffSafeFontInternal = true
    local ok = pcall(fontString.SetTextColor, fontString, ...)
    fontString._ffSafeFontInternal = false

    if ok then
        fontString._ffFontColorCustomized = true
    end

    return ok == true
end

function Object:RevertCustomFontColor(fontString)
    if not (fontString and fontString.SetTextColor) then
        return false
    end

    local args = fontString._ffFontColorDefaults
    if type(args) ~= "table" then
        return false
    end

    local n = args.n
    if type(n) ~= "number" or n <= 0 then
        return false
    end

    fontString._ffSafeFontInternal = true
    pcall(fontString.SetTextColor, fontString, unpack(args, 1, n))
    fontString._ffSafeFontInternal = false

    fontString._ffFontColorCustomized = false
    return true
end

function Object:RevertCustomPoint(frame)
    if not (frame and frame.ClearAllPoints and frame.SetPoint) then
        return false
    end

    local defaults = frame._ffPointDefaults
    if defaults == nil then
        return false
    end

    local points = type(defaults.points) == "table" and defaults.points or {}

    frame._ffSafeAnchoringInternal = true

    local allOk = true
    local okClear = pcall(frame.ClearAllPoints, frame)
    if not okClear then
        frame._ffSafeAnchoringInternal = false
        return false
    end

    Object:Log("Reverting to default point for frame", {
        frame = frame,
        points = points
    })

    for i, args in ipairs(points) do
        local n = type(args) == "table" and args.n
        if type(n) == "number" and n > 0 then
            local okPoint, err = pcall(frame.SetPoint, frame, unpack(args, 1, n))
            if not okPoint then
                allOk = false
                Object:Log("ERROR: SetPoint", {
                    frame = frame,
                    index = i,
                    args = args,
                    error = err,
                })
            end
        end
    end

    frame._ffSafeAnchoringInternal = false

    if allOk then
        frame._ffPointCustomized = false
    end

    return allOk
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

function Object:ClampInteger(value, minValue, maxValue, fallback)
    local num = self:ClampNumber(value, minValue, maxValue, fallback)
    return math.floor(num + 0.5)
end

function Object:RoundToDecimals(value, decimals, fallback)
    local num = value
    if type(num) ~= "number" then
        num = tonumber(num)
    end
    if type(num) ~= "number" then
        num = fallback
    end
    if type(num) ~= "number" then
        return nil
    end

    local places = decimals
    if type(places) ~= "number" then
        places = tonumber(places)
    end
    if type(places) ~= "number" then
        places = 0
    end
    places = math.floor(places + 0.5)
    if places < 0 then
        places = 0
    end

    local multiplier = 10 ^ places
    return math.floor((num * multiplier) + 0.5) / multiplier
end

function Object:SanitizeOption(value, options)
    if value == nil then
        return nil
    end
    if type(options) ~= "table" then
        return nil
    end

    if options[value] ~= nil then
        return value
    end

    return nil
end

function Object:SanitizeAxis(value, fallback)
    return self:SanitizeLayoutAxis(value, fallback)
end

function Object:SanitizeLayoutAxis(value, fallback)
    return self:SanitizeOption(value, Constants.LAYOUT_AXIS) or fallback
end

function Object:SanitizeGrowthDirection(value, fallback)
    return self:SanitizeOption(value, Constants.GROWTH_DIRECTIONS) or fallback
end

function Object:SanitizeAnchorPoint(value, fallback)
    return self:SanitizeOption(value, Constants.ANCHOR_POINTS) or fallback
end

function Object:SanitizeAnchorMode(value, fallback)
    local mode = value

    -- Compatibility: old "OUTSIDE" mode was renamed to AUTO.
    if mode == "OUTSIDE" then
        mode = Constants.ANCHOR_MODES.AUTO
    end

    return self:SanitizeOption(mode, Constants.ANCHOR_MODES) or fallback
end

function Object:SanitizeColor(value, fallback)
    local fallbackColor = fallback
    if type(fallbackColor) ~= "table" then
        fallbackColor = { r = 1, g = 1, b = 1 }
    end

    local color = value
    if type(color) ~= "table" then
        color = fallbackColor
    end

    return {
        r = self:ClampNumber(color.r, 0, 1, fallbackColor.r or 1),
        g = self:ClampNumber(color.g, 0, 1, fallbackColor.g or 1),
        b = self:ClampNumber(color.b, 0, 1, fallbackColor.b or 1),
    }
end

function Object:SanitizeBoolean(value, fallback)
    if value == nil then
        return fallback
    end
    return value == true
end

function Object:SanitizeOpacity(value, fallback)
    local sanitizedFallback = self:ClampNumber(fallback, 0, 1, 1)
    local opacity = self:ClampNumber(value, 0, 1, sanitizedFallback)
    return self:RoundToDecimals(opacity, 2, sanitizedFallback)
end

function Object:IsAnchorRightAligned(point)
    return point == anchorPoints.TOPRIGHT or point == anchorPoints.RIGHT or point == anchorPoints.BOTTOMRIGHT
end

function Object:IsAnchorLeftAligned(point)
    return point == anchorPoints.TOPLEFT or point == anchorPoints.LEFT or point == anchorPoints.BOTTOMLEFT
end

function Object:IsAnchorTopAligned(point)
    return point == anchorPoints.TOPLEFT or point == anchorPoints.TOP or point == anchorPoints.TOPRIGHT
end

function Object:IsAnchorBottomAligned(point)
    return point == anchorPoints.BOTTOMLEFT or point == anchorPoints.BOTTOM or point == anchorPoints.BOTTOMRIGHT
end

function Object:IsAnchorVerticalAligned(point)
    return point == anchorPoints.LEFT or point == anchorPoints.CENTER or point == anchorPoints.RIGHT
end

function Object:IsAnchorHorizontalAligned(point)
    return point == anchorPoints.TOP or point == anchorPoints.CENTER or point == anchorPoints.BOTTOM
end

local function FlipVerticalAnchorPoint(point)
    return flipVerticalAnchorPoints[point] or point
end

local function FlipHorizontalAnchorPoint(point)
    return flipHorizontalAnchorPoints[point] or point
end

function Object:FlipVerticalAnchorPoint(point)
    return FlipVerticalAnchorPoint(point)
end

function Object:FlipHorizontalAnchorPoint(point)
    return FlipHorizontalAnchorPoint(point)
end

function Object:FlipToRelativeOffsets(offsetX, offsetY, point)
    local x = offsetX
    local y = offsetY

    if self:IsAnchorRightAligned(point) and type(x) == "number" then
        x = -x
    end

    if (self:IsAnchorTopAligned(point) or self:IsAnchorVerticalAligned(point)) and type(y) == "number" then
        y = -y
    end

    return x, y
end

function Object:EnsureFontString(region)
    if not region then
        return nil
    end

    local isObjectType = region.IsObjectType
    if type(isObjectType) == "function" then
        local ok, isFontString = pcall(isObjectType, region, "FontString")
        if ok and isFontString then
            return region
        end
        return nil
    end

    local getObjectType = region.GetObjectType
    if type(getObjectType) == "function" then
        local ok, objectType = pcall(getObjectType, region)
        if ok and objectType == "FontString" then
            return region
        end
    end

    return nil
end

function Object:EnsureTexturePath(statusBar)
    if not (statusBar and statusBar.GetStatusBarTexture) then
        return nil
    end

    local textureObject = statusBar:GetStatusBarTexture()
    if not (textureObject and textureObject.GetTexture) then
        return nil
    end

    local ok, textureRef = pcall(textureObject.GetTexture, textureObject)
    if not ok then
        return nil
    end

    if type(textureRef) == "number" then
        return textureRef
    end

    if type(textureRef) == "string" and textureRef ~= "" then
        return textureRef
    end

    return nil
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
