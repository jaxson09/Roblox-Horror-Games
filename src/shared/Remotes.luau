--!strict
--[[
	Remotes — one RemoteEvent in each direction, addressed by message name.
	The server creates them; clients wait for them.

	Server -> client messages (ToClient):
	  Toast(text, kind?)            Subtitle(speaker, text, glitch?)
	  Jumpscare(fawnModel)          Flicker(seconds)
	  ScareAll(buyerName)           Shake(amount, seconds)
	  Elevator(direction, seconds)  Tape(index, title, body)
	  Note(id)                      Results(payload)
	  Sound(name, position?)        Objective(text)
	Client -> server messages (ToServer):
	  Sprint(on) Crouch(on) Flashlight(on) NightVision(on) HoldBreath(on)
	  ExitLocker() Struggle(on) Dazzle() IntroSeen()
	  PartyCreate(maxPlayers, difficulty, part) PartyStart() PartyLeave()
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local function get(name: string): RemoteEvent
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
		return remote
	end
	return ReplicatedStorage:WaitForChild(name) :: RemoteEvent
end

Remotes.ToClient = get("HS_ToClient")
Remotes.ToServer = get("HS_ToServer")

return Remotes
