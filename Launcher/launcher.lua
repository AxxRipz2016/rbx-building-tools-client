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

local PLACEHOLDER_USER = "YOUR_USERNAME"

local CONFIG = {
	user = "AxxRipz2016",
	repo = "rbx-building-tools-client",
	branch = "main",
	toolName = "Building Tools",
}

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
		"https://raw.githubusercontent.com/%s/%s/%s/%s",
		CONFIG.user,
		CONFIG.repo,
		CONFIG.branch,
		filePath:gsub("\\", "/")
	)
end

local function splitPath(instancePath)
	local parts = {}
	for part in string.gmatch(instancePath, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function getOrCreateParent(tool, instancePath)
	if instancePath == "" or instancePath == nil then
		return tool
	end

	local parent = tool
	for index, name in ipairs(splitPath(instancePath)) do
		local pathSoFar = table.concat(splitPath(instancePath), ".", 1, index)
		local existing = parent:FindFirstChild(name)
		if not existing then
			error("Родитель не создан: " .. pathSoFar, 0)
		end
		parent = existing
	end

	return parent
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
		local source = httpGet(rawUrl(entry.file))
		instance.Source = source
	end

	return instance
end

local function loadManifest()
	local manifestUrl = rawUrl("Launcher/manifest.json")
	local decoded = HttpService:JSONDecode(httpGet(manifestUrl))

	CONFIG.user = resolveGithubField(decoded.github.user, CONFIG.user)
	CONFIG.repo = resolveGithubField(decoded.github.repo, CONFIG.repo)
	CONFIG.branch = decoded.github.branch or CONFIG.branch
	CONFIG.toolName = decoded.toolName or CONFIG.toolName

	return decoded
end

local function buildTool(manifest)
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

local function main()
	local player = Players.LocalPlayer
	if not player then
		error("LocalPlayer не найден", 0)
	end

	print("[BT Launcher] Загрузка manifest...")
	local manifest = loadManifest()

	print("[BT Launcher] Сборка Tool (" .. tostring(manifest.entryCount) .. " объектов)...")
	local tool = buildTool(manifest)

	local backpack = player:WaitForChild("Backpack")
	local existing = backpack:FindFirstChild(tool.Name)
	if existing then
		existing:Destroy()
	end

	tool.Parent = backpack
	print("[BT Launcher] Готово. Экипируй Tool из Backpack.")
end

return main()
