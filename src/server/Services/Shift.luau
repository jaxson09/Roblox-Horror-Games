--!strict
--[[
	Shift — the run itself.

	  Idle       nobody below. The lobby elevator starts a shift.
	  Blackout   find three fuses, install them at the breaker.
	  Tapes      power is on, FAWN is awake. Recover four voice reels.
	  Broadcast  load the reels at Control and hold the room while the
	             recall tone transmits (it draws FAWN to you).
	  Escape     blast door opens, FAWN is enraged, lockdown timer runs.
	  Ended      results, then the sublevel resets.

	Crews can drop in by elevator at any point before the escape. Caught players
	are caged in the Kennel: a teammate can free them, they get one free
	break-out, and after that the Rusted Key (the self-revive product).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Lore = require(ReplicatedStorage.Shared.Lore)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Facility = require(script.Parent.Parent.World.Facility)
local Lobby = require(script.Parent.Parent.World.Lobby)
local Crew = require(script.Parent.Crew)
local Data = require(script.Parent.Data)
local Fawn = require(script.Parent.Fawn)
local Store = require(script.Parent.Store)

local Shift = {}

local S = Config.Shift
local rng = Random.new()

local facility: Facility.Facility
local lobby: Lobby.Lobby

local phase = "Idle"
local shiftId = 0
local fuses = 0
local tapes = 0
local progress = 0
local drift = false
local nextDriftAt = 0
local escapeEnds = 0
local wakeAt = 0
local endedAt = 0
local startedAt = 0
local padTimer = -1
local nextLureAt = 0
local scareReadyAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	workspace:SetAttribute("HS_Phase", phase)
	workspace:SetAttribute("HS_ShiftId", shiftId)
	workspace:SetAttribute("HS_Fuses", fuses)
	workspace:SetAttribute("HS_Tapes", tapes)
	workspace:SetAttribute("HS_Progress", math.floor(progress * 100))
	workspace:SetAttribute("HS_Drift", drift)
	workspace:SetAttribute("HS_EscapeEnds", escapeEnds)
end

local function setPhase(name: string)
	phase = name
	publish()
end

local function toast(player: Player, text: string, kind: string?)
	Remotes.ToClient:FireClient(player, "Toast", text, kind or "info")
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

local function regionOf(position: Vector3): string?
	local cx, cy = Facility.cellOf(facility, position)
	return Grid.regionAt(MapData.Regions, cx, cy)
end

----------------------------------------------------------------------------
-- Lockers and cages
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
	member.Breath = Config.Player.BreathSeconds
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

local function refreshCage(cage: Facility.Cage)
	local occupied = #cage.Occupants > 0
	cage.RescuePrompt.Enabled = occupied
	cage.KeyPrompt.Enabled = occupied
end

local function leaveCage(member: Crew.Member): Facility.Cage?
	local cage = member.Cage
	if not cage then
		return nil
	end
	local index = table.find(cage.Occupants, member.Player)
	if index then
		table.remove(cage.Occupants, index)
	end
	member.Cage = nil
	member.CageEnds = 0
	member.Struggling = false
	member.StruggleProgress = 0
	member.Player:SetAttribute("StruggleProgress", 0)
	refreshCage(cage)
	return cage
end

local function free(member: Crew.Member, how: string)
	local cage = leaveCage(member)
	if not cage then
		return
	end
	Crew.sync(member)
	Crew.setAnchored(member.Player, false)
	Facility.setCageOpen(cage, true)
	Crew.teleport(member.Player, cage.ExitCF)
	toast(member.Player, how, "good")
	Fawn.hear(cage.Gate.Position, 0.5)
	task.delay(2.5, function()
		Facility.setCageOpen(cage, false)
	end)
end

local function sendResults(member: Crew.Member, outcome: string)
	local profile = Data.get(member.Player)
	Remotes.ToClient:FireClient(member.Player, "Results", {
		Outcome = outcome,
		Seconds = math.floor(os.clock() - member.JoinedAt),
		Reels = member.Reels,
		Fuses = member.Fuses,
		Rescues = member.Rescues,
		Escapes = if profile then profile.Escapes else 0,
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
	leaveCage(member)
	member.Eliminated = true
	member.InShift = false
	member.Player:SetAttribute("Hunted", false)
	Crew.setLight(member, false)
	Crew.sync(member)
	Fawn.addSkin(member.Player)
	sendResults(member, outcome)
	toastShift(`{member.Player.DisplayName} IS GONE. COUNT YOUR CREW.`, "bad")
	task.delay(0.6, returnToSurface, member)
end

local function escape(member: Crew.Member)
	member.Escaped = true
	member.InShift = false
	member.Player:SetAttribute("Hunted", false)
	Crew.setLight(member, false)
	Crew.sync(member)
	Data.bump(member.Player, "Escapes", 1)
	task.spawn(Data.save, member.Player)
	sendResults(member, "Escaped")
	returnToSurface(member)
	toastShift(`{member.Player.DisplayName} REACHED THE SURFACE.`, "good")
end

local function catch(member: Crew.Member)
	if not Crew.isActive(member) then
		return
	end
	leaveLocker(member)
	local player = member.Player
	local cage = facility.Cages[1]
	for _, candidate in facility.Cages do
		if #candidate.Occupants < #cage.Occupants then
			cage = candidate
		end
	end
	member.Cage = cage
	member.CagedAt = os.clock()
	member.CageEnds = now() + S.CageSeconds + 2
	member.Struggling = false
	member.StruggleProgress = 0
	table.insert(cage.Occupants, player)
	player:SetAttribute("Hunted", false)
	Crew.setLight(member, false)
	Crew.setAnchored(player, true)
	Crew.sync(member)
	Data.bump(player, "Caught", 1)
	Remotes.ToClient:FireClient(player, "Jumpscare", Fawn.model())
	for _, other in Crew.Members do
		if other.InShift and other ~= member then
			toast(other.Player, `{player.DisplayName} WAS TAKEN TO THE KENNEL.`, "bad")
		end
	end
	task.delay(2.1, function()
		if member.Cage == cage and player.Parent then
			Crew.setAnchored(player, false)
			Crew.teleport(player, cage.InsideCF)
			refreshCage(cage)
		end
	end)
end

local function lockerFound(member: Crew.Member)
	local locker = member.Locker
	if locker then
		Remotes.ToClient:FireAllClients("Shake", 0.7, 0.4, locker.Position)
	end
	catch(member)
end

local function stepCages(dt: number)
	for _, member in Crew.Members do
		local cage = member.Cage
		if not cage or not member.InShift then
			continue
		end
		if now() > member.CageEnds then
			eliminate(member, "Taken")
			continue
		end
		local canStruggle = member.StrugglesLeft > 0 and os.clock() - member.CagedAt > S.StruggleDelay
		member.Player:SetAttribute("CanStruggle", canStruggle)
		if member.Struggling and canStruggle then
			member.StruggleProgress += dt / S.StruggleHold
			if rng:NextNumber() < dt * 1.2 then
				Fawn.hear(cage.Gate.Position, 0.45)
				local rattle = cage.Gate:FindFirstChild("CageRattle") :: Sound?
				if rattle then
					rattle:Play()
				end
			end
			if member.StruggleProgress >= 1 then
				member.StrugglesLeft -= 1
				free(member, "YOU FORCED THE BARS.")
			end
		else
			member.StruggleProgress = math.max(0, member.StruggleProgress - dt * 0.4)
		end
		member.Player:SetAttribute("StruggleProgress", math.round(member.StruggleProgress * 100) / 100)
	end
end

----------------------------------------------------------------------------
-- Objectives
----------------------------------------------------------------------------
local function powerOn()
	if phase ~= "Blackout" then
		return
	end
	for _, socket in facility.BreakerSockets do
		socket.Color = Config.Colors.Amber
		socket.Material = Enum.Material.Neon
	end
	facility.BreakerPrompt.Enabled = false
	local box = facility.BreakerPrompt.Parent :: Instance
	local insert = box:FindFirstChild("FuseInsert") :: Sound?
	local hum = box:FindFirstChild("PowerUp") :: Sound?
	if insert then
		insert:Play()
	end
	setPhase("Tapes")
	task.delay(1.4, function()
		if phase ~= "Tapes" then
			return
		end
		if hum then
			hum:Play()
		end
		Remotes.ToClient:FireAllClients("Flicker", 2.2)
		Facility.setPower(facility, true)
		for _, door in facility.Doors do
			if door.Kind == "L" then
				Facility.unlockDoor(facility, door, false)
			end
		end
		for _, item in facility.Items do
			if item.Kind == "Reel" then
				item.Prompt.Enabled = true
				local led = item.Root:FindFirstChild("ReelLed") :: BasePart?
				if led then
					led.Color = Config.Colors.Phosphor
					local glow = led:FindFirstChildOfClass("PointLight")
					if glow then
						glow.Color = Config.Colors.Phosphor
					end
				end
			end
		end
		facility.ConsoleScreen.Text = "RECALL TONE\nLOAD 4 REELS"
		toastShift("POWER RESTORED. SOMETHING IN THE KENNEL HEARD IT.", "bad")
		-- the generator is the loudest thing down here
		wakeAt = 0
		Fawn.wake()
		Fawn.hear((box :: BasePart).Position, 4, true)
	end)
end

local function startBroadcast()
	setPhase("Broadcast")
	progress = 0
	drift = false
	nextDriftAt = os.clock() + rng:NextNumber(S.RetuneEvery[1], S.RetuneEvery[2])
	facility.ConsolePrompt.Enabled = false
	facility.ConsolePrompt.ActionText = "Retune"
	facility.ConsolePrompt.HoldDuration = 1.5
	local desk = facility.ConsolePrompt.Parent :: Instance
	local start = desk:FindFirstChild("TapeStart") :: Sound?
	local tone = desk:FindFirstChild("BroadcastTone") :: Sound?
	if start then
		start:Play()
	end
	if tone then
		tone:Play()
	end
	Fawn.setLure(facility.ConsolePosition)
	toastShift("TRANSMITTING. SHE ALWAYS COMES TO A VOICE.", "bad")
	publish()
end

local function startEscape()
	setPhase("Escape")
	escapeEnds = now() + S.EscapeSeconds
	drift = false
	facility.ConsolePrompt.Enabled = false
	facility.ConsoleScreen.Text = "RECALL TONE SENT\nEVACUATE"
	local desk = facility.ConsolePrompt.Parent :: Instance
	local tone = desk:FindFirstChild("BroadcastTone") :: Sound?
	if tone then
		tone:Stop()
	end
	for _, door in facility.Doors do
		if door.Kind ~= "D" then
			Facility.unlockDoor(facility, door, true)
		end
	end
	Facility.setAlarm(facility, true)
	Fawn.setLure(nil)
	Fawn.setEnraged(true)
	Remotes.ToClient:FireAllClients("Flicker", 1.5)
	toastShift("BLAST DOOR OPEN. RUN.", "bad")
	publish()
end

local function stepBroadcast(dt: number)
	local occupied = false
	for _, member in Crew.active() do
		local pos = Crew.position(member.Player)
		if pos and regionOf(pos) == "CONTROL" then
			occupied = true
			break
		end
	end
	workspace:SetAttribute("HS_ControlHeld", occupied)
	if occupied and not drift then
		progress = math.min(1, progress + dt / S.BroadcastSeconds)
	end
	if not drift and os.clock() >= nextDriftAt then
		drift = true
		facility.ConsolePrompt.Enabled = true
	end
	if os.clock() >= nextLureAt then
		nextLureAt = os.clock() + 5
		Fawn.hear(facility.ConsolePosition, 2.2, true)
	end
	local percent = math.floor(progress * 100)
	facility.ConsoleScreen.Text = if drift then "SIGNAL DRIFT\nRETUNE" else `RECALL TONE\n{percent}%`
	publish()
	if progress >= 1 then
		startEscape()
	end
end

local function stepEscape()
	local map = facility.Map
	for _, member in Crew.active() do
		local pos = Crew.position(member.Player)
		if pos and not member.Locker then
			local cx, cy = Facility.cellOf(facility, pos)
			if Grid.charAt(map, cx, cy) == "Z" then
				escape(member)
			end
		end
	end
	if now() > escapeEnds then
		for _, member in Crew.inPlay() do
			eliminate(member, "Lockdown")
		end
	end
end

local function onItem(item: Facility.Item, player: Player)
	local member = acting(player)
	if not member or not item.Root.Parent then
		return
	end
	local position = item.Root.Position
	local pickup = item.Root:FindFirstChild("Pickup") :: Sound?
	if item.Kind == "Note" then
		local profile = Data.get(player)
		if profile and item.Data then
			profile.Notes[item.Data] = true
		end
		Remotes.ToClient:FireClient(player, "Note", item.Data)
		return
	end
	if pickup then
		-- move the sound off the part so it survives the part being destroyed
		pickup.Parent = workspace.Terrain
		pickup:Play()
		Debris:AddItem(pickup, 3)
	end
	item.Root:Destroy()
	if item.Kind == "Battery" then
		member.Battery = math.min(1, member.Battery + Config.Player.BatteryPickup)
		player:SetAttribute("Battery", member.Battery)
		toast(player, "BATTERY +50%", "good")
	elseif item.Kind == "Fuse" then
		fuses += 1
		member.Fuses += 1
		toastShift(`FUSE {fuses}/{S.FusesNeeded}  —  {player.DisplayName}`, "info")
		Fawn.hear(position, 0.3)
		if fuses >= S.FusesNeeded then
			facility.BreakerPrompt.Enabled = true
		end
		publish()
	elseif item.Kind == "Reel" then
		tapes += 1
		member.Reels += 1
		Data.bump(player, "Reels", 1)
		local reel = Lore.Reels[math.min(tapes, #Lore.Reels)]
		for _, other in Crew.Members do
			if other.InShift then
				Remotes.ToClient:FireClient(other.Player, "Tape", tapes, reel.Title, reel.Body)
			end
		end
		Fawn.hear(position, 0.4)
		if tapes >= S.TapesNeeded then
			facility.ConsolePrompt.Enabled = true
			facility.ConsoleScreen.Text = "RECALL TONE\nREADY — LOAD REELS"
		end
		publish()
	end
end

----------------------------------------------------------------------------
-- Shift lifecycle
----------------------------------------------------------------------------
local function startShift()
	shiftId += 1
	fuses, tapes, progress, drift = 0, 0, 0, false
	escapeEnds = 0
	startedAt = os.clock()
	wakeAt = os.clock() + S.GracePeriod + 90 -- it also wakes when power returns
	Facility.reset(facility)
	Fawn.reset()
	local noteIds = {}
	for _, note in Lore.Notes do
		table.insert(noteIds, note.Id)
	end
	for i = #noteIds, 2, -1 do
		local j = rng:NextInteger(1, i)
		noteIds[i], noteIds[j] = noteIds[j], noteIds[i]
	end
	for _, item in Facility.spawnItems(facility, rng, noteIds) do
		item.Prompt.Triggered:Connect(function(player)
			onItem(item, player)
		end)
	end
	facility.ConsolePrompt.ActionText = "Load reels"
	facility.ConsolePrompt.HoldDuration = 2
	setPhase("Blackout")
end

local function endShift()
	setPhase("Ended")
	endedAt = os.clock()
	Fawn.setLure(nil)
	Fawn.reset()
	local desk = facility.ConsolePrompt.Parent :: Instance
	local tone = desk:FindFirstChild("BroadcastTone") :: Sound?
	if tone then
		tone:Stop()
	end
end

local function descend(riders: { Player })
	if phase == "Idle" then
		startShift()
	end
	lobby.ElevatorSound:Play()
	for i, player in riders do
		Remotes.ToClient:FireClient(player, "Elevator", S.ElevatorRideTime)
		task.delay(1.3, function()
			local member = Crew.get(player)
			if not member or not player.Parent or (phase ~= "Blackout" and phase ~= "Tapes" and phase ~= "Broadcast") then
				return
			end
			-- going back down after being taken: allowed, but on borrowed time
			local returning = member.ShiftId == shiftId and member.Eliminated
			Crew.enterShift(member, shiftId, if Store.owns(player, "SecondWind") then 1 else 0)
			if returning then
				member.StrugglesLeft = 0
				Crew.sync(member)
				toast(player, "YOU WENT BACK DOWN. NO FREE BREAK-OUT THIS TIME.", "bad")
			end
			Data.bump(player, "Shifts", 1)
			local spawns = facility.ElevatorSpawns
			local spot = spawns[(i - 1) % #spawns + 1]
			Crew.teleport(player, CFrame.new(spot)) -- default facing (-Z) looks at the bay door
			task.delay(S.ElevatorRideTime, toast, player, Lore.Tips[rng:NextInteger(1, #Lore.Tips)], "info")
		end)
	end
end

local function stepElevator(dt: number)
	local riders = {}
	for _, player in Players:GetPlayers() do
		local member = Crew.get(player)
		local pos = Crew.position(player)
		if member and pos and not member.InShift then
			local offset = pos - lobby.PadCenter
			if math.abs(offset.X) < lobby.PadSize.X / 2 and math.abs(offset.Z) < lobby.PadSize.Z / 2 and offset.Y > -2 and offset.Y < 12 then
				table.insert(riders, player)
			end
		end
	end
	local label = lobby.CountdownLabel
	if phase == "Escape" or phase == "Ended" then
		padTimer = -1
		label.Text = "FREIGHT 01\nLOCKED — SHIFT ENDING"
	elseif #riders == 0 then
		padTimer = -1
		label.Text = if phase == "Idle" then "FREIGHT 01\nSTEP ON TO DESCEND" else "FREIGHT 01\nSHIFT IN PROGRESS — STEP ON TO JOIN"
	else
		if padTimer < 0 then
			padTimer = S.ElevatorCountdown
		end
		padTimer -= dt
		label.Text = `DESCENDING IN {math.max(0, math.ceil(padTimer))}\nCREW ABOARD: {#riders}`
		if padTimer <= 0 then
			padTimer = -1
			descend(riders)
		end
	end
	workspace:SetAttribute("HS_PadTimer", math.ceil(padTimer))
end

local function step(dt: number)
	stepElevator(dt)
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
		end
		return
	end
	if Fawn.state() == "Dormant" and os.clock() >= wakeAt then
		Fawn.wake()
	end
	Fawn.step(dt)
	stepCages(dt)
	if phase == "Broadcast" then
		stepBroadcast(dt)
	elseif phase == "Escape" then
		stepEscape()
	end
	if #Crew.inPlay() == 0 and os.clock() - startedAt > 4 then
		endShift()
	end
end

----------------------------------------------------------------------------
-- Purchases with gameplay effects
----------------------------------------------------------------------------
local function cagedCount(): number
	local count = 0
	for _, member in Crew.Members do
		if member.Cage and member.InShift then
			count += 1
		end
	end
	return count
end

local function sightTargets(): { Instance }
	local targets: { Instance } = {}
	for _, item in facility.Items do
		if item.Root.Parent and (item.Kind == "Fuse" or item.Kind == "Reel") then
			table.insert(targets, item.Root)
		end
	end
	if phase == "Blackout" and fuses >= S.FusesNeeded and facility.BreakerPrompt.Parent then
		table.insert(targets, facility.BreakerPrompt.Parent)
	end
	if phase == "Tapes" and tapes >= S.TapesNeeded and facility.ConsolePrompt.Parent then
		table.insert(targets, facility.ConsolePrompt.Parent)
	end
	return targets
end

local function registerGrants()
	Store.registerGrant("Revive", function(player)
		local member = Crew.get(player)
		if member and member.Cage and member.InShift then
			free(member, "THE KEY TURNS.")
			return true
		end
		return false
	end)
	Store.registerGrant("ReviveAll", function(player)
		if cagedCount() == 0 then
			return false
		end
		for _, member in Crew.Members do
			if member.Cage and member.InShift then
				free(member, `{player.DisplayName} MADE AN OFFERING. EVERY CAGE OPENS.`)
			end
		end
		return true
	end)
	Store.registerGrant("DeadAir", function(player)
		if phase == "Idle" or phase == "Ended" then
			return false
		end
		Fawn.setDeadAir(os.clock() + Config.Fawn.DeadAirSeconds)
		workspace:SetAttribute("HS_DeadAirEnds", now() + Config.Fawn.DeadAirSeconds)
		toastShift(`{player.DisplayName} MADE AN OFFERING. DEAD AIR — SHE CANNOT HEAR YOU FOR {Config.Fawn.DeadAirSeconds}s.`, "good")
		return true
	end)
	Store.registerGrant("Sight", function(player)
		local targets = sightTargets()
		if #targets == 0 then
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
		toastShift(`{player.DisplayName} MADE AN OFFERING. WHAT YOU SEEK SHOWS ITSELF.`, "good")
		return true
	end)
	Store.registerGrant("ScareAll", function(player)
		scareReadyAt = os.clock() + 25
		Remotes.ToClient:FireAllClients("ScareAll", player.DisplayName)
		local member = Crew.get(player)
		local pos = Crew.position(player)
		if member and pos and Crew.isActive(member) then
			Fawn.howl()
			Fawn.hear(pos, 4, true) -- it answers
		end
		return true
	end)
end

-- Refuse to open a purchase that would do nothing right now.
local function offer(player: Player, kind: string)
	if kind == "ScareAll" then
		if os.clock() < scareReadyAt then
			toast(player, "THE SIREN IS STILL RINGING.", "store")
			return
		end
	elseif kind == "ReviveAll" then
		if cagedCount() == 0 then
			toast(player, "NO ONE IS CAGED. THE EFFIGY WANTS NOTHING.", "store")
			return
		end
	elseif kind == "Sight" then
		if #sightTargets() == 0 then
			toast(player, "THERE IS NOTHING LEFT TO FIND.", "store")
			return
		end
	elseif kind == "DeadAir" then
		if Fawn.state() == "Dormant" then
			toast(player, "NOTHING IS LISTENING. YET.", "store")
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
	for _, effigy in facility.Effigies do
		effigy.Prompt.ActionText = withPrice("Leave an offering", "Product", effigy.Kind)
	end
	for _, cage in facility.Cages do
		cage.KeyPrompt.ActionText = withPrice("Take", "Product", "Revive")
	end
	lobby.SirenPrompt.ActionText = withPrice("Crank the siren", "Product", "ScareAll")
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
			if not member or door.Locked then
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
	for _, cage in facility.Cages do
		cage.RescuePrompt.Triggered:Connect(function(player)
			local rescuer = acting(player)
			if not rescuer then
				return
			end
			local freed = 0
			for _, occupant in table.clone(cage.Occupants) do
				local member = Crew.get(occupant)
				if member then
					free(member, `{player.DisplayName} OPENED YOUR CAGE.`)
					freed += 1
				end
			end
			if freed > 0 then
				rescuer.Rescues += freed
				Data.bump(player, "Rescues", freed)
			end
		end)
		cage.KeyPrompt.Triggered:Connect(function(player)
			local member = Crew.get(player)
			if not member or not member.Cage then
				return
			end
			local profile = Data.get(player)
			if profile and profile.Keys > 0 then
				Data.addKeys(player, -1)
				free(member, `THE KEY TURNS. ({profile.Keys} LEFT)`)
			else
				offer(player, "Revive")
			end
		end)
	end
	for _, effigy in facility.Effigies do
		effigy.Prompt.Triggered:Connect(function(player)
			if acting(player) then
				offer(player, effigy.Kind)
			end
		end)
	end
	facility.BreakerPrompt.Triggered:Connect(function(player)
		if acting(player) and fuses >= S.FusesNeeded then
			powerOn()
		end
	end)
	facility.ConsolePrompt.Triggered:Connect(function(player)
		if not acting(player) then
			return
		end
		if phase == "Tapes" and tapes >= S.TapesNeeded then
			startBroadcast()
		elseif phase == "Broadcast" and drift then
			drift = false
			facility.ConsolePrompt.Enabled = false
			nextDriftAt = os.clock() + rng:NextNumber(S.RetuneEvery[1], S.RetuneEvery[2])
			publish()
		end
	end)
	lobby.SirenPrompt.Triggered:Connect(function(player)
		offer(player, "ScareAll")
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
		member.Struggling = on and member.Cage ~= nil
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
		if os.clock() < member.DazzleReadyAt or member.Battery < Config.Player.DazzleBatteryCost then
			return
		end
		local near = (pos - fawnPos).Magnitude <= Config.Player.DazzleRange + 6
		if near and Grid.lineOfSight(facility.Map, pos.X, pos.Z, fawnPos.X, fawnPos.Z) and Fawn.stagger(member) then
			member.DazzleReadyAt = os.clock() + Config.Player.DazzleCooldown
			member.Battery = math.max(0, member.Battery - Config.Player.DazzleBatteryCost)
			player:SetAttribute("Battery", member.Battery)
			player:SetAttribute("DazzleReadyAt", now() + Config.Player.DazzleCooldown)
			toast(player, "HER OPTICS WHITE OUT. NOW SHE IS ANGRY.", "bad")
		end
	end
end

local function refreshBoard()
	local top = Data.topEscapes(8)
	local lines = { "CREWS WHO CAME BACK UP", "" }
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

	Fawn.init(facility, { OnCatch = catch, OnLockerFound = lockerFound })
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
			leaveCage(member)
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
