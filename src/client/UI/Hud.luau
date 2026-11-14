--!strict
--[[
	Hud — everything on the glass.

	  top right      case objectives with progress pips, and your vitals (hearts)
	  top centre     event lines ("IT HEARS YOU. BE QUIET."), then short messages
	  centre         camcorder viewfinder
	  lower centre   what it says to you, and the ANSWER prompt
	  bottom centre  hotbar — or the locker panel, or the grab panel
	  bottom left    noise meter and stamina (top left on phones)
	  bottom right   key hints (hidden on phones)

	Positions come from Layout.luau, which is checked offline so that no two
	things that can be on screen together ever overlap. The whole HUD lives in
	one scaled frame, so it keeps its proportions from a phone to a 1440p
	monitor. Full-screen panels (briefing, case file, field report, intro)
	hide the HUD while they are open.

	Type: Creepster for event lines and anything HUSH says, Special Elite for
	everything you read, Press Start 2P only for tiny camcorder tags.
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
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Vhs = require(script.Parent.Vhs)

local Hud = {}

local player = Players.LocalPlayer
local C = Config.Colors
local F = Theme.Fonts
local T = Layout.Text
local NEEDED = Config.Shift.PhotosNeeded
local RED = Color3.fromRGB(214, 40, 40)
local DARK = Color3.fromRGB(6, 7, 7)

Hud.Stamina = 1 -- written by Movement
Hud.TrackerAngle = nil :: number? -- written by FawnAnimator (radians, 0 = dead ahead)
Hud.TrackerStrength = 0
Hud.DazzleProgress = 0 -- written by Flashlight
Hud.CameraUp = false -- written by Camcorder
Hud.LightOn = false -- written by Flashlight

local gui: ScreenGui
local root: Frame
local rootScale: UIScale
local placed: { [string]: GuiObject } = {}
local lobbyHint: TextLabel
local photoLine: TextLabel
local sendLine: TextLabel
local cardHint: TextLabel
local photoPips: { Frame } = {}
local sendPips: { Frame } = {}
local heartPips: { Frame } = {}
local bannerHead: TextLabel
local bannerSub: TextLabel
local bannerRule: Frame
local location: TextLabel
local noiseBars: { Frame } = {}
local staminaFill: Frame
local batteryFill: Frame
local slots: { Frame } = {}
local toasts: Frame
local subtitle: TextLabel
local askFill: Frame
local viewfinder: Frame
local recDot: Frame
local timecode: TextLabel
local breathFill: Frame
local lockerHint: TextLabel
local grabHint: TextLabel
local grabFill: Frame
local trackerDot: Frame
local dazzleFill: Frame
local blip: Sound
local typeSound: Sound
local shiftJoinedAt = 0
local hiddenSince = 0
local holdingBreath = false
local askedUntil = 0
local askedFor = 5
local modals = 0
local touch = false

local function send(name: string, value: any?)
	Remotes.ToServer:FireServer(name, value)
end

-- Full-screen panels call this so the HUD is never drawn underneath them.
local function modal(open: boolean)
	modals = math.max(0, modals + (if open then 1 else -1))
	if root then
		root.Visible = modals == 0
	end
end

local function panel(parent: Instance, name: string): Frame
	local frame = Theme.frame(parent, name, UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), DARK, 0.35)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.82
	stroke.Parent = frame
	return frame
end

-- A thin meter. Returns the back frame (to place) and the fill (to size).
local function bar(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): (Frame, Frame)
	local back = Theme.frame(parent, name, size, position, Color3.new(0, 0, 0), 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.6
	stroke.Parent = back
	return back, Theme.frame(back, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 0.1)
end

-- A right-aligned row of little squares (or circles).
local function pips(parent: Instance, count: number, y: number, size: number, round: boolean): { Frame }
	local list = {}
	for i = 1, count do
		local pip = Theme.frame(parent, "Pip", UDim2.fromOffset(size, size), UDim2.new(1, -12 - (count - i + 1) * (size + 4) + 4, 0, y), C.Osd, 0.8)
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = pip
		end
		table.insert(list, pip)
	end
	return list
end

-- A single line of text, fitted to its box.
local function line(parent: Instance, name: string, size: UDim2, position: UDim2, font: Font, textSize: number, color: Color3, text: string): TextLabel
	local label = Theme.label(parent, name, size, position, font, textSize, color, text)
	label.TextYAlignment = Enum.TextYAlignment.Center
	Theme.fitText(label, textSize)
	return label
end

local function place(name: string, object: GuiObject, _inShiftOnly: boolean?): GuiObject
	placed[name] = object
	return object
end

local function applyLayout()
	local size = gui.AbsoluteSize
	if size.Y < 1 then
		return
	end
	touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local scale = Layout.scale(size.Y)
	rootScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale) -- so that, once scaled, it exactly fills the screen
	local rects = Layout.rects(size.X / scale, size.Y / scale, touch)
	for name, object in placed do
		local r = rects[name]
		object:SetAttribute("Placed", r ~= nil)
		if r then
			object.Position = UDim2.fromOffset(r.X, r.Y)
			object.Size = UDim2.fromOffset(r.W, r.H)
		else
			object.Visible = false
		end
	end
	local head = rects.BannerHead
	bannerRule.Position = UDim2.fromOffset(head.X + head.W / 2, head.Y + head.H + 4)
end

----------------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------------
function Hud.toast(text: string, kind: string?)
	-- the lobby screen owns the middle of the display while it is open
	if player:GetAttribute("PartyRole") ~= nil then
		return
	end
	local color = if kind == "bad" then C.Rec elseif kind == "good" then C.Phosphor elseif kind == "store" then C.Robux else C.Osd
	local labels: { Instance } = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels >= 3 then
		labels[1]:Destroy() -- three lines is all the band holds
	end
	local label = line(toasts, "Toast", UDim2.new(1, 0, 0, 20), UDim2.fromScale(0, 0), F.Body, T.Toast, color, text)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = math.floor(os.clock() * 100) % 1000000
	label.TextTransparency = 1
	blip:Play()
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(4.5, function()
		if not label.Parent then
			return
		end
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.9)
		label:Destroy()
	end)
