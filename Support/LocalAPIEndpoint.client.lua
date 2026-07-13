local SyncAPI = script.Parent;
local Tool = SyncAPI.Parent;
local RunService = game:GetService 'RunService'
local ClientOnly = Tool:GetAttribute 'BTClientOnly' == true

-- Provide functionality to the local API endpoint instance
SyncAPI.OnInvoke = function (...)

	-- Client-only builds always perform actions locally
	if ClientOnly or RunService:IsServer() then
		local SyncModule = require(SyncAPI:WaitForChild 'SyncModule')
		return SyncModule.PerformAction(game.Players.LocalPlayer, ...)
	end

	-- Route requests to server endpoint in standard tool mode
	local ServerEndpoint = SyncAPI:WaitForChild 'ServerEndpoint'
	return ServerEndpoint:InvokeServer(...)

end;