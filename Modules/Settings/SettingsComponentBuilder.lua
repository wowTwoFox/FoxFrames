local addonName, addon = ...

assert(addon, "FoxFrames: addon table missing (load order issue)")

local SettingsComponentBuilder = {}

local DEFAULT_BUTTON_HEIGHT = 24
local DEFAULT_BUTTON_PADDING_X = 60


local DEFAULT_BUTTON_MIN_WIDTH = 40

local DEFAULT_INPUT_HEIGHT = 20
local DEFAULT_INPUT_WIDTH = 160

local DEFAULT_TOGGLE_SIZE = 24

local DEFAULT_DROPDOWN_HEIGHT = 26
local DEFAULT_DROPDOWN_WIDTH = 200

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

function SettingsComponentBuilder:CreateInput(parent, value, options, onChanged, existing)
	assert(parent, "FoxFrames: CreateInput requires parent")
	assert(type(onChanged) == "function", "FoxFrames: CreateInput requires onChanged function")
	assert(options == nil or type(options) == "table", "FoxFrames: CreateInput options must be table or nil")

	local text = (type(value) == "string" or type(value) == "number") and tostring(value) or ""
	local optionsTable = options or {}
	local tooltipText = optionsTable.tooltip
	local maxChars = optionsTable.maxChars
	local numeric = optionsTable.numeric
	local justifyH = optionsTable.justifyH

	local input = existing
	if input ~= nil then
		assert(input._ffFlowKind == "input", "FoxFrames: CreateInput expected existing input")
		input:SetParent(parent)
	else
		input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
		input._ffFlowKind = "input"
		input:SetAutoFocus(false)
	end

	input:SetHeight(DEFAULT_INPUT_HEIGHT)
	input:SetWidth(DEFAULT_INPUT_WIDTH)
	input:SetText(text)

	if input.SetNumeric then
		input:SetNumeric(numeric == true)
	end
	if input.SetMaxLetters and maxChars ~= nil then
		input:SetMaxLetters(tonumber(maxChars) or 0)
	end
	if input.SetJustifyH and type(justifyH) == "string" then
		input:SetJustifyH(justifyH)
	end

	AttachTooltip(input, tooltipText)

	AttachSetEnabled(input, optionsTable.isEnabled)

	input._ffCommitByEnter = false
	input:SetScript("OnEnterPressed", function(control)
		control._ffCommitByEnter = true
		onChanged(control:GetText() or "", control)
		control:ClearFocus()
	end)
	input:SetScript("OnEditFocusLost", function(control)
		if control._ffCommitByEnter then
			control._ffCommitByEnter = false
			return
		end
		onChanged(control:GetText() or "", control)
	end)
	input:SetScript("OnEscapePressed", function(control)
		control._ffCommitByEnter = false
		control:ClearFocus()
	end)

	return input
end

function SettingsComponentBuilder:CreateToggle(parent, checked, options, onChanged, existing)
	assert(parent, "FoxFrames: CreateToggle requires parent")
	assert(type(onChanged) == "function", "FoxFrames: CreateToggle requires onChanged function")
	assert(options == nil or type(options) == "table", "FoxFrames: CreateToggle options must be table or nil")

	local optionsTable = options or {}
	local tooltipText = optionsTable.tooltip
	local labelText = optionsTable.text

	local toggle = existing
	if toggle ~= nil then
		assert(toggle._ffFlowKind == "toggle", "FoxFrames: CreateToggle expected existing toggle")
		toggle:SetParent(parent)
	else
		toggle = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		toggle._ffFlowKind = "toggle"
		toggle:SetMotionScriptsWhileDisabled(true)
	end

	toggle:SetSize(DEFAULT_TOGGLE_SIZE, DEFAULT_TOGGLE_SIZE)
	toggle:SetChecked(checked == true)
	if toggle.Text and toggle.Text.SetText then
		if type(labelText) == "string" or type(labelText) == "number" then
			toggle.Text:SetText(tostring(labelText))
		else
			toggle.Text:SetText("")
		end
	end

	AttachTooltip(toggle, tooltipText)

	AttachSetEnabled(toggle, optionsTable.isEnabled)

	toggle:SetScript("OnClick", function(control)
		onChanged(control:GetChecked() == true, control)
	end)

	return toggle
