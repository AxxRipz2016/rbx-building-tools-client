-- Общая палитра Building Tools (лаунчер + Roact UI + legacy-панели)
local Theme = {
	background = Color3.fromRGB(18, 18, 22),
	panel = Color3.fromRGB(26, 26, 32),
	panelLight = Color3.fromRGB(36, 36, 44),
	surface = Color3.fromRGB(48, 48, 58),
	surfaceHover = Color3.fromRGB(62, 62, 74),
	surfaceActive = Color3.fromRGB(78, 78, 92),
	accent = Color3.fromRGB(255, 148, 62),
	accentBright = Color3.fromRGB(255, 178, 96),
	accentDim = Color3.fromRGB(190, 95, 35),
	border = Color3.fromRGB(88, 88, 102),
	borderGlow = Color3.fromRGB(255, 148, 62),
	text = Color3.fromRGB(245, 245, 250),
	textDim = Color3.fromRGB(165, 168, 180),
	error = Color3.fromRGB(255, 90, 90),
	success = Color3.fromRGB(90, 220, 130),
	dockTransparency = 0.06,
	panelTransparency = 0.04,
	cornerRadius = 10,
	cornerRadiusSm = 7,
	cornerRadiusXs = 5,
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

function Theme.ensureStroke(instance, color, transparency, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = instance
	end
	stroke.Color = color or Theme.border
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.35
	return stroke
end

function Theme.ensureGradient(instance, topColor, bottomColor, rotation)
	local gradient = instance:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = instance
	end
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor or Theme.panelLight),
		ColorSequenceKeypoint.new(1, bottomColor or Theme.panel),
	})
	gradient.Rotation = rotation or 90
	return gradient
end

function Theme.accentStroke(instance, color, transparency)
	return Theme.ensureStroke(instance, color or Theme.borderGlow, transparency or 0.55, 1.5)
end

return Theme
