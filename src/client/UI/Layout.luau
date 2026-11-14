--!strict
--[[
	Layout — where every piece of the HUD goes. Pure numbers, no instances, so
	the same table is used by the game (Hud.luau) and by the offline check
	(tools/typecheck/test-layout.mjs) that proves nothing overlaps at phone,
	tablet and desktop sizes.

	The HUD is drawn in a "virtual" space: the real screen divided by
	Layout.scale(height, touch). Every position below is in virtual pixels.

	Two arrangements share the same pieces:

	  Desktop (h is about 800-1300)          Touch (h is about 580-820; larger type, tighter bands)
	  56 .. 208    event line, sub-line,     8 .. 112     event line, sub-line, messages
	               messages
	  56 .. 232    objectives, vitals,       12 .. 248    objectives, vitals, FX, noise meter
	               location (right)                       (right; the chat keeps the top left)
	  260 .. h-260 camcorder viewfinder      124 .. h-204 camcorder viewfinder
	  h-250..h-212 what it says              h-196..h-158 what it says
	  h-202..h-162 the ANSWER prompt         h-152..h-112 the ANSWER prompt
	  h-150..h-22  hotbar / locker / grab    h-106..h-10  hotbar / locker / grab
	               (one slot, never together)
	  bottom left  noise meter, FX           bottom       thumbstick (left), touch buttons (right)
	  bottom right key hints
]]

local Layout = {}

export type Rect = { X: number, Y: number, W: number, H: number }

-- Real pixels per virtual pixel. Touch screens are small and held close: they
-- get a larger scale (bigger type) and the tighter arrangement to pay for it.
function Layout.scale(realHeight: number, touch: boolean): number
	if touch then
		return math.clamp(realHeight / 640, 0.62, 1)
	end
	return math.clamp(realHeight / 800, 0.5, 1.1)
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { X = x, Y = y, W = w, H = h }
end

-- The centre column starts here (virtual px). Everything left of it, minus a gap,
-- belongs to Roblox's chat window.
local function columnStart(w: number, touch: boolean): number
	-- phones give the chat 30% of the screen; elsewhere a fixed 340 is plenty
	return if touch then math.max(340, w * 0.3 + 20) else 340
end

-- How wide and how tall the chat window may be, in REAL pixels (see Controllers/Chat).
function Layout.chatLimit(realWidth: number, realHeight: number, touch: boolean): (number, number)
	local scale = Layout.scale(realHeight, touch)
	return (columnStart(realWidth / scale, touch) - 20) * scale, realHeight * 0.5
end

-- Text sizes (virtual px). Single-line text is fitted, never wrapped.
Layout.Text = {
	BannerHead = 30,
	BannerSub = 13,
	Toast = 15,
	Subtitle = 30,
	Objective = 15,
	Hint = 12,
	LobbyHint = 17,
}

