local HttpService = game:GetService("HttpService")

local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary)
local SerializationV3 = require(Tool.Libraries.SerializationV3)
local SerializationV4 = require(Tool.Libraries.SerializationV4)

Support.ImportServices()

local MapLibrary = {}

local MAP_ROOT = "BT-BuildingTools/maps"
local INDEX_PATH = MAP_ROOT .. "/index.json"
local STORE_KEY = "__BT_MAPS"
local OWNER_ATTR = "BTUserId"
local MAP_ATTR = "BTMapId"

local memoryStore = nil
local fileApi = nil

local DEFAULT_SETTINGS = {
	includeUnions = true,
	onlyMine = false,
	saveSource = "selection",
	autoLoad = false,
	anchoredOnLoad = true,
}

local function resolveApi(name)
	if getgenv then
		local value = rawget(getgenv(), name)
		if value ~= nil then
			return value
		end
	end
	return rawget(_G, name)
end

local function getFileApi()
	if fileApi ~= nil then
		return fileApi
	end

	fileApi = {
		writefile = resolveApi("writefile"),
		readfile = resolveApi("readfile"),
		isfile = resolveApi("isfile"),
		isfolder = resolveApi("isfolder"),
		makefolder = resolveApi("makefolder"),
		delfile = resolveApi("delfile"),
	}

	return fileApi
end

local function hasFileApi()
	local api = getFileApi()
	return typeof(api.writefile) == "function"
		and typeof(api.readfile) == "function"
		and typeof(api.isfile) == "function"
end

local function ensureFolder(path)
	local api = getFileApi()
	if typeof(api.makefolder) ~= "function" then
		return
	end
	if typeof(api.isfolder) == "function" and api.isfolder(path) then
		return
	end
	pcall(api.makefolder, path)
end

local function splitPath(filePath)
	local parts = {}
	for segment in filePath:gsub("\\", "/"):gmatch("[^/]+") do
		table.insert(parts, segment)
	end
	return parts
end

local function ensureParentFolders(filePath)
	local api = getFileApi()
	if typeof(api.makefolder) ~= "function" then
		return
	end
	local parts = splitPath(filePath)
	table.remove(parts)
	local current = ""
	for _, segment in ipairs(parts) do
		current = current == "" and segment or (current .. "/" .. segment)
		ensureFolder(current)
	end
end

local function readFile(path)
	local api = getFileApi()
	if not hasFileApi() or not api.isfile(path) then
		return nil
	end
	local ok, content = pcall(api.readfile, path)
	if ok and type(content) == "string" and content ~= "" then
		return content
	end
	return nil
end

local function writeFile(path, content)
	if not hasFileApi() then
		return false
	end
	local api = getFileApi()
	ensureParentFolders(path)
	local ok, err = pcall(api.writefile, path, content)
	if not ok then
		warn("[BT Map] writefile failed:", path, err)
	end
	return ok
end

local function deleteFile(path)
	local api = getFileApi()
	if typeof(api.delfile) == "function" and api.isfile(path) then
		pcall(api.delfile, path)
	end
end

local function getMemoryStore()
	if memoryStore == nil then
		local env = (getgenv and getgenv()) or _G
		env[STORE_KEY] = env[STORE_KEY] or {}
		memoryStore = env[STORE_KEY]
	end
	return memoryStore
end

local function getMapFilePath(mapId)
	return string.format("%s/%s.json", MAP_ROOT, mapId)
end

local function encodeVector3(vector)
	return { x = vector.X, y = vector.Y, z = vector.Z }
end

function MapLibrary.decodeVector3(data)
	if type(data) ~= "table" then
		return nil
	end
	local x = tonumber(data.x or data.X)
	local y = tonumber(data.y or data.Y)
	local z = tonumber(data.z or data.Z)
	if x and y and z then
		return Vector3.new(x, y, z)
	end
	return nil
end

local function loadIndexEntries()
	ensureFolder(MAP_ROOT)
	local content = readFile(INDEX_PATH)
	if not content then
		return {}
	end
	local ok, entries = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not ok or type(entries) ~= "table" then
		return {}
	end
	return entries
end

local function saveIndexEntries(entries)
	if hasFileApi() then
		writeFile(INDEX_PATH, HttpService:JSONEncode(entries))
	end
end

local function readMapFile(mapId)
	local content = readFile(getMapFilePath(mapId))
	if not content then
		return nil
	end
	local ok, map = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not ok or type(map) ~= "table" or type(map.buildData) ~= "table" then
		return nil
	end
	return map
end

local function writeMapFile(map)
	if not hasFileApi() then
		return false
	end
	return writeFile(getMapFilePath(map.id), HttpService:JSONEncode(map))
