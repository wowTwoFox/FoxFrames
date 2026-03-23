local addonName, addon = ...

assert(addon, "FoxFrames: addon table missing (load order issue)")

local Settings = _G["Settings"]
local SettingsInbound = _G["SettingsInbound"]
local SettingsPanel = _G["SettingsPanel"]

assert(Settings, "FoxFrames: Settings API missing")

local DEFAULT_FRAME_WIDTH = 280
local DEFAULT_FRAME_HEIGHT = 26
local DEFAULT_BUTTON_HEIGHT = 20

local DEFAULT_LABEL_OFFSET_LEFT = 37
local DEFAULT_LABEL_OFFSET_RIGHT = -85

local DEFAULT_BUTTON_LEFT_OFFSET = -74
local DEFAULT_BUTTON_RIGHT_PADDING = -12

local function RefreshSettingsLayout()
	if SettingsInbound and SettingsInbound.RepairDisplay then
		SettingsInbound.RepairDisplay()
		return
	end
	if SettingsPanel and SettingsPanel.RepairDisplay then
		SettingsPanel:RepairDisplay()
		return
	end
end

function addon:RefreshSettingsLayout()
	RefreshSettingsLayout()
end

local function EvalPredicate(predicate)
	if predicate == nil then
		return true
	end

	if type(predicate) == "function" then
		local ok, result = pcall(predicate)
		if not ok then
			return true
		end
		return result ~= false
	end

	return predicate ~= false
end

FoxFrames_SettingsButtonMixin = CreateFromMixins(SettingsListElementMixin)

function FoxFrames_SettingsButtonMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)

	self:SetSize(DEFAULT_FRAME_WIDTH, DEFAULT_FRAME_HEIGHT)

	local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	button:SetHeight(DEFAULT_BUTTON_HEIGHT)
	button:ClearAllPoints()
	button:SetPoint("LEFT", self, "CENTER", DEFAULT_BUTTON_LEFT_OFFSET, 0)
	button:SetPoint("RIGHT", self, "RIGHT", DEFAULT_BUTTON_RIGHT_PADDING, 0)
	button:SetMotionScriptsWhileDisabled(true)

	button:SetScript("OnClick", function()
		self:OnButtonClicked()
	end)

	button:SetScript("OnEnter", function(control)
		self:OnButtonEnter(control)
	end)

	button:SetScript("OnLeave", function()
		self:OnButtonLeave()
	end)

	self.Button = button
end

function FoxFrames_SettingsButtonMixin:Init(initializer)
	SettingsListElementMixin.Init(self, initializer)

	self.initializer = initializer
	self.data = initializer.data or {}

	self:ApplyLabel()
	self:ApplyButtonText()
	self:EvaluateState()
end

function FoxFrames_SettingsButtonMixin:ApplyLabel()
	if not self.Text then
		return
	end

	local data = self.data or {}
	local label = data.label or ""

	self.Text:SetFontObject("GameFontNormal")
	self.Text:SetText(label)
	self.Text:ClearAllPoints()
	local textLeft = (self:GetIndent() or 0) + DEFAULT_LABEL_OFFSET_LEFT
	self.Text:SetPoint("LEFT", textLeft, 0)
	self.Text:SetPoint("RIGHT", self, "CENTER", DEFAULT_LABEL_OFFSET_RIGHT, 0)
end

function FoxFrames_SettingsButtonMixin:ApplyButtonText()
	local btn = self.Button
	if not btn then
		return
	end

	local data = self.data or {}
	local text = data.text or ""
	btn:SetText(text)
end

function FoxFrames_SettingsButtonMixin:IsButtonEnabled()
	local enabled = true

	-- If the underlying Settings row is disabled by parent initializer
	-- or other internal rules, respect that.
	if type(self.IsEnabled) == "function" then
		enabled = self:IsEnabled() ~= false
	end

	if enabled then
		local data = self.data or {}
		if data.parentCheck then
			enabled = EvalPredicate(data.parentCheck)
		end
	end

	if enabled then
		local data = self.data or {}
		enabled = EvalPredicate(data.isEnabled)
	end

	return enabled
end

function FoxFrames_SettingsButtonMixin:EvaluateState()
	SettingsListElementMixin.EvaluateState(self)

	local enabled = self:IsButtonEnabled()
	self:DisplayEnabled(enabled)

	if self.Button then
		if enabled then
			self.Button:Enable()
		else
			self.Button:Disable()
		end
	end

	if self.Text then
		self.Text:SetFontObject(enabled and "GameFontNormal" or "GameFontDisable")
	end
end

function FoxFrames_SettingsButtonMixin:OnButtonClicked()
	if not self:IsButtonEnabled() then
		return
	end

	local data = self.data or {}
	local click = data.click
	if type(click) == "function" then
		click()
	end

	if data.refresh ~= false then
		RefreshSettingsLayout()
	end
end

function FoxFrames_SettingsButtonMixin:OnButtonEnter(control)
	local data = self.data or {}
	local desc = data.desc
	if type(desc) ~= "string" or desc == "" then
		return
	end

	GameTooltip:SetOwner(control, "ANCHOR_TOP")
	GameTooltip:SetText(desc, 1, 1, 1, 1)
	GameTooltip:Show()
end

function FoxFrames_SettingsButtonMixin:OnButtonLeave()
	GameTooltip:Hide()
end

function addon:CreateSettingsButton(category, data)
	assert(category and data, "category and data required")
	assert(type(data.label) == "string", "FoxFrames: CreateSettingsButton requires data.label")
	assert(type(data.text) == "string", "FoxFrames: CreateSettingsButton requires data.text")
	assert(type(data.click) == "function", "FoxFrames: CreateSettingsButton requires data.click")

	local initializer = Settings.CreateElementInitializer("FoxFrames_SettingsButtonTemplate", {
		label = data.label,
		text = data.text,
		click = data.click,
		desc = data.desc,
		isEnabled = data.isEnabled,
		parentCheck = data.parentCheck,
		refresh = data.refresh,
	})

	if initializer.SetParentInitializer and data.parent then
		initializer:SetParentInitializer(data.parent, data.parentCheck)
	end

	if initializer.AddSearchTags then
		initializer:AddSearchTags(data.label)
	end

	Settings.RegisterInitializer(category, initializer)
	return initializer
end
