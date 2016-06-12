require("./otouto/plugins/youtube")

local yt_search = {}

local utilities = require('otouto.utilities')
local https = require('ssl.https')
local URL = require('socket.url')
local JSON = require('dkjson')

yt_search.command = 'yt <Suchbegriff>'

function yt_search:init(config)
	if not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('youtube_search.lua will not be enabled.')
		return
	end
	
	yt_search.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('yt', true):t('youtube', true).table
	yt_search.doc = [[*
]]..config.cmd_pat..[[yt* _<Suchbegriff>_: Sucht nach einem YouTube-Video]]
end

local BASE_URL = 'https://www.googleapis.com/youtube/v3'

function searchYoutubeVideo(text)
  local apikey = cred_data.google_apikey
  local data = httpsRequest('https://www.googleapis.com/youtube/v3/search?part=snippet&key='..apikey..'&maxResults=1&type=video&q=' .. URL.escape(text))
  if not data then
    print("HTTP-Fehler")
    return nil
  elseif not data.items[1] then
    return "YouTube-Video nicht gefunden!"
  end
  local videoId = data.items[1].id.videoId
  local videoURL = 'https://youtube.com/watch?v='..videoId
  return videoURL, videoId
end

function httpsRequest(url)
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  return JSON.decode(res)
end

function yt_search:action(msg)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(self, msg.chat.id, yt_search.doc, true, msg.message_id, true)
	  return
	end
  end

  local link, videoId = searchYoutubeVideo(input)
  if link == "YouTube-Video nicht gefunden!" or nil then utilities.send_reply(self, msg, 'YouTube-Video nicht gefunden!') return end
 
  local data = get_yt_data(videoId)

  send_youtube_data(data, msg, self, link, true)
  return
end

return yt_search