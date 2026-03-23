local addonName, addon = ...

assert(addon, "FoxFrames: addon table missing (load order issue)")

local ComponentBuilder = addon.SettingsComponentBuilder

assert(ComponentBuilder, "FoxFrames: SettingsComponentBuilder missing (load order issue)")
assert(type(ComponentBuilder.CreateButton) == "function", "FoxFrames: SettingsComponentBuilder missing CreateButton")
assert(type(ComponentBuilder.CreateInput) == "function", "FoxFrames: SettingsComponentBuilder missing CreateInput")
assert(type(ComponentBuilder.CreateToggle) == "function", "FoxFrames: SettingsComponentBuilder missing CreateToggle")
assert(type(ComponentBuilder.CreateDropdown) == "function", "FoxFrames: SettingsComponentBuilder missing CreateDropdown")

local DEFAULT_CHILD_X_PADDING = 4
local DEFAULT_CHILD_Y_PADDING = 0

local DEFAULT_FLOW_DIRECTION = "vertical"

local function NormalizeFlowDirection(direction)
	if direction == nil then
		return DEFAULT_FLOW_DIRECTION
	end

	assert(direction == "horizontal" or direction == "vertical", "FoxFrames: invalid flow direction")
	return direction
end

local function ApplyMixinSafe(target, mixin)
	if not (target and mixin) then
		return
	end
	Mixin(target, mixin)
end

local function LayoutNow(frame)
	if not frame then
		return
	end

	if frame.Layout then
		frame:Layout()
		return
	end

	if frame.MarkDirty then
		frame:MarkDirty()
		return
	end
end

local function SetEnabledRecursive(widget, enabled)
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

FoxFrames_SettingsFlowMixin = {}

function FoxFrames_SettingsFlowMixin:Layout()
	local frames = self._ffFlowFrames
	local count = tonumber(self._ffFlowCount) or 0
	if type(frames) ~= "table" or count <= 0 then
		if type(self.UpdateFlowSize) == "function" then
			self:UpdateFlowSize()
		end
		return
	end

	local padX = tonumber(self.childXPadding) or 0
	local padY = tonumber(self.childYPadding) or 0

	local prev = nil
	for i = 1, count do
		local frame = frames[i]
		if frame and frame.ignoreInLayout ~= true and frame.SetPoint and frame.ClearAllPoints then
			frame:ClearAllPoints()
			if prev then
				if self._ffIsHorizontalFlow then
					frame:SetPoint("TOPLEFT", prev, "TOPRIGHT", padX, 0)
				else
					frame:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -padY)
				end
			else
				frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
			end
			prev = frame
		end
	end

	if type(self.UpdateFlowSize) == "function" then
		self:UpdateFlowSize()
	end
end

function FoxFrames_SettingsFlowMixin:InitFlow(options)
	options = options or {}
	local direction = NormalizeFlowDirection(options.direction)
	self._ffFlowDirection = direction
	self._ffIsHorizontalFlow = direction == "horizontal"

	self._ffFlowFrames = self._ffFlowFrames or {}
	self._ffFlowCount = 0
	self._ffEnabled = true

	-- GridLayoutFrame expects these layout knobs.
	self.isHorizontal = true
	self.layoutFramesGoingRight = true
	self.layoutFramesGoingUp = false
	local defaultChildXPadding = self._ffIsHorizontalFlow and DEFAULT_CHILD_X_PADDING or DEFAULT_CHILD_Y_PADDING
	local defaultChildYPadding = self._ffIsHorizontalFlow and DEFAULT_CHILD_Y_PADDING or DEFAULT_CHILD_X_PADDING
	self.childXPadding = options.childXPadding or defaultChildXPadding
	self.childYPadding = options.childYPadding or defaultChildYPadding
	self.alwaysUpdateLayout = options.alwaysUpdateLayout ~= false

	-- Force a single row/column by default; horizontal flows grow stride.
	self.stride = 1

	self._ffFillParent = options.fillParent ~= false
	self._ffAutoSize = options.autoSize
	if self._ffAutoSize == nil then
		self._ffAutoSize = self._ffFillParent ~= true
	end
end

function FoxFrames_SettingsFlowMixin:ResetFlow()
	local frames = self._ffFlowFrames
	if type(frames) == "table" then
		for _, frame in ipairs(frames) do
			if frame then
				frame.ignoreInLayout = true
				if frame.Hide then
					frame:Hide()
				end
			end
		end
	end

	self._ffFlowCount = 0
	self.stride = 1
	if self._ffAutoSize then
		if self.SetSize then
			self:SetSize(0, 0)
		end
	end
end

function FoxFrames_SettingsFlowMixin:SetEnabled(enabled)
	self._ffEnabled = enabled ~= false

	local frames = self._ffFlowFrames
	if type(frames) ~= "table" then
		return
	end

	for _, frame in ipairs(frames) do
		SetEnabledRecursive(frame, self._ffEnabled)
	end
end

function FoxFrames_SettingsFlowMixin:AddFrame(frame)
	if not frame then
		return nil
	end

	self._ffFlowCount = (tonumber(self._ffFlowCount) or 0) + 1
	local index = self._ffFlowCount

	self._ffFlowFrames = self._ffFlowFrames or {}
	self._ffFlowFrames[index] = frame

	if frame.SetParent then
		frame:SetParent(self)
	end

	frame.layoutIndex = index
	frame.ignoreInLayout = false

	if frame.Show then
		frame:Show()
	end

	-- Keep everything on one row.
	if self._ffIsHorizontalFlow then
		self.stride = index
	else
		self.stride = 1
	end

	-- Propagate current enabled state.
	SetEnabledRecursive(frame, self._ffEnabled ~= false)

	if self.UpdateFlowSize then
		self:UpdateFlowSize()
	end
	LayoutNow(self)
	return frame
