local addonName, addon = ...

local FF = FoxFrames
if not FF then
    return
end

FoxFramesSpellRulesPanelMixin = CreateFromMixins(SettingsListElementMixin)

local PANEL_HEIGHT = 350
local RULE_ROW_HEIGHT = 22
local SPELL_PANE_WIDTH = 300

local SPELL_RULE_SCHOOL_COLORS = {
    PHYSICAL = "|cFFFFE680",
    HOLY = "|cFFFFF0A0",
    FIRE = "|cFFFF6A3D",
    NATURE = "|cFF4DFF4D",
    FROST = "|cFF80E5FF",
    SHADOW = "|cFFB48CFF",
    ARCANE = "|cFF80B3FF",
    MIXED = "|cFFFFFFFF",
}

local SPELL_RULE_KNOWN_SCHOOL_BITS = {
    { bit = 1, school = "PHYSICAL" },
    { bit = 2, school = "HOLY" },
    { bit = 4, school = "FIRE" },
    { bit = 8, school = "NATURE" },
    { bit = 16, school = "FROST" },
    { bit = 32, school = "SHADOW" },
    { bit = 64, school = "ARCANE" },
}

local function NormalizeSpellRuleSpellId(value)
    local num = tonumber(value)
    if type(num) ~= "number" then
        return nil
    end

    num = math.floor(num + 0.5)
    if num <= 0 then
        return nil
    end

    return tostring(num)
end

local function GetSpellRulesTable()
    local profile = FF and FF.db and FF.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    if type(profile.spellRules) ~= "table" then
        profile.spellRules = {}
    end
    if type(profile.spellRules.rules) ~= "table" then
        profile.spellRules.rules = {}
    end

    return profile.spellRules.rules
end

