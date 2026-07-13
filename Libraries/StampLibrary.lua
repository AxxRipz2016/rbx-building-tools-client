local HttpService = game:GetService("HttpService")

local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary)
local Serialization = require(Tool.Libraries.SerializationV3)

Support.ImportServices()

local StampLibrary = {}

local STAMP_ROOT = "BT-BuildingTools/stamps"
local INDEX_PATH = STAMP_ROOT .. "/index.json"
local STORE_KEY = "__BT_STAMPS"

local memoryStore = nil
local fileApi = nil

local function resolveApi(name)
	if getgenv then
		local genv = getgenv()
		local value = rawget(genv, name)
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
		warn("[BT Stamp] writefile failed:", path, err)
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

local function getStampFilePath(stampId)
	return string.format("%s/%s.json", STAMP_ROOT, stampId)
end

local function loadIndexEntries()
	ensureFolder(STAMP_ROOT)

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

local function readStampFile(stampId)
	local content = readFile(getStampFilePath(stampId))
	if not content then
		return nil
	end

	local ok, stamp = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not ok or type(stamp) ~= "table" or type(stamp.buildData) ~= "table" then
		return nil
	end

	return stamp
end

local function writeStampFile(stamp)
	if not hasFileApi() then
		return false
	end

	return writeFile(getStampFilePath(stamp.id), HttpService:JSONEncode(stamp))
end

local function removeStampFile(stampId)
	deleteFile(getStampFilePath(stampId))
end

local function syncMemoryFromDisk()
	memoryStore = {}
	if not hasFileApi() then
		return
	end

	for _, entry in ipairs(loadIndexEntries()) do
		local stamp = readStampFile(entry.id)
		if stamp then
			table.insert(memoryStore, stamp)
		end
	end
end

function StampLibrary.list()
	if hasFileApi() then
		syncMemoryFromDisk()
	end
	return getMemoryStore()
end

function StampLibrary.reload()
	memoryStore = nil
	return StampLibrary.list()
end

function StampLibrary.collectSerializableItems(selectionItems)
	local items = Support.CloneTable(selectionItems)
	for _, item in ipairs(selectionItems) do
		Support.ConcatTable(items, item:GetDescendants())
	end
	return items
end

local function persistStamp(stamp)
	if not writeStampFile(stamp) then
		return nil, "writefile недоступен — stamps не сохранятся на диск"
	end

	if hasFileApi() then
		local entries = loadIndexEntries()
		local found = false
		for _, entry in ipairs(entries) do
			if entry.id == stamp.id then
				entry.name = stamp.name
				entry.createdAt = stamp.createdAt
				found = true
				break
			end
		end
		if not found then
			table.insert(entries, {
				id = stamp.id,
				name = stamp.name,
				createdAt = stamp.createdAt,
			})
		end
		saveIndexEntries(entries)
	end

	if memoryStore == nil then
		getMemoryStore()
	end

	for index, existing in ipairs(memoryStore) do
		if existing.id == stamp.id then
			memoryStore[index] = stamp
			return stamp
		end
	end
	table.insert(memoryStore, stamp)

	return stamp
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
		name = (name ~= nil and name ~= "") and name or ("Stamp " .. (#StampLibrary.list() + 1)),
		createdAt = os.time(),
		buildData = buildData,
	}

	local saved, err = persistStamp(stamp)
	if not saved then
		return nil, err
	end
	return saved
end

function StampLibrary.delete(stampId)
	if hasFileApi() then
		local entries = loadIndexEntries()
		for index, entry in ipairs(entries) do
			if entry.id == stampId then
				table.remove(entries, index)
				saveIndexEntries(entries)
				break
			end
		end
		removeStampFile(stampId)
	end

	local store = StampLibrary.list()
	for index, stamp in ipairs(store) do
		if stamp.id == stampId then
			table.remove(store, index)
			return true
		end
	end
	return false
end

function StampLibrary.find(stampId)
	for _, stamp in ipairs(StampLibrary.list()) do
		if stamp.id == stampId then
			return stamp
		end
	end

	if hasFileApi() then
		local stamp = readStampFile(stampId)
		if stamp then
			table.insert(getMemoryStore(), stamp)
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
		name = name or ("Import " .. (#StampLibrary.list() + 1)),
		createdAt = os.time(),
		buildData = buildData,
	}

	local saved, err = persistStamp(stamp)
	if not saved then
		return nil, err
	end
	return saved
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

function StampLibrary.getStoragePath()
	return STAMP_ROOT
end

return StampLibrary
