local spotify = {}

spotify.triggers = {
  "open.spotify.com/track/([A-Za-z0-9-]+)",
  "play.spotify.com/track/([A-Za-z0-9-]+)"
}

local BASE_URL = 'https://api.spotify.com/v1'

function spotify:get_track_data(track)
  local url = BASE_URL..'/tracks/'..track
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  return data
end

function spotify:send_track_data(data, msg)
	local name = data.name
    local album = data.album.name
    local artist = data.artists[1].name
	local preview = data.preview_url
	local milliseconds = data.duration_ms
	
	-- convert s to mm:ss
	local totalseconds = math.floor(milliseconds / 1000)
    local duration = makeHumanTime(totalseconds)
	
    local text = '*'..name..'* von *'..artist..'* aus dem Album *'..album..'* _('..duration..')_'
	if preview then
	  utilities.send_typing(msg.chat.id, 'upload_audio')
	  local file = download_to_file(preview, name..'.mp3')
      utilities.send_audio(msg.chat.id, file, msg.message_id, totalseconds, artist, name)
	  return
	else
	  utilities.send_reply(msg, text, true)
	  return
	end
end

function spotify:action(msg, config, matches)
  local data = spotify:get_track_data(matches[1])
  if not data then utilities.send_reply(msg, config.errors.connection) return end
  spotify:send_track_data(data, msg)
  return
end

return spotify
