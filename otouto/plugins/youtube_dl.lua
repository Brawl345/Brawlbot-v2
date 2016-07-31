local youtube_dl = {}

function youtube_dl:init(config)
  youtube_dl.triggers = {
	"^/(mp4) (https?://[%w-_%.%?%.:/%+=&]+)$",
	"^/(mp3) (https?://[%w-_%.%?%.:/%+=&]+)$"
  }
	
  youtube_dl.doc = [[*
]]..config.cmd_pat..[[mp3* _<URL>_: Lädt Audio von [untersützten Seiten](https://rg3.github.io/youtube-dl/supportedsites.html)
*]]..config.cmd_pat..[[mp4* _<URL>_: Lädt Video von [untersützten Seiten](https://rg3.github.io/youtube-dl/supportedsites.html)
]]
end

youtube_dl.command = 'mp3 <URL>, /mp4 <URL>'

function youtube_dl:convert_video(link)
  local output = io.popen('youtube-dl -f mp4 --max-filesize 49m -o "/tmp/%(title)s.%(ext)s" '..link):read('*all')
  print(output)
  if string.match(output, '.* File is larger .*') then
    return 'TOOBIG'
  end
  local video = string.match(output, '%[download%] Destination: /tmp/(.*).mp4')
  if not video then
    video = string.match(output, '%[download%] /tmp/(.*).mp4 has already been downloaded')
  end
  return  '/tmp/'..video..'.mp4'
end

function youtube_dl:convert_audio(link)
  local output = io.popen('youtube-dl --max-filesize 49m -o "/tmp/%(title)s.%(ext)s" --extract-audio --audio-format mp3 '..link):read('*all')
  print(output)
  if string.match(output, '.* File is larger .*') then
    return 'TOOBIG'
  end
  local audio = string.match(output, '%[ffmpeg%] Destination: /tmp/(.*).mp3')
  return '/tmp/'..audio..'.mp3'
end

function youtube_dl:action(msg, config)
  local link = matches[2]

  if matches[1] == 'mp4' then
    utilities.send_typing(self, msg.chat.id, 'upload_video')
    local file = youtube_dl:convert_video(link)
	if file == 'TOOBIG' then
	  utilities.send_reply(self, msg, 'Das Video überschreitet die Grenze von 50 MB!')
	  return
	end
	utilities.send_video(self, msg.chat.id, file, nil, msg.message_id)
    return
  end
  
  if matches[1] == 'mp3' then
    utilities.send_typing(self, msg.chat.id, 'upload_audio')
    local file = youtube_dl:convert_audio(link)
	if file == 'TOOBIG' then
	  utilities.send_reply(self, msg, 'Die MP3 überschreitet die Grenze von 50 MB!')
	  return
	end
	utilities.send_audio(self, msg.chat.id, file, msg.message_id)
	return
  end
end

return youtube_dl
