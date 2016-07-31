local ip_info = {}

function ip_info:init(config)
  ip_info.triggers = {
	"^/ip (.*)$",
	"^/dns (.*)$"
  }
  
	ip_info.doc = [[*
]]..config.cmd_pat..[[ip* _<IP-Adresse>_: Sendet Infos zu dieser IP]]
end

ip_info.command = 'ip <IP-Adresse>'

local BASE_URL = 'http://ip-api.com/json'

function ip_info:get_host_data(host)
  local url = BASE_URL..'/'..host..'?lang=de&fields=country,regionName,city,zip,lat,lon,isp,org,as,status,message,reverse,query'
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-FEHLER: "..code end
  local data = json.decode(res)
  if data.status == 'fail' then
    return nil
  end

  local isp = data.isp
  
  local url
  if data.lat and data.lon then
    lat = tostring(data.lat)
    lon = tostring(data.lon)
	url = "https://maps.googleapis.com/maps/api/staticmap?zoom=16&size=600x300&maptype=hybrid&center="..lat..","..lon.."&markers=color:red%7Clabel:•%7C"..lat..","..lon
  end
  
  if data.query == host then
    query = ''
  else
    query = ' / '..data.query
  end
  
  if data.reverse ~= "" and data.reverse ~= host then
    host_addr = ' ('..data.reverse..')'
  else
    host_addr = ''
  end
  
  -- Location
  if data.zip ~= "" then
    zipcode = data.zip..' '
  else
    zipcode = ''
  end
  
  local city = data.city

  if data.regionName ~= "" then
    region = ', '..data.regionName
  else
    region = ''
  end
  
  if data.country ~= "" then
    country = ', '..data.country
  else
    country = ''
  end
  
  local text = host..query..host_addr..' ist bei '..isp..':\n'
  local location = zipcode..city..region..country
  return text..location, url
end

function ip_info:action(msg, config, matches)
  local host = matches[1]
  local text, image_url = ip_info:get_host_data(host)
  if not text then utilities.send_reply(self, msg, config.errors.connection) return end
  
  if image_url then
    utilities.send_typing(self, msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url, 'map.png')
    utilities.send_photo(self, msg.chat.id, file, text, msg.message_id)
  else
    utilities.send_reply(self, msg, text)
  end
end

return ip_info
