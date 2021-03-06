-- Doesn't use the API for now, maybe we can integrate some cool features?

local dropbox = {}

dropbox.triggers = {
  "dropbox.com/s/([a-z0-9]+)/(.*)"
}

function dropbox:action(msg, config, matches)
  local folder = matches[1]
  local file = string.gsub(matches[2], "?dl=0", "")
  local link = 'https://dl.dropboxusercontent.com/s/'..folder..'/'..file
  
  local v,code  = https.request(link)
  if code == 200 then
	if string.ends(link, ".png") or string.ends(link, ".jpe?g")then
	  utilities.send_typing(msg.chat.id, 'upload_photo')
	  local file = download_to_file(link)
      utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
	  return
    elseif string.ends(link, ".webp") or string.ends(link, ".gif") then
	  utilities.send_typing(msg.chat.id, 'upload_photo')
	  local file = download_to_file(link)
      utilities.send_document(msg.chat.id, file, nil, msg.message_id)
	  return
    else
      utilities.send_reply(msg, link)
    end
    return
  else
    return
  end
end

return dropbox
