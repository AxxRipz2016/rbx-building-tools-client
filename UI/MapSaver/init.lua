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

local PLACE_FILTER_LABELS = {
	all = "Все place",
	this_place = "Этот place",
	other_places = "Другие",
}

local SORT_LABELS = {
	newest = "Новые",
	oldest = "Старые",
	name = "Имя",
}

function MapSaverPanel:getFilterOptions()
	return {
		placeFilter = self.state.placeFilter or "this_place",
		searchQuery = self.state.searchQuery or "",
		autoLoadOnly = self.state.autoLoadOnly == true,
		sortBy = self.state.sortBy or "newest",
	}
end

function MapSaverPanel:getFilteredMaps()
	return MapLibrary.filterMaps(MapLibrary.list(), self:getFilterOptions())
end

function MapSaverPanel:init()
	self:setState({
		maps = MapLibrary.list(),
		selectedId = nil,
		name = "",
		searchQuery = "",
		placeFilter = "this_place",
		autoLoadOnly = false,
		sortBy = "newest",
		settings = Support.CloneTable(self.props.SaveSettings or MapLibrary.getDefaultSettings()),
		status = string.format("Place ID: %s — фильтр «Этот place».", tostring(game.PlaceId)),
	})
end

function MapSaverPanel:refreshMapList(selectedId, status)
	local filtered = self:getFilteredMaps()
	self:setState({
		maps = filtered,
		selectedId = selectedId or self.state.selectedId,
		status = status or (#filtered == 0 and "Нет карт по фильтру" or self.state.status),
	})
end

function MapSaverPanel:updateListFilters(patch)
	local nextPlaceFilter = patch.placeFilter or self.state.placeFilter
	local nextSearchQuery = if patch.searchQuery ~= nil then patch.searchQuery else self.state.searchQuery
	local nextAutoLoadOnly = if patch.autoLoadOnly ~= nil then patch.autoLoadOnly else self.state.autoLoadOnly
	local nextSortBy = patch.sortBy or self.state.sortBy
	local nextStatus = patch.status or self.state.status

	local filtered = MapLibrary.filterMaps(MapLibrary.list(), {
		placeFilter = nextPlaceFilter,
		searchQuery = nextSearchQuery,
		autoLoadOnly = nextAutoLoadOnly,
		sortBy = nextSortBy,
	})

	local selectedId = self.state.selectedId
	local selectedStillVisible = false
	for _, map in ipairs(filtered) do
		if map.id == selectedId then
			selectedStillVisible = true
			break
		end
	end

	self:setState({
		placeFilter = nextPlaceFilter,
		searchQuery = nextSearchQuery,
		autoLoadOnly = nextAutoLoadOnly,
		sortBy = nextSortBy,
		status = nextStatus,
		maps = filtered,
		selectedId = selectedStillVisible and selectedId or nil,
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

function MapSaverPanel:selectMap(mapId, status)
	self:setState({
		selectedId = mapId,
		status = status,
	})
	if self.props.OnSelectMap then
		self.props.OnSelectMap(mapId)
	end
end

function MapSaverPanel:didMount()
	local filtered = self:getFilteredMaps()
	self:setState({ maps = filtered })
	if #filtered > 0 and not self.state.selectedId then
		self:selectMap(filtered[1].id, "Выбрана: " .. filtered[1].name)
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
	local showPlaceId = self.state.placeFilter == "all" or self.state.placeFilter == "other_places"
	local mapButtons = {}
	for index, map in ipairs(self.state.maps) do
		local isSelected = map.id == self.state.selectedId
		mapButtons[tostring(index)] = new("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = isSelected and Theme.accent or Theme.surface,
			BackgroundTransparency = isSelected and 0.1 or 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Text = MapLibrary.formatMapLabel(map, showPlaceId),
			TextColor3 = Theme.text,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[Roact.Event.Activated] = function()
				local placeInfo = map.placeId and (" | place " .. tostring(map.placeId)) or ""
				self:selectMap(map.id, "Выбрана: " .. map.name .. placeInfo)
			end,
		}, {
			Corner = new("UICorner", {
				CornerRadius = UDim.new(0, Theme.cornerRadiusXs),
			}),
		})
	end

	local sourceButtons = {}
	local sourceOrder = 0
	for _, key in ipairs({ "selection", "scope", "all" }) do
		sourceOrder += 1
		local label = SAVE_SOURCE_LABELS[key]
		local isActive = self.state.settings.saveSource == key
		sourceButtons[key] = new("TextButton", {
			LayoutOrder = sourceOrder,
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

	local placeFilterButtons = {}
	local placeOrder = 0
	for _, key in ipairs({ "all", "this_place", "other_places" }) do
		placeOrder += 1
		local isActive = self.state.placeFilter == key
		placeFilterButtons[key] = new("TextButton", {
			LayoutOrder = placeOrder,
			Size = UDim2.new(0.33, -4, 1, 0),
			BackgroundColor3 = isActive and Theme.accentBright or Theme.surface,
			BackgroundTransparency = isActive and 0.1 or 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = PLACE_FILTER_LABELS[key],
			TextColor3 = Theme.text,
			TextSize = 8,
			[Roact.Event.Activated] = function()
				self:updateListFilters({
					placeFilter = key,
					status = string.format("Place ID: %s | фильтр: %s", tostring(game.PlaceId), PLACE_FILTER_LABELS[key]),
				})
			end,
		}, {
			Corner = new("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
	end

	return new("Frame", {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0.5, -230),
		Size = UDim2.fromOffset(300, 460),
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
			WorldChanges = self:renderCheckbox(5, "Сохранять изменения мира (beta)", self.state.settings.saveWorldChanges, function()
				self:updateSettings({ saveWorldChanges = not self.state.settings.saveWorldChanges })
			end),
		}),
		PlaceFilterRow = new("Frame", {
			LayoutOrder = 5,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
		}, SupportMerge(placeFilterButtons, {
			Layout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})),
		SearchRow = new("Frame", {
			LayoutOrder = 6,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
		}, {
			Layout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Search = new("TextBox", {
				LayoutOrder = 1,
				Size = UDim2.new(0.62, 0, 1, 0),
				BackgroundColor3 = Theme.surface,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				Font = Enum.Font.Gotham,
				PlaceholderText = "Поиск по имени / place ID…",
				PlaceholderColor3 = Theme.textDim,
				Text = self.state.searchQuery,
				TextColor3 = Theme.text,
				TextSize = 10,
				[Roact.Change.Text] = function(rbx)
					self:updateListFilters({ searchQuery = rbx.Text })
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Padding = new("UIPadding", {
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
				}),
			}),
			Sort = new("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(0.19, 0, 1, 0),
				BackgroundColor3 = Theme.surface,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = SORT_LABELS[self.state.sortBy] or "Новые",
				TextColor3 = Theme.text,
				TextSize = 8,
				[Roact.Event.Activated] = function()
					local order = { "newest", "oldest", "name" }
					local currentIndex = 1
					for index, key in ipairs(order) do
						if key == self.state.sortBy then
							currentIndex = index
							break
						end
					end
					local nextKey = order[(currentIndex % #order) + 1]
					self:updateListFilters({ sortBy = nextKey })
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}),
			AutoOnly = new("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.new(0.19, 0, 1, 0),
				BackgroundColor3 = self.state.autoLoadOnly and Theme.accent or Theme.surface,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "★",
				TextColor3 = Theme.text,
				TextSize = 10,
				[Roact.Event.Activated] = function()
					self:updateListFilters({ autoLoadOnly = not self.state.autoLoadOnly })
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}),
		}),
		List = new("ScrollingFrame", {
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, 140),
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
			LayoutOrder = 9,
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
			LayoutOrder = 10,
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
			LayoutOrder = 11,
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
					MapLibrary.reload()
					self:refreshMapList(self.state.selectedId, "Карт по фильтру: " .. #self:getFilteredMaps())
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
