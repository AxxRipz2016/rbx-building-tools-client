local Root = script.Parent.Parent
local Libraries = Root:WaitForChild("Libraries")
local Vendor = Root:WaitForChild("Vendor")

local Roact = require(Vendor:WaitForChild("Roact"))
local Theme = require(Root.UI:WaitForChild("Theme"))
local MapLibrary = require(Libraries:WaitForChild("MapLibrary"))
local Support = require(Libraries:WaitForChild("SupportLibrary"))

local new = Roact.createElement

local MapSaverPanel = Roact.PureComponent:extend("MapSaverPanel")

local SAVE_SOURCE_LABELS = {
	selection = "Выделение",
	scope = "Scope",
	all = "Всё",
}

function MapSaverPanel:init()
	self.viewportRef = Roact.createRef()
	self:setState({
		maps = MapLibrary.list(),
		selectedId = nil,
		name = "",
		settings = Support.CloneTable(self.props.SaveSettings or MapLibrary.getDefaultSettings()),
		status = "Сохраняй и загружай постройки на карте.",
	})
end

function MapSaverPanel:refreshMapList(selectedId, status)
	local maps = MapLibrary.list()
	self:setState({
		maps = maps,
		selectedId = selectedId or self.state.selectedId,
		status = status or (#maps == 0 and "Список пуст" or self.state.status),
	})
end

function MapSaverPanel:updateSettings(patch)
	local settings = Support.CloneTable(self.state.settings)
	for key, value in pairs(patch) do
		settings[key] = value
	end
	self:setState({ settings = settings })
	if self.props.OnSaveSettingsChanged then
		self.props.OnSaveSettingsChanged(settings)
	end
end

function MapSaverPanel:updatePreview(mapId)
	local viewport = self.viewportRef.current
	if not viewport then
		return
	end

	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end

	if not mapId then
		return
	end

	local map = MapLibrary.find(mapId)
	if not map then
		return
	end

	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport

	local roots = MapLibrary.inflate(map)
	for _, item in ipairs(roots) do
		item.Parent = world
	end

	local parts = MapLibrary.getPartsFromRoots(roots)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	MapLibrary.focusCameraOnParts(camera, parts)
end

function MapSaverPanel:selectMap(mapId, status)
	self:setState({
		selectedId = mapId,
		status = status,
	})
	if self.props.OnSelectMap then
		self.props.OnSelectMap(mapId)
	end
	self:updatePreview(mapId)
end

function MapSaverPanel:didMount()
	local maps = MapLibrary.list()
	if #maps > 0 and not self.state.selectedId then
		self:selectMap(maps[1].id, "Выбрана: " .. maps[1].name)
	else
		self:updatePreview(self.state.selectedId)
	end
end

function MapSaverPanel:didUpdate(previousProps, previousState)
	if previousState.selectedId ~= self.state.selectedId then
		self:updatePreview(self.state.selectedId)
	end
end

function MapSaverPanel:renderCheckbox(layoutOrder, label, checked, onToggle)
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

function MapSaverPanel:render()
	local mapButtons = {}
	for index, map in ipairs(self.state.maps) do
		local isSelected = map.id == self.state.selectedId
		local autoLoad = map.settings and map.settings.autoLoad
		mapButtons[tostring(index)] = new("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = isSelected and Theme.accent or Theme.surface,
			BackgroundTransparency = isSelected and 0.1 or 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Text = (autoLoad and "★ " or "") .. map.name,
			TextColor3 = Theme.text,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[Roact.Event.Activated] = function()
				self:selectMap(map.id, "Выбрана: " .. map.name)
			end,
		}, {
			Corner = new("UICorner", {
				CornerRadius = UDim.new(0, Theme.cornerRadiusXs),
			}),
		})
	end

	local sourceButtons = {}
	local order = 0
	for key, label in pairs(SAVE_SOURCE_LABELS) do
		order += 1
		local isActive = self.state.settings.saveSource == key
		sourceButtons[key] = new("TextButton", {
			LayoutOrder = order,
			Size = UDim2.new(0.33, -4, 1, 0),
			BackgroundColor3 = isActive and Theme.accent or Theme.surface,
			BackgroundTransparency = isActive and 0.1 or 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = label,
			TextColor3 = Theme.text,
			TextSize = 9,
			[Roact.Event.Activated] = function()
				self:updateSettings({ saveSource = key })
			end,
		}, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
	end

	return new("Frame", {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0.5, -210),
		Size = UDim2.fromOffset(300, 420),
	}, {
		Corner = new("UICorner", {
			CornerRadius = UDim.new(0, Theme.cornerRadius),
		}),
		Stroke = new("UIStroke", {
			Color = Theme.border,
			Thickness = 1,
			Transparency = 0.35,
		}),
		Layout = new("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
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
			Text = "MAP SAVER",
			TextColor3 = Theme.success,
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
		SourceRow = new("Frame", {
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
		}, SupportMerge(sourceButtons, {
			Layout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})),
		Settings = new("Frame", {
			LayoutOrder = 4,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 96),
		}, {
			Layout = new("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Unions = self:renderCheckbox(1, "Сохранять Union", self.state.settings.includeUnions, function()
				self:updateSettings({ includeUnions = not self.state.settings.includeUnions })
			end),
			OnlyMine = self:renderCheckbox(2, "Только мои постройки (BTUserId)", self.state.settings.onlyMine, function()
				self:updateSettings({ onlyMine = not self.state.settings.onlyMine })
			end),
			AutoLoad = self:renderCheckbox(3, "Автозагрузка при входе", self.state.settings.autoLoad, function()
				self:updateSettings({ autoLoad = not self.state.settings.autoLoad })
			end),
			Anchor = self:renderCheckbox(4, "Anchor при загрузке", self.state.settings.anchoredOnLoad, function()
				self:updateSettings({ anchoredOnLoad = not self.state.settings.anchoredOnLoad })
			end),
		}),
		Viewport = new("ViewportFrame", {
			[Roact.Ref] = self.viewportRef,
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundColor3 = Theme.background,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Ambient = Color3.fromRGB(180, 180, 190),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-1, -1, -1),
		}, {
			Corner = new("UICorner", {
				CornerRadius = UDim.new(0, Theme.cornerRadiusSm),
			}),
		}),
		List = new("ScrollingFrame", {
			LayoutOrder = 6,
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = Theme.background,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, SupportMerge(mapButtons, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Layout = new("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Padding = new("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
		})),
		NameBox = new("TextBox", {
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = Theme.surface,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			PlaceholderText = "Имя карты…",
			PlaceholderColor3 = Theme.textDim,
			Text = self.state.name,
			TextColor3 = Theme.text,
			TextSize = 11,
			[Roact.Change.Text] = function(rbx)
				self:setState({ name = rbx.Text })
			end,
		}, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, Theme.cornerRadiusXs) }),
			Padding = new("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}),
		Actions = new("Frame", {
			LayoutOrder = 8,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
		}, {
			Layout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Save = new("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.new(0.5, -3, 1, 0),
				BackgroundColor3 = Theme.success,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "Сохранить",
				TextColor3 = Theme.text,
				TextSize = 10,
				[Roact.Event.Activated] = function()
					if not self.props.OnSaveMap then
						return
					end
					local ok, message, mapId = self.props.OnSaveMap(self.state.name, self.state.settings)
					if not ok then
						warn("[BT Map UI]", message)
					end
					self:setState({ status = message or (ok and "Сохранено" or "Ошибка") })
					if ok then
						self:refreshMapList(mapId or self.state.selectedId)
						self:setState({ name = "" })
						if mapId then
							self:selectMap(mapId, message)
						end
					end
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Load = new("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(0.5, -3, 1, 0),
				BackgroundColor3 = Theme.accent,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "Загрузить",
				TextColor3 = Theme.text,
				TextSize = 10,
				[Roact.Event.Activated] = function()
					if not self.props.OnLoadMap or not self.state.selectedId then
						self:setState({ status = "Выбери карту из списка" })
						return
					end
					local ok, message = self.props.OnLoadMap(self.state.selectedId)
					self:setState({ status = message or (ok and "Загружено" or "Ошибка") })
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),
		BottomActions = new("Frame", {
			LayoutOrder = 9,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
		}, {
			Layout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Reload = new("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.new(0.34, -4, 1, 0),
				BackgroundColor3 = Theme.surface,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "Обновить",
				TextColor3 = Theme.text,
				TextSize = 9,
				[Roact.Event.Activated] = function()
					local maps = MapLibrary.reload()
					self:refreshMapList(self.state.selectedId, "Карт: " .. #maps)
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Delete = new("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(0.33, -4, 1, 0),
				BackgroundColor3 = Theme.surface,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "Удалить",
				TextColor3 = Theme.text,
				TextSize = 9,
				[Roact.Event.Activated] = function()
					if not self.state.selectedId then
						self:setState({ status = "Выбери карту" })
						return
					end
					MapLibrary.delete(self.state.selectedId)
					self:refreshMapList(nil, "Карта удалена")
					self:setState({ selectedId = nil })
					if self.props.OnSelectMap then
						self.props.OnSelectMap(nil)
					end
					self:updatePreview(nil)
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			AutoToggle = new("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.new(0.33, -4, 1, 0),
				BackgroundColor3 = Theme.surface,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "★ Авто",
				TextColor3 = Theme.text,
				TextSize = 9,
				[Roact.Event.Activated] = function()
					if not self.state.selectedId or not self.props.OnToggleAutoLoad then
						self:setState({ status = "Выбери карту" })
						return
					end
					local map = MapLibrary.find(self.state.selectedId)
					local enabled = not (map and map.settings and map.settings.autoLoad)
					local ok, message = self.props.OnToggleAutoLoad(self.state.selectedId, enabled)
					self:refreshMapList(self.state.selectedId, message)
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),
	})
end

function SupportMerge(...)
	local result = {}
	for i = 1, select("#", ...) do
		local chunk = select(i, ...)
		for key, value in pairs(chunk) do
			result[key] = value
		end
	end
	return result
end

return MapSaverPanel
