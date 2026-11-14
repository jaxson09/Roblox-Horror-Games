--!strict
--[[
	Prompts — custom look for every ProximityPrompt (camcorder OSD style).
	Prompts that open a Robux purchase are tinted and carry a small
	"ROBUX PURCHASE" tag so it is always clear before the Roblox dialog opens.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)

local Prompts = {}

local player = Players.LocalPlayer
local C = Config.Colors
local shown: { [ProximityPrompt]: () -> () } = {}

local function keyText(inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return "X"
	end
	return "E"
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or shown[prompt] then
		return
	end
	local purchase = prompt:GetAttribute("Product") ~= nil or prompt:GetAttribute("Pass") ~= nil

	local gui = Instance.new("BillboardGui")
	gui.Name = "HS_Prompt"
	gui.Adornee = prompt.Parent :: Instance
	gui.Size = UDim2.fromOffset(300, 70)
	gui.AlwaysOnTop = true
	gui.Active = true
	gui.ResetOnSpawn = false
	gui.StudsOffset = Vector3.new(0, 0.6, 0)
	gui.Parent = player:WaitForChild("PlayerGui")

	local key = Theme.frame(gui, "Key", UDim2.fromOffset(34, 34), UDim2.fromOffset(0, 10), Color3.new(0, 0, 0), 0.35)
	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = C.Osd
	keyStroke.Parent = key
	local keyLabel = Theme.label(key, "K", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Fonts.Osd, if inputType == Enum.ProximityPromptInputType.Touch then 8 else 14, C.Osd, keyText(inputType))
	keyLabel.TextXAlignment = Enum.TextXAlignment.Center
	keyLabel.TextYAlignment = Enum.TextYAlignment.Center
	local fill = Theme.frame(key, "Fill", UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), C.Osd, 0.55)
	fill.AnchorPoint = Vector2.new(0, 1)

	-- both lines are fitted to their rows, so a long action can never run into the tag below
	local object = Theme.label(gui, "Object", UDim2.new(1, -44, 0, 16), UDim2.fromOffset(44, 8), Theme.Fonts.Mono, 13, C.Amber, "")
	object.TextYAlignment = Enum.TextYAlignment.Center
	Theme.fitText(object, 13)
	local action = Theme.label(gui, "Action", UDim2.new(1, -44, 0, 20), UDim2.fromOffset(44, 24), Theme.Fonts.MonoBold, 16, if purchase then C.Robux else C.Osd, "")
	action.TextYAlignment = Enum.TextYAlignment.Center
	Theme.fitText(action, 16)
	if purchase then
		Theme.label(gui, "Tag", UDim2.new(1, -44, 0, 12), UDim2.fromOffset(44, 46), Theme.Fonts.Osd, 7, C.Robux, "ROBUX PURCHASE")
	end
	local function refresh()
		object.Text = string.upper(prompt.ObjectText)
		action.Text = prompt.ActionText
	end
	refresh()

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(refresh))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(refresh))
	local holdTween: Tween? = nil
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		fill.Size = UDim2.fromScale(1, 0)
		holdTween = TweenService:Create(fill, TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		if holdTween then
			holdTween:Play()
		end
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		fill.Size = UDim2.fromScale(1, 0)
	end))

	-- tap / click support
	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = gui
	table.insert(connections, button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end))
	table.insert(connections, button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end))

	shown[prompt] = function()
		for _, connection in connections do
			connection:Disconnect()
		end
		gui:Destroy()
	end
end

function Prompts.init()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local cleanup = shown[prompt]
		if cleanup then
			shown[prompt] = nil
			cleanup()
		end
	end)
	-- keep touch users from needing the default prompt UI
	if UserInputService.TouchEnabled then
		ProximityPromptService.MaxPromptsVisible = 2
	end
end

return Prompts
