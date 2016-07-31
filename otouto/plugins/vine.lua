local vine = {}

vine.triggers = {
  "vine.co/v/([A-Za-z0-9-_-]+)"
}

local BASE_URL = 'https://vine.co'

function vine:get_vine_data(vine_code)
  local res, code = https.request(BASE_URL..'/v/'..vine_code..'/embed/simple')
  if code ~= 200 then return nil end
  local json_data = string.match(res, '<script type%="application/json" id%="configuration">(.-)</script>')
  local data = json.decode(json_data).post
  return data
end

function vine:send_vine_data(data)
  local title = data.description
  local author_name = data.user.username
  local creation_date = data.createdPretty
  local loops = data.loops.count
  local video_url = data.videoUrls[1].videoUrl
  local profile_name = string.gsub(data.user.profileUrl, '/', '')
  local text = '"'..title..'", hochgeladen von '..author_name..' ('..profile_name..'), '..creation_date..', '..loops..'x angesehen'
  if data.explicitContent == 1 then
    text = text..' (ðŸ”ž NSFW ðŸ”ž)'
  end
  local file = download_to_file(video_url, data.shortId..'.mp4')
  return text, file
end

function vine:action(msg, config, matches)
  local data = vine:get_vine_data(matches[1])
  if not data then utilities.send_reply(self, msg, config.errors.connection) return end
  
  utilities.send_typing(self, msg.chat.id, 'upload_video')
  local text, file = vine:send_vine_data(data)
  utilities.send_video(self, msg.chat.id, file, text, msg.message_id)
end

return vine
