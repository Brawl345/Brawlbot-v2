local loc_manager = {}

local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()

function loc_manager:init(config)
    loc_manager.triggers = {
	  "^/location (set) (.*)$",
      "^/location (del)$",
	  "^/location$"
	}
	loc_manager.doc = [[*
]]..config.cmd_pat..[[location*: Gibt deinen gesetzten Wohnort aus
*]]..config.cmd_pat..[[location* _set_ _<Ort>_: Setzt deinen Wohnort auf diesen Ort
*]]..config.cmd_pat..[[location* _del_: Löscht deinen angegebenen Wohnort
]]
end

loc_manager.command = 'location'

function loc_manager:set_location(user_id, location)
  local hash = 'user:'..user_id
  local set_location = get_location(user_id)
  if set_location == location then
    return 'Dieser Ort wurde bereits gesetzt.'
  else
    print('Setting location in redis hash '..hash..' to location')
    redis:hset(hash, 'location', location)
    return 'Dein Wohnort wurde auf *'..location..'* festgelegt.'
  end
end

function loc_manager:del_location(user_id)
  local hash = 'user:'..user_id
  local set_location = get_location(user_id)
  if not set_location then
    return 'Du hast keinen Ort gesetzt'
  else
    print('Setting location in redis hash '..hash..' to false')
	-- We set the location to false, because deleting the value blocks redis for a few milliseconds
    redis:hset(hash, 'location', false)
    return 'Dein Wohnort *'..set_location..'* wurde gelöscht!'
  end
end

function loc_manager:action(msg, config, matches)
  local user_id = msg.from.id
  
  if matches[1] == 'set' then
	utilities.send_reply(self, msg, loc_manager:set_location(user_id, matches[2]), true)
	return
  elseif matches[1] == 'del' then
    utilities.send_reply(self, msg, loc_manager:del_location(user_id), true)
    return
  else
    local set_location = get_location(user_id)
    if not set_location then
	  utilities.send_reply(self, msg, '*Du hast keinen Ort gesetzt!*', true)
      return
    else
	  local coords = utilities.get_coords(set_location, config)
	  utilities.send_location(self, msg.chat.id, coords.lat, coords.lon, msg.message_id)
	  utilities.send_reply(self, msg, 'Gesetzter Wohnort: *'..set_location..'*', true)
	  return
    end
  end
end

return loc_manager
