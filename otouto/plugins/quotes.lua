local quotes = {}

require("./otouto/plugins/pasteee")

function quotes:init(config)
    quotes.triggers = {
    "^/(delquote) (.+)$",
    "^/(addquote) (.+)$",
    "^/(quote)$",
	"^/(listquotes)$",
	"^/(delquote)$"
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
  local quote = msg.text:sub(11)
  local hash = get_redis_hash(msg, 'quotes')
  print('Saving quote to redis set '..hash)
  redis:sadd(hash, quote)
  return '*Gespeichert!*'
end

function quotes:delete_quote(msg)
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

function quotes:callback(callback, msg, self, config)
  local hash = get_redis_hash(msg, 'quotes')
  
  if hash then
    print('Getting quotes from redis set '..hash)
    local quotes_table = redis:smembers(hash)
	local text = ""

    for num,quote in pairs(quotes_table) do
      text = text..'<b>'..num..")</b> "..quote..'\n'
    end

	if not text or text == "" then
	  utilities.answer_callback_query(callback, 'Es wurden noch keine Zitate gespeichert.', true)
	else
      -- In case the quote list is > 4096 chars
      local text_len = string.len(text)
      
      while text_len > 4096 do
        to_send_text = string.sub(text, 1, 4096)
        text = string.sub(text, 4096, text_len)
        local res = utilities.send_message(callback.from.id, to_send_text, true, nil, 'HTML')

        if not res then
          utilities.answer_callback_query(callback, 'Bitte starte den Bot zuerst privat!', true)
          return
        end
        text_len = string.len(text)
      end
      
      local res = utilities.send_message(callback.from.id, to_send_text, true, nil, 'HTML')
      if not res then
        utilities.answer_callback_query(callback, 'Bitte starte den Bot zuerst privat!', true)
        return
      end
      utilities.answer_callback_query(callback, 'Zitatliste per PN verschickt')
    end
  else
    utilities.answer_callback_query(callback, 'Es wurden noch keine Zitate gespeichert.', true)
  end
end

function quotes:action(msg, config, matches)
  if msg.chat.type == 'private' then
    utilities.send_reply(msg, 'Dieses Plugin kann nur in Gruppen verwendet werden!')
    return
  end

  if matches[1] == "quote" then
    utilities.send_message(msg.chat.id, quotes:get_quote(msg), true, nil, false)
    return
  elseif matches[1] == "addquote" and matches[2] then
    utilities.send_reply(msg, quotes:save_quote(msg), true)
    return
  elseif matches[1] == "delquote" and matches[2] then
    if not is_sudo(msg, config) then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
	utilities.send_reply(msg, quotes:delete_quote(msg), true)
	return
  elseif matches[1] == "delquote" and not matches[2] then
	if not is_sudo(msg, config) then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    end
    if msg.reply_to_message then
	  local msg = msg.reply_to_message
	  utilities.send_reply(msg, quotes:delete_quote(msg), true)
	  return
	end
  elseif matches[1] == "listquotes" then
    utilities.send_reply(msg, 'Bitte klicke hier unten auf diese attraktive Schaltfläche.', false, '{"inline_keyboard":[[{"text":"Alle Zitate per PN","callback_data":"quotes:"}]]}')
    return
  end
  utilities.send_reply(msg, quotes.doc, true)
end

return quotes