-- Touch buttons are placed in REAL pixels from the bottom-right corner
-- (offset to the button's left edge, offset to its top edge), and are square.
Layout.TouchButtonSize = 56
Layout.TouchButtons = {
	Run = { OX = 70, OY = 70 },
	Crouch = { OX = 132, OY = 70 },
	Cam = { OX = 70, OY = 132 },
	Shot = { OX = 132, OY = 132 },
	Light = { OX = 70, OY = 194 },
	Night = { OX = 132, OY = 194 },
} :: { [string]: { OX: number, OY: number } }

-- Which elements can be on screen at the same moment.
Layout.States = {
	Lobby = { "Chat", "BannerHead", "BannerSub", "Toasts", "LobbyHint", "Fx" },
	Case = { "Chat", "BannerHead", "BannerSub", "Toasts", "Card", "Vitals", "Location", "Noise", "Stamina", "Fx", "Slot1", "Slot2", "Slot3", "Hints", "Tracker", "Viewfinder", "Dazzle", "Subtitle", "Ask" },
	Locker = { "Chat", "BannerHead", "BannerSub", "Toasts", "Card", "Vitals", "Location", "Noise", "Stamina", "Fx", "Hints", "Locker", "Subtitle", "Ask" },
	Grabbed = { "Chat", "BannerHead", "BannerSub", "Toasts", "Subtitle", "Grab", "Fx" },
}

-- Things that sit inside another element on purpose.
Layout.Inside = { Dazzle = "Viewfinder" }

function Layout.rects(w: number, h: number, touch: boolean): { [string]: Rect }
	local columnX = columnStart(w, touch) -- the centre column: clear of the chat on the left and the cards on the right
	local columnW = w - columnX * 2
	local r: { [string]: Rect } = {
		-- not ours to draw: the most room Roblox's chat window is allowed to take
		Chat = rect(0, 0, columnX - 20, h * 0.5),
		Dazzle = rect(w / 2 - 45, h / 2 - 22, 90, 4),
		Slot1 = rect(w / 2 - 117, 0, 74, 40),
		Slot2 = rect(w / 2 - 37, 0, 74, 40),
		Slot3 = rect(w / 2 + 43, 0, 74, 40),
	}
	local finderTop: number, finderBottom: number
	if touch then
		r.BannerHead = rect(columnX, 8, columnW, 34)
		r.BannerSub = rect(columnX, 46, columnW, 20)
		r.Toasts = rect(columnX, 70, columnW, 42)
		r.Card = rect(w - 324, 12, 300, 118)
		r.Vitals = rect(w - 324, 136, 300, 30)
		-- thumbs own the bottom corners and the chat owns the top left,
		-- so the meter and the FX switch share a band under the vitals
		r.Fx = rect(w - 324, 172, 100, 22)
		r.Noise = rect(w - 214, 172, 190, 66)
		r.Stamina = rect(w - 214, 244, 190, 4)
		finderTop, finderBottom = 124, h - 204
		r.Subtitle = rect(w * 0.22, h - 196, w * 0.56, 38)
		r.Ask = rect(w / 2 - 100, h - 152, 200, 40)
		r.Locker = rect(w / 2 - 180, h - 106, 360, 96)
		r.Grab = rect(w / 2 - 190, h - 94, 380, 84)
		r.Tracker = rect(w / 2 - 90, h - 84, 180, 18)
		r.Slot1.Y, r.Slot2.Y, r.Slot3.Y = h - 56, h - 56, h - 56
		r.LobbyHint = rect(columnX, h - 46, columnW, 26)
	else
		r.BannerHead = rect(columnX, 56, columnW, 34)
		r.BannerSub = rect(columnX, 100, columnW, 34)
		r.Toasts = rect(columnX, 142, columnW, 66)
		r.Card = rect(w - 324, 56, 300, 118)
		r.Vitals = rect(w - 324, 180, 300, 30)
		r.Location = rect(w - 324, 216, 300, 16)
		finderTop, finderBottom = 260, h - 260
		r.Subtitle = rect(w * 0.22, h - 250, w * 0.56, 38)
		r.Ask = rect(w / 2 - 100, h - 202, 200, 40)
		r.Locker = rect(w / 2 - 180, h - 150, 360, 96)
		r.Grab = rect(w / 2 - 190, h - 134, 380, 84)
		r.Tracker = rect(w / 2 - 90, h - 92, 180, 18)
		r.Slot1.Y, r.Slot2.Y, r.Slot3.Y = h - 62, h - 62, h - 62
		r.LobbyHint = rect(columnX, h - 80, columnW, 26)
		r.Noise = rect(24, h - 112, 190, 66)
		r.Stamina = rect(24, h - 38, 190, 4)
		r.Fx = rect(24, h - 26, 110, 22)
		r.Hints = rect(w - 264, h - 92, 240, 70)
	end
	-- the viewfinder is 3:2, as tall as its band allows, and never wider than the centre column
	local finderH = math.max(120, finderBottom - finderTop)
	local finderW = math.min(finderH * 1.5, columnW)
	finderH = math.min(finderH, finderW / 1.2)
	r.Viewfinder = rect(w / 2 - finderW / 2, (finderTop + finderBottom) / 2 - finderH / 2, finderW, finderH)
	return r
end

return Layout
