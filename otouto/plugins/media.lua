local media = {}

local HTTP = require('socket.http')
local HTTPS = require('ssl.https')
local redis = (loadfile "./otouto/redis.lua")()
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
  local hash = 'telegram:cache:sent_file'
  local cached_file_id = redis:hget(hash..':'..url, 'file_id')
  local cached_last_modified = redis:hget(hash..':'..url, 'last_modified')
  local receiver = msg.chat.id
  
  -- Last-Modified-Header auslesen
  local doer = HTTP
  local do_redir = true
  if url:match('^https') then
	doer = HTTPS
	do_redir = false
  end
  local _, c, h = doer.request {
	method = "HEAD",
	url = url,
	redirect = do_redir
  }
  
  if c ~= 200 then
    if cached_file_id then
      redis:del(hash..':'..url)
	end
    return
  end

  utilities.send_typing(self, receiver, 'upload_document')
  if not h["last-modified"] and not h["Last-Modified"] then
	nocache = true
	last_modified = nil
  else
    nocache = false
	last_modified = h["last-modified"]
	if not last_modified then
	  last_modified = h["Last-Modified"]
	end
  end

  local mime_type = mimetype.get_content_type_no_sub(ext)
  
  if not nocache then
    if last_modified == cached_last_modified then
      print('File not modified and already cached')
      nocache = true
	  file = cached_file_id
    else
	  print('File cached, but modified or not already cached. (Re)downloading...')
      file = download_to_file(url)
    end
  else
    print('No Last-Modified header!')
    file = download_to_file(url)
  end

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
  if result.result.video then
    file_id = result.result.video.file_id
  elseif result.result.audio then
    file_id = result.result.audio.file_id
  elseif result.result.voice then
    file_id = result.result.voice.file_id
  else
    file_id = result.result.document.file_id
  end
  redis:hset(hash..':'..url, 'file_id', file_id)
  redis:hset(hash..':'..url, 'last_modified', last_modified)
  -- Why do we set a TTL? Because Telegram recycles outgoing file_id's
  -- See: https://core.telegram.org/bots/faq#can-i-count-on-file-ids-to-be-persistent
  redis:expire(hash..':'..url, 5259600) -- 2 months
end

return media
