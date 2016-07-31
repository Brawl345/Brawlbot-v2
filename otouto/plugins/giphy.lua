local giphy = {}

function giphy:init(config)
  giphy.triggers = {
    "/nil"
  }
  giphy.inline_triggers = {
    "^(gif) (.+)",
    "^(gif)$"
  }
end

local BASE_URL = 'http://api.giphy.com/v1/gifs'
local apikey = 'dc6zaTOxFJmzC' -- public beta key

function giphy:get_gifs(query)
  if not query then
    url = BASE_URL..'/trending?api_key='..apikey
  else
    url = BASE_URL..'/search?q='..URL.escape(query)..'&api_key='..apikey
  end
  local res, code = http.request(url)
  if code ~= 200 then return nil end
  return json.decode(res).data
end

function giphy:inline_callback(inline_query, config, matches)
  if not matches[2] then
    data = giphy:get_gifs()
  else
    data = giphy:get_gifs(matches[2])
  end
  if not data then return end
  if not data[1] then return end
  local results = '['
  
  for n in pairs(data) do
    results = results..'{"type":"mpeg4_gif","id":"'..math.random(100000000000000000)..'","mpeg4_url":"'..data[n].images.original.mp4..'","thumb_url":"'..data[n].images.fixed_height.url..'","mpeg4_width":'..data[n].images.original.width..',"mp4_height":'..data[n].images.original.height..'}'
	if n < #data then
	 results = results..','
	end
  end
  local results = results..']'
  utilities.answer_inline_query(self, inline_query, results, 3600)
end

function giphy:action()
end

return giphy