--!strict
--[[
	HOLLOW SIGNAL — central tuning + content configuration.
	Everything a designer is likely to tweak lives here: movement, the monster,
	pacing, monetization IDs, audio IDs and fonts.
]]

local Config = {}

Config.GameName = "HOLLOW SIGNAL"
Config.Tagline = "IT LEARNED YOUR VOICE."
Config.Version = "0.1.0"

-- Set true to print AI/state transitions to the output window.
Config.Debug = false

----------------------------------------------------------------------------
-- World layout
----------------------------------------------------------------------------
Config.World = {
	CellSize = 8, -- studs per map cell
	CeilingHeight = 12,
	DoorHeight = 11,
	-- World position of map cell (0,0)'s outer corner; Y is the floor surface.
	FacilityOrigin = Vector3.new(-188, -400, -128),
	LobbyFloorY = 0,
}

----------------------------------------------------------------------------
-- Player movement / senses
----------------------------------------------------------------------------
Config.Player = {
	WalkSpeed = 12,
	SprintSpeed = 21,
	CrouchSpeed = 6,
	LobbySpeed = 16,
	StaminaMax = 100,
	StaminaDrain = 22, -- per second while sprinting
	StaminaRegen = 13, -- per second while not sprinting
	StaminaRegenDelay = 1.1,
	StaminaPassMultiplier = 1.5,

	-- Flashlight
	BatterySeconds = 210, -- full battery, light on
	BatteryPassMultiplier = 2,
	BatteryPickup = 0.5, -- fraction restored per battery
	DazzleRange = 26, -- shine in FAWN's eye inside this range...
	DazzleTime = 1.1, -- ...for this long to stagger it
	DazzleCooldown = 22,
	DazzleBatteryCost = 0.15,

	-- Noise (0..1) by movement type; FAWN hears at Noise * HearRadius studs.
	NoiseCrouch = 0.1,
	NoiseWalk = 0.42,
	NoiseSprint = 1.0,

	-- Lockers
	BreathSeconds = 6.5,
	BreathRecover = 0.55, -- seconds of breath regained per second
}

----------------------------------------------------------------------------
-- The shift (one run)
----------------------------------------------------------------------------
Config.Shift = {
	ElevatorCountdown = 15, -- seconds on the pad before the cage drops
	ElevatorRideTime = 7,
	FusesNeeded = 3,
	TapesNeeded = 4,
	BatteriesSpawned = 7,
	NotesSpawned = 5,
	GracePeriod = 25, -- FAWN stays dormant this long after the first arrival
	BroadcastSeconds = 80, -- time someone must hold the control room
	RetuneEvery = { 14, 22 }, -- signal drifts and must be retuned at the console
	EscapeSeconds = 150, -- lockdown timer once the blast door opens
	ResultsSeconds = 14,
	CageSeconds = 70, -- time before a caged player is lost
	FreeStruggles = 1, -- free self-rescues per shift
	StruggleDelay = 8, -- seconds in the cage before you can struggle
	StruggleHold = 6, -- seconds of holding to break out
	RescueHold = 3.5, -- seconds a teammate holds to open a cage
	MaxPlayersHint = 8,
}

----------------------------------------------------------------------------
-- F.A.W.N.
----------------------------------------------------------------------------
Config.Fawn = {
	Name = "F.A.W.N.",
	Height = 9.2,
	PatrolSpeed = 8.5,
	InvestigateSpeed = 13,
	ChaseSpeed = 19,
	EnragedSpeed = 20.5,
	SightRange = 75,
	SightRangeFlashlight = 110, -- your light gives you away
	CloseSense = 13, -- notices anyone this close regardless of facing
	HearRadius = 85,
	WallMuffle = 0.6, -- hearing multiplier with no line of sight
	CatchRange = 5.5,
	CatchCooldown = 4.5,
	LoseTargetAfter = 3.2, -- seconds without sight before it starts searching
	SearchSeconds = 9,
	LockerSniffRange = 11,
	LockerFoundAfter = 1.4, -- seconds of audible breathing next to FAWN
	StaggerSeconds = 2.2,
	HowlEvery = { 28, 55 }, -- ambient howls while patrolling
	MimicEvery = { 38, 70 },
	DecoyLifetime = 75,
	DecoyTriggerRange = 11,
	DeadAirSeconds = 60,
}

----------------------------------------------------------------------------
-- Monetization. Create these on the Creator Dashboard (JBrosDev) and paste the
-- IDs. Id = 0 means "not for sale yet": the prompt shows a notice instead, and
-- in Studio the item is granted for free so everything can be tested.
-- Prices shown in-game are read live from Roblox (never hard-coded), so Roblox
-- Plus discounts and price changes always display correctly.
----------------------------------------------------------------------------
export type Product = { Id: number, Name: string, Blurb: string, SuggestedPrice: number }

Config.Products = {
	-- Self-revive, bought from inside a cage ("a key, just within reach").
	Revive = { Id = 0, Name = "Rusted Key", Blurb = "Unlock your cage.", SuggestedPrice = 39 },
	-- Effigy of Mercy (outside the Kennel): frees every caged teammate.
	ReviveAll = { Id = 0, Name = "Effigy of Mercy", Blurb = "Every cage opens.", SuggestedPrice = 99 },
	-- Effigy of Silence: the whole crew is inaudible to FAWN for a minute.
	DeadAir = { Id = 0, Name = "Effigy of Silence", Blurb = "Sixty seconds of dead air. It cannot hear your crew.", SuggestedPrice = 49 },
	-- Effigy of Sight: objective items glow through walls for the crew.
	Sight = { Id = 0, Name = "Effigy of Sight", Blurb = "What you are looking for shows itself.", SuggestedPrice = 29 },
	-- Effigy of Howling / lobby siren: scares every player on the server.
	ScareAll = { Id = 0, Name = "Effigy of Howling", Blurb = "Everyone hears it. Everyone.", SuggestedPrice = 25 },
} :: { [string]: Product }

