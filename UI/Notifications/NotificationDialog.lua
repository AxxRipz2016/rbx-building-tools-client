local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Theme = require(script.Parent.Parent:WaitForChild('Theme'))
local new = Roact.createElement

-- Create component
local NotificationDialog = Roact.PureComponent:extend(script.Name)

function NotificationDialog:init()
    self:setState({
        ShouldDisplayDetails = false;
    })
end

function NotificationDialog:render()
    return new('Frame', {
        BackgroundColor3 = self.props.ThemeColor:Lerp(Color3.new(0, 0, 0), 0.2); -- нужно чтобы ThemeColor но только темнее
        BackgroundTransparency = 0.1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 22 + 2);
        LayoutOrder = self.props.LayoutOrder;
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, Theme.cornerRadiusSm);
        });
        Stroke = new('UIStroke', {
            Color = Theme.border;
            Thickness = 1;
            Transparency = 0.45;
        });
        ColorBar = new('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = self.props.ThemeColor;
            Size = UDim2.new(1, 0, 0, 2);
        });
        OKButton = new('TextButton', {
            BackgroundColor3 = Theme.surface;
            BackgroundTransparency = 0.15;
            BorderSizePixel = 0;
            AnchorPoint = Vector2.new(0, 1);
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(self.state.ShouldDisplayDetails and 1 or 0.5, 0, 0, 22);
            Text = 'GOT IT';
            Font = Enum.Font.Gotham;
            TextSize = 10;
            TextColor3 = Theme.text;
            [Roact.Event.Activated] = function (rbx)
                self.props.OnDismiss()
            end;
        });
        DetailsButton = (not self.state.ShouldDisplayDetails or nil) and new('TextButton', {
            BackgroundColor3 = Theme.surface;
            BackgroundTransparency = 0.15;
            BorderSizePixel = 0;
            AnchorPoint = Vector2.new(0, 1);
            Position = UDim2.new(0.5, 0, 1, 0);
            Size = UDim2.new(0.5, 0, 0, 22);
            Text = 'WHAT CAN I DO?';
            Font = Enum.Font.Gotham;
            TextSize = 10;
            TextColor3 = Theme.text;
            [Roact.Event.Activated] = function (rbx)
                self:setState({
                    ShouldDisplayDetails = true;
                })
            end;
        });
        ButtonDivider = (not self.state.ShouldDisplayDetails or nil) and new('Frame', {
            BackgroundColor3 = Theme.border;
            BackgroundTransparency = 0.2;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 0, 1, 0);
            AnchorPoint = Vector2.new(0.5, 1);
            Size = UDim2.new(0, 1, 0, 22);
        });
        Text = new('TextLabel', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 2);
            Size = UDim2.new(1, 0, 1, -22 - 2);
            TextWrapped = true;
            RichText = true;
            Font = Enum.Font.GothamSemibold;
            TextColor3 = Theme.text;
            TextSize = 11;
            TextStrokeTransparency = 0.9;
            LineHeight = 1;
            Text = (not self.state.ShouldDisplayDetails) and
                self.props.NoticeText or
                self.props.DetailText;
            [Roact.Change.TextBounds] = function (rbx)
                rbx.Parent.Size = UDim2.new(1, 0, 0, rbx.TextBounds.Y + 29 + 22 + 2)
            end;
        });
    })
end

return NotificationDialog