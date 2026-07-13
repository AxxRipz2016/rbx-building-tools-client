--[[
	Building Tools client-only launcher.
	Скачивает manifest.json и все модули с GitHub, собирает Tool в Backpack.

	Перед публикацией:
	1. Заполни Launcher/config.json (user, repo, branch)
	2. npm install && git submodule update --init --recursive
	3. node Launcher/build-manifest.mjs
	4. Залей репозиторий на GitHub
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PLACEHOLDER_USER = "YOUR_USERNAME"

local CONFIG = {
	user = "AxxRipz2016",
	repo = "rbx-building-tools-client",
	branch = "main",
	toolName = "Кубик",
	toolVersion = "3.1.0-client",
}

local LAUNCHER_REVISION = "5"
local CACHE_ROOT = "BT-BuildingTools/cache"
local CACHE_FILES_DIR = CACHE_ROOT .. "/files"
local CACHE_VERSIONS_PATH = CACHE_ROOT .. "/versions.json"

local ModuleCache = {}
local LargeModuleSources = {}
local MAX_INSTANCE_SOURCE = 199000
local fileVersionIndex = {}

local function patchModuleSource(source)
	source = source:gsub("Game:GetService", "game:GetService")
	-- FontFace требует Font.new, которого нет во многих executor'ах; Enum.Font уже задан
	source = source:gsub("[\r\n]+[^\r\n]-%.FontFace = Font%.new%([^\r\n]-%)[\r\n]*", "\n")
	return source
end

local function loadModuleChunk(source, chunkName, env)
	if load then
		local chunk, compileError = load(source, chunkName, "t", env)
		if chunk then
			return chunk
		end
		if compileError then
			error("Компиляция " .. chunkName .. ": " .. tostring(compileError), 0)
		end
	end

	local legacyLoad = loadstring
	if not legacyLoad then
		error("load/loadstring недоступны в executor", 0)
	end

	local chunk, compileError = legacyLoad(source, chunkName)
	if not chunk then
		error("Компиляция " .. chunkName .. ": " .. tostring(compileError), 0)
	end

	if setfenv then
		setfenv(chunk, env)
	end

	return chunk
end

local function createModuleEnvironment(moduleScript, btRequire)
	local env = {
		script = moduleScript,
		require = btRequire,
		game = game,
		Game = game,
		workspace = workspace,
		Workspace = workspace,
		typeof = typeof,
		type = type,
		ipairs = ipairs,
		pairs = pairs,
		next = next,
		table = table,
		string = string,
		math = math,
		coroutine = coroutine,
		task = task,
		os = os,
		tick = tick,
		time = time,
		wait = task.wait,
		delay = task.delay,
		spawn = task.spawn,
		print = print,
		warn = warn,
		error = error,
		pcall = pcall,
		xpcall = xpcall,
		select = select,
		unpack = unpack,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		tostring = tostring,
		tonumber = tonumber,
		assert = assert,
		Enum = Enum,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		UDim = UDim,
		UDim2 = UDim2,
		Rect = Rect,
		BrickColor = BrickColor,
		Instance = Instance,
		Font = typeof(Font) ~= "nil" and Font or nil,
		Axes = Axes,
		Faces = Faces,
		Region3 = Region3,
		Ray = Ray,
	}

	env.getmetatable = getmetatable
	env.setmetatable = setmetatable

	env.newproxy = function(addMeta)
		local mt = {}
		return setmetatable({}, mt)
	end

	function env.getfenv(_level)
		return env
	end

	function env.setfenv()
		return env
	end

	env._G = env

	local globalEnv = if getgenv then getgenv() else _G
	local executorApis = {
		"getgenv",
		"writefile",
		"readfile",
		"isfile",
		"isfolder",
		"makefolder",
		"listfiles",
		"delfile",
		"delfolder",
	}
	for _, apiName in ipairs(executorApis) do
		local api = rawget(globalEnv, apiName) or rawget(_G, apiName)
		if api ~= nil then
			env[apiName] = api
		end
	end

	setmetatable(env, { __index = _G })

	return env
end

local function createBtRequire(tool)
	local function btRequire(moduleScript)
		if ModuleCache[moduleScript] ~= nil then
			return ModuleCache[moduleScript]
		end

		if typeof(moduleScript) ~= "Instance" or not moduleScript:IsA("ModuleScript") then
			error("btRequire ожидает ModuleScript, получено: " .. typeof(moduleScript), 0)
		end

		local source = LargeModuleSources[moduleScript] or moduleScript.Source
		if source == nil or source == "" then
			error("Пустой исходник: " .. moduleScript:GetFullName(), 0)
		end

		source = patchModuleSource(source)
		local env = createModuleEnvironment(moduleScript, btRequire)
		local chunk = loadModuleChunk(source, moduleScript:GetFullName(), env)

		local ok, result = pcall(chunk)
		if not ok then
			error(moduleScript:GetFullName() .. ": " .. tostring(result), 0)
		end

		if result == nil then
			result = true
		end

		ModuleCache[moduleScript] = result
		return result
	end

	local function smartRequire(target)
		if typeof(target) == "Instance" and target:IsA("ModuleScript") and target:IsDescendantOf(tool) then
			return btRequire(target)
		end
		return require(target)
	end

	return smartRequire, btRequire
end

local function installCompat()
	if rawget(_G, "Game") == nil then
		_G.Game = game
	end

	if newproxy == nil then
		_G.newproxy = function(_addMeta)
			return setmetatable({}, {})
		end
	end

	if getfenv == nil then
		getfenv = function()
			return _G
		end
	end

	local services = {
		Workspace = game:GetService("Workspace"),
		Players = game:GetService("Players"),
		UserInputService = game:GetService("UserInputService"),
		RunService = game:GetService("RunService"),
		HttpService = game:GetService("HttpService"),
		MarketplaceService = game:GetService("MarketplaceService"),
		ContentProvider = game:GetService("ContentProvider"),
		CoreGui = game:GetService("CoreGui"),
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
	}

	for name, service in pairs(services) do
		_G[name] = service
	end
end

local ROACT_VENDOR_PREFIX = "Vendor/Roact/src/"
local ROACT_PUBLISHED_PREFIX = "Libraries/_vendor/Roact/src/"

local gui = nil
local downloadedFiles = 0
local totalFiles = 0

local function resolveGithubField(manifestValue, configValue)
	if manifestValue == nil or manifestValue == "" or manifestValue == PLACEHOLDER_USER then
		return configValue
	end
	return manifestValue
end

local function hasFileApi()
	return typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
end

local function ensureFolder(path)
	if typeof(makefolder) ~= "function" then
		return
	end

	if typeof(isfolder) == "function" and isfolder(path) then
		return
	end

	pcall(makefolder, path)
end

local function splitPath(filePath)
	local parts = {}
	for segment in filePath:gsub("\\", "/"):gmatch("[^/]+") do
		table.insert(parts, segment)
	end
	return parts
end

local function ensureParentFolders(filePath)
	if typeof(makefolder) ~= "function" then
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

local function getFileCachePath(relativePath)
	return CACHE_FILES_DIR .. "/" .. relativePath:gsub("\\", "/")
end

local function loadFileVersionIndex()
	fileVersionIndex = {}
	if not hasFileApi() or not isfile(CACHE_VERSIONS_PATH) then
		return
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(CACHE_VERSIONS_PATH))
	end)
	if ok and type(decoded) == "table" then
		fileVersionIndex = decoded
	end