end

local function removeMapFile(mapId)
	deleteFile(getMapFilePath(mapId))
end

local function syncMemoryFromDisk()
	memoryStore = {}
	if not hasFileApi() then
		return
	end
	for _, entry in ipairs(loadIndexEntries()) do
		local map = readMapFile(entry.id)
		if map then
			table.insert(memoryStore, map)
		end
	end
end

function MapLibrary.getDefaultSettings()
	return Support.CloneTable(DEFAULT_SETTINGS)
end

function MapLibrary.list()
	if hasFileApi() then
		syncMemoryFromDisk()
	end
	return getMemoryStore()
end

function MapLibrary.reload()
	memoryStore = nil
	return MapLibrary.list()
end

function MapLibrary.find(mapId)
	for _, map in ipairs(MapLibrary.list()) do
		if map.id == mapId then
			return map
		end
	end
	if hasFileApi() then
		local map = readMapFile(mapId)
		if map then
			table.insert(getMemoryStore(), map)
			return map
		end
	end
end

function MapLibrary.isOwnedByPlayer(instance, userId)
	if not instance or not userId then
		return false
	end
	local ownerId = instance:GetAttribute(OWNER_ATTR)
	if ownerId == nil then
		return false
	end
	return tonumber(ownerId) == tonumber(userId)
end

function MapLibrary.tagOwnership(instance, userId)
	if instance and userId then
		instance:SetAttribute(OWNER_ATTR, userId)
	end
end

function MapLibrary.tagMapInstances(instances, mapId, userId)
	for _, instance in ipairs(instances) do
		if instance then
			instance:SetAttribute(MAP_ATTR, mapId)
			MapLibrary.tagOwnership(instance, userId)
			for _, descendant in ipairs(instance:GetDescendants()) do
				descendant:SetAttribute(MAP_ATTR, mapId)
				MapLibrary.tagOwnership(descendant, userId)
			end
		end
	end
end

function MapLibrary.collectSerializableItems(selectionItems)
	local items = Support.CloneTable(selectionItems)
	for _, item in ipairs(selectionItems) do
		Support.ConcatTable(items, item:GetDescendants())
	end
	return items
end

local function filterUnions(items, includeUnions)
	if includeUnions then
		return items
	end
	local filtered = {}
	for _, item in ipairs(items) do
		if not item:IsA("PartOperation") then
			table.insert(filtered, item)
		end
	end
	return filtered
end

local function filterOnlyMine(items, userId)
	local filtered = {}
	for _, item in ipairs(items) do
		if MapLibrary.isOwnedByPlayer(item, userId) then
			table.insert(filtered, item)
		end
	end
	return filtered
end

local function chooseSerializer(items, includeUnions)
	if not includeUnions then
		return SerializationV3
	end
	for _, item in ipairs(items) do
		if item:IsA("PartOperation") then
			return SerializationV4
		end
	end
	return SerializationV3
end

local function inflateBuildData(buildData)
	if type(buildData) == "table" and buildData.Version == 4 then
		return SerializationV4.InflateBuildData(buildData)
	end
	return SerializationV3.InflateBuildData(buildData)
end

function MapLibrary.getPartsFromRoots(roots)
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

function MapLibrary.computeAnchorPosition(parts)
	if #parts == 0 then
		return Vector3.new()
	end
	local sum = Vector3.new()
	for _, part in ipairs(parts) do
		sum += part.Position
	end
	return sum / #parts
end

function MapLibrary.focusCameraOnParts(camera, parts)
	if #parts == 0 then
		return
	end
	local center = MapLibrary.computeAnchorPosition(parts)
	local maxSpan = 4
	for _, part in ipairs(parts) do
		maxSpan = math.max(maxSpan, part.Size.Magnitude)
	end
	local distance = math.max(6, maxSpan * 2.2)
	camera.CFrame = CFrame.new(center + Vector3.new(distance, distance * 0.65, distance), center)
end

function MapLibrary.inflate(map)
	if not map or not map.buildData then
		return {}
	end
	return inflateBuildData(map.buildData)
end

function MapLibrary.resolveSaveRoots(core, settings)
	local saveSource = settings.saveSource or "selection"
	if saveSource == "selection" then
		return core.Selection.Items
	end
	if saveSource == "scope" then
		local scope = core.Targeting.Scope or workspace
		return scope:GetChildren()
	end
	if saveSource == "all" then
		return workspace:GetChildren()
	end
	return core.Selection.Items
end

