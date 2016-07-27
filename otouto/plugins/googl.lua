local googl = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')

function googl:init(config)
  if not cred_data.google_apikey then
    print('Missing config value: google_apikey.')
    print('googl.lua will not be enabled.')
    return
  end

  googl.triggers = {
	"goo.gl/([A-Za-z0-9-_-/-/]+)"
  }
  
  googl.inline_triggers = googl.triggers
end
	
local BASE_URL = 'https://www.googleapis.com/urlshortener/v1'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function googl:inline_callback(inline_query, config, matches)
  local shorturl = matches[1]
  local text, longUrl = googl:send_googl_info(shorturl)
  if not longUrl then return end

  local results = '[{"type":"article","id":"'..math.random(100000000000000000)..'","title":"Verlängerte URL","description":"'..longUrl..'","url":"'..longUrl..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/generic/internet.jpg","thumb_width":165,"thumb_height":150,"hide_url":true,"input_message_content":{"message_text":"'..text..'"}}]'
  utilities.answer_inline_query(self, inline_query, results, 1)
end

function googl:send_googl_info (shorturl)
  local apikey = cred_data.google_apikey
  local url = BASE_URL..'/url?key='..apikey..'&shortUrl=http://goo.gl/'..shorturl..'&projection=FULL&fields=longUrl,created,analytics(allTime(shortUrlClicks))'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  
  local longUrl = data.longUrl
  local shortUrlClicks = data.analytics.allTime.shortUrlClicks
  local created = makeOurDate(data.created)
  local text = longUrl..'\n'..shortUrlClicks..' mal geklickt (erstellt am '..created..')'
  
  return text, longUrl
end

function googl:action(msg, config, matches)
  local shorturl = matches[1]
  local text = googl:send_googl_info(shorturl)
  if not text then utilities.send_reply(self, msg, config.errors.connection) return end
  utilities.send_reply(self, msg, text)
end

return googl
