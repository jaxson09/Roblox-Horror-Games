--!strict
--[[
	Hud — everything on the glass.

	  top right      case objectives with progress pips, and your vitals (hearts)
	  top centre     event lines: "IT HEARS YOU. BE QUIET."
	  bottom left    noise meter (quiet / normal / loud) and stamina
	  bottom centre  hotbar: camcorder, light; what it is saying to you
	  bottom right   key hints
	  centre         camcorder viewfinder, locker and grab prompts

	Plus the panels: briefing tape, case files, field report, intro.
	Fonts: Bodoni for event lines and its speech, Roboto Mono for readouts,
	PressStart2P for small OSD tags, Special Elite for anything on paper.
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
local NEEDED = Config.Shift.PhotosNeeded

Hud.Stamina = 1 -- written by Movement
Hud.TrackerAngle = nil :: number? -- written by FawnAnimator (radians, 0 = dead ahead)
Hud.TrackerStrength = 0
Hud.DazzleProgress = 0 -- written by Flashlight
Hud.CameraUp = false -- written by Camcorder
Hud.LightOn = false -- written by Flashlight

local gui: ScreenGui
local shiftGroup: Frame
local lobbyHint: TextLabel
local card: Frame
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
local slotCamera: Frame
local slotLight: Frame
local toasts: Frame
local subtitle: TextLabel
local askPanel: Frame
local askFill: Frame
local viewfinder: Frame
local recDot: Frame
local timecode: TextLabel
local lockerPanel: Frame
local breathFill: Frame
local lockerHint: TextLabel
local grabPanel: Frame
local grabHint: TextLabel
local grabFill: Frame
local trackerStrip: Frame
local trackerDot: Frame
local dazzleBar: Frame
local blip: Sound
local typeSound: Sound
local shiftJoinedAt = 0
local hiddenSince = 0
local holdingBreath = false
local askedUntil = 0
local askedFor = 5

local function send(name: string, value: any?)
	Remotes.ToServer:FireServer(name, value)
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local frame = Theme.frame(parent, name, size, position, Color3.fromRGB(6, 7, 7), 0.35)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.82
	stroke.Parent = frame
	return frame
end

local function bar(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): Frame
	local back = Theme.frame(parent, name, size, position, Color3.new(0, 0, 0), 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Osd
	stroke.Transparency = 0.6
	stroke.Parent = back
	return Theme.frame(back, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 0.1)
end

local function pips(parent: Instance, count: number, x: number, y: number, size: number, round: boolean): { Frame }
	local list = {}
	for i = 1, count do
		local pip = Theme.frame(parent, "Pip", UDim2.fromOffset(size, size), UDim2.new(1, x - (count - i + 1) * (size + 4), 0, y), C.Osd, 0.8)
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = pip
		end
		table.insert(list, pip)
	end
	return list
end

----------------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------------
function Hud.toast(text: string, kind: string?)
	local color = if kind == "bad" then C.Rec elseif kind == "good" then C.Phosphor elseif kind == "store" then C.Robux else C.Osd
	local label = Theme.label(toasts, "Toast", UDim2.new(1, 0, 0, 20), UDim2.fromScale(0, 0), F.Mono, 14, color, text)
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

-- The big event line at the top. tone: "good" | "bad" | "info".
function Hud.banner(headline: string, sub: string?, tone: string?)
	local color = if tone == "bad" then Color3.fromRGB(214, 40, 40) else C.Osd
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
	TweenService:Create(bannerRule, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(260, 1) }):Play()
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
	subtitle.Visible = true
	local stamp = os.clock()
	subtitle:SetAttribute("Stamp", stamp)
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
			subtitle.Visible = false
		end
	end)
end

-- It asked you something. The prompt is real; using it is the mistake.
function Hud.asked(line: string, seconds: number)
	Hud.subtitle(line, false)
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
	local overlay = Theme.screen("HS_Note", 60)
	local paper = Theme.frame(overlay, "Paper", UDim2.fromOffset(440, 470), UDim2.fromScale(0.5, 0.5), C.Paper, 0)
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Rotation = -1.5
	Theme.fit(paper, 580)
	local stampLabel = Theme.label(paper, "Stamp", UDim2.new(1, -40, 0, 16), UDim2.fromOffset(20, 16), F.Osd, 9, Color3.fromRGB(140, 30, 30), Lore.CaseNumber .. "  //  CASE FILE")
	stampLabel.TextStrokeTransparency = 1
	local title = Theme.label(paper, "Title", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 40), F.Typewriter, 22, C.Ink, note.Title)
	title.TextStrokeTransparency = 1
	local body = Theme.label(paper, "Body", UDim2.new(1, -40, 1, -150), UDim2.fromOffset(20, 92), F.Typewriter, 18, C.Ink, note.Body)
	body.TextStrokeTransparency = 1
	body.LineHeight = 1.25
	local close = Theme.button(paper, "Close", UDim2.fromOffset(200, 30), UDim2.new(0.5, -100, 1, -44), "FILE IT [E]")
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
	local t = Theme.label(overlay, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.42, 0), F.Serif, 30, C.Osd, "")
	t.TextXAlignment = Enum.TextXAlignment.Center
	local s = Theme.label(overlay, "Sub", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.42, 48), F.Mono, 15, C.Amber, "")
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

