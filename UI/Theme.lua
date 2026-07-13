-- Общая палитра Building Tools (лаунчер + Roact UI + legacy-панели)
local Theme = {
	background = Color3.fromRGB(28, 28, 32),
	panel = Color3.fromRGB(32, 32, 38),
	surface = Color3.fromRGB(44, 44, 52),
	surfaceHover = Color3.fromRGB(56, 56, 66),
	surfaceActive = Color3.fromRGB(68, 68, 80),
	accent = Color3.fromRGB(255, 140, 50),
	accentDim = Color3.fromRGB(200, 110, 45),
	border = Color3.fromRGB(72, 72, 84),
	text = Color3.fromRGB(235, 235, 240),
	textDim = Color3.fromRGB(150, 150, 160),
	error = Color3.fromRGB(255, 90, 90),
	success = Color3.fromRGB(90, 220, 130),
	dockTransparency = 0.12,
	panelTransparency = 0.08,
	cornerRadius = 8,
	cornerRadiusSm = 6,
	cornerRadiusXs = 4,
}

function Theme.ensureCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = instance
	end
	corner.CornerRadius = UDim.new(0, radius or Theme.cornerRadiusSm)
	return corner
end

function Theme.ensureStroke(instance, color, transparency)
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = instance
	end
	stroke.Color = color or Theme.border
	stroke.Thickness = 1
	stroke.Transparency = transparency or 0.35
	return stroke
end

return Theme
