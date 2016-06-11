local imdb = {}

local HTTP = require('socket.http')
local URL = require('socket.url')
local JSON = require('dkjson')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

imdb.command = 'imdb <query>'

function imdb:init(config)
	imdb.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('imdb', true).table
	imdb.doc = [[*
]]..config.cmd_pat..[[imdb* _<Film>_
Sucht _Film_ bei IMDB]]
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

	local url = 'http://www.omdbapi.com/?t=' .. URL.escape(input)

	local jstr, res = HTTP.request(url)
	if res ~= 200 then
		utilities.send_reply(self, msg, config.errors.connection)
		return
	end

	local jdat = JSON.decode(jstr)

	if jdat.Response ~= 'True' then
		utilities.send_reply(self, msg, config.errors.results)
		return
	end

	local output = '*' .. jdat.Title .. ' ('.. jdat.Year ..')* von '..jdat.Director..'\n'
	output = output .. string.gsub(jdat.imdbRating, '%.', ',') ..'/10 | '.. jdat.Runtime ..' | '.. jdat.Genre ..'\n'
	output = output .. '_' .. jdat.Plot .. '_\n'
	output = output .. '[IMDB-Seite besuchen](http://imdb.com/title/' .. jdat.imdbID .. ')'

	utilities.send_message(self, msg.chat.id, output, true, nil, true)
	
	if jdat.Poster ~= "N/A" then
	  local file = download_to_file(jdat.Poster)
      bindings.sendPhoto(self, {chat_id = msg.chat.id}, {photo = file} )
	end

end

return imdb
