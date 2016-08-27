local vtt = {}

vtt.triggers = {
  '/nil'
}

local apikey = cred_data.witai_apikey
local headers = {
  ["Content-Type"] = "audio/mpeg3",
  Authorization = "Bearer "..apikey
}

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
  local ogg_file_name = file_id..'.ogg'
  local ogg_file = download_to_file(download_url, ogg_file_name)
  
  -- Convert to MP3
  run_command('ffmpeg -loglevel panic -i /tmp/'..ogg_file_name..' -ac 1 -y /tmp/'..file_id..'.mp3')
  os.remove('/tmp/'..ogg_file_name)
  
  -- Voice-To-Text via wit.ai
  local req_url = 'https://api.wit.ai/speech'
  local response_body = {}
  local ok, response_code = https.request{
    url = req_url,	
    method = "POST",
    headers = headers,
    source = ltn12.source.file(io.open("/tmp/"..file_id..".mp3")),
    sink = ltn12.sink.table(response_body)
  }
  os.remove("/tmp/"..file_id..".mp3")

  if response_code ~= 200 then
	return msg
  end
  vardump(response_body)
  local out = json.decode(table.concat(response_body))
  vardump(out)
  utilities.send_reply(msg, out._text)
    
  return msg
end

function vtt:action(msg)
end

return vtt