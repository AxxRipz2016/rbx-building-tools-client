local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local Libraries = Root:WaitForChild('Libraries')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Libraries:WaitForChild('Maid'))
local Theme = require(script.Parent.Parent:WaitForChild('Theme'))

-- Roact
local new = Roact.createElement
local ToolButton = require(script.Parent:WaitForChild('ToolButton'))

-- Create component
local ToolList = Roact.PureComponent:extend(script.Name)

function ToolList:init()
    self.Maid = Maid.new()
    self.CanvasSize, self.SetCanvasSize = Roact.createBinding(UDim2.new())

    -- Track current tool
    self:setState({
        CurrentTool = self.props.Core.CurrentTool;
    })
    self.Maid.CurrentTool = self.props.Core.ToolChanged:Connect(function (Tool)
        self:setState({
            CurrentTool = Tool;
        })
    end)
end

function ToolList:render()
    local Children = {
        Layout = new('UIGridLayout', {
            CellPadding = UDim2.new(0, 2, 0, 2);
            CellSize = UDim2.new(0, 34, 0, 34);
            FillDirection = Enum.FillDirection.Horizontal;
            FillDirectionMaxCells = 2;
            HorizontalAlignment = Enum.HorizontalAlignment.Left;
            VerticalAlignment = Enum.VerticalAlignment.Top;
            SortOrder = Enum.SortOrder.LayoutOrder;
            StartCorner = Enum.StartCorner.TopLeft;
            [Roact.Ref] = function (rbx)
                if rbx then
                    self.SetCanvasSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
                end
            end;
            [Roact.Change.AbsoluteContentSize] = function (rbx)
                self.SetCanvasSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
            end;
        });
    }

    -- Build buttons for each tool
    for ToolIndex, ToolInfo in ipairs(self.props.Tools) do
        Children[tostring(ToolIndex)] = new(ToolButton, {
            CurrentTool = self.state.CurrentTool;
            IconAssetId = ToolInfo.IconAssetId;
            HotkeyLabel = ToolInfo.HotkeyLabel;
            Tool = ToolInfo.Tool;
            Core = self.props.Core;
        })
    end

    return new('Frame', {
        BackgroundTransparency = Theme.dockTransparency;
        BackgroundColor3 = Theme.panel;
        BorderSizePixel = 0;
        LayoutOrder = self.props.LayoutOrder;
        Size = self.CanvasSize:map(function (CanvasSize)
            return UDim2.fromOffset(CanvasSize.X.Offset, (35) * 7)
        end);
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, Theme.cornerRadius);
        });
        Stroke = new('UIStroke', {
            Color = Theme.border;
            Thickness = 1;
            Transparency = 0.4;
        });
        SizeConstraint = new('UISizeConstraint', {
            MinSize = Vector2.new(70, 0);
        });
        List = new('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            CanvasSize = self.CanvasSize;
            ScrollBarThickness = 3;
            ScrollingDirection = Enum.ScrollingDirection.Y;
            ScrollBarImageColor3 = Theme.accent;
            [Roact.Children] = Children;
        });
    })
end

return ToolList