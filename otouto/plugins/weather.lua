local weather = {}

function weather:init(config)
	if not cred_data.forecastio_apikey then
		print('Missing config value: forecastio_apikey.')
		print('weather.lua will not be enabled.')
		return
	elseif not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('weather.lua will not be enabled.')
		return
	end

   weather.triggers = {
      "^/wetter$",
	  "^/wetter (.*)$",
	  "^/w$",
	  "^/w (.*)$"
	}
	weather.inline_triggers = {
	  "^w (.+)$",
	  "^w$"
	}
	weather.doc = [[*
]]..config.cmd_pat..[[wetter*:  Wetter für deinen Wohnort _(/location set [Ort])_
*]]..config.cmd_pat..[[wetter* _<Ort>_: Wetter für diesen Ort
]]
end

weather.command = 'w [Ort]'

local BASE_URL = "https://api.forecast.io/forecast"
local apikey = cred_data.forecastio_apikey
local google_apikey = cred_data.google_apikey

function get_city_name(lat, lng)
  local city = redis:hget('telegram:cache:weather:pretty_names', lat..','..lng)
  if city then return city end
  local url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng='..lat..','..lng..'&result_type=political&language=de&key='..google_apikey
  local res, code = https.request(url)
  if code ~= 200 then return 'Unbekannte Stadt' end
  local data = json.decode(res).results[1]
  local city = data.formatted_address
  print('Setting '..lat..','..lng..' in redis hash telegram:cache:weather:pretty_names to "'..city..'"')
  redis:hset('telegram:cache:weather:pretty_names', lat..','..lng, city)
  return city
end

function weather:get_city_coordinates(city, config)
  local lat = redis:hget('telegram:cache:weather:'..string.lower(city), 'lat')
  local lng = redis:hget('telegram:cache:weather:'..string.lower(city), 'lng')
  if not lat and not lng then
    print('Koordinaten nicht eingespeichert, frage Google...')
    coords = utilities.get_coords(city, config)
	lat = coords.lat
	lng = coords.lon
  end
  
  if not lat and not lng then
    return nil
  end

  redis:hset('telegram:cache:weather:'..string.lower(city), 'lat', lat)
  redis:hset('telegram:cache:weather:'..string.lower(city), 'lng', lng)
  return lat, lng
end

function weather:get_weather(lat, lng, is_inline)
  print('Finde Wetter in '..lat..', '..lng)
  local hash = 'telegram:cache:weather:'..lat..','..lng

  local text = redis:hget(hash, 'text')
  if text then
    print('...aus dem Cache')
	if is_inline then
	  local ttl = redis:ttl(hash)
	  local city = redis:hget(hash, 'city')
	  local temperature = redis:hget(hash, 'temperature')
	  local weather_icon = redis:hget(hash, 'weather_icon')
	  local condition = redis:hget(hash, 'condition')
	  return city, condition..' bei '..temperature..' °C', weather_icon, text, ttl
	else
	  return text
	end
  end

  local url = BASE_URL..'/'..apikey..'/'..lat..','..lng..'?lang=de&units=si&exclude=minutely,hourly,daily,alerts,flags'
  
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body)
   }
  local ok, response_code, response_headers, response_status_line = https.request(request_constructor)
  if not ok then return nil end
  local data = json.decode(table.concat(response_body))
  local ttl = tonumber(string.sub(response_headers["cache-control"], 9))

  
  local weather = data.currently
  local city = get_city_name(lat, lng)
  local temperature = string.gsub(round(weather.temperature, 1), "%.", ",")
  local feelslike = string.gsub(round(weather.apparentTemperature, 1), "%.", ",")
  local temp = '*Wetter in '..city..':*\n'..temperature..' °C'
  local weather_summary = weather.summary
  local conditions = ' | '..weather_summary
  local weather_icon = weather.icon
  if weather_icon == 'clear-day' then
	conditions = conditions..' ☀️'
  elseif weather_icon == 'clear-night' then
	conditions = conditions..' 🌙'
  elseif weather_icon == 'rain' then
    conditions = conditions..' ☔️'
  elseif weather_icon == 'snow' then
	 conditions = conditions..' ❄️'
  elseif weather_icon == 'sleet' then
     conditions = conditions..' 🌨'
  elseif weather_icon == 'wind' then
     conditions = conditions..' 💨'
  elseif weather.icon == 'fog' then
     conditions = conditions..' 🌫'
  elseif weather_icon == 'cloudy' then
     conditions = conditions..' ☁️☁️'
  elseif weather_icon == 'partly-cloudy-day' then
     conditions = conditions..' 🌤'
  elseif weather_icon == 'partly-cloudy-night' then
     conditions = conditions..' 🌙☁️'
  else
     conditions = conditions..''
  end
  local windspeed = ' | 💨 '..string.gsub(round(weather.windSpeed, 1), "%.", ",")..' m/s'
  
  local text = temp..conditions..windspeed
  
  if temperature ~= feelslike then
    text = text..'\n(gefühlt: '..feelslike..' °C)'
  end
  
  print('Caching data...')
  redis:hset(hash, 'city', city)
  redis:hset(hash, 'temperature', temperature)
  redis:hset(hash, 'weather_icon', weather_icon)
  redis:hset(hash, 'condition', weather_summary)
  redis:hset(hash, 'text', text)
  redis:expire(hash, ttl)
  
  if is_inline then
    return city, weather_summary..' bei '..temperature..' °C', weather_icon, text, ttl
  else
    return text
  end
