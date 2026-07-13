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
	local center = sum / #parts
	return CFrame.new(center)
end

local function reflectVector(v, axis)
	if axis == "X" then
		return Vector3.new(-v.X, v.Y, v.Z)
	elseif axis == "Y" then
		return Vector3.new(v.X, -v.Y, v.Z)
	else
		return Vector3.new(v.X, v.Y, -v.Z)
	end
end

local function reflectCFrame(cf, origin, axis)
	local rel = origin:ToObjectSpace(cf)
	local pos = rel.Position
	local right = rel.RightVector
	local up = rel.UpVector
	local look = rel.LookVector

	local rPos = reflectVector(pos, axis)
	local rRight = reflectVector(right, axis)
	local rUp = reflectVector(up, axis)
	local rLook = reflectVector(look, axis)

	local newRel = CFrame.fromMatrix(rPos, rRight, rUp, -rLook)
	return origin * newRel
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
	local clones = Core.SyncAPI:Invoke("Clone", Selection.Items, getPlacementParent())
	if not clones or #clones == 0 then
		return false, "Не удалось клонировать"
	end

	local clonedParts = Support.GetDescendantsWhichAreA(clones, "BasePart")
	local moveChanges = buildMoveChanges(clonedParts, origin, axis)
	Core.SyncAPI:Invoke("SyncMove", moveChanges)

	if groupResult then
		Core.SyncAPI:Invoke("CreateGroup", "Model", getPlacementParent(), clones)
	end

	local removedOriginal = nil
	if not keepOriginal then
		removedOriginal = Selection.Items
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

