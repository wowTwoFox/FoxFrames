-- FoxFrames DBMigrations
-- Contains all DB migration and sanitization logic for FoxFrames profiles/settings.

local addonName, addon = ...
local DB = addon.DB

-- The migration function will be injected into DB.lua
function DB:MigrateAndSanitizeDB()
end
