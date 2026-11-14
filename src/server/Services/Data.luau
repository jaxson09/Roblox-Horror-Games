--!strict
--[[
	Data — persistent player profiles (DataStore) and the escape leaderboard.
	Falls back to in-memory profiles when DataStores are unavailable (e.g. a
	Studio session without API access), so the game always runs.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Data = {}

export type Profile = {
	Escapes: number,
	Shifts: number,
	Caught: number,
	Reels: number,
	Rescues: number,
	Keys: number, -- banked adrenaline shots (each saves you from being kept, once)
	Xp: number,
	Notes: { [string]: boolean },
	Purchases: { string }, -- recent PurchaseIds, for idempotent receipts
	SeenIntro: boolean,
}

local STORE_NAME = "HS_Profiles_v1"
local BOARD_NAME = "HS_Escapes_v1"

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {} -- true only if the profile came from the DataStore
local store: DataStore? = nil
local board: OrderedDataStore? = nil

pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
	board = DataStoreService:GetOrderedDataStore(BOARD_NAME)
end)

local function blank(): Profile
	return { Escapes = 0, Shifts = 0, Caught = 0, Reels = 0, Rescues = 0, Keys = 0, Xp = 0, Notes = {}, Purchases = {}, SeenIntro = false }
end

local function key(player: Player): string
	return "u_" .. tostring(player.UserId)
end

function Data.load(player: Player): Profile
	local profile = blank()
	local ok = false
	if store then
		for attempt = 1, 3 do
			local success, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if success then
				ok = true
				if type(result) == "table" then
					for field, value in result :: { [string]: any } do
						(profile :: any)[field] = value
					end
				end
				break
			end
			task.wait(attempt)
		end
	end
	if player.Parent then
		profiles[player] = profile
		loaded[player] = ok
		if not ok and store then
			task.spawn(Data.retryLoad, player)
		end
		player:SetAttribute("Keys", profile.Keys)
		player:SetAttribute("Escapes", profile.Escapes)
		player:SetAttribute("SeenIntro", profile.SeenIntro)
		player:SetAttribute("Xp", profile.Xp or 0)
	end
	return profile
end

-- True once the profile really came from (and can be written back to) the DataStore.
function Data.isLoaded(player: Player): boolean
	return loaded[player] == true
end

-- The first load failed: keep trying, then fold this session's progress into the stored profile.
function Data.retryLoad(player: Player)
	while player.Parent and profiles[player] and not loaded[player] do
		task.wait(20)
		local success, result = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		local session = profiles[player]
		if success and session and player.Parent then
			if type(result) == "table" then
				local stored = result :: { [string]: any }
				for _, field in { "Escapes", "Shifts", "Caught", "Reels", "Rescues", "Keys", "Xp" } do
					if type(stored[field]) == "number" then
						(session :: any)[field] += stored[field]
					end
				end
				if type(stored.Notes) == "table" then
					for id in stored.Notes do
						session.Notes[id] = true
					end
				end
				if type(stored.Purchases) == "table" then
					for _, id in stored.Purchases do
						table.insert(session.Purchases, id)
					end
				end
				session.SeenIntro = session.SeenIntro or stored.SeenIntro == true
			end
			loaded[player] = true
			player:SetAttribute("Keys", session.Keys)
			player:SetAttribute("Escapes", session.Escapes)
		end
	end
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

-- Writes the profile. Returns true only if the DataStore confirmed it.
function Data.save(player: Player): boolean
	local profile = profiles[player]
	-- never overwrite real data with a profile that failed to load
	if not profile or not store or not loaded[player] then
		return false
	end
	local saved = pcall(function()
		(store :: DataStore):SetAsync(key(player), profile, { player.UserId })
	end)
	if not saved then
		return false
	end
	if board and profile.Escapes > 0 then
		pcall(function()
			(board :: OrderedDataStore):SetAsync(tostring(player.UserId), profile.Escapes)
		end)
	end
	return true
end

function Data.release(player: Player)
	Data.save(player)
	profiles[player] = nil
	loaded[player] = nil
end

function Data.addKeys(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	profile.Keys = math.max(0, profile.Keys + amount)
	player:SetAttribute("Keys", profile.Keys)
	return true
end

function Data.bump(player: Player, field: "Escapes" | "Shifts" | "Caught" | "Reels" | "Rescues", amount: number)
	local profile = profiles[player]
	if profile then
		(profile :: any)[field] += amount
		if field == "Escapes" then
			player:SetAttribute("Escapes", profile.Escapes)
		end
	end
end

-- Adds experience and returns the new total.
function Data.addXp(player: Player, amount: number): number
	local profile = profiles[player]
	if not profile then
		return amount
	end
	profile.Xp = (profile.Xp or 0) + amount
	player:SetAttribute("Xp", profile.Xp)
	return profile.Xp
end

function Data.hasPurchase(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.Purchases, purchaseId) ~= nil
end

function Data.recordPurchase(player: Player, purchaseId: string)
	local profile = profiles[player]
	if profile then
		table.insert(profile.Purchases, purchaseId)
		while #profile.Purchases > 60 do
			table.remove(profile.Purchases, 1)
		end
	end
end

-- Top crews for the lobby board: { {Name, Escapes} }.
function Data.topEscapes(count: number): { { Name: string, Escapes: number } }
	local out = {}
	if not board then
		return out
	end
	local ok, pages = pcall(function()
		return (board :: OrderedDataStore):GetSortedAsync(false, count)
	end)
	if not ok then
		return out
	end
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = "unknown"
		if userId then
			local gotName, result = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if gotName then
				name = result
			end
		end
		table.insert(out, { Name = name, Escapes = entry.value })
	end
	return out
end

function Data.init()
	task.spawn(function()
		while true do
			task.wait(150)
			for player in profiles do
				task.spawn(Data.save, player)
			end
		end
	end)
	game:BindToClose(function()
		for player in profiles do
			task.spawn(Data.save, player)
		end
		task.wait(2)
	end)
end

return Data
