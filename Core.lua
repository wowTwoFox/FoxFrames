local addonName, addon = ...

local FF = FoxFrames
local Utils = addon.Utils
local DB = addon.DB

-- PartyFrame layout updates can end up triggering Blizzard's GridLayout/Layouts while
-- some values are "secret" (e.g. during combat / edit mode) which then throws inside
-- Blizzard_SharedXML. Keep this debounced and only run when it's safe.
local partyLayoutScheduled = false
local partyLayoutDirty = false
local partyLayoutInProgress = false
local lastPartyLayoutReason = nil

local function IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame.editModeActive
end

local function SafeUpdatePartyFrameLayout()
    partyLayoutScheduled = false

    if partyLayoutInProgress then
        return
    end

    if not partyLayoutDirty then
        return
    end

    if not PartyFrame or type(PartyFrame.UpdateSpacingAndLayout) ~= "function" then
        partyLayoutDirty = false
        return
    end

    -- Don't try to force layout in restricted states.
    if (InCombatLockdown and InCombatLockdown()) or IsEditModeActive() then
        return
    end

    partyLayoutDirty = false
    partyLayoutInProgress = true

    local ok, err = pcall(function()
        if securecallfunction then
            securecallfunction(PartyFrame.UpdateSpacingAndLayout, PartyFrame)
        else
            PartyFrame:UpdateSpacingAndLayout()
        end
    end)

    partyLayoutInProgress = false

    if not ok and Utils and Utils.Log then
        Utils:Log("FoxFrames: PartyFrame layout update failed", {
            reason = lastPartyLayoutReason,
            error = err,
            inCombat = InCombatLockdown and InCombatLockdown() or nil,
            editMode = IsEditModeActive() or nil,
        })
    end
end

local function RequestPartyFrameLayoutUpdate(reason)
    lastPartyLayoutReason = reason or lastPartyLayoutReason
    partyLayoutDirty = true

    if partyLayoutScheduled then
        return
    end

    partyLayoutScheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, SafeUpdatePartyFrameLayout)
    else
        SafeUpdatePartyFrameLayout()
    end
end

local function RegisterLSMTextures()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then
        return
    end
end

local function ReassertPlayerFrameVisibility(_, unit)
    if unit and unit ~= "player" then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if FF and FF.ShowPlayerFrameIfNeeded then
        FF:ShowPlayerFrameIfNeeded()
    end
end

-- Update role icons on all frames
local function GroupChangeEvent(event, ...)
    if FF.RebuildIncomingCastUnitMap then
        FF:RebuildIncomingCastUnitMap()
    end

    ReassertPlayerFrameVisibility()

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
    RequestPartyFrameLayoutUpdate("UNIT_MODEL_CHANGED")
    ReassertPlayerFrameVisibility()
end

function FF:OnInitialize()
    -- Register as early as possible so we catch blocks that happen during initialization.
    self:RegisterEvent("ADDON_ACTION_BLOCKED")
    self:RegisterEvent("ADDON_ACTION_FORBIDDEN")

    DB:InitializeDB()
    self.DEFAULT_SETTINGS = DB.DEFAULT_SETTINGS

    -- Register Custom Textures with LSM if available
    RegisterLSMTextures()

    -- Register slash commands
    self:RegisterChatCommand("ff", "SlashCommand")
    self:RegisterChatCommand("foxframes", "SlashCommand")

    hooksecurefunc(CompactPartyFrame, "UpdateVisibility", function()
        FF:ShowPartyFrameIfNeeded()
    end)

    hooksecurefunc(PartyFrame, "SetPoint", function(...)
        -- Utils:Log("PartyFrame:SetPoint Called", { ... })
        -- This is needed to re-align the player frames
        RequestPartyFrameLayoutUpdate("PartyFrame:SetPoint")
    end)

    if PlayerFrame and PlayerFrame.HookScript then
        PlayerFrame:HookScript("OnShow", function()
            FF:ShowPlayerFrameIfNeeded()
        end)
    end

    if type(CompactUnitFrame_UpdateAuras) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            FF:ShowBuffCountdownIfNeededForFrame(frame)
            FF:ShowDebuffCountdownIfNeededForFrame(frame)
        end)
    end

    if type(_G["CompactUnitFrame_UpdateHealthText"]) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateHealthText", function(frame)
            FF:ApplyPlayerStatusSettingsForFrame(frame)
        end)
    end

    if type(_G["CompactUnitFrame_UpdateStatusText"]) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateStatusText", function(frame)
            FF:ApplyPlayerStatusSettingsForFrame(frame)
        end)
    end

    if type(_G["CompactUnitFrame_UpdateAll"]) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
            FF:ApplyPlayerStatusSettingsForFrame(frame)
        end)
    end

    if type(_G["CompactUnitFrame_UpdateName"]) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            FF:ApplyPlayerNameAnchorForFrame(frame)
            FF:ApplyPlayerNameColorForFrame(frame)
            FF:ApplyPlayerNameFontSizeForFrame(frame)
        end)
    end

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
    self:RegisterEvent("PLAYER_ENTERING_WORLD", GroupChangeEvent)
    self:RegisterEvent("UNIT_MODEL_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", ReassertPlayerFrameVisibility)
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", ReassertPlayerFrameVisibility)
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", ReassertPlayerFrameVisibility)
    self:RegisterEvent("UNIT_EXITED_VEHICLE", ReassertPlayerFrameVisibility)
    self:RegisterIncomingCastUnitEvents()

    -- Register internal messages
    self:RegisterMessage("FOXFRAMES_INCOMING_CASTS_UPDATED")

    if self.RebuildIncomingCastUnitMap then
        self:RebuildIncomingCastUnitMap()
    end

    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        self:UpdateRoleIcon(frame)
    end)

    -- Apply once after startup so status text exists before sizing it.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            self:ApplyPlayerStatusSettings()
            self:ApplyPlayerNameSettings()
        end)
    else
        self:ApplyPlayerStatusSettings()
        self:ApplyPlayerNameSettings()
    end
end

function FF:PLAYER_REGEN_ENABLED()
    -- If we skipped a layout update during combat, retry once combat drops.
    if partyLayoutDirty then
        RequestPartyFrameLayoutUpdate("PLAYER_REGEN_ENABLED")
    end

    if self.ShowPartyFrameIfNeeded then
        self:ShowPartyFrameIfNeeded()
    end

    ReassertPlayerFrameVisibility()
end

function FF:PLAYER_REGEN_DISABLED()
    if self.SetIncomingCastIndicatorPreviewEnabled then
        self:SetIncomingCastIndicatorPreviewEnabled(false)
    end
end

function FF:FOXFRAMES_INCOMING_CASTS_UPDATED(event, casterUnit, cast)
    if not self.UpdateIncomingCastIndicators then return end
    self:UpdateIncomingCastIndicators()
end

function FF:OnDisable()
    self:Print("Disabled.")

    if self.StopIncomingCastIndicatorPreviewStream then
        self:StopIncomingCastIndicatorPreviewStream()
    end

    self:UnregisterAllEvents()
end
