local quotes = {}

local bot = require('otouto.bot')
local utilities = require('otouto.utilities')
local redis = (loadfile "./otouto/redis.lua")()
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

function quotes:get_quote(msg, num)
  local hash = get_redis_hash(msg, 'quotes')
  
  if hash then
    print('Getting quote from redis set '..hash)
  	local quotes_table = redis:smembers(hash)
	if not quotes_table[1] then
	  return nil, 'Es wurden noch keine Zitate gespeichert.\nSpeichere doch welche mit /addquote [Zitat]'
	else
	  local totalquotes = #quotes_table
	  if num then
	    selected_quote = tonumber(num)
	  else
	    selected_quote = math.random(1,totalquotes)
	  end
	  local prev_num = selected_quote - 1
	  if prev_num == 0 then
	    prev_num = totalquotes -- last quote
	  end
	  local next_num = selected_quote + 1
	  if next_num > totalquotes then
	    next_num = 1
	  end
	  return prev_num, quotes_table[selected_quote], next_num
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

function quotes:action(msg, config, matches, num, self_plz)
  if num or matches[1] == "quote" then
    if not self.BASE_URL then self = self_plz end
    local prev_num, selected_quote, next_num = quotes:get_quote(msg, num)
	if prev_num == next_num or not next_num or not prev_num then
	  keyboard = nil
	else
	  keyboard = '{"inline_keyboard":[[{"text":"« '..prev_num..'","callback_data":"quotes:'..prev_num..'"},{"text":"'..next_num..' »","callback_data":"quotes:'..next_num..'"}]]}'
	end
	if num then
	  local result = utilities.edit_message(self, msg.chat.id, msg.message_id, selected_quote, true, false, keyboard)
	  return
	end
    utilities.send_message(self, msg.chat.id, selected_quote, true, false, false, keyboard)
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

function quotes:callback(callback, msg, self, config, num)
  utilities.answer_callback_query(self, callback)
  quotes:action(msg, config, nil, num, self)
end

return quotes
