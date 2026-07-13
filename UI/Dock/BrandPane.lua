local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Theme = require(script.Parent.Parent:WaitForChild('Theme'))

-- Roact
local new = Roact.createElement

local BrandPane = Roact.PureComponent:extend(script.Name)

function BrandPane:render()
	return new('Frame', {
		BackgroundTransparency = Theme.dockTransparency;
		BackgroundColor3 = Theme.panel;
		BorderSizePixel = 0;
		LayoutOrder = self.props.LayoutOrder;
		Size = UDim2.new(1, 0, 0, 36);
	}, {
		Corners = new('UICorner', {
			CornerRadius = UDim.new(0, Theme.cornerRadius);
		});
		Gradient = new('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.panelLight);
				ColorSequenceKeypoint.new(1, Theme.background);
			});
			Rotation = 110;
		});
		Stroke = new('UIStroke', {
			Color = Theme.accent;
			Thickness = 1;
			Transparency = 0.55;
		});
		AccentBar = new('Frame', {
			BackgroundColor3 = Theme.accent;
			BorderSizePixel = 0;
			Position = UDim2.new(0, 6, 0, 5);
			Size = UDim2.new(1, -12, 0, 2);
			ZIndex = 2;
		}, {
			BarCorners = new('UICorner', {
				CornerRadius = UDim.new(1, 0);
			});
		});
		Title = new('TextLabel', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 0, 0, 10);
			Size = UDim2.new(1, 0, 1, -10);
			Font = Enum.Font.GothamBold;
			Text = 'Пиратский куб';
			TextColor3 = Theme.accent;
			TextSize = 13;
			TextXAlignment = Enum.TextXAlignment.Center;
			TextYAlignment = Enum.TextYAlignment.Center;
		});
	})
end

return BrandPane
