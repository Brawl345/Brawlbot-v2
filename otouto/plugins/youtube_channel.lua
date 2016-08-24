local youtube_channel = {}

function youtube_channel:init(config)
	if not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('youtube_channel.lua will not be enabled.')
		return
	end
	
	youtube_channel.triggers = {
		"youtube.com/user/([A-Za-z0-9-_-]+)",
		"youtube.com/channel/([A-Za-z0-9-_-]+)"
	}
	youtube_channel.doc = [[*YouTube-Channel-Link*: Postet Infos zum Kanal]]
end

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function youtube_channel:get_yt_channel_data(channel_name)
  local BASE_URL = 'https://www.googleapis.com/youtube/v3'
  local apikey = cred_data.google_apikey
  local url = BASE_URL..'/channels?part=snippet,statistics&key='..apikey..'&forUsername='..channel_name..'&fields=items%28snippet%28publishedAt,localized%28title,description%29%29,statistics%28viewCount,subscriberCount,videoCount%29%29'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).items[1]
  if data == nil then
    local url = BASE_URL..'/channels?part=snippet,statistics&key='..apikey..'&id='..channel_name..'&fields=items%28snippet%28publishedAt,localized%28title,description%29%29,statistics%28viewCount,subscriberCount,videoCount%29%29'
    local res,code  = https.request(url)
	if code ~= 200 then return "HTTP-FEHLER" end
    return json.decode(res).items[1]
  end
  return data
end

function youtube_channel:send_yt_channel_data(data)
  local name = data.snippet.localized.title
  local creation_date = makeOurDate(data.snippet.publishedAt)
  local description = data.snippet.localized.description
  local views = comma_value(data.statistics.viewCount)
  local subscriber = comma_value(data.statistics.subscriberCount)
  if subscriber == "0" then subscriber = "0 (ausgblendet?)" end
  local videos = comma_value(data.statistics.videoCount)
  local text = '*'..name..'*\n_Registriert am '..creation_date..', '..views..' Video-Aufrufe insgesamt, '..subscriber..' Abonnenten und '..videos..' Videos_\n'..description
  return text
end

function youtube_channel:action(msg)
  if not msg.text:match('youtube.com/user/([A-Za-z0-9-_-]+)') and not msg.text:match('youtube.com/channel/([A-Za-z0-9-_-]+)') then
    return
  end
  local channel_name = msg.text:match('youtube.com/user/([A-Za-z0-9-_-]+)')
  if not channel_name then channel_name = msg.text:match('youtube.com/channel/([A-Za-z0-9-_-]+)') end
  
  local data = youtube_channel:get_yt_channel_data(channel_name)
  local output = youtube_channel:send_yt_channel_data(data)
  utilities.send_reply(msg, output, true)
end

return youtube_channel