local function persistMap(map)
	if not writeMapFile(map) then
		return nil, "writefile недоступен — карты не сохранятся на диск"
	end

	if hasFileApi() then
		local entries = loadIndexEntries()
		local found = false
		for _, entry in ipairs(entries) do
			if entry.id == map.id then
				entry.name = map.name
				entry.createdAt = map.createdAt
				entry.updatedAt = map.updatedAt
				entry.autoLoad = map.settings and map.settings.autoLoad or false
				entry.placeId = map.placeId
				found = true
				break
			end
		end
		if not found then
			table.insert(entries, {
				id = map.id,
				name = map.name,
				createdAt = map.createdAt,
				updatedAt = map.updatedAt,
				autoLoad = map.settings and map.settings.autoLoad or false,
				placeId = map.placeId,
			})
		end
		saveIndexEntries(entries)
	end

	if memoryStore == nil then
		getMemoryStore()
	end

	for index, existing in ipairs(memoryStore) do
		if existing.id == map.id then
			memoryStore[index] = map
			return map
		end
	end
	table.insert(memoryStore, map)
	return map
end

function MapLibrary.saveMap(name, core, settings, mapId)
	settings = settings or MapLibrary.getDefaultSettings()
	local roots = MapLibrary.resolveSaveRoots(core, settings)
	if #roots == 0 then
		return nil, "Нет объектов для сохранения"
	end

	local items = MapLibrary.collectSerializableItems(roots)
	items = filterUnions(items, settings.includeUnions ~= false)

	if settings.onlyMine and core.Player then
		items = filterOnlyMine(items, core.Player.UserId)
	end

	if #items == 0 then
		return nil, settings.onlyMine
			and "Нет твоих построек (нужен атрибут BTUserId — ставь через кубик)"
			or "Нет поддерживаемых объектов"
	end

	local parts = {}
	for _, item in ipairs(items) do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	if #parts == 0 then
		return nil, "Нет частей для сохранения"
	end

	local ok, serialized = pcall(function()
		return chooseSerializer(items, settings.includeUnions ~= false).SerializeModel(items)
	end)
	if not ok then
		warn("[BT Map] Ошибка сериализации:", serialized)
		return nil, "Не удалось сериализовать: " .. tostring(serialized)
	end

	local decodeOk, buildData = pcall(function()
		return HttpService:JSONDecode(serialized)
	end)
	if not decodeOk or not buildData or not buildData.Items then
		warn("[BT Map] Ошибка JSON:", buildData or serialized)
		return nil, "Не удалось сериализовать карту"
	end

	local itemCount = 0
	for _ in ipairs(buildData.Items) do
		itemCount += 1
	end
	if itemCount == 0 then
		return nil, "Нет поддерживаемых объектов для карты"
	end

	local now = os.time()
	local map = {
		id = mapId or HttpService:GenerateGUID(false),
		name = (name ~= nil and name ~= "") and name or ("Карта " .. (#MapLibrary.list() + 1)),
		createdAt = now,
		updatedAt = now,
		placeId = game.PlaceId,
		anchorPosition = encodeVector3(MapLibrary.computeAnchorPosition(parts)),
		settings = {
			includeUnions = settings.includeUnions ~= false,
			onlyMine = settings.onlyMine == true,
			saveSource = settings.saveSource or "selection",
			autoLoad = settings.autoLoad == true,
			anchoredOnLoad = settings.anchoredOnLoad ~= false,
		},
		buildData = buildData,
	}

	local saved, err = persistMap(map)
	if not saved then
		return nil, err
	end
	return saved
end

function MapLibrary.updateMapSettings(mapId, patch)
	local map = MapLibrary.find(mapId)
	if not map then
		return nil, "Карта не найдена"
	end
	map.settings = map.settings or MapLibrary.getDefaultSettings()
	for key, value in pairs(patch) do
		map.settings[key] = value
	end
	map.updatedAt = os.time()
	local saved, err = persistMap(map)
	if not saved then
		return nil, err
	end
	return saved
end

function MapLibrary.delete(mapId)
	if hasFileApi() then
		local entries = loadIndexEntries()
		for index, entry in ipairs(entries) do
			if entry.id == mapId then
				table.remove(entries, index)
				saveIndexEntries(entries)
				break
			end
		end
		removeMapFile(mapId)
	end

	local store = MapLibrary.list()
	for index, map in ipairs(store) do
		if map.id == mapId then
			table.remove(store, index)
			return true
		end
	end
	return false
end

function MapLibrary.getAutoLoadMaps(placeId)
	local result = {}
	for _, map in ipairs(MapLibrary.list()) do
		if map.settings and map.settings.autoLoad and map.placeId == placeId then
			table.insert(result, map)
		end
	end
	return result
end

function MapLibrary.getStoragePath()
	return MAP_ROOT
end

return MapLibrary
