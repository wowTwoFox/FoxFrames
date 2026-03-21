local addonName, addon = ...

local Object = {}
Object.__index = Object

function Object:New()
    local instance = setmetatable({}, Object)
    return instance
end

local constants = Object:New()

local anchorPoints = {
    TOPLEFT = "TOPLEFT",
    TOP = "TOP",
    TOPRIGHT = "TOPRIGHT",
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOM = "BOTTOM",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

local flipVerticalAnchorPoints = {
    [anchorPoints.TOPLEFT] = anchorPoints.BOTTOMLEFT,
    [anchorPoints.TOP] = anchorPoints.BOTTOM,
    [anchorPoints.TOPRIGHT] = anchorPoints.BOTTOMRIGHT,
    [anchorPoints.LEFT] = anchorPoints.LEFT,
    [anchorPoints.CENTER] = anchorPoints.CENTER,
    [anchorPoints.RIGHT] = anchorPoints.RIGHT,
    [anchorPoints.BOTTOMLEFT] = anchorPoints.TOPLEFT,
    [anchorPoints.BOTTOM] = anchorPoints.TOP,
    [anchorPoints.BOTTOMRIGHT] = anchorPoints.TOPRIGHT,
}

local flipHorizontalAnchorPoints = {
    [anchorPoints.TOPLEFT] = anchorPoints.TOPRIGHT,
    [anchorPoints.TOP] = anchorPoints.TOP,
    [anchorPoints.TOPRIGHT] = anchorPoints.TOPLEFT,
    [anchorPoints.LEFT] = anchorPoints.RIGHT,
    [anchorPoints.CENTER] = anchorPoints.CENTER,
    [anchorPoints.RIGHT] = anchorPoints.LEFT,
    [anchorPoints.BOTTOMLEFT] = anchorPoints.BOTTOMRIGHT,
    [anchorPoints.BOTTOM] = anchorPoints.BOTTOM,
    [anchorPoints.BOTTOMRIGHT] = anchorPoints.BOTTOMLEFT,
}

local growthDirections = {
    UP = "UP",
    DOWN = "DOWN",
    LEFT = "LEFT",
    RIGHT = "RIGHT",
}

local layoutAxis = {
    HORIZONTAL = "HORIZONTAL",
    VERTICAL = "VERTICAL",
}

constants.ANCHOR_POINTS = anchorPoints
constants.FLIP_VERTICAL_ANCHOR_POINTS = flipVerticalAnchorPoints
constants.FLIP_HORIZONTAL_ANCHOR_POINTS = flipHorizontalAnchorPoints
constants.GROWTH_DIRECTIONS = growthDirections
constants.LAYOUT_AXIS = layoutAxis

constants.anchorPoints = anchorPoints
constants.flipVerticalAnchorPoints = flipVerticalAnchorPoints
constants.flipHorizontalAnchorPoints = flipHorizontalAnchorPoints
constants.growthDirections = growthDirections
constants.layoutAxis = layoutAxis

if addon then
    addon.Constants = constants
end
