local pixabay = {}

function pixabay:init(config)
  if not cred_data.pixabay_apikey then
	print('Missing config value: pixabay_apikey.')
	print('pixabay.lua will not be enabled.')
	return
  end

  pixabay.triggers = {
    "^/pix(id) (%d+)",
    "^/pix (.*)$",
	"(pixabay.com).*%-(%d+)"
  }
	pixabay.doc = [[*
]]..config.cmd_pat..[[pix* _<Suchbegriff>_: Sendet lizenzfreies Bild]]
end

pixabay.command = 'pix <Suchbegriff>'

local BASE_URL = 'https://pixabay.com/api'
local apikey = cred_data.pixabay_apikey

function pixabay:get_pixabay_directlink(id)
  local url = BASE_URL..'/?key='..apikey..'&lang=de&id='..id
  local b,c = https.request(url)
  if c ~= 200 then return nil end
  local data = json.decode(b)
  if data.totalHits == 0 then return 'NOPIX' end

  local webformatURL = data.hits[1].webformatURL
  local image_url = string.gsub(webformatURL, '_640.jpg', '_960.jpg')
  
  -- Link to full, high resolution image
  local preview_url = data.hits[1].previewURL
  local image_code = string.sub(preview_url, 59)
  local image_code = string.sub(image_code, 0, -9)
  local full_url = 'https://pixabay.com/de/photos/download/'..image_code..'.jpg'
  
  local user = data.hits[1].user
  local tags = data.hits[1].tags
  local page_url = data.hits[1].pageURL
  
  -- cache this shit
  local hash = 'telegram:cache:pixabay:'..id
  print('Caching data in '..hash..' with timeout 1209600')
  redis:hset(hash, 'image_url', image_url)
  redis:hset(hash, 'full_url', full_url)
  redis:hset(hash, 'page_url', page_url)
  redis:hset(hash, 'user', user)
  redis:hset(hash, 'tags', tags)
  redis:expire(hash, 1209600) -- 1209600 = two weeks
  
  return image_url, full_url, page_url, user, tags
end

function pixabay:get_pixabay(term)
  local count = 70 -- how many pictures should be returned (3 to 200) NOTE: more pictures = higher load time
  local url = BASE_URL..'/?key='..apikey..'&lang=de&safesearch=true&per_page='..count..'&image_type=photo&q='..term
  local b,c = https.request(url)
  if c ~= 200 then return nil end
  local photo = json.decode(b)
  if photo.totalHits == 0 then return 'NOPIX' end
  local photos = photo.hits
  -- truly randomize
  math.randomseed(os.time())
  -- random max json table size
  local i = math.random(#photos)
  
  local webformatURL = photos[i].webformatURL
  local image_url = string.gsub(webformatURL, '_640.jpg', '_960.jpg')
  
  -- Link to full, high resolution image
  local preview_url = photos[i].previewURL
  local image_code = string.sub(preview_url, 59)
  local image_code = string.sub(image_code, 0, -9)
  local full_url = 'https://pixabay.com/de/photos/download/'..image_code..'.jpg'
  
  local user = photos[i].user
  local tags = photos[i].tags
  local page_url = photos[i].pageURL
  
  return image_url, full_url, page_url, user, tags
end

function pixabay:action(msg, config, matches)
  local term = matches[1]
  if matches[2] then
    if redis:exists("telegram:cache:pixabay:"..matches[2]) == true then -- if cached
	  local hash = 'telegram:cache:pixabay:'..matches[2]
	  url = redis:hget(hash, 'image_url')
	  full_url = redis:hget(hash, 'full_url')
	  page_url = redis:hget(hash, 'page_url')
	  user = redis:hget(hash, 'user')
	  tags = redis:hget(hash, 'tags')
	else
      url, full_url, page_url, user, tags = pixabay:get_pixabay_directlink(matches[2])
	end
  else
    url, full_url, page_url, user, tags = pixabay:get_pixabay(term)
  end
  
  if url == 'NOPIX' then
    utilities.send_reply(msg, config.errors.results)
	return
  else
    utilities.send_typing(msg.chat.id, 'upload_photo')
	local text = '"'..tags..'" von '..user
    utilities.send_photo(msg.chat.id, url, text, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..page_url..'"},{"text":"Volles Bild (Login notwendig)","url":"'..full_url..'"}]]}')
    return
  end
end

return pixabay