end

local function saveFileVersionIndex()
	if not hasFileApi() then
		return
	end

	ensureParentFolders(CACHE_VERSIONS_PATH)
	pcall(writefile, CACHE_VERSIONS_PATH, HttpService:JSONEncode(fileVersionIndex))
end

local function readCachedSource(relativePath, fileVersion)
	if not hasFileApi() or not fileVersion then
		return nil
	end

	if fileVersionIndex[relativePath] ~= fileVersion then
		return nil
	end

	local cachePath = getFileCachePath(relativePath)
	if not isfile(cachePath) then
		return nil
	end

	local ok, content = pcall(readfile, cachePath)
	if ok and type(content) == "string" and content ~= "" then
		return content
	end

	return nil
end

local function writeCachedSource(relativePath, fileVersion, content)
	if not hasFileApi() or not fileVersion then
		return
	end

	local cachePath = getFileCachePath(relativePath)
	ensureParentFolders(cachePath)
	pcall(writefile, cachePath, content)
	fileVersionIndex[relativePath] = fileVersion
end

local function httpGet(url)
	local ok, result = pcall(function()
		if game.HttpGet then
			return game:HttpGet(url, true)
		end
		return HttpService:GetAsync(url)
	end)
	if not ok then
		error("HTTP ошибка: " .. tostring(result) .. "\nURL: " .. url, 0)
	end
	return result
