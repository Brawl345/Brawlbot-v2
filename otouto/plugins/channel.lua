local channel = {}

local bindings = require('otouto.bindings')
local utilities = require('otouto.utilities')

channel.command = 'ch <Kanal> \\n <Nachricht>'
channel.doc = [[*
/ch*_ <Kanal>_
_<Nachricht>_

Sendet eine Nachricht in den Kanal. Der Kanal kann per Username oder ID bestimmt werden, Markdown wird unterstützt. Du musst Administrator oder Besitzer des Kanals sein.

Markdown-Syntax:
 *Fetter Text*
 _Kursiver Text_
 [Text](URL)
 `Inline-Codeblock`
 `‌`‌`Größere Code-Block über mehrere Zeilen`‌`‌`
 
*Der Kanalname muss mit einem @ beginnen!*]]

function channel:init(config)
	channel.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('ch', true).table
end

function channel:action(msg, config)
	local input = utilities.input(msg.text)
	local output
	if input then
		local chat_id = utilities.get_word(input, 1)
		local admin_list, t = bindings.getChatAdministrators(self, { chat_id = chat_id } )
		if admin_list then
			local is_admin = false
			for _, admin in ipairs(admin_list.result) do
				if admin.user.id == msg.from.id then
					is_admin = true
				end
			end
			if is_admin then
				local text = input:match('\n(.+)')
				if text then
					local success, result = utilities.send_message(self, chat_id, text, true, nil, true)
					if success then
						output = 'Deine Nachricht wurde versendet!'
					else
						output = 'Sorry, ich konnte deine Nachricht nicht senden.\n`' .. result.description .. '`'
					end
				else
					output = 'Bitte gebe deine Nachricht ein. Markdown wird unterstützt.'
				end
			else
				output = 'Es sieht nicht so aus, als wärst du der Administrator dieses Kanals.'
			end
		else
			output = 'Sorry, ich konnte die Administratorenliste nicht abrufen. Falls du den Kanalnamen benutzt: Beginnt er mit einem @?\n`' .. t.description .. '`'
		end
	else
		output = channel.doc
	end
	utilities.send_reply(self, msg, output, true)
end

return channel
