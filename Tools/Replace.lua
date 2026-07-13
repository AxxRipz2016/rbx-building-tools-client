Tool = script.Parent.Parent
Core = require(Tool.Core)

local Vendor = Tool:WaitForChild("Vendor")
local UI = Tool:WaitForChild("UI")
local Libraries = Tool:WaitForChild("Libraries")

local Roact = require(Vendor:WaitForChild("Roact"))
local ReplacePanel = require(UI:WaitForChild("Replace"))
local SerializationV3 = require(Libraries:WaitForChild("SerializationV3"))
local SerializationV4 = require(Libraries:WaitForChild("SerializationV4"))

Selection = Core.Selection
Support = Core.Support
Security = Core.Security
Support.ImportServices()

local ReplaceTool = {
	Name = "Replace",
	Color = BrickColor.new("Deep orange"),
}

ReplaceTool.ManualText = [[<font face="GothamBlack" size="16">Replace Tool  🔁</font>
Заменяет выбранные части на шаблон.<font size="6"><br /></font>

<b>Шаблон</b> — сначала выдели 1 part и нажми «Взять шаблон».<font size="6"><br /></font>
<b>Заменить</b> — выдели части и нажми «Заменить».<font size="6"><br /></font>
<b>Опции</b> — что сохранять от старых частей (Size/Color/Material).]]

local PanelHandle = nil

local TemplateBuildData = nil
local TemplateName = nil

local Settings = {
	keepSize = true,
	keepColor = true,
	keepMaterial = true,
}

local function chooseSerializer(items)
	for _, item in ipairs(items) do
		if item:IsA("PartOperation") then
			return SerializationV4
		end
	end
	return SerializationV3
end

function ReplaceTool:SetSettings(patch)
	for key, value in pairs(patch) do
		Settings[key] = value
	end
end

function ReplaceTool:GetSettings()
	return Settings
end

function ReplaceTool:GetTemplateInfo()
	return TemplateBuildData ~= nil, TemplateName
end

function ReplaceTool:CaptureTemplateFromSelection()
	if #Selection.Items ~= 1 or not Selection.Items[1]:IsA("BasePart") then
		return false, "Выдели ровно 1 part для шаблона"
	end

	local template = Selection.Items[1]
	local serializer = chooseSerializer({ template })
	local ok, encoded = pcall(function()
		return serializer.SerializeModel({ template })
	end)
	if not ok then
		warn("[BT Replace] serialize template failed:", encoded)
		return false, "Не удалось сериализовать шаблон"
	end

	local decodeOk, buildData = pcall(function()
		return game:GetService("HttpService"):JSONDecode(encoded)
	end)
	if not decodeOk or type(buildData) ~= "table" or type(buildData.Items) ~= "table" then
		return false, "Шаблон: ошибка данных"
	end

	TemplateBuildData = buildData
	TemplateName = template.Name
	return true, "Шаблон: " .. TemplateName
end

function ReplaceTool:ApplyReplace()
	if not TemplateBuildData then
		return false, "Сначала возьми шаблон"
	end

	local parts = Selection.Parts or {}
	if #parts == 0 then
		return false, "Выдели части для замены"
	end

	local created = Core.SyncAPI:Invoke("ReplaceParts", TemplateBuildData, parts, {
		KeepSize = Settings.keepSize,
		KeepColor = Settings.keepColor,
		KeepMaterial = Settings.keepMaterial,
	})
	if not created or #created == 0 then
		return false, "Не удалось заменить"
	end

	local removed = parts
	Core.SyncAPI:Invoke("Remove", removed)

	local HistoryRecord = {
		Clones = created,
		Removed = removed,
		Unapply = function(record)
			Selection.Remove(record.Clones, false)
			Core.SyncAPI:Invoke("Remove", record.Clones)
			Core.SyncAPI:Invoke("UndoRemove", record.Removed)
		end,
		Apply = function(record)
			Core.SyncAPI:Invoke("UndoRemove", record.Clones)
			Core.SyncAPI:Invoke("Remove", record.Removed)
			Selection.Replace(record.Clones, false)
		end,
	}

	Core.History.Add(HistoryRecord)
	Selection.Replace(created, false)
	return true, "Заменено: " .. #created
end

function ReplaceTool:ShowUI()
	if PanelHandle then
		return
	end

	local element = Roact.createElement(ReplacePanel, {
		Core = Core,
		Settings = Settings,
		OnSettingsChanged = function(patch)
			ReplaceTool:SetSettings(patch)
		end,
		OnCaptureTemplate = function()
			return ReplaceTool:CaptureTemplateFromSelection()
		end,
		OnApply = function()
			return ReplaceTool:ApplyReplace()
		end,
		OnGetTemplateInfo = function()
			return ReplaceTool:GetTemplateInfo()
		end,
	})
	PanelHandle = Roact.mount(element, Core.UI, "ReplacePanel")
end

function ReplaceTool:HideUI()
	if PanelHandle then
		Roact.unmount(PanelHandle)
		PanelHandle = nil
	end
end

function ReplaceTool:Equip()
	self:ShowUI()
end

function ReplaceTool:Unequip()
	self:HideUI()
end

return ReplaceTool

