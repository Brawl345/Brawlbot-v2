local time = {}

time.command = 'time <Ort>'

function time:init(config)
	time.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('time', true).table
	time.doc = [[*
]]..config.cmd_pat..[[time*: Aktuelle Zeit in Deutschland
*]]..config.cmd_pat..[[time* _<Ort>_: Gibt Zeit an diesem Ort aus]]
end

function time:localize(output)
  -- Days
  local output = string.gsub(output, "Monday", "Montag")
  local output = string.gsub(output, "Tuesday", "Dienstag")
  local output = string.gsub(output, "Wednesday", "Mittwoch")
  local output = string.gsub(output, "Thursday", "Donnerstag")
  local output = string.gsub(output, "Friday", "Freitag")
  local output = string.gsub(output, "Saturday", "Samstag")
  local output = string.gsub(output, "Sunday", "Sonntag")
	
	-- Months
  local output = string.gsub(output, "January", "Januar")
  local output = string.gsub(output, "February", "Februar")
  local output = string.gsub(output, "March", "März")
  local output = string.gsub(output, "April", "April")
  local output = string.gsub(output, "May", "Mai")
  local output = string.gsub(output, "June", "Juni")
  local output = string.gsub(output, "July", "Juli")
  local output = string.gsub(output, "August", "August")
  local output = string.gsub(output, "September", "September")
  local output = string.gsub(output, "October", "Oktober")
  local output = string.gsub(output, "November", "November")
  local output = string.gsub(output, "December", "Dezember")
	
	-- Timezones
  local output = string.gsub(output, "Africa", "Afrika")
  local output = string.gsub(output, "America", "Amerika")
  local output = string.gsub(output, "Asia", "Asien")
  local output = string.gsub(output, "Australia", "Australien")
  local output = string.gsub(output, "Europe", "Europa")
  local output = string.gsub(output, "Indian", "Indien")
  local output = string.gsub(output, "Pacific", "Pazifik")
  
  return output
end

function time:action(msg, config)
  local input = utilities.input(msg.text)
  if not input then
    local output = os.date("%A, %d. %B %Y, *%H:%M:%S Uhr*")
	utilities.send_reply(self, msg, time:localize(output), true)
	return
  end

  local coords = utilities.get_coords(input, config)
  if type(coords) == 'string' then
    utilities.send_reply(self, msg, coords)
    return
  end

  local now = os.time()
  local utc = os.time(os.date("!*t", now))

  local url = 'https://maps.googleapis.com/maps/api/timezone/json?location=' .. coords.lat ..','.. coords.lon .. '&timestamp='..utc..'&language=de'
  local jstr, res = https.request(url)
  if res ~= 200 then
    utilities.send_reply(self, msg, config.errors.connection)
    return
  end
  
  local jdat = json.decode(jstr)
  local timezoneid = '*'..string.gsub(jdat.timeZoneId, '_', ' ' )..'*'
  local timestamp = now + jdat.rawOffset + jdat.dstOffset
  local utcoff = (jdat.rawOffset + jdat.dstOffset) / 3600
  if utcoff == math.abs(utcoff) then
    utcoff = '+'.. utilities.pretty_float(utcoff)
  else
    utcoff = utilities.pretty_float(utcoff)
  end
  -- "%A, %d. %B %Y, %H:%M:%S Uhr"
  local output = timezoneid..':\n'..os.date('!%A, %d. %B %Y, %H:%M:%S Uhr',timestamp)
  local output = time:localize(output)
  
  local output = output..'\n_'..jdat.timeZoneName .. ' (UTC' .. utcoff .. ')_'
	
  utilities.send_reply(self, msg, output, true)
end

return time
