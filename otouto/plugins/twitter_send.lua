local twitter_send = {}

function twitter_send:init(config)
	if not cred_data.tw_consumer_key then
		print('Missing config value: tw_consumer_key.')
		print('twitter_send.lua will not be enabled.')
		return
	elseif not cred_data.tw_consumer_secret then
		print('Missing config value: tw_consumer_secret.')
		print('twitter_send.lua will not be enabled.')
		return
	end

    twitter_send.triggers = {
	  "^/tw (auth) (%d+)$",
	  "^/tw (unauth)$",
	  "^/tw (verify)$",
	  "^/tw (.+)$",
	  "^/(twwhitelist add) (%d+)$",
	  "^/(twwhitelist del) (%d+)$",
	  "^/(twwhitelist add)$",
	  "^/(twwhitelist del)$"
	}
	twitter_send.doc = [[*
]]..config.cmd_pat..[[tw* _<Text>_: Sendet einen Tweet an den Account, der im Chat angemeldet ist
*]]..config.cmd_pat..[[tw* _verify_: Gibt den angemeldeten User aus, inklusive Profilbild
*]]..config.cmd_pat..[[twwitelist* _add_ _<user>_: Schaltet User für die Tweet-Funktion frei
*]]..config.cmd_pat..[[twwitelist* _del_ _<user>_: Entfernt User von der Tweet-Whitelist
*]]..config.cmd_pat..[[tw* _auth_ _<PIN>_: Meldet mit dieser PIN an (Setup)
*]]..config.cmd_pat..[[tw* _unauth_: Meldet Twitter-Account ab
]]
end

twitter_send.command = 'tw <Tweet>'

local consumer_key = cred_data.tw_consumer_key
local consumer_secret = cred_data.tw_consumer_secret

function can_send_tweet(msg)
  local hash = 'user:'..msg.from.id
  local var = redis:hget(hash, 'can_send_tweet')
  if var == "true" then
    return true
  else
    return false
  end
end

local client = OAuth.new(consumer_key, consumer_secret, {
    RequestToken = "https://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "https://api.twitter.com/oauth/access_token"
}) 

function twitter_send:do_twitter_authorization_flow(hash, is_chat)
  local callback_url = "oob"
  local values = client:RequestToken({ oauth_callback = callback_url })
  local oauth_token = values.oauth_token
  local oauth_token_secret = values.oauth_token_secret
  
  -- save temporary oauth keys
  redis:hset(hash, 'oauth_token', oauth_token)
  redis:hset(hash, 'oauth_token_secret', oauth_token_secret)
  
  local auth_url = client:BuildAuthorizationUrl({ oauth_callback = callback_url, force_login = true })
  if is_chat then
    return 'Bitte schließe den Vorgang ab, indem du unten auf den attraktiven Button klickst und mir die angezeigte PIN per `/tw auth PIN` *in der Gruppe von gerade eben* übergibst.', auth_url
  else
    return 'Bitte schließe den Vorgang ab, indem du unten auf den attraktiven Button klickst und mir die angezeigte PIN per `/tw auth PIN` übergibst.', auth_url
  end
end

function twitter_send:get_twitter_access_token(hash, oauth_verifier, oauth_token, oauth_token_secret)
  local oauth_verifier = tostring(oauth_verifier)       -- must be a string

  -- now we'll use the tokens we got in the RequestToken call, plus our PIN
  local client = OAuth.new(consumer_key, consumer_secret, {
	RequestToken = "https://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "https://api.twitter.com/oauth/access_token"
  }, {
    OAuthToken = oauth_token,
    OAuthVerifier = oauth_verifier
  })
  client:SetTokenSecret(oauth_token_secret)

  local values, err, headers, status, body = client:GetAccessToken()
  if err then return 'Einloggen fehlgeschlagen!' end

  -- save permanent oauth keys
  redis:hset(hash, 'oauth_token', values.oauth_token)
  redis:hset(hash, 'oauth_token_secret', values.oauth_token_secret)
  
  local screen_name = values.screen_name
  
  return 'Erfolgreich eingeloggt als <a href="https://twitter.com/'..screen_name..'">@'..screen_name..'</a> (User-ID: '..values.user_id..')'
end

function twitter_send:reset_twitter_auth(hash, frominvalid)
  redis:hdel(hash, 'oauth_token')
  redis:hdel(hash, 'oauth_token_secret')
  if frominvalid then
    return '<b>Authentifizierung nicht erfolgreich, wird zurückgesetzt...</b>'
  else
    return '<b>Erfolgreich abgemeldet!</b> Entziehe den Zugriff endgültig in deinen <a href="https://twitter.com/settings/applications">Twitter-Einstellungen</a>!'
  end
