--!strict
--[[
	Lobby — the surface level of Marrow Creek Relay: a long, half-lit intake
	hall. Everyone loads in at the sealed entrance and walks the length of it.
	At the far end, in front of four freight elevator doors, are the circles
	where crews form (see Services/Parties). The supply shelf is on the left
	wall partway down: you pass it, it does not jump at you.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Build = require(script.Parent.Build)
local Facility = require(script.Parent.Facility)

local Lobby = {}

export type ShopItem = { Key: string, Prompt: ProximityPrompt, Card: TextLabel }
export type PadSpec = { Disc: BasePart, Center: Vector3, Radius: number, Label: TextLabel }
export type Lobby = {
	Folder: Folder,
	Pads: { PadSpec },
	ReturnCFrame: CFrame,
	ShopItems: { ShopItem },
	SirenPrompt: ProximityPrompt,
	BoardLabel: TextLabel,
	ElevatorSound: Sound,
}

-- interior bounds
local X1, X2 = -32, 32
local Z_FAR, Z_NEAR = -76, 56 -- elevators at the far end, entrance at the near end
local H = 18

local CONCRETE = Color3.fromRGB(58, 60, 58)
local PAINT = Color3.fromRGB(52, 66, 60) -- institutional green, lower half of the walls
local DARK = Color3.fromRGB(26, 28, 28)
local STEEL = Color3.fromRGB(70, 74, 76)
local WOOD = Color3.fromRGB(64, 48, 36)
local HAZARD = Color3.fromRGB(196, 150, 28)
local LAMP = Color3.fromRGB(226, 220, 190)
local RED = Color3.fromRGB(255, 40, 30)

local function buildShell(hall: Folder)
	local w, l = X2 - X1, Z_NEAR - Z_FAR
	local midZ = (Z_NEAR + Z_FAR) / 2
	Build.block(hall, "Floor", Vector3.new(w + 4, 2, l + 4), CFrame.new(0, -1, midZ), Color3.fromRGB(70, 72, 68), Enum.Material.CeramicTiles)
	Build.block(hall, "Ceiling", Vector3.new(w + 4, 2, l + 4), CFrame.new(0, H + 1, midZ), DARK, Enum.Material.Concrete)
	-- a worn runner down the middle leads the eye to the elevators
	Build.block(hall, "Runner", Vector3.new(10, 0.1, l - 30), CFrame.new(0, 0.05, midZ + 6), Color3.fromRGB(64, 34, 30), Enum.Material.Carpet, { CanCollide = false })
	for _, side in { -1, 1 } do
		local x = side * (w / 2 + 1)
		Build.block(hall, "Wall", Vector3.new(2, H, l + 4), CFrame.new(x, H / 2, midZ), CONCRETE, Enum.Material.Concrete)
		Build.block(hall, "WallPaint", Vector3.new(0.2, 6, l), CFrame.new(side * (w / 2 - 0.05), 3, midZ), PAINT, Enum.Material.Plaster, { CanCollide = false, CastShadow = false })
	end
	Build.block(hall, "WallFar", Vector3.new(w + 4, H, 2), CFrame.new(0, H / 2, Z_FAR - 1), CONCRETE, Enum.Material.Concrete)
	Build.block(hall, "WallNear", Vector3.new(w + 4, H, 2), CFrame.new(0, H / 2, Z_NEAR + 1), CONCRETE, Enum.Material.Concrete)

	-- pillars, with a dying strip light between each pair
	for z = 36, -36, -24 do
		for _, side in { -1, 1 } do
			Build.block(hall, "Pillar", Vector3.new(3, H, 3), CFrame.new(side * 15, H / 2, z), CONCRETE, Enum.Material.Concrete)
			Build.block(hall, "Bench", Vector3.new(2.4, 1.6, 9), CFrame.new(side * 20, 0.8, z + 12), WOOD, Enum.Material.WoodPlanks)
		end
		local lamp = Build.block(hall, "Lamp", Vector3.new(8, 0.3, 1.2), CFrame.new(0, H - 0.2, z + 12), LAMP, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
		Build.pointLight(lamp, LAMP, 0.9, 34, z == 12)
		lamp:SetAttribute("Lit", true)
		CollectionService:AddTag(lamp, "HS_Flicker")
	end
	Build.block(hall, "Pipe", Vector3.new(l, 1, 1), CFrame.new(-26, H - 1.4, midZ) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(92, 58, 40), Enum.Material.CorrodedMetal, { CanCollide = false, Shape = Enum.PartType.Cylinder })

	-- the way in, sealed behind you
	local door = Build.block(hall, "EntranceDoors", Vector3.new(14, 12, 0.6), CFrame.new(0, 6, Z_NEAR - 0.3), DARK, Enum.Material.Metal)
	Build.block(hall, "EntranceChain", Vector3.new(15, 0.5, 0.3), door.CFrame * CFrame.new(0, -0.5, -0.5) * CFrame.Angles(0, 0, math.rad(12)), STEEL, Enum.Material.CorrodedMetal, { CanCollide = false })
	local exit = Build.block(hall, "ExitSign", Vector3.new(5, 1.6, 0.3), CFrame.new(0, 13.4, Z_NEAR - 0.4), Color3.fromRGB(12, 30, 16), Enum.Material.Metal, { CanCollide = false })
	Build.sign(exit, Enum.NormalId.Front, "NO EXIT", Config.Fonts.Sign, { TextColor = Color3.fromRGB(140, 255, 160), LightInfluence = 0, Brightness = 1.2 })
	Build.pointLight(exit, Color3.fromRGB(120, 255, 150), 0.5, 16)
	local scrawl = Build.block(hall, "Scrawl", Vector3.new(0.2, 3, 16), CFrame.new(X2 - 0.2, 10.5, 34), CONCRETE, Enum.Material.Concrete, { Transparency = 1, CanCollide = false })
	Build.sign(scrawl, Enum.NormalId.Left, "IT KNOWS YOUR NAME", Config.Fonts.Scrawl, { TextColor = Color3.fromRGB(130, 18, 18) })
end

local function buildElevators(hall: Folder, lobby: Lobby)
	local count = Config.Lobby.PadCount
	local spacing = (X2 - X1) / count
	local header = Build.block(hall, "AccessSign", Vector3.new(44, 2.4, 0.3), CFrame.new(0, 15.6, Z_FAR + 0.4), Color3.fromRGB(14, 14, 14), Enum.Material.Metal, { CanCollide = false })
	Build.sign(header, Enum.NormalId.Back, "SUBLEVEL ACCESS  —  FORM YOUR CREW IN A CIRCLE", Config.Fonts.Sign, { TextColor = Config.Colors.Amber, LightInfluence = 0, Brightness = 1.3 })
	for i = 1, count do
		local x = X1 + spacing * (i - 0.5)
		-- freight elevator door set into the far wall
		Build.block(hall, "ElevatorFrame", Vector3.new(11, 13, 0.6), CFrame.new(x, 6.5, Z_FAR + 0.3), HAZARD, Enum.Material.Metal)
		local doors = Build.block(hall, "ElevatorDoors", Vector3.new(9.4, 12, 0.4), CFrame.new(x, 6, Z_FAR + 0.7), Color3.fromRGB(44, 46, 50), Enum.Material.DiamondPlate)
		Build.block(hall, "ElevatorSeam", Vector3.new(0.2, 12, 0.1), doors.CFrame * CFrame.new(0, 0, 0.25), DARK, Enum.Material.Metal, { CanCollide = false })
		local plate = Build.block(hall, "ElevatorNumber", Vector3.new(5, 1.4, 0.2), CFrame.new(x, 13.9, Z_FAR + 0.7), Color3.fromRGB(14, 14, 14), Enum.Material.Metal, { CanCollide = false })
		Build.sign(plate, Enum.NormalId.Back, string.format("FREIGHT %02d", i), Config.Fonts.Mono, { TextColor = Config.Colors.Amber, LightInfluence = 0, Brightness = 1.3 })
		local beacon = Build.block(hall, "ElevatorBeacon", Vector3.new(0.9, 0.6, 0.9), CFrame.new(x, 15, Z_FAR + 1.2), RED, Enum.Material.Neon, { CanCollide = false })
		Build.pointLight(beacon, RED, 1, 20)
		CollectionService:AddTag(beacon, "HS_Beacon")

		-- the circle: a glowing ring on the floor in front of the door
		local radius = 6
		local center = Vector3.new(x, 0, Z_FAR + 12)
		local disc = Build.block(hall, "Pad" .. i, Vector3.new(0.3, radius * 2, radius * 2), CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Config.Colors.Amber, Enum.Material.Neon, { CanCollide = false, Transparency = 0.55, Shape = Enum.PartType.Cylinder, CastShadow = false })
		Build.block(hall, "PadCore", Vector3.new(0.32, radius * 2 - 1.2, radius * 2 - 1.2), disc.CFrame, Color3.fromRGB(30, 26, 18), Enum.Material.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder, CastShadow = false })
		Build.pointLight(disc, Config.Colors.Amber, 0.8, 14)

		local gui = Instance.new("BillboardGui")
		gui.Name = "PadSign"
		gui.Size = UDim2.fromScale(11, 4)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
		gui.MaxDistance = 140
		gui.LightInfluence = 0
		gui.Parent = disc
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.new(Config.Fonts.Mono, Enum.FontWeight.Bold)
		label.TextColor3 = Config.Colors.Amber
		label.TextStrokeTransparency = 0.3
		label.TextScaled = true
		label.Text = ""
		label.Parent = gui
		local spec: PadSpec = { Disc = disc, Center = center, Radius = radius, Label = label }
		table.insert(lobby.Pads, spec)
	end
	local rumble = Build.block(hall, "ElevatorRumble", Vector3.new(1, 1, 1), CFrame.new(0, 6, Z_FAR + 4), STEEL, Enum.Material.Metal, { Transparency = 1, CanCollide = false })
	lobby.ElevatorSound = Sfx.make(rumble, "Elevator", { Volume = 1, MaxDistance = 160 })
end

local function buildSupply(hall: Folder, lobby: Lobby)
	-- left wall, a third of the way down
	local shelfX = X1 + 1.6
	local z0 = 26
	Build.block(hall, "ShelfBack", Vector3.new(0.4, 9, 30), CFrame.new(X1 + 0.3, 5, z0 - 12), WOOD, Enum.Material.WoodPlanks)
	for _, y in { 3.2, 6.4 } do
		Build.block(hall, "Shelf", Vector3.new(2.6, 0.3, 30), CFrame.new(shelfX, y, z0 - 12), WOOD, Enum.Material.WoodPlanks)
	end
	local sign = Build.block(hall, "SupplySign", Vector3.new(0.2, 1.6, 10), CFrame.new(X1 + 0.7, 10.6, z0 - 12), Color3.fromRGB(14, 14, 14), Enum.Material.Metal, { CanCollide = false })
	Build.sign(sign, Enum.NormalId.Right, "SUPPLY", Config.Fonts.Sign, { TextColor = Config.Colors.Amber, LightInfluence = 0, Brightness = 1.2 })
	Build.pointLight(sign, Config.Colors.Amber, 0.5, 14)
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
		local z = z0 - (i - 1) * 4.8
		local shape = shapes[key]
		local display = Build.block(hall, "Supply_" .. key, shape.Size, CFrame.new(shelfX, 3.35 + shape.Size.Y / 2, z), shape.Color, shape.Material, { CanCollide = false, Shape = shape.Shape })
		local card = Build.block(hall, "Card_" .. key, Vector3.new(0.1, 1.5, 3.6), CFrame.new(shelfX + 1.35, 2.3, z), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
		local pass = Config.Passes[key]
		local label = Build.sign(card, Enum.NormalId.Right, pass.Name, Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink, LightInfluence = 0.8, PixelsPerStud = 50 })
		local prompt = Build.prompt(display, pass.Name, "Look", 0.3, 8)
		prompt:SetAttribute("Pass", key)
		table.insert(lobby.ShopItems, { Key = key, Prompt = prompt, Card = label })
	end
	-- what it left for the last ranger
	Facility.buildSkull(hall, CFrame.new(X1 + 0.9, 9, z0 - 32) * CFrame.Angles(0, math.rad(-90), 0), 1.1)
end

local function buildOffice(hall: Folder, lobby: Lobby)
	-- right wall: the board of crews who came back, the rules, the duty desk
	local board = Build.block(hall, "Board", Vector3.new(0.3, 7, 12), CFrame.new(X2 - 0.2, 6, 2), Color3.fromRGB(96, 74, 50), Enum.Material.Fabric)
	lobby.BoardLabel = Build.sign(board, Enum.NormalId.Left, "CREWS WHO CAME BACK UP\n\n— no records yet —", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink, LightInfluence = 0.9, PixelsPerStud = 44, TextScaled = false, TextSize = 26, YAlign = Enum.TextYAlignment.Top })
	local rules = Build.block(hall, "Rules", Vector3.new(0.1, 4.6, 5), CFrame.new(X2 - 0.1, 6, 14), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
	Build.sign(rules, Enum.NormalId.Left, "NIGHT SHIFT RULES\n1. Walk. She comes to noise.\n2. Close doors behind you.\n3. In a locker, hold your breath.\n4. Count your crew. Then count again.", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink, LightInfluence = 0.9, PixelsPerStud = 44, XAlign = Enum.TextXAlignment.Left })
	local desk = Build.block(hall, "Desk", Vector3.new(4, 3.2, 10), CFrame.new(X2 - 3, 1.6, 24), WOOD, Enum.Material.Wood)
	local tv = Build.block(hall, "Television", Vector3.new(3, 2.8, 3.4), desk.CFrame * CFrame.new(0.2, 3, -2.4), Color3.fromRGB(60, 56, 50), Enum.Material.Plastic)
	local screen = Build.block(hall, "TvScreen", Vector3.new(0.1, 2.2, 2.8), tv.CFrame * CFrame.new(-1.52, 0, 0), Color3.fromRGB(8, 14, 12), Enum.Material.Glass, { CanCollide = false })
	Build.sign(screen, Enum.NormalId.Left, "PLEASE STAND BY", Config.Fonts.Osd, { TextColor = Config.Colors.Osd, LightInfluence = 0, Brightness = 1.5, Background = Color3.fromRGB(10, 20, 30), BackgroundTransparency = 0 })
	Build.pointLight(screen, Color3.fromRGB(120, 150, 190), 0.9, 16)
	CollectionService:AddTag(screen, "HS_Candle")
	-- the lobby theme plays out of this radio
	local set = Build.block(hall, "RadioSet", Vector3.new(2.2, 1.6, 3), desk.CFrame * CFrame.new(0, 2.4, 2.6), Color3.fromRGB(52, 60, 52), Enum.Material.Metal)
	set:SetAttribute("MusicSource", true)

	-- emergency broadcast handle on the nearest pillar: scares everyone on the server
	local box = Build.block(hall, "Siren", Vector3.new(2.2, 2.6, 1), CFrame.new(15, 5, 37.9), Color3.fromRGB(150, 30, 26), Enum.Material.Metal)
	local tag = Build.block(hall, "SirenTag", Vector3.new(2.6, 1.2, 0.1), box.CFrame * CFrame.new(0, -2.2, 0.5), Config.Colors.Paper, Enum.Material.SmoothPlastic, { CanCollide = false })
	Build.sign(tag, Enum.NormalId.Back, "DO NOT CRANK.\nit answers.", Config.Fonts.Typewriter, { TextColor = Config.Colors.Ink })
	lobby.SirenPrompt = Build.prompt(box, Config.Products.ScareAll.Name, "Crank the siren", 0.5, 8)
	lobby.SirenPrompt:SetAttribute("Product", "ScareAll")
end

function Lobby.build(parent: Instance): Lobby
	local folder = Build.folder(parent, "Lobby")
	local hall = Build.folder(folder, "Hall")
	local lobby: Lobby = {
		Folder = folder,
		Pads = {},
		ReturnCFrame = CFrame.lookAt(Vector3.new(0, 3.5, Z_NEAR - 14), Vector3.new(0, 3.5, Z_FAR)),
		ShopItems = {},
		SirenPrompt = nil :: any,
		BoardLabel = nil :: any,
		ElevatorSound = nil :: any,
	}
	buildShell(hall)
	buildElevators(hall, lobby)
	buildSupply(hall, lobby)
	buildOffice(hall, lobby)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Entrance"
	spawn.Size = Vector3.new(14, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, Z_NEAR - 8), Vector3.new(0, 0.2, Z_FAR))
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
	return lobby
end

return Lobby
