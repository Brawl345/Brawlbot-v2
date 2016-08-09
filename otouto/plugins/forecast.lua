local forecast = {}

require("./otouto/plugins/weather")

function forecast:init(config)
	if not cred_data.forecastio_apikey then
		print('Missing config value: forecastio_apikey.')
		print('weather.lua will not be enabled.')
		return
	elseif not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('weather.lua will not be enabled.')
		return
	end

   forecast.triggers = {
    "^(/f)$",
	"^(/f) (.*)$",
	"^(/fh)$",
	"^(/fh) (.*)$",
	"^(/forecast)$",
	"^(/forecast) (.*)$",
	"^(/forecasth)$",
	"^(/forecasth) (.*)$"
	}
	forecast.inline_triggers = {
	  "^(f) (.+)$",
	  "^(fh) (.+)$",
	  "^(fh)$",
	  "^(f)$"
	}
	forecast.doc = [[*
]]..config.cmd_pat..[[f*:  Wettervorhersage für deinen Wohnort _(/location set <Ort>)_
*]]..config.cmd_pat..[[f* _<Ort>_: Wettervorhersage für diesen Ort
*]]..config.cmd_pat..[[fh*: 24-Stunden-Wettervorhersage für deine Stadt _(/location set [Ort]_
*]]..config.cmd_pat..[[fh* _<Ort>_: 24-Stunden-Wettervorhersage für diesen Ort
]]
end

forecast.command = 'f [Ort]'

local BASE_URL = "https://api.forecast.io/forecast"
local apikey = cred_data.forecastio_apikey
local google_apikey = cred_data.google_apikey

function forecast:get_condition_symbol(weather_data)
  if weather_data.icon == 'clear-day' then
	return '☀️'
  elseif weather_data.icon == 'clear-night' then
    return '🌙'
  elseif weather_data.icon == 'rain' then
    return '☔️'
  elseif weather_data.icon == 'snow' then
	return '❄️'
  elseif weather_data.icon == 'sleet' then
    return '🌨'
  elseif weather_data.icon == 'wind' then
    return '💨'
  elseif weather_data.icon == 'fog' then
    return '🌫'
  elseif weather_data.icon == 'cloudy' then
    return '☁️☁️'
  elseif weather_data.icon == 'partly-cloudy-day' then
    return '🌤'
  elseif weather_data.icon == 'partly-cloudy-night' then
    return '🌙☁️'
  else
    return ''
  end
end

function get_temp(weather, n, hourly)
  local weather_data = weather.data[n]
  if hourly then
    local temperature = string.gsub(round(weather_data.temperature, 1), "%.", ",")
	local condition = weather_data.summary
	return temperature..'°C | '..forecast:get_condition_symbol(weather_data)..' '..condition
  else
    local day = string.gsub(round(weather_data.temperatureMax, 1), "%.", ",")
    local night = string.gsub(round(weather_data.temperatureMin, 1), "%.", ",")
    local condition = weather_data.summary
    return '☀️ '..day..'°C | 🌙 '..night..'°C | '..forecast:get_condition_symbol(weather_data)..' '..condition
  end
end

function forecast:get_forecast(lat, lng, is_inline)
  print('Finde Wetter in '..lat..', '..lng)
  local hash = 'telegram:cache:forecast:'..lat..','..lng
  local text = redis:hget(hash, 'text')
  if text then
    print('...aus dem Cache..')
	if is_inline then
	  local ttl = redis:ttl(hash)
	  local city = redis:hget(hash, 'city')
	  local summary = redis:hget(hash, 'summary')
	  return city, summary, text, ttl
	else
	  return text
	end
  end

  local url = BASE_URL..'/'..apikey..'/'..lat..','..lng..'?lang=de&units=si&exclude=currently,minutely,hourly,alerts,flags'
  
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body)
   }
  local ok, response_code, response_headers = https.request(request_constructor)
  if not ok then return nil end
  local weather = json.decode(table.concat(response_body)).daily
  local ttl = tonumber(string.sub(response_headers["cache-control"], 9))
  local city = get_city_name(lat, lng)
  local weather_summary = weather.summary
  
  local header = '*Vorhersage für '..city..':*\n_'..weather_summary..'_\n'
  
  local text = '*Heute:* '..get_temp(weather, 1)
  local text = text..'\n*Morgen:* '..get_temp(weather, 2)
  
  local weather_data = weather.data
  for day in pairs(weather_data) do
	if day > 2 then 
	  text = text..'\n*'..convert_timestamp(weather_data[day].time, '%a, %d.%m')..'*: '..get_temp(weather, day)
    end
  end
  
  local text = text:gsub("Mon", "Mo")
  local text = text:gsub("Tue", "Di")
  local text = text:gsub("Wed", "Mi")
  local text = text:gsub("Thu", "Do")
  local text = text:gsub("Fri", "Fr")
  local text = text:gsub("Sat", "Sa")
  local text = text:gsub("Sun", "So")
  
  print('Caching data...')
  redis:hset(hash, 'city', city)
  redis:hset(hash, 'summary', weather_summary)
  redis:hset(hash, 'text', header..text)
  redis:expire(hash, ttl)
  
  if is_inline then
    return city, weather_summary, header..text, ttl
  else
    return header..text
  end
