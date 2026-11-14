--!strict
--[[
	Lobby — the Marrow Creek ranger outpost: a clearing in a pine forest at
	night, a cabin with the freight elevator, and a supply shelf along one wall.
	Players spawn at the trailhead looking at the cabin; the shop is inside and
	to the left, where you find it rather than where it finds you.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Build = require(script.Parent.Build)
local Facility = require(script.Parent.Facility)

local Lobby = {}

export type ShopItem = { Key: string, Prompt: ProximityPrompt, Card: TextLabel }
export type Lobby = {
	Folder: Folder,
	PadCenter: Vector3,
	PadSize: Vector3,
	CountdownLabel: TextLabel,
	ReturnCFrame: CFrame,
	ShopItems: { ShopItem },
	SirenPrompt: ProximityPrompt,
	SirenPart: Part,
	BoardLabel: TextLabel,
	ElevatorSound: Sound,
}

local WOOD = Color3.fromRGB(72, 52, 38)
local WOOD_DARK = Color3.fromRGB(44, 32, 25)
local PINE = Color3.fromRGB(18, 38, 28)
local BARK = Color3.fromRGB(38, 28, 22)
local STEEL = Color3.fromRGB(70, 74, 76)
local HAZARD = Color3.fromRGB(196, 150, 28)
local WARM = Color3.fromRGB(255, 190, 120)

local function pine(parent: Instance, base: Vector3, height: number, rng: Random)
	local trunkH = height * 0.3
	Build.block(parent, "Trunk", Vector3.new(trunkH, 1.6, 1.6), CFrame.new(base + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), BARK, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder, CastShadow = false })
	local layers = 3
	for i = 1, layers do
		local t = (i - 1) / layers
		local w = height * 0.42 * (1 - t * 0.55)
		local h = height * 0.34
		local y = trunkH + height * 0.7 * t + h / 2 - 1
		local yaw = rng:NextNumber(0, math.pi)
		-- two wedges back to back make a tent; two tents crossed make a tree layer
		for k = 0, 1 do
			local cf = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, yaw + k * math.pi / 2, 0)
			Build.wedge(parent, "Bough", Vector3.new(w * 0.5, h, w / 2), cf * CFrame.new(0, 0, w / 4), PINE, Enum.Material.Grass, { CanCollide = false, CastShadow = false })
			Build.wedge(parent, "Bough", Vector3.new(w * 0.5, h, w / 2), cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, w / 4), PINE, Enum.Material.Grass, { CanCollide = false, CastShadow = false })
		end
	end
end

