local tagesschau = {}

local https = require('ssl.https')
local URL = require('socket.url')
local json = require('dkjson')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

tagesschau.triggers = {
  "tagesschau.de/([A-Za-z0-9-_-_-/]+).html"
}
  
local BASE_URL = 'https://www.tagesschau.de/api'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+)%:(%d+)%:(%d+)"
  local year, month, day, hours, minutes, seconds = dateString:match(pattern)
  return day..'.'..month..'.'..year..' um '..hours..':'..minutes..':'..seconds
end

function tagesschau:get_tagesschau_article(article)
  local url = BASE_URL..'/'..article..'.json'
  local res,code  = https.request(url)
  local data = json.decode(res)
  if code == 404 then return "Artikel nicht gefunden!" end
  if code ~= 200 then return "HTTP-Fehler" end
  if not data then return "HTTP-Fehler" end
  if data.type ~= "story" then
    print('Typ "'..data.type..'" wird nicht unterstützt')
    return nil
  end
  
  local title = data.topline..': '..data.headline
  local news = data.shorttext
  local posted_at = makeOurDate(data.date)..' Uhr'
  
  local text = '*'..title..'*\n_'..posted_at..'_\n'..news
  if data.banner[1] then
    return text, data.banner[1].variants[1].modPremium
  else
    return text
  end
end

function tagesschau:action(msg, config, matches)
  local article = matches[1]
  local text, image_url = tagesschau:get_tagesschau_article(article)
  if image_url then
    utilities.send_typing(self, msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url)
    utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
  end
  utilities.send_reply(self, msg, text, true)
end

return tagesschau