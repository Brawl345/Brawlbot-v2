local bitly = {}

function bitly:init(config)
  if not cred_data.bitly_access_token then
    print('Missing config value: bitly_access_token.')
    print('bitly.lua will not be enabled.')
    return
  end

  bitly.triggers = {
	"bit.ly/([A-Za-z0-9-_-]+)",
	"bitly.com/([A-Za-z0-9-_-]+)",
	"j.mp/([A-Za-z0-9-_-]+)",
	"andib.tk/([A-Za-z0-9-_-]+)"
  }
  bitly.inline_triggers = bitly.triggers
end
	
local BASE_URL = 'https://api-ssl.bitly.com/v3/expand'

function bitly:expand_bitly_link (shorturl)
  local access_token = cred_data.bitly_access_token
  local url = BASE_URL..'?access_token='..access_token..'&shortUrl=https://bit.ly/'..shorturl
  local res, code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res).data.expand[1]
  cache_data('bitly', shorturl, data)
  return data.long_url
end

function bitly:inline_callback(inline_query, config, matches)
  local shorturl = matches[1]
  local hash = 'telegram:cache:bitly:'..shorturl
  if redis:exists(hash) == false then
    url = bitly:expand_bitly_link(shorturl)
  else
    local data = redis:hgetall(hash)
    url = data.long_url
  end
  
  if not url then utilities.answer_inline_query(self, inline_query) return end
  
  local results = '[{"type":"article","id":"2","title":"Verlängerte URL","description":"'..url..'","url":"'..url..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/generic/internet.jpg","thumb_width":165,"thumb_height":150,"hide_url":true,"input_message_content":{"message_text":"'..url..'"}}]'
  utilities.answer_inline_query(self, inline_query, results, 3600)
end

function bitly:action(msg, config, matches)
  local shorturl = matches[1]
  local hash = 'telegram:cache:bitly:'..shorturl
  if redis:exists(hash) == false then
    local longurl = bitly:expand_bitly_link(shorturl)
	if not longurl then
	  utilities.send_reply(self, msg, config.errors.connection)
	  return
	end
    utilities.send_reply(self, msg, longurl)
    return
  else
    local data = redis:hgetall(hash)
	utilities.send_reply(self, msg, data.long_url)
	return
  end
end

return bitly
