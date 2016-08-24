local gdrive = {}

function gdrive:init(config)
	if not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('gdrive.lua will not be enabled.')
		return
	end
	
	gdrive.triggers = {
      "docs.google.com/(.*)/d/([A-Za-z0-9-_-]+)",
	  "drive.google.com/(.*)/d/([A-Za-z0-9-_-]+)",
      "drive.google.com/(open)%?id=([A-Za-z0-9-_-]+)"
	}
end

local apikey = cred_data.google_apikey

local BASE_URL = 'https://www.googleapis.com/drive/v3'
local apikey = cred_data.google_apikey

function gdrive:get_drive_document_data (docid)
  local url = BASE_URL..'/files/'..docid..'?key='..apikey..'&fields=id,name,mimeType,owners,fullFileExtension'
  local res, code  = https.request(url)
  local res = string.gsub(res, 'image/', '') -- snip mimetype
  local res = string.gsub(res, 'application/', '')
  if code ~= 200 then return nil end
  local data = json.decode(res)
  return data
end

function gdrive:send_drive_document_data(data, self, msg)
  local title = data.name
  local mimetype = data.mimeType
  local id = data.id
  local owner = data.owners[1].displayName
  local text = '"'..title..'", freigegeben von '..owner
  if mimetype:match('google') then -- if document is Google document (like a Spreadsheet)
    if mimetype:match('drawing') then -- Drawing
	  local image_url = BASE_URL..'/files/'..id..'/export?key='..apikey..'&mimeType=image/png'
	  utilities.send_typing(msg.chat.id, 'upload_photo')
	  local file = download_to_file(image_url, 'export.png')
	  utilities.send_photo(msg.chat.id, file, text, msg.message_id)
	  return
	else
	  local pdf_url = BASE_URL..'/files/'..id..'/export?key='..apikey..'&mimeType=application/pdf'
	  utilities.send_typing(msg.chat.id, 'upload_document')
	  local file = download_to_file(pdf_url, 'document.pdf')
	  utilities.send_document(msg.chat.id, file, text, msg.message_id)
	  return
	end
  else
	local get_file_url = 'https://drive.google.com/uc?id='..id
	local keyboard = '{"inline_keyboard":[[{"text":"Direktlink","url":"'..get_file_url..'"}]]}'
	local ext = data.fullFileExtension
    if mimetype == "png" or mimetype == "jpg" or mimetype == "jpeg" or mimetype == "gif" or mimetype == "webp" then
	  local respbody = {}
      local options = {
        url = get_file_url,
        sink = ltn12.sink.table(respbody),
        redirect = false
      }
      local response = {https.request(options)} -- luasec doesn't support 302 redirects, so we must contact gdrive again
      local code = response[2]
      local headers = response[3]
	  local file_url = headers.location
	  if ext == "jpg"  or ext == "jpeg" or ext == "png" then
	    utilities.send_typing(msg.chat.id, 'upload_photo')
        local file = download_to_file(file_url, 'photo.'..ext)
        utilities.send_photo(msg.chat.id, file, text, msg.message_id, keyboard)
		return
	  else
	    utilities.send_typing(msg.chat.id, 'upload_document')
	    local file = download_to_file(file_url, 'document.'..ext)
        utilities.send_document(msg.chat.id, file, text, msg.message_id, keyboard)
		return
	  end
	else
	  local text = '*'..title..'*, freigegeben von _'..owner..'_'
	  utilities.send_reply(msg, text, true, keyboard)
	  return
	end
  end
end

function gdrive:action(msg, config, matches)
  local docid = matches[2]
  local data = gdrive:get_drive_document_data(docid)
  if not data then utilities.send_reply(msg, config.errors.connection) return end
  gdrive:send_drive_document_data(data, self, msg)
  return
end

return gdrive