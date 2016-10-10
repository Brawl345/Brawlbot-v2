local speedtest = {}

speedtest.triggers = {
  "speedtest.net/my%-result/(%d+)",
  "speedtest.net/my%-result/i/(%d+)",
  "speedtest.net/my%-result/a/(%d+)"
}

function speedtest:action(msg, config, matches)
  local url = 'http://www.speedtest.net/result/'..matches[1]..'.png'
  utilities.send_typing(msg.chat.id, 'upload_photo')
  utilities.send_photo(msg.chat.id, url, nil, msg.message_id)
end

return speedtest