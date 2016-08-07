-- This plugin goes through every message with a document and if the document is an image,
-- it downloads the file and resends it as image

local post_photo = {}

post_photo.triggers = {
  '/nil'
}

function post_photo:pre_process(msg, self, config)
  if not msg.document then return msg end -- Ignore
  local mime_type = msg.document.mime_type
  local valid_mimetypes = {['image/jpeg'] = true, ['image/png'] = true, ['image/bmp'] = true}
  if not valid_mimetypes[mime_type] then return msg end

  local file_id = msg.document.file_id
  local file_size = msg.document.file_size
  if file_size > 19922944 then
	print('File is over 20 MB - can\'t download :(')
	return
  end
  
  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  -- Saving file to the Telegram Cloud
  local request = bindings.request(self, 'getFile', {
		file_id = file_id
  } )

  local download_url = 'https://api.telegram.org/file/bot'..config.bot_api_key..'/'..request.result.file_path
  local file = download_to_file(download_url, msg.file_name)
  utilities.send_photo(self, msg.chat.id, file, msg.caption, msg.message_id)
  
  return msg
end

function post_photo:action(msg)
end

return post_photo
