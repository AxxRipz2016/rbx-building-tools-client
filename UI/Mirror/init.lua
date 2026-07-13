local Root = script.Parent.Parent
local Vendor = Root:WaitForChild("Vendor")

local Roact = require(Vendor:WaitForChild("Roact"))
local Theme = require(Root.UI:WaitForChild("Theme"))

local new = Roact.createElement

local MirrorPanel = Roact.PureComponent:extend("MirrorPanel")

function MirrorPanel:init()
	local s = self.props.Settings or {}
	self:setState({
		axis = s.axis or "X",
		keepOriginal = s.keepOriginal ~= false,
		groupResult = s.groupResult == true,
		status = "Зеркаль по X/Y/Z.",
	})
end

function MirrorPanel:update(patch)
	self:setState(patch)
	if self.props.OnSettingsChanged then
		self.props.OnSettingsChanged(patch)
	end
end

function MirrorPanel:render()
	local axisButtons = {}
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local isActive = self.state.axis == axis
		axisButtons[axis] = new("TextButton", {
			LayoutOrder = (axis == "X" and 1) or (axis == "Y" and 2) or 3,
			Size = UDim2.new(0.33, -4, 1, 0),
			BackgroundColor3 = isActive and Theme.accent or Theme.surface,
			BackgroundTransparency = isActive and 0.1 or 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = axis,
			TextColor3 = Theme.text,
			TextSize = 12,
			[Roact.Event.Activated] = function()
				self:update({ axis = axis })
			end,
		}, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
	end

	local function checkbox(label, checked, onToggle, layoutOrder)
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

	return new("Frame", {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0.5, -120),
		Size = UDim2.fromOffset(260, 240),
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
			Text = "MIRROR",
			TextColor3 = Theme.accent,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Status = new("TextLabel", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			Font = Enum.Font.Gotham,
			Text = self.state.status,
			TextColor3 = Theme.textDim,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		AxisRow = new("Frame", {
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
		}, {
			Layout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			X = axisButtons.X,
			Y = axisButtons.Y,
			Z = axisButtons.Z,
		}),
		Options = new("Frame", {
			LayoutOrder = 4,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 70),
		}, {
			Layout = new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			KeepOriginal = checkbox("Сохранить оригинал", self.state.keepOriginal, function()
				local nextValue = not self.state.keepOriginal
				self:update({ keepOriginal = nextValue })
			end, 1),
			GroupResult = checkbox("Группировать результат (beta)", self.state.groupResult, function()
				local nextValue = not self.state.groupResult
				self:update({ groupResult = nextValue })
			end, 2),
		}),
		Apply = new("TextButton", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Theme.accent,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = "Зеркалить",
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

return MirrorPanel