end

function weather:inline_callback(inline_query, config, matches)
  local user_id = inline_query.from.id
  if matches[1] ~= 'w' then
    city = matches[1]
	is_personal = false
  else
    local set_location = get_location(user_id)
	if not set_location then
	  city = 'Berlin, Deutschland'
	  is_personal = false
	else
	  city = set_location
	  is_personal = true
	end
  end
  local lat, lng = weather:get_city_coordinates(city, config)
  if not lat and not lng then utilities.answer_inline_query(self, inline_query) return end
  
  local title, description, icon, text, ttl = weather:get_weather(lat, lng, true)
  if not title and not description and not icon and not text and not ttl then utilities.answer_inline_query(self, inline_query) return end
  
  local text = text:gsub('\n', '\\n')
  local thumb_url = 'https://anditest.perseus.uberspace.de/inlineQuerys/weather/'
  if icon == 'clear-day' or icon == 'partly-cloudy-day' then
	thumb_url = thumb_url..'day.jpg'
  elseif icon == 'clear-night' or icon == 'partly-cloudy-night' then
	thumb_url = thumb_url..'night.jpg'
  elseif icon == 'rain' then
    thumb_url = thumb_url..'rain.jpg'
  elseif icon == 'snow' then
    thumb_url = thumb_url..'snow.jpg'
  else
    thumb_url = thumb_url..'cloudy.jpg'
  end
  local results = '[{"type":"article","id":"19122006","title":"'..title..'","description":"'..description..'","thumb_url":"'..thumb_url..'","thumb_width":80,"thumb_height":80,"input_message_content":{"message_text":"'..text..'", "parse_mode":"Markdown"}}]'
  utilities.answer_inline_query(self, inline_query, results, ttl, is_personal)
end

function weather:action(msg, config, matches)
  local user_id = msg.from.id

  if matches[1] ~= '/wetter' and matches[1] ~= '/w' then 
    city = matches[1]
  else
    local set_location = get_location(user_id)
	if not set_location then
	  city = 'Berlin, Deutschland'
	else
	  city = set_location
	end
  end
  
  local lat, lng = weather:get_city_coordinates(city, config)
  if not lat and not lng then
	utilities.send_reply(self, msg, '*Diesen Ort gibt es nicht!*', true)
    return
  end
  
  local text = weather:get_weather(lat, lng)
  if not text then
    text = 'Konnte das Wetter von dieser Stadt nicht bekommen.'
  end
  utilities.send_reply(self, msg, text, true)
end

return weather
