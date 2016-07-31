local flickr = {}

function flickr:init(config)
	if not cred_data.flickr_apikey then
		print('Missing config value: flickr_apikey.')
		print('flickr.lua will not be enabled.')
		return
	end

  flickr.triggers = {
	"flickr.com/photos/([A-Za-z0-9-_-]+)/([0-9]+)"
  }
end

local BASE_URL = 'https://api.flickr.com/services/rest'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)%:(%d+)"
  local year, month, day, hours, minutes, seconds = dateString:match(pattern)
  return day..'.'..month..'.'..year..' um '..hours..':'..minutes..':'..seconds..' Uhr'
end

function flickr:get_flickr_photo_data (photo_id)
  local apikey = cred_data.flickr_apikey
  local url = BASE_URL..'/?method=flickr.photos.getInfo&api_key='..apikey..'&photo_id='..photo_id..'&format=json&nojsoncallback=1'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).photo
  return data
end

function flickr:send_flickr_photo_data(data)
  local title = data.title._content
  local username = data.owner.username
  local taken = data.dates.taken
  local views = data.views
  if data.usage.candownload == 1 then
    local text = '"'..title..'", aufgenommen am '..makeOurDate(taken)..' von '..username..' ('..comma_value(data.views)..' Aufrufe)'
    local image_url = 'https://farm'..data.farm..'.staticflickr.com/'..data.server..'/'..data.id..'_'..data.originalsecret..'_o_d.'..data.originalformat
	if data.originalformat == 'gif' then
	  return text, image_url, true
	else
	  return text, image_url
	end
  else
    return '"'..title..'", aufgenommen '..taken..' von '..username..' ('..data.views..' Aufrufe)\nBild konnte nicht gedownloadet werden (Keine Berechtigung)'
  end
end

function flickr:action(msg, config, matches)
  local data = flickr:get_flickr_photo_data(matches[2])
  if not data then utilities.send_reply(self, msg, config.errors.connection) return end
  local text, image_url, isgif = flickr:send_flickr_photo_data(data)
  
  if image_url then
    utilities.send_typing(self, msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url)
	if isgif then
	  utilities.send_document(self, msg.chat.id, file, text, msg.message_id)
	  return
	else
      utilities.send_photo(self, msg.chat.id, file, text, msg.message_id)
	  return
	end
  else
    utilities.send_reply(self, msg, text)
	return
  end
end

return flickr