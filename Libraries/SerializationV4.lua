Serialization = {};

-- Import services
local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary);
local SerializationV3 = require(script.Parent.SerializationV3);
Support.ImportServices();

local TEMP_ROOT = "BT-BuildingTools/temp"

local function resolveApi(name)
	if getgenv then
		local value = rawget(getgenv(), name)
		if value ~= nil then
			return value
		end
	end
	return rawget(_G, name)
end

local function getBase64Encode()
	local direct = resolveApi("base64encode")
	if typeof(direct) == "function" then
		return direct
	end
	local synCrypt = syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.encode
	if typeof(synCrypt) == "function" then
		return synCrypt
	end
	if crypt then
		if typeof(crypt.base64encode) == "function" then
			return crypt.base64encode
		end
		if crypt.base64 and typeof(crypt.base64.encode) == "function" then
			return crypt.base64.encode
		end
	end
	return nil
end

local function readHidden(instance, propertyName)
	local getHidden = resolveApi("gethiddenproperty")
	if typeof(getHidden) ~= "function" then
		return nil
	end
	local ok, value = pcall(getHidden, instance, propertyName)
	if ok then
		return value
	end
	return nil
end

local function resolveInitialSize(union)
	local initialSize = readHidden(union, "InitialSize")
	if initialSize then
		return initialSize
	end
	local ok, meshSize = pcall(function()
		return union.MeshSize
	end)
	if ok and meshSize then
		return meshSize
	end
	return union.Size
end

