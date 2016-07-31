local cleverbot = {}

function cleverbot:init(config)
	cleverbot.triggers = {
	"^/cbot (.*)$"
	}
	
	cleverbot.doc = [[*
]]..config.cmd_pat..[[cbot* _<Text>_*: Befragt den Cleverbot]]
end

cleverbot.command = 'cbot <Text>'

function cleverbot:action(msg, config)
  local text = msg.text
  local url = "https://brawlbot.tk/apis/chatter-bot-api/cleverbot.php?text="..URL.escape(text)
  local query = https.request(url)
  if query == nil then utilities.send_reply(self, msg, 'Ein Fehler ist aufgetreten :(') return end
  local decode = json.decode(query)
  local answer = string.gsub(decode.clever, "&Auml;", "Ä")
  local answer = string.gsub(answer, "&auml;", "ä")
  local answer = string.gsub(answer, "&Ouml;", "Ö")
  local answer = string.gsub(answer, "&ouml;", "ö")
  local answer = string.gsub(answer, "&Uuml;", "Ü")
  local answer = string.gsub(answer, "&uuml;", "ü")
  local answer = string.gsub(answer, "&szlig;", "ß")
  utilities.send_reply(self, msg, answer)
end

return cleverbot
