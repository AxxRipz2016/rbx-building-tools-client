local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local UI = Root:WaitForChild('UI')
local Libraries = Root:WaitForChild('Libraries')
local UserInputService = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Libraries:WaitForChild('Maid'))
local Theme = require(script.Parent.Parent:WaitForChild('Theme'))

-- Roact
local new = Roact.createElement
local ToolManualWindow = require(UI:WaitForChild('ToolManualWindow'))

local MANUAL_CONTENT = [[<font face="GothamBlack" size="16"><font color="rgb(255, 0, 0)">ПИРАТСКИЙ</font> КУБИК от AxxRipz2016  🛠</font>
Чтобы шарить за инструмент. Просто нажми нахуй на его иконку в верхнем правом углу.<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Выделение</b></font>
 <font color="rgb(150, 150, 150)">•</font> Выдели отдельные части, удерживая <b>Shift</b> и кликая на каждую.
 <font color="rgb(150, 150, 150)">•</font> Выдели прямоугольно, удерживая <b>Shift</b>, кликая и тяни.
 <font color="rgb(150, 150, 150)">•</font> Нажми <b>Shift-K</b> чтобы выделить части внутри выделенных частей.
 <font color="rgb(150, 150, 150)">•</font> Нажми <b>Shift-R</b> чтобы очистить свое выделение.<font size="12"><br /></font>
<font size="12" color="rgb(150, 150, 150)"><b>Группировка</b></font>
<font color="rgb(150, 150, 150)">•</font> Группируй части как <i>модель</i> нажав <b>Shift-G</b>.
<font color="rgb(150, 150, 150)">•</font> Группируй части как <i>папку</i> нажав <b>Shift-F</b>.
<font color="rgb(150, 150, 150)">•</font> Разгруппируй части нажав <b>Shift-U</b>.<font size="12"><br /></font>
<font size="12" color="rgb(150, 150, 150)"><b>Экспорт</b></font>
]]

-- Create component
local AboutPane = Roact.PureComponent:extend(script.Name)

function AboutPane:init()
    self.DockSize, self.SetDockSize = Roact.createBinding(UDim2.new())
    self.Maid = Maid.new()
end

function AboutPane:willUnmount()
    self.Maid:Destroy()
end

function AboutPane:render()
    return new('ImageButton', {
        Image = '';
        BackgroundTransparency = Theme.dockTransparency;
        BackgroundColor3 = Theme.panel;
        LayoutOrder = self.props.LayoutOrder;
        Size = UDim2.new(1, 0, 0, 32);
        [Roact.Event.Activated] = function (rbx)
            self:setState({
                IsManualOpen = not self.state.IsManualOpen;
            })
        end;
        [Roact.Event.MouseButton1Down] = function (rbx)
            local Dock = rbx.Parent
            local InitialAbsolutePosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
            local InitialPosition = Dock.Position

            self.Maid.DockDragging = UserInputService.InputChanged:Connect(function (Input)
                if (Input.UserInputType.Name == 'MouseMovement') or (Input.UserInputType.Name == 'Touch') then

                    -- Suppress activation response if dragging detected
                    if (Vector2.new(Input.Position.X, Input.Position.Y) - InitialAbsolutePosition).Magnitude > 3 then
                        rbx.Active = false
                    end

                    -- Reposition dock
                    Dock.Position = UDim2.new(
                        InitialPosition.X.Scale,
                        InitialPosition.X.Offset + (Input.Position.X - InitialAbsolutePosition.X),
                        InitialPosition.Y.Scale,
                        InitialPosition.Y.Offset + (Input.Position.Y - InitialAbsolutePosition.Y)
                    )
                end
            end)

            self.Maid.DockDraggingEnd = UserInputService.InputEnded:Connect(function (Input)
                if (Input.UserInputType.Name == 'MouseButton1') or (Input.UserInputType.Name == 'Touch') then
                    self.Maid.DockDragging = nil
                    self.Maid.DockDraggingEnd = nil
                    rbx.Active = true
                end
            end)
        end;
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
            Color = Theme.border;
            Thickness = 1;
            Transparency = 0.5;
        });
        Signature = new('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 13);
            Image = 'rbxassetid://2326685066';
            Position = UDim2.new(0, 6, 0.5, 0);
        }, {
            AspectRatio = new('UIAspectRatioConstraint', {
                AspectRatio = 2.385;
            });
        });
        HelpIcon = new('ImageLabel', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.new(0, 30, 0, 30);
            Image = 'rbxassetid://141911973';

        });
        ManualWindowPortal = new(Roact.Portal, {
            target = self.props.Core.UI;
        }, {
            ManualWindow = (self.state.IsManualOpen or nil) and new(ToolManualWindow, {
                Text = MANUAL_CONTENT;
                ThemeColor = Theme.accent;
            });
        });
    })
end

return AboutPane