local function BuildSpellRuleSummary(rule)
    local parts = {}
    if rule and rule.hideIncomingCasts == true then
        parts[#parts + 1] = "incoming casts"
    end
    if rule and rule.hideBuffs == true then
        parts[#parts + 1] = "buffs"
    end
    if rule and rule.hideDebuffs == true then
        parts[#parts + 1] = "debuffs"
    end

    if #parts == 0 then
        return "none"
    end

    return table.concat(parts, ", ")
end

local function MaskHasSchoolBit(mask, bit)
    if type(mask) ~= "number" or type(bit) ~= "number" or bit <= 0 then
        return false
    end

    local quotient = math.floor(mask / bit)
    return (quotient % 2) >= 1
end

local function GetSpellRuleNameAndTexture(spellId)
    local normalizedSpellId = NormalizeSpellRuleSpellId(spellId)
    if not normalizedSpellId then
        return "Unknown spell", nil
    end

    local spellIdNumber = tonumber(normalizedSpellId)
    local spellName
    local spellTexture

    if C_Spell then
        if C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(spellIdNumber)
        end
        if C_Spell.GetSpellTexture then
            spellTexture = C_Spell.GetSpellTexture(spellIdNumber)
        end
        if (not spellName or spellName == "") and C_Spell.RequestLoadSpellData then
            C_Spell.RequestLoadSpellData(spellIdNumber)
        end
    end

    if type(spellName) ~= "string" or spellName == "" then
        spellName = "Unknown spell"
    end

    return spellName, spellTexture
end

local function GetSpellRuleSchoolMask(spellId)
    local normalizedSpellId = NormalizeSpellRuleSpellId(spellId)
    if not normalizedSpellId then
        return nil
    end

    local spellIdNumber = tonumber(normalizedSpellId)
    if type(spellIdNumber) ~= "number" then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellIdNumber)
        if type(info) == "table" then
            local schoolMask = rawget(info, "schoolMask") or rawget(info, "school")
            schoolMask = tonumber(schoolMask)
            if type(schoolMask) == "number" and schoolMask > 0 then
                return math.floor(schoolMask + 0.5)
            end
        end
    end

    return nil
end

local function GetSpellRuleNameColorBySchool(spellId)
    local schoolMask = GetSpellRuleSchoolMask(spellId)
    if type(schoolMask) ~= "number" then
        return nil
    end

    local foundSchool = nil
    local schoolCount = 0
    for _, entry in ipairs(SPELL_RULE_KNOWN_SCHOOL_BITS) do
        if MaskHasSchoolBit(schoolMask, entry.bit) then
            foundSchool = entry.school
            schoolCount = schoolCount + 1
        end
    end

    if schoolCount <= 0 then
        return nil
    end

    if schoolCount > 1 then
        return SPELL_RULE_SCHOOL_COLORS.MIXED
    end

    return SPELL_RULE_SCHOOL_COLORS[foundSchool]
end

local function ColorizeSpellRuleName(spellName, spellId)
    local colorCode = GetSpellRuleNameColorBySchool(spellId)
    if type(colorCode) ~= "string" or colorCode == "" then
        return spellName
    end

    return string.format("%s%s|r", colorCode, spellName)
end

local function BuildSpellRuleDisplayLabel(spellId, rule)
    local spellName = GetSpellRuleNameAndTexture(spellId)
    local coloredSpellName = ColorizeSpellRuleName(spellName, spellId)

    return string.format("%s (%s) - %s", coloredSpellName, spellId, BuildSpellRuleSummary(rule))
end

function FoxFramesSpellRulesPanelMixin:OnLoad()
    SettingsListElementMixin.OnLoad(self)

    if self.Tooltip and self.Tooltip.HoverBackground then
        self.Tooltip.HoverBackground:SetAlpha(0)
    end

    self.ruleRows = {}
    self._selectedSpellId = nil

    self:SetHeight(PANEL_HEIGHT)

    self.SpellList = CreateFrame("Frame", nil, self)
    self.SpellList:SetPoint("TOPRIGHT", self, "TOPRIGHT", -12, -4)
    self.SpellList:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 8)
    self.SpellList:SetWidth(SPELL_PANE_WIDTH)
    self.SpellList:SetFrameStrata(self:GetFrameStrata())
    self.SpellList:SetFrameLevel((self:GetFrameLevel() or 0) + 10)

    self.SpellListBackground = self.SpellList:CreateTexture(nil, "BACKGROUND")
    self.SpellListBackground:SetAllPoints()
    self.SpellListBackground:SetColorTexture(0, 0, 0, 0.2)

    self.SpellListTitle = self.SpellList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.SpellListTitle:SetPoint("TOPLEFT", self.SpellList, "TOPLEFT", 10, -8)
    self.SpellListTitle:SetText("Spell Rules")

    self.RuleScroll = CreateFrame("ScrollFrame", nil, self.SpellList, "UIPanelScrollFrameTemplate")
    self.RuleScroll:SetPoint("TOPLEFT", self.SpellList, "TOPLEFT", 8, -28)
    self.RuleScroll:SetPoint("BOTTOMRIGHT", self.SpellList, "BOTTOMRIGHT", -27, 8)

    self.RuleContent = CreateFrame("Frame", nil, self.RuleScroll)
    self.RuleContent:SetPoint("TOPLEFT")
    self.RuleContent:SetSize(SPELL_PANE_WIDTH - 40, 1)
    self.RuleScroll:SetScrollChild(self.RuleContent)

    self.EmptyHint = self.SpellList:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.EmptyHint:SetPoint("TOPLEFT", self.RuleScroll, "TOPLEFT", 6, -6)
    self.EmptyHint:SetPoint("RIGHT", self.RuleScroll, "RIGHT", -6, 0)
    self.EmptyHint:SetJustifyH("LEFT")
    self.EmptyHint:SetText("No spell rules yet. Add one from the details pane.")

    self.RuleScroll:SetScript("OnSizeChanged", function()
        local contentWidth = (self.RuleScroll:GetWidth() or (SPELL_PANE_WIDTH - 40))
        if contentWidth < 1 then
            contentWidth = SPELL_PANE_WIDTH - 40
        end
        self.RuleContent:SetWidth(contentWidth)
    end)

    self.SpellDetails = CreateFrame("Frame", nil, self)
    self.SpellDetails:SetPoint("TOPLEFT", self, "TOPLEFT", 24, -4)
    self.SpellDetails:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 24, 8)
    self.SpellDetails:SetPoint("TOPRIGHT", self.SpellList, "TOPLEFT", -8, 0)
    self.SpellDetails:SetPoint("BOTTOMRIGHT", self.SpellList, "BOTTOMLEFT", -8, 0)
    self.SpellDetails:SetFrameStrata(self:GetFrameStrata())
    self.SpellDetails:SetFrameLevel((self:GetFrameLevel() or 0) + 10)

    self.SpellDetailsBackground = self.SpellDetails:CreateTexture(nil, "BACKGROUND")
    self.SpellDetailsBackground:SetAllPoints()
    self.SpellDetailsBackground:SetColorTexture(0, 0, 0, 0.0)

    self.SpellDetailsTitle = self.SpellDetails:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.SpellDetailsTitle:SetPoint("TOPLEFT", self.SpellDetails, "TOPLEFT", 10, -8)
    self.SpellDetailsTitle:SetText("Rule Details")

    self.SpellIdLabel = self.SpellDetails:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.SpellIdLabel:SetPoint("TOPLEFT", self.SpellDetails, "TOPLEFT", 10, -34)
    self.SpellIdLabel:SetText("Spell ID")

    self.SpellIdInput = CreateFrame("EditBox", nil, self.SpellDetails, "InputBoxTemplate")
    self.SpellIdInput:SetAutoFocus(false)
    self.SpellIdInput:SetPoint("TOPLEFT", self.SpellIdLabel, "BOTTOMLEFT", -2, -4)
    self.SpellIdInput:SetSize(140, 20)
    self.SpellIdInput:SetScript("OnEnterPressed", function(editBox)
        local spellId = NormalizeSpellRuleSpellId(editBox:GetText())
        if spellId then
            self:_SelectSpellId(spellId)
        end
        editBox:ClearFocus()
    end)

    self.HideIncomingCheck = CreateFrame("CheckButton", nil, self.SpellDetails, "UICheckButtonTemplate")
    self.HideIncomingCheck:SetPoint("TOPLEFT", self.SpellIdInput, "BOTTOMLEFT", 0, -8)
    if self.HideIncomingCheck.Text then
        self.HideIncomingCheck.Text:SetText("Filter incoming casts")
    end

    self.HideBuffsCheck = CreateFrame("CheckButton", nil, self.SpellDetails, "UICheckButtonTemplate")
    self.HideBuffsCheck:SetPoint("TOPLEFT", self.HideIncomingCheck, "BOTTOMLEFT", 0, -4)
    if self.HideBuffsCheck.Text then
        self.HideBuffsCheck.Text:SetText("Filter buffs")
    end

    self.HideDebuffsCheck = CreateFrame("CheckButton", nil, self.SpellDetails, "UICheckButtonTemplate")
    self.HideDebuffsCheck:SetPoint("TOPLEFT", self.HideBuffsCheck, "BOTTOMLEFT", 0, -4)
    if self.HideDebuffsCheck.Text then
        self.HideDebuffsCheck.Text:SetText("Filter debuffs")
    end

    self.SaveButton = CreateFrame("Button", nil, self.SpellDetails, "UIPanelButtonTemplate")
    self.SaveButton:SetSize(130, 22)
    self.SaveButton:SetPoint("TOPLEFT", self.HideDebuffsCheck, "BOTTOMLEFT", 2, -10)
    self.SaveButton:SetText("Add / Update")
    self.SaveButton:SetScript("OnClick", function()
        self:_SaveCurrentRule()
    end)

    self.RemoveButton = CreateFrame("Button", nil, self.SpellDetails, "UIPanelButtonTemplate")
    self.RemoveButton:SetSize(130, 22)
    self.RemoveButton:SetPoint("LEFT", self.SaveButton, "RIGHT", 8, 0)
    self.RemoveButton:SetText("Remove")
    self.RemoveButton:SetScript("OnClick", function()
        self:_RemoveCurrentRule()
    end)

    self.SelectedSummary = self.SpellDetails:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.SelectedSummary:SetPoint("TOPLEFT", self.SaveButton, "BOTTOMLEFT", 0, -10)
    self.SelectedSummary:SetPoint("RIGHT", self.SpellDetails, "RIGHT", -10, 0)
    self.SelectedSummary:SetJustifyH("LEFT")
    self.SelectedSummary:SetJustifyV("TOP")
    self.SelectedSummary:SetText("Select a spell rule from the spell list.")
