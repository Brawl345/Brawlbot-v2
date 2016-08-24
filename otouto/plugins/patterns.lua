local patterns = {}

function patterns:init(config)
  patterns.command = 's/<Pattern>/<Ersetzung>'
  patterns.triggers = {
  config.cmd_pat .. '?s/.-/.-$'
  }
end

function patterns:action(msg)
	if not msg.reply_to_message then return true end
	local output = msg.reply_to_message.text
	if msg.reply_to_message.from.id == self.info.id then
		output = output:gsub('Du meintest wohl:\n"', '')
		output = output:gsub('"$', '')
	end
	local m1, m2 = msg.text:match('^/?s/(.-)/(.-)/?$')
	if not m2 then return true end
	local res
	res, output = pcall(
		function()
			return output:gsub(m1, m2)
		end
	)
	if res == false then
		utilities.send_reply(msg, 'Falsches Pattern!')
	else
		output = output:sub(1, 4000)
		output = '*Du meintest wohl*:\n"'..utilities.md_escape(utilities.trim(output))..'"'
		utilities.send_reply(msg.reply_to_message, output, true)
	end
end

return patterns
