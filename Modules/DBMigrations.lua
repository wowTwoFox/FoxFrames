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
						local current = storage:GetValue(enabledPath)
						if current == nil then
							storage:SetValue(enabledPath, legacy == true)
						end
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
end