local function buildUnionRbxmx(union)
	local className = union.ClassName
	local base64encode = getBase64Encode()
	if not base64encode then
		return nil, "base64encode недоступен"
	end

	local resolvedInitialSize = resolveInitialSize(union)
	local serializedProps = {}

	local function addProp(tag, name, value)
		table.insert(serializedProps, string.format('<%s name="%s">%s</%s>', tag, name, tostring(value), tag))
	end

	addProp("string", "Name", union.Name)
	addProp("float", "Transparency", union.Transparency)
	addProp("bool", "CanCollide", union.CanCollide and "true" or "false")
	addProp("bool", "Anchored", union.Anchored and "true" or "false")
	addProp("bool", "UsePartColor", union.UsePartColor and "true" or "false")

	local okFidelity, fidelity = pcall(function()
		return union.CollisionFidelity.Value
	end)
	if okFidelity then
		addProp("token", "CollisionFidelity", fidelity)
	end

	local size = union.Size
	table.insert(serializedProps, string.format(
		'<Vector3 name="size"><X>%s</X><Y>%s</Y><Z>%s</Z></Vector3>',
		size.X, size.Y, size.Z
	))

	table.insert(serializedProps, string.format(
		'<Vector3 name="InitialSize"><X>%s</X><Y>%s</Y><Z>%s</Z></Vector3>',
		resolvedInitialSize.X, resolvedInitialSize.Y, resolvedInitialSize.Z
	))

	local color = union.Color
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	local intColor = 4278190080 + r * 65536 + g * 256 + b
	addProp("Color3uint8", "Color3uint8", intColor)

	local cf = union.CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	table.insert(serializedProps, string.format(
		'<CoordinateFrame name="CFrame">'
			.. '<X>%s</X><Y>%s</Y><Z>%s</Z>'
			.. '<R00>%s</R00><R01>%s</R01><R02>%s</R02>'
			.. '<R10>%s</R10><R11>%s</R11><R12>%s</R12>'
			.. '<R20>%s</R20><R21>%s</R21><R22>%s</R22>'
			.. '</CoordinateFrame>',
		x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
	))

	local physData = readHidden(union, "PhysicalConfigData")
	if physData and physData ~= "" then
		addProp("BinaryString", "PhysicalConfigData", base64encode(physData))
	end

	local assetId = readHidden(union, "AssetId")
	if assetId and assetId ~= "" then
		table.insert(serializedProps, string.format('<Content name="AssetId"><url>%s</url></Content>', assetId))
	end

	local sharedStrings = {}
	local function addSharedString(propName, rawData)
		if rawData and rawData ~= "" then
			local b64 = base64encode(rawData)
			local key = base64encode(tostring(1000000 + #sharedStrings + 1))
			sharedStrings[key] = b64
			addProp("SharedString", propName, key)
		end
	end

	addSharedString("MeshData2", readHidden(union, "MeshData2") or readHidden(union, "MeshData"))
	addSharedString("ChildData2", readHidden(union, "ChildData2") or readHidden(union, "ChildData"))

	local xml = '<roblox version="4">\n'
	xml ..= string.format('  <Item class="%s" referent="RBX0">\n', className)
	xml ..= '    <Properties>\n'
	for _, propXml in ipairs(serializedProps) do
		xml ..= '      ' .. propXml .. '\n'
	end
	xml ..= '    </Properties>\n'
	xml ..= '  </Item>\n'

	if next(sharedStrings) then
		xml ..= '  <SharedStrings>\n'
		for key, b64 in pairs(sharedStrings) do
			xml ..= '    <SharedString md5="' .. key .. '">' .. b64 .. '</SharedString>\n'
		end
		xml ..= '  </SharedStrings>\n'
	end
	xml ..= '</roblox>'

	return xml
end

local function ensureTempFolder()
	local makefolder = resolveApi("makefolder")
	if typeof(makefolder) ~= "function" then
		return
	end
	pcall(makefolder, "BT-BuildingTools")
	pcall(makefolder, TEMP_ROOT)
end

local function inflateUnionFromRbxmx(rbxmx)
	local writefile = resolveApi("writefile")
	local getcustomasset = resolveApi("getcustomasset")
	if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then
		warn("[BT SerializationV4] Union: нужны writefile и getcustomasset")
		return nil
	end

	ensureTempFolder()
	local path = TEMP_ROOT .. "/" .. HttpService:GenerateGUID(false) .. ".rbxmx"
	local writeOk = pcall(writefile, path, rbxmx)
	if not writeOk then
		return nil
	end

	local assetOk, assetUrl = pcall(getcustomasset, path)
	if not assetOk or not assetUrl then
		return nil
	end

	local loadOk, objects = pcall(game.GetObjects, game, assetUrl)
	if loadOk and objects and objects[1] then
		return objects[1]
	end

	return nil
end

local function isSerializableItem(item)
	if item:IsA("PartOperation") then
		return true
	end
	return Types[item.ClassName] ~= nil
end

local Types = {
	Part = 0,
	WedgePart = 1,
	CornerWedgePart = 2,
	VehicleSeat = 3,
	Seat = 4,
	TrussPart = 5,
	SpecialMesh = 6,
	Texture = 7,
	Decal = 8,
	PointLight = 9,
	SpotLight = 10,
	SurfaceLight = 11,
	Smoke = 12,
	Fire = 13,
	Sparkles = 14,
	Model = 15,
	Folder = 18,
	UnionOperation = 19,
	IntersectOperation = 20,
	MeshPart = 21,
};

local DefaultNames = {
	Part = 'Part',
	WedgePart = 'Wedge',
	CornerWedgePart = 'CornerWedge',
	VehicleSeat = 'VehicleSeat',
	Seat = 'Seat',
	TrussPart = 'Truss',
	SpecialMesh = 'Mesh',
	Texture = 'Texture',
	Decal = 'Decal',
	PointLight = 'PointLight',
	SpotLight = 'SpotLight',
	SurfaceLight = 'SurfaceLight',
	Smoke = 'Smoke',
	Fire = 'Fire',
	Sparkles = 'Sparkles',
	Model = 'Model',
	Folder = 'Folder',
	MeshPart = 'MeshPart',
};

function Serialization.SerializeModel(Items)
	-- Returns a serialized version of the given model

	local hasPartOperation = false
	for _, item in ipairs(Items) do
		if item:IsA("PartOperation") then
			hasPartOperation = true
			break
		end
	end

	if not hasPartOperation then
		return SerializationV3.SerializeModel(Items)
	end

	-- Keep only supported instances (scripts/sounds/etc. are skipped, not left as nil holes)
	local SerializableItems = {};
	for _, Item in ipairs(Items) do
		if isSerializableItem(Item) then
			table.insert(SerializableItems, Item);
		end;
	end;
	Items = SerializableItems;

	if #Items == 0 then
		return HttpService:JSONEncode({ Version = 4, Items = {} });
	end;

	-- Get a snapshot of the content
	local Keys = Support.FlipTable(Items);

	local Data = {};
	Data.Version = 4;
	Data.Items = {};

	-- Serialize each item in the model
	for Index, Item in pairs(Items) do

		if Item:IsA 'BasePart' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Size.X;
			Datum[5] = Item.Size.Y;
			Datum[6] = Item.Size.Z;
			Support.ConcatTable(Datum, { Item.CFrame:components() });
			Datum[19] = Item.Color.r;
			Datum[20] = Item.Color.g;
			Datum[21] = Item.Color.b;
			Datum[22] = Item.Material.Value;
			Datum[23] = Item.Anchored and 1 or 0;
			Datum[24] = Item.CanCollide and 1 or 0;
			Datum[25] = Item.Reflectance;
			Datum[26] = Item.Transparency;
			Datum[27] = Item.TopSurface.Value;
			Datum[28] = Item.BottomSurface.Value;
			Datum[29] = Item.FrontSurface.Value;
			Datum[30] = Item.BackSurface.Value;
			Datum[31] = Item.LeftSurface.Value;
			Datum[32] = Item.RightSurface.Value;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Part' then
			local Datum = Data.Items[Index];
			Datum[33] = Item.Shape.Value;
		end;

		if Item.ClassName == 'VehicleSeat' then
			local Datum = Data.Items[Index];
			Datum[33] = Item.MaxSpeed;
			Datum[34] = Item.Torque;
			Datum[35] = Item.TurnSpeed;
		end;

		if Item.ClassName == 'TrussPart' then
			local Datum = Data.Items[Index];
			Datum[33] = Item.Style.Value;
		end;

		if Item.ClassName == 'MeshPart' then
			local Datum = Data.Items[Index];
			Datum[33] = Item.MeshId;
			Datum[34] = Item.TextureID;
		end;

		if Item.ClassName == 'SpecialMesh' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.MeshType.Value;
			Datum[5] = Item.MeshId;
			Datum[6] = Item.TextureId;
			Datum[7] = Item.Offset.X;
			Datum[8] = Item.Offset.Y;
			Datum[9] = Item.Offset.Z;
			Datum[10] = Item.Scale.X;
			Datum[11] = Item.Scale.Y;
			Datum[12] = Item.Scale.Z;
			Datum[13] = Item.VertexColor.X;
			Datum[14] = Item.VertexColor.Y;
			Datum[15] = Item.VertexColor.Z;
			Data.Items[Index] = Datum;
		end;

		if Item:IsA 'Decal' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Texture;
			Datum[5] = Item.Transparency;
			Datum[6] = Item.Face.Value;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Texture' then
			local Datum = Data.Items[Index];
			Datum[7] = Item.StudsPerTileU;
			Datum[8] = Item.StudsPerTileV;
		end;

		if Item:IsA 'Light' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Brightness;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.Enabled and 1 or 0;
			Datum[9] = Item.Shadows and 1 or 0;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'PointLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
		end;

		if Item.ClassName == 'SpotLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
			Datum[11] = Item.Angle;
			Datum[12] = Item.Face.Value;
		end;

		if Item.ClassName == 'SurfaceLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
			Datum[11] = Item.Angle;
			Datum[12] = Item.Face.Value;
		end;

		if Item.ClassName == 'Smoke' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.Size;
			Datum[9] = Item.RiseVelocity;
			Datum[10] = Item.Opacity;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Fire' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.SecondaryColor.r;
			Datum[9] = Item.SecondaryColor.g;
			Datum[10] = Item.SecondaryColor.b;
			Datum[11] = Item.Heat;
			Datum[12] = Item.Size;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Sparkles' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.SparkleColor.r;
			Datum[6] = Item.SparkleColor.g;
			Datum[7] = Item.SparkleColor.b;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Model' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.PrimaryPart and Keys[Item.PrimaryPart] or 0;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Folder' then
			local Datum = {}
			Datum[1] = Types[Item.ClassName]
			Datum[2] = Keys[Item.Parent] or 0
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name
			Data.Items[Index] = Datum
		end

		if Item:IsA('PartOperation') then
			local rbxmx, err = buildUnionRbxmx(Item)
			if rbxmx then
				local Datum = {}
				Datum[1] = Item.ClassName == 'IntersectOperation' and Types.IntersectOperation or Types.UnionOperation
				Datum[2] = Keys[Item.Parent] or 0
				Datum[3] = Item.Name == Item.ClassName and '' or Item.Name
				Datum[4] = rbxmx
				Data.Items[Index] = Datum
			else
				warn("[BT SerializationV4] Union не сохранён:", Item:GetFullName(), err)
			end
		end

		-- Spread the workload over time to avoid locking up the CPU
		if Index % 100 == 0 then
			wait(0.01);
		end;

	end;

	-- Return the serialized data
	return HttpService:JSONEncode(Data);

end;

function Serialization.InflateBuildData(Data)
	-- Returns an inflated version of the given build data

	if Data.Version ~= 4 then
		return SerializationV3.InflateBuildData(Data)
	end

	local Build = {};
	local Instances = {};

	-- Create each instance
	for Index, Datum in ipairs(Data.Items) do

		-- Inflate BaseParts
		if Datum[1] == Types.Part
			or Datum[1] == Types.WedgePart
			or Datum[1] == Types.CornerWedgePart
			or Datum[1] == Types.VehicleSeat
			or Datum[1] == Types.Seat
			or Datum[1] == Types.TrussPart
			or Datum[1] == Types.MeshPart
		then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Size = Vector3.new(unpack(Support.Slice(Datum, 4, 6)));
			Item.CFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
			Item.Color = Color3.new(Datum[19], Datum[20], Datum[21]);
			Item.Material = Datum[22];
			Item.Anchored = Datum[23] == 1;
			Item.CanCollide = Datum[24] == 1;
			Item.Reflectance = Datum[25];
			Item.Transparency = Datum[26];
			Item.TopSurface = Datum[27];
			Item.BottomSurface = Datum[28];
			Item.FrontSurface = Datum[29];
			Item.BackSurface = Datum[30];
			Item.LeftSurface = Datum[31];
			Item.RightSurface = Datum[32];

			-- Register the part
			Instances[Index] = Item;
		end;

		-- Inflate specific Part properties
		if Datum[1] == Types.Part then
			local Item = Instances[Index];
			Item.Shape = Datum[33];
		end;

		-- Inflate specific VehicleSeat properties
		if Datum[1] == Types.VehicleSeat then
			local Item = Instances[Index];
			Item.MaxSpeed = Datum[33];
			Item.Torque = Datum[34];
			Item.TurnSpeed = Datum[35];
		end;

		-- Inflate specific TrussPart properties
		if Datum[1] == Types.TrussPart then
			local Item = Instances[Index];
			Item.Style = Datum[33];
		end;

		if Datum[1] == Types.MeshPart then
			local Item = Instances[Index];
			Item.MeshId = Datum[33];
			Item.TextureID = Datum[34];
		end;

		-- Inflate SpecialMesh instances
		if Datum[1] == Types.SpecialMesh then
			local Item = Instance.new('SpecialMesh');
			Item.MeshType = Datum[4];
			Item.MeshId = Datum[5];
			Item.TextureId = Datum[6];
			Item.Offset = Vector3.new(unpack(Support.Slice(Datum, 7, 9)));
			Item.Scale = Vector3.new(unpack(Support.Slice(Datum, 10, 12)));
			Item.VertexColor = Vector3.new(unpack(Support.Slice(Datum, 13, 15)));

			-- Register the mesh
			Instances[Index] = Item;
		end;

		-- Inflate Decal instances
		if Datum[1] == Types.Decal or Datum[1] == Types.Texture then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Texture = Datum[4];
			Item.Transparency = Datum[5];
			Item.Face = Datum[6];

			-- Register the Decal
			Instances[Index] = Item;
		end;

		-- Inflate specific Texture properties
		if Datum[1] == Types.Texture then
			local Item = Instances[Index];
			Item.StudsPerTileU = Datum[7];
			Item.StudsPerTileV = Datum[8];
		end;

		-- Inflate Light instances
		if Datum[1] == Types.PointLight
			or Datum[1] == Types.SpotLight
			or Datum[1] == Types.SurfaceLight
		then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Brightness = Datum[4];
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.Enabled = Datum[8] == 1;
			Item.Shadows = Datum[9] == 1;

			-- Register the light
			Instances[Index] = Item;
		end;

		-- Inflate specific PointLight properties
		if Datum[1] == Types.PointLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
		end;

		-- Inflate specific SpotLight properties
		if Datum[1] == Types.SpotLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
			Item.Angle = Datum[11];
			Item.Face = Datum[12];
		end;

		-- Inflate specific SurfaceLight properties
		if Datum[1] == Types.SurfaceLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
			Item.Angle = Datum[11];
			Item.Face = Datum[12];
		end;

		-- Inflate Smoke instances
		if Datum[1] == Types.Smoke then
			local Item = Instance.new('Smoke');
			Item.Enabled = Datum[4] == 1;
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.Size = Datum[8];
			Item.RiseVelocity = Datum[9];
			Item.Opacity = Datum[10];

			-- Register the smoke
			Instances[Index] = Item;
		end;

		-- Inflate Fire instances
		if Datum[1] == Types.Fire then
			local Item = Instance.new('Fire');
			Item.Enabled = Datum[4] == 1;
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.SecondaryColor = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
			Item.Heat = Datum[11];
			Item.Size = Datum[12];

			-- Register the fire
			Instances[Index] = Item;
		end;

		-- Inflate Sparkles instances
		if Datum[1] == Types.Sparkles then
			local Item = Instance.new('Sparkles');
			Item.Enabled = Datum[4] == 1;
			Item.SparkleColor = Color3.new(unpack(Support.Slice(Datum, 5, 7)));

			-- Register the instance
			Instances[Index] = Item;
		end;

		-- Inflate Model instances
		if Datum[1] == Types.Model then
			local Item = Instance.new('Model');

			-- Register the model
			Instances[Index] = Item;
		end;

		-- Inflate Folder instances
		if Datum[1] == Types.Folder then
			local Item = Instance.new('Folder')

			-- Register the folder
			Instances[Index] = Item
		end

		if Datum[1] == Types.UnionOperation or Datum[1] == Types.IntersectOperation then
			local Item = inflateUnionFromRbxmx(Datum[4])
			if Item then
				Instances[Index] = Item
			end
		end

	end;

	-- Set object values on each instance
	for Index, Datum in pairs(Data.Items) do

		-- Get the item's instance
		local Item = Instances[Index];

		-- Set each item's parent and name
		if Item and (Datum[1] <= 18 or Datum[1] == Types.MeshPart or Datum[1] == Types.UnionOperation or Datum[1] == Types.IntersectOperation) then
			Item.Name = (Datum[3] == '') and (DefaultNames[Item.ClassName] or Item.ClassName) or Datum[3];
			if Datum[2] == 0 then
				table.insert(Build, Item);
			else
				Item.Parent = Instances[Datum[2]];
			end;
		end;

		-- Set model primary parts
		if Item and Datum[1] == 15 then
			Item.PrimaryPart = (Datum[4] ~= 0) and Instances[Datum[4]] or nil;
		end;

	end;

	-- Return the model
	return Build;

end;

-- Return the API
return Serialization;