end

local function rawUrl(filePath, fileVersion)
	local url = string.format(
		"https://raw.githubusercontent.com/%s/%s/%s/%s?v=%s",
		CONFIG.user,
		CONFIG.repo,
		CONFIG.branch,
		filePath:gsub("\\", "/"),
		fileVersion or LAUNCHER_REVISION
	)
	return url
end

local function resolveFilePath(filePath)
	if filePath:find(ROACT_VENDOR_PREFIX, 1, true) then
		return filePath:gsub(ROACT_VENDOR_PREFIX, ROACT_PUBLISHED_PREFIX, 1)
	end
	return filePath
end

local function migrateManifest(manifest)
	for _, entry in ipairs(manifest.entries) do
		if entry.file then
			entry.file = resolveFilePath(entry.file)
		end
	end
	return manifest
end

local function fetchFileSource(filePath, fileVersion)
	local resolved = resolveFilePath(filePath)
	local pathsToTry = if resolved ~= filePath then { resolved, filePath } else { filePath }

	for _, path in ipairs(pathsToTry) do
		local cached = readCachedSource(path, fileVersion)
		if cached then
			if gui then
				gui.setStatus("Из кэша")
			end
			return cached
		end
	end

	local errors = {}
	for _, path in ipairs(pathsToTry) do
		local ok, result = pcall(function()
			return httpGet(rawUrl(path, fileVersion))
		end)
		if ok then
			if gui then
				gui.setStatus("Скачивание…")
			end
			writeCachedSource(path, fileVersion, result)
			return result
		end
		table.insert(errors, rawUrl(path, fileVersion) .. "\n" .. tostring(result))
	end

	error("HTTP ошибка при загрузке:\n" .. table.concat(errors, "\n\n"), 0)
end

local function deleteCacheTree(path)
	if typeof(delfolder) == "function" then
		pcall(delfolder, path)
		return
	end

	if typeof(listfiles) ~= "function" or typeof(delfile) ~= "function" then
		return
	end

	local ok, entries = pcall(listfiles, path)
	if not ok or type(entries) ~= "table" then
		return
	end

	for _, entry in ipairs(entries) do
		local childPath = if entry:find("/", 1, true) then entry else (path .. "/" .. entry)
		if typeof(isfolder) == "function" and isfolder(childPath) then
			deleteCacheTree(childPath)
		else
			pcall(delfile, childPath)
		end
	end

	if typeof(delfolder) == "function" then
		pcall(delfolder, path)
	end
end