end

function FoxFramesSpellRulesPanelMixin:Init(initializer)
    SettingsListElementMixin.Init(self, initializer)

    self.categoryID = initializer.data and initializer.data.categoryID

    if not self._callbacksRegistered then
        EventRegistry:RegisterCallback("Settings.Defaulted", self.RefreshRules, self)
        EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, category)
            if self.categoryID == category:GetID() then
                self:RefreshRules()
            end
        end, self)
        self._callbacksRegistered = true
    end

    self:RefreshRules()
end

function FoxFramesSpellRulesPanelMixin:_GetOrderedSpellIds()
    local rules = GetSpellRulesTable() or {}
    local spellIds = {}

    for spellId in pairs(rules) do
        spellIds[#spellIds + 1] = spellId
    end

    table.sort(spellIds, function(a, b)
        return tonumber(a) < tonumber(b)
    end)

    return spellIds
end

function FoxFramesSpellRulesPanelMixin:_CreateRow(index)
    local row = CreateFrame("Button", nil, self.RuleContent)
    row.layoutIndex = index
    row:SetFrameStrata(self.SpellList:GetFrameStrata())
    row:SetFrameLevel((self.SpellList:GetFrameLevel() or self:GetFrameLevel() or 0) + 2)
    row:SetHeight(RULE_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", self.RuleContent, "TOPLEFT", 2, -((index - 1) * RULE_ROW_HEIGHT))
    row:SetPoint("RIGHT", self.RuleContent, "RIGHT", -2, 0)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetAllPoints()
    row.Background:SetColorTexture(1, 1, 1, 0)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(16, 16)
    row.Icon:SetPoint("LEFT", row, "LEFT", 4, 0)

    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetMaxLines(1)

    row:SetScript("OnClick", function(button)
        self:_SelectSpellId(button.spellId)
    end)

    row:SetScript("OnEnter", function(button)
        if button.spellId ~= self._selectedSpellId then
            button.Background:SetColorTexture(1, 1, 1, 0.07)
        end
    end)

    row:SetScript("OnLeave", function(button)
        self:_RefreshRowState(button)
    end)

    return row
end

function FoxFramesSpellRulesPanelMixin:_RefreshRowState(row)
    if not row then
        return
    end

    if row.spellId == self._selectedSpellId then
        row.Background:SetColorTexture(1, 1, 1, 0.14)
    else
        row.Background:SetColorTexture(1, 1, 1, 0)
    end
end

function FoxFramesSpellRulesPanelMixin:_RefreshRuleRows()
    local rules = GetSpellRulesTable() or {}
    local spellIds = self:_GetOrderedSpellIds()

    local visibleCount = #spellIds
    for i = 1, visibleCount do
        local row = self.ruleRows[i]
        if not row then
            row = self:_CreateRow(i)
            self.ruleRows[i] = row
        end

        row.layoutIndex = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.RuleContent, "TOPLEFT", 2, -((i - 1) * RULE_ROW_HEIGHT))
        row:SetPoint("RIGHT", self.RuleContent, "RIGHT", -2, 0)

        local spellId = spellIds[i]
        row.spellId = spellId
        row.Text:SetText(BuildSpellRuleDisplayLabel(spellId, rules[spellId]))

        local _, spellTexture = GetSpellRuleNameAndTexture(spellId)
        row.Icon:SetTexture(spellTexture)
        row:Show()

        self:_RefreshRowState(row)
    end

    for i = visibleCount + 1, #self.ruleRows do
        local row = self.ruleRows[i]
        if row then
            row.spellId = nil
            row:Hide()
        end
    end

    local contentHeight = math.max(1, visibleCount * RULE_ROW_HEIGHT)
    local contentWidth = self.RuleScroll and self.RuleScroll:GetWidth() or (SPELL_PANE_WIDTH - 40)
    if type(contentWidth) ~= "number" or contentWidth < 1 then
        contentWidth = SPELL_PANE_WIDTH - 40
    end
    self.RuleContent:SetWidth(contentWidth)
    self.RuleContent:SetHeight(contentHeight)

    if self.EmptyHint then
        self.EmptyHint:SetShown(visibleCount == 0)
    end

    return spellIds
end

function FoxFramesSpellRulesPanelMixin:_UpdateEditorForSelection()
    local spellId = self._selectedSpellId
    if not spellId then
        self.SpellIdInput:SetText("")
        self.HideIncomingCheck:SetChecked(false)
        self.HideBuffsCheck:SetChecked(false)
        self.HideDebuffsCheck:SetChecked(false)
        self.SelectedSummary:SetText("Select a spell rule from the spell list.")
        return
    end

    local rules = GetSpellRulesTable() or {}
    local rule = rules[spellId] or {}

    self.SpellIdInput:SetText(spellId)
    self.HideIncomingCheck:SetChecked(rule.hideIncomingCasts == true)
    self.HideBuffsCheck:SetChecked(rule.hideBuffs == true)
    self.HideDebuffsCheck:SetChecked(rule.hideDebuffs == true)

    local spellName = GetSpellRuleNameAndTexture(spellId)
    local coloredName = ColorizeSpellRuleName(spellName, spellId)
    self.SelectedSummary:SetText(string.format("Selected: %s (%s)\nCurrent filters: %s", coloredName, spellId, BuildSpellRuleSummary(rule)))
end

function FoxFramesSpellRulesPanelMixin:_SelectSpellId(spellId)
    local normalizedSpellId = NormalizeSpellRuleSpellId(spellId)
    if not normalizedSpellId then
        return
    end

    self._selectedSpellId = normalizedSpellId
    self:_UpdateEditorForSelection()

    for _, row in ipairs(self.ruleRows) do
        self:_RefreshRowState(row)
    end
end

function FoxFramesSpellRulesPanelMixin:_NotifyRulesChanged()
    if FF.UpdateIncomingCastIndicators then
        FF:UpdateIncomingCastIndicators()
    end
    if FF.RefreshSpellRuleAuraFilters then
        FF:RefreshSpellRuleAuraFilters()
    end
end

function FoxFramesSpellRulesPanelMixin:_SaveCurrentRule()
    local spellId = NormalizeSpellRuleSpellId(self.SpellIdInput:GetText())
    if not spellId then
        return
    end

    local rules = GetSpellRulesTable()
    if not rules then
        return
    end

    rules[spellId] = {
        hideIncomingCasts = self.HideIncomingCheck:GetChecked() == true,
        hideBuffs = self.HideBuffsCheck:GetChecked() == true,
        hideDebuffs = self.HideDebuffsCheck:GetChecked() == true,
    }

    self._selectedSpellId = spellId
    self:_NotifyRulesChanged()
    self:RefreshRules()
end

function FoxFramesSpellRulesPanelMixin:_RemoveCurrentRule()
    local spellId = NormalizeSpellRuleSpellId(self._selectedSpellId) or NormalizeSpellRuleSpellId(self.SpellIdInput:GetText())
    if not spellId then
        return
    end

    local rules = GetSpellRulesTable()
    if not rules then
        return
    end

    rules[spellId] = nil

    if self._selectedSpellId == spellId then
        self._selectedSpellId = nil
    end

    self:_NotifyRulesChanged()
    self:RefreshRules()
end

function FoxFramesSpellRulesPanelMixin:RefreshRules()
    local spellIds = self:_RefreshRuleRows()

    if self._selectedSpellId and not (GetSpellRulesTable() or {})[self._selectedSpellId] then
        self._selectedSpellId = nil
    end

    if not self._selectedSpellId and #spellIds > 0 then
        self._selectedSpellId = spellIds[1]
    end

    self:_UpdateEditorForSelection()

    for _, row in ipairs(self.ruleRows) do
        self:_RefreshRowState(row)
    end
end
