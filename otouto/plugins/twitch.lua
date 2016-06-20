local twitch = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')

twitch.triggers = {
  "twitch.tv/([A-Za-z0-9-_-]+)"
}

local BASE_URL = 'https://api.twitch.tv'

function twitch:send_twitch_info(twitch_name)
  local url = BASE_URL..'/kraken/channels/'..twitch_name
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res)

  local display_name = data.display_name
  local name = data.name
  if not data.game then
    game = 'nichts'
  else
    game = data.game
  end
  local status = data.status
  local views = comma_value(data.views)
  local followers = comma_value(data.followers)
  local text = '*'..display_name..'* ('..name..') streamt *'..game..'*\n'..status..'\n_'..views..' Zuschauer insgesamt und '..followers..' Follower_'
  
  return text
end

function twitch:action(msg, config, matches)
  local text = twitch:send_twitch_info(matches[1])
  if not text then utilities.send_reply(self, msg, config.errors.connection) return end
  utilities.send_reply(self, msg, text, true)
end

return twitch
