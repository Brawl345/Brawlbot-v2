local remind = {}

remind.command = 'remind <Länge> <Nachricht>'

function remind:init(config)
	self.database.reminders = self.database.reminders or {}

	remind.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('remind', true).table
	remind.doc = [[*
]]..config.cmd_pat..[[remind* _<Länge>_ _<Nachricht>_
Erinnert dich in der angegeben Länge in Minuten an eine Nachricht.
Die maximale Länge einer Erinnerung beträgt %s Buchstaben, die maximale Zeit beträgt %s Minuten, die maximale Anzahl an Erinnerung für eine Gruppe ist %s und für private Chats %s.]]
	remind.doc = remind.doc:format(config.remind.max_length, config.remind.max_duration, config.remind.max_reminders_group, config.remind.max_reminders_private)
end

function remind:action(msg, config)
  local input = utilities.input(msg.text)
  if not input then
	utilities.send_reply(msg, remind.doc, true)
	return
  end

  local duration = tonumber(utilities.get_word(input, 1))
  if not duration then
	utilities.send_reply(msg, remind.doc, true)
	return
  end

  if duration < 1 then
	duration = 1
  elseif duration > config.remind.max_duration then
	duration = config.remind.max_duration
  end

  local message
  if msg.reply_to_message and #msg.reply_to_message.text > 0 then
	message = msg.reply_to_message.text
  elseif utilities.input(input) then
	message = utilities.input(input)
  else
	utilities.send_reply(msg, remind.doc, true)
	return
  end

  if #message > config.remind.max_length then
	utilities.send_reply(msg, 'Die maximale Länge einer Erinnerung ist ' .. config.remind.max_length .. '.')
	return
  end
 
  local chat_id_str = tostring(msg.chat.id)
  local output
  self.database.reminders[chat_id_str] = self.database.reminders[chat_id_str] or {}
  if msg.chat.type == 'private' and utilities.table_size(self.database.reminders[chat_id_str]) >= config.remind.max_reminders_private then
	output = 'Sorry, du kannst keine Erinnerungen mehr hinzufügen.'
  elseif msg.chat.type ~= 'private' and utilities.table_size(self.database.reminders[chat_id_str]) >= config.remind.max_reminders_group then
	output = 'Sorry, diese Gruppe kann keine Erinnerungen mehr hinzufügen.'
  else
	-- Put together the reminder with the expiration, message, and message to reply to.
	local timestamp = os.time() + duration * 60
	local reminder = {
	  time = timestamp,
	  message = message
	}
	table.insert(self.database.reminders[chat_id_str], reminder)
	local human_readable_time = convert_timestamp(timestamp, '%H:%M:%S')
	output = 'Ich werde dich um *'..human_readable_time..' Uhr* erinnern.'
  end
  utilities.send_reply(msg, output, true)
end

function remind:cron(config)
	local time = os.time()
	-- Iterate over the group entries in the reminders database.
	for chat_id, group in pairs(self.database.reminders) do
		-- Iterate over each reminder.
		for k, reminder in pairs(group) do
			-- If the reminder is past-due, send it and nullify it.
			-- Otherwise, add it to the replacement table.
			if time > reminder.time then
				local output = '*ERINNERUNG:*\n"' .. utilities.md_escape(reminder.message) .. '"'
				local res = utilities.send_message(chat_id, output, true, nil, true)
				-- If the message fails to send, save it for later (if enabled in config).
				if res or not config.remind.persist then
					group[k] = nil
				end
			end
		end
	end
end

return remind