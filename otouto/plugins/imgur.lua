local imgur = {}

function imgur:init(config)
	if not cred_data.imgur_client_id then
		print('Missing config value: imgur_client_id.')
		print('imgur.lua will not be enabled.')
		return
	end

    imgur.triggers = {
     "imgur.com/([A-Za-z0-9]+).gifv",
      "https?://imgur.com/([A-Za-z0-9]+)"
	}
end

local client_id = cred_data.imgur_client_id
local BASE_URL = 'https://api.imgur.com/3'

function imgur:get_imgur_data(imgur_code)
  local response_body = {}
  local request_constructor = {
      url = BASE_URL..'/image/'..imgur_code,
      method = "GET",
      sink = ltn12.sink.table(response_body),
      headers = {
	    Authorization = 'Client-ID '..client_id
	  }
  }
  local ok, response_code, response_headers, response_status_line = https.request(request_constructor)
  if not ok then
    return nil
  end

  local response_body = json.decode(table.concat(response_body))
  
  if response_body.status ~= 200 then return nil end
    
  return response_body.data.link
end

function imgur:action(msg)
  local imgur_code = matches[1]
  if imgur_code == "login" then return nil end
  utilities.send_typing(msg.chat.id, 'upload_photo')
  local link = imgur:get_imgur_data(imgur_code)
  if link then
    local file = download_to_file(link)
    if string.ends(link, ".gif") then
      utilities.send_document(msg.chat.id, file, nil, msg.message_id)
    else
      utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
    end
  end
end

return imgur
