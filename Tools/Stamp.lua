Tool = script.Parent.Parent
Core = require(Tool.Core)

local Vendor = Tool:WaitForChild("Vendor")
local UI = Tool:WaitForChild("UI")
local Libraries = Tool:WaitForChild("Libraries")

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
Сохраняй выделение как stamp и ставь его снова.<font size="6"><br /></font>

<b>Выделение</b> — кликай по миру как обычно, stamp не ставится.<font size="6"><br /></font>
<b>Поставить</b> — выбери stamp в списке, нажми кнопку «Поставить».<font size="6"><br /></font>
<b>Сохранить</b> — выдели постройку, имя, «Сохранить выделение».<font size="6"><br /></font>
<b>Файлы</b> — папка BT-BuildingTools/stamps.]]

local PanelHandle = nil
local SelectedStampId = nil

local function getPlacementParent()
	return Core.Targeting.Scope or workspace
end

function StampTool:PlaceStamp()
	if not SelectedStampId then
		return false, "Выбери stamp в списке"
	end

	local stamp = StampLibrary.find(SelectedStampId)
	if not stamp then
		return false, "Stamp не найден"
	end

	local hit = Core.Mouse and Core.Mouse.Hit
	if not hit then
		return false, "Наведи курсор на место постановки"
	end

	local created = Core.SyncAPI:Invoke("StampPlace", stamp.buildData, hit.Position, getPlacementParent())
	if not created or #created == 0 then
		return false, "Не удалось поставить stamp"
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

	return true, "Поставлено: " .. stamp.name
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
		OnPlaceStamp = function()
			return StampTool:PlaceStamp()
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
	self:ShowUI()
end

function StampTool:Unequip()
	self:HideUI()
end

return StampTool
