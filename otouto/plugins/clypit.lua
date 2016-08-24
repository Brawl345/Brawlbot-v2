local clypit = {}

clypit.triggers = {
  "clyp.it/([A-Za-z0-9-_-]+)"
}

function clypit:get_clypit_details(shortcode)
  local BASE_URL = "http://api.clyp.it"
  local url = BASE_URL..'/'..shortcode
  local res,code  = http.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)

  local title = data.Title
  local duration = data.Duration

  local audio = download_to_file(data.Mp3Url)
  return audio, title, duration
end

function clypit:action(msg, config, matches)
  utilities.send_typing(msg.chat.id, 'upload_audio')
  local audio, title, duration = clypit:get_clypit_details(matches[1])
  if not audio then return utilities.send_reply(msg, config.errors.connection) end
  utilities.send_audio(msg.chat.id, audio, nil, msg.message_id, duration, nil, title)
end

return clypit
