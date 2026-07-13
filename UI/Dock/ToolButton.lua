local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local TextService = game:GetService('TextService')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Theme = require(script.Parent.Parent:WaitForChild('Theme'))
local new = Roact.createElement

-- Create component
local ToolButton = Roact.PureComponent:extend(script.Name)

function ToolButton:init()
    self:UpdateHotkeyTextSize(self.props.HotkeyLabel)
end

function ToolButton:willUpdate(nextProps)
    if self.props.HotkeyLabel ~= nextProps.HotkeyLabel then
        self:UpdateHotkeyTextSize(nextProps.HotkeyLabel)
    end
end

function ToolButton:UpdateHotkeyTextSize(Text)
    self.HotkeyTextSize = TextService:GetTextSize(
        Text,
        9,
        Enum.Font.Gotham,
        Vector2.new(math.huge, math.huge)
    )
end

function ToolButton:render()
    local isSelected = self.props.CurrentTool == self.props.Tool
    return new('ImageButton', {
        BackgroundColor3 = isSelected and self.props.Tool.Color.Color or Theme.surface;
        BackgroundTransparency = isSelected and 0.15 or 0.55;
        BorderSizePixel = 0;
        Image = self.props.IconAssetId;
        AutoButtonColor = false;
        [Roact.Event.Activated] = function ()
            self.props.Core.EquipTool(self.props.Tool)
        end;
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, Theme.cornerRadiusSm);
        });
        Stroke = isSelected and new('UIStroke', {
            Color = self.props.Tool.Color.Color;
            Thickness = 2;
            Transparency = 0.1;
        }) or new('UIStroke', {
            Color = Theme.border;
            Thickness = 1;
            Transparency = 0.55;
        });
        Hotkey = new('TextLabel', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 3, 0, 3);
            Size = UDim2.fromOffset(self.HotkeyTextSize.X, self.HotkeyTextSize.Y);
            Font = Enum.Font.GothamSemibold;
            Text = self.props.HotkeyLabel;
            TextColor3 = Theme.text;
            TextSize = 9;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Top;
        });
    })
end

return ToolButton