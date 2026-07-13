local Root = script.Parent.Parent
local Vendor = Root:WaitForChild("Vendor")

local Roact = require(Vendor:WaitForChild("Roact"))
local Theme = require(Root.UI:WaitForChild("Theme"))

local new = Roact.createElement

local ReplacePanel = Roact.PureComponent:extend("ReplacePanel")

function ReplacePanel:init()
	local s = self.props.Settings or {}
	local hasTemplate, templateName = (self.props.OnGetTemplateInfo and self.props.OnGetTemplateInfo()) or false, nil
	self:setState({
		keepSize = s.keepSize ~= false,
		keepColor = s.keepColor ~= false,
		keepMaterial = s.keepMaterial ~= false,
		status = hasTemplate and ("Шаблон: " .. tostring(templateName or "?")) or "Сначала возьми шаблон (1 part).",
	})
end

function ReplacePanel:update(patch)
	self:setState(patch)
	if self.props.OnSettingsChanged then
		self.props.OnSettingsChanged(patch)
	end
end

function ReplacePanel:renderCheckbox(layoutOrder, label, checked, onToggle)
	local assets = self.props.Core and self.props.Core.Assets
	return new("TextButton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Theme.surface,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[Roact.Event.Activated] = onToggle,
	}, {
		Corner = new("UICorner", { CornerRadius = UDim.new(0, Theme.cornerRadiusXs) }),
		Layout = new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = new("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Checkbox = new("ImageLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			Image = checked
				and (assets and assets.CheckedCheckbox or "")
				or (assets and assets.UncheckedCheckbox or ""),
		}),
		Label = new("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, -20, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = label,
			TextColor3 = Theme.text,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

function ReplacePanel:render()
	return new("Frame", {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0.5, -120),
		Size = UDim2.fromOffset(280, 250),
	}, {
		Corner = new("UICorner", { CornerRadius = UDim.new(0, Theme.cornerRadius) }),
		Stroke = new("UIStroke", { Color = Theme.border, Thickness = 1, Transparency = 0.35 }),
		Layout = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = new("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Title = new("TextLabel", {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Font = Enum.Font.GothamBold,
			Text = "REPLACE",
			TextColor3 = Theme.accent,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Status = new("TextLabel", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Font = Enum.Font.Gotham,
			Text = self.state.status,
			TextColor3 = Theme.textDim,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Template = new("TextButton", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Theme.surface,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = "Взять шаблон (1 part)",
			TextColor3 = Theme.text,
			TextSize = 11,
			[Roact.Event.Activated] = function()
				if not self.props.OnCaptureTemplate then
					return
				end
				local ok, message = self.props.OnCaptureTemplate()
				self:setState({ status = message or (ok and "Шаблон сохранён" or "Ошибка") })
			end,
		}, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		}),
		Options = new("Frame", {
			LayoutOrder = 4,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 74),
		}, {
			Layout = new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			KeepSize = self:renderCheckbox(1, "Сохранять Size", self.state.keepSize, function()
				local v = not self.state.keepSize
				self:update({ keepSize = v })
			end),
			KeepColor = self:renderCheckbox(2, "Сохранять Color", self.state.keepColor, function()
				local v = not self.state.keepColor
				self:update({ keepColor = v })
			end),
			KeepMaterial = self:renderCheckbox(3, "Сохранять Material", self.state.keepMaterial, function()
				local v = not self.state.keepMaterial
				self:update({ keepMaterial = v })
			end),
		}),
		Apply = new("TextButton", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Theme.accent,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = "Заменить выделение",
			TextColor3 = Theme.text,
			TextSize = 12,
			[Roact.Event.Activated] = function()
				if not self.props.OnApply then
					return
				end
				local ok, message = self.props.OnApply()
				self:setState({ status = message or (ok and "Готово" or "Ошибка") })
			end,
		}, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		}),
	})
end

return ReplacePanel