end

local function GetDropdownLabelForValue(list, value)
	if type(list) ~= "table" then
		return nil
	end
	local label = list[value]
	return label ~= nil and tostring(label) or nil
end

local function GetDropdownOptions(optionsTable)
	local list = optionsTable.values
	if optionsTable.optionfunc then
		list = optionsTable.optionfunc()
	end
	if list ~= nil then
		assert(type(list) == "table", "FoxFrames: dropdown values must be a table")
	end
	return list
end

local function OverrideDropdownText(dropdown, text)
	if not dropdown then
		return
	end
	local label = (type(text) == "string" or type(text) == "number") and tostring(text) or ""
	if dropdown.OverrideText then
		dropdown:OverrideText(label)
		return
	end
	if dropdown.SetText then
		dropdown:SetText(label)
	end
end

function SettingsComponentBuilder:CreateDropdown(parent, value, options, onChanged, existing)
	assert(parent, "FoxFrames: CreateDropdown requires parent")
	assert(type(onChanged) == "function", "FoxFrames: CreateDropdown requires onChanged function")
	assert(options == nil or type(options) == "table", "FoxFrames: CreateDropdown options must be table or nil")

	local optionsTable = options or {}
	local tooltipText = optionsTable.tooltip
	local placeholder = optionsTable.placeholder
	if placeholder == nil then
		placeholder = "Select..."
	end

	local control = existing
	if control ~= nil then
		assert(control._ffFlowKind == "dropdown", "FoxFrames: CreateDropdown expected existing dropdown")
		control:SetParent(parent)
	else
		control = CreateFrame("Frame", nil, parent, "SettingsDropdownWithButtonsTemplate")
		control._ffFlowKind = "dropdown"
		if control.DecrementButton then
			control.DecrementButton:Hide()
		end
		if control.IncrementButton then
			control.IncrementButton:Hide()
		end
	end

	local dropdown = control.Dropdown or control
	control._ffDropdownButton = dropdown
	if control ~= dropdown and type(control.SetEnabled) ~= "function" then
		function control:SetEnabled(enabled)
			SetEnabledRecursive(dropdown, enabled)
		end
	end

	AttachSetEnabled(control, optionsTable.isEnabled)

	if dropdown ~= control and dropdown.ClearAllPoints and dropdown.SetPoint then
		dropdown:ClearAllPoints()
		dropdown:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)
		dropdown:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 0, 0)
	end

	control:SetSize(DEFAULT_DROPDOWN_WIDTH, DEFAULT_DROPDOWN_HEIGHT)
	if dropdown ~= control and dropdown.SetHeight then
		dropdown:SetHeight(DEFAULT_DROPDOWN_HEIGHT)
	end

	control._ffDropdownValue = value
	local list = GetDropdownOptions(optionsTable)
	local currentLabel = GetDropdownLabelForValue(list, value) or placeholder
	OverrideDropdownText(dropdown, currentLabel)

	AttachTooltip(dropdown, tooltipText)

	dropdown:SetupMenu(function(_, rootDescription)
		local menuList = GetDropdownOptions(optionsTable)
		local order = type(optionsTable.order) == "table" and optionsTable.order or nil

		local function AddOption(optValue, optLabel)
			assert(type(optLabel) ~= "table", "FoxFrames: dropdown values must be a key->label table")
			rootDescription:CreateRadio(
				tostring(optLabel),
				function()
					return control._ffDropdownValue == optValue
				end,
				function()
					control._ffDropdownValue = optValue
					local label = GetDropdownLabelForValue(menuList, optValue) or tostring(optLabel)
					OverrideDropdownText(dropdown, label)
					onChanged(optValue, dropdown)
				end
			)
		end

		if type(menuList) ~= "table" then
			return
		end

		local seen = nil
		if order then
			seen = {}
			for _, key in ipairs(order) do
				if key ~= "_order" and menuList[key] ~= nil then
					AddOption(key, menuList[key])
					seen[key] = true
				end
			end
		end

		for key, label in pairs(menuList) do
			if key ~= "_order" and (not seen or not seen[key]) then
				AddOption(key, label)
			end
		end
	end)

	return control, dropdown
end

addon.SettingsComponentBuilder = SettingsComponentBuilder