-- The training tape, played full-screen during the elevator ride.
function Hud.briefing()
	local overlay = Theme.screen("HS_Briefing", 88)
	local screen = Theme.frame(overlay, "Tape", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(6, 22, 16), 0)
	local head = Theme.frame(screen, "Head", UDim2.new(0.62, 0, 0, 44), UDim2.new(0.19, 0, 0.2, 0), Color3.fromRGB(150, 30, 30), 0)
	local headText = Theme.label(head, "Text", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), F.Osd, 18, C.Osd, "")
	headText.TextXAlignment = Enum.TextXAlignment.Center
	headText.TextYAlignment = Enum.TextYAlignment.Center
	local body = Theme.label(screen, "Body", UDim2.new(0.62, 0, 0.38, 0), UDim2.new(0.19, 0, 0.2, 70), F.Osd, 13, C.Phosphor, "")
	body.LineHeight = 1.9
	local warning = Theme.label(screen, "Warning", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.74, 0), F.Osd, 22, Color3.fromRGB(255, 70, 60), "")
	warning.TextXAlignment = Enum.TextXAlignment.Center
	Theme.label(screen, "Play", UDim2.fromOffset(200, 20), UDim2.new(0.19, 0, 0.2, -30), F.Osd, 12, C.Osd, "PLAY ▶")
	local counter = Theme.label(screen, "Counter", UDim2.fromOffset(200, 20), UDim2.new(0.81, -200, 0.2, -30), F.Osd, 12, C.Osd, "SP 0:00")
	counter.TextXAlignment = Enum.TextXAlignment.Right
	local skip = Theme.button(screen, "Skip", UDim2.fromOffset(120, 28), UDim2.new(1, -150, 1, -56), "SKIP ▶▶")
	local done = false
	local function finish()
		if not done then
			done = true
			overlay:Destroy()
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
	local overlay = Theme.screen("HS_Results", 90)
	local back = Theme.frame(overlay, "Back", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	TweenService:Create(back, TweenInfo.new(1.2), { BackgroundTransparency = 0.3 }):Play()
	local escaped = results.Outcome == "Escaped"
	local ending = Lore.Endings[results.Outcome] or Lore.Endings.Taken
	local report = panel(overlay, "Report", UDim2.fromOffset(460, 430), UDim2.fromScale(0.5, 0.5))
	report.AnchorPoint = Vector2.new(0.5, 0.5)
	report.BackgroundTransparency = 0.08
	Theme.fit(report, 560)
	local tag = Theme.label(report, "Tag", UDim2.new(1, -40, 0, 14), UDim2.fromOffset(20, 18), F.Osd, 9, C.Amber, Lore.CaseNumber .. "   //   " .. string.upper(player.DisplayName))
	tag.TextStrokeTransparency = 1
	Theme.label(report, "Title", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 38), F.Serif, 30, C.Osd, "FIELD REPORT")
	local verdict = Theme.label(report, "Verdict", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 78), if escaped then F.MonoBold else F.Horror, if escaped then 16 else 24, if escaped then C.Phosphor else C.Dread, ending[1])
	verdict.TextStrokeTransparency = 0.8
	local line = Theme.label(report, "Line", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 106), F.Typewriter, 15, C.Paper, "")
	Theme.typewrite(line, ending[2], 34)
	local X = Config.Xp
	local rows = {
		{ "Photographs taken", tostring(results.Photos), results.Photos * X.Photo },
		{ "Evidence sent", tostring(results.Sent), results.Sent * X.Sent },
		{ "Case files recovered", tostring(results.Files), results.Files * X.File },
		{ "Returned to the elevator", if escaped then "YES" else "NO", if escaped then X.Escaped else 0 },
		{ "Times it had you", tostring(results.Caught), 0 },
	}
	for i, row in rows do
		local y = 156 + (i - 1) * 26
		Theme.label(report, "RowName", UDim2.new(0.6, 0, 0, 20), UDim2.fromOffset(20, y), F.Mono, 14, C.Osd, row[1] :: string)
		local value = Theme.label(report, "RowValue", UDim2.new(0.2, 0, 0, 20), UDim2.new(0.55, 0, 0, y), F.Mono, 14, C.Osd, row[2] :: string)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local xp = Theme.label(report, "RowXp", UDim2.new(0.2, -20, 0, 20), UDim2.new(0.8, 0, 0, y), F.Mono, 14, C.Phosphor, if (row[3] :: number) > 0 then `+{row[3]} XP` else "")
		xp.TextXAlignment = Enum.TextXAlignment.Right
	end
	Theme.frame(report, "Rule", UDim2.new(1, -40, 0, 1), UDim2.fromOffset(20, 292), C.Osd, 0.7)
	local total = Theme.label(report, "Total", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 300), F.MonoBold, 18, C.Phosphor, `+{results.Xp} XP`)
	total.TextXAlignment = Enum.TextXAlignment.Right
	local level = results.TotalXp // X.PerLevel + 1
	Theme.label(report, "Level", UDim2.new(1, -40, 0, 20), UDim2.fromOffset(20, 302), F.Mono, 14, C.Osd, `LEVEL {level}  —  {RANKS[math.min(level, #RANKS)]}`)
	local fill = bar(report, "LevelBar", UDim2.new(1, -40, 0, 6), UDim2.fromOffset(20, 332), C.Phosphor)
	fill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(fill, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale((results.TotalXp % X.PerLevel) / X.PerLevel, 1) }):Play()
	local close = Theme.button(report, "Close", UDim2.fromOffset(200, 36), UDim2.new(0.5, -100, 1, -54), "CONTINUE")
	close.Modal = true
	local closed = false
	local function dismiss()
		if not closed then
			closed = true
			overlay:Destroy()
		end
	end
	close.MouseButton1Click:Connect(dismiss)
	task.delay(20, dismiss)
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
		text.FontFace = F.Serif
		text.TextSize = 54
		text.TextColor3 = C.Osd
		text.Text = Config.GameName .. "\n\n"
		text.MaxVisibleGraphemes = -1
		local tag = Theme.label(overlay, "Tag", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.3, 84), F.Mono, 16, C.Rec, Config.Tagline)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		task.wait(2.6)
		tag:Destroy()
		finish()
	end)
