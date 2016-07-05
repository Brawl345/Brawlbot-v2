local about = {}

local bot = require('otouto.bot')
local utilities = require('otouto.utilities')

about.command = 'about'
about.doc = '`Sendet Informationen über den Bot.`'

about.triggers = {
	'/about',
	'/start'
}

function about:action(msg, config)

	-- Filthy hack, but here is where we'll stop forwarded messages from hitting
	-- other plugins.
	-- disabled to restore old behaviour
	-- if msg.forward_from then return end

	local output = config.about_text .. '\nBrawlbot v'..bot.version..', basierend auf Otouto von topkecleon.'

	if
		(msg.new_chat_member and msg.new_chat_member.id == self.info.id)
		or msg.text_lower:match('^'..config.cmd_pat..'about$')
		or msg.text_lower:match('^'..config.cmd_pat..'about@'..self.info.username:lower()..'$')
		or msg.text_lower:match('^'..config.cmd_pat..'start$')
		or msg.text_lower:match('^'..config.cmd_pat..'start@'..self.info.username:lower()..'$')
	then
		utilities.send_message(self, msg.chat.id, output, true, nil, true)
		return
	end

	return true

end

return about
