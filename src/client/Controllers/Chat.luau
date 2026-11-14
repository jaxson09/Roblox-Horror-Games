--!strict
--[[
	Chat — keeps Roblox's chat window in its own column (top left) so it can
	never sit on top of the event line or the noise meter, and sets it in the
	game's typewriter face. The limits come from Layout, the same table the
	HUD is placed by.
]]

local TextChatService = game:GetService("TextChatService")

local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UserInputService = game:GetService("UserInputService")

local Chat = {}

function Chat.init()
	task.spawn(function()
		local window = TextChatService:WaitForChild("ChatWindowConfiguration", 15) :: ChatWindowConfiguration?
		local input = TextChatService:WaitForChild("ChatInputBarConfiguration", 15) :: ChatInputBarConfiguration?
		if not window then
			return
		end
		window.HorizontalAlignment = Enum.HorizontalAlignment.Left
		window.VerticalAlignment = Enum.VerticalAlignment.Top
		window.FontFace = Theme.Fonts.Body
		if input then
			input.FontFace = Theme.Fonts.Body
		end
		while true do
			local camera = workspace.CurrentCamera
			if camera then
				local view = camera.ViewportSize
				local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
				local maxWidth, maxHeight = Layout.chatLimit(view.X, view.Y, touch)
				-- measure what Roblox actually drew, and scale it down until it fits its column
				local right = window.AbsolutePosition.X + window.AbsoluteSize.X
				local bottom = window.AbsolutePosition.Y + window.AbsoluteSize.Y
				if input then
					right = math.max(right, input.AbsolutePosition.X + input.AbsoluteSize.X)
					bottom = math.max(bottom, input.AbsolutePosition.Y + input.AbsoluteSize.Y)
				end
				if right > maxWidth + 1 and window.WidthScale > 0.3 then
					window.WidthScale = math.max(0.3, window.WidthScale * maxWidth / right)
				end
				if bottom > maxHeight + 1 and window.HeightScale > 0.3 then
					window.HeightScale = math.max(0.3, window.HeightScale * maxHeight / bottom)
				end
			end
			task.wait(1)
		end
	end)
end

return Chat
