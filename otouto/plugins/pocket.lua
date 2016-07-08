local pocket = {}

local https = require('ssl.https')
local URL = require('socket.url')
local redis = (loadfile "./otouto/redis.lua")()
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

function pocket:init(config)
  if not cred_data.pocket_consumer_key then
	print('Missing config value: pocket_consumer_key.')
	print('pocket.lua will not be enabled.')
	return
  end

  pocket.triggers = {
    "^/pocket(set)(.+)$",
	"^/pocket (add) (https?://.*)$",
	"^/pocket (archive) (%d+)$",
	"^/pocket (readd) (%d+)$",
	"^/pocket (unfavorite) (%d+)$",
	"^/pocket (favorite) (%d+)$",
	"^/pocket (delete) (%d+)$",
	"^/pocket (unauth)$",
    "^/pocket$"
  }

  pocket.doc =   [[*
]]..config.cmd_pat..[[pocket*: Postet Liste deiner Links
*]]..config.cmd_pat..[[pocket* add _(url)_: Fügt diese URL deiner Liste hinzu
*]]..config.cmd_pat..[[pocket* archive _[id]_: Archiviere diesen Eintrag
*]]..config.cmd_pat..[[pocket* readd _[id]_: De-archiviere diesen Eintrag
*]]..config.cmd_pat..[[pocket* favorite _[id]_: Favorisiere diesen Eintrag
*]]..config.cmd_pat..[[pocket* unfavorite _[id]_: Entfavorisiere diesen Eintrag
*]]..config.cmd_pat..[[pocket* delete _[id]_: Lösche diesen Eintrag
*]]..config.cmd_pat..[[pocket* unauth: Löscht deinen Account aus dem Bot]]
end

pocket.command = 'pocket <siehe `/hilfe pocket`>'

local BASE_URL = 'https://getpocket.com/v3'
local consumer_key = cred_data.pocket_consumer_key
local headers = {
   ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF8",
   ["X-Accept"] = "application/json"
}

function pocket:set_pocket_access_token(hash, access_token)
  if string.len(access_token) ~= 30 then return '*Inkorrekter Access-Token*' end
  print('Setting pocket in redis hash '..hash..' to users access_token')
  redis:hset(hash, 'pocket', access_token)
  return '*Authentifizierung abgeschlossen!*\nDas Plugin kann jetzt verwendet werden.'
end

function pocket:list_pocket_items(access_token)
  local items = post_petition(BASE_URL..'/get', 'consumer_key='..consumer_key..'&access_token='..access_token..'&state=unread&sort=newest&detailType=simple', headers)
  
  if items.status == 2 then return 'Keine Elemente eingespeichert.' end
  if items.status ~= 1 then return 'Ein Fehler beim Holen der Elemente ist aufgetreten.' end
  
  local text = ''
  for element in pairs(items.list) do
    title = items.list[element].given_title
	if not title or title == "" then title = items.list[element].resolved_title end
    text = text..'#'..items.list[element].item_id..': '..title..'\n— '..items.list[element].resolved_url..'\n\n'
  end
  
  return text
end

function pocket:add_pocket_item(access_token, url)
  local result = post_petition(BASE_URL..'/add', 'consumer_key='..consumer_key..'&access_token='..access_token..'&url='..url, headers)
  if result.status ~= 1 then return 'Ein Fehler beim Hinzufügen der URL ist aufgetreten :(' end
  local given_url = result.item.given_url
  if result.item.title == "" or not result.item.title then
    title = 'Seite'
  else
    title = '"'..result.item.title..'"'
  end
  local code = result.item.response_code
  
  local text = title..' ('..given_url..') hinzugefügt!'
  if code ~= "200" and code ~= "0" then text = text..'\nAber die Seite liefert Fehler '..code..' zurück.' end
  return text
end

function pocket:modify_pocket_item(access_token, action, id)
  local result = post_petition(BASE_URL..'/send', 'consumer_key='..consumer_key..'&access_token='..access_token..'&actions=[{"action":"'..action..'","item_id":'..id..'}]', headers)
  if result.status ~= 1 then return 'Ein Fehler ist aufgetreten :(' end
  
  if action == 'readd' then
    if result.action_results[1] == false then
	  return 'Dieser Eintrag existiert nicht!'
	end
    local url = result.action_results[1].normal_url
	return url..' wieder de-archiviert'
  end
  if result.action_results[1] == true then
    return 'Aktion ausgeführt.'
  else
    return 'Ein Fehler ist aufgetreten.'
  end
end  

function pocket:action(msg, config, matches)
  local hash = 'user:'..msg.from.id
  local access_token = redis:hget(hash, 'pocket')
  
  if matches[1] == 'set' then
    local access_token = matches[2]
	utilities.send_reply(self, msg, pocket:set_pocket_access_token(hash, access_token), true)
	local message_id = redis:hget(hash, 'pocket_login_msg')
	utilities.edit_message(self, msg.chat.id, message_id, '*Anmeldung abgeschlossen!*', true, true)
	redis:hdel(hash, 'pocket_login_msg')
    return
  end
  
  if not access_token then
    local result = utilities.send_reply(self, msg, '*Bitte authentifiziere dich zuerst, indem du dich anmeldest.*', true, '{"inline_keyboard":[[{"text":"Bei Pocket anmelden","url":"https://brawlbot.tk/apis/callback/pocket/connect.php"}]]}')
    redis:hset(hash, 'pocket_login_msg', result.result.message_id)
	return
  end
  
  if matches[1] == 'unauth' then
    redis:hdel(hash, 'pocket')
	utilities.send_reply(self, msg, 'Erfolgreich ausgeloggt! Du kannst den Zugriff [in deinen Einstellungen](https://getpocket.com/connected_applications) endgültig entziehen.', true)
	return
  end
  
  if matches[1] == 'add' then
    utilities.send_reply(self, msg, pocket:add_pocket_item(access_token, matches[2]))
    return
  end
  
  if matches[1] == 'archive' or matches[1] == 'delete' or matches[1] == 'readd' or matches[1] == 'favorite' or matches[1] == 'unfavorite' then
    utilities.send_reply(self, msg, pocket:modify_pocket_item(access_token, matches[1], matches[2]))
	return
  end
  
  if msg.chat.type == 'chat' or msg.chat.type == 'supergroup' then
    utilities.send_reply(self, msg, 'Ausgeben deiner privaten Pocket-Liste in einem öffentlichen Chat wird feige verweigert. Bitte schreibe mich privat an!', true)
    return
  else
    utilities.send_reply(self, msg, pocket:list_pocket_items(access_token))
    return
  end
end

return pocket