local soundcloud = {}

soundcloud.triggers = {
  "soundcloud.com/([A-Za-z0-9-/-_-.]+)"
}

local BASE_URL = 'http://api.soundcloud.com/resolve.json'
local client_id = cred_data.soundcloud_client_id

function soundcloud:send_soundcloud_info(sc_url)
  local url = BASE_URL..'?url=http://soundcloud.com/'..sc_url..'&client_id='..client_id

  local res,code  = http.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  
  local title = data.title
  local description = data.description
  local user = data.user.username
  local user = 'Unbekannt'
  local genre = data.genre
  local playback_count = data.playback_count
  local milliseconds = data.duration
  local totalseconds = math.floor(milliseconds / 1000)
  local duration = makeHumanTime(totalseconds)
  
  local text = '*'..title..'* von _'..user..'_\n_(Tag: '..genre..', '..duration..'; '..playback_count..' mal angehört)_\n'..description
  return text
end

function soundcloud:action(msg, config, matches)
  local text = soundcloud:send_soundcloud_info(matches[1])
  if not text then utilities.send_reply(msg, config.errors.connection) return end
  utilities.send_reply(msg, text, true)
end

return soundcloud
