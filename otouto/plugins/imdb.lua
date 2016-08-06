local imdb = {}

imdb.command = 'imdb <query>'

function imdb:init(config)
	imdb.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('imdb', true).table
	imdb.inline_triggers = {
	  "^imdb (.+)"
	}
	imdb.doc = [[*
]]..config.cmd_pat..[[imdb* _<Film>_
Sucht _Film_ bei IMDb]]
end

local BASE_URL = 'https://www.omdbapi.com'

function imdb:get_imdb_info(id)
  local url = BASE_URL..'/?i='..id
  local res, code = https.request(url)
  if code ~= 200 then return end
  local movie_info = json.decode(res)
  return movie_info
end

function imdb:inline_callback(inline_query, config, matches)
  local query = matches[1]
  local url = BASE_URL..'/?s='..URL.escape(query)
  local res, code = https.request(url)
  if code ~= 200 then utilities.answer_inline_query(self, inline_query) return end
  local data = json.decode(res)
  if data.Response ~= "True" then utilities.answer_inline_query(self, inline_query) return end
  
  local results = '['
  for num in pairs(data.Search) do
    if num > 5 then
	  break;
	end
  	local imdb_id = data.Search[num].imdbID
	local movie_info = imdb:get_imdb_info(imdb_id)
    local title = movie_info.Title
	local year = movie_info.Year
	local text = '<b>'..movie_info.Title.. ' ('..movie_info.Year..')</b> von '..movie_info.Director..'\\n'..string.gsub(movie_info.imdbRating, '%.', ',')..'/10 | '..movie_info.Runtime..' | '.. movie_info.Genre
	if movie_info.Plot then
	  text = text..'\\n<i>'..movie_info.Plot..'</i>'
	  description = movie_info.Plot
	else
	  description = 'Keine Beschreibung verfügbar'
	end
	local text = text:gsub('"', '\\"')
	local text = text:gsub("'", "\'")
	local description = description:gsub('"', '\\"')
	local description = description:gsub("'", "\'")

	if movie_info.Poster == "N/A" then
	  img_url = 'https://anditest.perseus.uberspace.de/inlineQuerys/imdb/logo.jpg'
	else
	  img_url = movie_info.Poster
	end
    results = results..'{"type":"article","id":"'..math.random(100000000000000000)..'","title":"'..title..' ('..year..')","description":"'..description..'","url":"http://imdb.com/title/'..imdb_id..'","hide_url":true,"thumb_url":"'..img_url..'","reply_markup":{"inline_keyboard":[[{"text":"IMDb-Seite aufrufen","url":"http://imdb.com/title/'..imdb_id..'"}]]},"input_message_content":{"message_text":"'..text..'","parse_mode":"HTML"}},'
  end
  
  local results = results:sub(0, -2)
  local results = results..']'
  utilities.answer_inline_query(self, inline_query, results, 10000)
end

function imdb:action(msg, config)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
	  input = msg.reply_to_message.text
	else
	  utilities.send_message(self, msg.chat.id, imdb.doc, true, msg.message_id, true)
	  return
	end
  end
  
  local url = BASE_URL..'/?t='..URL.escape(input)
  local jstr, res = https.request(url)
  if res ~= 200 then
    utilities.send_reply(self, msg, config.errors.connection)
    return
  end

  local jdat = json.decode(jstr)
  if jdat.Response ~= 'True' then
	utilities.send_reply(self, msg, config.errors.results)
	return
  end

  local output = '<b>'..jdat.Title.. ' ('..jdat.Year..')</b> von '..jdat.Director..'\n'
  output = output..string.gsub(jdat.imdbRating, '%.', ',')..'/10 | '..jdat.Runtime..' | '.. jdat.Genre..'\n'
  output = output..'<i>' .. jdat.Plot .. '</i>'

  utilities.send_reply(self, msg, output, 'HTML', '{"inline_keyboard":[[{"text":"IMDb-Seite aufrufen","url":"http://imdb.com/title/'.. jdat.imdbID..'"}]]}')
	
  if jdat.Poster ~= "N/A" then
    local file = download_to_file(jdat.Poster)
    utilities.send_photo(self, msg.chat.id, file)
  end
end

return imdb