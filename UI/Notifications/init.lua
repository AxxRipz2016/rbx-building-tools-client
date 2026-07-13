local Root = script:FindFirstAncestorWhichIsA('Tool')
local Libraries = Root:WaitForChild('Libraries')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local fastSpawn = require(Libraries:WaitForChild('fastSpawn'))

-- Roact
local new = Roact.createElement
local NotificationDialog = require(script:WaitForChild('NotificationDialog'))

-- Create component
local Notifications = Roact.PureComponent:extend(script.Name)

function Notifications:init()
    self.Active = true
    local Tool = script:FindFirstAncestorWhichIsA('Tool')
    self:setState({
        ShouldWarnAboutHttpService = false;
        ShouldWarnAboutUpdate = false;
        ShouldWarnAboutUnofficial = Tool and Tool:GetAttribute('BTClientOnly') == true;
    })

    fastSpawn(function ()
        local IsOutdated = self.props.Core.IsVersionOutdated()
        if self.Active then
            self:setState({
                ShouldWarnAboutUpdate = IsOutdated;
            })
        end
    end)
    fastSpawn(function ()
        local Core = self.props.Core
        local IsHttpServiceDisabled = (Core.Mode == 'Tool') and
            not Core.SyncAPI:Invoke('IsHttpServiceEnabled')
        if self.Active then
            self:setState({
                ShouldWarnAboutHttpService = IsHttpServiceDisabled;
            })
        end
    end)
end

function Notifications:willUnmount()
    self.Active = false
end

function Notifications:render()
    return new('ScreenGui', {}, {
        Container = new('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(0.5, 0, 0.5, 0);
            Size = UDim2.new(0, 300, 1, 0);
        }, {
            Layout = new('UIListLayout', {
                Padding = UDim.new(0, 10);
                FillDirection = Enum.FillDirection.Vertical;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                SortOrder = Enum.SortOrder.LayoutOrder;
            });
            UnofficialNotification = (self.state.ShouldWarnAboutUnofficial or nil) and new(NotificationDialog, {
                LayoutOrder = 0;
                ThemeColor = Color3.fromRGB(255, 140, 50);
                NoticeText = 'Это <b><font color="rgb(200, 0, 0)">ПИРАТСКАЯ</font></b> версия кубика (Building Tools).';
                DetailText = 'Клиентский порт, не оригинал от F3X Team. Возможны баги и ограничения.';
                OnDismiss = function ()
                    self:setState({
                        ShouldWarnAboutUnofficial = false;
                    })
                end;
            });
            UpdateNotification = (self.state.ShouldWarnAboutUpdate or nil) and new(NotificationDialog, {
                LayoutOrder = 2;
                ThemeColor = Color3.fromRGB(255, 170, 0);
                NoticeText = 'This version of Building Tools is <b>outdated.</b>';
                DetailText = (self.props.Core.Mode == 'Plugin') and
                    'To update plugins, go to\n<b>PLUGINS</b> > <b>Manage Plugins</b> :-)' or
                    'Own this place? Simply <b>reinsert</b> the Building Tools model.';
                OnDismiss = function ()
                    self:setState({
                        ShouldWarnAboutUpdate = false;
                    })
                end;
            });
            HTTPEnabledNotification = (self.state.ShouldWarnAboutHttpService or nil) and new(NotificationDialog, {
                LayoutOrder = 1;
                ThemeColor = Color3.fromRGB(255, 0, 4);
                NoticeText = 'HTTP запросы должны быть <b>включены</b> для некоторых функций кубика, включая экспорт.';
                DetailText = 'Пиздабоство, в чите они не нужны.';
                OnDismiss = function ()
                    self:setState({
                        ShouldWarnAboutHttpService = false;
                    })
                end;
            });
        });
    })
end

return Notifications