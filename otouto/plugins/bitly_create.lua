local bitly_create = {}

function bitly_create:init(config)
	if not cred_data.bitly_client_id then
		print('Missing config value: bitly_client_id.')
		print('bitly_create.lua will not be enabled.')
		return
	elseif not cred_data.bitly_client_secret then
		print('Missing config value: bitly_client_secret.')
		print('bitly_create.lua will not be enabled.')
		return
	elseif not cred_data.bitly_redirect_uri then
		print('Missing config value: bitly_redirect_uri.')
		print('bitly_create.lua will not be enabled.')
		return
	end

    bitly_create.triggers = {
    "^/short(auth)(.+)$",
    "^/short (auth)$",
	"^/short (unauth)$",
	"^/short (me)$",
  	"^/short (j.mp) (https?://[%w-_%.%?%.:/%+=&]+)$",
	"^/short (bit.ly) (https?://[%w-_%.%?%.:/%+=&]+)$",
	"^/short (bitly.com) (https?://[%w-_%.%?%.:/%+=&]+)$",
	"^/short (https?://[%w-_%.%?%.:/%+=&]+)$"
	}
	bitly_create.doc = [[*
]]..config.cmd_pat..[[short* _<Link>_: Kürzt einen Link mit der Standard Bitly-Adresse
*]]..config.cmd_pat..[[short* _<j.mp|bit.ly|bitly.com>_ _[Link]_: Kürzt einen Link mit der ausgewählten Kurz-URL
*]]..config.cmd_pat..[[short* _auth_: Loggt deinen Account ein und nutzt ihn für deine Links (empfohlen!)
*]]..config.cmd_pat..[[short* _me_: Gibt den eingeloggten Account aus
*]]..config.cmd_pat..[[short* _unauth_: Loggt deinen Account aus
]]
end

bitly_create.command = 'short <URL>'

local BASE_URL = 'https://api-ssl.bitly.com'

local client_id = cred_data.bitly_client_id
local client_secret = cred_data.bitly_client_secret
local redirect_uri = cred_data.bitly_redirect_uri

function bitly_create:get_bitly_access_token(hash, code)
  local req = post_petition(BASE_URL..'/oauth/access_token', 'client_id='..client_id..'&client_secret='..client_secret..'&code='..code..'&redirect_uri='..redirect_uri)
  if not req.access_token then return '*Fehler beim Einloggen!*' end
  
  local access_token = req.access_token
  local login_name = req.login
  redis:hset(hash, 'bitly', access_token)
  return 'Erfolgreich als `'..login_name..'` eingeloggt!'
end

function bitly_create:get_bitly_user_info(bitly_access_token)
  local url = BASE_URL..'/v3/user/info?access_token='..bitly_access_token..'&format=json'
  local res,code  = https.request(url)
  if code == 401 then return 'Login fehlgeschlagen!' end
  if code ~= 200 then return 'HTTP-Fehler!' end
  
  local data = json.decode(res).data
  
  if data.full_name then
    name = '*'..data.full_name..'* (`'..data.login..'`)'
  else
    name = '`'..data.login..'`'
  end
  
  local text = 'Eingeloggt als '..name
  
  return text
end

function bitly_create:create_bitlink (long_url, domain, bitly_access_atoken)
  local url = BASE_URL..'/v3/shorten?access_token='..bitly_access_token..'&domain='..domain..'&longUrl='..long_url..'&format=txt'
  local text,code  = https.request(url)
  if code ~= 200 then return 'FEHLER: '..text end
  return text
end

function bitly_create:action(msg, config, matches)
  local hash = 'user:'..msg.from.id
  bitly_access_token = redis:hget(hash, 'bitly')
  
  if matches[1] == 'auth' and matches[2] then
    utilities.send_reply(msg, bitly_create:get_bitly_access_token(hash, matches[2]), true)
	local message_id = redis:hget(hash, 'bitly_login_msg')
	utilities.edit_message(msg.chat.id, message_id, '*Anmeldung abgeschlossen!*', true, true)
	redis:hdel(hash, 'bitly_login_msg')
    return
  end
  
  if matches[1] == 'auth' then
    local result = utilities.send_reply(msg, '*Bitte logge dich ein und folge den Anweisungen.*', true, '{"inline_keyboard":[[{"text":"Bei Bitly anmelden","url":"https://bitly.com/oauth/authorize?client_id='..client_id..'&redirect_uri='..redirect_uri..'&state='..self.info.username..'"}]]}')
    redis:hset(hash, 'bitly_login_msg', result.result.message_id)
	return
  end
  
  if matches[1] == 'unauth' and bitly_access_token then
    redis:hdel(hash, 'bitly')
	utilities.send_reply(msg, '*Erfolgreich ausgeloggt!* Du kannst den Zugriff [in deinen Kontoeinstellungen](https://bitly.com/a/settings/connected) endgültig entziehen.', true)
	return
  elseif matches[1] == 'unauth' and not bitly_access_token then
    utilities.send_reply(msg, 'Wie willst du dich ausloggen, wenn du gar nicht eingeloggt bist?', true)
    return
  end
  
  if matches[1] == 'me' and bitly_access_token then
    local text = bitly_create:get_bitly_user_info(bitly_access_token)
	if text then
	  utilities.send_reply(msg, text, true)
	  return
	else
	  return
	end
  elseif matches[1] == 'me' and not bitly_access_token then
    utilities.send_reply(msg, 'Du bist nicht eingeloggt! Logge dich ein mit\n/short auth', true)
    return
  end

  if not bitly_access_token then
    print('Not signed in, will use global bitly access_token')
    bitly_access_token = cred_data.bitly_access_token
  end

  if matches[2] == nil then
    long_url = URL.encode(matches[1])
	domain = 'bit.ly'
  else
    long_url = URL.encode(matches[2])
	domain = matches[1]
  end
  utilities.send_reply(msg, bitly_create:create_bitlink(long_url, domain, bitly_access_token))
  return
end

return bitly_create