local luarun = {}

function luarun:init(config)
	luarun.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('lua', true):t('return', true).table
	if config.luarun_serpent then
		serpent = require('serpent')
		luarun.serialize = function(t)
			return serpent.block(t, {comment=false})
		end
	else
		JSON = require('dkjson')
		luarun.serialize = function(t)
			return JSON.encode(t, {indent=true})
		end
	end
end

function luarun:action(msg, config)

	if not is_sudo(msg, config) then
		return true
	end

	local input = utilities.input(msg.text)
	if not input then
		utilities.send_reply(self, msg, 'Bitte gebe einen Befehl ein.')
		return
	end

	if msg.text_lower:match('^'..config.cmd_pat..'return') then
		input = 'return ' .. input
	end

	local output = loadstring( [[
		local bot = require('otouto.bot')
		local bindings = require('otouto.bindings')
		local utilities = require('otouto.utilities')
		local json = require('dkjson')
		local URL = require('socket.url')
		local http = require('socket.http')
		local https = require('ssl.https')
		return function (self, msg, config) ]] .. input .. [[ end
	]] )()(self, msg, config)
	if output == nil then
		output = 'Ausgeführt!'
	else
		if type(output) == 'table' then
			local s = luarun.serialize(output)
			if URL.escape(s):len() < 4000 then
				output = s
			end
		end
		output = '```\n' .. tostring(output) .. '\n```'
	end
	utilities.send_message(self, msg.chat.id, output, true, msg.message_id, true)

end

return luarun