end

-- The big event line at the top. tone: "good" | "bad" | "info".
function Hud.banner(headline: string, sub: string?, tone: string?)
	local color = if tone == "bad" then RED else C.Osd
	local stamp = os.clock()
	bannerHead:SetAttribute("Stamp", stamp)
	bannerHead.Text = headline
	bannerHead.TextColor3 = color
	bannerSub.Text = sub or ""
	bannerRule.BackgroundColor3 = color
	for _, object in { bannerHead, bannerSub } do
		object.TextTransparency = 1
		TweenService:Create(object, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end
	bannerRule.Size = UDim2.fromOffset(0, 1)
	bannerRule.BackgroundTransparency = 0.3
	TweenService:Create(bannerRule, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(240, 1) }):Play()
	if tone ~= "info" then
		blip:Play()
	end
	task.delay(4.2, function()
		if bannerHead:GetAttribute("Stamp") == stamp then
			TweenService:Create(bannerHead, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerSub, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerRule, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		end
	end)
end

local GLITCH = { "#", "%", "_", "/", "~", "=", "?" }

-- What it says. `glitch` crawls wrong characters through the line.
function Hud.subtitle(text: string, glitch: boolean?)
	subtitle.Text = text
	local stamp = os.clock()
	subtitle:SetAttribute("Stamp", stamp)
	subtitle:SetAttribute("Showing", true)
	if glitch then
		task.spawn(function()
			local rng = Random.new()
			while subtitle:GetAttribute("Stamp") == stamp and os.clock() - stamp < 5 do
				local chars = string.split(text, "")
				chars[rng:NextInteger(1, #chars)] = GLITCH[rng:NextInteger(1, #GLITCH)]
				subtitle.Text = table.concat(chars)
				task.wait(0.08)
				subtitle.Text = text
				task.wait(rng:NextNumber(0.15, 0.6))
			end
		end)
	end
	task.delay(5.2, function()
		if subtitle:GetAttribute("Stamp") == stamp then
			subtitle:SetAttribute("Showing", false)
		end
	end)
end

-- It asked you something. The prompt is real; using it is the mistake.
function Hud.asked(text: string, seconds: number)
	Hud.subtitle(text, false)
	Hud.banner(Lore.Banners.Asked[1], Lore.Banners.Asked[2], "bad")
	askedUntil = os.clock() + seconds
	askedFor = seconds
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
	modal(true)
	local overlay = Theme.screen("HS_Note", 60)
	local paper = Theme.frame(overlay, "Paper", UDim2.fromOffset(460, 500), UDim2.fromScale(0.5, 0.5), C.Paper, 0)
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Rotation = -1.5
	Theme.fit(paper, 620, 560)
	local stamp = line(paper, "Stamp", UDim2.new(1, -40, 0, 16), UDim2.fromOffset(20, 18), F.Osd, 9, Color3.fromRGB(140, 30, 30), Lore.CaseNumber .. "  //  CASE FILE")
	stamp.TextStrokeTransparency = 1
	local title = line(paper, "Title", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 44), F.Body, 24, C.Ink, note.Title)
	title.TextStrokeTransparency = 1
	Theme.frame(paper, "Rule", UDim2.new(1, -40, 0, 1), UDim2.fromOffset(20, 86), C.Ink, 0.5)
	local body = Theme.label(paper, "Body", UDim2.new(1, -40, 0, 320), UDim2.fromOffset(20, 100), F.Body, 19, C.Ink, note.Body)
	body.TextStrokeTransparency = 1
	body.LineHeight = 1.25
	local close = Theme.button(paper, "Close", UDim2.fromOffset(220, 34), UDim2.new(0.5, -110, 1, -52), "FILE IT  [E]")
	close.Modal = true -- frees the cursor while the camera is locked in first person
	local opened = os.clock()
	local keyConnection: RBXScriptConnection? = nil
	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		if keyConnection then
			keyConnection:Disconnect()
		end
		overlay:Destroy()
		modal(false)
	end
	keyConnection = UserInputService.InputBegan:Connect(function(input)
		if os.clock() - opened > 0.5 and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB) then
			dismiss()
		end
	end)
	close.MouseButton1Click:Connect(dismiss)
	task.delay(25, dismiss)
end

-- "MERIDIAN GENERAL HOSPITAL - WARD C": the card when you step out of the lift.
function Hud.locationCard(title: string, sub: string)
	local overlay = Theme.screen("HS_Card", 85)
	local box = Theme.frame(overlay, "Box", UDim2.fromOffset(900, 110), UDim2.fromScale(0.5, 0.42), DARK, 1)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.fit(box, 520, 960)
	local t = line(box, "Title", UDim2.new(1, 0, 0, 56), UDim2.fromOffset(0, 0), F.Display, 46, C.Osd, title)
	t.TextXAlignment = Enum.TextXAlignment.Center
	local s = line(box, "Sub", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 70), F.Body, 18, C.Amber, sub)
	s.TextXAlignment = Enum.TextXAlignment.Center
	s.MaxVisibleGraphemes = 0
	Theme.typewrite(t, title, 22, function()
		typeSound:Play()
	end)
	task.delay(#title / 22 + 0.3, function()
		if s.Parent then
			Theme.typewrite(s, sub, 30)
		end
	end)
	task.delay(6, function()
		TweenService:Create(t, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(1.1)
		overlay:Destroy()
	end)
end

-- The training tape, played full-screen during the elevator ride.
function Hud.briefing()
	modal(true)
	local overlay = Theme.screen("HS_Briefing", 88)
	Theme.frame(overlay, "Tape", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(6, 22, 16), 0)
	-- a fixed 920x440 "screen" that is scaled as one piece, so lines never re-wrap
	local screen = Theme.frame(overlay, "Screen", UDim2.fromOffset(920, 440), UDim2.fromScale(0.5, 0.5), DARK, 1)
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.fit(screen, 540, 980)
	line(screen, "Play", UDim2.fromOffset(200, 18), UDim2.fromOffset(0, 0), F.Osd, 12, C.Osd, "PLAY >")
	local counter = line(screen, "Counter", UDim2.fromOffset(200, 18), UDim2.new(1, -200, 0, 0), F.Osd, 12, C.Osd, "SP 0:00")
	counter.TextXAlignment = Enum.TextXAlignment.Right
	local head = Theme.frame(screen, "Head", UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 32), Color3.fromRGB(150, 30, 30), 0)
	local headText = line(head, "Text", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), F.Osd, 18, C.Osd, "")
	headText.TextXAlignment = Enum.TextXAlignment.Center
	local body = Theme.label(screen, "Body", UDim2.new(1, 0, 0, 230), UDim2.fromOffset(0, 104), F.Osd, 13, C.Phosphor, "")
	body.LineHeight = 1.9
	local warning = line(screen, "Warning", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 360), F.Display, 56, Color3.fromRGB(255, 70, 60), "")
	warning.TextXAlignment = Enum.TextXAlignment.Center
	local skip = Theme.button(overlay, "Skip", UDim2.fromOffset(120, 30), UDim2.new(1, -144, 1, -54), "SKIP >>")
	skip.Modal = true
	local done = false
	local function finish()
		if not done then
			done = true
			overlay:Destroy()
			modal(false)
		end
	end
	skip.MouseButton1Click:Connect(finish)
	task.spawn(function()
		local elapsed = 0
		for _, slide in Lore.Briefing do
			if done then
				return
			end
			Vhs.burst(0.5, 0.18) -- tape splice
			head.Visible = slide.Title ~= ""
			headText.Text = slide.Title
			body.Text = table.concat(slide.Lines, "\n")
			body.TextXAlignment = if slide.Title == "" then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			warning.Text = slide.Warning or ""
			typeSound:Play()
			local shown = 0
			while shown < slide.Seconds and not done do
				shown += task.wait(0.1)
				counter.Text = string.format("SP 0:%02d", math.floor(elapsed + shown))
				warning.TextTransparency = if (shown * 2) % 1 < 0.6 then 0 else 0.7
			end
			elapsed += slide.Seconds
		end
		finish()
	end)
