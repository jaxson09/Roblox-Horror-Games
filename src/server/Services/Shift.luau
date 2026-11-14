--!strict
--[[
	Shift — one case, start to finish.

	  Idle     nobody on the ward. A lobby starting sends a crew up.
	  Case     photograph the subject (5), and send each piece of evidence out
	           through a pneumatic tube station (5). Both counts are shared by
	           the crew. Stations are loud and only hold two canisters each.
	  Return   all evidence sent: the elevator comes back, the power fails,
	           HUSH knows you are leaving. Reach the elevator before lockdown.
	  Ended    field reports, then the ward resets.

	Being caught is a grab, not a death: a close-up, a few seconds to wrench
	free (if you have a break-free left), otherwise you lose a heart and wake
	up strapped to a recovery bed somewhere else on the ward. No hearts left
	and it keeps you — and starts using your name.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Lore = require(ReplicatedStorage.Shared.Lore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Facility = require(script.Parent.Parent.World.Facility)
local Lobby = require(script.Parent.Parent.World.Lobby)
local Crew = require(script.Parent.Crew)
local Data = require(script.Parent.Data)
local Fawn = require(script.Parent.Fawn)
local Store = require(script.Parent.Store)

local Shift = {}

local S = Config.Shift
local P = Config.Player
local rng = Random.new()

local facility: Facility.Facility
local lobby: Lobby.Lobby

local phase = "Idle"
local shiftId = 0
local photos = 0
local sent = 0
local lastPhotoAt = 0
local returnEnds = 0
local wakeAt = 0
local endedAt = 0
local startedAt = 0
local scareReadyAt = 0
local difficulty: Config.Difficulty = Config.Difficulties.Normal
local difficultyKey = "Normal"
local onEnded: (() -> ())? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	workspace:SetAttribute("HS_Phase", phase)
	workspace:SetAttribute("HS_ShiftId", shiftId)
	workspace:SetAttribute("HS_Photos", photos)
	workspace:SetAttribute("HS_Sent", sent)
	workspace:SetAttribute("HS_Needed", S.PhotosNeeded)
	workspace:SetAttribute("HS_ReturnEnds", returnEnds)
	workspace:SetAttribute("HS_Difficulty", difficultyKey)
end

local function setPhase(name: string)
	phase = name
	publish()
end

local function toast(player: Player, text: string, kind: string?)
	Remotes.ToClient:FireClient(player, "Toast", text, kind or "info")
end

-- A big line at the top of one player's screen. `tone` colours it.
local function banner(player: Player, key: string, tone: string, a: any?, b: any?)
	local entry = Lore.Banners[key]
	if entry then
		Remotes.ToClient:FireClient(player, "Banner", string.format(entry[1], a, b), string.format(entry[2], a, b), tone)
	end
end

local function bannerShift(key: string, tone: string, a: any?, b: any?)
	for _, member in Crew.Members do
		if member.InShift then
			banner(member.Player, key, tone, a, b)
		end
	end
end

local function toastShift(text: string, kind: string?)
	for _, member in Crew.Members do
		if member.InShift then
			toast(member.Player, text, kind)
		end
	end
end

local function acting(player: Player): Crew.Member?
	local member = Crew.get(player)
	if member and Crew.isActive(member) and not member.Locker then
		return member
	end
	return nil
end

local function maxHearts(): number
	return difficulty.Hearts + 1 -- adrenaline can take you one over
end

----------------------------------------------------------------------------
-- Lockers
----------------------------------------------------------------------------
local function leaveLocker(member: Crew.Member)
	local locker = member.Locker
	if not locker then
		return
	end
	member.Locker = nil
	member.Exposed = false
	member.HoldingBreath = false
	member.Loud = 0
	locker.Occupant = nil
	locker.Prompt.Enabled = true
	member.Player:SetAttribute("FawnAtLocker", false)
	Crew.setAnchored(member.Player, false)
	Crew.teleport(member.Player, locker.ExitCF)
	Crew.sync(member)
	local sound = locker.Prompt.Parent and locker.Prompt.Parent:FindFirstChild("Locker") :: Sound?
	if sound then
		sound:Play()
	end
end

local function enterLocker(player: Player, locker: Facility.Locker)
	local member = acting(player)
	if not member or locker.Occupant then
		return
	end
	locker.Occupant = player
	locker.Prompt.Enabled = false
	member.Locker = locker
	member.Breath = P.BreathSeconds
	member.Loud = 0
	member.HoldingBreath = false
	Crew.setLight(member, false)
	Crew.teleport(player, locker.InsideCF)
	Crew.setAnchored(player, true)
	Fawn.onHide(member)
	Fawn.hear(locker.Position, 0.3)
	Crew.sync(member)
	local sound = locker.Prompt.Parent and locker.Prompt.Parent:FindFirstChild("Locker") :: Sound?
	if sound then
		sound:Play()
	end
end

----------------------------------------------------------------------------
-- Leaving the ward, one way or another
----------------------------------------------------------------------------
local function sendResults(member: Crew.Member, outcome: string)
	local X = Config.Xp
	local xp = member.Photos * X.Photo + member.Sent * X.Sent + member.Files * X.File + (if outcome == "Escaped" then X.Escaped else 0)
	local total = Data.addXp(member.Player, xp)
	Remotes.ToClient:FireClient(member.Player, "Results", {
		Outcome = outcome,
		Seconds = math.floor(os.clock() - member.JoinedAt),
		Photos = member.Photos,
		Sent = member.Sent,
		Files = member.Files,
		Caught = member.Caught,
		Xp = xp,
		TotalXp = total,
	})
end

local function returnToSurface(member: Crew.Member)
	local player = member.Player
	local spread = CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-4, 4))
	Crew.setAnchored(player, false)
	Crew.teleport(player, lobby.ReturnCFrame * spread)
end

local function eliminate(member: Crew.Member, outcome: string)
	if member.Eliminated or not member.InShift then
		return
	end
	leaveLocker(member)
	if member.Grabbed then
		Remotes.ToClient:FireClient(member.Player, "GrabEnd", false) -- or their camera stays on its face
	end
	member.Grabbed = false
	member.Recovering = false
	member.Eliminated = true
	member.InShift = false
	member.Player:SetAttribute("Hunted", false)
	Crew.setLight(member, false)
	Crew.sync(member)
	Fawn.addSkin(member.Player)
	sendResults(member, outcome)
	if outcome == "Taken" then
		toastShift(`{string.upper(member.Player.DisplayName)} HAS BEEN ADMITTED. IT HAS THEIR VOICE NOW.`, "bad")
	end
	task.delay(0.6, returnToSurface, member)
end

local function escape(member: Crew.Member)
	member.Recovering = false
	member.Escaped = true
	member.InShift = false
	member.Player:SetAttribute("Hunted", false)
	Crew.setLight(member, false)
	Crew.sync(member)
	Data.bump(member.Player, "Escapes", 1)
	sendResults(member, "Escaped")
	task.spawn(Data.save, member.Player)
	returnToSurface(member)
	toastShift(`{string.upper(member.Player.DisplayName)} MADE IT TO THE ELEVATOR.`, "good")
end

----------------------------------------------------------------------------
-- Grabs, hearts, recovery
----------------------------------------------------------------------------
local function catch(member: Crew.Member)
	if not Crew.isActive(member) then
		return
	end
	leaveLocker(member)
	local player = member.Player
	member.Grabbed = true
	member.GrabEnds = now() + S.GrabSeconds
	member.GrabProgress = 0
	member.Caught += 1
	player:SetAttribute("Hunted", false)
	player:SetAttribute("GrabProgress", 0)
	Crew.setLight(member, false)
	Crew.setAnchored(player, true)
	Crew.sync(member)
	Data.bump(player, "Caught", 1)
	Fawn.hold(S.GrabSeconds + 1.2) -- until they are out of its hands and gone
	local line = string.format(Lore.GrabLines[rng:NextInteger(1, #Lore.GrabLines)], string.upper(player.DisplayName))
	Remotes.ToClient:FireClient(player, "Grab", Fawn.model(), line, member.BreakFrees > 0, S.GrabSeconds)
	for _, other in Crew.Members do
		if other.InShift and other ~= member then
			toast(other.Player, `IT HAS {string.upper(player.DisplayName)}.`, "bad")
		end
	end
end

local function lockerFound(member: Crew.Member)
	local locker = member.Locker
	if locker then
		Remotes.ToClient:FireAllClients("Shake", 0.7, 0.4, locker.Position)
	end
	catch(member)
end

-- The bed farthest from HUSH (with a little randomness so it is not always the same one).
local function recoveryBed(): Facility.Bed
	local fawnPos = Fawn.position()
	local ranked = table.clone(facility.Beds)
	table.sort(ranked, function(a: Facility.Bed, b: Facility.Bed): boolean
		return (a.Position - fawnPos).Magnitude > (b.Position - fawnPos).Magnitude
	end)
	return ranked[rng:NextInteger(1, math.min(3, #ranked))]
end

local function resolveGrab(member: Crew.Member, brokeFree: boolean)
	local player = member.Player
	member.Grabbed = false
	member.GrabProgress = 0
	player:SetAttribute("GrabProgress", 0)
	if brokeFree then
		member.BreakFrees -= 1
		Crew.setAnchored(player, false)
		Crew.sync(member)
		Fawn.pause(3.2) -- it reels; you have a head start
		Remotes.ToClient:FireClient(player, "GrabEnd", true)
		banner(player, "BrokeFree", "good")
		return
	end
	member.Hearts -= 1
	if member.Hearts <= 0 then
		-- a banked adrenaline shot saves you once, automatically
		local profile = Data.get(player)
		if profile and profile.Keys > 0 then
			Data.addKeys(player, -1)
			member.Hearts = 1
			toast(player, `ADRENALINE. ({profile.Keys} SHOT(S) LEFT)`, "good")
		else
			Remotes.ToClient:FireClient(player, "GrabEnd", false)
			member.InShift = true
			eliminate(member, "Taken")
			return
		end
	end
	-- from here until they wake in a bed they are nobody's target
	member.Recovering = true
	Crew.sync(member)
	Remotes.ToClient:FireClient(player, "GrabEnd", false)
	local bed = recoveryBed()
	task.delay(0.9, function()
		if player.Parent and member.InShift and member.Recovering then
			Crew.teleport(player, bed.WakeCF)
			Crew.setAnchored(player, false)
			banner(player, "Recovery", "bad", member.Hearts)
		end
		member.Recovering = false
	end)
end

local function stepGrabs()
	for _, member in Crew.Members do
		if member.Grabbed and member.InShift then
			if member.BreakFrees > 0 and member.GrabProgress >= 0.999 then
				resolveGrab(member, true)
			elseif now() >= member.GrabEnds then
				resolveGrab(member, false)
			end
		end
	end
end

----------------------------------------------------------------------------
-- The job: photographs and tube stations
----------------------------------------------------------------------------
local function refreshStations()
	local carrying = photos - sent
	for _, station in facility.Stations do
		station.Prompt.Enabled = phase == "Case" and carrying > 0 and station.Left > 0
		station.Prompt.ActionText = if station.Left > 0 then `Send evidence ({station.Left} left)` else "Out of canisters"
	end
	workspace:SetAttribute("HS_Carrying", carrying)
end

local function startReturn()
	setPhase("Return")
	returnEnds = now() + S.ReturnSeconds
	refreshStations()
	Facility.setElevator(facility, true)
	bannerShift("Exit", "good")
	publish()
	-- a breath, then the lights go
	task.delay(5, function()
		if phase ~= "Return" then
			return
		end
		Remotes.ToClient:FireAllClients("PowerOut")
		Facility.setPower(facility, false)
		Fawn.setEnraged(true)
		bannerShift("Power", "bad")
	end)
end

local function takePhoto(member: Crew.Member, look: Vector3)
	local player = member.Player
	local pos = Crew.position(player)
	if not pos or os.clock() - member.LastPhotoAt < P.PhotoCooldown then
		return
	end
	member.LastPhotoAt = os.clock()
	-- the flash goes off whether or not anything was in frame, and it is not quiet
	for _, other in Crew.Members do
		if other.InShift then
			Remotes.ToClient:FireClient(other.Player, "Flash", pos, other == member)
		end
	end
	if Fawn.state() == "Dormant" then
		wakeAt = 0
	end
	Fawn.hear(pos, 1.1)

	local target = Fawn.position() + Vector3.new(0, 1.5, 0)
	local toward = target - (pos + Vector3.new(0, 1.5, 0))
	local inFrame = toward.Magnitude <= P.PhotoRange
		and look.Magnitude > 0.5
		and look.Unit:Dot(toward.Unit) >= P.PhotoAim
		and Grid.lineOfSight(facility.Map, pos.X, pos.Z, target.X, target.Z)
	if not inFrame then
		banner(player, "NoSubject", "info")
		return
	end
	if photos >= S.PhotosNeeded or phase ~= "Case" then
		toast(player, "YOU HAVE ALL THE PHOTOGRAPHS YOU NEED.", "info")
		return
	end
	if os.clock() - lastPhotoAt < P.PhotoSpacing then
		banner(player, "TooSoon", "info")
		return
	end
	lastPhotoAt = os.clock()
	photos += 1
	member.Photos += 1
	bannerShift(if photos >= S.PhotosNeeded then "PhotoAll" else "Photo", "good", photos, S.PhotosNeeded)
	refreshStations()
	publish()
end

local function sendEvidence(player: Player, station: Facility.Station)
	local member = acting(player)
	if not member or phase ~= "Case" or photos - sent <= 0 or station.Left <= 0 then
		return
	end
	sent += 1
	member.Sent += 1
	station.Left -= 1
	Facility.setStationLamp(station)
	local sound = station.Root:FindFirstChild("TubeSend") :: Sound?
	if sound then
		sound:Play()
	end
	Remotes.ToClient:FireAllClients("Shake", 0.4, 0.5, station.Position)
	Fawn.hear(station.Position, 2.4, true) -- the whole ward hears a canister go
	bannerShift("Sent", "good", sent, S.PhotosNeeded)
	refreshStations()
	publish()
	if sent >= S.PhotosNeeded then
		startReturn()
	end
end

local function searchCabinet(player: Player, cabinet: Facility.Cabinet)
	local member = acting(player)
	if not member then
		return
	end
	local sound = cabinet.Root:FindFirstChild("Locker") :: Sound?
	if sound then
		sound:Play()
	end
	Fawn.hear(cabinet.Position, 0.35)
	cabinet.Prompt.Enabled = false
	local file = cabinet.File
	if not file then
		toast(player, "NOTHING BUT DUST.", "info")
		return
	end
	cabinet.File = nil
	cabinet.Root:SetAttribute("HasFile", false)
	member.Files += 1
	local profile = Data.get(player)
	if profile then
		profile.Notes[file] = true
	end
	Remotes.ToClient:FireClient(player, "Note", file)
	toastShift(`CASE FILE RECOVERED — {string.upper(player.DisplayName)}`, "good")
end

local function takeBattery(item: Facility.Item, player: Player)
	local member = acting(player)
	if not member or not item.Root.Parent then
		return
	end
	Sfx.playAt(item.Root.Position, "Pickup", { Volume = 0.6, MaxDistance = 50 })
	item.Root:Destroy()
	member.Battery = math.min(1, member.Battery + P.BatteryPickup)
	player:SetAttribute("Battery", member.Battery)
	toast(player, "BATTERY +50%", "good")
end

----------------------------------------------------------------------------
-- Shift lifecycle
----------------------------------------------------------------------------
local function startShift()
	shiftId += 1
	photos, sent, lastPhotoAt, returnEnds = 0, 0, 0, 0
	startedAt = os.clock()
	wakeAt = os.clock() + S.GracePeriod + S.BriefingSeconds
	Facility.reset(facility)
	Fawn.reset()
	Fawn.setTuning(difficulty.Speed, difficulty.Hearing)
	local fileIds = {}
	for _, note in Lore.Notes do
		table.insert(fileIds, note.Id)
	end
	for _, item in Facility.stock(facility, rng, fileIds) do
		item.Prompt.Triggered:Connect(function(player)
			takeBattery(item, player)
		end)
	end
	setPhase("Case")
	refreshStations()
end

local function endShift()
	setPhase("Ended")
	endedAt = os.clock()
	Fawn.reset()
end

local function anyRiding(): boolean
	for _, member in Crew.Members do
		if member.Riding then
			return true
		end
	end
	return false
end

-- `fresh` is true for the ride that opens a new case.
local function descend(riders: { Player }, fresh: boolean)
	lobby.ElevatorSound:Play()
	local longest = S.ElevatorRideTime
	for i, player in riders do
		local member = Crew.get(player)
		if not member then
			continue
		end
		-- New investigators get the training tape, but only while it is safe to watch it:
		-- on the ride that opens a case, or while HUSH is still on its dock with time to spare.
		-- Nobody sits through a tape while their crew is already being hunted.
		local profile = Data.get(player)
		local timeToWatch = fresh or (Fawn.state() == "Dormant" and os.clock() + S.BriefingSeconds + 8 <= wakeAt)
		local briefing = timeToWatch and profile ~= nil and profile.Shifts < 2
		local seconds = if briefing then S.BriefingSeconds else S.ElevatorRideTime
		longest = math.max(longest, seconds)
		member.Riding = true
		Crew.setAnchored(player, true) -- they cannot see: do not let them wander
		Remotes.ToClient:FireClient(player, "Elevator", seconds, briefing)
		-- step out of the lift just as the screen comes back, never while it is still black
		task.delay(seconds - 0.6, function()
			member.Riding = false
			if not player.Parent or Crew.get(player) ~= member then
				return
			end
			Crew.setAnchored(player, false)
			if phase ~= "Case" then
				toast(player, "THE LIFT STOPPED. THE CASE UPSTAIRS IS OVER.", "info")
				return
			end
			-- going back up after being admitted: allowed, but on your last heart
			local returning = member.ShiftId == shiftId and member.Eliminated
			local breakFrees = difficulty.BreakFrees + (if Store.owns(player, "SecondWind") then 1 else 0)
			Crew.enterShift(member, shiftId, if returning then 1 else difficulty.Hearts, if returning then 0 else breakFrees)
			Data.bump(player, "Shifts", 1)
			local spawns = facility.ElevatorSpawns
			Crew.teleport(player, CFrame.new(spawns[(i - 1) % #spawns + 1])) -- default facing (-Z) looks out of the car
			if returning then
				toast(player, "YOU WENT BACK UP. ONE HEART. NO BREAK-FREE.", "bad")
			end
		end)
	end
	if fresh then
		-- HUSH stays on its dock until the first crew has had time to arrive and look around
		wakeAt = os.clock() + longest + S.GracePeriod
	end
end

-- Sends a crew up. Starts a new case on the chosen difficulty if none is running,
-- otherwise the crew joins the case already in progress.
function Shift.begin(players: { Player }, chosenDifficulty: string?): boolean
	if phase == "Return" or phase == "Ended" then
		for _, player in players do
			toast(player, "THE CASE UPSTAIRS IS WRAPPING UP. TRY AGAIN IN A MOMENT.", "info")
		end
		return false
	end
	local fresh = phase == "Idle"
	if fresh then
		difficultyKey = if chosenDifficulty and Config.Difficulties[chosenDifficulty] then chosenDifficulty else "Normal"
		difficulty = Config.Difficulties[difficultyKey]
		startShift()
	end
	descend(players, fresh)
	return true
end

-- May this player use the lobby circles right now?
function Shift.inLobby(player: Player): boolean
	local member = Crew.get(player)
	return member ~= nil and not member.InShift and not member.Riding
end

function Shift.onEnded(callback: () -> ())
	onEnded = callback
end

local function step(dt: number)
	Crew.step(dt, function(player)
		return Store.owns(player, "Flashlight")
	end)
	if phase == "Idle" then
		return
	end
	if phase == "Ended" then
		if os.clock() - endedAt > S.ResultsSeconds then
			Facility.reset(facility)
			setPhase("Idle")
			local ended = onEnded
			if ended then
				task.spawn(ended)
			end
		end
		return
	end
	if Fawn.state() == "Dormant" and os.clock() >= wakeAt then
		Fawn.wake()
		bannerShift("Watching", "bad")
	end
	Fawn.step(dt)
	stepGrabs()
	if phase == "Return" then
		for _, member in Crew.active() do
			local pos = Crew.position(member.Player)
			if pos and not member.Locker then
				local cx, cy = Facility.cellOf(facility, pos)
				if Grid.charAt(facility.Map, cx, cy) == "E" then
					escape(member)
				end
			end
		end
		if now() > returnEnds then
			for _, member in Crew.inPlay() do
				eliminate(member, "Lockdown")
			end
		end
	end
	-- nobody left on the ward and nobody on the way up: the case is over
	if #Crew.inPlay() == 0 and not anyRiding() and os.clock() - startedAt > 4 then
		endShift()
	end
end

----------------------------------------------------------------------------
-- Purchases with gameplay effects
----------------------------------------------------------------------------
local function crewBelowMax(): boolean
	for _, member in Crew.inPlay() do
		if member.Hearts < maxHearts() then
			return true
		end
	end
	return false
end

local function scanTargets(): { Instance }
	local targets: { Instance } = {}
	if phase == "Case" then -- stations are shut once the evidence is all sent
		for _, station in facility.Stations do
			if station.Left > 0 then
				table.insert(targets, station.Root)
			end
		end
	end
	for _, cabinet in facility.Cabinets do
		if cabinet.File then
			table.insert(targets, cabinet.Root)
		end
	end
	return targets
end

local function registerGrants()
	Store.registerGrant("Revive", function(player)
		local member = Crew.get(player)
		if member and member.InShift and member.Hearts < maxHearts() then
			member.Hearts += 1
			Crew.sync(member)
			toast(player, "ADRENALINE. ONE HEART BACK.", "good")
			return true
		end
		return false -- not usable right now: the Store banks it for later
	end)
	Store.registerGrant("ReviveAll", function(player)
		if not crewBelowMax() then
			return false
		end
		for _, member in Crew.inPlay() do
			if member.Hearts < maxHearts() then
				member.Hearts += 1
				Crew.sync(member)
			end
		end
		toastShift(`{string.upper(player.DisplayName)} CALLED A CRASH CART. ONE HEART BACK FOR EVERYONE.`, "good")
		return true
	end)
	Store.registerGrant("DeadAir", function(player)
		-- once it is enraged it hunts without listening: a sedative would do nothing
		if (phase ~= "Case" and phase ~= "Return") or Fawn.enraged() or Fawn.state() == "Dormant" then
			return false
		end
		Fawn.setDeadAir(os.clock() + Config.Fawn.DeadAirSeconds)
		workspace:SetAttribute("HS_DeadAirEnds", now() + Config.Fawn.DeadAirSeconds)
		toastShift(`{string.upper(player.DisplayName)} SEDATED IT. IT CANNOT HEAR YOU FOR {Config.Fawn.DeadAirSeconds}s.`, "good")
		return true
	end)
	Store.registerGrant("Sight", function(player)
		local targets = scanTargets()
		if #targets == 0 or (phase ~= "Case" and phase ~= "Return") then
			return false
		end
		for _, target in targets do
			local glow = Instance.new("Highlight")
			glow.FillColor = Config.Colors.Amber
			glow.OutlineColor = Config.Colors.Amber
			glow.FillTransparency = 0.5
			glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			glow.Parent = target
			Debris:AddItem(glow, 45)
		end
		toastShift(`{string.upper(player.DisplayName)} RAN THE SCANNER. STATIONS AND FILES ARE MARKED.`, "good")
		return true
	end)
	Store.registerGrant("ScareAll", function(player)
		scareReadyAt = os.clock() + 25
		Remotes.ToClient:FireAllClients("ScareAll", player.DisplayName)
		local member = Crew.get(player)
		local pos = Crew.position(player)
		if member and pos and Crew.isActive(member) then
			Fawn.howl()
			Fawn.hear(pos, 4, true) -- it answers the page
		end
		return true
	end)
end

-- Refuse to open a purchase that would do nothing right now.
local function offer(player: Player, kind: string)
	if kind == "ScareAll" then
		if os.clock() < scareReadyAt then
			toast(player, "THE PA IS STILL RINGING.", "store")
			return
		end
	elseif kind == "ReviveAll" then
		if not crewBelowMax() then
			toast(player, "NOBODY NEEDS IT. THE CART STAYS WHERE IT IS.", "store")
			return
		end
	elseif kind == "Sight" then
		if #scanTargets() == 0 then
			toast(player, "THERE IS NOTHING LEFT TO FIND.", "store")
			return
		end
	elseif kind == "DeadAir" then
		if Fawn.state() == "Dormant" then
			toast(player, "IT IS NOT LISTENING. YET.", "store")
			return
		elseif Fawn.enraged() then
			toast(player, "IT IS PAST HEARING. NOTHING WILL CALM IT NOW.", "store")
			return
		end
	end
	Store.prompt(player, kind)
end

local function refreshPriceLabels()
	local function withPrice(text: string, scope: "Product" | "Pass", key: string): string
		local price = Store.priceText(scope, key)
		return if price == "" then text else text .. "  " .. price
	end
	for _, dispenser in facility.Dispensers do
		dispenser.Prompt.ActionText = withPrice("Dispense", "Product", dispenser.Kind)
	end
	lobby.SirenPrompt.ActionText = withPrice("Page the building", "Product", "ScareAll")
	lobby.ShotPrompt.ActionText = withPrice("Dispense (kept for your next case)", "Product", "Revive")
	for _, item in lobby.ShopItems do
		local pass = Config.Passes[item.Key]
		item.Prompt.ActionText = withPrice("Buy", "Pass", item.Key)
		local price = Store.priceText("Pass", item.Key)
		item.Card.Text = pass.Name .. "\n" .. pass.Blurb .. (if price == "" then "" else "\n" .. price)
	end
end

----------------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------------
local function wireWorld()
	for _, door in facility.Doors do
		door.Prompt.Triggered:Connect(function(player)
			local member = acting(player)
			if not member then
				return
			end
			local slam = member.Sprinting
			Facility.setDoor(facility, door, not door.Open, slam)
			Fawn.hear(door.Position, if slam then 0.9 else 0.22)
		end)
	end
	for _, locker in facility.Lockers do
		locker.Prompt.Triggered:Connect(function(player)
			enterLocker(player, locker)
		end)
	end
	for _, station in facility.Stations do
		station.Prompt.Triggered:Connect(function(player)
			sendEvidence(player, station)
		end)
	end
	for _, cabinet in facility.Cabinets do
		cabinet.Prompt.Triggered:Connect(function(player)
			searchCabinet(player, cabinet)
		end)
	end
	for _, dispenser in facility.Dispensers do
		dispenser.Prompt.Triggered:Connect(function(player)
			if acting(player) then
				offer(player, dispenser.Kind)
			end
		end)
	end
	lobby.SirenPrompt.Triggered:Connect(function(player)
		offer(player, "ScareAll")
	end)
	lobby.ShotPrompt.Triggered:Connect(function(player)
		Store.prompt(player, "Revive") -- bought in the lobby it is banked for the next case
	end)
	for _, item in lobby.ShopItems do
		item.Prompt.Triggered:Connect(function(player)
			Store.promptPass(player, item.Key)
		end)
	end
end

local budgets: { [Player]: number } = {}

local function onMessage(player: Player, name: any, a: any)
	-- cheap flood guard: 40 messages per second per player
	budgets[player] = (budgets[player] or 0) + 1
	if budgets[player] > 40 then
		return
	end
	local member = Crew.get(player)
	if not member or type(name) ~= "string" then
		return
	end
	local on = a == true
	if name == "Sprint" then
		member.Sprinting = on
	elseif name == "Crouch" then
		member.Crouching = on
	elseif name == "Flashlight" then
		if Crew.isActive(member) and not member.Locker then
			Crew.setLight(member, on)
		end
	elseif name == "NightVision" then
		member.NightVision = on and Store.owns(player, "NightVision")
	elseif name == "HoldBreath" then
		member.HoldingBreath = on and member.Locker ~= nil and member.Breath > 0.25
	elseif name == "ExitLocker" then
		leaveLocker(member)
	elseif name == "Struggle" then
		-- one message per tap while it has you
		if member.Grabbed and member.BreakFrees > 0 then
			local taps = math.floor(member.GrabProgress * S.BreakFreeTaps + 0.5) + 1
			member.GrabProgress = math.min(1, taps / S.BreakFreeTaps)
			player:SetAttribute("GrabProgress", member.GrabProgress)
		end
	elseif name == "Photo" then
		if acting(player) and typeof(a) == "Vector3" then
			takePhoto(member, a)
		end
	elseif name == "Answer" then
		if os.clock() < member.AskedUntil and Crew.isActive(member) then
			member.AskedUntil = 0
			local pos = Crew.position(player)
			if pos then
				Fawn.hear(pos, 4, true)
			end
			banner(player, "Answered", "bad")
		end
	elseif name == "IntroSeen" then
		local profile = Data.get(player)
		if profile then
			profile.SeenIntro = true
			player:SetAttribute("SeenIntro", true)
		end
	elseif name == "Dazzle" then
		local pos = Crew.position(player)
		local fawnPos = Fawn.position()
		if not pos or not Crew.isActive(member) or not member.LightOn then
			return
		end
		if os.clock() < member.DazzleReadyAt or member.Battery < P.DazzleBatteryCost then
			return
		end
		local near = (pos - fawnPos).Magnitude <= P.DazzleRange + 6
		if near and Grid.lineOfSight(facility.Map, pos.X, pos.Z, fawnPos.X, fawnPos.Z) and Fawn.stagger(member) then
			member.DazzleReadyAt = os.clock() + P.DazzleCooldown
			member.Battery = math.max(0, member.Battery - P.DazzleBatteryCost)
			player:SetAttribute("Battery", member.Battery)
			player:SetAttribute("DazzleReadyAt", now() + P.DazzleCooldown)
			toast(player, "ITS LENS WHITES OUT. NOW IT IS ANGRY.", "bad")
		end
	end
end

-- HUSH asked this player a question. They have a few seconds in which answering is a mistake.
local function asked(member: Crew.Member, line: string)
	member.AskedUntil = os.clock() + 5
	Remotes.ToClient:FireClient(member.Player, "Asked", line, 5)
	for _, other in Crew.Members do
		if other.InShift and other ~= member then
			Remotes.ToClient:FireClient(other.Player, "Subtitle", line, true)
		end
	end
end

local function refreshBoard()
	local top = Data.topEscapes(8)
	local lines = { "INVESTIGATORS WHO CAME BACK", "" }
	if #top == 0 then
		table.insert(lines, "— no records yet —")
	end
	for i, entry in top do
		table.insert(lines, string.format("%d.  %s  —  %d", i, entry.Name, entry.Escapes))
	end
	lobby.BoardLabel.Text = table.concat(lines, "\n")
end

function Shift.init(theFacility: Facility.Facility, theLobby: Lobby.Lobby)
	facility = theFacility
	lobby = theLobby

	Fawn.init(facility, { OnCatch = catch, OnLockerFound = lockerFound, OnAsk = asked })
	registerGrants()
	wireWorld()
	refreshPriceLabels()
	Store.onPricesChanged(refreshPriceLabels)
	publish()

	local function onPlayer(player: Player)
		Crew.add(player, function(p)
			return Store.owns(p, "Veteran")
		end, function(member)
			eliminate(member, "Left")
		end)
		task.spawn(Data.load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local member = Crew.get(player)
		if member then
			if member.Locker then
				member.Locker.Occupant = nil
				member.Locker.Prompt.Enabled = true
			end
			-- anything still holding this member (e.g. HUSH's target) must see them as gone
			member.Locker = nil
			member.Grabbed = false
			member.InShift = false
		end
		budgets[player] = nil
		Crew.remove(player)
		Data.release(player)
	end)

	Remotes.ToServer.OnServerEvent:Connect(onMessage)

	local acc = 0
	local budgetClock = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		budgetClock += dt
		if budgetClock >= 1 then
			budgetClock = 0
			table.clear(budgets)
		end
		if acc >= 0.1 then
			local ok, err = pcall(step, acc)
			if not ok then
				warn("[Shift] step failed:", err)
			end
			acc = 0
		end
	end)

	task.spawn(function()
		while true do
			pcall(refreshBoard)
			task.wait(120)
		end
	end)
end

return Shift
