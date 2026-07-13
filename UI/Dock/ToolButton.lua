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
    local toolColor = self.props.Tool.Color.Color

    return new('ImageButton', {
        BackgroundColor3 = isSelected and toolColor or Theme.surface;
        BackgroundTransparency = isSelected and 0.05 or 0.35;
        BorderSizePixel = 0;
        Image = self.props.IconAssetId;
        ImageColor3 = Color3.fromRGB(255, 255, 255);
        ImageTransparency = isSelected and 0 or 0.08;
        AutoButtonColor = false;
        [Roact.Event.Activated] = function ()
            self.props.Core.EquipTool(self.props.Tool)
        end;
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, Theme.cornerRadiusSm);
        });
        Gradient = isSelected and new('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, toolColor);
                ColorSequenceKeypoint.new(1, Theme.panelLight);
            });
            Rotation = 135;
        }) or nil;
        Stroke = new('UIStroke', {
            Color = isSelected and toolColor or Theme.border;
            Thickness = isSelected and 2 or 1;
            Transparency = isSelected and 0.05 or 0.45;
        });
        HotkeyBadge = new('Frame', {
            BackgroundColor3 = isSelected and Color3.new(0, 0, 0) or Theme.panel;
            BackgroundTransparency = isSelected and 0.45 or 0.2;
            Position = UDim2.new(0, 2, 0, 2);
            Size = UDim2.fromOffset(self.HotkeyTextSize.X + 6, self.HotkeyTextSize.Y + 2);
            ZIndex = 2;
        }, {
            Corners = new('UICorner', {
                CornerRadius = UDim.new(0, 4);
            });
            Hotkey = new('TextLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.fromScale(1, 1);
                Font = Enum.Font.GothamBold;
                Text = self.props.HotkeyLabel;
                TextColor3 = isSelected and Theme.text or Theme.textDim;
                TextSize = 9;
                TextXAlignment = Enum.TextXAlignment.Center;
                TextYAlignment = Enum.TextYAlignment.Center;
            });
        });
    })
end

return ToolButton
