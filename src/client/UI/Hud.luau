--!strict
--[[
	Hud — the camcorder on-screen display and every panel: objective, toasts,
	subtitles, reel transcripts, notes, locker/cage prompts, results, intro.
	Fonts: PressStart2P for OSD tags, Roboto Mono for readouts, Special Elite
	for anything typed on paper, Creepster exactly once (when it takes you).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Lore = require(ReplicatedStorage.Shared.Lore)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Theme = require(script.Parent.Theme)
local Vhs = require(script.Parent.Vhs)

local Hud = {}

local player = Players.LocalPlayer
local C = Config.Colors
local F = Theme.Fonts

Hud.Stamina = 1 -- written by Movement
Hud.TrackerAngle = nil :: number? -- written by FawnAnimator (radians, 0 = dead ahead)
Hud.TrackerStrength = 0
Hud.DazzleProgress = 0 -- written by Flashlight

local gui: ScreenGui
local shiftGroup: Frame
local objective: TextLabel
local recDot: Frame
local timecode: TextLabel
local location: TextLabel
local batteryFill: Frame
local noiseSegments: { Frame } = {}
local staminaFill: Frame
local toasts: Frame
local subtitle: TextLabel
local lockerPanel: Frame
local breathFill: Frame
local lockerHint: TextLabel
local cagePanel: Frame
local cageTimer: TextLabel
local struggleFill: Frame
local struggleHint: TextLabel
local trackerStrip: Frame
local trackerDot: Frame
local dazzleBar: Frame
local tapePanel: Frame
local tapeTitle: TextLabel
local tapeBody: TextLabel
local blip: Sound
local typeSound: Sound
local shiftJoinedAt = 0
local hiddenSince = 0
local holdingAction = false
local cancelTape: (() -> ())? = nil

local function send(name: string, value: any?)
	Remotes.ToServer:FireServer(name, value)
end

local function bar(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): Frame
	local back = Theme.frame(parent, name, size, position, Color3.new(0, 0, 0), 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.55
	stroke.Parent = back
	return Theme.frame(back, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 0.1)
end

----------------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------------
function Hud.toast(text: string, kind: string?)
	local color = if kind == "bad" then C.Rec elseif kind == "good" then C.Phosphor elseif kind == "store" then C.Robux else C.Osd
	local label = Theme.label(toasts, "Toast", UDim2.new(1, 0, 0, 22), UDim2.fromScale(0, 0), F.MonoBold, 15, color, text)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTransparency = 1
	blip:Play()
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(4.5, function()
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.9)
		label:Destroy()
	end)
end

local GLITCH = { "#", "%", "_", "/", "~", "=", "?" }

-- Spoken lines. `glitch` renders the mimic's voice: wrong, crawling characters.
function Hud.subtitle(text: string, glitch: boolean?)
	subtitle.Text = text
	subtitle.TextColor3 = if glitch then Color3.fromRGB(255, 120, 110) else C.Osd
	subtitle.FontFace = if glitch then F.Typewriter else F.Mono
	subtitle.Visible = true
	local stamp = os.clock()
	subtitle:SetAttribute("Stamp", stamp)
	if glitch then
		task.spawn(function()
			local rng = Random.new()
			while subtitle:GetAttribute("Stamp") == stamp and os.clock() - stamp < 5 do
				local chars = string.split(text, "")
				for _ = 1, 2 do
					chars[rng:NextInteger(1, #chars)] = GLITCH[rng:NextInteger(1, #GLITCH)]
				end
				subtitle.Text = table.concat(chars)
				task.wait(0.09)
				subtitle.Text = text
				task.wait(rng:NextNumber(0.1, 0.5))
			end
		end)
	end
	task.delay(5.2, function()
		if subtitle:GetAttribute("Stamp") == stamp then
			subtitle.Visible = false
		end
	end)
end

function Hud.showTape(index: number, title: string, body: string)
	if cancelTape then
		cancelTape()
	end
	tapePanel.Visible = true
	tapePanel.Position = UDim2.new(1, 20, 0.3, 0)
	TweenService:Create(tapePanel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -380, 0.3, 0) }):Play()
	tapeTitle.Text = `▶ {title}  [{index}/{Config.Shift.TapesNeeded}]`
	cancelTape = Theme.typewrite(tapeBody, body, 28, function()
		typeSound:Play()
	end)
	local stamp = os.clock()
	tapePanel:SetAttribute("Stamp", stamp)
	task.delay(#body / 28 + 7, function()
		if tapePanel:GetAttribute("Stamp") == stamp then
			TweenService:Create(tapePanel, TweenInfo.new(0.5), { Position = UDim2.new(1, 20, 0.3, 0) }):Play()
		end
	end)
end

function Hud.showNote(id: string)
	local note: Lore.Note? = nil
	for _, candidate in Lore.Notes do
		if candidate.Id == id then
			note = candidate
		end
	end
	if not note then
		return
	end
	local overlay = Theme.screen("HS_Note", 60)
	local paper = Theme.frame(overlay, "Paper", UDim2.fromOffset(420, 460), UDim2.fromScale(0.5, 0.5), C.Paper, 0)
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Rotation = -1.5
	Theme.fit(paper, 560)
	local title = Theme.label(paper, "Title", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 22), F.Typewriter, 22, C.Ink, note.Title)
	title.TextStrokeTransparency = 1
	local body = Theme.label(paper, "Body", UDim2.new(1, -40, 1, -130), UDim2.fromOffset(20, 76), F.Typewriter, 18, C.Ink, note.Body)
	body.TextStrokeTransparency = 1
	body.LineHeight = 1.25
	local close = Theme.button(paper, "Close", UDim2.fromOffset(200, 30), UDim2.new(0.5, -100, 1, -44), "PUT IT BACK [E]")
	close.Modal = true -- frees the cursor while the camera is locked in first person
	local opened = os.clock()
	local keyConnection: RBXScriptConnection? = nil
	local function dismiss()
		if keyConnection then
			keyConnection:Disconnect()
			keyConnection = nil
		end
		overlay:Destroy()
	end
	keyConnection = UserInputService.InputBegan:Connect(function(input)
		if os.clock() - opened > 0.5 and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB) then
			dismiss()
		end
	end)
	close.MouseButton1Click:Connect(dismiss)
	task.delay(25, dismiss)
