local ifttt = {}

local https = require('ssl.https')
local URL = require('socket.url')
local redis = (loadfile "./otouto/redis.lua")()
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

function ifttt:init(config)
  ifttt.triggers = {
    "^/ifttt (!set) (.*)$",
	"^/ifttt (!unauth)$",
	"^/ifttt (.*)%&(.*)%&(.*)%&(.*)",
	"^/ifttt (.*)%&(.*)%&(.*)",
	"^/ifttt (.*)%&(.*)",
	"^/ifttt (.*)$"
  }
  
  ifttt.doc = [[*
]]..config.cmd_pat..[[ifttt* _!set_ _<Key>_: Speichere deinen Schlüssel ein (erforderlich)
*]]..config.cmd_pat..[[ifttt* _!unauth_: Löscht deinen Account aus dem Bot
*]]..config.cmd_pat..[[ifttt* _<Event>_&_<Value1>_&_<Value2>_&_<Value3>_: Führt [Event] mit den optionalen Parametern Value1, Value2 und Value3 aus
Beispiel: `/ifttt DeinFestgelegterName&Hallo&NochEinHallo`: Führt 'DeinFestgelegterName' mit den Parametern 'Hallo' und 'NochEinHallo' aus.]]
end

ifttt.command = 'ifttt <Event>&<Value1>&<Value2>&<Value3>'

local BASE_URL = 'https://maker.ifttt.com/trigger'

function ifttt:set_ifttt_key(hash, key)
  print('Setting ifttt in redis hash '..hash..' to '..key)
  redis:hset(hash, 'ifttt', key)
  return '*Schlüssel eingespeichert!* Das Plugin kann jetzt verwendet werden.'
end

function ifttt:do_ifttt_request(key, event, value1, value2, value3)
  if not value1 then
    url = BASE_URL..'/'..event..'/with/key/'..key
  elseif not value2 then
    url = BASE_URL..'/'..event..'/with/key/'..key..'/?value1='..URL.escape(value1)
  elseif not value3 then
    url = BASE_URL..'/'..event..'/with/key/'..key..'/?value1='..URL.escape(value1)..'&value2='..URL.escape(value2)
  else
    url = BASE_URL..'/'..event..'/with/key/'..key..'/?value1='..URL.escape(value1)..'&value2='..URL.escape(value2)..'&value3='..URL.escape(value3)
  end

  local res,code = https.request(url)
  if code ~= 200 then return "*Ein Fehler ist aufgetreten!* Aktion wurde nicht ausgeführt." end
  
  return "*Event \""..event.."\" getriggert!*"
end

function ifttt:action(msg, config, matches)
  local hash = 'user:'..msg.from.id
  local key = redis:hget(hash, 'ifttt')
  local event = matches[1]
  local value1 = matches[2]
  local value2 = matches[3]
  local value3 = matches[4]
  
  if event == '!set' then
    utilities.send_reply(self, msg, ifttt:set_ifttt_key(hash, value1), true)
    return
  end
  
  if not key then
    utilities.send_reply(self, msg, '*Bitte speichere zuerst deinen Schlüssel ein!* Aktiviere dazu den [Maker Channel](https://ifttt.com/maker) und speichere deinen Schlüssel mit `/ifttt !set KEY` ein', true)
    return
  end
  
  if event == '!unauth' then
    redis:hdel(hash, 'ifttt')
	utilities.send_reply(self, msg, '*Erfolgreich ausgeloggt!*', true)
	return
  end
  
  utilities.send_reply(self, msg, ifttt:do_ifttt_request(key, event, value1, value2, value3), true)
end

return ifttt