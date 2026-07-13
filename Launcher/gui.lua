local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Gui = {}

local COLORS = {
	background = Color3.fromRGB(28, 28, 32),
	accent = Color3.fromRGB(255, 140, 50),
	accentDim = Color3.fromRGB(60, 45, 35),
	text = Color3.fromRGB(235, 235, 240),
	textDim = Color3.fromRGB(150, 150, 160),
	error = Color3.fromRGB(255, 90, 90),
	success = Color3.fromRGB(90, 220, 130),
	track = Color3.fromRGB(45, 45, 52),
}

local function createLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = COLORS.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	for key, value in pairs(props) do
		label[key] = value
	end
	label.Parent = parent
	return label
end

function Gui.create()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BTLauncher"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = screenGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(440, 248)
	root.BackgroundColor3 = COLORS.background
	root.BorderSizePixel = 0
	root.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(55, 55, 65)
	stroke.Thickness = 1
	stroke.Parent = root

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root

	createLabel(root, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBold,
		Text = "Building Tools",
		TextSize = 20,
		TextColor3 = COLORS.accent,
	})

	createLabel(root, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Text = "Неофициальный клиентский порт · не оригинал F3X",
		TextSize = 11,
		TextColor3 = COLORS.textDim,
		TextWrapped = true,
	})

	local statusLabel = createLabel(root, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Подготовка…",
		TextSize = 15,
	})

	local fileLabel = createLabel(root, {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextSize = 13,
		TextColor3 = COLORS.textDim,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local progressRow = Instance.new("Frame")
	progressRow.LayoutOrder = 4
	progressRow.Size = UDim2.new(1, 0, 0, 22)
	progressRow.BackgroundTransparency = 1
	progressRow.Parent = root

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -52, 1, 0)
	track.BackgroundColor3 = COLORS.track
	track.BorderSizePixel = 0
	track.Parent = progressRow

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLORS.accent
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local counterLabel = createLabel(progressRow, {
		Position = UDim2.new(1, -48, 0, 0),
		Size = UDim2.fromOffset(48, 22),
		Text = "0 / 0",
		TextSize = 13,
		TextColor3 = COLORS.textDim,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local closeButton = Instance.new("TextButton")
	closeButton.LayoutOrder = 5
	closeButton.Size = UDim2.new(1, 0, 0, 32)
	closeButton.BackgroundColor3 = COLORS.accentDim
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamMedium
	closeButton.Text = "Закрыть"
	closeButton.TextColor3 = COLORS.text
	closeButton.TextSize = 14
	closeButton.Visible = false
	closeButton.Parent = root

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	screenGui.Parent = playerGui

	local api = {}
	local destroyed = false

	local function tweenFill(ratio)
		ratio = math.clamp(ratio, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(ratio, 1),
		}):Play()
	end

	function api.setStatus(text)
		if destroyed then
			return
		end
		statusLabel.Text = text
	end

	function api.setFile(text)
		if destroyed then
			return
		end
		fileLabel.Text = text or ""
	end

	function api.setProgress(current, total)
		if destroyed then
			return
		end
		counterLabel.Text = string.format("%d / %d", current, total)
		tweenFill(total > 0 and current / total or 0)
	end

	function api.setError(title, details)
		if destroyed then
			return
		end
		statusLabel.Text = title or "Ошибка"
		statusLabel.TextColor3 = COLORS.error
		fileLabel.Text = details or ""
		fileLabel.TextColor3 = COLORS.error
		fileLabel.TextWrapped = true
		fill.BackgroundColor3 = COLORS.error
		closeButton.Visible = true
	end

	function api.setSuccess(message)
		if destroyed then
			return
		end
		statusLabel.Text = message or "Готово!"
		statusLabel.TextColor3 = COLORS.success
		fileLabel.Text = "Экипируй Tool из Backpack"
		fileLabel.TextColor3 = COLORS.textDim
		tweenFill(1)
		task.delay(2.5, function()
			if not destroyed then
				api.destroy()
			end
		end)
	end

	function api.onClose(callback)
		closeButton.MouseButton1Click:Connect(function()
			if callback then
				callback()
			end
			api.destroy()
		end)
	end

	function api.destroy()
		if destroyed then
			return
		end
		destroyed = true
		screenGui:Destroy()
	end

	api.onClose()

	return api
end

return Gui
