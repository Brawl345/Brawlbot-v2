local cleverbot = {}

function cleverbot:init(config)
	cleverbot.triggers = {
	"^/cbot (.+)$",
	"^[Bb]rawlbot, (.+)$",
	"^[Bb]ot, (.+)$"
	}
end

cleverbot.command = 'cbot <Text>'

local BASE_URL = 'https://www.cleverbot.com/getreply'
local apikey = cred_data.cleverbot_apikey -- get your key here: https://www.cleverbot.com/api/

function cleverbot:action(msg, config, matches)
  utilities.send_typing(msg.chat.id, 'typing')
  local text = matches[1]
  local query, code = https.request(BASE_URL..'?key='..apikey..'&input='..URL.escape(text))
  if code ~= 200 then
	utilities.send_reply(msg, config.errors.connection)
	return
  end

  local data = json.decode(query)
  if not data.output then
    utilities.send_reply(msg, 'Ich möchte jetzt nicht reden...')
	return
  end

  utilities.send_reply(msg, data.output)
end

return cleverbot