end

function FoxFrames_SettingsFlowMixin:UpdateFlowSize()
	local count = tonumber(self._ffFlowCount) or 0
	if count <= 0 then
		self._ffMeasuredWidth = 0
		self._ffMeasuredHeight = 0
		if self.SetSize then
			if self._ffAutoSize then
				self:SetSize(0, 0)
			end
		end
		return
	end

	local frames = self._ffFlowFrames
	if type(frames) ~= "table" then
		self._ffMeasuredWidth = 0
		self._ffMeasuredHeight = 0
		return
	end

	local width = 0
	local height = 0

	if self._ffIsHorizontalFlow then
		local totalWidth = 0
		local maxHeight = 0
		local padX = tonumber(self.childXPadding) or 0
		local used = 0

		for i = 1, count do
			local frame = frames[i]
			if frame and frame.ignoreInLayout ~= true then
				local w = (frame.GetWidth and frame:GetWidth()) or 0
				local h = (frame.GetHeight and frame:GetHeight()) or 0
				if used > 0 then
					totalWidth = totalWidth + padX
				end
				totalWidth = totalWidth + math.max(0, w)
				maxHeight = math.max(maxHeight, math.max(0, h))
				used = used + 1
			end
		end

		width = totalWidth
		height = maxHeight
	else
		local totalHeight = 0
		local maxWidth = 0
		local padY = tonumber(self.childYPadding) or 0
		local used = 0

		for i = 1, count do
			local frame = frames[i]
			if frame and frame.ignoreInLayout ~= true then
				local w = (frame.GetWidth and frame:GetWidth()) or 0
				local h = (frame.GetHeight and frame:GetHeight()) or 0
				if used > 0 then
					totalHeight = totalHeight + padY
				end
				totalHeight = totalHeight + math.max(0, h)
				maxWidth = math.max(maxWidth, math.max(0, w))
				used = used + 1
			end
		end

		width = maxWidth
		height = totalHeight
	end

	self._ffMeasuredWidth = width
	self._ffMeasuredHeight = height

	if self._ffAutoSize and self.SetSize then
		self:SetSize(width, height)
	end
end

function FoxFrames_SettingsFlowMixin:AddButton(text, options, click)
	local nextIndex = (tonumber(self._ffFlowCount) or 0) + 1
	local existing = self._ffFlowFrames and self._ffFlowFrames[nextIndex]
	local button = ComponentBuilder:CreateButton(self, text, options, click, existing)
	self:AddFrame(button)
	return button
end

function FoxFrames_SettingsFlowMixin:AddInput(value, options, onChanged)
	local nextIndex = (tonumber(self._ffFlowCount) or 0) + 1
	local existing = self._ffFlowFrames and self._ffFlowFrames[nextIndex]
	local input = ComponentBuilder:CreateInput(self, value, options, onChanged, existing)
	self:AddFrame(input)
	return input
end

function FoxFrames_SettingsFlowMixin:AddToggle(checked, options, onChanged)
	local nextIndex = (tonumber(self._ffFlowCount) or 0) + 1
	local existing = self._ffFlowFrames and self._ffFlowFrames[nextIndex]
	local toggle = ComponentBuilder:CreateToggle(self, checked, options, onChanged, existing)
	self:AddFrame(toggle)
	return toggle
end

function FoxFrames_SettingsFlowMixin:AddDropdown(value, options, onChanged)
	local nextIndex = (tonumber(self._ffFlowCount) or 0) + 1
	local existing = self._ffFlowFrames and self._ffFlowFrames[nextIndex]
	local control, dropdown = ComponentBuilder:CreateDropdown(self, value, options, onChanged, existing)
	self:AddFrame(control)
	return dropdown
end

function FoxFrames_SettingsFlowMixin:AddFlow(options, callback)
	assert(type(callback) == "function", "FoxFrames: AddFlow requires callback")
	local flowOptions = options or {}
	flowOptions.fillParent = false
	if flowOptions.autoSize == nil then
		flowOptions.autoSize = true
	end

	local nextIndex = (tonumber(self._ffFlowCount) or 0) + 1
	local flow = self._ffFlowFrames and self._ffFlowFrames[nextIndex]
	if not (flow and flow._ffFlowKind == "flow") then
		flow = CreateFrame("Frame", nil, self, "GridLayoutFrame")
		flow._ffFlowKind = "flow"
		ApplyMixinSafe(flow, FoxFrames_SettingsFlowMixin)
	end

	if flow.ClearAllPoints then
		flow:ClearAllPoints()
	end

	flow:InitFlow(flowOptions)
	flow:ResetFlow()
	callback(flow)

	flow:UpdateFlowSize()
	self:AddFrame(flow)
	return flow
end

function addon:CreateSettingsFlow(parent, options)
	if not parent then
		return nil
	end

	options = options or {}
	if options.direction == nil then
		options.direction = DEFAULT_FLOW_DIRECTION
	end
	if options.fillParent == nil then
		options.fillParent = true
	end

	local flow = CreateFrame("Frame", nil, parent, "GridLayoutFrame")
	assert(flow, "FoxFrames: failed to create GridLayoutFrame")
	flow._ffFlowKind = "flow"

	ApplyMixinSafe(flow, FoxFrames_SettingsFlowMixin)
	flow:InitFlow(options)

	flow:ClearAllPoints()
	if options.fillParent ~= false then
		flow:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		flow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	end

	return flow
end
