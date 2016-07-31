local quotes = {}

require("./otouto/plugins/pasteee")

function quotes:init(config)
    quotes.triggers = {
    "^/(delquote) (.+)$",
    "^/(addquote) (.+)$",
    "^/(quote)$",
	"^/(listquotes)$"
	}
	quotes.doc = [[*
]]..config.cmd_pat..[[addquote* _<Zitat>_: Fügt Zitat hinzu.
*]]..config.cmd_pat..[[delquote* _<Zitat>_: Löscht das Zitat (nur Superuser)
*]]..config.cmd_pat..[[quote*: Gibt zufälliges Zitat aus
*]]..config.cmd_pat..[[listquotes*: Listet alle Zitate auf
]]
end

quotes.command = 'quote'

function quotes:save_quote(msg)
  if msg.text:sub(11):isempty() then
    return "Benutzung: /addquote [Zitat]"
  end
  
  local quote = msg.text:sub(11)
  local hash = get_redis_hash(msg, 'quotes')
  print('Saving quote to redis set '..hash)
  redis:sadd(hash, quote)
  return '*Gespeichert!*'
end

function quotes:delete_quote(msg)
  if msg.text:sub(11):isempty() then
    return "Benutzung: /delquote [Zitat]"
  end
  
  local quote = msg.text:sub(11)
  local hash = get_redis_hash(msg, 'quotes')
  print('Deleting quote from redis set '..hash)
  if redis:sismember(hash, quote) == true then
    redis:srem(hash, quote)
    return '*Zitat erfolgreich gelöscht!*'
  else
    return 'Dieses Zitat existiert nicht.'
  end
end

function quotes:get_quote(msg)
  local hash = get_redis_hash(msg, 'quotes')
  
  if hash then
    print('Getting quote from redis set '..hash)
  	local quotes_table = redis:smembers(hash)
	if not quotes_table[1] then
	  return 'Es wurden noch keine Zitate gespeichert.\nSpeichere doch welche mit /addquote [Zitat]'
	else
	  return quotes_table[math.random(1,#quotes_table)]
	end
  end
end

function quotes:list_quotes(msg)
  local hash = get_redis_hash(msg, 'quotes')
  
  if hash then
    print('Getting quotes from redis set '..hash)
    local quotes_table = redis:smembers(hash)
	local text = ""
    for num,quote in pairs(quotes_table) do
      text = text..num..") "..quote..'\n'
    end
	if not text or text == "" then
	  return '*Es wurden noch keine Zitate gespeichert.*\nSpeichere doch welche mit `/addquote [Zitat]`', true
	else
	  return upload(text)
	end
  end
end

function quotes:action(msg, config, matches)
  if matches[1] == "quote" then
    utilities.send_message(self, msg.chat.id, quotes:get_quote(msg), true)
    return
  elseif matches[1] == "addquote" and matches[2] then
    utilities.send_reply(self, msg, quotes:save_quote(msg), true)
    return
  elseif matches[1] == "delquote" and matches[2] then
    if msg.from.id ~= config.admin then
      utilities.send_reply(self, msg, config.errors.sudo)
	  return
    end
	  utilities.send_reply(self, msg, quotes:delete_quote(msg), true)
	  return
  elseif matches[1] == "listquotes" then
    local link, iserror = quotes:list_quotes(msg)
	if iserror then
      utilities.send_reply(self, msg, link, true)
	  return
    end
    utilities.send_reply(self, msg, 'Ich habe eine Liste aller Zitate hochgeladen.', false, '{"inline_keyboard":[[{"text":"Alle Zitate abrufen","url":"'..link..'"}]]}')
    return
  end
  utilities.send_reply(self, msg, quotes.doc, true)
end

return quotes
