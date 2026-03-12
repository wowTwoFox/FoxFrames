local addonName, addon = ...

local FF = FoxFrames
local Utils = addon and addon.Utils

local function RegisterLSMTextures()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then
        return
    end
end

-- Update role icons on all frames
local function GroupChangeEvent(event, ...)
    if FF.RebuildIncomingCastUnitMap then
        FF:RebuildIncomingCastUnitMap()
    end

    if not FF:InAllowedGroup() then
        return
    end

    -- Utils:Log("GROUP_CHANGE_EVENT", event)
    FF:UpdateFrames()

    if FF.SetupIncomingCastIndicators then
        FF:SetupIncomingCastIndicators()
    end
    if FF.UpdateIncomingCastIndicators then
        FF:UpdateIncomingCastIndicators()
    end
end

function FF:ADDON_ACTION_BLOCKED(event, blockedAddon, blockedFunction)
    Utils:LogBlockedAddon(event, blockedAddon, blockedFunction)
end

function FF:ADDON_ACTION_FORBIDDEN(event, blockedAddon, blockedFunction)
    Utils:LogBlockedAddon(event, blockedAddon, blockedFunction)
end

function FF:UNIT_MODEL_CHANGED(event, ...)
    -- This fixes an issue with the party frames being offset
    -- Caused by the frames being laid-out when the anchor points are set to TOPLEFT
    -- We fix it by re-applying the layout after the anchor points are correctly set
    PartyFrame:UpdateSpacingAndLayout()
end

function FF:OnInitialize()
    -- Register as early as possible so we catch blocks that happen during initialization.
    self:RegisterEvent("ADDON_ACTION_BLOCKED")
    self:RegisterEvent("ADDON_ACTION_FORBIDDEN")

    local defaults = {
        profile = FF.DEFAULT_SETTINGS or {},
    }

    self.db = LibStub("AceDB-3.0"):New("FoxFramesDB", defaults, true)

    -- Register Custom Textures with LSM if available
    RegisterLSMTextures()

    -- Register slash commands
    self:RegisterChatCommand("ff", "SlashCommand")
    self:RegisterChatCommand("foxframes", "SlashCommand")
    self:RegisterChatCommand("ffpreview", "PreviewSlashCommand")

    hooksecurefunc(CompactPartyFrame, "UpdateVisibility", function()
        FF:ShowPartyFrameIfNeeded()
    end)

    hooksecurefunc(PartyFrame, "SetPoint", function(...)
        -- Utils:Log("PartyFrame:SetPoint Called", { ... })
        -- This is needed to re-align the player frames
        PartyFrame:UpdateSpacingAndLayout()
    end)

    -- Utils:Log("CompactPartyFrame", CompactPartyFrame)
    -- Utils:Log("EditModeManagerFrame", EditModeManagerFrame)
    -- Utils:Log("PartyFrame", PartyFrame)
    -- Utils:Log("Player Frame", PlayerFrame)

    -- Setup options
    self:SetupOptions()
    self:SetupFrames()
    -- Utils:Log("FOX_FRAMES_LOADED", FF)
end

function FF:OnEnable()
    -- Register events for role changes
    self:RegisterEvent("GROUP_ROSTER_UPDATE", GroupChangeEvent)
    self:RegisterEvent("PARTY_LEADER_CHANGED", GroupChangeEvent)
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", GroupChangeEvent)
    self:RegisterEvent("COMPACT_UNIT_FRAME_PROFILES_LOADED", GroupChangeEvent)
    self:RegisterEvent("UNIT_MODEL_CHANGED")
    self:RegisterIncomingCastUnitEvents()

    -- Register internal messages
    self:RegisterMessage("FOXFRAMES_INCOMING_CASTS_UPDATED")

    if self.RebuildIncomingCastUnitMap then
        self:RebuildIncomingCastUnitMap()
    end

    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        self:UpdateRoleIcon(frame)
    end)
end

function FF:FOXFRAMES_INCOMING_CASTS_UPDATED(event, casterUnit, cast)
    if not self.UpdateIncomingCastIndicators then return end
    self:UpdateIncomingCastIndicators()
end

function FF:OnDisable()
    self:Print("Disabled.")
    self:UnregisterAllEvents()
end