local function purgeStaleCache(manifest)
	if not hasFileApi() then
		return
	end

	ensureFolder(CACHE_FILES_DIR)

	local validFiles = {}
	for _, entry in ipairs(manifest.entries) do
		if entry.file then
			validFiles[entry.file] = true
			local resolved = resolveFilePath(entry.file)
			validFiles[resolved] = true
		end
	end

	for filePath in pairs(fileVersionIndex) do
		if not validFiles[filePath] then
			fileVersionIndex[filePath] = nil
			local cachePath = getFileCachePath(filePath)
			if typeof(delfile) == "function" and isfile(cachePath) then
				pcall(delfile, cachePath)
			end
		end
	end

	if typeof(listfiles) ~= "function" then
		saveFileVersionIndex()
		return
	end

	local ok, entries = pcall(listfiles, CACHE_ROOT)
	if ok and type(entries) == "table" then
		for _, entry in ipairs(entries) do
			local name = if entry:find("/", 1, true) then entry:match("([^/]+)$") else entry
			if name ~= "files" and name ~= "versions.json" then
				local legacyPath = CACHE_ROOT .. "/" .. name
				if typeof(isfolder) == "function" and isfolder(legacyPath) then
					deleteCacheTree(legacyPath)
				elseif typeof(delfile) == "function" and isfile(legacyPath) then
					pcall(delfile, legacyPath)
				end
			end
		end
	end

	saveFileVersionIndex()
end

local function getParentPath(fullPath)
	if not fullPath or not string.find(fullPath, ".", 1, true) then
		return ""
	end
	return fullPath:match("^(.*)%.[^%.]+$") or ""
end

local function getInstanceName(fullPath)
	if not fullPath or fullPath == "" then
		return nil
	end
	return fullPath:match("[^%.]+$")
end

local function applyProperties(instance, properties)
	for key, value in pairs(properties) do
		if key == "Size" and typeof(value) == "table" then
			instance.Size = Vector3.new(value[1], value[2], value[3])
		elseif key == "Value" then
			instance.Value = value
		else
			pcall(function()
				instance[key] = value
			end)
		end
	end
end

local function reportFileProgress(filePath)
	downloadedFiles += 1
	if gui then
		gui.setProgress(downloadedFiles, totalFiles)
		gui.setFile(filePath)
	end
	RunService.Heartbeat:Wait()
end

local function createInstance(entry)
	local className = entry.className
	local instance = Instance.new(className)
	local name = getInstanceName(entry.path)

	if name then
		instance.Name = name
	end

	if entry.properties then
		applyProperties(instance, entry.properties)
	end

	if entry.value ~= nil and instance:IsA("ValueBase") then
		instance.Value = entry.value
	end

	if entry.file and (instance:IsA("LuaSourceContainer") or instance:IsA("Script")) then
		reportFileProgress(entry.file)
		local source = fetchFileSource(entry.file, entry.version)
		if #source > MAX_INSTANCE_SOURCE then
			LargeModuleSources[instance] = source
			instance.Source = "-- BT: source too large for Instance.Source"
		else
			instance.Source = source
		end
	end

	return instance
end

local function countFileEntries(entries)
	local count = 0
	for _, entry in ipairs(entries) do
		if entry.file then
			count += 1
		end
	end
	return count
end

local function loadManifest()
	if gui then
		gui.setStatus("Загрузка manifest…")
		gui.setFile("Launcher/manifest.json")
		RunService.Heartbeat:Wait()
	end

	local manifestPath = "Launcher/manifest.json"
	local manifestUrl = rawUrl(manifestPath, CONFIG.toolVersion or LAUNCHER_REVISION)
	local manifestContent = httpGet(manifestUrl)

	local decoded = HttpService:JSONDecode(manifestContent)

	CONFIG.user = resolveGithubField(decoded.github.user, CONFIG.user)
	CONFIG.repo = resolveGithubField(decoded.github.repo, CONFIG.repo)
	CONFIG.branch = decoded.github.branch or CONFIG.branch
	CONFIG.toolName = decoded.toolName or CONFIG.toolName
	CONFIG.toolVersion = decoded.toolVersion or CONFIG.toolVersion

	return migrateManifest(decoded)
end

