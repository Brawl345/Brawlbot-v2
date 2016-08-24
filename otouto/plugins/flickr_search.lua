local flickr_search = {}

function flickr_search:init(config)
	if not cred_data.flickr_apikey then
		print('Missing config value: flickr_apikey.')
		print('flickr_search.lua will not be enabled.')
		return
	end

  flickr_search.triggers = {
	"^/flickr (.*)$"
  }
end

flickr_search.command = 'flickr <Suchbegriff>'

local apikey = cred_data.flickr_apikey
local BASE_URL = 'https://api.flickr.com/services/rest'

function flickr_search:get_flickr (term)
  local url = BASE_URL..'/?method=flickr.photos.search&api_key='..apikey..'&format=json&nojsoncallback=1&privacy_filter=1&safe_search=3&extras=url_o&text='..term
  local b,c = https.request(url)
  if c ~= 200 then return nil end
  local photo = json.decode(b).photos.photo
  -- truly randomize
  math.randomseed(os.time())
  -- random max json table size
  local i = math.random(#photo)
  local link_image = photo[i].url_o
  return link_image
end

function flickr_search:action(msg, config, matches)
  local url = flickr_search:get_flickr(matches[1])
  if not url then utilities.send_reply(msg, config.errors.results) return end
  
  local file = download_to_file(url)
  
  if string.ends(url, ".gif") then
    utilities.send_document(msg.chat.id, file, url)
	return
  else
    utilities.send_photo(msg.chat.id, file, url)
	return
  end
end

return flickr_search