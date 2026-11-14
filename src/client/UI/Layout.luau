--!strict
--[[
	Layout — where every piece of the HUD goes. Pure numbers, no instances, so
	the same table is used by the game (Hud.luau) and by the offline check
	(tools/typecheck/test-layout.mjs) that proves nothing overlaps at phone,
	tablet and desktop sizes.

	The HUD is drawn in a "virtual" space: the real screen divided by
	Layout.scale(height). Every position below is in virtual pixels.

	Vertical bands (h = virtual height):
	  56 .. 208        event line, its sub-line, toasts       (centre column)
	  56 .. 232        objectives, vitals, location           (right column)
	  260 .. h-260     camcorder viewfinder                   (centre)
	  h-250 .. h-212   what it says
	  h-202 .. h-162   the ANSWER prompt
	  h-150 .. h-22    hotbar / locker panel / grab panel     (one slot, never together)
]]

local Layout = {}

export type Rect = { X: number, Y: number, W: number, H: number }

-- Real pixels per virtual pixel.
function Layout.scale(realHeight: number): number
	return math.clamp(realHeight / 800, 0.5, 1.1)
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { X = x, Y = y, W = w, H = h }
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
	Lobby = { "BannerHead", "BannerSub", "Toasts", "LobbyHint", "Fx" },
	Case = { "BannerHead", "BannerSub", "Toasts", "Card", "Vitals", "Location", "Noise", "Stamina", "Fx", "Slot1", "Slot2", "Slot3", "Hints", "Tracker", "Viewfinder", "Dazzle", "Subtitle", "Ask" },
	Locker = { "BannerHead", "BannerSub", "Toasts", "Card", "Vitals", "Location", "Noise", "Stamina", "Fx", "Hints", "Locker", "Subtitle", "Ask" },
	Grabbed = { "BannerHead", "BannerSub", "Toasts", "Subtitle", "Grab", "Fx" },
}

-- Things that sit inside another element on purpose.
Layout.Inside = { Dazzle = "Viewfinder" }

function Layout.rects(w: number, h: number, touch: boolean): { [string]: Rect }
	local columnX, columnW = 340, w - 680 -- the centre column, clear of the right-hand cards
	local finderH = math.max(140, h - 520)
	local finderW = finderH * 1.5
	local r: { [string]: Rect } = {
		BannerHead = rect(columnX, 56, columnW, 34),
		BannerSub = rect(columnX, 100, columnW, 34),
		Toasts = rect(columnX, 142, columnW, 66),
		Card = rect(w - 324, 56, 300, 118),
		Vitals = rect(w - 324, 180, 300, 30),
		Viewfinder = rect(w / 2 - finderW / 2, 260, finderW, finderH),
		Dazzle = rect(w / 2 - 45, h / 2 - 22, 90, 4),
		Subtitle = rect(w * 0.22, h - 250, w * 0.56, 38),
		Ask = rect(w / 2 - 100, h - 202, 200, 40),
		Locker = rect(w / 2 - 180, h - 150, 360, 110),
		Grab = rect(w / 2 - 190, h - 134, 380, 84),
		Tracker = rect(w / 2 - 90, h - 92, 180, 18),
		Slot1 = rect(w / 2 - 117, h - 62, 74, 40),
		Slot2 = rect(w / 2 - 37, h - 62, 74, 40),
		Slot3 = rect(w / 2 + 43, h - 62, 74, 40),
		LobbyHint = rect(columnX, h - 80, columnW, 26),
	}
	if touch then
		-- thumbs own the bottom corners on a phone: the meter moves up under the top bar
		r.Noise = rect(24, 124, 190, 66)
		r.Stamina = rect(24, 198, 190, 4)
		r.Fx = rect(24, 212, 110, 22)
	else
		r.Location = rect(w - 324, 216, 300, 16)
		r.Noise = rect(24, h - 112, 190, 66)
		r.Stamina = rect(24, h - 38, 190, 4)
		r.Fx = rect(24, h - 26, 110, 22)
		r.Hints = rect(w - 264, h - 92, 240, 70)
	end
	return r
end

return Layout
