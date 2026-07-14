local InstancePath = {}

local function escapeNameForBracket(name)
	return (name:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

function InstancePath.getSafePath(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end
	if not instance:IsDescendantOf(workspace) then
		return nil
	end

	local path = ""
	local current = instance

	while current and current ~= workspace do
		local name = current.Name
		local segment = ""
		local parent = current.Parent

		if parent then
			local firstChildWithSameName = parent:FindFirstChild(name)
			if firstChildWithSameName and firstChildWithSameName ~= current then
				local children = parent:GetChildren()
				local index = table.find(children, current)
				if index then
					segment = ":GetChildren()[" .. index .. "]"
				end
			else
				local isStandardName = string.match(name, "^[%a_][%w_]*$") ~= nil
				if isStandardName then
					segment = "." .. name
				else
					segment = '["' .. escapeNameForBracket(name) .. '"]'
				end
			end
		end

		path = segment .. path
		current = parent
	end

	return "workspace" .. path
end

function InstancePath.resolveSafePath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	if string.sub(path, 1, 28) == 'game:GetService("Workspace")' then
		path = "workspace" .. string.sub(path, 29)
	end

	if path == "workspace" then
		return workspace
	end

	if string.sub(path, 1, 9) ~= "workspace" then
		return nil
	end

	local rest = string.sub(path, 10)
	if rest == "" then
		return workspace
	end

	local current = workspace
	local pos = 1

	while pos <= #rest do
		local remainder = string.sub(rest, pos)

		if string.sub(remainder, 1, 1) == "." then
			pos += 1
			remainder = string.sub(rest, pos)
			local name = string.match(remainder, "^([%a_][%w_]*)")
			if not name or not current then
				return nil
			end
			current = current:FindFirstChild(name)
			pos += #name
		elseif string.sub(remainder, 1, 2) == '["' then
			local name = string.match(remainder, '^%["([^"]*)"%]')
			if not name or not current then
				return nil
			end
			current = current:FindFirstChild(name)
			pos += #('["' .. name .. '"]')
		elseif string.sub(remainder, 1, 14) == ":GetChildren()[" then
			local indexText = string.match(remainder, "^:GetChildren()%[(%d+)%]")
			if not indexText or not current then
				return nil
			end
			current = current:GetChildren()[tonumber(indexText)]
			pos += #(":GetChildren()[" .. indexText .. "]")
		else
			return nil
		end

		if not current then
			return nil
		end
	end

	return current
end

return InstancePath
