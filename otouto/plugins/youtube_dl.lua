local youtube_dl = {}

function youtube_dl:init(config)
  youtube_dl.triggers = {
	"^/(mp4) https?://w?w?w?%.?youtu.be/([A-Za-z0-9-_-]+)",
	"^/(mp4) https?://w?w?w?%.?youtube.com/embed/([A-Za-z0-9-_-]+)",
	"^/(mp4) https?://w?w?w?%.?youtube.com/watch%?v=([A-Za-z0-9-_-]+)",
	"^/(mp3) https?://w?w?w?%.?youtu.be/([A-Za-z0-9-_-]+)",
	"^/(mp3) https?://w?w?w?%.?youtube.com/embed/([A-Za-z0-9-_-]+)",
	"^/(mp3) https?://w?w?w?%.?youtube.com/watch%?v=([A-Za-z0-9-_-]+)"
  }
	
  youtube_dl.doc = [[*
]]..config.cmd_pat..[[mp3* _<URL>_: Lädt Audio von YouTube
*]]..config.cmd_pat..[[mp4* _<URL>_: Lädt Video von YouTube
]]
end

youtube_dl.command = 'mp3 <URL>, /mp4 <URL>'

function youtube_dl:convert_video(id, chosen_res)
  local ytdl_json = io.popen('youtube-dl -f '..chosen_res..' --max-filesize 49m -j https://www.youtube.com/watch/?v='..id):read('*all')
  if not ytdl_json then return end
  local data = json.decode(ytdl_json)
  return data
end

function youtube_dl:convert_audio(id)
  local output = io.popen('youtube-dl --max-filesize 49m -o "/tmp/%(title)s.%(ext)s" --extract-audio --audio-format mp3 https://www.youtube.com/watch/?v='..id):read('*all')
  if string.match(output, '.* File is larger .*') then
    return 'TOOBIG'
  end
  local audio = string.match(output, '%[ffmpeg%] Destination: /tmp/(.*).mp3')
  return '/tmp/'..audio..'.mp3'
end

function youtube_dl:action(msg, config, matches)
  local id = matches[2]
  local hash = 'user:'..msg.from.id
  local chosen_res = redis:hget(hash, 'yt_dl_res_ordner')
  if not chosen_res then
    chosen_res = '22/18/43/36/17'
  end

  if matches[1] == 'mp4' then
    local first_msg = utilities.send_reply(self, msg, '<b>Video wird heruntergeladen...</b>', 'HTML')
    utilities.send_typing(self, msg.chat.id, 'upload_video')
    local data = youtube_dl:convert_video(id, chosen_res)
	if not data then
	  utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, config.errors.results)
	  return
	end

    local ext = data.ext
    local resolution = data.resolution
    local url = data.url
    local headers = get_http_header(url) -- need to get full url, because first url is actually a 302
    local full_url = headers.location
	if not full_url then
	  utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, config.errors.connection)
	  return
	end

    local headers = get_http_header(full_url) -- YES TWO FCKING HEAD REQUESTS
    if tonumber(headers["content-length"]) > 52420000 then
	  utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, '<b>Das Video überschreitet die Grenze von 50 MB!</b>\n<a href="'..full_url..'">Direktlink zum Video</a> ('..resolution..')', nil, 'HTML')
	  return
    end
    local file = download_to_file(full_url, id..'.'..ext)
	local width = data.width
	local height = data.width
	local duration = data.duration
	utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, '<a href="'..full_url..'">Direktlink zum Video</a> ('..resolution..')', nil, 'HTML')
	utilities.send_video(self, msg.chat.id, file, nil, msg.message_id, duration, width, height)
    return
  end
  
  if matches[1] == 'mp3' then
    local first_msg = utilities.send_reply(self, msg, '<b>Audio wird heruntergeladen...</b>', 'HTML')
    utilities.send_typing(self, msg.chat.id, 'upload_audio')
    local file = youtube_dl:convert_audio(id)
	if file == 'TOOBIG' then
	  utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, '<b>Die MP3 überschreitet die Grenze von 50 MB!</b>', nil, 'HTML')
	  return
	end
	utilities.send_audio(self, msg.chat.id, file, msg.message_id)
	return
  end
end

return youtube_dl
