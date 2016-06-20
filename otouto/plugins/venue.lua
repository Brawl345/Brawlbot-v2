local venue = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')

venue.triggers = {
  '/nil'
}

local apikey = cred_data.google_apikey

function venue:pre_process(msg, self)
  if not msg.venue then return end -- Ignore

  local lat = msg.venue.location.latitude
  local lng = msg.venue.location.longitude
  local url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng='..lat..','..lng..'&result_type=street_address&language=de&key='..apikey
  local res, code = https.request(url)
  if code ~= 200 then return msg end
  local data = json.decode(res).results[1]
  local city = data.formatted_address
  utilities.send_reply(self, msg, city)
  
  return msg
end

function venue:action(msg)
end

return venue
