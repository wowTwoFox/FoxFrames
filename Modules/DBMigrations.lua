-- FoxFrames DBMigrations
-- Contains all DB migration and sanitization logic for FoxFrames profiles/settings.

local addonName, addon = ...
local DB = addon.DB
local Utils = addon.Utils

-- The migration function will be injected into DB.lua
function DB:MigrateAndSanitizeDB()
	local storage = self.storage
	if not storage then
		return
	end

	local profile = storage:GetValuesTableAtPath("profile")
	if type(profile) ~= "table" then
		return
	end

	profile.migrations = type(profile.migrations) == "table" and profile.migrations or {}

	local function MigrateValue(legacyPath, newPath, sanitize)
		if type(legacyPath) ~= "string" or legacyPath == "" then
			return
		end
		if type(newPath) ~= "string" or newPath == "" then
			return
		end
		if type(sanitize) ~= "function" then
			return
		end

		local legacyValue = storage:GetValueAtPath(legacyPath)
		if legacyValue == nil then
			return
		end

		local sanitized = sanitize(legacyValue)
		if sanitized ~= nil then
			storage:SetValue(newPath, sanitized)
		end

		storage:SetValue(legacyPath, nil)
	end

	if profile.migrations.moveTextSettingsToTextGroup ~= true then
		local paths = {
			"profile.partyFrame.playerName",
			"profile.partyFrame.playerStatus",
			"profile.raidFrame.playerName",
			"profile.raidFrame.playerStatus",
		}

		for _, basePath in ipairs(paths) do
			MigrateValue(
				basePath .. ".useClassColors",
				basePath .. ".text.useClassColors",
				function(v)
					return Utils:SanitizeBoolean(v, false)
				end
			)

			MigrateValue(
				basePath .. ".fontSize",
				basePath .. ".text.fontSize",
				function(v)
					return Utils:ClampInteger(v, 8, 32, nil)
				end
			)

			MigrateValue(
				basePath .. ".opacity",
				basePath .. ".text.opacity",
				function(v)
					return Utils:SanitizeOpacity(v, nil)
				end
			)

			MigrateValue(
				basePath .. ".color",
				basePath .. ".text.color",
				function(v)
					return Utils:SanitizeColor(v, nil)
				end
			)
		end

		profile.migrations.moveTextSettingsToTextGroup = true
		profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
	end

	if profile.migrations.groupPartyFrameHealthBarSettings ~= true then
		local legacyUseCustomPath = "profile.partyFrame.useCustomHealthBarTexture"
		local newUseCustomPath = "profile.partyFrame.healthBar.useCustomTexture"
		MigrateValue(legacyUseCustomPath, newUseCustomPath, function(v)
			return Utils:SanitizeBoolean(v, false)
		end)

		local legacyTexturePath = "profile.partyFrame.healthBarTexture"
		local newTexturePath = "profile.partyFrame.healthBar.texture"
		MigrateValue(legacyTexturePath, newTexturePath, function(v)
			return Utils:SanitizeString(v, nil, true)
		end)

		profile.migrations.groupPartyFrameHealthBarSettings = true
		profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
	end

	if profile.migrations.groupPartyFrameRoleIconsSettings ~= true then
		local keys = {
			"showTankRoleIcon",
			"showHealerRoleIcon",
			"showDPSRoleIcon",
		}

		for _, key in ipairs(keys) do
			local legacyPath = "profile.partyFrame." .. key
			local newPath = "profile.partyFrame.roleIcons." .. key
			MigrateValue(legacyPath, newPath, function(v)
				return Utils:SanitizeBoolean(v, true)
			end)
		end

		profile.migrations.groupPartyFrameRoleIconsSettings = true
		profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
	end

	-- Targetted Spells / Incoming Casts feature was removed (client "secret" restrictions).
	-- Purge any leftover profile keys so they don't linger in saved variables.
	if profile.migrations.removeIncomingCastsSettings ~= true then
		storage:SetValue("profile.partyFrame.incomingCasts", nil)
		storage:SetValue("profile.raidFrame.incomingCasts", nil)

		profile.migrations.removeIncomingCastsSettings = true
		profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
	end
end
