local mal = {}

local http = require('socket.http')
local URL = require('socket.url')
local xml = require("xml") 
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

mal.command = 'anime <Anime>, /manga <Manga>'

function mal:init(config)
	if not cred_data.mal_user then
		print('Missing config value: mal_user.')
		print('myanimelist.lua will not be enabled.')
		return
	elseif not cred_data.mal_pw then
		print('Missing config value: mal_pw.')
		print('myanimelist.lua will not be enabled.')
		return
	end

  mal.triggers = {
	"^/(anime) (.+)$",
	"^/(manga) (.+)$"
	}
  mal.doc = [[*
]]..config.cmd_pat..[[anime*_ <Anime>_: Sendet Infos zum Anime
*]]..config.cmd_pat..[[manga*_ <Manga>_: Sendet Infos zum Manga
]]
end

local user = cred_data.mal_user
local password = cred_data.mal_pw

local BASE_URL = 'http://'..user..':'..password..'@myanimelist.net/api'

function mal:delete_tags(str)
  str = string.gsub( str, '<br />', '')
  str = string.gsub( str, '%[i%]', '')
  str = string.gsub( str, '%[/i%]', '')
  str = string.gsub( str, '&mdash;', ' — ')
  return str
end

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)"
  local year, month, day = dateString:match(pattern)
  return day..'.'..month..'.'..year
end

function mal:get_mal_info(query, typ)
  if typ == 'anime' then
    url = BASE_URL..'/anime/search.xml?q='..query
  elseif typ == 'manga' then
    url = BASE_URL..'/manga/search.xml?q='..query
  end
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-Fehler" end
  local result = xml.load(res)
  return result
end

function mal:send_anime_data(result, receiver)
  local title = xml.find(result, 'title')[1]
  local id = xml.find(result, 'id')[1]
  local mal_url = 'http://myanimelist.net/anime/'..id
  
  if xml.find(result, 'synonyms')[1] then
    alt_name = '\noder: '..unescape(mal:delete_tags(xml.find(result, 'synonyms')[1]))
  else
    alt_name = ''
  end
  
  if xml.find(result, 'synopsis')[1] then
    desc = '\n'..unescape(mal:delete_tags(string.sub(xml.find(result, 'synopsis')[1], 1, 200))) .. '...'
  else
    desc = ''
  end

  if xml.find(result, 'episodes')[1] then
    episodes = '\nEpisoden: '..xml.find(result, 'episodes')[1]
  else
    episodes = ''
  end
  
  if xml.find(result, 'status')[1] then
    status = ' ('..xml.find(result, 'status')[1]..')'
  else
    status = ''
  end
  
  if xml.find(result, 'score')[1] ~= "0.00" then
    score = '\nScore: '..string.gsub(xml.find(result, 'score')[1], "%.", ",")
  else
    score = ''
  end
  
  if xml.find(result, 'type')[1] then
    typ = '\nTyp: '..xml.find(result, 'type')[1]
  else
    typ = ''
  end
 
  if xml.find(result, 'start_date')[1] ~= "0000-00-00" then
    startdate = '\nVeröffentlichungszeitraum: '..makeOurDate(xml.find(result, 'start_date')[1])
  else
    startdate = ''
  end
 
  if xml.find(result, 'end_date')[1] ~= "0000-00-00" then
    enddate = ' - '..makeOurDate(xml.find(result, 'end_date')[1])
  else
    enddate = ''
  end
  
  local text = '*'..title..'*'..alt_name..typ..episodes..status..score..startdate..enddate..'_'..desc..'_\n[Auf MyAnimeList ansehen]('..mal_url..')'
  if xml.find(result, 'image') then
    local image_url = xml.find(result, 'image')[1]
    return text, image_url
  else
    return text
  end 
end

function mal:send_manga_data(result)
  local title = xml.find(result, 'title')[1]
  local id = xml.find(result, 'id')[1]
  local mal_url = 'http://myanimelist.net/manga/'..id
  
  if xml.find(result, 'type')[1] then
    typ = ' ('..xml.find(result, 'type')[1]..')'
  else
    typ = ''
  end
  
  if xml.find(result, 'synonyms')[1] then
    alt_name = '\noder: '..unescape(mal:delete_tags(xml.find(result, 'synonyms')[1]))
  else
    alt_name = ''
  end

  if xml.find(result, 'chapters')[1] then
    chapters = '\nKapitel: '..xml.find(result, 'chapters')[1]
  else
    chapters = ''
  end
  
  if xml.find(result, 'status')[1] then
    status = ' ('..xml.find(result, 'status')[1]..')'
  else
    status = ''
  end

  if xml.find(result, 'volumes')[1] then
    volumes = '\nBände '..xml.find(result, 'volumes')[1]
  else
    volumes = ''
  end
  
  if xml.find(result, 'score')[1] ~= "0.00" then
    score = '\nScore: '..xml.find(result, 'score')[1]
  else
    score = ''
  end
 
  if xml.find(result, 'start_date')[1] ~= "0000-00-00" then
    startdate = '\nVeröffentlichungszeitraum: '..makeOurDate(xml.find(result, 'start_date')[1])
  else
    startdate = ''
  end
 
  if xml.find(result, 'end_date')[1] ~= "0000-00-00" then
    enddate = ' - '..makeOurDate(xml.find(result, 'end_date')[1])
  else
    enddate = ''
  end
  
  if xml.find(result, 'synopsis')[1] then
    desc = '\n'..unescape(mal:delete_tags(string.sub(xml.find(result, 'synopsis')[1], 1, 200))) .. '...'
  else
    desc = ''
  end
 
  local text = '*'..title..'*'..alt_name..typ..chapters..status..volumes..score..startdate..enddate..'_'..desc..'_\n[Auf MyAnimeList ansehen]('..mal_url..')'
  if xml.find(result, 'image') then
    local image_url = xml.find(result, 'image')[1]
    return text, image_url
  else
    return text
  end 
end

function mal:action(msg, config, matches)
  local query = URL.escape(matches[2])
  if matches[1] == 'anime' then
    local anime_info = mal:get_mal_info(query, 'anime')
    if anime_info == "HTTP-Fehler" then
      utilities.send_reply(self, msg, 'Anime nicht gefunden!')
	  return
    else
      local text, image_url = mal:send_anime_data(anime_info)
	  if image_url then
	    utilities.send_typing(self, msg.chat.id, 'upload_photo')
	    local file = download_to_file(image_url)
		utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
	  end
	  utilities.send_reply(self, msg, text, true)  
	  return
    end
  elseif matches[1] == 'manga' then
    local manga_info = mal:get_mal_info(query, 'manga')
    if manga_info == "HTTP-Fehler" then
      utilities.send_reply(self, msg, 'Manga nicht gefunden!')
	  return
    else
      local text, image_url = mal:send_manga_data(manga_info)
	  if image_url then
	    utilities.send_typing(self, msg.chat.id, 'upload_photo')
	    local file = download_to_file(image_url)
		utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
	  end
	  utilities.send_reply(self, msg, text, true)
	  return
    end
  end
end

return mal
