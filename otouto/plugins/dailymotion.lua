local dailymotion = {}

dailymotion.triggers = {
  "dailymotion.com/video/([A-Za-z0-9-_-]+)"
}

local BASE_URL = 'https://api.dailymotion.com'

function dailymotion:send_dailymotion_info (dm_code)
  local url = BASE_URL..'/video/'..dm_code
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  
  local title = data.title
  local channel = data.channel
  local text = '*'..title..'*\nHochgeladen in die Kategorie *'..channel..'*'
  return text
end

function dailymotion:action(msg, config, matches)
  local text = dailymotion:send_dailymotion_info(matches[1])
  if not text then utilities.send_reply(self, msg, config.errors.connection) return end
  utilities.send_reply(self, msg, text, true)
end

return dailymotion
