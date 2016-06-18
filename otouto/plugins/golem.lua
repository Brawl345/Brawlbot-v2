local golem = {}

local http = require('socket.http')
local json = require('dkjson')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

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
  return data
end

function golem:send_golem_data(data)
  local headline = '*'..data.headline..'*'
  if data.subheadline ~= "" then
    subheadline = '\n_'..data.subheadline..'_'
  else
    subheadline = ""
  end
  local subheadline = data.subheadline
  local abstracttext = data.abstracttext
  local text = headline..subheadline..'\n'..abstracttext
  local image_url = data.leadimg.url
  return text, image_url
end

function golem:action(msg, config, matches)
  local article_identifier = matches[2]
  local data = golem:get_golem_data(article_identifier)
  if not data then utilities.send_reply(self, msg, config.errors.connection) return end
  local text, image_url = golem:send_golem_data(data)
  
  if image_url then
    utilities.send_typing(self, msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url)
    utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
  end
  utilities.send_reply(self, msg, text, true)
end

return golem