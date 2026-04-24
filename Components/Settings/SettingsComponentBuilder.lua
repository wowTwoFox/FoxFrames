local addonName, addon = ...

assert(addon, "FoxFrames: addon table missing (load order issue)")

local SettingsComponentBuilder = {}

local DEFAULT_BUTTON_HEIGHT = 24
local DEFAULT_BUTTON_PADDING_X = 60
local DEFAULT_BUTTON_MIN_WIDTH = 40

local function EvalPredicate(predicate, control)
	if predicate == nil then
		return true
	end

	if type(predicate) == "function" then
		local ok, result = pcall(predicate, control)
		if not ok then
			return true
		end
		return result ~= false
	end

	return predicate ~= false
end

local function AttachSetEnabled(control, predicate)
	if not control then
		return
	end

	-- Allow callers to update predicate when reusing controls.
	control._ffEnabledPredicate = predicate

	if control._ffSetEnabledAttached then
		return
	end
	control._ffSetEnabledAttached = true

	local baseSetEnabled = type(control.SetEnabled) == "function" and control.SetEnabled or nil
	control._ffBaseSetEnabled = baseSetEnabled

	function control:SetEnabled(enabled)
		local shouldEnable = enabled ~= false
		if shouldEnable and not EvalPredicate(self._ffEnabledPredicate, self) then
			shouldEnable = false
		end

		local base = self._ffBaseSetEnabled
		if type(base) == "function" then
			base(self, shouldEnable)
			return
		end

		if shouldEnable then
			if self.Enable then
				self:Enable()
			end
		else
			if self.Disable then
				self:Disable()
			end
		end
	end
end

local function AttachTooltip(control, tooltip)
	if not control then
		return
	end

	if type(tooltip) ~= "string" or tooltip == "" then
		control._ffTooltipText = nil
		return
	end

	control._ffTooltipText = tooltip

	if control._ffTooltipHooksApplied then
		return
	end
	control._ffTooltipHooksApplied = true

	if not control.HookScript then
		return
	end

	control:HookScript("OnEnter", function(widget)
		local text = widget and widget._ffTooltipText
		if type(text) ~= "string" or text == "" then
			return
		end
		GameTooltip:SetOwner(widget, "ANCHOR_TOP")
		GameTooltip:SetText(text, 1, 1, 1, 1)
		GameTooltip:Show()
	end)

	control:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function SettingsComponentBuilder:CreateButton(parent, text, options, click, existing)
	assert(parent, "FoxFrames: CreateButton requires parent")
	assert(type(click) == "function", "FoxFrames: CreateButton requires click function")
	assert(options == nil or type(options) == "table", "FoxFrames: CreateButton options must be table or nil")

	local label = (type(text) == "string" or type(text) == "number") and tostring(text) or ""
	local optionsTable = options or {}
	local tooltipText = optionsTable.tooltip

	local button = existing
	if button ~= nil then
		assert(button._ffFlowKind == "button", "FoxFrames: CreateButton expected existing button")
		button:SetParent(parent)
	else
		button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		button._ffFlowKind = "button"
		button:SetMotionScriptsWhileDisabled(true)
	end

	button:SetHeight(DEFAULT_BUTTON_HEIGHT)
	button:SetText(label)
	local textWidth = (button.GetTextWidth and button:GetTextWidth()) or 0
	button:SetWidth(math.max(DEFAULT_BUTTON_MIN_WIDTH, textWidth + DEFAULT_BUTTON_PADDING_X))

	AttachTooltip(button, tooltipText)

	AttachSetEnabled(button, optionsTable.isEnabled)

	button:SetScript("OnClick", function(control)
		click(control)
	end)

	return button
end

addon.SettingsComponentBuilder = SettingsComponentBuilder
