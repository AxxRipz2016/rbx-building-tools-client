Tool = script.Parent.Parent
Core = require(Tool.Core)

local Vendor = Tool:WaitForChild("Vendor")
local UI = Tool:WaitForChild("UI")
local Libraries = Tool:WaitForChild("Libraries")

local ContextActionService = game:GetService("ContextActionService")
local Roact = require(Vendor:WaitForChild("Roact"))
local StampPanel = require(UI:WaitForChild("Stamp"))
local StampLibrary = require(Libraries:WaitForChild("StampLibrary"))

Selection = Core.Selection
Support = Core.Support
Security = Core.Security
Support.ImportServices()

local StampTool = {
	Name = "Stamp Tool",
	Color = BrickColor.new("Bright blue"),
}

StampTool.ManualText = [[<font face="GothamBlack" size="16">Stamp Tool  🛠</font>
Сохраняй выделение как stamp и ставь его снова одним кликом.<font size="6"><br /></font>

<b>Сохранить</b> — выдели постройку, имя, кнопка «Сохранить выделение».<font size="6"><br /></font>
<b>Загрузить</b> — кнопка «Загрузить список» читает stamps с диска.<font size="6"><br /></font>
<b>Поставить</b> — выбери stamp в списке, кликни по миру.<font size="6"><br /></font>
<b>Файлы</b> — папка BT-BuildingTools/stamps.]]

local Connections = {}
local PanelHandle = nil
local SelectedStampId = nil

local function clearConnections()
	for key, connection in pairs(Connections) do
		connection:Disconnect()
		Connections[key] = nil
	end
end

local function getPlacementParent()
	return Core.Targeting.Scope or workspace
end

local function placeSelectedStamp()
	if not SelectedStampId then
		return
	end

	local stamp = StampLibrary.find(SelectedStampId)
	if not stamp then
		return
	end

	local hit = Core.Mouse and Core.Mouse.Hit
	if not hit then
		return
	end

	local created = Core.SyncAPI:Invoke("StampPlace", stamp.buildData, hit.Position, getPlacementParent())
	if not created or #created == 0 then
		return
	end

	local HistoryRecord = {
		Clones = created,

		Unapply = function(record)
			Selection.Remove(record.Clones, false)
			Core.SyncAPI:Invoke("Remove", record.Clones)
		end,

		Apply = function(record)
			Core.SyncAPI:Invoke("UndoRemove", record.Clones)
			Selection.Replace(record.Clones, false)
		end,
	}

	Core.History.Add(HistoryRecord)
	Selection.Replace(created, false)
end

local function enablePlacement()
	ContextActionService:BindAction(
		"BT: Stamp place",
		function(_, state)
			if state.Name == "Begin" then
				Core.Targeting.CancelSelecting()
				placeSelectedStamp()
			end
		end,
		false,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch
	)
end

function StampTool:SetSelectedStamp(stampId)
	SelectedStampId = stampId
end

function StampTool:ShowUI()
	if PanelHandle then
		return
	end

	local element = Roact.createElement(StampPanel, {
		Core = Core,
		OnSelectStamp = function(stampId)
			StampTool:SetSelectedStamp(stampId)
		end,
	})
	PanelHandle = Roact.mount(element, Core.UI, "StampPanel")
end

function StampTool:HideUI()
	if PanelHandle then
		Roact.unmount(PanelHandle)
		PanelHandle = nil
	end
end

function StampTool:Equip()
	Selection.Clear(false)
	self:ShowUI()
	enablePlacement()
end

function StampTool:Unequip()
	self:HideUI()
	clearConnections()
	ContextActionService:UnbindAction("BT: Stamp place")
end

return StampTool