end

export type Results = { Outcome: string, Seconds: number, Photos: number, Sent: number, Files: number, Caught: number, Xp: number, TotalXp: number }

local RANKS = { "RECRUIT", "FIELD AGENT", "INVESTIGATOR", "SENIOR INVESTIGATOR", "ARCHIVIST" }

function Hud.showResults(results: Results)
	modal(true)
	local overlay = Theme.screen("HS_Results", 90)
	local back = Theme.frame(overlay, "Back", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	TweenService:Create(back, TweenInfo.new(1.2), { BackgroundTransparency = 0.3 }):Play()
	local escaped = results.Outcome == "Escaped"
	local ending = Lore.Endings[results.Outcome] or Lore.Endings.Taken
	local report = Theme.frame(overlay, "Report", UDim2.fromOffset(480, 500), UDim2.fromScale(0.5, 0.5), DARK, 0.08)
	report.AnchorPoint = Vector2.new(0.5, 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.7
	stroke.Parent = report
	Theme.fit(report, 620, 580)
	-- every row below has its own band; nothing shares vertical space
	local tag = line(report, "Tag", UDim2.new(1, -40, 0, 14), UDim2.fromOffset(20, 18), F.Osd, 9, C.Amber, Lore.CaseNumber .. "   //   " .. string.upper(player.DisplayName))
	tag.TextStrokeTransparency = 1
	line(report, "Title", UDim2.new(1, -40, 0, 46), UDim2.fromOffset(20, 38), F.Display, 42, C.Osd, "FIELD REPORT")
	line(report, "Verdict", UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 90), F.Display, 28, if escaped then C.Phosphor else RED, ending[1])
	local story = Theme.label(report, "Line", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 128), F.Body, 16, C.Paper, "")
	Theme.typewrite(story, ending[2], 34)
	local X = Config.Xp
	local rows = {
		{ "Photographs taken", tostring(results.Photos), results.Photos * X.Photo },
		{ "Evidence sent", tostring(results.Sent), results.Sent * X.Sent },
		{ "Case files recovered", tostring(results.Files), results.Files * X.File },
		{ "Returned to the elevator", if escaped then "YES" else "NO", if escaped then X.Escaped else 0 },
		{ "Times it had you", tostring(results.Caught), 0 },
	}
	for i, row in rows do
		local y = 184 + (i - 1) * 28
		line(report, "RowName", UDim2.new(0.55, -20, 0, 22), UDim2.fromOffset(20, y), F.Body, 16, C.Osd, row[1] :: string)
		local value = line(report, "RowValue", UDim2.new(0.15, 0, 0, 22), UDim2.new(0.55, 0, 0, y), F.Body, 16, C.Osd, row[2] :: string)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local xp = line(report, "RowXp", UDim2.new(0.3, -20, 0, 22), UDim2.new(0.7, 0, 0, y), F.Body, 16, C.Phosphor, if (row[3] :: number) > 0 then `+{row[3]} XP` else "")
		xp.TextXAlignment = Enum.TextXAlignment.Right
	end
	Theme.frame(report, "Rule", UDim2.new(1, -40, 0, 1), UDim2.fromOffset(20, 330), C.Osd, 0.7)
	local level = results.TotalXp // X.PerLevel + 1
	line(report, "Level", UDim2.new(0.62, -20, 0, 26), UDim2.fromOffset(20, 340), F.Body, 17, C.Osd, `LEVEL {level}  -  {RANKS[math.min(level, #RANKS)]}`)
	local total = line(report, "Total", UDim2.new(0.38, -20, 0, 26), UDim2.new(0.62, 0, 0, 340), F.Body, 20, C.Phosphor, `+{results.Xp} XP`)
	total.TextXAlignment = Enum.TextXAlignment.Right
	local _, fill = bar(report, "LevelBar", UDim2.new(1, -40, 0, 6), UDim2.fromOffset(20, 378), C.Phosphor)
	fill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(fill, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale((results.TotalXp % X.PerLevel) / X.PerLevel, 1) }):Play()
	local close = Theme.button(report, "Close", UDim2.fromOffset(220, 38), UDim2.new(0.5, -110, 1, -62), "CONTINUE")
	close.Modal = true
	local closed = false
	local function dismiss()
		if not closed then
			closed = true
			overlay:Destroy()
			modal(false)
		end
	end
	close.MouseButton1Click:Connect(dismiss)
	task.delay(20, dismiss)
