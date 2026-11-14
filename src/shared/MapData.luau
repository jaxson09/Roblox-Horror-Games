--!strict
--[[
	Meridian General Hospital — Ward C. One character = one 8x8 stud cell.

	  #  wall                   .  corridor (vinyl)     :  clinical tile
	  =  carpet                 ,  bare concrete
	  D  door
	  E  elevator (arrival, and the way out once the evidence is sent)
	  P  pneumatic tube station (send evidence)
	  R  recovery bed (where you wake up after it gets you)
	  F  filing cabinet (some hold case files)
	  H  locker (hide)          S  where HUSH starts its rounds
	  b  battery candidate      m  mimic decoy spot
	  1  dispenser: Sedative    2  dispenser: Crash Cart
	  3  dispenser: Code Blue   4  dispenser: Scanner

	Lockers, tube stations and dispensers may replace a wall cell (they become
	an alcove facing the corridor) or stand on a room floor cell. Rooms are
	furnished automatically from their Kind (see World/Furnish).
]]

local MapData = {}

MapData.Rows = {
	"#############################################",
	"#########F::::::::::b###F==========b#########",
	"#########::::::::::::###============#########",
	"##########1###D##P###########D###############",
	"#R:::H#m.............................m#b,,,F#",
	"#:::::#.#######H######.####4##H######.#,,,,,#",
	"#:::::#.#===b=======F#.#:::::::::::F#.#,,,,,#",
	"#:::::#.#============#.#::::::::::::#.#,,,,,#",
	"#R:::bD.#============#.#::::::::::::#.D,,,,,#",
	"#:::::#.D============D.D::::::::::::D.#,,,,,#",
	"#:::::#.#============#m#::::::::::::#.#,,,,,#",
	"#:::::P.#============#.#::::::::::::#.#,,,,,#",
	"#R::::#.#===========H#.#H::::::::b::#.#H,,,,#",
	"###D###.H#####D#######.###P##D#######.###D###",
	"#R::::#......m.................m......#,,,,,#",
	"#:::::#.######D#######.######D######H.#,,,,,#",
	"#:::::#.#F==========F#.#,,b,,,,,,,,,#.P,,,,,#",
	"#:::::#.#============#.#,,,,,,,,,,,,#.#,,,,,#",
	"#:::::#.#============#.#,,,,,,,,,,,,#.#,,,,,#",
	"#R::::D.D============DmD,,,,,,,,,,,,D.D,,,,,#",
	"#:::::#.#============#.#,,,,,,,,,,,,#.#,,S,,#",
	"#:::::#.#============#.#,,,,,,,,,,,,#.#,,,,,#",
	"#:::::#.#F========b=H#.#H,,,,,,,,,,F#.3,,,,,#",
	"#:::::#.#######H######.#######H######.#,,,,,#",
	"#R:::H#m.............................m#,,b,H#",
	"############P#########D#########P#2##########",
	"###################H......###################",
	"###################.......###################",
	"###################..EEE..###################",
	"###################..EEE.b###################",
	"#############################################",
}

export type Region = { Name: string, X1: number, Y1: number, X2: number, Y2: number, Kind: string }

-- Named rooms (1-based inclusive cell rectangles): signage, the HUD, and furniture.
MapData.Regions = {
{ Name = "WARD C-1", X1 = 2, Y1 = 5, X2 = 6, Y2 = 13, Kind = "Ward" },
	{ Name = "WARD C-2", X1 = 2, Y1 = 15, X2 = 6, Y2 = 25, Kind = "Ward" },
	{ Name = "WAITING ROOM", X1 = 10, Y1 = 7, X2 = 21, Y2 = 13, Kind = "Waiting" },
	{ Name = "NURSE STATION", X1 = 25, Y1 = 7, X2 = 36, Y2 = 13, Kind = "Station" },
	{ Name = "RECORDS", X1 = 10, Y1 = 17, X2 = 21, Y2 = 23, Kind = "Office" },
	{ Name = "PHARMACY", X1 = 25, Y1 = 17, X2 = 36, Y2 = 23, Kind = "Storage" },
	{ Name = "RADIOLOGY", X1 = 40, Y1 = 5, X2 = 44, Y2 = 13, Kind = "Lab" },
	{ Name = "MORGUE", X1 = 40, Y1 = 15, X2 = 44, Y2 = 25, Kind = "Morgue" },
	{ Name = "SURGERY", X1 = 10, Y1 = 2, X2 = 21, Y2 = 3, Kind = "Lab" },
	{ Name = "STAFF OFFICE", X1 = 25, Y1 = 2, X2 = 36, Y2 = 3, Kind = "Office" },
	{ Name = "ELEVATOR LOBBY", X1 = 20, Y1 = 27, X2 = 26, Y2 = 30, Kind = "Lobby" },
} :: { Region }

return MapData
