local HttpService = game:GetService("HttpService")

local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary)
local Serialization = require(Tool.Libraries.SerializationV3)

Support.ImportServices()

local StampLibrary = {}

local STORE_KEY = "__BT_STAMPS"

local function getStore()
	local env = (getgenv and getgenv()) or _G
	env[STORE_KEY] = env[STORE_KEY] or {}
	return env[STORE_KEY]
end

function StampLibrary.list()
	return getStore()
end

function StampLibrary.collectSerializableItems(selectionItems)
	local items = Support.CloneTable(selectionItems)
	for _, item in ipairs(selectionItems) do
		Support.ConcatTable(items, item:GetDescendants())
	end
	return items
end

function StampLibrary.saveFromSelection(name, selectionItems)
	local items = StampLibrary.collectSerializableItems(selectionItems)
	if #items == 0 then
		return nil, "Выделите хотя бы один объект"
	end

	local ok, buildData = pcall(function()
		return HttpService:JSONDecode(Serialization.SerializeModel(items))
	end)
	if not ok or not buildData or not buildData.Items then
		return nil, "Не удалось сериализовать выделение"
	end

	local stamp = {
		id = HttpService:GenerateGUID(false),
		name = (name ~= nil and name ~= "") and name or ("Stamp " .. (#getStore() + 1)),
		createdAt = os.time(),
		buildData = buildData,
	}

	table.insert(getStore(), stamp)
	return stamp
end

function StampLibrary.delete(stampId)
	local store = getStore()
	for index, stamp in ipairs(store) do
		if stamp.id == stampId then
			table.remove(store, index)
			return true
		end
	end
	return false
end

function StampLibrary.find(stampId)
	for _, stamp in ipairs(getStore()) do
		if stamp.id == stampId then
			return stamp
		end
	end
end

function StampLibrary.importBuildData(buildData, name)
	if type(buildData) ~= "table" or type(buildData.Items) ~= "table" then
		return nil, "Неверный формат stamp JSON"
	end

	local stamp = {
		id = HttpService:GenerateGUID(false),
		name = name or ("Import " .. (#getStore() + 1)),
		createdAt = os.time(),
		buildData = buildData,
	}
	table.insert(getStore(), stamp)
	return stamp
end

function StampLibrary.importFromJson(jsonString)
	local ok, buildData = pcall(function()
		return HttpService:JSONDecode(jsonString)
	end)
	if not ok then
		return nil, "Невалидный JSON"
	end
	return StampLibrary.importBuildData(buildData)
end

function StampLibrary.exportToJson(stamp)
	return HttpService:JSONEncode(stamp.buildData)
end

function StampLibrary.inflate(stamp)
	if not stamp or not stamp.buildData then
		return {}
	end
	return Serialization.InflateBuildData(stamp.buildData)
end

function StampLibrary.getPartsFromRoots(roots)
	local parts = {}
	local function scan(instance)
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
		for _, child in ipairs(instance:GetChildren()) do
			scan(child)
		end
	end
	for _, root in ipairs(roots) do
		scan(root)
	end
	return parts
end

function StampLibrary.focusCameraOnParts(camera, parts)
	if #parts == 0 then
		return
	end

	local sum = Vector3.new()
	local maxSpan = 4
	for _, part in ipairs(parts) do
		sum += part.Position
		maxSpan = math.max(maxSpan, part.Size.Magnitude)
	end
	local center = sum / #parts
	local distance = math.max(6, maxSpan * 2.2)
	camera.CFrame = CFrame.new(center + Vector3.new(distance, distance * 0.65, distance), center)
end

return StampLibrary
