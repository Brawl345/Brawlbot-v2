local imgblacklist = {}

local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()

imgblacklist.command = 'imgblacklist'

function imgblacklist:init(config)
	imgblacklist.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('imgblacklist', true).table
	imgblacklist.doc = [[*
]]..config.cmd_pat..[[imgblacklist* _show_: Zeige Blacklist
*]]..config.cmd_pat..[[imgblacklist* _add_ _<Wort>_: Fügt Wort der Blacklist hinzu
*]]..config.cmd_pat..[[imgblacklist* _remove_ _<Wort>_: Entfernt Wort von der Blacklist]]
end

function imgblacklist:show_blacklist()
  if not _blacklist[1] then
    return "Keine Wörter geblacklisted!\nBlackliste welche mit `/imgblacklist add [Wort]`"
  else
    local sort_alph = function( a,b ) return a < b end
    table.sort( _blacklist, sort_alph )
    local blacklist = "Folgende Wörter stehen auf der Blacklist:\n"
    for v,word in pairs(_blacklist) do
      blacklist = blacklist..'- '..word..'\n'
    end
	return blacklist
  end
end

function imgblacklist:add_blacklist(word)
  print('Blacklisting '..word..' - saving to redis set telegram:img_blacklist')
  if redis:sismember("telegram:img_blacklist", word) == true then
    return '"'..word..'" steht schon auf der Blacklist.'
  else
    redis:sadd("telegram:img_blacklist", word)
    return '"'..word..'" blacklisted!'
  end
end

function imgblacklist:remove_blacklist(word)
  print('De-blacklisting '..word..' - removing from redis set telegram:img_blacklist')
  if redis:sismember("telegram:img_blacklist", word) == true then
    redis:srem("telegram:img_blacklist", word)
    return '"'..word..'" erfolgreich von der Blacklist gelöscht!'
  else
    return '"'..word..'" steht nicht auf der Blacklist.'
  end
end

function imgblacklist:action(msg, config)
  if msg.from.id ~= config.admin then
    utilities.send_reply(self, msg, config.errors.sudo)
	return
  end
  
  local input = utilities.input(msg.text)
  local input = string.lower(input)
  _blacklist = redis:smembers("telegram:img_blacklist")
  
  if input:match('(add) (.*)') then
    local word = input:match('add (.*)')
    output = imgblacklist:add_blacklist(word)
  elseif input:match('(remove) (.*)') then
    local word = input:match('remove (.*)')
    output = imgblacklist:remove_blacklist(word)
  elseif input:match('(show)') then
    output = imgblacklist:show_blacklist()
  else
    utilities.send_message(self, msg.chat.id, imgblacklist.doc, true, msg.message_id, true)
	return
  end

  utilities.send_message(self, msg.chat.id, output, true, nil, true)
end

return imgblacklist
