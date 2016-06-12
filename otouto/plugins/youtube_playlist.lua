local youtube_playlist = {}

local utilities = require('otouto.utilities')
local https = require('ssl.https')
local JSON = require('dkjson')

function youtube_playlist:init(config)
	if not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('youtube_playlist.lua will not be enabled.')
		return
	end
	
	youtube_playlist.triggers = {
		"youtube.com/playlist%?list=([A-Za-z0-9-_-]+)"
	}
	youtube_playlist.doc = [[*YouTube-PlayList-Link*: Postet Infos zu PlayList]]
end

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function youtube_playlist:get_pl_data (pl_code)
  local BASE_URL = 'https://www.googleapis.com/youtube/v3'
  local apikey = cred_data.google_apikey
  local url = BASE_URL..'/playlists?part=snippet,contentDetails&key='..apikey..'&id='..pl_code..'&fields=items(snippet(publishedAt,channelTitle,localized(title,description)),contentDetails(itemCount))'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = JSON.decode(res).items[1]
  return data
end

function youtube_playlist:send_youtubepl_data(data)
  local title = data.snippet.localized.title
  if data.snippet.localized.description == '(null)' or data.snippet.localized.description == '' then
    description = ''
  else
    description = '\n'..data.snippet.localized.description
  end
  local author = data.snippet.channelTitle
  local creation_date = makeOurDate(data.snippet.publishedAt)
  if data.contentDetails.itemCount == 1 then
    itemCount = data.contentDetails.itemCount..' Video'
  else
    itemCount = comma_value(data.contentDetails.itemCount)..' Videos'
  end
  local text = '*'..title..'*'..description..'\n_Erstellt von '..author..' am '..creation_date..', '..itemCount..'_'
  return text
end

function youtube_playlist:action(msg)
  if not msg.text:match('youtube.com/playlist%?list=([A-Za-z0-9-_-]+)') then
    return
  end
  local pl_code = msg.text:match('youtube.com/playlist%?list=([A-Za-z0-9-_-]+)')
  
  local data = youtube_playlist:get_pl_data(pl_code)
  local output = youtube_playlist:send_youtubepl_data(data)
  utilities.send_reply(self, msg, output, true)
end

return youtube_playlist