local lyrics = {}

local http = require('socket.http')
local json = require('dkjson')
local utilities = require('otouto.utilities')

function lyrics:init(config)
	if not cred_data.lyricsnmusic_apikey then
		print('Missing config value: lyricsnmusic_apikey.')
		print('lyrics.lua will not be enabled.')
		return
	end

	lyrics.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('lyrics', true).table
	lyrics.doc = [[*
]]..config.cmd_pat..[[lyrics* _<Lied>_: Postet Liedertext]]
end

lyrics.command = 'lyrics <Lied>'

function lyrics:getLyrics(text)
  local apikey = cred_data.lyricsnmusic_apikey
  local q = url_encode(text)
  local b = http.request("http://api.lyricsnmusic.com/songs?api_key="..apikey.."&q=" .. q)
  response = json.decode(b)
  local reply = ""
  if #response > 0 then
    -- grab first match
    local result = response[1]
    reply = result.title .. " - " .. result.artist.name .. "\n" .. result.snippet .. "\n[Ganzen Liedertext ansehen](" .. result.url .. ")"
  else
    reply = nil
  end
  return reply
end

function lyrics:action(msg, config, matches)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(self, msg.chat.id, lyrics.doc, true, msg.message_id, true)
	  return
	end
  end
  
  utilities.send_reply(self, msg, lyrics:getLyrics(input), true)
end

return lyrics