end

----------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------
local function build()
	gui = Theme.screen("HS_HUD", 30)
	blip = Sfx.make(gui, "Blip", { Volume = 0.3 })
	typeSound = Sfx.make(gui, "Type", { Volume = 0.25 })

	lobbyHint = Theme.label(gui, "LobbyHint", UDim2.new(0.6, 0, 0, 24), UDim2.new(0.2, 0, 0, 52), F.Mono, 15, C.Osd, "")
	lobbyHint.TextXAlignment = Enum.TextXAlignment.Center

	-- event line, top centre
	bannerHead = Theme.label(gui, "BannerHead", UDim2.new(0.6, 0, 0, 30), UDim2.new(0.2, 0, 0, 58), F.Serif, 25, C.Osd, "")
	bannerHead.TextXAlignment = Enum.TextXAlignment.Center
	bannerHead.TextStrokeTransparency = 0.5
	bannerRule = Theme.frame(gui, "BannerRule", UDim2.fromOffset(0, 1), UDim2.new(0.5, 0, 0, 92), C.Osd, 1)
	bannerRule.AnchorPoint = Vector2.new(0.5, 0)
	bannerSub = Theme.label(gui, "BannerSub", UDim2.new(0.6, 0, 0, 18), UDim2.new(0.2, 0, 0, 98), F.Mono, 12, C.Osd, "")
	bannerSub.TextXAlignment = Enum.TextXAlignment.Center
	bannerSub.TextTransparency = 0.25

	shiftGroup = Theme.frame(gui, "Shift", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)

	-- objectives card, top right
	card = panel(shiftGroup, "Objectives", UDim2.fromOffset(300, 118), UDim2.new(1, -324, 0, 56))
	local tag = Theme.label(card, "Tag", UDim2.new(1, -24, 0, 12), UDim2.fromOffset(12, 8), F.Osd, 7, C.Amber, "CASE OBJECTIVES")
	tag.TextXAlignment = Enum.TextXAlignment.Right
	photoLine = Theme.label(card, "Photo", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 26), F.MonoBold, 14, C.Osd, "")
	photoPips = pips(card, NEEDED, -8, 31, 8, false)
	sendLine = Theme.label(card, "Send", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 52), F.MonoBold, 14, C.Osd, "")
	sendPips = pips(card, NEEDED, -8, 57, 8, false)
	cardHint = Theme.label(card, "Hint", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 78), F.Mono, 11, C.Osd, "")
	cardHint.TextTransparency = 0.3
	-- vitals under the card
	local vitals = panel(shiftGroup, "Vitals", UDim2.fromOffset(300, 30), UDim2.new(1, -324, 0, 180))
	Theme.label(vitals, "Tag", UDim2.fromOffset(80, 12), UDim2.fromOffset(12, 10), F.Osd, 8, C.Osd, "VITALS")
	heartPips = pips(vitals, 5, -8, 8, 14, true)
	location = Theme.label(shiftGroup, "Location", UDim2.fromOffset(300, 16), UDim2.new(1, -324, 0, 216), F.Mono, 12, C.Amber, "")
	location.TextXAlignment = Enum.TextXAlignment.Right

	-- noise meter, bottom left
	local noise = panel(shiftGroup, "Noise", UDim2.fromOffset(190, 66), UDim2.new(0, 24, 1, -110))
	Theme.label(noise, "Tag", UDim2.fromOffset(160, 12), UDim2.fromOffset(12, 8), F.Osd, 8, C.Osd, "NOISE METER")
	for i = 1, 24 do
		table.insert(noiseBars, Theme.frame(noise, "Bar", UDim2.fromOffset(4, 16), UDim2.fromOffset(12 + (i - 1) * 7, 26), C.Osd, 0.85))
	end
	for i, word in { "QUIET", "NORMAL", "LOUD" } do
		local label = Theme.label(noise, word, UDim2.fromOffset(56, 10), UDim2.fromOffset(12 + (i - 1) * 56, 48), F.Osd, 6, if i == 3 then C.Rec else C.Osd, word)
		label.TextTransparency = 0.4
	end
	staminaFill = bar(shiftGroup, "Stamina", UDim2.fromOffset(190, 4), UDim2.new(0, 24, 1, -36), C.Osd)

	-- hotbar, bottom centre
	local function slot(index: number, name: string, key: string): Frame
		local frame = panel(shiftGroup, "Slot" .. index, UDim2.fromOffset(74, 40), UDim2.new(0.5, -117 + (index - 1) * 80, 1, -62))
		Theme.label(frame, "Key", UDim2.fromOffset(20, 10), UDim2.fromOffset(6, 5), F.Osd, 7, C.Amber, key)
		local label = Theme.label(frame, "Name", UDim2.new(1, 0, 0, 12), UDim2.fromOffset(0, 20), F.Osd, 8, C.Osd, name)
		label.TextXAlignment = Enum.TextXAlignment.Center
		return frame
	end
	slotCamera = slot(1, "CAMERA", "Q")
	slotLight = slot(2, "LIGHT", "F")
	local battery = slot(3, "BATT", "")
	batteryFill = bar(battery, "Battery", UDim2.new(1, -16, 0, 4), UDim2.fromOffset(8, 8), C.Osd)

	-- key hints, bottom right
	local hints = Theme.label(shiftGroup, "Hints", UDim2.fromOffset(240, 70), UDim2.new(1, -264, 1, -92), F.Mono, 11, C.Osd, "Q / RMB   Raise camcorder\nCLICK   Photograph\nC   Crouch      SHIFT   Sprint\nF   Flashlight")
	hints.TextXAlignment = Enum.TextXAlignment.Right
	hints.TextTransparency = 0.35
	hints.LineHeight = 1.25

	toasts = Theme.frame(gui, "Toasts", UDim2.new(0.6, 0, 0, 70), UDim2.new(0.2, 0, 1, -186), Color3.new(0, 0, 0), 1)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = toasts

	-- what it says, in its own typeface
	subtitle = Theme.label(gui, "Subtitle", UDim2.new(0.7, 0, 0, 34), UDim2.new(0.15, 0, 0.72, 0), F.Serif, 26, Color3.fromRGB(236, 226, 226), "")
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextStrokeTransparency = 0.3
	subtitle.Visible = false
	askPanel = panel(gui, "Ask", UDim2.fromOffset(200, 40), UDim2.new(0.5, -100, 0.72, 44))
	local askLabel = Theme.label(askPanel, "Label", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 8), F.MonoBold, 14, C.Osd, "[T]  ANSWER")
	askLabel.TextXAlignment = Enum.TextXAlignment.Center
	askFill = bar(askPanel, "Time", UDim2.new(1, -24, 0, 3), UDim2.fromOffset(12, 30), C.Osd)
	local askButton = Instance.new("TextButton")
	askButton.Size = UDim2.fromScale(1, 1)
	askButton.BackgroundTransparency = 1
	askButton.Text = ""
	askButton.Parent = askPanel
	askButton.MouseButton1Click:Connect(function()
		send("Answer")
		askedUntil = 0
	end)

	-- camcorder viewfinder
	viewfinder = Theme.frame(shiftGroup, "Viewfinder", UDim2.fromOffset(360, 240), UDim2.new(0.5, -180, 0.5, -120), Color3.new(0, 0, 0), 1)
	for _, corner in { { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } } do
		local h = Theme.frame(viewfinder, "H", UDim2.fromOffset(28, 2), UDim2.new(corner[1], if corner[3] > 0 then 0 else -28, corner[2], if corner[4] > 0 then 0 else -2), C.Osd, 0.1)
		local v = Theme.frame(viewfinder, "V", UDim2.fromOffset(2, 28), UDim2.new(corner[1], if corner[3] > 0 then 0 else -2, corner[2], if corner[4] > 0 then 0 else -28), C.Osd, 0.1)
		h.ZIndex, v.ZIndex = 2, 2
	end
	Theme.frame(viewfinder, "Dot", UDim2.fromOffset(4, 4), UDim2.new(0.5, -2, 0.5, -2), C.Osd, 0.2)
	recDot = Theme.frame(viewfinder, "RecDot", UDim2.fromOffset(10, 10), UDim2.fromOffset(10, 12), C.Rec, 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = recDot
	Theme.label(viewfinder, "Rec", UDim2.fromOffset(60, 14), UDim2.fromOffset(26, 10), F.Osd, 11, C.Osd, "REC")
	timecode = Theme.label(viewfinder, "Timecode", UDim2.fromOffset(160, 14), UDim2.new(1, -170, 0, 10), F.Osd, 10, C.Osd, "00:00:00")
	timecode.TextXAlignment = Enum.TextXAlignment.Right
	local shoot = Theme.button(viewfinder, "Shoot", UDim2.fromOffset(120, 34), UDim2.new(0.5, -60, 1, 14), "PHOTOGRAPH")
	shoot.Visible = UserInputService.TouchEnabled
	shoot.MouseButton1Click:Connect(function()
		player:SetAttribute("ShootRequest", os.clock())
	end)

	trackerStrip = Theme.frame(shiftGroup, "Tracker", UDim2.fromOffset(180, 4), UDim2.new(0.5, -90, 1, -84), C.Osd, 0.7)
	trackerDot = Theme.frame(trackerStrip, "Dot", UDim2.fromOffset(8, 14), UDim2.new(0.5, -4, 0, -5), C.Rec, 0)
	dazzleBar = bar(shiftGroup, "Dazzle", UDim2.fromOffset(90, 4), UDim2.new(0.5, -45, 0.56, 0), C.Amber)

	-- locker: hold your breath
	lockerPanel = panel(gui, "Locker", UDim2.fromOffset(360, 110), UDim2.new(0.5, -180, 0.58, 0))
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

	-- in its hands
	grabPanel = panel(gui, "Grab", UDim2.fromOffset(380, 84), UDim2.new(0.5, -190, 0.8, 0))
	grabHint = Theme.label(grabPanel, "Hint", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 10), F.MonoBold, 16, C.Osd, "")
	grabHint.TextXAlignment = Enum.TextXAlignment.Center
	grabFill = bar(grabPanel, "Progress", UDim2.new(1, -40, 0, 10), UDim2.fromOffset(20, 42), C.Osd)
	local grabButton = Instance.new("TextButton")
	grabButton.Size = UDim2.fromScale(1, 1)
	grabButton.BackgroundTransparency = 1
	grabButton.Text = ""
	grabButton.Modal = true
	grabButton.Parent = grabPanel
	grabButton.MouseButton1Down:Connect(function()
		send("Struggle")
	end)

	local fx = Theme.button(gui, "Fx", UDim2.fromOffset(110, 22), UDim2.new(0, 24, 1, -26), "FX: FULL")
	fx.TextSize = 8
	fx.MouseButton1Click:Connect(function()
		Vhs.ReducedFlashing = not Vhs.ReducedFlashing
		player:SetAttribute("ReducedFlashing", Vhs.ReducedFlashing)
		fx.Text = if Vhs.ReducedFlashing then "FX: REDUCED" else "FX: FULL"
	end)
