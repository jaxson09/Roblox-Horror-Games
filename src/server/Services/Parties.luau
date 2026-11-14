--!strict
--[[
	Parties — the lobby circles.

	Step into an empty circle and a setup screen opens: crew size, difficulty,
	chapter. Create the lobby and anyone who walks into the circle joins it.
	The Leave button (or walking out) takes you out. The creator can start at
	any time; when the lobby is full a 15 second countdown starts it for them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Parties = {}

export type Settings = { MaxPlayers: number, Difficulty: string, Part: number }
export type PadSpec = { Disc: BasePart, Center: Vector3, Radius: number, Label: TextLabel }

type Pad = {
	Index: number,
	Spec: PadSpec,
	State: string, -- "Empty" | "Config" | "Open"
	Host: Player?,
	Members: { Player },
	Settings: Settings,
	Countdown: number, -- seconds left, -1 when not counting
}

local pads: { Pad } = {}
local where: { [Player]: Pad } = {}
local lastLeft: { [Player]: number } = {}
local lastToast: { [Player]: number } = {}
local onStart: ({ Player }, Settings) -> ()
local canUse: (Player) -> boolean
local reentry: ((Player) -> ())? = nil

local function toast(player: Player, text: string)
	if os.clock() - (lastToast[player] or 0) > 4 then
		lastToast[player] = os.clock()
		Remotes.ToClient:FireClient(player, "Toast", text, "info")
	end
end

local function defaults(): Settings
	return { MaxPlayers = Config.Lobby.DefaultPlayers, Difficulty = "Normal", Part = 1 }
end

local function describe(settings: Settings): string
	local part = Config.Parts[settings.Part]
	return `{settings.MaxPlayers} MAX  ·  {Config.Difficulties[settings.Difficulty].Label}  ·  {part.Name}`
end

-- Mirrors a pad's state onto attributes (for the client UI) and its floating sign.
local function publish(pad: Pad)
	local disc = pad.Spec.Disc
	local names = {}
	for _, member in pad.Members do
		table.insert(names, member.DisplayName)
	end
	local host = pad.Host
	disc:SetAttribute("State", pad.State)
	disc:SetAttribute("HostName", if host then host.DisplayName else "")
	disc:SetAttribute("Count", #pad.Members)
	disc:SetAttribute("Max", pad.Settings.MaxPlayers)
	disc:SetAttribute("Difficulty", pad.Settings.Difficulty)
	disc:SetAttribute("PartNo", pad.Settings.Part)
	disc:SetAttribute("Countdown", if pad.Countdown < 0 then -1 else math.ceil(pad.Countdown))
	disc:SetAttribute("MemberNames", table.concat(names, "\n"))

	local label = pad.Spec.Label
	if reentry then
		label.Text = "GO BACK DOWN"
	elseif pad.State == "Empty" then
		label.Text = "STEP IN\nTO CREATE A LOBBY"
	elseif pad.State == "Config" then
		label.Text = `{if host then host.DisplayName else "SOMEONE"}\nIS SETTING UP...`
	else
		local status = if pad.Countdown >= 0 then `STARTING IN {math.ceil(pad.Countdown)}` else `{#pad.Members}/{pad.Settings.MaxPlayers} CREW`
		label.Text = `{if host then string.upper(host.DisplayName) else ""}'S LOBBY\n{describe(pad.Settings)}\n{status}`
	end
	for _, member in pad.Members do
		member:SetAttribute("PartyPad", pad.Index)
		member:SetAttribute("PartyRole", if pad.State == "Config" then "Config" elseif member == host then "Host" else "Member")
	end
end

local function clear(player: Player)
	where[player] = nil
	player:SetAttribute("PartyPad", 0)
	player:SetAttribute("PartyRole", nil)
end

local function reset(pad: Pad)
	pad.State = "Empty"
	pad.Host = nil
	table.clear(pad.Members)
	pad.Settings = defaults()
	pad.Countdown = -1
	publish(pad)
end

local function leave(player: Player, moveOut: boolean)
	local pad = where[player]
	if not pad then
		return
	end
	clear(player)
	lastLeft[player] = os.clock()
	local index = table.find(pad.Members, player)
	if index then
		table.remove(pad.Members, index)
	end
	if moveOut then
		-- put them just outside the circle, on the side they came from
		local character = player.Character
		if character then
			local spot = pad.Spec.Center + Vector3.new(0, 3, pad.Spec.Radius + 6)
			character:PivotTo(CFrame.lookAt(spot, spot + Vector3.new(0, 0, -1)))
		end
	end
	if #pad.Members == 0 or pad.State == "Config" then
		for _, member in table.clone(pad.Members) do
			clear(member)
		end
		reset(pad)
		return
	end
	if pad.Host == player then
		pad.Host = pad.Members[1] -- the lobby survives its creator leaving
	end
	pad.Countdown = -1
	publish(pad)
end

local function launch(pad: Pad)
	local members = table.clone(pad.Members)
	local settings = table.clone(pad.Settings)
	for _, member in members do
		clear(member)
		lastLeft[member] = os.clock() + 6 -- do not re-enter the circle while the screen fades
	end
	reset(pad)
	onStart(members, settings)
end

local function inside(pad: Pad, position: Vector3, margin: number): boolean
	local offset = position - pad.Spec.Center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= pad.Spec.Radius + margin and offset.Y > -3 and offset.Y < 10
end

local function step(dt: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local current = where[player]
		if not root or not canUse(player) then
			if current then
				leave(player, false)
			end
			continue
		end
		if current then
			if not inside(current, root.Position, 2) then
				leave(player, false) -- walked out of the circle
			end
			continue
		end
		if os.clock() - (lastLeft[player] or 0) < 1.5 then
			continue
		end
		for _, pad in pads do
			if not inside(pad, root.Position, 0) then
				continue
			end
			local again = reentry
			if again then
				lastLeft[player] = os.clock() + 4
				again(player)
			elseif pad.State == "Empty" then
				pad.State = "Config"
				pad.Host = player
				pad.Members = { player }
				where[player] = pad
				publish(pad)
			elseif pad.State == "Open" and #pad.Members < pad.Settings.MaxPlayers then
				table.insert(pad.Members, player)
				where[player] = pad
				publish(pad)
			elseif pad.State == "Open" then
				toast(player, "THAT LOBBY IS FULL.")
			else
				toast(player, "SOMEONE IS STILL SETTING UP THAT LOBBY.")
			end
			break
		end
	end

	for _, pad in pads do
		if pad.State ~= "Open" then
			continue
		end
		if #pad.Members >= pad.Settings.MaxPlayers then
			local before = math.ceil(pad.Countdown)
			if pad.Countdown < 0 then
				pad.Countdown = Config.Lobby.AutoStartSeconds
			else
				pad.Countdown -= dt
			end
			if pad.Countdown <= 0 then
				launch(pad)
			elseif math.ceil(pad.Countdown) ~= before then
				publish(pad)
			end
		elseif pad.Countdown >= 0 then
			pad.Countdown = -1
			publish(pad)
		end
	end
end

local function onMessage(player: Player, name: any, a: any, b: any, c: any)
	local pad = where[player]
	if type(name) ~= "string" or not pad then
		return
	end
	if name == "PartyLeave" then
		leave(player, true)
	elseif name == "PartyCreate" and pad.State == "Config" and pad.Host == player then
		local part = if type(c) == "number" then Config.Parts[c] else nil
		if type(a) ~= "number" or not table.find(Config.Lobby.PlayerOptions, a) or type(b) ~= "string" or not Config.Difficulties[b] then
			return
		end
		if not part or not part.Available then
			Remotes.ToClient:FireClient(player, "Toast", "THAT PART IS STILL IN DEVELOPMENT.", "info")
			return
		end
		pad.Settings = { MaxPlayers = a, Difficulty = b, Part = c }
		pad.State = "Open"
		publish(pad)
	elseif name == "PartyStart" and pad.State == "Open" and pad.Host == player then
		launch(pad)
	end
end

-- Match servers have no lobbies to form: the circles send returning players back down.
function Parties.setReentry(callback: ((Player) -> ())?)
	reentry = callback
	for _, pad in pads do
		publish(pad)
	end
end

function Parties.init(specs: { PadSpec }, start: ({ Player }, Settings) -> (), usable: (Player) -> boolean)
	onStart = start
	canUse = usable
	for index, spec in specs do
		local pad: Pad = { Index = index, Spec = spec, State = "Empty", Host = nil, Members = {}, Settings = defaults(), Countdown = -1 }
		table.insert(pads, pad)
		publish(pad)
	end
	Players.PlayerRemoving:Connect(function(player)
		leave(player, false)
		lastLeft[player] = nil
		lastToast[player] = nil
	end)
	Remotes.ToServer.OnServerEvent:Connect(onMessage)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			local ok, err = pcall(step, acc)
			if not ok then
				warn("[Parties] step failed:", err)
			end
			acc = 0
		end
	end)
end

return Parties
