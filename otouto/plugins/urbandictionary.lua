local urbandictionary = {}

urbandictionary.command = 'urbandictionary <query>'

function urbandictionary:init(config)
	urbandictionary.triggers = utilities.triggers(self.info.username, config.cmd_pat)
		:t('urbandictionary', true):t('ud', true):t('urban', true).table
	urbandictionary.doc = [[```
]]..config.cmd_pat..[[urbandictionary <query>
Returns a definition from Urban Dictionary.
Aliases: ]]..config.cmd_pat..[[ud, ]]..config.cmd_pat..[[urban
```]]
end

function urbandictionary:action(msg, config)

	local input = utilities.input(msg.text)
	if not input then
		if msg.reply_to_message and msg.reply_to_message.text then
			input = msg.reply_to_message.text
		else
			utilities.send_message(self, msg.chat.id, urbandictionary.doc, true, msg.message_id, true)
			return
		end
	end

	local url = 'http://api.urbandictionary.com/v0/define?term=' .. URL.escape(input)

	local jstr, res = http.request(url)
	if res ~= 200 then
		utilities.send_reply(self, msg, config.errors.connection)
		return
	end

	local jdat = json.decode(jstr)
	if jdat.result_type == "no_results" then
		utilities.send_reply(self, msg, config.errors.results)
		return
	end

	local output = '<b>' .. jdat.list[1].word .. '</b>\n' .. utilities.trim(jdat.list[1].definition)
	if string.len(jdat.list[1].example) > 0 then
		output = output .. '<i>\n' .. utilities.trim(jdat.list[1].example) .. '</i>'
	end
	
	output = output:gsub('%[', ''):gsub('%]', '')

	utilities.send_reply(self, msg, output, 'HTML')

end

return urbandictionary
