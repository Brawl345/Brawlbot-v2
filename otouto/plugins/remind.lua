local remind = {}

remind.command = 'remind <Länge> <Nachricht>'

function remind:init(config)
	self.database.reminders = self.database.reminders or {}

	remind.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('remind', true).table
	remind.doc = [[*
	]]..config.cmd_pat..[[remind* _<Länge>_ _<Nachricht>_: Erinnert dich in X Minuten an die Nachricht]]
end

function remind:action(msg)
  -- Ensure there are arguments. If not, send doc.
  local input = utilities.input(msg.text)
  if not input then
	utilities.send_message(self, msg.chat.id, remind.doc, true, msg.message_id, true)
	return
  end

  -- Ensure first arg is a number. If not, send doc.
  local duration = utilities.get_word(input, 1)
  if not tonumber(duration) then
	utilities.send_message(self, msg.chat.id, remind.doc, true, msg.message_id, true)
	return
  end

  -- Duration must be between one minute and one day (approximately).
  duration = tonumber(duration)
  if duration < 1 then
	duration = 1
  elseif duration > 1440 then
	duration = 1440
  end

  -- Ensure there is a second arg.
  local message = utilities.input(input)
  if not message then
	utilities.send_message(self, msg.chat.id, remind.doc, true, msg.message_id, true)
	return
  end
 
  -- Make a database entry for the group/user if one does not exist.
  self.database.reminders[msg.chat.id_str] = self.database.reminders[msg.chat.id_str] or {}
  -- Limit group reminders to 10 and private reminders to 50.
  if msg.chat.type ~= 'private' and utilities.table_size(self.database.reminders[msg.chat.id_str]) > 9 then
	utilities.send_reply(self, msg, 'Diese Gruppe hat schon zehn Erinnerungen!')
	return
  elseif msg.chat.type == 'private' and utilities.table_size(self.database.reminders[msg.chat.id_str]) > 49 then
	utilities.send_reply(msg, 'Du hast schon 50 Erinnerungen!')
	return
  end

  -- Put together the reminder with the expiration, message, and message to reply to.
  local timestamp = os.time() + duration * 60
  local reminder = {
	time = timestamp,
	message = message
  }
  table.insert(self.database.reminders[msg.chat.id_str], reminder)
  local human_readable_time = convert_timestamp(timestamp, '%H:%M:%S')
  local output = 'Ich werde dich um *'..human_readable_time..' Uhr* erinnern.'
  utilities.send_reply(self, msg, output, true)
end

function remind:cron()
	local time = os.time()
	-- Iterate over the group entries in the reminders database.
	for chat_id, group in pairs(self.database.reminders) do
		local new_group = {}
		-- Iterate over each reminder.
		for _, reminder in ipairs(group) do
			-- If the reminder is past-due, send it and nullify it.
			-- Otherwise, add it to the replacement table.
			if time > reminder.time then
				local output = '*ERINNERUNG:*\n"' .. utilities.md_escape(reminder.message) .. '"'
				local res = utilities.send_message(self, chat_id, output, true, nil, true)
				-- If the message fails to send, save it for later.
				if not res then
					table.insert(new_group, reminder)
				end
			else
				table.insert(new_group, reminder)
			end
		end
		-- Nullify the original table and replace it with the new one.
		self.database.reminders[chat_id] = new_group
		-- Nullify the table if it is empty.
		if #new_group == 0 then
			self.database.reminders[chat_id] = nil
		end
	end
end

return remind