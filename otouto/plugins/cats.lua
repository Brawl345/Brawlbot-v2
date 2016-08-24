local cats = {}

cats.command = 'cat [gif]'

function cats:init(config)
	if not cred_data.cat_apikey then
		print('Missing config value: cat_apikey.')
		print('cats.lua will be enabled, but there are more features with a key.')
	end

	cats.triggers = {
      "^/cat$",
	  "^/cat (gif)$"
	}
	
	cats.inline_triggers = {
	  "^cat (gif)$",
	  "^cat$"
	}
	
	cats.doc = [[*
]]..config.cmd_pat..[[cat*: Postet eine zufällige Katze
*]]..config.cmd_pat..[[cat* _gif_: Postet eine zufällige, animierte Katze]]
end


local apikey = cred_data.cat_apikey or "" -- apply for one here: http://thecatapi.com/api-key-registration.html

function cats:inline_callback(inline_query, config, matches)
  if matches[1] == 'gif' then
    img_type = 'gif'
	id = 100
  else
    img_type = 'jpg'
	id = 200
  end
  local url = 'https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20xml%20where%20url%3D%27http%3A%2F%2Fthecatapi.com%2Fapi%2Fimages%2Fget%3Fformat%3Dxml%26results_per_page%3D50%26type%3D'..img_type..'%26apikey%3D'..apikey..'%27&format=json' -- no way I'm using XML, plz die
  local res, code  = https.request(url)
  if code ~= 200 then return end
  local data = json.decode(res).query.results.response.data.images.image
  if not data then return end
  if not data[1] then return end
  
  local results = '['
  
  for n in pairs(data) do
    if img_type == 'gif' then
	  results = results..'{"type":"gif","id":"'..id..'","gif_url":"'..data[n].url..'","thumb_url":"'..data[n].url..'"}'
	  id = id+1
	else
      results = results..'{"type":"photo","id":"'..id..'","photo_url":"'..data[n].url..'","thumb_url":"'..data[n].url..'"}'
	  id = id+1
	end
	if n < #data then
	 results = results..','
	end
  end
  local results = results..']'
  utilities.answer_inline_query(inline_query, results, 30)
end

function cats:action(msg, config)
  if matches[1] == 'gif' then
    local url = 'http://thecatapi.com/api/images/get?type=gif&apikey='..apikey
	local file = download_to_file(url, 'miau.gif')
    utilities.send_document(msg.chat.id, file, nil, msg.message_id)
  else
    local url = 'http://thecatapi.com/api/images/get?type=jpg,png&apikey='..apikey
	local file = download_to_file(url, 'miau.png')
    utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
  end
end

return cats
