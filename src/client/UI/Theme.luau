--!strict
--[[ Theme — fonts, colours and tiny typed constructors shared by all client UI. ]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local Theme = {}

Theme.Colors = Config.Colors
-- Three typefaces, each with one job:
--   Display  Creepster      event lines, titles, anything HUSH says
--   Body     Special Elite  a worn typewriter: objectives, messages, buttons, case files
--   Osd      Press Start 2P tiny camcorder tags (REC, timecode, key caps)
local display = Font.new(Config.Fonts.Display)
local body = Font.new(Config.Fonts.Body)
Theme.Fonts = {
	Display = display,
	Body = body,
	Osd = Font.new(Config.Fonts.Osd),
	Scrawl = Font.new(Config.Fonts.Scrawl),
	-- older names used around the client
	Serif = display,
	Horror = display,
	Mono = body,
	MonoBold = body,
	Typewriter = body,
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
	button.FontFace = Theme.Fonts.Body
	button.TextSize = 16
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

-- Scales a fixed-size panel down so it always fits the screen (never up).
function Theme.fit(object: GuiObject, designHeight: number, designWidth: number?)
	local scale = Instance.new("UIScale")
	scale.Parent = object
	local function update()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(designWidth or 1280, designHeight)
		local byWidth = if designWidth then size.X / designWidth else 1
		scale.Scale = math.clamp(math.min(size.Y / designHeight, byWidth), 0.4, 1)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		object.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end
end

-- One line of text that shrinks to fit its box instead of wrapping or spilling out of it.
function Theme.fitText(label: TextLabel | TextButton, maxSize: number)
	label.TextScaled = true
	label.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.MinTextSize = 6
	limit.Parent = label
end

-- Gives a ContextActionService touch button its title, size and slot on the grid.
function Theme.touchButton(action: string, title: string, slot: string)
	local spot = Layout.TouchButtons[slot]
	ContextActionService:SetTitle(action, title)
	ContextActionService:SetPosition(action, UDim2.new(1, -spot.OX, 1, -spot.OY))
	local button = ContextActionService:GetButton(action)
	if button and button:IsA("GuiObject") then
		(button :: GuiObject).Size = UDim2.fromOffset(Layout.TouchButtonSize, Layout.TouchButtonSize)
	end
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
