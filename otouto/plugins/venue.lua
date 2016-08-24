local venue = {}

venue.triggers = {
  '/nil'
}

local apikey = cred_data.google_apikey

function venue:pre_process(msg)
  if not msg.venue then return msg end -- Ignore

  local lat = msg.venue.location.latitude
  local lng = msg.venue.location.longitude
  local url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng='..lat..','..lng..'&result_type=street_address&language=de&key='..apikey
  local res, code = https.request(url)
  if code ~= 200 then return msg end
  local data = json.decode(res).results[1]
  local city = data.formatted_address
  utilities.send_reply(msg, city)
  
  return msg
end

function venue:action(msg)
end

return venue
