local Theme = require(script.Parent:WaitForChild("Theme"))

local LegacyPanelTheme = {}

local PANEL_ACCENTS = {
	BTMoveToolGUI = BrickColor.new("Deep orange").Color,
	BTResizeToolGUI = BrickColor.new("Cyan").Color,
	BTRotateToolGUI = BrickColor.new("Bright green").Color,
	BTPaintToolGUI = BrickColor.new("Really red").Color,
	BTSurfaceToolGUI = BrickColor.new("Bright violet").Color,
	BTMaterialToolGUI = BrickColor.new("Bright violet").Color,
	BTAnchorToolGUI = Color3.fromRGB(140, 145, 155),
	BTCollisionToolGUI = Color3.fromRGB(140, 145, 155),
	BTNewPartToolGUI = Color3.fromRGB(140, 145, 155),
	BTMeshToolGUI = BrickColor.new("Bright violet").Color,
	BTTextureToolGUI = BrickColor.new("Bright violet").Color,
	BTWeldToolGUI = Color3.fromRGB(140, 145, 155),
	BTLightingToolGUI = Color3.fromRGB(255, 210, 80),
	BTDecorateToolGUI = Color3.fromRGB(255, 180, 90),
}

local LEGACY_PANEL = Color3.fromRGB(23, 23, 24)
local LEGACY_BAR = Color3.fromRGB(17, 17, 17)
local SLANTED_SHAPE = "rbxassetid://127772502"

local function isNearColor(color, target, tolerance)
	tolerance = tolerance or 3
	return math.abs(color.R * 255 - target.R * 255) <= tolerance
		and math.abs(color.G * 255 - target.G * 255) <= tolerance
		and math.abs(color.B * 255 - target.B * 255) <= tolerance
end

local function styleTextObject(object, isTitle)
	if object.Font == Enum.Font.ArialBold or object.Font == Enum.Font.GothamBold then
		object.Font = isTitle and Enum.Font.GothamBold or Enum.Font.GothamSemibold
	elseif object.Font == Enum.Font.Arial or object.Font == Enum.Font.SourceSans or object.Font == Enum.Font.Legacy then
		object.Font = Enum.Font.GothamMedium
	end
	object.TextColor3 = isTitle and Theme.text or Theme.textDim
	object.TextStrokeTransparency = 1
	if isTitle then
		object.TextSize = math.max(object.TextSize, 12)
	end
end

local function styleOptionBackground(imageLabel, accent)
	imageLabel.Image = SLANTED_SHAPE
	imageLabel.ImageColor3 = Theme.surface
	imageLabel.ImageTransparency = 0.08
	imageLabel.BackgroundTransparency = 1
end

local function ensureBackdrop(panel, accent)
	if panel:FindFirstChild("BTPanelBackdrop") then
		return
	end

	panel:SetAttribute("BTAccentColor", accent)

	local backdrop = Instance.new("Frame")
	backdrop.Name = "BTPanelBackdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.panel
	backdrop.BackgroundTransparency = Theme.panelTransparency
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 0
	backdrop.Parent = panel

	Theme.ensureCorner(backdrop, Theme.cornerRadius)
	Theme.ensureGradient(backdrop, Theme.panelLight, Theme.background, 105)
	Theme.accentStroke(backdrop, accent, 0.7)

	local accentLine = Instance.new("Frame")
	accentLine.Name = "AccentLine"
	accentLine.AnchorPoint = Vector2.new(0, 0)
	accentLine.Position = UDim2.new(0, 0, 0, 0)
	accentLine.Size = UDim2.new(1, 0, 0, 4)
	accentLine.BackgroundColor3 = accent
	accentLine.BorderSizePixel = 0
	accentLine.ZIndex = 1
	accentLine.Parent = backdrop

	local accentGradient = Instance.new("UIGradient")
	local gradientOk = pcall(function()
		accentGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent),
			ColorSequenceKeypoint.new(1, Theme.accentBright),
		})
	end)
	if not gradientOk then
		accentLine.BackgroundColor3 = accent
		accentGradient:Destroy()
	end
	accentGradient.Rotation = 0
	accentGradient.Parent = accentLine

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, Theme.cornerRadius)
	accentCorner.Parent = accentLine
end

function LegacyPanelTheme.getAccent(panel)
	return panel:GetAttribute("BTAccentColor") or PANEL_ACCENTS[panel.Name] or Theme.accent
end

function LegacyPanelTheme.applyToPanel(panel)
	if not panel:IsA("GuiObject") or panel.Name:sub(1, 2) ~= "BT" then
		return
	end

	local accent = PANEL_ACCENTS[panel.Name] or Theme.accent
	ensureBackdrop(panel, accent)

	for _, descendant in ipairs(panel:GetDescendants()) do
		if descendant:IsA("Frame") and descendant.Name == "ColorBar" then
			local parentName = descendant.Parent and descendant.Parent.Name
			if parentName == "Title" or isNearColor(descendant.BackgroundColor3, LEGACY_BAR) then
				descendant.BackgroundColor3 = accent
				descendant.Size = UDim2.new(
					descendant.Size.X.Scale,
					descendant.Size.X.Offset,
					0,
					3
				)
			elseif parentName == "Tip" or parentName == "Changes" then
				descendant.BackgroundColor3 = accent
				descendant.BackgroundTransparency = 0.15
			end
		elseif descendant:IsA("Frame") and descendant.Name == "Background" then
			if isNearColor(descendant.BackgroundColor3, LEGACY_PANEL) then
				descendant.BackgroundColor3 = Theme.surface
				descendant.BackgroundTransparency = 0.12
				descendant.BorderSizePixel = 0
				Theme.ensureCorner(descendant, Theme.cornerRadiusXs)
				Theme.ensureStroke(descendant, Theme.border, 0.5)
			end
		elseif descendant:IsA("ImageLabel") and descendant.Name == "Background" then
			styleOptionBackground(descendant, accent)
		elseif descendant:IsA("Frame") and descendant.Name == "SelectedIndicator" then
			descendant.BackgroundColor3 = accent
			descendant.Size = UDim2.new(
				descendant.Size.X.Scale,
				descendant.Size.X.Offset,
				0,
				3
			)
		elseif descendant:IsA("TextLabel") then
			local parent = descendant.Parent
			local isTitle = parent and parent.Name == "Title" and descendant.Name == "Label"
			local isOptionLabel = parent and parent.Name ~= "Label" and descendant.Name == "Label"
				and parent.Parent and parent.Parent.Name:match("Option")
			if isOptionLabel then
				descendant.Font = Enum.Font.GothamSemibold
				descendant.TextColor3 = Theme.textDim
				descendant.TextStrokeTransparency = 1
				descendant.ZIndex = 5000
			else
				styleTextObject(descendant, isTitle)
			end
		elseif descendant:IsA("TextButton") then
			styleTextObject(descendant, false)
		elseif descendant:IsA("TextBox") then
			styleTextObject(descendant, false)
			descendant.PlaceholderColor3 = Theme.textDim
			descendant.TextColor3 = Theme.text
		end
	end

	for _, child in ipairs(panel:GetDescendants()) do
		if child:IsA("GuiObject") and child.ZIndex > 0 and child.ZIndex < 10 then
			child.ZIndex = math.max(child.ZIndex, 2)
		end
	end
end

function LegacyPanelTheme.applyAll(interfacesFolder)
	for _, child in ipairs(interfacesFolder:GetChildren()) do
		if child:IsA("Frame") and child.Name:sub(1, 2) == "BT" then
			LegacyPanelTheme.applyToPanel(child)
		end
	end
end

return LegacyPanelTheme
