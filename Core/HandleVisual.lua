-- Визуал рукоятки Tool: видимый куб с подписью вместо «пустого» Handle
local HandleVisual = {}

local LABEL_TEXT = "пиратский куб"
local CUBE_SIZE = Vector3.new(1, 1, 1)

local function createFaceLabel(handle, face, name)
	local existing = handle:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0
	gui.ZOffset = 0.01
	gui.Parent = handle

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = LABEL_TEXT
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 24)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui

	return gui
end

function HandleVisual.apply(tool)
	if not tool or not tool:IsA("Tool") then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	handle.Size = CUBE_SIZE
	handle.Transparency = 0
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = false
	handle.Material = Enum.Material.SmoothPlastic

	if not handle.BrickColor or handle.BrickColor == BrickColor.new("Medium stone grey") then
		handle.BrickColor = BrickColor.new("Deep orange")
	end

	createFaceLabel(handle, Enum.NormalId.Top, "BTHandleLabelTop")
	createFaceLabel(handle, Enum.NormalId.Front, "BTHandleLabelFront")
end

return HandleVisual
