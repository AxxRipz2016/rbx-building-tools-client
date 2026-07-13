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
	toolName = "Building Tools",
}

local CACHE_BUST = "20260713b"

local PATH_ALIASES = {
	{ "^Vendor/Roact/src/", "Libraries/_vendor/Roact/src/" },
}

local gui = nil
local downloadedFiles = 0
local totalFiles = 0

local function resolveGithubField(manifestValue, configValue)
	if manifestValue == nil or manifestValue == "" or manifestValue == PLACEHOLDER_USER then
		return configValue
	end
	return manifestValue
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

local function rawUrl(filePath)
	return string.format(
		"https://raw.githubusercontent.com/%s/%s/%s/%s?v=%s",
		CONFIG.user,
		CONFIG.repo,
		CONFIG.branch,
		filePath:gsub("\\", "/"),
		CACHE_BUST
	)
end

local function remapFilePath(filePath)
	for _, alias in ipairs(PATH_ALIASES) do
		local remapped = filePath:gsub(alias[1], alias[2])
		if remapped ~= filePath then
			return remapped
		end
	end
	return filePath
end

local function fetchFileSource(filePath)
	local pathsToTry = { filePath }
	local remapped = remapFilePath(filePath)
	if remapped ~= filePath then
		table.insert(pathsToTry, remapped)
	end

	local errors = {}
	for _, path in ipairs(pathsToTry) do
		local ok, result = pcall(function()
			return httpGet(rawUrl(path))
		end)
		if ok then
			return result
		end
		table.insert(errors, path .. " -> " .. tostring(result))
	end

	error("HTTP ошибка при загрузке:\n" .. filePath .. "\n" .. table.concat(errors, "\n"), 0)
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
		local source = fetchFileSource(entry.file)
		instance.Source = source
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

	local manifestUrl = rawUrl("Launcher/manifest.json")
	local decoded = HttpService:JSONDecode(httpGet(manifestUrl))

	CONFIG.user = resolveGithubField(decoded.github.user, CONFIG.user)
	CONFIG.repo = resolveGithubField(decoded.github.repo, CONFIG.repo)
	CONFIG.branch = decoded.github.branch or CONFIG.branch
	CONFIG.toolName = decoded.toolName or CONFIG.toolName

	return decoded
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

	local ok, result = pcall(function()
		downloadedFiles = 0

		local manifest = loadManifest()
		totalFiles = countFileEntries(manifest.entries)
		downloadedFiles = 0

		if gui then
			gui.setProgress(0, totalFiles)
			gui.setStatus("Скачивание модулей…")
		end

		local tool = buildTool(manifest)

		local backpack = player:WaitForChild("Backpack")
		local existing = backpack:FindFirstChild(tool.Name)
		if existing then
			existing:Destroy()
		end

		tool.Parent = backpack
		return tool
	end)

	if not ok then
		warn("[BT Launcher] " .. tostring(result))
		if gui then
			local message = tostring(result)
			local title = "Ошибка загрузки"
			local url = message:match("https://[^\n]+")
			if url then
				gui.setError(title, url)
			else
				gui.setError(title, message)
			end
		end
		return
	end

	print("[BT Launcher] Готово. Экипируй Tool из Backpack.")
	if gui then
		gui.setSuccess("Готово!")
	end
end

return main()
