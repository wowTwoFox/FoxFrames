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

Utils = Object:New()