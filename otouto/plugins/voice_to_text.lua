local vtt = {}

vtt.triggers = {
  '/nil'
}

local apikey = cred_data.witai_apikey

function vtt:pre_process(msg, config)
  if not msg.voice then return msg end -- Ignore
  local mime_type = msg.voice.mime_type
  if mime_type ~= 'audio/ogg' then return msg end -- We only want to transcript voice messages
  local file_id = msg.voice.file_id
  local file_size = msg.voice.file_size
  if file_size > 19922944 then
	print('File is over 20 MB - can\'t download :(')
	return msg
  end
  
  utilities.send_typing(msg.chat.id, 'typing')
  -- Saving file to the Telegram Cloud
  local request = bindings.request('getFile', {
		file_id = file_id
  } )

  local download_url = 'https://api.telegram.org/file/bot'..config.bot_api_key..'/'..request.result.file_path
  local ogg_file_name = file_id..'.oga'
  local ogg_file = download_to_file(download_url, ogg_file_name)
  
  -- Convert to MP3
  run_command('ffmpeg -loglevel panic -i /tmp/'..ogg_file_name..' -ac 1 -y /tmp/'..file_id..'.mp3')
  os.remove('/tmp/'..ogg_file_name)

  local mp3_file = '/tmp/'..file_id..'.mp3'

  -- Voice-To-Text via wit.ai
  local headers = {
	["Content-Type"] = "audio/mpeg3",
	Authorization = "Bearer "..apikey
  }
  local data = post_petition('https://api.wit.ai/speech?v=20160526', io.open(mp3_file, 'r'), headers)
  os.remove(mp3_file)

  if not data then
	return msg
  end
  
  if not data._text then
    utilities.send_reply(msg, 'Keine Stimme zu hören!')
	return
  end

  utilities.send_reply(msg, data._text)
    
  return msg
end

function vtt:action(msg)
end

return vtt