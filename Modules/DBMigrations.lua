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

		local legacyValue = storage:GetValue(legacyPath)
		if legacyValue == nil then
			return
		end

		local sanitized = sanitize(legacyValue)
		if sanitized ~= nil then
			storage:SetValue(newPath, sanitized)
		end

		storage:SetValue(legacyPath, nil)
	end

	if profile.migrations.moveIncomingCastBarToPartyIncomingCasts ~= true then
		local legacy = storage:GetValuesTableAtPath("profile.incomingCastBar")
		local partyIncoming = storage:GetValuesTableAtPath("profile.partyFrame.incomingCasts")

		if type(legacy) == "table" then
			local shouldCopy = true
			if type(partyIncoming) == "table" then
				-- Treat any configured key as already migrated.
				for k, _ in pairs(partyIncoming) do
					shouldCopy = false
					break
				end

				if profile.migrations.moveTrackIncomingCastsToIncomingCastsEnabled ~= true then
					local legacy = storage:GetValue("profile.partyFrame.trackIncomingCasts")
					if legacy ~= nil then
						local enabledPath = "profile.partyFrame.incomingCasts.enabled"
						storage:SetValue(enabledPath, legacy == true)
						storage:SetValue("profile.partyFrame.trackIncomingCasts", nil)
					end

					profile.migrations.moveTrackIncomingCastsToIncomingCastsEnabled = true
					profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
				end
			end

			if shouldCopy then
				storage:SetValue("profile.partyFrame.incomingCasts", legacy)
			end

			-- Remove legacy table to avoid ambiguity going forward.
			storage:SetValue("profile.incomingCastBar", nil)
		end

		profile.migrations.moveIncomingCastBarToPartyIncomingCasts = true
		profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
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
					return v == true
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
					if type(v) ~= "table" then
						return nil
					end
					return Utils:SanitizeColor(v, nil)
				end
			)
		end

		profile.migrations.moveTextSettingsToTextGroup = true
		profile.migrationIndex = Utils:ClampInteger(profile.migrationIndex, 0, 9999, 0) + 1
	end
end
