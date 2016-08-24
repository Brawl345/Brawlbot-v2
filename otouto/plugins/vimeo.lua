local vimeo = {}

vimeo.triggers = {
  "vimeo.com/(%d+)"
}

local BASE_URL = 'https://vimeo.com/api/v2'

function vimeo:send_vimeo_data (vimeo_code)
  local url = BASE_URL..'/video/'..vimeo_code..'.json'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP FEHLER" end
  local data = json.decode(res)
  
  local title = '*'..data[1].title..'*'
  local uploader = data[1].user_name
  local totalseconds = data[1].duration
  local duration = makeHumanTime(totalseconds)
  
  if not data[1].stats_number_of_plays then
    return title..'\n_(Hochgeladen von: '..uploader..', '..duration..')_'
  else
    local viewCount = ', '..comma_value(data[1].stats_number_of_plays)..' mal angsehen)' or ""
	return title..'\n_(Hochgeladen von: '..uploader..', '..duration..viewCount..'_'
  end
end

function vimeo:action(msg, config, matches)
  local text = vimeo:send_vimeo_data(matches[1])
  if not text then utilities.send_reply(msg, config.errors.connection) return end
  utilities.send_reply(msg, text, true)
end

return vimeo
