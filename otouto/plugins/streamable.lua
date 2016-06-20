local streamable = {}

local https = require('ssl.https')
local json = require('dkjson')
local utilities = require('otouto.utilities')

streamable.triggers = {
	"streamable.com/([A-Za-z0-9-_-]+)",
}

function streamable:send_streamable_video(shortcode, self, msg)
  local BASE_URL = "https://api.streamable.com"
  local url = BASE_URL..'/videos/'..shortcode
  local res,code  = https.request(url)
  if code ~= 200 then return 'HTTP-Fehler' end
  local data = json.decode(res)
  if data.status ~= 2 then utilities.send_reply(self, msg, "Video ist (noch) nicht verfügbar.") return end
  
  if data.files.webm then
    if data.title == "" then title = shortcode..'.webm' else title = data.title..'.webm' end
    url = 'https:'..data.files.webm.url
	width = data.files.webm.width
	height = data.files.webm.height
    if data.files.webm.size > 50000000 then
	  local size = math.floor(data.files.webm.size / 1000000)
	  utilities.send_reply(self, msg, '*Video ist größer als 50 MB* ('..size..' MB)!\n[Direktlink]('..url..')', true)
	  return
	end
  elseif data.files.mp4 then
    if data.title == "" then title = shortcode..'.mp4' else title = data.title..'.mp4' end
    url = 'https:'..data.files.mp4.url
	width = data.files.mp4.width
	height = data.files.mp4.height
    if data.files.mp4.size > 50000000 then
	  local size = math.floor(data.files.mp4.size / 1000000)
	  utilities.send_reply(self, msg, '*Video ist größer als 50 MB* ('..size..' MB)!\n[Direktlink]('..url..')', true)
	  return
	end
  end
  
  utilities.send_typing(self, msg.chat.id, 'upload_video')
  local file = download_to_file(url, title)
  utilities.send_video(self, msg.chat.id, file, nil, msg.message_id, nil, width, height)
  return
end

function streamable:action(msg, config, matches)
  local shortcode = matches[1]
  streamable:send_streamable_video(shortcode, self, msg)
  return
end

return streamable
