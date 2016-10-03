-- Thanks to Akamaru for the API entrypoints and the initial idea

local gfycat = {}

gfycat.triggers = {
	"gfycat.com/([A-Za-z0-9-_-]+)"
}

function gfycat:send_gfycat_video(name, msg)
  local BASE_URL = "https://gfycat.com"
  local url = BASE_URL..'/cajax/get/'..name
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res).gfyItem
  utilities.send_typing(msg.chat.id, 'upload_video')
  local file = download_to_file(data.mp4Url)
  if tonumber(data.mp4Size) > 20971520 then
    file = download_to_file(data.mp4Url)
  else
    file = data.mp4Url
  end
  utilities.send_video(msg.chat.id, file, nil, msg.message_id)
end

function gfycat:action(msg, config, matches)
  local name = matches[1]
  gfycat:send_gfycat_video(name, msg)
  return
end

return gfycat
