local botan = {}

local https = require('ssl.https')
local URL = require('socket.url')
local redis = (loadfile "./otouto/redis.lua")()
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

function botan:init(config)
  if not config.botan_token then
	print('Missing config value: botan_token.')
	print('botan.lua will not be enabled.')
	return
  end
  botan.triggers = {
    "^/nil$"
	}
end

local BASE_URL = 'https://api.botan.io/track'

function botan:appmetrica(text, token, plugin_name)
  https.request(BASE_URL..'/?token='..token..'&uid=1&name='..plugin_name)
end

function botan:action(msg, config, matches, plugin_name)
  if not plugin_name then
    return
  end

  botan:appmetrica(msg.text, config.botan_token, plugin_name)
end

return botan