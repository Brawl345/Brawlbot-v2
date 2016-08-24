local imgblacklist = {}

imgblacklist.command = 'imgblacklist'

function imgblacklist:init(config)
	imgblacklist.triggers = {
	  "^/imgblacklist show$",
      "^/imgblacklist (add) (.*)$",
	  "^/imgblacklist (remove) (.*)$"
	}
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

function imgblacklist:action(msg, config, matches)
  if msg.from.id ~= config.admin then
    utilities.send_reply(msg, config.errors.sudo)
	return
  end
  
  
  local action = matches[1]
  if matches[2] then word = string.lower(matches[2]) else word = nil end
  _blacklist = redis:smembers("telegram:img_blacklist")
  
  if action == 'add' and not word then
    utilities.send_reply(msg, imgblacklist.doc, true)
	return
  elseif action == "add" and word then
	utilities.send_reply(msg, imgblacklist:add_blacklist(word), true)
    return
  end
  
  if action == 'remove' and not word then
    utilities.send_reply(msg, imgblacklist.doc, true)
	return
  elseif action == "remove" and word then
	utilities.send_reply(msg, imgblacklist:remove_blacklist(word), true)
    return
   end

  utilities.send_reply(msg, imgblacklist:show_blacklist())
end

return imgblacklist
