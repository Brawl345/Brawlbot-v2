local media = {}

local utilities = require('otouto.utilities')
local mimetype = (loadfile "./otouto/mimetype.lua")()

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
  local receiver = msg.chat.id

  local file = download_to_file(url)
  local mime_type = mimetype.get_content_type_no_sub(ext)

  if ext == 'gif' then
    print('send gif')
    utilities.send_document(self, receiver, file, nil, msg.message_id)
	return

  elseif mime_type == 'text' then
    print('send_document')
    utilities.send_document(self, receiver, file, nil, msg.message_id)
	return
  
  elseif mime_type == 'image' then
    print('send_photo')
    utilities.send_photo(self, receiver, file, nil, msg.message_id)
	return
  
  elseif mime_type == 'audio' then
    print('send_audio')
    utilities.send_audio(self, receiver, file, nil, msg.message_id)
	return

  elseif mime_type == 'video' then
    print('send_video')
	utilities.send_video(self, receiver, file, nil, msg.message_id)
	return
  
  else
    print('send_file')
    utilities.send_document(self, receiver, file, nil, msg.message_id)
	return
  end
end

return media