end

-- First-visit intro: photosensitivity notice, then the premise, typed.
function Hud.intro(first: boolean, onDone: () -> ())
	modal(true)
	local overlay = Theme.screen("HS_Intro", 95)
	local back = Theme.frame(overlay, "Back", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0)
	local stage = Theme.frame(overlay, "Stage", UDim2.fromOffset(900, 420), UDim2.fromScale(0.5, 0.5), DARK, 1)
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.fit(stage, 520, 960)
	local text = Theme.label(stage, "Text", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), F.Body, 24, C.Paper, "")
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.LineHeight = 1.3
	local skip = Theme.button(overlay, "Skip", UDim2.fromOffset(120, 30), UDim2.new(1, -144, 1, -54), "SKIP >>")
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		TweenService:Create(back, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
		skip.Visible = false
		for _, child in stage:GetChildren() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
		task.delay(1.6, function()
			overlay:Destroy()
		end)
		modal(false)
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
		-- title card: the name in its own band, the tagline in the band below it
		text.Visible = false
		local name = line(stage, "Name", UDim2.new(1, 0, 0, 120), UDim2.fromOffset(0, 110), F.Display, 110, C.Osd, Config.GameName)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local tag = line(stage, "Tag", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 244), F.Display, 30, RED, Config.Tagline)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		task.wait(2.8)
		finish()
	end)
