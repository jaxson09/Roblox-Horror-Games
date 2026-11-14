--!strict
--[[ Sfx — creates Sound instances from Config.Sounds keys. A key whose id is 0 yields a silent Sound, so nothing else needs to care. ]]

local Config = require(script.Parent.Config)

local Sfx = {}

export type SoundProps = {
	Volume: number?,
	Looped: boolean?,
	Speed: number?,
	MinDistance: number?,
	MaxDistance: number?,
	Group: SoundGroup?,
}

function Sfx.id(key: string): string
	local id = Config.Sounds[key]
	if id == nil or id == 0 then
		return ""
	end
	return "rbxassetid://" .. tostring(id)
end

function Sfx.make(parent: Instance, key: string, props: SoundProps?): Sound
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = Sfx.id(key)
	sound.Volume = if props and props.Volume then props.Volume else 0.6
	sound.Looped = if props and props.Looped then true else false
	sound.PlaybackSpeed = if props and props.Speed then props.Speed else 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = if props and props.MinDistance then props.MinDistance else 12
	sound.RollOffMaxDistance = if props and props.MaxDistance then props.MaxDistance else 140
	if props and props.Group then
		sound.SoundGroup = props.Group
	end
	sound.Parent = parent
	return sound
end

-- Fire-and-forget positional sound at a world position.
function Sfx.playAt(position: Vector3, key: string, props: SoundProps?)
	if Sfx.id(key) == "" then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = "Sfx_" .. key
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local sound = Sfx.make(holder, key, props)
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	sound:Play()
	task.delay(30, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

return Sfx
