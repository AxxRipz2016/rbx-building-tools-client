Tool = script.Parent.Parent
Core = require(Tool.Core)

local Vendor = Tool:WaitForChild("Vendor")
local UI = Tool:WaitForChild("UI")
local Libraries = Tool:WaitForChild("Libraries")

local Roact = require(Vendor:WaitForChild("Roact"))
local MapSaverPanel = require(UI:WaitForChild("MapSaver"))
local MapLibrary = require(Libraries:WaitForChild("MapLibrary"))

Selection = Core.Selection
Support = Core.Support
Security = Core.Security
Support.ImportServices()

local MapSaverTool = {
	Name = "Map Saver",
	Color = BrickColor.new("Bright green"),
}

MapSaverTool.ManualText = [[<font face="GothamBlack" size="16">Map Saver  🗺</font>
Сохраняй постройки на карте и загружай их на том же месте.<font size="6"><br /></font>

<b>Сохранить</b> — выбери источник, настройки, имя, «Сохранить карту».<font size="6"><br /></font>
<b>Загрузить</b> — карта появится на сохранённой позиции.<font size="6"><br /></font>
<b>Только мои</b> — части с атрибутом BTUserId (ставятся через кубик).<font size="6"><br /></font>
<b>Union</b> — галочка включает сохранение Union.<font size="6"><br /></font>
<b>Автозагрузка</b> — карта грузится при входе на этот place.<font size="6"><br /></font>
<b>Фильтр place</b> — все карты, только этот place ID, или с других игр.<font size="6"><br /></font>
<b>Поиск</b> — по имени или place ID; кнопки сортировки и ★ (только автозагрузка).<font size="6"><br /></font>
<b>Файлы</b> — BT-BuildingTools/maps.]]

local PanelHandle = nil
local SelectedMapId = nil
local SaveSettings = MapLibrary.getDefaultSettings()
local AutoLoadDone = false

local function getPlacementParent()
	return Core.Targeting.Scope or workspace
end

function MapSaverTool:GetSaveSettings()
	return SaveSettings
end

function MapSaverTool:SetSaveSettings(settings)
	SaveSettings = settings or MapLibrary.getDefaultSettings()
end

function MapSaverTool:SetSelectedMap(mapId)
	SelectedMapId = mapId
end

function MapSaverTool:LoadMap(mapId, replaceExisting)
	local map = MapLibrary.find(mapId or SelectedMapId)
	if not map then
		return false, "Выбери карту в списке"
	end

	local anchor = MapLibrary.decodeVector3(map.anchorPosition)
	if not anchor then
		return false, "У карты нет сохранённой позиции"
	end

	local mapSettings = map.settings or {}
	local created = Core.SyncAPI:Invoke("MapLoad", map.buildData, anchor, getPlacementParent(), {
		ReplaceExisting = replaceExisting ~= false,
		MapId = map.id,
		Anchored = mapSettings.anchoredOnLoad ~= false,
	})

	if not created or #created == 0 then
		return false, "Не удалось загрузить карту"
	end

	local HistoryRecord = {
		Clones = created,
		MapId = map.id,

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

	return true, "Загружено: " .. map.name
end

function MapSaverTool:SaveMap(name, settings)
	local saved, err = MapLibrary.saveMap(name, Core, settings or SaveSettings, SelectedMapId)
	if not saved then
		return false, err
	end
	SelectedMapId = saved.id
	return true, "Сохранено: " .. saved.name, saved.id
end

function MapSaverTool:TryAutoLoad()
	if AutoLoadDone then
		return
	end
	AutoLoadDone = true

	local maps = MapLibrary.getAutoLoadMaps(game.PlaceId)
	if #maps == 0 then
		return
	end

	task.defer(function()
		for _, map in ipairs(maps) do
			local ok, message = MapSaverTool:LoadMap(map.id, true)
			if ok then
				print("[BT Map] Автозагрузка:", message)
			else
				warn("[BT Map] Автозагрузка не удалась:", map.name, message)
			end
		end
	end)
end

function MapSaverTool:ShowUI()
	if PanelHandle then
		return
	end

	local element = Roact.createElement(MapSaverPanel, {
		Core = Core,
		SaveSettings = SaveSettings,
		OnSelectMap = function(mapId)
			MapSaverTool:SetSelectedMap(mapId)
		end,
		OnSaveSettingsChanged = function(settings)
			MapSaverTool:SetSaveSettings(settings)
		end,
		OnSaveMap = function(name, settings)
			return MapSaverTool:SaveMap(name, settings)
		end,
		OnLoadMap = function(mapId)
			return MapSaverTool:LoadMap(mapId, true)
		end,
		OnToggleAutoLoad = function(mapId, enabled)
			local updated, err = MapLibrary.updateMapSettings(mapId, { autoLoad = enabled })
			if not updated then
				return false, err
			end
			return true, enabled and "Автозагрузка включена" or "Автозагрузка выключена"
		end,
	})
	PanelHandle = Roact.mount(element, Core.UI, "MapSaverPanel")
end

function MapSaverTool:HideUI()
	if PanelHandle then
		Roact.unmount(PanelHandle)
		PanelHandle = nil
	end
end

function MapSaverTool:Equip()
	self:ShowUI()
	self:TryAutoLoad()
end

function MapSaverTool:Unequip()
	self:HideUI()
end

return MapSaverTool