end

----------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------
local function build()
	gui = Theme.screen("HS_HUD", 30)
	root = Theme.frame(gui, "Root", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), DARK, 1)
	rootScale = Instance.new("UIScale")
	rootScale.Parent = root
	blip = Sfx.make(gui, "Blip", { Volume = 0.3 })
	typeSound = Sfx.make(gui, "Type", { Volume = 0.25 })

	lobbyHint = line(root, "LobbyHint", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), F.Body, T.LobbyHint, C.Osd, "")
	lobbyHint.TextXAlignment = Enum.TextXAlignment.Center
	place("LobbyHint", lobbyHint)

	-- event line, top centre
	bannerHead = line(root, "BannerHead", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), F.Display, T.BannerHead, C.Osd, "")
	bannerHead.TextXAlignment = Enum.TextXAlignment.Center
	bannerHead.TextStrokeTransparency = 0.5
	place("BannerHead", bannerHead)
	bannerRule = Theme.frame(root, "BannerRule", UDim2.fromOffset(0, 1), UDim2.fromOffset(0, 0), C.Osd, 1)
	bannerRule.AnchorPoint = Vector2.new(0.5, 0)
	bannerSub = Theme.label(root, "BannerSub", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), F.Body, T.BannerSub, C.Osd, "")
	bannerSub.TextXAlignment = Enum.TextXAlignment.Center
	Theme.fitText(bannerSub, T.BannerSub) -- may use two lines, never more than its band
	place("BannerSub", bannerSub)

	toasts = Theme.frame(root, "Toasts", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), DARK, 1)
	toasts.ClipsDescendants = true
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = toasts
	place("Toasts", toasts)

	-- objectives card, top right
	local card = panel(root, "Objectives")
	place("Card", card, true)
	local tag = line(card, "Tag", UDim2.new(1, -24, 0, 12), UDim2.fromOffset(12, 8), F.Osd, 7, C.Amber, "CASE OBJECTIVES")
	tag.TextXAlignment = Enum.TextXAlignment.Right
	-- text takes the left of each row, pips the right: 8px squares, 5 of them = 60px
	photoLine = line(card, "Photo", UDim2.new(1, -24 - 72, 0, 20), UDim2.fromOffset(12, 26), F.Body, T.Objective, C.Osd, "")
	photoPips = pips(card, NEEDED, 32, 8, false)
	sendLine = line(card, "Send", UDim2.new(1, -24 - 72, 0, 20), UDim2.fromOffset(12, 52), F.Body, T.Objective, C.Osd, "")
	sendPips = pips(card, NEEDED, 58, 8, false)
	cardHint = Theme.label(card, "Hint", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 80), F.Body, T.Hint, C.Osd, "")
	cardHint.TextTransparency = 0.3
	Theme.fitText(cardHint, T.Hint)

	local vitals = panel(root, "Vitals")
	place("Vitals", vitals, true)
	line(vitals, "Tag", UDim2.fromOffset(90, 12), UDim2.fromOffset(12, 9), F.Osd, 8, C.Osd, "VITALS")
	heartPips = pips(vitals, 5, 8, 14, true)
	location = line(root, "Location", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), F.Body, 13, C.Amber, "")
	location.TextXAlignment = Enum.TextXAlignment.Right
	place("Location", location, true)

	-- noise meter
	local noise = panel(root, "Noise")
	place("Noise", noise, true)
	line(noise, "Tag", UDim2.fromOffset(166, 12), UDim2.fromOffset(12, 8), F.Osd, 8, C.Osd, "NOISE METER")
	for i = 1, 24 do
		table.insert(noiseBars, Theme.frame(noise, "Bar", UDim2.fromOffset(4, 16), UDim2.fromOffset(12 + (i - 1) * 7, 26), C.Osd, 0.85))
	end
	for i, word in { "QUIET", "NORMAL", "LOUD" } do
		local label = line(noise, word, UDim2.fromOffset(52, 10), UDim2.fromOffset(12 + (i - 1) * 56, 48), F.Osd, 6, if i == 3 then C.Rec else C.Osd, word)
		label.TextTransparency = 0.4
	end
	local staminaBack
	staminaBack, staminaFill = bar(root, "Stamina", UDim2.fromOffset(10, 4), UDim2.fromOffset(0, 0), C.Osd)
	place("Stamina", staminaBack, true)

	-- hotbar, bottom centre
	local function slot(index: number, name: string, key: string): Frame
		local frame = panel(root, "Slot" .. index)
		place("Slot" .. index, frame, true)
		line(frame, "Key", UDim2.fromOffset(24, 10), UDim2.fromOffset(6, 5), F.Osd, 7, C.Amber, key)
		local label = line(frame, "Name", UDim2.new(1, -8, 0, 12), UDim2.fromOffset(4, 22), F.Osd, 8, C.Osd, name)
		label.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(slots, frame)
		return frame
	end
	slot(1, "CAMERA", "Q")
	slot(2, "LIGHT", "F")
	local battery = slot(3, "BATT", "")
	local _
	_, batteryFill = bar(battery, "Battery", UDim2.new(1, -16, 0, 4), UDim2.fromOffset(8, 9), C.Osd)

	local hints = Theme.label(root, "Hints", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), F.Body, 13, C.Osd, "Q / RMB   Raise camcorder\nCLICK   Photograph\nC   Crouch      SHIFT   Sprint\nF   Flashlight")
	hints.TextXAlignment = Enum.TextXAlignment.Right
	hints.TextYAlignment = Enum.TextYAlignment.Bottom
	hints.TextTransparency = 0.35
	hints.LineHeight = 1.2
	Theme.fitText(hints, 13)
	place("Hints", hints, true)

	-- what it says, in its own typeface
	subtitle = line(root, "Subtitle", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), F.Display, T.Subtitle, Color3.fromRGB(236, 226, 226), "")
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextStrokeTransparency = 0.3
	place("Subtitle", subtitle)
	local askPanel = panel(root, "Ask")
	place("Ask", askPanel)
	local askLabel = line(askPanel, "Label", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 6), F.Body, 16, C.Osd, "[T]  ANSWER")
	askLabel.TextXAlignment = Enum.TextXAlignment.Center
	local _askBack
	_askBack, askFill = bar(askPanel, "Time", UDim2.new(1, -24, 0, 3), UDim2.fromOffset(12, 31), C.Osd)
	local askButton = Instance.new("TextButton")
	askButton.Size = UDim2.fromScale(1, 1)
	askButton.BackgroundTransparency = 1
	askButton.Text = ""
	askButton.Parent = askPanel
	askButton.MouseButton1Click:Connect(function()
		send("Answer")
		askedUntil = 0
	end)

	-- camcorder viewfinder: four corner brackets, a centre dot, REC and timecode along the top
	viewfinder = Theme.frame(root, "Viewfinder", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), DARK, 1)
	place("Viewfinder", viewfinder, true)
	for _, corner in { { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } } do
		Theme.frame(viewfinder, "H", UDim2.fromOffset(28, 2), UDim2.new(corner[1], if corner[3] > 0 then 0 else -28, corner[2], if corner[4] > 0 then 0 else -2), C.Osd, 0.1)
		Theme.frame(viewfinder, "V", UDim2.fromOffset(2, 28), UDim2.new(corner[1], if corner[3] > 0 then 0 else -2, corner[2], if corner[4] > 0 then 0 else -28), C.Osd, 0.1)
	end
	Theme.frame(viewfinder, "Dot", UDim2.fromOffset(4, 4), UDim2.new(0.5, -2, 0.5, -2), C.Osd, 0.2)
	recDot = Theme.frame(viewfinder, "RecDot", UDim2.fromOffset(10, 10), UDim2.fromOffset(12, 12), C.Rec, 0)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = recDot
	line(viewfinder, "Rec", UDim2.fromOffset(40, 14), UDim2.fromOffset(28, 10), F.Osd, 11, C.Osd, "REC")
	timecode = line(viewfinder, "Timecode", UDim2.fromOffset(96, 14), UDim2.new(1, -108, 0, 10), F.Osd, 10, C.Osd, "00:00:00")
	timecode.TextXAlignment = Enum.TextXAlignment.Right

	local trackerStrip = Theme.frame(root, "Tracker", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), DARK, 1)
	place("Tracker", trackerStrip, true)
	Theme.frame(trackerStrip, "Line", UDim2.new(1, 0, 0, 4), UDim2.new(0, 0, 0.5, -2), C.Osd, 0.7)
	trackerDot = Theme.frame(trackerStrip, "Dot", UDim2.fromOffset(8, 14), UDim2.new(0.5, -4, 0.5, -7), C.Rec, 0)
	local dazzleBack
	dazzleBack, dazzleFill = bar(root, "Dazzle", UDim2.fromOffset(10, 4), UDim2.fromOffset(0, 0), C.Amber)
	place("Dazzle", dazzleBack, true)

	-- locker: hold your breath (takes the hotbar's place)
	local lockerPanel = panel(root, "Locker")
	place("Locker", lockerPanel)
	lockerHint = line(lockerPanel, "Hint", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), F.Body, 16, C.Osd, "")
	lockerHint.TextXAlignment = Enum.TextXAlignment.Center
	local _breathBack
	_breathBack, breathFill = bar(lockerPanel, "Breath", UDim2.new(1, -40, 0, 8), UDim2.fromOffset(20, 40), C.Phosphor)
	local breathButton = Theme.button(lockerPanel, "Hold", UDim2.fromOffset(160, 34), UDim2.fromOffset(14, 64), "HOLD BREATH")
	local exitButton = Theme.button(lockerPanel, "Exit", UDim2.fromOffset(160, 34), UDim2.fromOffset(186, 64), "GET OUT [E]")
	breathButton.MouseButton1Down:Connect(function()
		send("HoldBreath", true)
	end)
	breathButton.MouseButton1Up:Connect(function()
		send("HoldBreath", false)
	end)
	exitButton.MouseButton1Click:Connect(function()
		send("ExitLocker")
	end)

	-- in its hands (also takes the hotbar's place)
	local grabPanel = panel(root, "Grab")
	place("Grab", grabPanel)
	grabHint = line(grabPanel, "Hint", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 8), F.Display, 26, C.Osd, "")
	grabHint.TextXAlignment = Enum.TextXAlignment.Center
	local _grabBack
	_grabBack, grabFill = bar(grabPanel, "Progress", UDim2.new(1, -40, 0, 10), UDim2.fromOffset(20, 52), C.Osd)
	local grabButton = Instance.new("TextButton")
	grabButton.Size = UDim2.fromScale(1, 1)
	grabButton.BackgroundTransparency = 1
	grabButton.Text = ""
	grabButton.Parent = grabPanel
	grabButton.MouseButton1Down:Connect(function()
		send("Struggle")
	end)

	local fx = Theme.button(root, "Fx", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), "FX: FULL")
	Theme.fitText(fx, 12)
	place("Fx", fx)
	fx.MouseButton1Click:Connect(function()
		Vhs.ReducedFlashing = not Vhs.ReducedFlashing
		player:SetAttribute("ReducedFlashing", Vhs.ReducedFlashing)
		fx.Text = if Vhs.ReducedFlashing then "FX: REDUCED" else "FX: FULL"
	end)

	applyLayout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	UserInputService.LastInputTypeChanged:Connect(function()
		local nowTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		if nowTouch ~= touch then
			applyLayout()
		end
	end)
