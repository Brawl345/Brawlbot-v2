local adfly = {}

local utilities = require('otouto.utilities')
local HTTPS = require('ssl.https')
local redis = (loadfile "./otouto/redis.lua")()

function adfly:init(config)
	adfly.triggers = {
		'adf.ly/([A-Za-z0-9-_-]+)'
	}
	adfly.doc = [[*adf.ly-Link*: Postet vollen Link]]
end

function adfly:expand_adfly_link(adfly_code)
  local BASE_URL = 'https://andibi.tk/dl/adfly.php'
  local url = BASE_URL..'/?url=http://adf.ly/'..adfly_code
  local res,code  = HTTPS.request(url)
  if code ~= 200 then return nil end
  if res == 'Fehler: Keine Adf.ly-URL gefunden!' then return 'NOTFOUND' end
  cache_data('adfly', adfly_code, res, 31536000, 'key')
  return res
end

function adfly:action(msg)
  local input = msg.text
  if not input:match('adf.ly/([A-Za-z0-9-_-]+)') then
    return
  end
  
  local adfly_code = input:match('adf.ly/([A-Za-z0-9-_-]+)')
  local hash = 'telegram:cache:adfly:'..adfly_code
  if redis:exists(hash) == false then
    local expanded_url = adfly:expand_adfly_link(adfly_code)
	if not expanded_url then
      utilities.send_reply(self, msg, config.errors.connection)
	  return
	end
	if expanded_url == 'NOTFOUND' then
	  utilities.send_reply(self, msg, 'Fehler: Keine Adf.ly-URL gefunden!')
	  return
	end
	utilities.send_reply(self, msg, expanded_url)
  else
    local data = redis:get(hash)
	utilities.send_reply(self, msg, data)
  end
end

return adfly