end

function twitter_send:resolve_url(url)
  local response_body = {}
  local request_constructor = {
    url = url,
    method = "HEAD",
    sink = ltn12.sink.table(response_body),
    headers = {},
    redirect = false
  }

  local ok, response_code, response_headers, response_status_line = http.request(request_constructor)
  if ok and response_headers.location then
    return response_headers.location
  else
    return url
  end
end

function twitter_send:twitter_verify_credentials(oauth_token, oauth_token_secret)
  local client = OAuth.new(consumer_key, consumer_secret, {
    RequestToken = "https://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "https://api.twitter.com/oauth/access_token"
  }, {
    OAuthToken = oauth_token,
    OAuthTokenSecret = oauth_token_secret
  })

  local response_code, response_headers, response_status_line, response_body = 
  client:PerformRequest(
    "GET", "https://api.twitter.com/1.1/account/verify_credentials.json", {
      include_entities = false,
	  skip_status = true,
	  include_email = false
    }
  )

  local response = json.decode(response_body)
  if response_code == 401 then
    return twitter_send:reset_twitter_auth(hash, true)
  end
  if response_code ~= 200 then
    return 'HTTP-Fehler '..response_code..': '..data.errors[1].message
  end
  
  -- TODO: copied straight from the twitter_user plugin, maybe we can do it better?
  local full_name = response.name
  local user_name = response.screen_name
  if response.verified then
    user_name = user_name..' ✅'
  end
  if response.protected then
    user_name = user_name..' 🔒'
  end
  local header = full_name.. " (@" ..user_name.. ")\n"
  
  local description = unescape(response.description)
  if response.location then
    location = response.location
  else
    location = ''
  end
  if response.url and response.location ~= '' then
    url = ' | '..response.url..'\n'
  elseif response.url and response.location == '' then
    url = response.url..'\n'
  else
    url = '\n'
  end

  -- replace short url
  if response.entities.url then
    for k, v in pairs(response.entities.url.urls) do 
        local short = v.url
        local long = v.expanded_url
		local long = long:gsub('%%', '%%%%')
        url = url:gsub(short, long)
    end
  end
  
  local body = description..'\n'..location..url
  
  local favorites = comma_value(response.favourites_count)
  local follower = comma_value(response.followers_count)
  local following = comma_value(response.friends_count)
  local statuses = comma_value(response.statuses_count)
  local footer = statuses..' Tweets, '..follower..' Follower, '..following..' folge ich, '..favorites..' Tweets favorisiert'
  
  local text = 'Eingeloggter Account:\n'..header..body..footer
  local pp_url = string.gsub(response.profile_image_url_https, "normal", "400x400")
  
  return text, pp_url
end

function twitter_send:send_tweet(tweet, oauth_token, oauth_token_secret, hash)
  local client = OAuth.new(consumer_key, consumer_secret, {
    RequestToken = "https://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "https://api.twitter.com/oauth/access_token"
  }, {
    OAuthToken = oauth_token,
    OAuthTokenSecret = oauth_token_secret
  })

  local response_code, response_headers, response_status_line, response_body = 
  client:PerformRequest(
    "POST", "https://api.twitter.com/1.1/statuses/update.json", {
      status = tweet
    }
  )

  local data = json.decode(response_body)
  if response_code == 401 then
    return twitter_send:reset_twitter_auth(hash, true)
  end
  if response_code ~= 200 then
    return 'HTTP-Fehler '..response_code..': '..data.errors[1].message
  end
  
  local statusnumber = comma_value(data.user.statuses_count)
  local screen_name = data.user.screen_name
  local status_id = data.id_str 

  return '<a href="https://twitter.com/'..screen_name..'/status/'..status_id..'">Tweet #'..statusnumber..' gesendet!</a>'
end

function twitter_send:add_to_twitter_whitelist(user_id)
  local hash = 'user:'..user_id
  local whitelisted = redis:hget(hash, 'can_send_tweet')
  if whitelisted ~= 'true' then
    print('Setting can_send_tweet in redis hash '..hash..' to true')
    redis:hset(hash, 'can_send_tweet', true)
    return '*User '..user_id..' kann jetzt Tweets senden!*'
  else
    return '*User '..user_id..' kann schon Tweets senden.*'
  end
end

