local games = {}

local xml = require("xml") 

games.command = 'game <Spiel>'

function games:init(config)
  games.triggers = {
	"^/game (.+)$"
	}
  games.doc = [[*
]]..config.cmd_pat..[[game*_ <Spiel>_: Sendet Infos zum Spiel]]
end

local BASE_URL = 'http://thegamesdb.net/api'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%/(%d+)%/(%d+)"
  local month, day, year = dateString:match(pattern)
  return day..'.'..month..'.'..year
end


function games:get_game_id(game)
  local url = BASE_URL..'/GetGamesList.php?name='..game
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local result = xml.load(res)
  if xml.find(result, 'id') then
    local game =  xml.find(result, 'id')[1]
	return game
  else
    return nil
  end
end

function games:send_game_photo(result, self, msg)
  local BASE_URL = xml.find(result, 'baseImgUrl')[1]
  local images = {}
  
  if xml.find(result, 'fanart') then
    local fanart = xml.find(result, 'fanart')[1]
    local fanrt_url = BASE_URL..fanart[1]
    table.insert(images, fanrt_url)
  end
  
  if xml.find(result, 'boxart', 'side', 'front') then
    local boxart = xml.find(result, 'boxart', 'side', 'front')[1]
    local boxart_url = BASE_URL..boxart
    table.insert(images, boxart_url)
  end
  
  local i = 0
  for k, v in pairs(images) do
    i = i+1
    local file = download_to_file(v, 'game'..i..'.jpg')
	utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
  end
end

function games:send_game_data(game_id, self, msg)
  local url = BASE_URL..'/GetGame.php?id='..game_id
  local res,code  = http.request(url)
  if code ~= 200 then return nil end
  local result = xml.load(res)
  
  local title = xml.find(result, 'GameTitle')[1]
  local platform = xml.find(result, 'Platform')[1]
  
  if xml.find(result, 'ReleaseDate') then
    date = ', erschienen am '..makeOurDate(xml.find(result, 'ReleaseDate')[1])
  else
    date = ''
  end
  
  if xml.find(result, 'Overview') then
    desc = '\n_'..string.sub(xml.find(result, 'Overview')[1], 1, 200) .. '..._'
  else
    desc = ''
  end
  
  if xml.find(result, 'Genres') then
    local genres = xml.find(result, 'Genres')
    local genre_count = tablelength(genres)-1
    if genre_count == 1 then
      genre = '\nGenre: '..genres[1][1]
    else
      local genre_loop = '\nGenres: '
      for v in pairs(genres) do
        if v == 'xml' then break; end
	    if v < genre_count then
          genre_loop = genre_loop..genres[v][1]..', '
	    else
	      genre_loop = genre_loop..genres[v][1]
	    end
      end
	  genre = genre_loop
    end
  else
    genre = ''
  end
  
  if xml.find(result, 'Players') then
    players = '\nSpieler: '..xml.find(result, 'Players')[1]
  else
    players = ''
  end
  
  if xml.find(result, 'Youtube') then
    video = '\n[Video auf YouTube ansehen]('..xml.find(result, 'Youtube')[1]..')'
  else
    video = ''
  end
  
  if xml.find(result, 'Publisher') then
    publisher = '\nPublisher: '..xml.find(result, 'Publisher')[1]
  else
    publisher = ''
  end
  
  local text = '*'..title..'* für *'..platform..'*'..date..desc..genre..players..video..publisher
  utilities.send_reply(self, msg, text, true)
  
  if xml.find(result, 'fanrt') or xml.find(result, 'boxart') then
    utilities.send_typing(self, msg.chat.id, 'upload_photo')
    games:send_game_photo(result, self, msg)
  end
  return
end


function games:action(msg, config, matches)
  local game = URL.escape(matches[1])
  local game_id = games:get_game_id(game)
  if not game_id then
    utilities.send_reply(self, msg, 'Spiel nicht gefunden!')
    return
  else
    games:send_game_data(game_id, self, msg)
  end
end

return games
