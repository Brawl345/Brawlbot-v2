local bitly = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()

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
end
	
local BASE_URL = 'https://api-ssl.bitly.com/v3/expand'

function bitly:expand_bitly_link (shorturl)
  local access_token = cred_data.bitly_access_token
  local url = BASE_URL..'?access_token='..access_token..'&shortUrl=https://bit.ly/'..shorturl
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).data.expand[1]
  cache_data('bitly', shorturl, data)
  return data.long_url
end

function bitly:action(msg, config, matches)
  local shorturl = matches[1]
  local hash = 'telegram:cache:bitly:'..shorturl
  if redis:exists(hash) == false then
    utilities.send_reply(self, msg, bitly:expand_bitly_link(shorturl))
    return
  else
    local data = redis:hgetall(hash)
	utilities.send_reply(self, msg, data.long_url)
	return
  end
end

return bitly
