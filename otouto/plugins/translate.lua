local translate = {}

local HTTPS = require('ssl.https')
local URL = require('socket.url')
local JSON = require('dkjson')
local utilities = require('otouto.utilities')

translate.command = 'translate [text]'

function translate:init(config)
	translate.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('translate', true):t('tl', true).table
	translate.doc = [[```
]]..config.cmd_pat..[[translate [text]
Translates input or the replied-to message into the bot's language.
```]]
end

function translate:action(msg, config)

	local input = utilities.input(msg.text)
	if not input then
		if msg.reply_to_message and msg.reply_to_message.text then
			input = msg.reply_to_message.text
		else
			utilities.send_message(self, msg.chat.id, translate.doc, true, msg.message_id, true)
			return
		end
	end

	local url = 'https://translate.yandex.net/api/v1.5/tr.json/translate?key=' .. config.yandex_key .. '&lang=' .. config.lang .. '&text=' .. URL.escape(input)

	local str, res = HTTPS.request(url)
	if res ~= 200 then
		utilities.send_reply(self, msg, config.errors.connection)
		return
	end

	local jdat = JSON.decode(str)
	if jdat.code ~= 200 then
		utilities.send_reply(self, msg, config.errors.connection)
		return
	end

	local output = jdat.text[1]
	output = '*Translation:*\n"' .. utilities.md_escape(output) .. '"'

	utilities.send_reply(self, msg.reply_to_message or msg, output, true)

end

return translate
