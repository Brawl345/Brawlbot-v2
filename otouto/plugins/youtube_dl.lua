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

function youtube_dl:get_availabe_formats(id, hash)
  local ytdl_json = io.popen('youtube-dl -j https://www.youtube.com/watch/?v='..id):read('*all')
  if not ytdl_json then return end
  local data = json.decode(ytdl_json)
  
  local available_formats = {}
  redis:hset(hash, 'duration', data.duration)
  
  -- Building table with infos
  for n=1, #data.formats do
    local vid_format = data.formats[n].format
	local format_num = vid_format:match('^(%d+) ')	 
	local valid_nums = {['17'] = true, ['36'] = true, ['43'] = true, ['18'] = true, ['22'] = true}
	if not vid_format:match('DASH') and valid_nums[format_num] then -- We don't want DASH videos!
	  local format_info = {}
	  format_info.format = format_num
	  local hash = hash..':'..format_num
	  if format_num == '17' then
	    format_info.pretty_format = '144p'
	  elseif format_num == '36' then
	    format_info.pretty_format = '180p'
	  elseif format_num == '43' then
	    format_info.pretty_format = '360p WebM'
	  elseif format_num == '18' then
	    format_info.pretty_format = '360p MP4'
	  elseif format_num == '22' then
	    format_info.pretty_format = '720p'
	  end
	  format_info.ext = data.formats[n].ext
	  local url = data.formats[n].url
	  local headers = get_http_header(url)
	  local full_url = headers.location
	  local headers = get_http_header(full_url) -- first was for 302, this get's use the size
	  if headers.location then -- There are some videos where there is a "chain" of 302... repeat this, until we get the LAST url!
	    repeat
		  headers = get_http_header(headers.location)
		until not headers.location
	  end

	  format_info.url = full_url
	  local size = tonumber(headers["content-length"])
	  format_info.size = size
	  format_info.pretty_size = string.gsub(tostring(round(size / 1048576, 2)), '%.', ',')..' MB' -- 1048576 = 1024*1024
	  available_formats[#available_formats+1] = format_info
	  redis:hset(hash, 'ext', format_info.ext)
	  redis:hset(hash, 'format', format_info.pretty_format)
	  redis:hset(hash, 'url', full_url)
	  redis:hset(hash, 'size', size)
	  redis:hset(hash, 'height', data.formats[n].height)
	  redis:hset(hash, 'width', data.formats[n].width)
	  redis:hset(hash, 'pretty_size', format_info.pretty_size)
	  redis:expire(hash, 7889400)
	end
  end
  
  return available_formats
end

function youtube_dl:convert_audio(id)
  local output = io.popen('youtube-dl --max-filesize 49m -o "/tmp/%(title)s.%(ext)s" --extract-audio --audio-format mp3 https://www.youtube.com/watch/?v='..id):read('*all')
  if string.match(output, '.* File is larger .*') then
    return 'TOOBIG'
  end
  local audio = string.match(output, '%[ffmpeg%] Destination: /tmp/(.*).mp3')
  return '/tmp/'..audio..'.mp3'
end

function youtube_dl:callback(callback, msg, self, config, input)
  utilities.answer_callback_query(self, callback, 'Informationen werden verarbeitet...')
  local video_id = input:match('(.+)@')
  local vid_format = input:match('@(%d+)')
  local hash = 'telegram:cache:youtube_dl:mp4:'..video_id
  local format_hash = hash..':'..vid_format
  if not redis:exists(format_hash) then
    youtube_dl:get_availabe_formats(video_id, hash)
  end
  
  local duration = redis:hget(hash, 'duration')
  local format_info = redis:hgetall(format_hash)

  local full_url = format_info.url
  local width = format_info.width
  local height = format_info.height
  local ext = format_info.ext
  local pretty_size = format_info.pretty_size
  local size = tonumber(format_info.size)
  local format = format_info.format
  
  if size > 52420000 then
    utilities.edit_message(self, msg.chat.id, msg.message_id, '<a href="'..full_url..'">Direktlink zum Video</a> ('..format..', '..pretty_size..')', nil, 'HTML')
	return
  end
  
  utilities.edit_message(self, msg.chat.id, msg.message_id, '<b>Video wird hochgeladen</b>', nil, 'HTML')
  utilities.send_typing(self, msg.chat.id, 'upload_video')
  
  local file = download_to_file(full_url, video_id..'.'..ext)
  if not file then return end
  utilities.send_video(self, msg.chat.id, file, nil, msg.message_id, duration, width, height)
  utilities.edit_message(self, msg.chat.id, msg.message_id, '<a href="'..full_url..'">Direktlink zum Video</a> ('..format..', '..pretty_size..')', nil, 'HTML')
end

function youtube_dl:action(msg, config, matches)
  if msg.chat.type ~= 'private' then
    utilities.send_reply(self, msg, 'Dieses Plugin kann nur im Privatchat benutzt werden')
	return
  end
  local id = matches[2]

  if matches[1] == 'mp4' then
    local hash = 'telegram:cache:youtube_dl:mp4:'..id
    local first_msg = utilities.send_reply(self, msg, '<b>Verfügbare Videoformate werden ausgelesen...</b>', 'HTML')
	local callback_keyboard = redis:hget(hash, 'keyboard')
	if not callback_keyboard then
	  utilities.send_typing(self, msg.chat.id, 'typing')
      local available_formats = youtube_dl:get_availabe_formats(id, hash)
	  if not available_formats then
	    utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, config.errors.results)
	    return
	  end

	  local callback_buttons = {}
	  for n=1, #available_formats do
        local video = available_formats[n]
	    local format = video.format
	    local size = video.size
	    local pretty_size = video.pretty_size
	    if size > 52420000 then
	      pretty_format = video.pretty_format..' ('..pretty_size..', nur Link)'
	    else
	      pretty_format = video.pretty_format..' ('..pretty_size..')'
	    end
	    local button = '{"text":"'..pretty_format..'","callback_data":"@'..self.info.username..' youtube_dl:'..id..'@'..format..'"}'
	    callback_buttons[#callback_buttons+1] = button
	  end
	
	  local keyboard = '{"inline_keyboard":['
	  for button in pairs(callback_buttons) do
	    keyboard = keyboard..'['..callback_buttons[button]..']'
		if button < #callback_buttons then
		  keyboard = keyboard..','
		end
	  end
	  
	  callback_keyboard = keyboard..']}'
	  redis:hset(hash, 'keyboard', callback_keyboard)
	  redis:expire(hash, 7889400)
	end
	utilities.edit_message(self, msg.chat.id, first_msg.result.message_id, 'Wähle die gewünschte Auflösung.', nil, nil, callback_keyboard)
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
