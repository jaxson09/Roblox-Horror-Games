--!strict
--[[
	Vhs — the camcorder layer over everything: scanlines, vignette, a rolling
	tracking bar, static that thickens as HUSH's carrier signal gets closer,
	and the fade-to-black used by cuts. Built from plain frames, so it needs no
	image assets (set Config.Images.Noise to use a real noise texture instead).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local Vhs = {}

Vhs.ReducedFlashing = false

local COLS, ROWS = 16, 9
local blocks: { Frame } = {}
local noiseImage: ImageLabel? = nil
local staticLayer: Frame
local fadeFrame: Frame
local flashFrame: Frame
local captionLabel: TextLabel
local redFrame: Frame
local trackBar: Frame
local baseStatic = 0
local burstAmount = 0
local burstUntil = 0
local rng = Random.new()

local function gradientFrame(parent: Instance, name: string, size: UDim2, position: UDim2, rotation: number, color: Color3, edge: number): Frame
	local frame = Theme.frame(parent, name, size, position, color, 0)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, edge),
		NumberSequenceKeypoint.new(0.6, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	return frame
end

function Vhs.init()
	local gui = Theme.screen("HS_VHS", 40)
	local black = Color3.new(0, 0, 0)

	-- vignette: four soft edges
	gradientFrame(gui, "VignetteTop", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90, black, 0.25)
	gradientFrame(gui, "VignetteBottom", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), 270, black, 0.25)
	gradientFrame(gui, "VignetteLeft", UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0, black, 0.3)
	gradientFrame(gui, "VignetteRight", UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180, black, 0.3)

	-- red pulse at the edges while hunted
	redFrame = Theme.frame(gui, "Dread", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Config.Colors.Dread, 1)
	local redGradient = Instance.new("UIGradient")
	redGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	redGradient.Parent = redFrame

	-- scanlines
	local lines = Theme.frame(gui, "Scanlines", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), black, 1)
	local count = 120
	for i = 0, count - 1 do
		Theme.frame(lines, "L", UDim2.new(1, 0, 0.35 / count, 0), UDim2.fromScale(0, i / count), black, 0.84)
	end

	-- tracking bar: a pale band that rolls down the picture now and then
	trackBar = Theme.frame(gui, "Tracking", UDim2.fromScale(1, 0.05), UDim2.fromScale(0, -0.1), Color3.new(1, 1, 1), 0.93)

	-- static
	staticLayer = Theme.frame(gui, "Static", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), black, 1)
	staticLayer.Visible = false
	if Config.Images.Noise ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Noise"
		image.Size = UDim2.fromScale(1.2, 1.2)
		image.BackgroundTransparency = 1
		image.Image = Config.Images.Noise
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(256, 256)
		image.Parent = staticLayer
		noiseImage = image
	else
		for y = 0, ROWS - 1 do
			for x = 0, COLS - 1 do
				table.insert(blocks, Theme.frame(staticLayer, "B", UDim2.fromScale(1 / COLS, 1 / ROWS), UDim2.fromScale(x / COLS, y / ROWS), Color3.new(1, 1, 1), 1))
			end
		end
	end

	local fadeGui = Theme.screen("HS_Fade", 80)
	fadeFrame = Theme.frame(fadeGui, "Fade", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), black, 1)
	flashFrame = Theme.frame(fadeGui, "Flash", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), 1)
	-- one line of text on the black screen itself (lift rides, teleports), low and centred
	captionLabel = Theme.label(fadeGui, "Caption", UDim2.new(0.7, 0, 0, 28), UDim2.new(0.15, 0, 0.82, 0), Theme.Fonts.Body, 18, Color3.fromRGB(190, 190, 182), "")
	captionLabel.TextXAlignment = Enum.TextXAlignment.Center
	captionLabel.TextYAlignment = Enum.TextYAlignment.Center
	Theme.fitText(captionLabel, 18)
	captionLabel.Visible = false

	local acc = 0
	local nextRoll = os.clock() + 6
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local amount = baseStatic
		if now < burstUntil then
			amount = math.max(amount, burstAmount)
		end
		if Vhs.ReducedFlashing then
			amount = math.min(amount, 0.25)
		end
		staticLayer.Visible = amount > 0.02
		acc += dt
		if amount > 0.02 and acc > 1 / 18 then
			acc = 0
			if noiseImage then
				noiseImage.ImageTransparency = 1 - amount
				noiseImage.Position = UDim2.fromOffset(-rng:NextInteger(0, 200), -rng:NextInteger(0, 200))
			else
				for _, block in blocks do
					local roll = rng:NextNumber()
					block.BackgroundTransparency = if roll < amount then 1 - amount * rng:NextNumber(0.25, 0.9) else 1
					local shade = rng:NextNumber(0.35, 1)
					block.BackgroundColor3 = Color3.new(shade, shade, shade)
				end
			end
		end
		if now > nextRoll then
			nextRoll = now + rng:NextNumber(5, 14)
			trackBar.Position = UDim2.fromScale(0, -0.1)
			TweenService:Create(trackBar, TweenInfo.new(rng:NextNumber(1.2, 2.4), Enum.EasingStyle.Linear), { Position = UDim2.fromScale(0, 1.1) }):Play()
		end
	end)
end

-- Steady static level (0..1), e.g. from HUSH's proximity.
function Vhs.setStatic(amount: number)
	baseStatic = math.clamp(amount, 0, 1)
end

-- A short spike of static on top of the steady level.
function Vhs.burst(amount: number, seconds: number)
	burstAmount = amount
	burstUntil = os.clock() + seconds
end

function Vhs.setDread(amount: number)
	redFrame.BackgroundTransparency = 1 - math.clamp(amount, 0, 1) * 0.5
end

-- Text shown on the black screen so a dark wait is never just a dark wait. nil clears it.
function Vhs.caption(text: string?)
	captionLabel.Text = text or ""
	captionLabel.Visible = text ~= nil
end

function Vhs.fade(toBlack: boolean, seconds: number)
	TweenService:Create(fadeFrame, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { BackgroundTransparency = if toBlack then 0 else 1 }):Play()
end

-- Camera flash: the screen whites out and comes back.
function Vhs.flash(seconds: number)
	flashFrame.BackgroundTransparency = if Vhs.ReducedFlashing then 0.7 else 0.05
	TweenService:Create(flashFrame, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

function Vhs.cut(toBlack: boolean)
	fadeFrame.BackgroundTransparency = if toBlack then 0 else 1
end

return Vhs