local function buildForest(folder: Folder)
	local forest = Build.folder(folder, "Forest")
	Build.block(forest, "Ground", Vector3.new(700, 4, 700), CFrame.new(0, -2, 0), Color3.fromRGB(24, 32, 24), Enum.Material.Grass)
	Build.block(forest, "Path", Vector3.new(9, 0.2, 86), CFrame.new(0, 0.05, 20), Color3.fromRGB(52, 44, 36), Enum.Material.Ground, { CanCollide = false })
	local rng = Random.new(1987)
	local placed = 0
	while placed < 150 do
		local x, z = rng:NextNumber(-300, 300), rng:NextNumber(-300, 300)
		local clearing = math.abs(x) < 48 and z > -75 and z < 95
		local onPath = math.abs(x) < 12 and z > -30
		if not clearing and not onPath then
			pine(forest, Vector3.new(x, 0, z), rng:NextNumber(34, 62), rng)
			placed += 1
		end
	end
	-- invisible fence so nobody wanders off the edge of the world
	for _, side in { { 0, 150, 300, 2 }, { 0, -150, 300, 2 }, { 150, 0, 2, 300 }, { -150, 0, 2, 300 } } do
		Build.block(forest, "Bound", Vector3.new(side[3], 80, side[4]), CFrame.new(side[1], 38, side[2]), PINE, Enum.Material.SmoothPlastic, { Transparency = 1 })
	end

	-- the relay mast: the landmark you can see from anywhere
	local mast = Instance.new("TrussPart")
	mast.Name = "RelayMast"
	mast.Size = Vector3.new(4, 110, 4)
	mast.CFrame = CFrame.new(-70, 55, -95)
	mast.Color = STEEL
	mast.Anchored = true
	mast.Parent = forest
	local beacon = Build.block(forest, "MastBeacon", Vector3.new(2, 2, 2), CFrame.new(-70, 111, -95), Color3.fromRGB(255, 30, 20), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	Build.pointLight(beacon, Color3.fromRGB(255, 30, 20), 3, 60)
	CollectionService:AddTag(beacon, "HS_Beacon")

	-- trailhead: truck with its lights left on, and a sign nobody obeyed
	local truck = Build.model(forest, "Truck")
	local tcf = CFrame.new(15, 0, 70) * CFrame.Angles(0, math.rad(-8), 0)
	Build.block(truck, "Bed", Vector3.new(7, 2.4, 9), tcf * CFrame.new(0, 2.6, 5), Color3.fromRGB(60, 76, 64), Enum.Material.Metal)
	Build.block(truck, "Cab", Vector3.new(7, 5, 6), tcf * CFrame.new(0, 3.9, -2.5), Color3.fromRGB(60, 76, 64), Enum.Material.Metal)
	Build.block(truck, "Hood", Vector3.new(7, 2.6, 4.5), tcf * CFrame.new(0, 2.7, -7.7), Color3.fromRGB(60, 76, 64), Enum.Material.Metal)
	Build.block(truck, "Glass", Vector3.new(6.2, 2, 0.2), tcf * CFrame.new(0, 5.2, -5.55), Color3.fromRGB(20, 28, 30), Enum.Material.Glass, { CanCollide = false, Reflectance = 0.25 })
	for _, wx in { -3.3, 3.3 } do
		for _, wz in { -6.5, 6 } do
			Build.block(truck, "Wheel", Vector3.new(1.2, 2.8, 2.8), tcf * CFrame.new(wx, 1.4, wz), Color3.fromRGB(16, 16, 16), Enum.Material.Rubber, { Shape = Enum.PartType.Cylinder })
		end
		local lamp = Build.block(truck, "Headlight", Vector3.new(1, 0.8, 0.2), tcf * CFrame.new(wx * 0.75, 3, -10), Color3.fromRGB(255, 244, 214), Enum.Material.Neon, { CanCollide = false })
		Build.spotLight(lamp, Enum.NormalId.Front, Color3.fromRGB(255, 240, 205), 3.2, 60, 55, true)
	end
	local radio = Build.block(truck, "Radio", Vector3.new(1, 1, 1), tcf * CFrame.new(0, 4, -3), STEEL, Enum.Material.Metal, { Transparency = 1, CanCollide = false })
	Sfx.make(radio, "Static", { Volume = 0.12, Looped = true, MaxDistance = 40 }):Play()

	local post = Build.block(forest, "SignPost", Vector3.new(0.6, 7, 0.6), CFrame.new(-8, 3.5, 52), WOOD_DARK, Enum.Material.Wood)
	local board = Build.block(forest, "TrailSign", Vector3.new(9, 4, 0.4), post.CFrame * CFrame.new(0, 2.4, 0.4), WOOD, Enum.Material.WoodPlanks)
	Build.sign(board, Enum.NormalId.Back, "MARROW CREEK RELAY\nSTATE PROPERTY — NO PUBLIC ACCESS\n<font size=\"14\">sealed by order, 1989</font>", Config.Fonts.Sign, { TextColor = Color3.fromRGB(222, 213, 190), Rich = true, PixelsPerStud = 30 })
	local scrawl = Build.block(forest, "TrailScrawl", Vector3.new(8, 1.6, 0.1), board.CFrame * CFrame.new(0.4, -2.6, 0.3) * CFrame.Angles(0, 0, math.rad(-4)), WOOD, Enum.Material.WoodPlanks, { Transparency = 1, CanCollide = false })
	Build.sign(scrawl, Enum.NormalId.Back, "it knows your name", Config.Fonts.Scrawl, { TextColor = Color3.fromRGB(150, 20, 20) })

	-- campfire the last crew left burning
	local fireBase = Vector3.new(-22, 0, 24)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.block(forest, "FireStone", Vector3.new(1.4, 1, 1.4), CFrame.new(fireBase + Vector3.new(math.cos(a) * 2.4, 0.4, math.sin(a) * 2.4)), Color3.fromRGB(60, 60, 60), Enum.Material.Slate)
	end
	local ember = Build.block(forest, "Embers", Vector3.new(2.6, 0.4, 2.6), CFrame.new(fireBase + Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 96, 30), Enum.Material.Neon, { CanCollide = false })
	Build.pointLight(ember, Color3.fromRGB(255, 120, 50), 1.6, 34, true)
	CollectionService:AddTag(ember, "HS_Candle")
	local fire = Instance.new("Fire")
	fire.Heat = 6
	fire.Size = 5
	fire.Parent = ember
	for _, lz in { -6, 6 } do
		Build.block(forest, "Log", Vector3.new(7, 1.4, 1.4), CFrame.new(fireBase + Vector3.new(0, 0.7, lz)), BARK, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	end
end

local function buildCabin(folder: Folder, lobby: Lobby)
	local cabin = Build.folder(folder, "Cabin")
	local X1, X2, Z1, Z2, H = -24, 24, -58, -24, 13 -- interior bounds
	local wallT = 1
	Build.block(cabin, "Floor", Vector3.new(X2 - X1 + 2, 0.6, Z2 - Z1 + 2), CFrame.new(0, 0.3, (Z1 + Z2) / 2), WOOD_DARK, Enum.Material.WoodPlanks)
	Build.block(cabin, "Porch", Vector3.new(26, 0.5, 8), CFrame.new(0, 0.25, Z2 + 4.5), WOOD_DARK, Enum.Material.WoodPlanks)
	-- walls (front wall has the doorway)
	Build.block(cabin, "WallBack", Vector3.new(X2 - X1 + 2, H, wallT), CFrame.new(0, H / 2, Z1 - 0.5), WOOD, Enum.Material.WoodPlanks)
	Build.block(cabin, "WallWest", Vector3.new(wallT, H, Z2 - Z1), CFrame.new(X1 - 0.5, H / 2, (Z1 + Z2) / 2), WOOD, Enum.Material.WoodPlanks)
	Build.block(cabin, "WallEast", Vector3.new(wallT, H, Z2 - Z1), CFrame.new(X2 + 0.5, H / 2, (Z1 + Z2) / 2), WOOD, Enum.Material.WoodPlanks)
	local doorW, doorH = 8, 9.5
	local sideW = (X2 - X1 + 2 - doorW) / 2
	for _, s in { -1, 1 } do
		Build.block(cabin, "WallFront", Vector3.new(sideW, H, wallT), CFrame.new(s * (doorW / 2 + sideW / 2), H / 2, Z2 + 0.5), WOOD, Enum.Material.WoodPlanks)
		-- a warm window either side of the door
		local window = Build.block(cabin, "Window", Vector3.new(5, 4, 0.3), CFrame.new(s * 13, 6.5, Z2 + 1.05), WARM, Enum.Material.Neon, { CanCollide = false, Transparency = 0.25 })
		Build.pointLight(window, WARM, 0.7, 18)
		Build.block(cabin, "PorchPost", Vector3.new(0.8, 10, 0.8), CFrame.new(s * 12, 5, Z2 + 8), WOOD_DARK, Enum.Material.Wood)
	end
	Build.block(cabin, "WallFrontTop", Vector3.new(doorW, H - doorH, wallT), CFrame.new(0, doorH + (H - doorH) / 2, Z2 + 0.5), WOOD, Enum.Material.WoodPlanks)
	Build.block(cabin, "Ceiling", Vector3.new(X2 - X1 + 2, 0.6, Z2 - Z1 + 2), CFrame.new(0, H + 0.3, (Z1 + Z2) / 2), WOOD_DARK, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		Build.wedge(cabin, "Roof", Vector3.new(Z2 - Z1 + 14, 9, (X2 - X1) / 2 + 4), CFrame.new(s * ((X2 - X1) / 4 + 2), H + 5.1, (Z1 + Z2) / 2 + 3) * CFrame.Angles(0, math.rad(if s == 1 then -90 else 90), 0), Color3.fromRGB(34, 36, 38), Enum.Material.Slate, { CastShadow = false })
	end
	local header = Build.block(cabin, "Header", Vector3.new(14, 1.8, 0.3), CFrame.new(0, doorH + 1.6, Z2 + 1.2), WOOD_DARK, Enum.Material.Wood, { CanCollide = false })
	Build.sign(header, Enum.NormalId.Back, "RANGER OUTPOST 9", Config.Fonts.Sign, { TextColor = Color3.fromRGB(222, 213, 190) })
	local porchLamp = Build.block(cabin, "PorchLamp", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, doorH + 0.2, Z2 + 2.2), WARM, Enum.Material.Neon, { CanCollide = false, Shape = Enum.PartType.Ball })
	Build.pointLight(porchLamp, WARM, 1.3, 30, true)
	CollectionService:AddTag(porchLamp, "HS_Flicker")
	porchLamp:SetAttribute("Lit", true)

	-- interior light: one bare bulb, so the corners stay dark
	local bulb = Build.block(cabin, "Bulb", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, H - 2, -38), WARM, Enum.Material.Neon, { CanCollide = false, Shape = Enum.PartType.Ball })
	Build.pointLight(bulb, WARM, 1.5, 38, true)

	-- freight elevator against the back wall
	local padCenter = Vector3.new(0, 0.7, Z1 + 7.5)
	local padSize = Vector3.new(15, 0.2, 13)
	lobby.PadCenter = padCenter
	lobby.PadSize = padSize
	Build.block(cabin, "ElevatorPad", padSize, CFrame.new(padCenter), HAZARD, Enum.Material.DiamondPlate)
	for _, ox in { -1, 1 } do
		for _, oz in { -1, 1 } do
			Build.block(cabin, "ElevatorPost", Vector3.new(0.8, H - 1, 0.8), CFrame.new(padCenter + Vector3.new(ox * 7.5, (H - 1) / 2, oz * 6.5)), STEEL, Enum.Material.Metal)
		end
		Build.block(cabin, "ElevatorMesh", Vector3.new(0.3, 7, 13), CFrame.new(padCenter + Vector3.new(ox * 7.5, 3.6, 0)), STEEL, Enum.Material.DiamondPlate, { Transparency = 0.25 })
	end
	local eSign = Build.block(cabin, "ElevatorSign", Vector3.new(15, 2.4, 0.3), CFrame.new(padCenter + Vector3.new(0, 10.4, 6.5)), Color3.fromRGB(14, 14, 14), Enum.Material.Metal, { CanCollide = false })
	lobby.CountdownLabel = Build.sign(eSign, Enum.NormalId.Back, "FREIGHT 01\nSTEP ON TO DESCEND", Config.Fonts.Mono, { TextColor = Config.Colors.Amber, LightInfluence = 0, Brightness = 1.4 })
	local eLamp = Build.block(cabin, "ElevatorLamp", Vector3.new(1, 0.6, 1), CFrame.new(padCenter + Vector3.new(0, H - 1.6, 0)), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, { CanCollide = false })
	Build.pointLight(eLamp, Color3.fromRGB(255, 40, 30), 1.2, 22)
	CollectionService:AddTag(eLamp, "HS_Beacon")
	lobby.ElevatorSound = Sfx.make(eLamp, "Elevator", { Volume = 1, MaxDistance = 120 })

	-- supply shelf along the west wall
	local shelfX = X1 + 1.6
	Build.block(cabin, "ShelfBack", Vector3.new(0.4, 9, 30), CFrame.new(X1 + 0.3, 5, -41), WOOD_DARK, Enum.Material.WoodPlanks)
	for _, y in { 3.2, 6.4 } do
		Build.block(cabin, "Shelf", Vector3.new(2.6, 0.3, 30), CFrame.new(shelfX, y, -41), WOOD_DARK, Enum.Material.WoodPlanks)
	end
	local supplySign = Build.block(cabin, "SupplySign", Vector3.new(0.2, 1.6, 10), CFrame.new(X1 + 0.7, 10.6, -41), Color3.fromRGB(14, 14, 14), Enum.Material.Metal, { CanCollide = false })
	Build.sign(supplySign, Enum.NormalId.Right, "SUPPLY", Config.Fonts.Sign, { TextColor = Config.Colors.Amber, LightInfluence = 0, Brightness = 1.2 })
	Build.pointLight(supplySign, Config.Colors.Amber, 0.5, 14)
	local keys = { "Flashlight", "NightVision", "Tracker", "Stamina", "SecondWind", "Veteran" }
	local shapes: { [string]: { Size: Vector3, Color: Color3, Material: Enum.Material, Shape: Enum.PartType? } } = {
		Flashlight = { Size = Vector3.new(2, 0.8, 0.8), Color = Color3.fromRGB(190, 160, 40), Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder },
		NightVision = { Size = Vector3.new(1.6, 1.1, 1), Color = Color3.fromRGB(30, 32, 30), Material = Enum.Material.Plastic },
		Tracker = { Size = Vector3.new(1, 1.4, 0.5), Color = Color3.fromRGB(70, 90, 70), Material = Enum.Material.Metal },
		Stamina = { Size = Vector3.new(1.1, 1, 1.8), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Leather },
		SecondWind = { Size = Vector3.new(0.9, 1.3, 0.9), Color = Color3.fromRGB(170, 40, 40), Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder },
		Veteran = { Size = Vector3.new(1.4, 0.2, 1), Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal },
	}
	for i, key in keys do
		local z = -53 + (i - 1) * 4.8
		local shape = shapes[key]
		local display = Build.block(cabin, "Supply_" .. key, shape.Size, CFrame.new(shelfX, 3.35 + shape.Size.Y / 2, z), shape.Color, shape.Material, { CanCollide = false, Shape = shape.Shape })
		local card = Build.block(cabin, "Card_" .. key, Vector3.new(0.1, 1.5, 3.6), CFrame.new(shelfX + 1.35, 2.3, z), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
		local pass = Config.Passes[key]
		local label = Build.sign(card, Enum.NormalId.Right, pass.Name, Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink, LightInfluence = 0.8, PixelsPerStud = 50 })
		local prompt = Build.prompt(display, pass.Name, "Look", 0.3, 8)
		prompt:SetAttribute("Pass", key)
		table.insert(lobby.ShopItems, { Key = key, Prompt = prompt, Card = label })
	end
	-- the thing it left for the ranger
	Facility.buildSkull(cabin, CFrame.new(X1 + 0.9, 8.6, -30) * CFrame.Angles(0, math.rad(-90), 0), 1)

	-- east wall: the board and the desk
	local board = Build.block(cabin, "Board", Vector3.new(0.3, 7, 12), CFrame.new(X2 - 0.2, 6, -46), Color3.fromRGB(96, 74, 50), Enum.Material.Fabric)
	lobby.BoardLabel = Build.sign(board, Enum.NormalId.Left, "CREWS WHO CAME BACK UP\n\n— no records yet —", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink, LightInfluence = 0.9, PixelsPerStud = 44, TextScaled = false, TextSize = 26, YAlign = Enum.TextYAlignment.Top })
	local rules = Build.block(cabin, "Rules", Vector3.new(0.1, 4.6, 5), CFrame.new(X2 - 0.1, 6, -33), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
	Build.sign(rules, Enum.NormalId.Left, "NIGHT SHIFT RULES\n1. Walk. She comes to noise.\n2. Close doors behind you.\n3. In a locker, hold your breath.\n4. Count your crew. Then count again.", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink, LightInfluence = 0.9, PixelsPerStud = 44, XAlign = Enum.TextXAlignment.Left })
	local desk = Build.block(cabin, "Desk", Vector3.new(4, 3.2, 9), CFrame.new(X2 - 3, 1.9, -33), WOOD_DARK, Enum.Material.Wood)
	local tv = Build.block(cabin, "Television", Vector3.new(3, 2.8, 3.4), desk.CFrame * CFrame.new(0.2, 3, -2), Color3.fromRGB(60, 56, 50), Enum.Material.Plastic)
	local tvScreen = Build.block(cabin, "TvScreen", Vector3.new(0.1, 2.2, 2.8), tv.CFrame * CFrame.new(-1.52, 0, 0), Color3.fromRGB(8, 14, 12), Enum.Material.Glass, { CanCollide = false })
	Build.sign(tvScreen, Enum.NormalId.Left, "PLEASE STAND BY", Config.Fonts.Osd, { TextColor = Config.Colors.Osd, LightInfluence = 0, Brightness = 1.5, Background = Color3.fromRGB(10, 20, 30), BackgroundTransparency = 0 })
	Build.pointLight(tvScreen, Color3.fromRGB(120, 150, 190), 0.8, 14)
	CollectionService:AddTag(tvScreen, "HS_Candle")
	local set = Build.block(cabin, "RadioSet", Vector3.new(2.2, 1.6, 3), desk.CFrame * CFrame.new(0, 2.4, 2.4), Color3.fromRGB(52, 60, 52), Enum.Material.Metal)
	set:SetAttribute("MusicSource", true)

	-- the siren on the porch: scares everyone on the server
	local sirenPost = Build.block(cabin, "SirenPost", Vector3.new(0.6, 6, 0.6), CFrame.new(9, 3, Z2 + 7.4), STEEL, Enum.Material.Metal)
	local siren = Build.block(cabin, "Siren", Vector3.new(2, 2, 2.6), sirenPost.CFrame * CFrame.new(0, 3.6, 0), Color3.fromRGB(150, 30, 26), Enum.Material.Metal)
	local sirenTag = Build.block(cabin, "SirenTag", Vector3.new(2.6, 1.2, 0.1), sirenPost.CFrame * CFrame.new(0, 1.2, 0.36), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
	Build.sign(sirenTag, Enum.NormalId.Back, "DO NOT CRANK.\nit answers.", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink })
	lobby.SirenPart = siren
	lobby.SirenPrompt = Build.prompt(siren, Config.Products.ScareAll.Name, "Crank the siren", 0.5, 8)
	lobby.SirenPrompt:SetAttribute("Product", "ScareAll")
end

function Lobby.build(parent: Instance): Lobby
	local folder = Build.folder(parent, "Lobby")
	local lobby: Lobby = {
		Folder = folder,
		PadCenter = Vector3.zero,
		PadSize = Vector3.one,
		CountdownLabel = nil :: any,
		ReturnCFrame = CFrame.lookAt(Vector3.new(4, 3.5, 58), Vector3.new(0, 3.5, -24)),
		ShopItems = {},
		SirenPrompt = nil :: any,
		SirenPart = nil :: any,
		BoardLabel = nil :: any,
		ElevatorSound = nil :: any,
	}
	buildForest(folder)
	buildCabin(folder, lobby)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Trailhead"
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 62), Vector3.new(0, 0.2, -24))
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
	return lobby
end

return Lobby