end

function Hud.locationCard(title: string, sub: string)
	local overlay = Theme.screen("HS_Card", 85)
	local t = Theme.label(overlay, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.42, 0), F.Osd, 22, C.Osd, "")
	t.TextXAlignment = Enum.TextXAlignment.Center
	local s = Theme.label(overlay, "Sub", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.42, 48), F.Mono, 16, C.Amber, "")
	s.TextXAlignment = Enum.TextXAlignment.Center
	Theme.typewrite(t, title, 22, function()
		typeSound:Play()
	end)
	task.delay(#title / 22 + 0.3, function()
		Theme.typewrite(s, sub, 30)
	end)
	task.delay(6, function()
		TweenService:Create(t, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(1.1)
		overlay:Destroy()
	end)
end

export type Results = { Outcome: string, Seconds: number, Reels: number, Fuses: number, Rescues: number, Escapes: number }

function Hud.showResults(results: Results)
	local overlay = Theme.screen("HS_Results", 90)
	local back = Theme.frame(overlay, "Back", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	TweenService:Create(back, TweenInfo.new(1.2), { BackgroundTransparency = 0.25 }):Play()
	local escaped = results.Outcome == "Escaped"
	local ending = if escaped then Lore.Endings.Escaped elseif results.Outcome == "Lockdown" then Lore.Endings.Lockdown else Lore.Endings.Taken
	local panel = Theme.frame(overlay, "Panel", UDim2.fromOffset(900, 380), UDim2.fromScale(0.5, 0.5), Color3.new(0, 0, 0), 1)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.fit(panel, 520)
	local title = Theme.label(panel, "Title", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 0), if escaped then F.Osd else F.Horror, if escaped then 26 else 64, if escaped then C.Phosphor else C.Dread, ending[1])
	title.TextXAlignment = Enum.TextXAlignment.Center
	local line = Theme.label(panel, "Line", UDim2.new(0.8, 0, 0, 60), UDim2.new(0.1, 0, 0, 86), F.Typewriter, 20, C.Paper, "")
	line.TextXAlignment = Enum.TextXAlignment.Center
	Theme.typewrite(line, ending[2], 30)
	local minutes = results.Seconds // 60
	local stats = string.format("TIME BELOW   %02d:%02d\nREELS        %d\nFUSES        %d\nCREW FREED   %d\nESCAPES      %d", minutes, results.Seconds % 60, results.Reels, results.Fuses, results.Rescues, results.Escapes)
	local statLabel = Theme.label(panel, "Stats", UDim2.new(0, 320, 0, 130), UDim2.new(0.5, -160, 0, 170), F.Mono, 17, C.Osd, stats)
	statLabel.LineHeight = 1.2
	local close = Theme.button(panel, "Close", UDim2.fromOffset(200, 36), UDim2.new(0.5, -100, 0, 320), "CONTINUE")
	close.Modal = true
	local closed = false
	local function dismiss()
		if not closed then
			closed = true
			overlay:Destroy()
		end
	end
	close.MouseButton1Click:Connect(dismiss)
	task.delay(18, dismiss)
end

-- First-visit intro: photosensitivity notice, then the premise, typed.
function Hud.intro(first: boolean, onDone: () -> ())
	local overlay = Theme.screen("HS_Intro", 95)
	local back = Theme.frame(overlay, "Back", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0)
	local text = Theme.label(overlay, "Text", UDim2.new(0.7, 0, 0.5, 0), UDim2.new(0.15, 0, 0.3, 0), F.Typewriter, 22, C.Paper, "")
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.LineHeight = 1.3
	local skip = Theme.button(overlay, "Skip", UDim2.fromOffset(120, 30), UDim2.new(1, -150, 1, -60), "SKIP ▶▶")
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		TweenService:Create(back, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		skip.Visible = false
		task.delay(1.6, function()
			overlay:Destroy()
		end)
		onDone()
	end
	skip.MouseButton1Click:Connect(finish)
	task.spawn(function()
		if first then
			text.Text = "THIS EXPERIENCE CONTAINS FLASHING LIGHTS,\nLOUD SOUNDS AND JUMPSCARES.\n\nFlashing can be reduced with the FX button."
			task.wait(4)
			if finished then
				return
			end
			local body = table.concat(Lore.Intro, "\n")
			Theme.typewrite(text, body, 26, function()
				typeSound:Play()
			end)
			task.wait(#body / 26 + 3.5)
			if finished then
				return
			end
		end
		text.FontFace = F.Osd
		text.TextSize = 34
		text.TextColor3 = C.Osd
		text.Text = Config.GameName .. "\n\n"
		text.MaxVisibleGraphemes = -1
		local tag = Theme.label(overlay, "Tag", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.3, 70), F.Mono, 16, C.Rec, Config.Tagline)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		task.wait(2.6)
		tag:Destroy()
		finish()
	end)
end

----------------------------------------------------------------------------
-- Layout + update
----------------------------------------------------------------------------
local function objectiveText(): string
	local O = Lore.Objectives
	if not player:GetAttribute("InShift") then
		return O.Lobby
	end
	if player:GetAttribute("Caged") then
		local left = math.max(0, math.ceil(Theme.num(player, "CageEnds", 0) - workspace:GetServerTimeNow()))
		return string.format(O.Caged, left)
	end
	local phase = workspace:GetAttribute("HS_Phase")
	local fuses = Theme.num(workspace, "HS_Fuses", 0)
	local tapes = Theme.num(workspace, "HS_Tapes", 0)
	if phase == "Blackout" then
		return if fuses >= Config.Shift.FusesNeeded then O.BlackoutInstall else string.format(O.Blackout, fuses, Config.Shift.FusesNeeded)
	elseif phase == "Tapes" then
		return if tapes >= Config.Shift.TapesNeeded then O.TapesInsert else string.format(O.Tapes, tapes, Config.Shift.TapesNeeded)
	elseif phase == "Broadcast" then
		if workspace:GetAttribute("HS_Drift") then
			return O.BroadcastDrift
		elseif not workspace:GetAttribute("HS_ControlHeld") then
			return O.BroadcastEmpty
		end
		return string.format(O.Broadcast, Theme.num(workspace, "HS_Progress", 0))
	elseif phase == "Escape" then
		local left = math.max(0, math.ceil(Theme.num(workspace, "HS_EscapeEnds", 0) - workspace:GetServerTimeNow()))
		return string.format(O.Escape, string.format("%d:%02d", left // 60, left % 60))
	end
	return ""
end

local function build()
	gui = Theme.screen("HS_HUD", 30)
	blip = Sfx.make(gui, "Blip", { Volume = 0.35 })
	typeSound = Sfx.make(gui, "Type", { Volume = 0.25 })

	local strip = Theme.frame(gui, "ObjectiveStrip", UDim2.new(0.6, 0, 0, 30), UDim2.new(0.2, 0, 0, 46), Color3.new(0, 0, 0), 0.55)
	objective = Theme.label(strip, "Objective", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), F.MonoBold, 16, C.Osd, "")
	objective.TextXAlignment = Enum.TextXAlignment.Center
	objective.TextYAlignment = Enum.TextYAlignment.Center
	toasts = Theme.frame(gui, "Toasts", UDim2.new(0.7, 0, 0, 80), UDim2.new(0.15, 0, 0, 84), Color3.new(0, 0, 0), 1)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = toasts

	subtitle = Theme.label(gui, "Subtitle", UDim2.new(0.6, 0, 0, 56), UDim2.new(0.2, 0, 0.8, 0), F.Mono, 20, C.Osd, "")
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextStrokeTransparency = 0.2
	subtitle.Visible = false

	shiftGroup = Theme.frame(gui, "Shift", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	recDot = Theme.frame(shiftGroup, "RecDot", UDim2.fromOffset(12, 12), UDim2.new(0.965, -76, 0.07, 46), C.Rec, 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = recDot
	Theme.label(shiftGroup, "Rec", UDim2.fromOffset(56, 16), UDim2.new(0.965, -56, 0.07, 44), F.Osd, 14, C.Osd, "REC")
	timecode = Theme.label(shiftGroup, "Timecode", UDim2.fromOffset(200, 16), UDim2.new(0.965, -200, 0.07, 68), F.Osd, 12, C.Osd, "00:00:00")
	timecode.TextXAlignment = Enum.TextXAlignment.Right
	location = Theme.label(shiftGroup, "Location", UDim2.fromOffset(300, 18), UDim2.new(0.965, -300, 0.07, 90), F.Mono, 14, C.Amber, "")
	location.TextXAlignment = Enum.TextXAlignment.Right
	local sp = Theme.label(shiftGroup, "Sp", UDim2.fromOffset(120, 16), UDim2.new(0.965, -120, 0.07, 0), F.Osd, 14, C.Osd, "SP  BATT")
	sp.TextXAlignment = Enum.TextXAlignment.Right
	batteryFill = bar(shiftGroup, "Battery", UDim2.fromOffset(120, 10), UDim2.new(0.965, -120, 0.07, 24), C.Osd)

	Theme.label(shiftGroup, "NoiseTag", UDim2.fromOffset(80, 14), UDim2.new(0.035, 0, 0.9, -22), F.Osd, 10, C.Osd, "NOISE")
	for i = 1, 8 do
		table.insert(noiseSegments, Theme.frame(shiftGroup, "Noise" .. i, UDim2.fromOffset(12, 8 + i * 2), UDim2.new(0.035, (i - 1) * 16, 0.9, 18 - i * 2), C.Osd, 0.8))
	end
	staminaFill = bar(shiftGroup, "Stamina", UDim2.fromOffset(124, 5), UDim2.new(0.035, 0, 0.9, 32), C.Phosphor)

	trackerStrip = Theme.frame(shiftGroup, "Tracker", UDim2.fromOffset(180, 4), UDim2.new(0.5, -90, 0.93, 0), C.Osd, 0.7)
	trackerDot = Theme.frame(trackerStrip, "Dot", UDim2.fromOffset(8, 14), UDim2.new(0.5, -4, 0, -5), C.Rec, 0)
	local trackerTag = Theme.label(trackerStrip, "Tag", UDim2.fromOffset(180, 12), UDim2.fromOffset(0, 10), F.Osd, 8, C.Osd, "CARRIER SIGNAL")
	trackerTag.TextXAlignment = Enum.TextXAlignment.Center
	dazzleBar = bar(shiftGroup, "Dazzle", UDim2.fromOffset(90, 4), UDim2.new(0.5, -45, 0.56, 0), C.Amber)

	-- locker: hold your breath
	lockerPanel = Theme.frame(gui, "Locker", UDim2.fromOffset(360, 110), UDim2.new(0.5, -180, 0.62, 0), Color3.new(0, 0, 0), 0.5)
	lockerHint = Theme.label(lockerPanel, "Hint", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 8), F.MonoBold, 15, C.Osd, "")
	lockerHint.TextXAlignment = Enum.TextXAlignment.Center
	breathFill = bar(lockerPanel, "Breath", UDim2.new(1, -40, 0, 8), UDim2.fromOffset(20, 38), C.Phosphor)
	local breathButton = Theme.button(lockerPanel, "Hold", UDim2.fromOffset(160, 34), UDim2.fromOffset(14, 62), "HOLD BREATH")
	local exitButton = Theme.button(lockerPanel, "Exit", UDim2.fromOffset(160, 34), UDim2.fromOffset(186, 62), "GET OUT [E]")
	breathButton.MouseButton1Down:Connect(function()
		send("HoldBreath", true)
	end)
	breathButton.MouseButton1Up:Connect(function()
		send("HoldBreath", false)
	end)
	exitButton.MouseButton1Click:Connect(function()
		send("ExitLocker")
	end)

	-- cage: wait, struggle, or the key
	cagePanel = Theme.frame(gui, "Cage", UDim2.fromOffset(400, 120), UDim2.new(0.5, -200, 0.62, 0), Color3.new(0, 0, 0), 0.5)
	cageTimer = Theme.label(cagePanel, "Timer", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 8), F.MonoBold, 15, C.Rec, "")
	cageTimer.TextXAlignment = Enum.TextXAlignment.Center
	struggleFill = bar(cagePanel, "Struggle", UDim2.new(1, -40, 0, 8), UDim2.fromOffset(20, 38), C.Amber)
	struggleHint = Theme.label(cagePanel, "Hint", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 50), F.Mono, 13, C.Osd, "")
	struggleHint.TextXAlignment = Enum.TextXAlignment.Center
	local struggleButton = Theme.button(cagePanel, "Struggle", UDim2.fromOffset(200, 34), UDim2.new(0.5, -100, 0, 76), "FORCE THE BARS")
	struggleButton.MouseButton1Down:Connect(function()
		send("Struggle", true)
	end)
	struggleButton.MouseButton1Up:Connect(function()
		send("Struggle", false)
	end)

	-- reel transcript card
	tapePanel = Theme.frame(gui, "Tape", UDim2.fromOffset(360, 190), UDim2.new(1, 20, 0.3, 0), Color3.fromRGB(6, 12, 9), 0.2)
	tapePanel.Visible = false
	local tapeStroke = Instance.new("UIStroke")
	tapeStroke.Color = C.Phosphor
	tapeStroke.Transparency = 0.5
	tapeStroke.Parent = tapePanel
	tapeTitle = Theme.label(tapePanel, "Title", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 10), F.Osd, 10, C.Phosphor, "")
	tapeBody = Theme.label(tapePanel, "Body", UDim2.new(1, -24, 1, -44), UDim2.fromOffset(12, 36), F.Typewriter, 17, C.Paper, "")
	tapeBody.LineHeight = 1.15

	local fx = Theme.button(gui, "Fx", UDim2.fromOffset(110, 22), UDim2.new(0.965, -110, 1, -34), "FX: FULL")
	fx.TextSize = 9
	fx.MouseButton1Click:Connect(function()
		Vhs.ReducedFlashing = not Vhs.ReducedFlashing
		player:SetAttribute("ReducedFlashing", Vhs.ReducedFlashing)
		fx.Text = if Vhs.ReducedFlashing then "FX: REDUCED" else "FX: FULL"
	end)
end

local function setHold(on: boolean)
	if holdingAction == on then
		return
	end
	holdingAction = on
	if player:GetAttribute("Hidden") then
		send("HoldBreath", on)
	elseif player:GetAttribute("Caged") then
		send("Struggle", on)
	end
end

local function update()
	local inShift = player:GetAttribute("InShift") == true
	local hidden = player:GetAttribute("Hidden") == true
	local caged = player:GetAttribute("Caged") == true
	shiftGroup.Visible = inShift
	local objectiveStrip = objective.Parent :: Frame
	objective.Text = objectiveText()
	objectiveStrip.Visible = objective.Text ~= ""
	lockerPanel.Visible = inShift and hidden
	cagePanel.Visible = inShift and caged
	if not inShift then
		return
	end

	local t = os.clock() - shiftJoinedAt
	timecode.Text = string.format("%02d:%02d:%02d", t // 60, t % 60, (t * 30) % 30)
	recDot.Visible = (t % 1.2) < 0.7

	local camera = workspace.CurrentCamera
	if camera then
		local p = camera.CFrame.Position
		local origin = Config.World.FacilityOrigin
		local cx = math.floor((p.X - origin.X) / Config.World.CellSize) + 1
		local cy = math.floor((p.Z - origin.Z) / Config.World.CellSize) + 1
		location.Text = Grid.regionAt(MapData.Regions, cx, cy) or "SUBLEVEL 1"
	end

	local battery = Theme.num(player, "Battery", 1)
	batteryFill.Size = UDim2.fromScale(battery, 1)
	batteryFill.BackgroundColor3 = if battery < 0.2 then C.Rec else C.Osd
	local noise = Theme.num(player, "Noise", 0)
	local deadAir = Theme.num(workspace, "HS_DeadAirEnds", 0) > workspace:GetServerTimeNow()
	for i, segment in noiseSegments do
		local lit = noise >= i / 8 - 0.06
		segment.BackgroundTransparency = if lit then 0 else 0.8
		segment.BackgroundColor3 = if deadAir then C.Phosphor elseif i > 5 then C.Rec else C.Osd
	end
	staminaFill.Size = UDim2.fromScale(math.clamp(Hud.Stamina, 0, 1), 1)

	local hasTracker = player:GetAttribute("Pass_Tracker") == true
	trackerStrip.Visible = hasTracker and Hud.TrackerAngle ~= nil
	if hasTracker and Hud.TrackerAngle then
		local x = math.clamp(Hud.TrackerAngle / math.rad(90), -1, 1)
		trackerDot.Position = UDim2.new(0.5 + x * 0.5, -4, 0, -5)
		trackerDot.BackgroundTransparency = 1 - math.clamp(Hud.TrackerStrength, 0.15, 1)
	end
	local dazzleBack = dazzleBar.Parent :: Frame
	dazzleBack.Visible = Hud.DazzleProgress > 0.02
	dazzleBar.Size = UDim2.fromScale(math.clamp(Hud.DazzleProgress, 0, 1), 1)

	if hidden then
		local breath = Theme.num(player, "Breath", 1)
		breathFill.Size = UDim2.fromScale(breath, 1)
		local near = player:GetAttribute("FawnAtLocker") == true
		lockerHint.Text = if near then "SHE IS RIGHT OUTSIDE — HOLD [SPACE]" else "HIDDEN.  [SPACE] HOLD BREATH"
		lockerHint.TextColor3 = if near then C.Rec else C.Osd
		breathFill.BackgroundColor3 = if breath < 0.25 then C.Rec else C.Phosphor
	end
	if caged then
		local left = math.max(0, math.ceil(Theme.num(player, "CageEnds", 0) - workspace:GetServerTimeNow()))
		cageTimer.Text = `SHE COMES BACK FOR YOU IN {left}s`
		struggleFill.Size = UDim2.fromScale(Theme.num(player, "StruggleProgress", 0), 1)
		local free = Theme.num(player, "StrugglesLeft", 0)
		local keys = Theme.num(player, "Keys", 0)
		if free > 0 and player:GetAttribute("CanStruggle") then
			struggleHint.Text = "HOLD [SPACE] TO FORCE THE BARS — ONCE PER SHIFT"
		elseif free > 0 then
			struggleHint.Text = "CATCH YOUR BREATH... A CREWMATE CAN OPEN THE GATE"
		elseif keys > 0 then
			struggleHint.Text = `YOU HOLD {keys} RUSTED KEY(S) — USE THE KEY ON THE WALL`
		else
			struggleHint.Text = "WAIT FOR YOUR CREW — OR REACH FOR THE KEY ON THE WALL"
		end
	end
end

function Hud.init()
	build()
	player:GetAttributeChangedSignal("InShift"):Connect(function()
		if player:GetAttribute("InShift") then
			shiftJoinedAt = os.clock()
		end
	end)
	player:GetAttributeChangedSignal("Hidden"):Connect(function()
		hiddenSince = os.clock()
		holdingAction = false
	end)
	player:GetAttributeChangedSignal("Caged"):Connect(function()
		holdingAction = false
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			setHold(true)
		elseif (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB) and not processed then
			if player:GetAttribute("Hidden") and os.clock() - hiddenSince > 0.6 then
				send("ExitLocker")
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			setHold(false)
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc > 1 / 20 then
			acc = 0
			update()
		end
	end)
end

return Hud
