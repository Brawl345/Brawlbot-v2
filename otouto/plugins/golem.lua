local golem = {}

function golem:init(config)
	if not cred_data.golem_apikey then
		print('Missing config value: golem_apikey.')
		print('golem.lua will not be enabled.')
		return
	end

  golem.triggers = {
	"golem.de/news/([A-Za-z0-9-_-]+)-(%d+).html"
  }
end

local BASE_URL = 'http://api.golem.de/api'

function golem:get_golem_data (article_identifier)
  local apikey = cred_data.golem_apikey
  local url = BASE_URL..'/article/meta/'..article_identifier..'/?key='..apikey..'&format=json'
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).data

  local url = BASE_URL..'/article/images/'..article_identifier..'/?key='..apikey..'&format=json'
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local image_data = json.decode(res).data
  return data, image_data
end

function golem:send_golem_data(data, image_data)
  local headline = '*'..data.headline..'*'
  if data.subheadline ~= "" then
    subheadline = '\n_'..data.subheadline..'_'
  else
    subheadline = ""
  end
  local subheadline = data.subheadline
  local abstracttext = data.abstracttext
  local text = headline..subheadline..'\n'..abstracttext
  if image_data[1] then
    image_url = image_data[1].native.url
  else
	image_url = data.leadimg.url
  end
  return text, image_url
end

function golem:action(msg, config, matches)
  local article_identifier = matches[2]
  local data, image_data = golem:get_golem_data(article_identifier)
  if not data and not image_data then utilities.send_reply(msg, config.errors.connection) return end
  local text, image_url = golem:send_golem_data(data, image_data)
  
  if image_url then
    utilities.send_typing(msg.chat.id, 'upload_photo')
    utilities.send_photo(msg.chat.id, image_url, nil, msg.message_id)
  end
  utilities.send_reply(msg, text, true)
end

return golem