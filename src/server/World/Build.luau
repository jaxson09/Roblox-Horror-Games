--!strict
--[[ Build — small typed helpers for constructing the world out of parts. ]]

local PhysicsService = game:GetService("PhysicsService")

local Build = {}

export type PartOpts = {
	Transparency: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Shape: Enum.PartType?,
	Reflectance: number?,
	Anchored: boolean?,
	Massless: boolean?,
	Group: string?,
}

Build.Groups = { Players = "HS_Players", Fawn = "HS_Fawn", Props = "HS_Props" }
local GROUP_NAMES = { "HS_Players", "HS_Fawn", "HS_Props" }

local groupsReady = false
function Build.setupCollisionGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	for _, name in GROUP_NAMES do
		PhysicsService:RegisterCollisionGroup(name)
	end
	PhysicsService:CollisionGroupSetCollidable(Build.Groups.Fawn, Build.Groups.Players, false)
	PhysicsService:CollisionGroupSetCollidable(Build.Groups.Fawn, Build.Groups.Props, false)
	PhysicsService:CollisionGroupSetCollidable(Build.Groups.Fawn, Build.Groups.Fawn, false)
	PhysicsService:CollisionGroupSetCollidable(Build.Groups.Players, Build.Groups.Players, false)
end

local function applyOpts(part: BasePart, opts: PartOpts?)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not opts then
		return
	end
	if opts.Transparency ~= nil then
		part.Transparency = opts.Transparency
	end
	if opts.CanCollide ~= nil then
		part.CanCollide = opts.CanCollide
	end
	if opts.CastShadow ~= nil then
		part.CastShadow = opts.CastShadow
	end
	if opts.Reflectance ~= nil then
		part.Reflectance = opts.Reflectance
	end
	if opts.Anchored ~= nil then
		part.Anchored = opts.Anchored
	end
	if opts.Massless ~= nil then
		part.Massless = opts.Massless
	end
	if opts.Group ~= nil then
		part.CollisionGroup = opts.Group
	end
end

function Build.block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, opts: PartOpts?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	if opts and opts.Shape then
		part.Shape = opts.Shape
	end
	applyOpts(part, opts)
	part.Parent = parent
	return part
end

function Build.wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, opts: PartOpts?): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	applyOpts(part, opts)
	part.Parent = parent
	return part
end

function Build.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.pointLight(parent: Instance, color: Color3, brightness: number, range: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

function Build.spotLight(parent: Instance, face: Enum.NormalId, color: Color3, brightness: number, range: number, angle: number, shadows: boolean?): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

function Build.prompt(parent: Instance, objectText: string, actionText: string, hold: number, distance: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = parent
	return prompt
end

export type SignOpts = {
	TextColor: Color3?,
	Background: Color3?,
	BackgroundTransparency: number?,
	PixelsPerStud: number?,
	LightInfluence: number?,
	Brightness: number?,
	TextScaled: boolean?,
	TextSize: number?,
	Wrapped: boolean?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Rich: boolean?,
}

-- Text on a part face. Returns the label so callers can update it.
function Build.sign(part: BasePart, face: Enum.NormalId, text: string, fontFamily: string, opts: SignOpts?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = if opts and opts.PixelsPerStud then opts.PixelsPerStud else 40
	gui.LightInfluence = if opts and opts.LightInfluence then opts.LightInfluence else 1
	gui.Brightness = if opts and opts.Brightness then opts.Brightness else 1
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = if opts and opts.Background then opts.Background else Color3.new(0, 0, 0)
	label.BackgroundTransparency = if opts and opts.BackgroundTransparency then opts.BackgroundTransparency else 1
	label.BorderSizePixel = 0
	label.FontFace = Font.new(fontFamily)
	label.Text = text
	label.TextColor3 = if opts and opts.TextColor then opts.TextColor else Color3.new(1, 1, 1)
	label.TextScaled = if opts and opts.TextScaled ~= nil then opts.TextScaled else true
	if opts and opts.TextSize then
		label.TextSize = opts.TextSize
	end
	label.TextWrapped = if opts and opts.Wrapped ~= nil then opts.Wrapped else true
	label.TextXAlignment = if opts and opts.XAlign then opts.XAlign else Enum.TextXAlignment.Center
	label.TextYAlignment = if opts and opts.YAlign then opts.YAlign else Enum.TextYAlignment.Center
	label.RichText = if opts and opts.Rich then true else false
	label.Parent = gui

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = label
	return label
end

function Build.weld(a: BasePart, b: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = b
	return weld
end

return Build
