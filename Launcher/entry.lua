-- Однострочник для executor (подставь свой GitHub user/repo/branch):
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/AxxRipz2016/rbx-building-tools-client/main/Launcher/launcher.lua?v=20260713g", true))()

local LAUNCHER_URL = "https://raw.githubusercontent.com/AxxRipz2016/rbx-building-tools-client/main/Launcher/launcher.lua?v=20260713g"

local function httpGet(url)
	if game.HttpGet then
		return game:HttpGet(url, true)
	end
	return game:GetService("HttpService"):GetAsync(url)
end

local source = httpGet(LAUNCHER_URL)
local runner = loadstring(source)
if not runner then
	error("Не удалось скомпилировать launcher", 0)
end
return runner()
