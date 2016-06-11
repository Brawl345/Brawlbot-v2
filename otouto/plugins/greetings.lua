 -- Put this on the bottom of your plugin list, after help.lua.
 -- If you want to configure your own greetings, copy the following table
 -- (without the "config.") to your config.lua file.

local greetings = {}

local utilities = require('otouto.utilities')

function greetings:init(config)
	config.greetings = config.greetings or {
		['Hello, #NAME.'] = {
			'hello',
			'hey',
			'sup',
			'hi',
			'good morning',
			'good day',
			'good afternoon',
			'good evening'
		},
		['Goodbye, #NAME.'] = {
			'bye',
			'later',
			'see ya',
			'good night'
		},
		['Welcome back, #NAME.'] = {
			'i\'m home',
			'i\'m back'
		},
		['You\'re welcome, #NAME.'] = {
			'thanks',
			'thank you'
		}
	}

	greetings.triggers = {
		self.info.first_name:lower() .. '%p*$'
	}
end

function greetings:action(msg, config)

	local nick = self.database.users[msg.from.id_str].nickname or msg.from.first_name

	for trigger,responses in pairs(config.greetings) do
		for _,response in pairs(responses) do
			if msg.text_lower:match(response..',? '..self.info.first_name:lower()) then
				utilities.send_message(self, msg.chat.id, utilities.latcyr(trigger:gsub('#NAME', nick)))
				return
			end
		end
	end

	return true

end

return greetings
