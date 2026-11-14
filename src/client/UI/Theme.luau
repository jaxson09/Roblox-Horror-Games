--!strict
--[[ Theme — fonts, colours and tiny typed constructors shared by all client UI. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = {}

Theme.Colors = Config.Colors
Theme.Fonts = {
	Osd = Font.new(Config.Fonts.Osd),
	Mono = Font.new(Config.Fonts.Mono, Enum.FontWeight.Medium),
	MonoBold = Font.new(Config.Fonts.Mono, Enum.FontWeight.Bold),
	Typewriter = Font.new(Config.Fonts.Typewriter),
	Scrawl = Font.new(Config.Fonts.Scrawl),
	Horror = Font.new(Config.Fonts.Horror),
	Sign = Font.new(Config.Fonts.Sign),
}

function Theme.screen(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = order
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Theme.frame(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function Theme.label(parent: Instance, name: string, size: UDim2, position: UDim2, font: Font, textSize: number, color: Color3, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	return label
end

function Theme.button(parent: Instance, name: string, size: UDim2, position: UDim2, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	button.BackgroundTransparency = 0.35
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.FontFace = Theme.Fonts.Osd
	button.TextSize = 12
	button.TextColor3 = Config.Colors.Osd
	button.Text = text
	button.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Colors.Osd
	stroke.Transparency = 0.5
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

-- Shrinks a fixed-size panel on short screens (phones) so nothing lands off-screen.
function Theme.fit(object: GuiObject, designHeight: number)
	local scale = Instance.new("UIScale")
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else designHeight
	scale.Scale = math.clamp(height / designHeight, 0.45, 1)
	scale.Parent = object
end

-- Numeric attribute with a default (attributes are untyped).
function Theme.num(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else default
end

-- Types text into a label one character at a time. Returns a cancel function.
function Theme.typewrite(label: TextLabel, text: string, perSecond: number, onTick: (() -> ())?): () -> ()
	local cancelled = false
	label.Text = text
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(text) or #text
		for i = 1, total do
			if cancelled or not label.Parent then
				return
			end
			label.MaxVisibleGraphemes = i
			local tick = onTick
			if tick and i % 2 == 0 then
				tick()
			end
			task.wait(1 / perSecond)
		end
		label.MaxVisibleGraphemes = -1
	end)
	return function()
		cancelled = true
		label.MaxVisibleGraphemes = -1
	end
end

return Theme