local function buildTool(manifest)
	if gui then
		gui.setStatus("Сборка Tool…")
	end

	local tool = Instance.new("Tool")
	tool.Name = CONFIG.toolName
	tool.RequiresHandle = true
	tool:SetAttribute("BTClientOnly", true)

	local instancesByPath = {
		[""] = tool,
	}

	for _, entry in ipairs(manifest.entries) do
		local parentPath = getParentPath(entry.path)
		local parent = instancesByPath[parentPath]
		if not parent then
			error("Не найден родитель для: " .. tostring(entry.path), 0)
		end

		local instance = createInstance(entry)
		instance.Parent = parent
		instancesByPath[entry.path] = instance
	end

	local descendantCount = #tool:GetDescendants()
	local loaded = tool:FindFirstChild("Loaded")
	local countValue = loaded and loaded:FindFirstChild("DescendantCount")
	if countValue then
		countValue.Value = descendantCount
	end

	return tool
end

local function disableClientScripts(tool)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
end

local function bootstrapTool(tool)
	installCompat()

	local loaded = tool:WaitForChild("Loaded")
	local descendantCount = loaded:FindFirstChild("DescendantCount")

	if descendantCount and descendantCount.Value > 0 then
		while #tool:GetDescendants() < descendantCount.Value do
			RunService.Heartbeat:Wait()
		end
	end

	loaded.Value = true

	local btRequire = createBtRequire(tool)
	btRequire(tool.Core:WaitForChild("HandleVisual")).apply(tool)

	local interfaces = tool:WaitForChild("Interfaces")
	if not interfaces:FindFirstChild("BTMoveToolGUI") then
		btRequire(interfaces:WaitForChild("BuildInterfaces"))
	end
	btRequire(tool.UI:WaitForChild("LegacyPanelTheme")).applyAll(interfaces)

	local syncAPI = tool:WaitForChild("SyncAPI")
	local syncModule = btRequire(syncAPI:WaitForChild("SyncModule"))

	syncAPI.OnInvoke = function(...)
		return syncModule.PerformAction(Players.LocalPlayer, ...)
	end

	btRequire(tool:WaitForChild("Loader"))
end

local function loadGui()
	local ok, guiApi = pcall(function()
		local guiSource = fetchFileSource("Launcher/gui.lua")
		local guiModule = loadstring(guiSource)
		if not guiModule then
			error("Не удалось скомпилировать Launcher/gui.lua", 0)
		end
		local Gui = guiModule()
		return Gui.create()
	end)

	if ok then
		return guiApi
	end

	warn("[BT Launcher] GUI не загружен: " .. tostring(guiApi))
	return {
		setStatus = function() end,
		setFile = function() end,
		setProgress = function() end,
		setError = function(_, details)
			warn("[BT Launcher] " .. tostring(details))
		end,
		setSuccess = function() end,
		destroy = function() end,
	}
end

local function main()
	local player = Players.LocalPlayer
	if not player then
		error("LocalPlayer не найден", 0)
	end

	gui = loadGui()
	gui.setStatus("Инициализация…")
	gui.setProgress(0, 1)

	loadFileVersionIndex()

	local ok, result = pcall(function()
		downloadedFiles = 0

		local manifest = loadManifest()
		purgeStaleCache(manifest)
		totalFiles = countFileEntries(manifest.entries)
		downloadedFiles = 0

		if gui then
			gui.setProgress(0, totalFiles)
			gui.setStatus("Скачивание модулей…")
		end

		local tool = buildTool(manifest)
		saveFileVersionIndex()
		disableClientScripts(tool)

		local backpack = player:WaitForChild("Backpack")
		local existing = backpack:FindFirstChild(tool.Name)
		if existing then
			existing:Destroy()
		end

		tool.Parent = backpack

		if gui then
			gui.setStatus("Инициализация Tool…")
			gui.setFile("Loader / SyncAPI / Core")
		end

		bootstrapTool(tool)
		return tool
	end)

	if not ok then
		warn("[BT Launcher] " .. tostring(result))
		if gui then
			local message = tostring(result)
			gui.setError("Ошибка загрузки", message)
		end
		return
	end

	print("[BT Launcher] Готово. Экипируй Tool из Backpack.")
	if gui then
		gui.setSuccess("Готово!")
	end
end

return main()
