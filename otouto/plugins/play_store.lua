local play_store = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')

function play_store:init(config)
  if not cred_data.x_mashape_key then
	print('Missing config value: x_mashape_key.')
	print('play_store.lua will not be enabled.')
	return
  end

  play_store.triggers = {
	"play.google.com/store/apps/details%?id=(.*)"
  }
end

local BASE_URL = 'https://apps.p.mashape.com/google/application'

function play_store:get_playstore_data (appid)
  local apikey = cred_data.x_mashape_key
  local url = BASE_URL..'/'..appid..'?mashape-key='..apikey
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res).data
  return data
end

function play_store:send_playstore_data(data)
  local title = data.title
  local developer = data.developer.id
  local category = data.category.name
  local rating = data.rating.average
  local installs = data.performance.installs
  local description = data.description
  if data.version == "Varies with device" then
    appversion = "variiert je nach Gerät"
  else
    appversion = data.version
  end
  if data.price == 0 then
    price = "Gratis"
  else
    price = data.price
  end
  local text = '*'..title..'* von *'..developer..'* aus der Kategorie _'..category..'_, durschnittlich bewertet mit '..rating..' Sternen.\n_'..description..'_\n'..installs..' Installationen, Version '..appversion
  return text
end

function play_store:action(msg, config, matches)
  local appid = matches[1]
  local data = play_store:get_playstore_data(appid)
  if data == nil then
    return
  else
	utilities.send_reply(self, msg, play_store:send_playstore_data(data), true)
	return
   end
end

return play_store
