local tv = {}

local xml = require("xml") 

tv.command = 'tv <TV-Serie>'

function tv:init(config)
  tv.triggers = {
	"^/tv (.+)$"
	}
  tv.doc = [[*
]]..config.cmd_pat..[[tv*_ <TV-Serie>_: Sendet Infos zur TV-Serie]]
end

local BASE_URL = 'http://thetvdb.com/api'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end


function tv:get_tv_info(series)
  local url = BASE_URL..'/GetSeries.php?seriesname='..series..'&language=de'
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-ERROR" end
  local result = xml.load(res)
  if not xml.find(result, 'seriesid') then return "NOTFOUND" end
  return result
end

function tv:send_tv_data(result, msg)
  local title = xml.find(result, 'SeriesName')[1]
  local id = xml.find(result, 'seriesid')[1]
  
  if xml.find(result, 'AliasNames') and xml.find(result, 'AliasNames')[1] ~= title then
    alias = '\noder: '..xml.find(result, 'AliasNames')[1]
  else
    alias = ''
  end
  
  if xml.find(result, 'Overview') then
    desc = '\n_'..string.sub(xml.find(result, 'Overview')[1], 1, 250) .. '..._'
  else
    desc = ''
  end
  
  if xml.find(result, 'FirstAired') then
    aired = '\n*Erstausstrahlung:* '..makeOurDate(xml.find(result, 'FirstAired')[1])
  else
    aired = ''
  end
 
  
  if xml.find(result, 'Network') then
    publisher = '\n*Publisher:* '..xml.find(result, 'Network')[1]
  else
    publisher = ''
  end
  
  if xml.find(result, 'IMDB_ID') then
    imdb = '\n[IMDB-Seite](http://www.imdb.com/title/'..xml.find(result, 'IMDB_ID')[1]..')'
  else
    imdb = ''
  end
  
  local text = '*'..title..'*'..alias..aired..publisher..imdb..desc..'\n[TVDB-Seite besuchen](http://thetvdb.com/?id='..id..'&tab=series)'
  if xml.find(result, 'banner') then
    local image_url = 'http://www.thetvdb.com/banners/'..xml.find(result, 'banner')[1]
	utilities.send_typing(msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url)
	utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
  end
  utilities.send_reply(msg, text, true)
end


function tv:action(msg, config, matches)
  local series = URL.escape(matches[1])
  local tv_info = tv:get_tv_info(series)
  if tv_info == "NOTFOUND" then
    utilities.send_reply(msg, config.errors.results)
	return
  elseif tv_info == "HTTP-ERROR" then
    utilities.send_reply(msg, config.errors.connection)
	return
  else
    tv:send_tv_data(tv_info, msg)
  end
end

return tv
