--!strict
--[[
	Store — every Robux purchase in the game goes through here.

	Design rules (they are also Roblox policy):
	  * Purchases are diegetic — an effigy, a key in a cage, a siren, a shelf —
	    but the prompt always names the item and shows the real, live price,
	    and Roblox's own purchase dialog confirms it. Nothing is disguised.
	  * Nothing is ever sold that would do nothing (no "free everyone" when
	    nobody is caged), and a purchase that cannot be applied the moment it
	    lands is banked as a Rusted Key instead of being lost.
	  * Developer product grants are idempotent on PurchaseId.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)

local Store = {}

local ROBUX = utf8.char(0xE002) -- Roblox's Robux glyph

type Grant = (Player) -> boolean

local grants: { [string]: Grant } = {}
local kindByProductId: { [number]: string } = {}
local keyByPassId: { [number]: string } = {}
local prices: { [string]: number } = {} -- "Product:Revive" / "Pass:Tracker" -> live price
local owned: { [Player]: { [string]: boolean } } = {}
local listeners: { () -> () } = {}

local function toast(player: Player, text: string)
	Remotes.ToClient:FireClient(player, "Toast", text, "store")
end

local function freeInStudio(): boolean
	return RunService:IsStudio() and Config.Monetization.StudioFreeGrants
end

function Store.registerGrant(kind: string, grant: Grant)
	grants[kind] = grant
end

-- "R$49"-style text for prompts and cards ("" when unknown).
function Store.priceText(scope: "Product" | "Pass", key: string): string
	if not Config.Monetization.ShowPriceOnPrompts then
		return ""
	end
	local live = prices[scope .. ":" .. key]
	if live then
		return ROBUX .. tostring(live)
	end
	local entry = if scope == "Product" then Config.Products[key] else Config.Passes[key]
	if entry and entry.Id == 0 and RunService:IsStudio() then
		return ROBUX .. tostring(entry.SuggestedPrice) -- preview of the planned price
	end
	return ""
end

function Store.onPricesChanged(callback: () -> ())
	table.insert(listeners, callback)
end

function Store.owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

local function setOwned(player: Player, key: string)
	local set = owned[player]
	if not set then
		set = {}
		owned[player] = set
	end
	set[key] = true
	player:SetAttribute("Pass_" .. key, true)
end

-- Opens Roblox's purchase dialog for a developer product.
function Store.prompt(player: Player, kind: string)
	local product = Config.Products[kind]
	if not product then
		return
	end
	if product.Id == 0 then
		if freeInStudio() then
			local grant = grants[kind]
			if grant and grant(player) then
				toast(player, `[STUDIO] {product.Name} granted free — set Config.Products.{kind}.Id to sell it`)
			end
		else
			toast(player, "The effigy does not answer. (Not for sale yet.)")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

function Store.promptPass(player: Player, key: string)
	local pass = Config.Passes[key]
	if not pass then
		return
	end
	if Store.owns(player, key) then
		toast(player, `You already carry the {pass.Name}.`)
		return
	end
	if pass.Id == 0 then
		if freeInStudio() then
			setOwned(player, key)
			toast(player, `[STUDIO] {pass.Name} granted free — set Config.Passes.{key}.Id to sell it`)
		else
			toast(player, "Out of stock. (Not for sale yet.)")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local kind = kindByProductId[receipt.ProductId]
	if not player or not kind or not Data.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if Data.hasPurchase(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local grant = grants[kind]
	local ok, granted = pcall(function(): boolean
		return grant ~= nil and grant(player)
	end)
	if not ok or not granted then
		-- could not be applied right now: bank it so the Robux are never wasted
		if not Data.addKeys(player, 1) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		toast(player, "The offering could not be used right now. A Rusted Key has been kept for you instead.")
	end
	Data.recordPurchase(player, purchaseId)
	task.spawn(Data.save, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function loadPasses(player: Player)
	owned[player] = {}
	for key, pass in Config.Passes do
		player:SetAttribute("Pass_" .. key, false)
		if pass.Id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				setOwned(player, key)
			end
		end
	end
end

local function fetchPrices()
	local function fetch(scope: string, key: string, id: number, infoType: Enum.InfoType)
		if id == 0 then
			return
		end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			prices[scope .. ":" .. key] = info.PriceInRobux
		end
	end
	for key, product in Config.Products do
		fetch("Product", key, product.Id, Enum.InfoType.Product)
	end
	for key, pass in Config.Passes do
		fetch("Pass", key, pass.Id, Enum.InfoType.GamePass)
	end
	for _, callback in listeners do
		task.spawn(callback)
	end
end

function Store.init()
	for kind, product in Config.Products do
		if product.Id ~= 0 then
			kindByProductId[product.Id] = kind
		end
	end
	for key, pass in Config.Passes do
		if pass.Id ~= 0 then
			keyByPassId[pass.Id] = key
		end
	end
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = keyByPassId[passId]
		if purchased and key then
			setOwned(player, key)
			toast(player, `{Config.Passes[key].Name} is yours.`)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	task.spawn(function()
		while true do
			fetchPrices()
			task.wait(600) -- prices can change while servers are up
		end
	end)
end

return Store