end

function forecast:get_forecast_hourly(lat, lng, is_inline)
  print('Finde stündliches Wetter in '..lat..', '..lng)
  local hash = 'telegram:cache:forecast:'..lat..','..lng..':hourly'
  local text = redis:hget(hash, 'text')
  if text then
    print('...aus dem Cache..')
	if is_inline then
	  local ttl = redis:ttl(hash)
	  local city = redis:hget(hash, 'city')
	  local summary = redis:hget(hash, 'summary')
	  return city, summary, text, ttl
	else
	  return text
	end
  end

  local url = BASE_URL..'/'..apikey..'/'..lat..','..lng..'?lang=de&units=si&exclude=currently,minutely,daily,alerts,flags'
  
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body)
   }
  local ok, response_code, response_headers = https.request(request_constructor)
  if not ok then return nil end
  local weather = json.decode(table.concat(response_body)).hourly
  local ttl = tonumber(string.sub(response_headers["cache-control"], 9))
  local city = get_city_name(lat, lng)
  local weather_summary = weather.summary
  
  local header = '*24-Stunden-Vorhersage für '..city..':*\n_'..weather_summary..'_'
  local text = ""
  
  local weather_data = weather.data
  for hour in pairs(weather_data) do
	if hour < 26 then 
	  text = text..'\n*'..convert_timestamp(weather_data[hour].time, '%H:%M Uhr')..'* | '..get_temp(weather, hour, true)
	end
  end
  
  print('Caching data...')
  redis:hset(hash, 'city', city)
  redis:hset(hash, 'summary', weather_summary)
  redis:hset(hash, 'text', header..text)
  redis:expire(hash, ttl)
  
  if is_inline then
    return city, weather_summary, header..text, ttl
  else
    return header..text
  end
end

function forecast:inline_callback(inline_query, config, matches)
  local user_id = inline_query.from.id
  if matches[2] then
    city = matches[2]
	is_personal = false
  else
    local set_location = get_location(user_id)
	is_personal = true
	if not set_location then
	  city = 'Berlin, Deutschland'
	else
	  city = set_location
	end
  end
  
  local lat, lng = get_city_coordinates(city, config)
  if not lat and not lng then utilities.answer_inline_query(self, inline_query) return end
  if matches[1] == 'f' then
    title, description, text, ttl = forecast:get_forecast(lat, lng, true)
  else
    title, description, text, ttl = forecast:get_forecast_hourly(lat, lng, true)
  end
  if not title and not description and not text and not ttl then utilities.answer_inline_query(self, inline_query) return end

  local text = text:gsub('\n', '\\n')
  local results = '[{"type":"article","id":"28062013","title":"'..title..'","description":"'..description..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/weather/cloudy.jpg","thumb_width":80,"thumb_height":80,"input_message_content":{"message_text":"'..text..'", "parse_mode":"Markdown"}}]'
  utilities.answer_inline_query(self, inline_query, results, ttl, is_personal)
end

function forecast:action(msg, config, matches)
  local user_id = msg.from.id
  
  if matches[2] then
    city = matches[2]
  else
    local set_location = get_location(user_id)
	if not set_location then
	  city = 'Berlin, Deutschland'
	else
	  city = set_location
	end
  end
  
  local lat, lng = get_city_coordinates(city, config)
  if not lat and not lng then
	utilities.send_reply(self, msg, '*Diesen Ort gibt es nicht!*', true)
    return
  end
  
  if matches[1] == '/forecasth' or matches[1] == '/fh' then
    text = forecast:get_forecast_hourly(lat, lng)
  else
    text = forecast:get_forecast(lat, lng)
  end
  if not text then
    text = '*Konnte die Wettervorhersage für diese Stadt nicht bekommen.*'
  end
  utilities.send_reply(self, msg, text, true)
end

return forecast
