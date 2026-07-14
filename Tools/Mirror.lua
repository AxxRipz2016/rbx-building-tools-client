Tool = script.Parent.Parent
Core = require(Tool.Core)

local Vendor = Tool:WaitForChild("Vendor")
local UI = Tool:WaitForChild("UI")

local Roact = require(Vendor:WaitForChild("Roact"))
local MirrorPanel = require(UI:WaitForChild("Mirror"))

Selection = Core.Selection
Support = Core.Support
Security = Core.Security
Support.ImportServices()

local CollectionService = game:GetService("CollectionService")

local MirrorTool = {
	Name = "Mirror",
	Color = BrickColor.new("Institutional white"),
}

MirrorTool.ManualText = [[<font face="GothamBlack" size="16">Mirror Tool  🪞</font>
Зеркалит выделение относительно плоскости (X/Y/Z).<font size="6"><br /></font>

<b>Ось</b> — X/Y/Z.<font size="6"><br /></font>
<b>Сохранить оригинал</b> — если выключено, оригинал удалится.<font size="6"><br /></font>
<b>Группа</b> — опционально сгруппировать результат.]]

local PanelHandle = nil

local Settings = {
	axis = "X",
	keepOriginal = true,
	groupResult = false,
}

local function getPlacementParent()
	return Core.Targeting.Scope or workspace
end

local function getCloneParent(items)
	local highestItem = nil
	local highestDepth = nil

	for _, item in ipairs(items) do
		local depth = 0
		local current = item
		while current and current ~= game do
			depth += 1
			current = current.Parent
		end
		if not highestDepth or depth < highestDepth then
			highestDepth = depth
			highestItem = item
		end
	end

	return highestItem and highestItem.Parent or getPlacementParent()
end

local function waitForStreamingClones(streamingCloneId, expectedCount)
	local clones = {}
	local deadline = os.clock() + 3

	while os.clock() < deadline do
		clones = {}
		for _, clone in CollectionService:GetTagged("BTStreamingClone") do
			if clone:GetAttribute("BTStreamingCloneID") == streamingCloneId then
				table.insert(clones, clone)
			end
		end
		if #clones >= expectedCount then
			break
		end
		task.wait(0.1)
	end

	return clones
end

local function cloneSelectionItems(items)
	local parent = getCloneParent(items)
	local clones, streamingCloneId, streamingCloneCount = Core.SyncAPI:Invoke("Clone", items, parent)

	if clones == nil and streamingCloneId and streamingCloneCount then
		clones = waitForStreamingClones(streamingCloneId, streamingCloneCount)
	end

	return clones or {}
end

local function getSelectionParts()
	return Selection.Parts or {}
end

local function computeOrigin(parts)
	if #parts == 0 then
		return CFrame.new()
	end
	local sum = Vector3.new()
	for _, part in ipairs(parts) do
		sum += part.Position
	end
	return CFrame.new(sum / #parts)
end

local function getMirrorTransform(origin, axis)
	local flip
	if axis == "X" then
		flip = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif axis == "Y" then
		flip = CFrame.new(0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0, 1)
	else
		flip = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, -1)
	end
	return origin * flip * origin:Inverse()
end

local function reflectCFrame(cf, origin, axis)
	return getMirrorTransform(origin, axis) * cf
end

local function buildMoveChanges(parts, origin, axis)
	local changes = {}
	for _, part in ipairs(parts) do
		table.insert(changes, {
			Part = part,
			CFrame = reflectCFrame(part.CFrame, origin, axis),
		})
	end
	return changes
end

local function collectBaseParts(instances)
	local seen = {}
	local parts = {}

	local function add(part)
		if part and not seen[part] then
			seen[part] = true
			table.insert(parts, part)
		end
	end

	for _, instance in ipairs(instances) do
		if not instance then
			continue
		end
		if instance:IsA("BasePart") then
			add(instance)
		end
		for _, descendant in ipairs(Support.GetDescendantsWhichAreA(instance, "BasePart")) do
			add(descendant)
		end
	end

	return parts
end

function MirrorTool:SetSettings(patch)
	for key, value in pairs(patch) do
		Settings[key] = value
	end
end

function MirrorTool:GetSettings()
	return Settings
end

function MirrorTool:ApplyMirror(axis, keepOriginal, groupResult)
	local parts = getSelectionParts()
	if #parts == 0 then
		return false, "Выдели части/модели"
	end

	local origin = computeOrigin(parts)
	local clones = cloneSelectionItems(Selection.Items)
	if #clones == 0 then
		return false, "Не удалось клонировать"
	end

	local clonedParts = collectBaseParts(clones)
	if #clonedParts == 0 then
		return false, "Не удалось получить части из клонов"
	end

	Core.SyncAPI:Invoke("SyncMove", buildMoveChanges(clonedParts, origin, axis))

	if groupResult then
		Core.SyncAPI:Invoke("CreateGroup", "Model", getCloneParent(clones), clones)
	end

	local removedOriginal = nil
	if not keepOriginal then
		removedOriginal = Support.CloneTable(Selection.Items)
		Core.SyncAPI:Invoke("Remove", removedOriginal)
	end

	local HistoryRecord = {
		Clones = clones,
		Removed = removedOriginal,
		Unapply = function(record)
			Selection.Remove(record.Clones, false)
			Core.SyncAPI:Invoke("Remove", record.Clones)
			if record.Removed then
				Core.SyncAPI:Invoke("UndoRemove", record.Removed)
			end
		end,
		Apply = function(record)
			Core.SyncAPI:Invoke("UndoRemove", record.Clones)
			if record.Removed then
				Core.SyncAPI:Invoke("Remove", record.Removed)
			end
			Selection.Replace(record.Clones, false)
		end,
	}

	Core.History.Add(HistoryRecord)
	Selection.Replace(clones, false)
	return true, "Готово"
end

function MirrorTool:ShowUI()
	if PanelHandle then
		return
	end

	local element = Roact.createElement(MirrorPanel, {
		Core = Core,
		Settings = Settings,
		OnSettingsChanged = function(patch)
			MirrorTool:SetSettings(patch)
		end,
		OnApply = function()
			return MirrorTool:ApplyMirror(Settings.axis, Settings.keepOriginal, Settings.groupResult)
		end,
	})
	PanelHandle = Roact.mount(element, Core.UI, "MirrorPanel")
end

function MirrorTool:HideUI()
	if PanelHandle then
		Roact.unmount(PanelHandle)
		PanelHandle = nil
	end
end

function MirrorTool:Equip()
	self:ShowUI()
end

function MirrorTool:Unequip()
	self:HideUI()
end

return MirrorTool