function twitter_send:del_from_twitter_whitelist(user_id)
  local hash = 'user:'..user_id
  local whitelisted = redis:hget(hash, 'can_send_tweet')
  if whitelisted == 'true' then
    print('Setting can_send_tweet in redis hash '..hash..' to false')
    redis:hset(hash, 'can_send_tweet', false)
    return '*User '..user_id..' kann jetzt keine Tweets mehr senden!*'
  else
    return '*User '..user_id..' ist nicht whitelisted.*'
  end
end

function twitter_send:action(msg, config, matches)
  if matches[1] == "twwhitelist add" then
    if not is_sudo(msg, config) then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    else
	  local user_id = matches[2]
	  if not user_id then
	    if not msg.reply_to_message then
	      return
		end
	    user_id = msg.reply_to_message.from.id
	  end  
	  utilities.send_reply(msg, twitter_send:add_to_twitter_whitelist(user_id), true)
      return
    end
  end

  if matches[1] == "twwhitelist del" then
    if not is_sudo(msg, config) then
      utilities.send_reply(msg, config.errors.sudo)
	  return
    else
	  local user_id = matches[2]
	  if not user_id then
	    if not msg.reply_to_message then
	      return
		end
	    user_id = msg.reply_to_message.from.id
	  end
	  utilities.send_reply(msg, twitter_send:del_from_twitter_whitelist(user_id), true)
      return
    end
  end
  
  local hash = get_redis_hash(msg, 'twitter')
  local oauth_token = redis:hget(hash, 'oauth_token')
  local oauth_token_secret = redis:hget(hash, 'oauth_token_secret')
  
  -- Thanks to the great doc at https://github.com/ignacio/LuaOAuth#a-more-involved-example
  if not oauth_token and not oauth_token_secret then
    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
	  if not is_sudo(msg, config) then
        utilities.send_reply(msg, config.errors.sudo)
	    return
      else
        local text, auth_url = twitter_send:do_twitter_authorization_flow(hash, true)
		local res = utilities.send_message(msg.from.id, text, true, nil, true, '{"inline_keyboard":[[{"text":"Bei Twitter anmelden","url":"'..auth_url..'"}]]}')
		if not res then
			utilities.send_reply(msg, 'Bitte starte mich zuerst [privat](http://telegram.me/' .. self.info.username .. '?start).', true)
		elseif msg.chat.type ~= 'private' then
			local result = utilities.send_message(msg.chat.id, '_Bitte warten, der Administrator meldet sich an..._', true, nil, true)
			redis:hset(hash, 'login_msg', result.result.message_id)
		end
		return
	  end
    else
	  local text, auth_url = twitter_send:do_twitter_authorization_flow(hash)
	  local result = utilities.send_reply(msg, text, true, '{"inline_keyboard":[[{"text":"Bei Twitter anmelden","url":"'..auth_url..'"}]]}')
	  redis:hset(hash, 'login_msg', result.result.message_id)
	  return
	end
  end

  if matches[1] == 'auth' and matches[2] then
    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
      if not is_sudo(msg, config) then
        utilities.send_reply(msg, config.errors.sudo)
	    return
      end
	end
    if string.len(matches[2]) > 7 then utilities.send_reply(msg, 'Invalide PIN!') return end
	utilities.send_reply(msg, twitter_send:get_twitter_access_token(hash, matches[2], oauth_token, oauth_token_secret), 'HTML')
	local message_id = redis:hget(hash, 'login_msg')
	utilities.edit_message(msg.chat.id, message_id, '*Anmeldung abgeschlossen!*', true, true)
	redis:hdel(hash, 'login_msg')
	return
  end
  
  if matches[1] == 'unauth' then
    if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
      if not is_sudo(msg, config) then
        utilities.send_reply(msg, config.errors.sudo)
	    return
      end
	end
	utilities.send_reply(msg, twitter_send:reset_twitter_auth(hash), 'HTML')
	return
  end
  
  if matches[1] == 'verify' then
    local text, pp_url = twitter_send:twitter_verify_credentials(oauth_token, oauth_token_secret)
	utilities.send_photo(msg.chat.id, pp_url, nil, msg.message_id)
	utilities.send_reply(msg, text)
	return
  end
  
  
  if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
    if not can_send_tweet(msg) and not is_sudo(msg, config) then
	  utilities.send_reply(msg, '*Du darfst keine Tweets senden.* Entweder wurdest du noch gar nicht freigeschaltet oder ausgeschlossen.', true)
	  return 
	else
	  utilities.send_reply(msg, twitter_send:send_tweet(matches[1], oauth_token, oauth_token_secret, hash), 'HTML')
	  return
	end
  else
    utilities.send_reply(msg, twitter_send:send_tweet(matches[1], oauth_token, oauth_token_secret, hash), 'HTML')
	return
  end
end

return twitter_send