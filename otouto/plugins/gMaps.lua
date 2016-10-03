local gMaps = {}

gMaps.command = 'loc <Ort>'

function gMaps:init(config)
	gMaps.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('loc', true).table
	gMaps.inline_triggers = {
	  "^loc (.+)"
	}
	gMaps.doc = [[*
]]..config.cmd_pat..[[loc* _<Ort>_: Sendet Ort via Google Maps]]
end

function gMaps:get_staticmap(area, lat, lon)
  local base_api = "https://maps.googleapis.com/maps/api"
  local url = base_api .. "/staticmap?size=600x300&zoom=12&center="..URL.escape(area).."&markers=color:red"..URL.escape("|"..area)

  return url
end

function gMaps:inline_callback(inline_query, config, matches)
  local place = matches[1]
  local coords = utilities.get_coords(place, config)
  if type(coords) == 'string' then abort_inline_query(inline_query) return end
  
  local results = '[{"type":"venue","id":"10","latitude":'..coords.lat..',"longitude":'..coords.lon..',"title":"Ort","address":"'..coords.addr..'"}]'

  utilities.answer_inline_query(inline_query, results, 10000)
end

function gMaps:action(msg, config)
  local input = utilities.input_from_msg(msg)
  if not input then
    utilities.send_reply(msg, gMaps.doc, true)
	return
  end

  utilities.send_typing(msg.chat.id, 'find_location')
  local coords = utilities.get_coords(input, config)
  if type(coords) == 'string' then
	utilities.send_reply(msg, coords)
	return
  end

  utilities.send_location(msg.chat.id, coords.lat, coords.lon, msg.message_id)
  utilities.send_photo(msg.chat.id, gMaps:get_staticmap(input, coords.lat, coords.lon), nil, msg.message_id)
end

return gMaps