Config.Passes = {
	Flashlight = { Id = 0, Name = "Heavy-Duty Lantern", Blurb = "Battery lasts twice as long. Wider beam.", SuggestedPrice = 129 },
	NightVision = { Id = 0, Name = "Camcorder Night Mode", Blurb = "Press N: see in the dark without a light. Static blinds it when FAWN is close.", SuggestedPrice = 249 },
	SecondWind = { Id = 0, Name = "Second Wind", Blurb = "One extra free cage break-out every shift.", SuggestedPrice = 199 },
	Tracker = { Id = 0, Name = "Signal Tracker", Blurb = "A needle on your HUD leans toward FAWN's carrier signal.", SuggestedPrice = 79 },
	Stamina = { Id = 0, Name = "Night Runner", Blurb = "50% more stamina.", SuggestedPrice = 149 },
	Veteran = { Id = 0, Name = "Night Shift Veteran", Blurb = "Gold crew tag, lobby lantern, and a wave from the ranger.", SuggestedPrice = 99 },
} :: { [string]: Product }

Config.Monetization = {
	StudioFreeGrants = true, -- grant unconfigured (Id = 0) items for free in Studio
	ShowPriceOnPrompts = true, -- keep true: Roblox requires purchases to be clearly disclosed
}

----------------------------------------------------------------------------
-- Audio. Upload the files in assets/audio to the JBrosDev account (Studio >
-- Asset Manager > Bulk Import) and paste each asset id here. 0 = silent.
----------------------------------------------------------------------------
Config.Sounds = {
	-- music / ambience (looped)
	LobbyTheme = 0, -- lobby_theme.ogg
	LobbyForest = 0, -- forest_night.ogg
	BunkerDrone = 0, -- bunker_drone.ogg
	ChaseTheme = 0, -- chase_theme.ogg
	BroadcastTone = 0, -- broadcast_tone.ogg
	Alarm = 0, -- alarm_loop.ogg
	Static = 0, -- static_loop.ogg
	Heartbeat = 0, -- heartbeat_loop.ogg
	FawnIdle = 0, -- fawn_idle_loop.ogg
	-- monster one-shots
	FawnHowl1 = 0, -- fawn_howl_1.ogg
	FawnHowl2 = 0, -- fawn_howl_2.ogg
	FawnHowl3 = 0, -- fawn_howl_3.ogg
	FawnShriek = 0, -- fawn_shriek.ogg (spotted you)
	FawnStep = 0, -- fawn_step.ogg
	FawnMimic1 = 0, -- fawn_mimic_1.ogg
	FawnMimic2 = 0, -- fawn_mimic_2.ogg
	Jumpscare = 0, -- jumpscare.ogg
	-- world
	DoorOpen = 0, -- door_open.ogg
	DoorClose = 0, -- door_close.ogg
	DoorSlam = 0, -- door_slam.ogg
	Locker = 0, -- locker.ogg
	Pickup = 0, -- pickup.ogg
	FuseInsert = 0, -- fuse_insert.ogg
	PowerUp = 0, -- power_up.ogg
	BlastDoor = 0, -- blast_door.ogg
	Elevator = 0, -- elevator.ogg
	CageRattle = 0, -- cage_rattle.ogg
	CageOpen = 0, -- cage_open.ogg
	Effigy = 0, -- effigy_whisper.ogg
	LightFlicker = 0, -- light_flicker.ogg
	-- player / ui
	FlashlightClick = 0, -- flashlight_click.ogg
	Blip = 0, -- ui_blip.ogg
	Type = 0, -- ui_type.ogg
	TapeStart = 0, -- tape_start.ogg
	Breath = 0, -- breath_gasp.ogg
	Sting = 0, -- sting_low.ogg
} :: { [string]: number }

Config.Images = {
	-- Optional tiling noise texture for the VHS static layer ("" = procedural blocks).
	Noise = "",
}

----------------------------------------------------------------------------
-- Typography (all built-in Roblox font families).
----------------------------------------------------------------------------
Config.Fonts = {
	Osd = "rbxasset://fonts/families/PressStart2P.json", -- camcorder on-screen display
	Mono = "rbxasset://fonts/families/RobotoMono.json", -- terminals, objectives
	Typewriter = "rbxasset://fonts/families/SpecialElite.json", -- documents, tapes
	Scrawl = "rbxasset://fonts/families/PermanentMarker.json", -- things written on walls
	Horror = "rbxasset://fonts/families/Creepster.json", -- used once: when it takes you
	Sign = "rbxasset://fonts/families/Michroma.json", -- facility signage
}

Config.Colors = {
	Osd = Color3.fromRGB(235, 235, 225),
	Rec = Color3.fromRGB(255, 45, 45),
	Amber = Color3.fromRGB(255, 176, 64),
	Phosphor = Color3.fromRGB(120, 255, 170),
	Paper = Color3.fromRGB(222, 213, 190),
	Ink = Color3.fromRGB(28, 24, 22),
	Dread = Color3.fromRGB(150, 12, 12),
	Robux = Color3.fromRGB(190, 255, 205),
}

return Config
