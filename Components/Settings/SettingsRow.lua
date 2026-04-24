local addonName, addon = ...

assert(addon, "FoxFrames: addon table missing (load order issue)")

local Settings = _G["Settings"]

assert(Settings, "FoxFrames: Settings API missing")

local DEFAULT_FRAME_HEIGHT = 26

local DEFAULT_LABEL_OFFSET_LEFT = 37
local DEFAULT_LABEL_OFFSET_RIGHT = -85

-- Align with Blizzard/LibEQOL control placement
local DEFAULT_CONTENT_LEFT_OFFSET = -79
local DEFAULT_CONTENT_RIGHT_PADDING = -12

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

FoxFrames_SettingsRowMixin = CreateFromMixins(SettingsListElementMixin)

local function GetParentWidth(frame)
	local parent = frame and frame.GetParent and frame:GetParent() or nil
	if not (parent and parent.GetWidth) then
		return nil
	end
	local width = parent:GetWidth()
	if type(width) ~= "number" or width <= 0 then
		return nil
	end
	return width
end

local function AnchorContentWidget(widget, parent)
	if not (widget and parent) then
		return
	end
	if not (widget.ClearAllPoints and widget.SetPoint) then
		return
	end

	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", parent, "TOP", DEFAULT_CONTENT_LEFT_OFFSET, 0)
	widget:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", DEFAULT_CONTENT_RIGHT_PADDING, 0)
end

function FoxFrames_SettingsRowMixin:OnLoad()
	SettingsListElementMixin.OnLoad(self)

	self:SetHeight(DEFAULT_FRAME_HEIGHT)
	self:HookScript("OnShow", function(frame)
		if frame and frame.UpdateWidth then
			frame:UpdateWidth()
		end
	end)
end

function FoxFrames_SettingsRowMixin:UpdateWidth()
	local width = GetParentWidth(self)
	if width == nil then
		return
	end
	if self.SetWidth then
		self:SetWidth(width)
	end
end

function FoxFrames_SettingsRowMixin:Init(initializer)
	SettingsListElementMixin.Init(self, initializer)

	self.initializer = initializer
	self.data = initializer.data or {}
	self:SetLabelText(self.data.name)

	local createContent = self.data.createContent
	assert(type(createContent) == "function", "FoxFrames: SettingsRow requires data.createContent")
	local result = createContent(self)
	if result ~= nil then
		self:SetContentWidget(result)
		return
	end

	self:EvaluateState()
end

function FoxFrames_SettingsRowMixin:SetLabelText(text)
	if not self.Text then
		return
	end

	local label = (type(text) == "string" or type(text) == "number") and tostring(text) or ""

	self.Text:SetFontObject("GameFontNormal")
	self.Text:SetText(label)
	self.Text:ClearAllPoints()
	local textLeft = (self:GetIndent() or 0) + DEFAULT_LABEL_OFFSET_LEFT
	self.Text:SetPoint("LEFT", textLeft, 0)
	self.Text:SetPoint("RIGHT", self, "CENTER", DEFAULT_LABEL_OFFSET_RIGHT, 0)
end

function FoxFrames_SettingsRowMixin:SetContentWidget(widget)
	if widget == nil then
		return
	end

	if self.ContentWidget and self.ContentWidget ~= widget then
		if self.ContentWidget.Hide then
			self.ContentWidget:Hide()
		end
	end

	self.ContentWidget = widget

	local parent = self.Content or self
	if widget.SetParent then
		widget:SetParent(parent)
	end

	-- Settings list elements are recycled; ensure widgets aren't still anchored to a prior row's frame.
	AnchorContentWidget(widget, parent)

	if widget.Show then
		widget:Show()
	end

	self:UpdateHeightFromContentWidget()
end

function FoxFrames_SettingsRowMixin:UpdateHeightFromContentWidget()
	local desiredHeight = DEFAULT_FRAME_HEIGHT
	local widget = self.ContentWidget

	if widget then
		if type(widget.UpdateFlowSize) == "function" then
			widget:UpdateFlowSize()
		end

		local measured = tonumber(widget._ffMeasuredHeight)
		if measured == nil and widget.GetHeight then
			local h = widget:GetHeight()
			measured = type(h) == "number" and h or nil
		end
		if measured and measured > desiredHeight then
			desiredHeight = measured
		end
	end

	if self.SetHeight then
		self:SetHeight(desiredHeight)
	end
end

function FoxFrames_SettingsRowMixin:IsRowEnabled()
	local enabled = true

	-- Respect the underlying Settings row state (including parent initializer rules).
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

local function ApplyEnabled(widget, enabled)
	if not widget then
		return
	end

	if widget.SetEnabled then
		widget:SetEnabled(enabled)
		return
	end

	if enabled then
		if widget.Enable then
			widget:Enable()
		end
	else
		if widget.Disable then
			widget:Disable()
		end
	end
end

function FoxFrames_SettingsRowMixin:EvaluateState()
	SettingsListElementMixin.EvaluateState(self)

	local enabled = self:IsRowEnabled()
	self:DisplayEnabled(enabled)

	if self.Text then
		self.Text:SetFontObject(enabled and "GameFontNormal" or "GameFontDisable")
	end

	ApplyEnabled(self.ContentWidget, enabled)
end

function addon:CreateSettingsRow(category, data)
	assert(category and data, "category and data required")
	assert(type(data) == "table", "FoxFrames: CreateSettingsRow requires data table")
	assert(data.build == nil, "FoxFrames: CreateSettingsRow does not support data.build")
	assert(type(data.createContent) == "function", "FoxFrames: CreateSettingsRow requires data.createContent")

	if data.createLabel ~= nil then
		assert(type(data.createLabel) == "function", "FoxFrames: CreateSettingsRow data.createLabel must be a function")
	end

	if data.createLabel == nil then
		assert(type(data.label) == "string", "FoxFrames: CreateSettingsRow requires data.label when data.createLabel is missing")
	end

	local initializer = Settings.CreateElementInitializer("FoxFrames_SettingsRowTemplate", data)

	if initializer.SetParentInitializer and data.parent then
		initializer:SetParentInitializer(data.parent, data.parentCheck)
	end

	if initializer.AddSearchTags and type(data.searchTags) == "string" and data.searchTags ~= "" then
		initializer:AddSearchTags(data.searchTags)
	end

	Settings.RegisterInitializer(category, initializer)
	return initializer
end
