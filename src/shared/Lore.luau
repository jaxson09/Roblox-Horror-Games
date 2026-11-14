--!strict
--[[ Story text: intro, reels, notes, objectives, mimic lines. ]]

local Lore = {}

Lore.Intro = {
	"MARROW CREEK RELAY STATION",
	"DECOMMISSIONED 1989",
	"",
	"You answered a listing. One night. Cash. No questions.",
	"Take the freight elevator down. Bring up the four reels.",
	"",
	"Whatever calls your name down there —",
	"check that your friend is standing next to you first.",
}

Lore.Objectives = {
	Lobby = "TAKE THE FREIGHT ELEVATOR DOWN",
	Blackout = "RESTORE POWER  //  FUSES %d/%d",
	BlackoutInstall = "INSTALL THE FUSES  //  GENERATOR ROOM",
	Tapes = "RECOVER THE REELS  //  %d/%d",
	TapesInsert = "LOAD THE REELS  //  CONTROL",
	Broadcast = "HOLD CONTROL  //  RECALL TONE %d%%",
	BroadcastDrift = "SIGNAL DRIFT  //  RETUNE AT THE CONSOLE",
	BroadcastEmpty = "TRANSMISSION PAUSED  //  SOMEONE MUST STAY IN CONTROL",
	Escape = "BLAST DOOR OPEN  //  REACH THE SURFACE  %s",
	Caged = "CAGED  //  %ds",
	Spectating = "YOU WERE TAKEN",
}

export type Reel = { Title: string, Body: string }

-- Played in order as the crew recovers reels.
Lore.Reels = {
	{
		Title = "REEL 1 — COMMISSIONING",
		Body = "Field Automaton for Wilderness Navigation. Unit seven. The rangers call her Fawn. "
			.. "She finds lost hikers by playing them the voices of people they love. "
			.. "Forty-one rescues the first winter. We are very proud.",
	},
	{
		Title = "REEL 2 — INCIDENT LOG",
		Body = "She came back alone again. Third time this month. "
			.. "The speaker was playing a child's voice. We never recorded a child. "
			.. "Maintenance found deer hair in the shoulder joints.",
	},
	{
		Title = "REEL 3 — DR. OKAFOR",
		Body = "She has started collecting. Antlers first. Then hides. "
			.. "It is not malice. It is the rescue heuristic: people walk toward what looks alive. "
			.. "So she is trying to look alive. She is trying to look like us.",
	},
	{
		Title = "REEL 4 — LAST TRANSMISSION",
		Body = "Do not try to shut her down by hand. Broadcast the recall tone from Control and get out. "
			.. "She will come to the tone. She always comes to a voice. "
			.. "And if you can hear me, and I sound like someone you know — I am sorry. That is not me anymore.",
	},
} :: { Reel }

export type Note = { Id: string, Title: string, Body: string }

Lore.Notes = {
	{ Id = "memo_voices", Title = "MEMO — VOICE LIBRARY", Body = "All staff are required to record forty phrases for Unit 7's rescue library. Speak clearly. Say your own name twice. She learns faster from names." },
	{ Id = "kennel_log", Title = "KENNEL LOG", Body = "Moved the search dogs topside. They will not go near the charging bay. Kepler chewed through his lead rather than walk past it. Dogs know." },
	{ Id = "night_rules", Title = "NIGHT SHIFT RULES", Body = "1. Walk. Do not run. She comes to noise.\n2. Close doors behind you. She cannot see through steel.\n3. If she is near your locker, hold your breath.\n4. Count your crew. Then count again." },
	{ Id = "requisition", Title = "REQUISITION DENIED", Body = "Request for 'one (1) full-length mirror, charging bay' is denied. Unit 7 is not staff. Unit 7 does not need to see how it looks." },
	{ Id = "okafor_private", Title = "PRIVATE — S. OKAFOR", Body = "I heard my mother call me from the server room tonight. My mother has been dead for nine years. I answered anyway. God help me, I answered." },
	{ Id = "trade", Title = "SCRAWLED ON CARDBOARD", Body = "it leaves the skulls where it wants us to stop. leave something. take something. it TRADES. i think it thinks that's what people do." },
	{ Id = "evac", Title = "EVACUATION ORDER", Body = "Station is to be sealed. Blast door will be welded from the surface side. Anyone still below at 0600 is to be considered part of the station." },
	{ Id = "light", Title = "MAINTENANCE TIP", Body = "Her optics are old. A strong light straight in the lens will whiteout the sensor for a second or two. It also makes her very, very angry." },
} :: { Note }

-- %s is replaced with a real crew member's name. It prefers the ones it has taken.
Lore.MimicLines = {
	"%s: hey. over here.",
	"%s: i found the way out. come on.",
	"%s: wait for me.",
	"%s: help me. please.",
	"%s: it's safe now. you can come out.",
	"%s: don't leave me down here.",
	"%s: why did you leave me?",
	"%s: say your name again.",
}

Lore.Tips = {
	"She comes to noise. Walk.",
	"Close doors behind you.",
	"In a locker, hold your breath when she is close.",
	"A caged friend can be freed. A missing one is being worn.",
	"Your light gives you away — and can blind her, once.",
	"Count your crew.",
}

Lore.Endings = {
	Escaped = { "YOU REACHED THE SURFACE", "The tone is still playing somewhere below you. It will play until the generator dies." },
	Taken = { "YOU WERE TAKEN", "Your voice has been added to the library." },
	Lockdown = { "SEALED BELOW", "The blast door closed at 0600. You are part of the station now." },
}

return Lore
