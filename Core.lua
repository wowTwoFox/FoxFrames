local addonName, addon = ...

local FF = FoxFrames

local oneTimePrint = true

local defaults = {
    profile = FF.DEFAULT_SETTINGS
}

local function RegisterLSMTextures()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then
        return
    end
end

local function OnUnitModelChanged(event, ...)
    -- This fixes an issue with the party frames being offset
    -- Caused by the frames being laid-out when the anchor points are set to TOPLEFT
    -- We fix it by re-applying the layout after the anchor points are correctly set
    PartyFrame:UpdateSpacingAndLayout()
end

-- Update role icons on all frames
local function GroupChangeEvent(event, ...)
    if not FF:InAllowedGroup() then
        return
    end

    Utils:Log("GROUP_CHANGE_EVENT")
    FF:UpdateFrames()
end

function FF:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("FoxFramesDB", defaults, true)

    -- Register Custom Textures with LSM if available
    RegisterLSMTextures()

    -- Register slash commands
    self:RegisterChatCommand("ff", "SlashCommand")
    self:RegisterChatCommand("foxframes", "SlashCommand")

    hooksecurefunc(CompactPartyFrame, "UpdateVisibility", function()
        FF:ShowPartyFrameIfNeeded()
    end)

    hooksecurefunc(CompactPartyFrame:GetParent(), "SetPoint", function(...)
        Utils:Log("PartyFrame:SetPoint Called", { ... })
        -- This is needed to re-align the player frames
        CompactPartyFrame:GetParent():UpdateSpacingAndLayout()
    end)

    Utils:Log("CompactPartyFrame", CompactPartyFrame)
    Utils:Log("EditModeManagerFrame", EditModeManagerFrame)
    Utils:Log("PartyFrame", PartyFrame)
    Utils:Log("Player Frame", PlayerFrame)

    -- Setup options
    self:SetupOptions()
    self:SetupFrames()
    Utils:Log("FOX_FRAMES_LOADED")
end

function FF:OnEnable()
    -- Register events for role changes
    self:RegisterEvent("GROUP_ROSTER_UPDATE", GroupChangeEvent)
    self:RegisterEvent("PARTY_LEADER_CHANGED", GroupChangeEvent)
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", GroupChangeEvent)
    self:RegisterEvent("COMPACT_UNIT_FRAME_PROFILES_LOADED", GroupChangeEvent)
    self:RegisterEvent("UNIT_MODEL_CHANGED", OnUnitModelChanged)

    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        self:UpdateRoleIcon(frame)
    end)

    if self:InAllowedGroup() then
        -- Apply anchor point on enable
        self:GroupChangeEvent("INITIAL_STARTUP")
    end
end

function FF:OnDisable()
    self:Print("Disabled.")
    self:UnregisterAllEvents()
end