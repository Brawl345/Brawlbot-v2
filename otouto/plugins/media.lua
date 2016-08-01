local media = {}

mimetype = (loadfile "./otouto/mimetype.lua")()

media.triggers = {
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(gif))$",
    	"^(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(mp4))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(pdf))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(ogg))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(zip))$",
        "(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(tar.gz))$",
        "(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(7z))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(mp3))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(rar))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(wmv))$",
    	"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(doc))$",
    	"^(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(avi))$",
		"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(wav))$",
		"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(apk))$",
		"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(webm))$",
		"^(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(ogv))$",
		"(https?://[%w-_%.%?%.:,/%+=&%[%]]+%.(webp))$"
}

function media:action(msg)
  local url = matches[1]
  local ext = matches[2]
  local mime_type = mimetype.get_content_type_no_sub(ext)
  local receiver = msg.chat.id
  
  if mime_type == 'audio' then
    chat_action = 'upload_audio'
  elseif mime_type == 'video' then
    chat_action = 'upload_video'
  else
    chat_action = 'upload_document'
  end

  local file, last_modified, nocache = get_cached_file(url, nil, msg.chat.id, chat_action, self)
  if not file then return end

  if ext == 'gif' then
    print('send gif')
    result = utilities.send_document(self, receiver, file, nil, msg.message_id)
  elseif mime_type == 'audio' then
    print('send_audio')
    result = utilities.send_audio(self, receiver, file, nil, msg.message_id)
  elseif mime_type == 'video' then
    print('send_video')
	result = utilities.send_video(self, receiver, file, nil, msg.message_id)
  else
    print('send_file')
    result = utilities.send_document(self, receiver, file, nil, msg.message_id)
  end
  
  if nocache then return end
  if not result then return end

  -- Cache File-ID und Last-Modified-Header in Redis
  cache_file(result, url, last_modified)
end

return media
