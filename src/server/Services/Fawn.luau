--!strict
--[[
	Fawn — the monster's brain.

	  Dormant      asleep in the kennel until the crew makes itself known
	  Patrol       wanders, drifting toward wherever the crew is; howls; mimics
	  Investigate  walks to a noise it heard
	  Search       prowls an area, lingering at lockers and listening for breath
	  Chase        has eyes on someone
	  Stagger      optics whited out by a flashlight

	It navigates on the cell grid (Grid.findPath), opens doors by slamming
	them, and during the escape it is Enraged: faster, and it always knows
	where the nearest survivor is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Lore = require(ReplicatedStorage.Shared.Lore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Facility = require(script.Parent.Parent.World.Facility)
local FawnRig = require(script.Parent.Parent.World.FawnRig)
local Crew = require(script.Parent.Crew)

local Fawn = {}

export type Hooks = {
	OnCatch: (Crew.Member) -> (),
	OnLockerFound: (Crew.Member) -> (),
}

type Decoy = { Model: Model, Position: Vector3, ExpiresAt: number }

local F = Config.Fawn
local rng = Random.new()

local facility: Facility.Facility
local rig: FawnRig.Rig
local hooks: Hooks

local state = "Dormant"
local target: Crew.Member? = nil
local lastSeenAt = 0
local lastKnown = Vector3.zero
local goal: Vector3? = nil
local path: { number } = {}
local pathGoalIdx = 0
local pathAt = 0
local stateUntil = 0
local pauseUntil = 0
local staggerUntil = 0
local enraged = false
local deadAirUntil = 0
local nextHowlAt = 0
local nextMimicAt = 0
local lastShriekAt = 0
local lureActive = false
local lurePos = Vector3.zero
local nextLureAt = 0
local searchCenter = Vector3.zero
local lingerUntil = 0
local doorOpenAt = 0 -- 0 = not waiting at a door
local patrolPickedAt = 0
local stuckAnchor = Vector3.zero
local stuckSince = 0
local skins: { Player } = {}
local decoys: { Decoy } = {}

local function log(...: any)
	if Config.Debug then
		print("[FAWN]", ...)
	end
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function speedFor(name: string): number
	if name == "Patrol" then
		return F.PatrolSpeed
	elseif name == "Investigate" or name == "Search" then
		return F.InvestigateSpeed
	elseif name == "Chase" then
		return if enraged then F.EnragedSpeed else F.ChaseSpeed
	end
	return 0
end

local function setState(name: string)
	if state == name then
		return
	end
	log(state, "->", name)
	state = name
	rig.Model:SetAttribute("State", name)
	workspace:SetAttribute("HS_FawnState", name)
	rig.Humanoid.WalkSpeed = speedFor(name)
	path = {}
	pathGoalIdx = 0
	doorOpenAt = 0
	if name ~= "Chase" and target then
		target.Player:SetAttribute("Hunted", false)
		target = nil
	end
end

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

function Fawn.position(): Vector3
	return rig.Root.Position
end

function Fawn.model(): Model
	return rig.Model
end

function Fawn.state(): string
	return state
end

local function playHowl(key: string)
	local sound = rig.Sounds[key]
	if sound then
		sound.PlaybackSpeed = rng:NextNumber(0.92, 1.06)
		sound:Play()
	end
	rig.Model:SetAttribute("HowlAt", workspace:GetServerTimeNow())
end

-- The long one. It stops walking to do it.
function Fawn.howl()
	if state == "Dormant" then
		return
	end
	playHowl("Howl" .. rng:NextInteger(1, 3))
	pauseUntil = os.clock() + 2.4
end

local function shriek()
	local now = os.clock()
	if now - lastShriekAt > 5 then
		lastShriekAt = now
		playHowl("Shriek")
	end
end

----------------------------------------------------------------------------
-- Movement
----------------------------------------------------------------------------
local function cellPoint(idx: number, y: number): Vector3
	local cx, cy = Grid.coords(facility.Map, idx)
	local x, z = Grid.cellCenter(facility.Map, cx, cy)
	return Vector3.new(x, y, z)
end

local function moveToward(point: Vector3, direct: boolean)
	local map = facility.Map
	local now = os.clock()
	local pos = rig.Root.Position
	local sx, sy = Grid.worldToCell(map, pos.X, pos.Z)
	local rawX, rawY = Grid.worldToCell(map, point.X, point.Z)
	local gx = math.clamp(rawX, 1, map.Width)
	local gy = math.clamp(rawY, 1, map.Height)
	local goalIdx = Grid.index(map, gx, gy)
	if goalIdx ~= pathGoalIdx or now - pathAt > 0.8 then
		path = Grid.findPath(map, sx, sy, gx, gy) or {}
		pathGoalIdx = goalIdx
		pathAt = now
	end
	while #path > 0 and flat(pos, cellPoint(path[1], pos.Y)) < 3.4 do
		table.remove(path, 1)
	end

	-- slam open any door in the next couple of cells
	for i = 1, math.min(2, #path) do
		local door = facility.Doors[path[i]]
		if door and not door.Open and not door.Locked and flat(pos, door.Position) < 10 then
			if doorOpenAt == 0 then
				doorOpenAt = now + 0.55
			elseif now >= doorOpenAt then
				doorOpenAt = 0
				Facility.setDoor(facility, door, true, true)
				Remotes.ToClient:FireAllClients("Shake", 0.5, 0.35, door.Position)
			end
			break
		end
	end

	local nextPoint: Vector3
	if direct or #path == 0 then
		nextPoint = Vector3.new(point.X, pos.Y, point.Z)
	else
		nextPoint = cellPoint(path[1], pos.Y)
	end
	rig.Humanoid:MoveTo(nextPoint)

	-- unstick: if it has not moved for a while, drop it on the nearest cell centre
	if flat(pos, stuckAnchor) > 1.5 then
		stuckAnchor = pos
		stuckSince = now
	elseif now - stuckSince > 3.5 and rig.Humanoid.WalkSpeed > 0 and flat(pos, point) > 6 then
		local cx, cy = Grid.nearestPassable(map, sx, sy)
		local x, z = Grid.cellCenter(map, cx, cy)
		rig.Model:PivotTo(CFrame.new(x, facility.FloorY + FawnRig.RootHeight, z))
		stuckSince = now
		path = {}
		pathGoalIdx = 0
		log("unstuck")
	end
end

----------------------------------------------------------------------------
-- Senses
----------------------------------------------------------------------------
local function canSee(member: Crew.Member, pos: Vector3): boolean
	local me = rig.Root.Position
	local distance = flat(me, pos)
	local range = if member.LightOn then F.SightRangeFlashlight else F.SightRange
	if member.Crouching and not member.LightOn then
		range *= 0.55
	end
	if distance > range then
		return false
	end
	if not Grid.lineOfSight(facility.Map, me.X, me.Z, pos.X, pos.Z) then
		return false
	end
	if distance <= F.CloseSense then
		return true
	end
	local toward = Vector3.new(pos.X - me.X, 0, pos.Z - me.Z).Unit
	return rig.Root.CFrame.LookVector:Dot(toward) > 0.15
end

local function canHear(member: Crew.Member, pos: Vector3): boolean
	if os.clock() < deadAirUntil or member.Noise <= 0.05 then
		return false
	end
	local me = rig.Root.Position
	local radius = member.Noise * F.HearRadius
	if not Grid.lineOfSight(facility.Map, me.X, me.Z, pos.X, pos.Z) then
		radius *= F.WallMuffle
	end
	return flat(me, pos) <= radius
end

local function investigate(position: Vector3)
	setState("Investigate")
	goal = position
	stateUntil = os.clock() + 22
end

local function startSearch(position: Vector3)
	setState("Search")
	searchCenter = position
	goal = position
	stateUntil = os.clock() + F.SearchSeconds
	lingerUntil = 0
end

-- A noise that is not a footstep: doors, lockers, cages, the console.
function Fawn.hear(position: Vector3, loudness: number, ignoreDeadAir: boolean?)
	if state == "Dormant" or state == "Chase" or state == "Stagger" then
		return
	end
	if os.clock() < deadAirUntil and not ignoreDeadAir then
		return
	end
	local me = rig.Root.Position
	local radius = loudness * F.HearRadius
	if not Grid.lineOfSight(facility.Map, me.X, me.Z, position.X, position.Z) then
		radius *= F.WallMuffle
	end
	if flat(me, position) <= radius then
		investigate(position)
	end
end

----------------------------------------------------------------------------
-- Mimicry
----------------------------------------------------------------------------
local function mimicName(): string?
	for i = #skins, 1, -1 do
		if skins[i].Parent == nil then
			table.remove(skins, i)
		end
	end
	if #skins > 0 and rng:NextNumber() < 0.7 then
		return skins[rng:NextInteger(1, #skins)].DisplayName
	end
	local crew = Crew.inPlay()
	if #crew == 0 then
		return nil
	end
	return crew[rng:NextInteger(1, #crew)].Player.DisplayName
end

local function voiceLure()
	local name = mimicName()
	if not name then
		return
	end
	local line = string.format(Lore.MimicLines[rng:NextInteger(1, #Lore.MimicLines)], name)
	local sound = rig.Sounds["Mimic" .. rng:NextInteger(1, 2)]
	if sound then
		sound.PlaybackSpeed = rng:NextNumber(0.85, 1.1)
		sound:Play()
	end
	local me = rig.Root.Position
	for _, member in Crew.inPlay() do
		local pos = Crew.position(member.Player)
		if pos and flat(pos, me) < 150 then
			Remotes.ToClient:FireClient(member.Player, "Subtitle", line, true)
		end
	end
end

local function removeDecoy(index: number, reveal: boolean)
	local decoy = decoys[index]
	table.remove(decoys, index)
	if reveal then
		Sfx.playAt(decoy.Position + Vector3.new(0, 4, 0), "FawnShriek", { Volume = 1.6, MinDistance = 30, MaxDistance = 300 })
		Remotes.ToClient:FireAllClients("DecoyReveal", decoy.Position)
		decoy.Model:SetAttribute("Revealed", true)
		Fawn.hear(decoy.Position, 1.6, true)
		task.delay(0.45, function()
			decoy.Model:Destroy()
		end)
	else
		decoy.Model:Destroy()
	end
end

-- Stands a copy of someone you know at the end of a corridor, facing away.
local function spawnDecoy()
	if #decoys >= 2 or #facility.MimicSpots == 0 then
		return
	end
	local crew = Crew.inPlay()
	if #crew == 0 then
		return
	end
	-- prefer wearing someone it has already taken
	local source: Player = crew[rng:NextInteger(1, #crew)].Player
	if #skins > 0 and rng:NextNumber() < 0.75 then
		source = skins[rng:NextInteger(1, #skins)]
	end
	local character = source.Character
	if not character then
		return
	end

	local me = rig.Root.Position
	local best: Vector3? = nil
	for _ = 1, 8 do
		local spot = facility.MimicSpots[rng:NextInteger(1, #facility.MimicSpots)]
		local ok = flat(spot, me) > 30
		for _, member in Crew.active() do
			local pos = Crew.position(member.Player)
			if pos and (flat(pos, spot) < 28 or Grid.lineOfSight(facility.Map, pos.X, pos.Z, spot.X, spot.Z)) then
				ok = false
			end
		end
		if ok then
			best = spot
			break
		end
	end
	if not best then
		return
	end

	character.Archivable = true
	local clone = character:Clone() :: Model
	character.Archivable = false
	clone.Name = "Crewmate"
	for _, item in clone:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ForceField") or item:IsA("Sound") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		elseif item:IsA("SpotLight") then
			(item :: SpotLight).Enabled = false
		elseif item:IsA("BillboardGui") then
			(item :: BillboardGui).PlayerToHideFrom = nil :: any
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- face away from whoever is nearest, like it is waiting for them
	local nearest, nearestDist = best + Vector3.new(0, 0, 1), math.huge
	for _, member in Crew.active() do
		local pos = Crew.position(member.Player)
		if pos and flat(pos, best) < nearestDist then
			nearest, nearestDist = pos, flat(pos, best)
		end
	end
	local stand = best + Vector3.new(0, 3, 0)
	local away = stand + (stand - Vector3.new(nearest.X, stand.Y, nearest.Z))
	clone:PivotTo(CFrame.lookAt(stand, away))
	clone:SetAttribute("Decoy", true)
	clone.Parent = facility.Dynamic
	table.insert(decoys, { Model = clone, Position = best, ExpiresAt = os.clock() + F.DecoyLifetime })
	log("decoy wearing", source.Name)
end

local function stepDecoys()
	local now = os.clock()
	for i = #decoys, 1, -1 do
		local decoy = decoys[i]
		local reveal = false
		for _, member in Crew.active() do
			local pos = Crew.position(member.Player)
			if pos and not member.Locker and flat(pos, decoy.Position) < F.DecoyTriggerRange then
				reveal = true
			end
		end
		if reveal then
			removeDecoy(i, true)
		elseif now > decoy.ExpiresAt or decoy.Model.Parent == nil then
			removeDecoy(i, false)
		end
	end
end

----------------------------------------------------------------------------
-- Brain
----------------------------------------------------------------------------
local function pickWander(): Vector3
	local cells = facility.WanderCells
	local crew = Crew.active()
	local anchor: Vector3? = nil
	if #crew > 0 and os.clock() >= deadAirUntil and rng:NextNumber() < 0.55 then
		anchor = Crew.position(crew[rng:NextInteger(1, #crew)].Player)
	end
	local best = cellPoint(cells[rng:NextInteger(1, #cells)], facility.FloorY)
	if anchor then
		local bestDist = flat(best, anchor)
		for _ = 1, 6 do
			local candidate = cellPoint(cells[rng:NextInteger(1, #cells)], facility.FloorY)
			local d = flat(candidate, anchor)
			-- close to them, but not on top of them: let it arrive, not appear
			if d < bestDist and d > 24 then
				best, bestDist = candidate, d
			end
		end
	end
	return best
end

local function sniffLockers(dt: number)
	local me = rig.Root.Position
	for _, locker in facility.Lockers do
		local occupant = locker.Occupant
		local member = if occupant then Crew.get(occupant) else nil
		if member then
			local near = flat(me, locker.Position) < F.LockerSniffRange
			member.Player:SetAttribute("FawnAtLocker", near)
			if near and not member.HoldingBreath then
				member.Loud += dt
			else
				member.Loud = math.max(0, member.Loud - dt * 0.5)
			end
			if near and member.Loud >= F.LockerFoundAfter then
				member.Loud = 0
				hooks.OnLockerFound(member)
			end
		end
	end
end

local function nearestOccupiedLocker(center: Vector3, radius: number): Facility.Locker?
	local best: Facility.Locker? = nil
	local bestDist = radius
	for _, locker in facility.Lockers do
		if locker.Occupant then
			local d = flat(center, locker.Position)
			if d < bestDist then
				best, bestDist = locker, d
			end
		end
	end
	return best
end

function Fawn.step(dt: number)
	if state == "Dormant" then
		return
	end
	local now = os.clock()
	local me = rig.Root.Position
	stepDecoys()

	if state == "Stagger" then
		rig.Humanoid.WalkSpeed = 0
		if now >= staggerUntil then
			setState("Chase") -- it comes for whoever blinded it
			lastSeenAt = now
		end
		return
	end
	if now < pauseUntil then
		rig.Humanoid.WalkSpeed = 0
		return
	end
	rig.Humanoid.WalkSpeed = speedFor(state)
	sniffLockers(dt)

	-- look and listen
	local seen: Crew.Member? = nil
	local seenDist = math.huge
	local heardPos: Vector3? = nil
	local nearest: Crew.Member? = nil
	local nearestDist = math.huge
	for _, member in Crew.active() do
		local pos = Crew.position(member.Player)
		if not pos then
			continue
		end
		local d = flat(me, pos)
		if not member.Locker and d < nearestDist then
			nearest, nearestDist = member, d
		end
		if member.Locker then
			continue
		end
		if canSee(member, pos) then
			if d < seenDist then
				seen, seenDist = member, d
			end
		elseif canHear(member, pos) then
			heardPos = pos
		end
	end
	if enraged and not seen and nearest then
		seen, seenDist = nearest, nearestDist
	end

	-- catch anyone in reach
	if seen and seenDist <= F.CatchRange then
		local caught = seen
		shriek()
		setState("Search")
		searchCenter = me
		goal = me
		stateUntil = now + F.SearchSeconds
		pauseUntil = now + F.CatchCooldown
		rig.Model:SetAttribute("CatchAt", workspace:GetServerTimeNow())
		hooks.OnCatch(caught)
		return
	end

	if seen then
		if state ~= "Chase" then
			setState("Chase")
			shriek()
		end
		if target ~= seen then
			if target then
				target.Player:SetAttribute("Hunted", false)
			end
			target = seen
			seen.Player:SetAttribute("Hunted", true)
		end
		lastSeenAt = now
		local pos = Crew.position(seen.Player)
		if pos then
			lastKnown = pos
		end
	end

	if state == "Chase" then
		local chasing = target
		if not chasing or not Crew.isActive(chasing) then
			startSearch(lastKnown)
			return
		end
		if chasing.Locker then
			if chasing.Exposed then
				-- it watched them climb in
				local lockerPos = chasing.Locker.Position
				moveToward(lockerPos, flat(me, lockerPos) < 10)
				if flat(me, lockerPos) < 7 then
					hooks.OnLockerFound(chasing)
				end
			else
				startSearch(chasing.Locker.Position)
			end
			return
		end
		if now - lastSeenAt > F.LoseTargetAfter then
			startSearch(lastKnown)
			return
		end
		local direct = flat(me, lastKnown) < 14 and Grid.lineOfSight(facility.Map, me.X, me.Z, lastKnown.X, lastKnown.Z)
		moveToward(lastKnown, direct)
		return
	end

	if heardPos and state ~= "Investigate" then
		investigate(heardPos)
	elseif heardPos then
		goal = heardPos
	end

	if state == "Investigate" then
		local point = goal or me
		moveToward(point, false)
		if flat(me, point) < 6 or now > stateUntil then
			startSearch(point)
		end
	elseif state == "Search" then
		if now > stateUntil then
			setState("Patrol")
			goal = nil
			return
		end
		if now < lingerUntil then
			rig.Humanoid.WalkSpeed = 0
			return
		end
		local point = goal or searchCenter
		if flat(me, point) < 5 then
			-- prefer standing right outside a locker someone is hiding in
			local locker = nearestOccupiedLocker(searchCenter, 34)
			if locker and rng:NextNumber() < 0.65 then
				goal = locker.ExitCF.Position
				if flat(me, locker.ExitCF.Position) < 6 then
					lingerUntil = now + rng:NextNumber(2.5, 4.5)
					stateUntil = math.max(stateUntil, lingerUntil + 2)
				end
			else
				local offset = Vector3.new(rng:NextNumber(-22, 22), 0, rng:NextNumber(-22, 22))
				goal = searchCenter + offset
			end
		else
			moveToward(point, false)
		end
	elseif state == "Patrol" then
		if lureActive and now >= nextLureAt then
			nextLureAt = now + rng:NextNumber(16, 26)
			investigate(lurePos)
			return
		end
		if now >= nextHowlAt then
			nextHowlAt = now + between(F.HowlEvery)
			Fawn.howl()
			return
		end
		if now >= nextMimicAt and not enraged then
			nextMimicAt = now + between(F.MimicEvery)
			if rng:NextNumber() < 0.5 then
				voiceLure()
			else
				spawnDecoy()
			end
		end
		if not goal or flat(me, goal) < 5 or now - patrolPickedAt > 28 then
			goal = pickWander()
			patrolPickedAt = now
		end
		moveToward(goal :: Vector3, false)
	end
end

----------------------------------------------------------------------------
-- Controls used by the shift
----------------------------------------------------------------------------
function Fawn.wake()
	if state ~= "Dormant" then
		return
	end
	local now = os.clock()
	nextHowlAt = now + 6
	nextMimicAt = now + between(F.MimicEvery)
	rig.Root.Anchored = false
	pcall(function()
		rig.Root:SetNetworkOwner(nil) -- keep the server in charge of where it is
	end)
	rig.Sounds.Idle:Play()
	setState("Patrol")
	goal = nil
end

function Fawn.reset()
	for i = #decoys, 1, -1 do
		removeDecoy(i, false)
	end
	if target then
		target.Player:SetAttribute("Hunted", false)
	end
	target = nil
	state = "Dormant"
	enraged = false
	lureActive = false
	deadAirUntil = 0
	pauseUntil = 0
	table.clear(skins)
	rig.Sounds.Idle:Stop()
	rig.Humanoid.WalkSpeed = 0
	rig.Root.Anchored = true
	rig.Root.AssemblyLinearVelocity = Vector3.zero
	rig.Model:PivotTo(CFrame.new(facility.NestPosition + Vector3.new(0, FawnRig.RootHeight, 0)))
	rig.Model:SetAttribute("State", "Dormant")
	workspace:SetAttribute("HS_FawnState", "Dormant")
end

function Fawn.setEnraged(on: boolean)
	enraged = on
	rig.Model:SetAttribute("Enraged", on)
	if on then
		Fawn.wake()
		Fawn.howl()
	end
end

function Fawn.setLure(position: Vector3?)
	lureActive = position ~= nil
	if position then
		lurePos = position
		nextLureAt = os.clock() + 4
	end
end

function Fawn.setDeadAir(untilClock: number)
	deadAirUntil = untilClock
	if state == "Investigate" then
		setState("Patrol")
		goal = nil
	end
end

-- A flashlight held in its eye. Returns true if it worked.
function Fawn.stagger(by: Crew.Member): boolean
	if state == "Dormant" or state == "Stagger" or enraged then
		return false
	end
	setState("Stagger")
	staggerUntil = os.clock() + F.StaggerSeconds
	playHowl("Shriek")
	target = by
	by.Player:SetAttribute("Hunted", true)
	local pos = Crew.position(by.Player)
	if pos then
		lastKnown = pos
	end
	return true
end

-- Called when a member climbs into a locker.
function Fawn.onHide(member: Crew.Member)
	local pos = Crew.position(member.Player)
	member.Exposed = false
	if state == "Chase" and target == member and pos then
		local me = rig.Root.Position
		if os.clock() - lastSeenAt < 0.8 and flat(me, pos) < 40 and Grid.lineOfSight(facility.Map, me.X, me.Z, pos.X, pos.Z) then
			member.Exposed = true
		end
	end
end

-- It keeps what it takes: taken players become voices and decoys.
function Fawn.addSkin(player: Player)
	if not table.find(skins, player) then
		table.insert(skins, player)
	end
end

function Fawn.init(theFacility: Facility.Facility, theHooks: Hooks)
	facility = theFacility
	hooks = theHooks
	rig = FawnRig.build(theFacility.Folder, theFacility.NestPosition)
	Fawn.reset()
end

return Fawn
