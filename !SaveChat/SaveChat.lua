----------------------------------------------------------------------------------------------------
-- logging messages
----------------------------------------------------------------------------------------------------
-- Messages are saved as they happen because the chat copy methods that addons use won't be able to
-- get the full log instantly when logging off/reloading. Also, GetMessageInfo() isn't in TBC.

-- new ChatFrame:AddMessage() to save each message
local OriginalAddMessage = ChatFrame1.AddMessage
local function NewAddMessage(frame, text, r, g, b, a, hold)
	-- Prat and Chatter will set a loading flag if readding back lines after setting a frame's max
	-- line option - all of that is already added back so just ignore these messages
	if (Prat and Prat.loading) or (Chatter and Chatter.loading) then
		return
	end
	-- save the line to the chat log
	if frame.saveChatLog then
		local log = frame.saveChatLog
		local first = log.first
		log.last = log.last + 1
		log[log.last] = {text, r, g, b}
		if first < log.last - frame:GetMaxLines() + 1 then
			log[first] = nil
			log.first = first + 1
		end
	end
	OriginalAddMessage(frame, text, r, g, b, a, hold)
end

-- new ChatFrame:Clear() to remove all saved messages
local OriginalClear = ChatFrame1.Clear
local function NewClear(frame)
	if frame.saveChatLog then
		frame.saveChatLog = {first=0, last=-1}
	end
	OriginalClear(frame)
end

-- new ChatFrame:SetMaxLines() to handle it in a way to keep messages
local OriginalSetMaxLines = ChatFrame1.SetMaxLines
local function NewSetMaxLines(frame, lines)
	OriginalSetMaxLines(frame, lines) -- will clear the chat frame's text
	if frame.saveChatLog then
		local log = frame.saveChatLog
		-- remove excess entries if needed
		local new_first = log.last - frame:GetMaxLines() + 1
		if log.first < new_first then
			for i=log.first,new_first-1 do
				log[i] = nil
			end
			log.first = new_first
		end
		-- add back the lines to the chat frame - it must be visible
		local visible = frame:IsVisible()
		if not visible then
			frame:Show()
		end
		for i=log.first,log.last do
			OriginalAddMessage(frame, log[i][1], log[i][2], log[i][3], log[i][4])
		end
		if not visible then
			frame:Hide()
		end
	end
end

-- set the hooks for each chat frame and add a message log table to them
for i=1,NUM_CHAT_WINDOWS do
	if i ~= 2 then -- don't want to add a chat log to the combat log
		local frame = _G["ChatFrame"..i]
		frame.AddMessage  = NewAddMessage
		frame.Clear       = NewClear
		frame.SetMaxLines = NewSetMaxLines
		frame.saveChatLog = {first=0, last=-1}
	end
end

----------------------------------------------------------------------------------------------------
-- saving/loading
----------------------------------------------------------------------------------------------------
local eventFrame = CreateFrame("frame")
eventFrame:SetScript("OnEvent", function(self, event, addon_name)
	-- add back the saved chat text when loading
	if event == "ADDON_LOADED" then
		if addon_name ~= "!SaveChat" then
			return
		end
		eventFrame:UnregisterEvent(event)

		local frame, visible, line_count
		for i=1,NUM_CHAT_WINDOWS do
			if SaveChatSave and SaveChatSave[i] and next(SaveChatSave[i]) then
				frame = _G["ChatFrame"..i]
				line_count = #SaveChatSave[i]
				-- set maximum lines if needed
				if frame:GetMaxLines() < line_count then
					frame:SetMaxLines(line_count)
				end
				-- must show the frame before adding to it
				visible = frame:IsVisible()
				if not visible then
					frame:Show()
				end
				-- add each line
				for j=1,line_count do
					frame:AddMessage(SaveChatSave[i][j][1], SaveChatSave[i][j][2], SaveChatSave[i][j][3],
					                 SaveChatSave[i][j][4])
				end
				-- set the frame back to its original visible state
				if not visible then
					frame:Hide()
				end
				-- the lines are no longer needed here so can be deleted to free some memory
				SaveChatSave[i] = nil
			end
		end
		return
	end

	-- save the text of each chat frame when logging out/reloading
	if event == "PLAYER_LOGOUT" then
		SaveChatSave = SaveChatSave or {}
		for i=1,NUM_CHAT_WINDOWS do
			local frame = _G["ChatFrame"..i]
			SaveChatSave[i] = {}
			if frame.saveChatLog and frame.saveChatLog.last >= frame.saveChatLog.first then
				-- add a final message showing the session ended unless no new messages were shown
				if not frame.saveChatLog[frame.saveChatLog.last][1]:find("%-%-%- end of session: ") then
					frame:AddMessage("--- end of session: "..date())
				end
				for j=frame.saveChatLog.first,frame.saveChatLog.last do
					SaveChatSave[i][#SaveChatSave[i]+1] = frame.saveChatLog[j]
				end
			end
		end
		return
	end
end)
eventFrame:RegisterEvent("ADDON_LOADED")  -- temporary - to add the chat text back when loading
eventFrame:RegisterEvent("PLAYER_LOGOUT") -- to save the chat text when logging out/reloading
