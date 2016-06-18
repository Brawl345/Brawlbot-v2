local deviantart = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')

deviantart.triggers = {
  "http://(.*).deviantart.com/art/(.*)"
}

local BASE_URL = 'https://backend.deviantart.com'

function deviantart:get_da_data (da_code)
  local url = BASE_URL..'/oembed?url='..da_code
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  return data
end

function deviantart:send_da_data (data)
  local title = data.title
  local category = data.category
  local author_name = data.author_name
  local text = title..' von '..author_name..'\n'..category
  
  if data.rating == "adult" then
    return title..' von '..author_name..'\n'..category..'\n(NSFW)'
  else
    local image_url = data.fullsize_url
    if image_url == nil then
      image_url = data.url
    end 
	local file = download_to_file(image_url)
    return text, file
  end
end

function deviantart:action(msg, config, matches)
  local data = deviantart:get_da_data('http://'..matches[1]..'.deviantart.com/art/'..matches[2])
  if not data then utilities.send_reply(self, msg, config.errors.connection) return end
  
  local text, file = deviantart:send_da_data(data)
  if file then
    utilities.send_photo(self, msg.chat.id, file, text, msg.message_id)
  else
    utilities.send_reply(self, msg, text)
	return
  end
end

return deviantart
