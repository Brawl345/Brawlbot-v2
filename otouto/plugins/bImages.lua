local bImages = {}

function bImages:init(config)
  if not cred_data.bing_search_key then
	print('Missing config value: bing_search_key.')
	print('bImages.lua will not be enabled.')
	return
  end

  bImages.triggers = {"^/nil$"}
  bImages.inline_triggers = {
	"^b (.*)",
	"^i (.+)"
  }
end

local apikey = cred_data.bing_search_key
local BASE_URL = 'https://api.cognitive.microsoft.com/bing/v5.0'

function bImages:getImages(query)
  local url = BASE_URL..'/images/search?q='..URL.escape(query)..'&count=50&mkt=de-de'
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body),
	  redirect = false,
      headers = {
	    ["Ocp-Apim-Subscription-Key"] = apikey
	  }
   }
  local ok, response_code, response_headers = https.request(request_constructor)
  if not ok then return end
  local images = json.decode(table.concat(response_body)).value
  if not images[1] then return end
  
  

  local results = '['
  local id = 300
  for n in pairs(images) do
    if images[n].encodingFormat == 'jpeg' then -- Inline-Querys MUST use JPEG photos!
      local photo_url = images[n].contentUrl
	  local thumb_url = images[n].thumbnailUrl
      results = results..'{"type":"photo","id":"'..id..'","photo_url":"'..photo_url..'","thumb_url":"'..thumb_url..'","photo_width":'..images[n].width..',"photo_height":'..images[n].height..',"reply_markup":{"inline_keyboard":[[{"text":"Bing aufrufen","url":"'..images[n].webSearchUrl..'"},{"text":"Bild öffnen","url":"'..photo_url..'"}]]}},'
	  id = id+1
	end
  end
  
  local results = results:sub(0, -2)
  local results = results..']'
  cache_data('bImages', string.lower(query), results, 1209600, 'key')
  return results
end

function bImages:inline_callback(inline_query, config, matches)
  local query = matches[1]
  local results = redis:get('telegram:cache:bImages:'..string.lower(query))
  if not results then
    results = bImages:getImages(query)
  end

  if not results then abort_inline_query(inline_query) return end 
  utilities.answer_inline_query(inline_query, results, 3600)
end

function bImages:action()
end

return bImages