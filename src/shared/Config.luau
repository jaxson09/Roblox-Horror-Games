--!strict
--[[
	HOLLOW SIGNAL — central tuning + content configuration.
	Everything a designer is likely to tweak lives here: movement, the monster,
	pacing, monetization IDs, audio IDs and fonts.
]]

local Config = {}

Config.GameName = "HOLLOW SIGNAL"
Config.Tagline = "DO NOT ANSWER IT."
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
	FacilityOrigin = Vector3.new(-180, -400, -124),
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
	DazzleRange = 26, -- shine in HUSH's eye inside this range...
	DazzleTime = 1.1, -- ...for this long to stagger it
	DazzleCooldown = 22,
	DazzleBatteryCost = 0.15,

	-- Noise (0..1) by movement type; HUSH hears at Noise * HearRadius studs.
	NoiseCrouch = 0.1,
	NoiseWalk = 0.42,
	NoiseSprint = 1.0,

	-- Camcorder: photographing the subject is the job
	PhotoRange = 70,
	PhotoCooldown = 4, -- seconds between your own shots
	PhotoSpacing = 9, -- seconds between photos that count as new evidence
	PhotoAim = 0.9, -- how centred the subject must be (dot product)

	-- Lockers
	BreathSeconds = 6.5,
	BreathRecover = 0.55, -- seconds of breath regained per second
}

----------------------------------------------------------------------------
-- The shift (one run)
----------------------------------------------------------------------------
Config.Shift = {
	ElevatorRideTime = 7, -- the ride with the training tape is longer: its length is worked out from the tape
	PhotosNeeded = 5,
	CanistersPerStation = 2, -- each tube station can only send this many
	SendHold = 5, -- seconds to load and fire a canister
	FilesHidden = 6, -- case files hidden in filing cabinets
	BatteriesSpawned = 6,
	GracePeriod = 22, -- HUSH does not move for this long after the first arrival
	ReturnSeconds = 150, -- lockdown timer once the evidence is all sent
	ResultsSeconds = 14,
	GrabSeconds = 3.4, -- how long you have to break free
	BreakFreeTaps = 14,
	MaxPlayersHint = 6,
}

-- Experience awarded on the field report.
Config.Xp = { Photo = 40, Sent = 60, File = 25, Escaped = 200, PerLevel = 300 }

----------------------------------------------------------------------------
-- Lobby: crews form in the circles at the far end of the intake hall.
----------------------------------------------------------------------------
Config.Lobby = {
	PadCount = 4,
	PlayerOptions = { 1, 2, 3, 4, 6 },
	DefaultPlayers = 4,
	AutoStartSeconds = 15, -- countdown once a lobby is full
}

export type Difficulty = { Label: string, Blurb: string, Speed: number, Hearing: number, Hearts: number, BreakFrees: number }

Config.Difficulties = {
	Easy = { Label = "EASY", Blurb = "It is slower and hard of hearing. Four hearts, two break-frees.", Speed = 0.9, Hearing = 0.8, Hearts = 4, BreakFrees = 2 },
	Normal = { Label = "NORMAL", Blurb = "The job as written. Three hearts, one break-free.", Speed = 1, Hearing = 1, Hearts = 3, BreakFrees = 1 },
	Nightmare = { Label = "NIGHTMARE", Blurb = "Faster. Hears everything. Two hearts. You cannot break free.", Speed = 1.07, Hearing = 1.25, Hearts = 2, BreakFrees = 0 },
} :: { [string]: Difficulty }
Config.DifficultyOrder = { "Easy", "Normal", "Nightmare" }

-- Chapters. Only available ones can be selected; the rest show as in development.
Config.Parts = {
	{ Name = "PART 1", Title = "THE NIGHT WARD", Available = true },
	{ Name = "PART 2", Title = "IN DEVELOPMENT", Available = false },
	{ Name = "PART 3", Title = "IN DEVELOPMENT", Available = false },
}

----------------------------------------------------------------------------
-- H.U.S.H. (the code still calls the module "Fawn")
----------------------------------------------------------------------------
Config.Fawn = {
	Name = "H.U.S.H.",
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
	LockerFoundAfter = 1.4, -- seconds of audible breathing next to HUSH
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
	-- Wall dispenser, any ward: one heart back (also banked if it cannot be used).
	Revive = { Id = 0, Name = "Adrenaline", Blurb = "One heart back.", SuggestedPrice = 39 },
	-- Dispenser by the elevator lobby: a heart back for the whole crew.
	ReviveAll = { Id = 0, Name = "Crash Cart", Blurb = "A heart back for everyone on the ward.", SuggestedPrice = 99 },
	-- Dispenser outside Surgery: HUSH cannot hear the crew for a minute.
	DeadAir = { Id = 0, Name = "Sedative", Blurb = "Sixty seconds. It cannot hear your crew.", SuggestedPrice = 49 },
	-- Dispenser by the Nurse Station: tube stations and case files glow through walls.
	Sight = { Id = 0, Name = "Scanner", Blurb = "Tube stations and case files show through the walls.", SuggestedPrice = 29 },
	-- Dispenser outside the Morgue, and the PA handset in the lobby: scares the whole server.
	ScareAll = { Id = 0, Name = "Code Blue", Blurb = "Page the whole building. Everyone hears it.", SuggestedPrice = 25 },
} :: { [string]: Product }

Config.Passes = {
	Flashlight = { Id = 0, Name = "Heavy-Duty Lantern", Blurb = "Battery lasts twice as long. Wider beam.", SuggestedPrice = 129 },
	NightVision = { Id = 0, Name = "Camcorder Night Mode", Blurb = "Press N: see in the dark without a light. Static blinds it when HUSH is close.", SuggestedPrice = 249 },
	SecondWind = { Id = 0, Name = "Second Wind", Blurb = "One extra break-free every shift.", SuggestedPrice = 199 },
	Tracker = { Id = 0, Name = "Signal Tracker", Blurb = "A needle on your HUD leans toward HUSH's carrier signal.", SuggestedPrice = 79 },
	Stamina = { Id = 0, Name = "Night Runner", Blurb = "50% more stamina.", SuggestedPrice = 149 },
	Veteran = { Id = 0, Name = "Senior Investigator", Blurb = "Gold name tag and a Hollow Signal lanyard.", SuggestedPrice = 99 },
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
	Elevator = 0, -- elevator.ogg
	Dispenser = 0, -- dispenser_hum.ogg
	LightFlicker = 0, -- light_flicker.ogg
	-- player / ui
	FlashlightClick = 0, -- flashlight_click.ogg
	Blip = 0, -- ui_blip.ogg
	Type = 0, -- ui_type.ogg
	TapeStart = 0, -- tape_start.ogg
	Shutter = 0, -- camera_shutter.ogg
	TubeSend = 0, -- tube_send.ogg
	PowerDown = 0, -- power_down.ogg
	Grab = 0, -- grab.ogg
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
	Display = "rbxasset://fonts/families/Creepster.json", -- event lines, titles, what it says
	Body = "rbxasset://fonts/families/SpecialElite.json", -- worn typewriter: everything you read
	Osd = "rbxasset://fonts/families/PressStart2P.json", -- tiny camcorder tags only
	Scrawl = "rbxasset://fonts/families/PermanentMarker.json", -- things written on walls
	-- world signage and older names
	Sign = "rbxasset://fonts/families/SpecialElite.json",
	Mono = "rbxasset://fonts/families/SpecialElite.json",
	Typewriter = "rbxasset://fonts/families/SpecialElite.json",
	Horror = "rbxasset://fonts/families/Creepster.json",
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
