--!strict
--[[
	Marrow Creek Relay — sublevel layout. One character = one 8x8 stud cell.

	  #  rock / wall            .  corridor floor      ,  metal floor
	  :  tile floor             =  carpet floor
	  D  door                   L  security door (opens with power)
	  B  blast door (opens for the escape)
	  E  elevator arrival       Z  surface ladder (escape)
	  X  breaker panel          C  broadcast console
	  S  FAWN's nest            K  cage
	  H  locker (hide)          m  mimic decoy spot
	  F  fuse spawn candidate   T  reel spawn candidate
	  b  battery candidate      n  note candidate
	  1  Effigy of Silence      2  Effigy of Mercy
	  3  Effigy of Howling      4  Effigy of Sight

	Lockers and effigies may replace a wall cell (they become an alcove facing
	the corridor) or sit on a room floor cell.
]]

local MapData = {}

MapData.Rows = {
	"###############################################",
	"#...........................................ZZ#",
	"#.#############################################",
	"#...........m...........#######################",
	"##############H########B#3######H##############",
	"#:::::b#m.............................m#,,,,,H#",
	"#:T::::#.##############L###4##########.#,T,,,,#",
	"#::::::#.#,,,b#===n===========b=#,,,,#.#,,,,,,#",
	"#:::n::D.#,F,,#========C========#n,F,#.D,,,,,X#",
	"#::::::#.#,,,,#=================#,,,,#.#,,,,,,#",
	"#::::T:#.D,,,,L=================L,,,,D.#,F,,,,#",
	"#H:::::#.#,,,,#=================#,,,,#.#b,,,,,#",
	"###D####.#,,T,#=================#,T,,#.####D###",
	"#=====H#.#,,,H#Hb==============H#H,,b#.#,,,,,K#",
	"#=F====#.##D###########L####H######D##.2,,,,,K#",
	"#======#........m.............m........#,,S,,K#",
	"#==n===D.######D##H####.#######D######.D,,,,,K#",
	"#====T=#.#b:::::::::::#.#:::::::::::b#.#,,,,,K#",
	"#b=====#.#::::::::::T:#.#:T::::::::::#.#,,,,,K#",
	"####D###.#::::::::::::#.#::::::::::::#.###D####",
	"#H:::::#.D::::::n:::::D.D:::::n::::::D.#,,,,,,#",
	"#::::T:#.#::::::::::::#m#::::::::::::#.#,T,,,,#",
	"#::::::D.#:F::::::::::#.#::::::::::F:#.D,,,,,,#",
	"#::n:::#.#H:::::::::::#.#:::::::::::H#.#,,,n,,#",
	"#:F::::#.##############.##############.#,,,,F,#",
	"#b:::::#m.............................m#H,,,,b#",
	"########H#########1####D##############H########",
	"####################H,,,,,n####################",
	"####################,,,,,,,####################",
	"####################,,EEE,,####################",
	"####################b,EEE,,####################",
	"###############################################",
}

export type Region = { Name: string, X1: number, Y1: number, X2: number, Y2: number }

-- Named areas (1-based inclusive cell rectangles) for signage and the HUD.
MapData.Regions = {
	{ Name = "ARCHIVE", X1 = 2, Y1 = 6, X2 = 7, Y2 = 12 },
	{ Name = "DORMITORY", X1 = 2, Y1 = 14, X2 = 7, Y2 = 19 },
	{ Name = "LABORATORY", X1 = 2, Y1 = 21, X2 = 7, Y2 = 26 },
	{ Name = "GENERATOR ROOM", X1 = 41, Y1 = 6, X2 = 46, Y2 = 12 },
	{ Name = "KENNEL", X1 = 41, Y1 = 14, X2 = 46, Y2 = 19 },
	{ Name = "STORAGE", X1 = 41, Y1 = 21, X2 = 46, Y2 = 26 },
	{ Name = "SERVER ROOM", X1 = 11, Y1 = 8, X2 = 14, Y2 = 14 },
	{ Name = "CONTROL", X1 = 16, Y1 = 8, X2 = 32, Y2 = 14 },
	{ Name = "WORKSHOP", X1 = 34, Y1 = 8, X2 = 37, Y2 = 14 },
	{ Name = "MESS HALL", X1 = 11, Y1 = 18, X2 = 22, Y2 = 24 },
	{ Name = "INFIRMARY", X1 = 26, Y1 = 18, X2 = 37, Y2 = 24 },
	{ Name = "FREIGHT ELEVATOR", X1 = 21, Y1 = 28, X2 = 27, Y2 = 31 },
	{ Name = "SURFACE TUNNEL", X1 = 2, Y1 = 2, X2 = 46, Y2 = 4 },
} :: { Region }

return MapData
