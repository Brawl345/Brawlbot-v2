-- Thanks to Akamaru for the API entrypoints and the initial idea

local gfycat = {}

gfycat.triggers = {
	"gfycat.com/([A-Za-z0-9-_-]+)"
}

function gfycat:send_gfycat_video(name, self, msg)
  local BASE_URL = "https://gfycat.com"
  local url = BASE_URL..'/cajax/get/'..name
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).gfyItem
  utilities.send_typing(self, msg.chat.id, 'upload_video')
  local file = download_to_file(data.webmUrl)
  if file == nil then
    send_reply(self, msg, 'Fehler beim Herunterladen von '..name)
	return
  else
    utilities.send_video(self, msg.chat.id, file, nil, msg.message_id)
	return
  end
end

function gfycat:action(msg, config, matches)
  local name = matches[1]
  gfycat:send_gfycat_video(name, self, msg)
  return
end

return gfycat
