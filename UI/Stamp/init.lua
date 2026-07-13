local Root = script.Parent.Parent
local Libraries = Root:WaitForChild("Libraries")
local Vendor = Root:WaitForChild("Vendor")

local Roact = require(Vendor:WaitForChild("Roact"))
local Theme = require(Root.UI:WaitForChild("Theme"))
local StampLibrary = require(Libraries:WaitForChild("StampLibrary"))
local Support = require(Libraries:WaitForChild("SupportLibrary"))

local new = Roact.createElement

local StampPanel = Roact.PureComponent:extend("StampPanel")

function StampPanel:init()
	self.viewportRef = Roact.createRef()
	self:setState({
		stamps = StampLibrary.list(),
		selectedId = nil,
		name = "",
		status = "Выдели постройку и нажми «Сохранить» (папка BT-BuildingTools/stamps)",
	})
end

function StampPanel:refreshStampList(selectedId)
	local stamps = StampLibrary.list()
	self:setState({
		stamps = stamps,
		selectedId = selectedId or self.state.selectedId,
		status = #stamps == 0 and "Список пуст" or self.state.status,
	})
end

function StampPanel:updatePreview(stampId)
	local viewport = self.viewportRef.current
	if not viewport then
		return
	end

	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end

	if not stampId then
		return
	end

	local stamp = StampLibrary.find(stampId)
	if not stamp then
		return
	end

	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport

	local roots = StampLibrary.inflate(stamp)
	for _, item in ipairs(roots) do
		item.Parent = world
	end

	local parts = StampLibrary.getPartsFromRoots(roots)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	StampLibrary.focusCameraOnParts(camera, parts)
end

function StampPanel:didMount()
	local stamps = StampLibrary.list()
	if #stamps > 0 and not self.state.selectedId then
		local first = stamps[1]
		self:setState({
			selectedId = first.id,
			status = "Выбран: " .. first.name,
		})
		if self.props.OnSelectStamp then
			self.props.OnSelectStamp(first.id)
		end
		self:updatePreview(first.id)
	else
		self:updatePreview(self.state.selectedId)
	end
end

function StampPanel:didUpdate(previousProps, previousState)
	if previousState.selectedId ~= self.state.selectedId then
		self:updatePreview(self.state.selectedId)
	end
end

function StampPanel:render()
	local stampButtons = {}
	for index, stamp in ipairs(self.state.stamps) do
		local isSelected = stamp.id == self.state.selectedId
		stampButtons[tostring(index)] = new("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = isSelected and Theme.accent or Theme.surface,
			BackgroundTransparency = isSelected and 0.1 or 0.2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Text = stamp.name,
			TextColor3 = Theme.text,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[Roact.Event.Activated] = function()
				self:setState({
					selectedId = stamp.id,
					status = "Выбран: " .. stamp.name,
				})
				if self.props.OnSelectStamp then
					self.props.OnSelectStamp(stamp.id)
				end
			end,
		}, {
			Corner = new("UICorner", {
				CornerRadius = UDim.new(0, Theme.cornerRadiusXs),
			}),
		})
	end

	return new("Frame", {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0.5, -170),
		Size = UDim2.fromOffset(280, 308),
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
			Padding = UDim.new(0, 6),
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
			Text = "STAMP",
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
		Viewport = new("ViewportFrame", {
			[Roact.Ref] = self.viewportRef,
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 140),
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
		NameBox = new("TextBox", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Theme.surface,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			PlaceholderText = "Имя stamp…",
			PlaceholderColor3 = Theme.textDim,
			Text = self.state.name,
			TextColor3 = Theme.text,
			TextSize = 11,
			[Roact.Change.Text] = function(rbx)
				self:setState({ name = rbx.Text })
			end,
		}, {
			Corner = new("UICorner", {
				CornerRadius = UDim.new(0, Theme.cornerRadiusXs),
			}),
			Padding = new("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}),
		Actions = new("Frame", {
			LayoutOrder = 5,
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
				BackgroundColor3 = Theme.accent,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "Сохранить",
				TextColor3 = Theme.text,
				TextSize = 11,
				[Roact.Event.Activated] = function()
					local stamp, err = StampLibrary.saveFromSelection(self.state.name, self.props.Core.Selection.Items)
					if not stamp then
						self:setState({ status = err or "Ошибка сохранения" })
						return
					end
					self:refreshStampList(stamp.id)
					self:setState({
						name = "",
						status = "Сохранено в " .. StampLibrary.getStoragePath() .. ": " .. stamp.name,
					})
					if self.props.OnSelectStamp then
						self.props.OnSelectStamp(stamp.id)
					end
					self:updatePreview(stamp.id)
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Delete = new("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(0.5, -3, 1, 0),
				BackgroundColor3 = Theme.surface,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = "Удалить",
				TextColor3 = Theme.text,
				TextSize = 11,
				[Roact.Event.Activated] = function()
					if not self.state.selectedId then
						self:setState({ status = "Выбери stamp из списка" })
						return
					end
					StampLibrary.delete(self.state.selectedId)
					self:refreshStampList(nil)
					self:setState({
						selectedId = nil,
						status = "Stamp удалён",
					})
					if self.props.OnSelectStamp then
						self.props.OnSelectStamp(nil)
					end
					self:updatePreview(nil)
				end,
			}, {
				Corner = new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),
		List = new("ScrollingFrame", {
			LayoutOrder = 6,
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = Theme.background,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, SupportMerge(stampButtons, {
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
		Hint = new("TextLabel", {
			LayoutOrder = 7,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Font = Enum.Font.GothamMedium,
			Text = "Клик по миру — поставить stamp",
			TextColor3 = Theme.textDim,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
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

return StampPanel