end

local function setPips(list: { Frame }, lit: number, color: Color3)
	for i, pip in list do
		pip.BackgroundColor3 = if i <= lit then color else C.Osd
		pip.BackgroundTransparency = if i <= lit then 0 else 0.82
	end
end

local function update()
	local inShift = player:GetAttribute("InShift") == true
	local hidden = player:GetAttribute("Hidden") == true
	local grabbed = player:GetAttribute("Grabbed") == true
	shiftGroup.Visible = inShift and not grabbed
	lockerPanel.Visible = inShift and hidden
	grabPanel.Visible = inShift and grabbed
	askPanel.Visible = inShift and os.clock() < askedUntil
	if askPanel.Visible then
		askFill.Size = UDim2.fromScale(math.clamp((askedUntil - os.clock()) / askedFor, 0, 1), 1)
	end
	if not inShift then
		local O = Lore.Objectives
		lobbyHint.Text = if player:GetAttribute("PartyRole") then "" elseif workspace:GetAttribute("HS_Mode") == "Match" then O.LobbyMatch else O.Lobby
		return
	end
	lobbyHint.Text = ""

	-- objectives
	local phase = workspace:GetAttribute("HS_Phase")
	local photos = Theme.num(workspace, "HS_Photos", 0)
	local sentCount = Theme.num(workspace, "HS_Sent", 0)
	local O = Lore.Objectives
	if phase == "Return" then
		local left = math.max(0, math.ceil(Theme.num(workspace, "HS_ReturnEnds", 0) - workspace:GetServerTimeNow()))
		photoLine.Text = O.Return
		photoLine.TextColor3 = Color3.fromRGB(214, 40, 40)
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
	setPips(heartPips, Theme.num(player, "Hearts", 0), Color3.fromRGB(214, 40, 40))

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
		barFrame.BackgroundColor3 = if deadAir then C.Phosphor elseif i > 16 then Color3.fromRGB(214, 40, 40) else C.Osd
	end
	staminaFill.Size = UDim2.fromScale(math.clamp(Hud.Stamina, 0, 1), 1)
	local battery = Theme.num(player, "Battery", 1)
	batteryFill.Size = UDim2.fromScale(battery, 1)
	batteryFill.BackgroundColor3 = if battery < 0.2 then C.Rec else C.Osd
	slotCamera.BackgroundColor3 = if Hud.CameraUp then C.Osd else Color3.fromRGB(6, 7, 7)
	slotCamera.BackgroundTransparency = if Hud.CameraUp then 0.55 else 0.35
	slotLight.BackgroundColor3 = if Hud.LightOn then C.Osd else Color3.fromRGB(6, 7, 7)
	slotLight.BackgroundTransparency = if Hud.LightOn then 0.55 else 0.35

	viewfinder.Visible = Hud.CameraUp and not hidden
	local t = os.clock() - shiftJoinedAt
	timecode.Text = string.format("%02d:%02d:%02d", t // 60, t % 60, (t * 30) % 30)
	recDot.Visible = (t % 1.2) < 0.7

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
		lockerHint.Text = if near then "IT IS RIGHT OUTSIDE — HOLD [SPACE]" else "HIDDEN.  [SPACE] HOLD BREATH"
		lockerHint.TextColor3 = if near then C.Rec else C.Osd
		breathFill.BackgroundColor3 = if breath < 0.25 then C.Rec else C.Phosphor
	end
	if grabbed then
		local can = Theme.num(player, "BreakFrees", 0) > 0
		grabHint.Text = if can then "TAP [E] — BREAK FREE" else "IT HAS YOU."
		grabHint.TextColor3 = if can then C.Osd else Color3.fromRGB(214, 40, 40)
		local back = grabFill.Parent :: Frame
		back.Visible = can
		grabFill.Size = UDim2.fromScale(Theme.num(player, "GrabProgress", 0), 1)
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