end

local function setPips(list: { Frame }, lit: number, color: Color3)
	for i, pip in list do
		pip.BackgroundColor3 = if i <= lit then color else C.Osd
		pip.BackgroundTransparency = if i <= lit then 0 else 0.82
	end
end

-- Shows an element only if this screen size has a place for it.
local function show(name: string, visible: boolean)
	local object = placed[name]
	object.Visible = visible and object:GetAttribute("Placed") == true
end

local function update()
	local inShift = player:GetAttribute("InShift") == true
	local hidden = inShift and player:GetAttribute("Hidden") == true
	local grabbed = inShift and player:GetAttribute("Grabbed") == true
	local working = inShift and not grabbed -- on the ward, on your feet or in a locker

	-- exactly one of these owns the bottom-centre slot
	show("Locker", hidden)
	show("Grab", grabbed)
	local hotbar = working and not hidden
	show("Slot1", hotbar)
	show("Slot2", hotbar)
	show("Slot3", hotbar)
	show("Tracker", hotbar and player:GetAttribute("Pass_Tracker") == true and Hud.TrackerAngle ~= nil)
	show("Viewfinder", hotbar and Hud.CameraUp)
	show("Dazzle", hotbar and Hud.DazzleProgress > 0.02)
	show("Card", working)
	show("Vitals", working)
	show("Location", working)
	show("Noise", working)
	show("Stamina", working)
	show("Hints", working)
	show("Subtitle", subtitle:GetAttribute("Showing") == true)
	show("Ask", inShift and os.clock() < askedUntil)
	show("LobbyHint", not inShift)
	askFill.Size = UDim2.fromScale(math.clamp((askedUntil - os.clock()) / askedFor, 0, 1), 1)

	local O = Lore.Objectives
	if not inShift then
		lobbyHint.Text = if player:GetAttribute("PartyRole") then "" elseif workspace:GetAttribute("HS_Mode") == "Match" then O.LobbyMatch else O.Lobby
		return
	end

	-- objectives
	local photos = Theme.num(workspace, "HS_Photos", 0)
	local sentCount = Theme.num(workspace, "HS_Sent", 0)
	if workspace:GetAttribute("HS_Phase") == "Return" then
		local left = math.max(0, math.ceil(Theme.num(workspace, "HS_ReturnEnds", 0) - workspace:GetServerTimeNow()))
		photoLine.Text = O.Return
		photoLine.TextColor3 = RED
		sendLine.Text = string.format("LOCKDOWN IN %d:%02d", left // 60, left % 60)
		cardHint.Text = O.ReturnHint
	else
		photoLine.Text = O.Photograph
		photoLine.TextColor3 = if photos >= NEEDED then C.Phosphor else C.Osd
		sendLine.Text = O.Send
		cardHint.Text = if photos > sentCount then O.SendHint else O.PhotographHint
	end
	setPips(photoPips, photos, C.Phosphor)
	setPips(sendPips, sentCount, C.Amber)
	setPips(heartPips, Theme.num(player, "Hearts", 0), RED)

	local camera = workspace.CurrentCamera
	if camera then
		local p = camera.CFrame.Position
		local origin = Config.World.FacilityOrigin
		local cx = math.floor((p.X - origin.X) / Config.World.CellSize) + 1
		local cy = math.floor((p.Z - origin.Z) / Config.World.CellSize) + 1
		location.Text = Grid.regionAt(MapData.Regions, cx, cy) or "WARD C CORRIDOR"
	end

	-- noise: bars fill left to right, the last third reads as danger
	local noise = Theme.num(player, "Noise", 0)
	local deadAir = Theme.num(workspace, "HS_DeadAirEnds", 0) > workspace:GetServerTimeNow()
	for i, barFrame in noiseBars do
		local lit = noise >= i / #noiseBars - 0.02
		barFrame.BackgroundTransparency = if lit then 0.05 else 0.85
		barFrame.BackgroundColor3 = if deadAir then C.Phosphor elseif i > 16 then RED else C.Osd
	end
	staminaFill.Size = UDim2.fromScale(math.clamp(Hud.Stamina, 0, 1), 1)
	local battery = Theme.num(player, "Battery", 1)
	batteryFill.Size = UDim2.fromScale(battery, 1)
	batteryFill.BackgroundColor3 = if battery < 0.2 then C.Rec else C.Osd
	slots[1].BackgroundColor3 = if Hud.CameraUp then C.Osd else DARK
	slots[1].BackgroundTransparency = if Hud.CameraUp then 0.55 else 0.35
	slots[2].BackgroundColor3 = if Hud.LightOn then C.Osd else DARK
	slots[2].BackgroundTransparency = if Hud.LightOn then 0.55 else 0.35

	local t = os.clock() - shiftJoinedAt
	timecode.Text = string.format("%02d:%02d:%02d", t // 60, t % 60, (t * 30) % 30)
	recDot.Visible = (t % 1.2) < 0.7
	if Hud.TrackerAngle then
		local x = math.clamp(Hud.TrackerAngle / math.rad(90), -1, 1)
		trackerDot.Position = UDim2.new(0.5 + x * 0.48, -4, 0.5, -7)
		trackerDot.BackgroundTransparency = 1 - math.clamp(Hud.TrackerStrength, 0.15, 1)
	end
	dazzleFill.Size = UDim2.fromScale(math.clamp(Hud.DazzleProgress, 0, 1), 1)

	if hidden then
		local breath = Theme.num(player, "Breath", 1)
		breathFill.Size = UDim2.fromScale(breath, 1)
		local near = player:GetAttribute("FawnAtLocker") == true
		lockerHint.Text = if near then "IT IS RIGHT OUTSIDE - HOLD [SPACE]" else "HIDDEN.  [SPACE] HOLD BREATH"
		lockerHint.TextColor3 = if near then C.Rec else C.Osd
		breathFill.BackgroundColor3 = if breath < 0.25 then C.Rec else C.Phosphor
	end
	if grabbed then
		local can = Theme.num(player, "BreakFrees", 0) > 0
		grabHint.Text = if can then "TAP [E] - BREAK FREE" else "IT HAS YOU."
		grabHint.TextColor3 = if can then C.Osd else RED
		local back = grabFill.Parent :: Frame
		back.Visible = can
		grabFill.Size = UDim2.fromScale(Theme.num(player, "GrabProgress", 0), 1)
	end
end

function Hud.init()
	build()
	root.Visible = modals == 0
	player:GetAttributeChangedSignal("InShift"):Connect(function()
		if player:GetAttribute("InShift") then
			shiftJoinedAt = os.clock()
		end
	end)
	player:GetAttributeChangedSignal("Hidden"):Connect(function()
		hiddenSince = os.clock()
		holdingBreath = false
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		if key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
			if player:GetAttribute("Hidden") and not holdingBreath then
				holdingBreath = true
				send("HoldBreath", true)
			end
		elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonX then
			if player:GetAttribute("Grabbed") then
				send("Struggle")
			elseif player:GetAttribute("Hidden") and not processed and os.clock() - hiddenSince > 0.6 then
				send("ExitLocker")
			end
		elseif key == Enum.KeyCode.T and not processed and os.clock() < askedUntil then
			send("Answer")
			askedUntil = 0
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) and holdingBreath then
			holdingBreath = false
			send("HoldBreath", false)
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
