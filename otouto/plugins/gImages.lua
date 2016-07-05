 -- You need a Google API key and a Google Custom Search Engine set up to use this, in config.google_api_key and config.google_cse_key, respectively.
 -- You must also sign up for the CSE in the Google Developer Console, and enable image results.

local gImages = {}

local HTTPS = require('ssl.https')
local URL = require('socket.url')
local JSON = require('dkjson')
local redis = (loadfile "./otouto/redis.lua")()
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

function gImages:init(config)
	if not cred_data.google_apikey then
		print('Missing config value: google_apikey.')
		print('gImages.lua will not be enabled.')
		return
	elseif not cred_data.google_cse_id then
		print('Missing config value: google_cse_id.')
		print('gImages.lua will not be enabled.')
		return
	end

	gImages.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('img', true):t('i', true).table
	gImages.doc = [[*
]]..config.cmd_pat..[[img* _<Suchbegriff>_
Sucht Bild mit Google und versendet es (SafeSearch aktiv)
Alias: *]]..config.cmd_pat..[[i*]]
end

gImages.command = 'img <Suchbegriff>'

function gImages:callback(callback, msg, self, config, input)
  if not msg then return end
  utilities.answer_callback_query(self, callback, 'Suche nochmal nach "'..URL.unescape(input)..'"')
  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  local img_url, mimetype, context = gImages:get_image(input)
  if img_url == 403 then
    utilities.send_reply(self, msg, config.errors.quotaexceeded, true)
	return
  elseif img_url == 'NORESULTS' then
    utilities.send_reply(self, msg, config.errors.results, true)
    return
  elseif not img_url then
    utilities.send_reply(self, msg, config.errors.connection, true)
	return
  end

  if mimetype == 'image/gif' then
    local file = download_to_file(img_url, 'img.gif')
    result = utilities.send_document(self, msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"gImages:'..input..'"}]]}')
  elseif mimetype == 'image/png' then
    local file = download_to_file(img_url, 'img.png')
    result = utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"gImages:'..input..'"}]]}')
  elseif mimetype == 'image/jpeg' then
    local file = download_to_file(img_url, 'img.jpg')
    result = utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"gImages:'..input..'"}]]}')
  end

  if not result then
    utilities.send_reply(self, msg, config.errors.connection, true, '{"inline_keyboard":[[{"text":"Nochmal versuchen","callback_data":"gImages:'..input..'"}]]}')
	return
  end
end

function gImages:get_image(input)
  local hash = 'telegram:cache:gImages'
  local results = redis:smembers(hash..':'..string.lower(input))
  if results[1] then
    print('getting image from cache')
    local i = math.random(#results)
    local img_url = results[i]
	local mime = redis:hget(hash..':'..img_url, 'mime')
	local contextLink = redis:hget(hash..':'..img_url, 'contextLink')
	return img_url, mime, contextLink
  end

  local apikey = cred_data.google_apikey_2 -- 100 requests is RIDICULOUS, Google!
  local cseid = cred_data.google_cse_id_2
  local BASE_URL = 'https://www.googleapis.com/customsearch/v1'
  local url = BASE_URL..'/?searchType=image&alt=json&num=10&key='..apikey..'&cx='..cseid..'&safe=high'..'&q=' .. input .. '&fields=items(link,mime,image(contextLink))'
  local jstr, res = HTTPS.request(url)
  local jdat = JSON.decode(jstr).items
  
  if not jdat then
	return 'NORESULTS'
  end

  if jdat.error then
    if jdat.error.code == 403 then
	  return 403
    else
	  return false
	end
  end
  
  gImages:cache_result(jdat, input)
  local i = math.random(#jdat)
  return jdat[i].link, jdat[i].mime, jdat[i].image.contextLink
end

function gImages:cache_result(results, text)
  local cache = {}
  for v in pairs(results) do
    table.insert(cache, results[v].link)
  end
  for n, link in pairs(cache) do
   redis:hset('telegram:cache:gImages:'..link, 'mime', results[n].mime)
   redis:hset('telegram:cache:gImages:'..link, 'contextLink', results[n].image.contextLink)
   redis:expire('telegram:cache:gImages:'..link, 1209600)
  end
  cache_data('gImages', string.lower(text), cache, 1209600, 'set')
end

function gImages:action(msg, config, matches)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(self, msg.chat.id, gImages.doc, true, msg.message_id, true)
	  return
	end
  end
  
  print ('Checking if search contains blacklisted word: '..input)
  if is_blacklisted(input) then
    utilities.send_reply(self, msg, 'Vergiss es! ._.')
	return
  end

  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  local img_url, mimetype, context = gImages:get_image(URL.escape(input))
  if img_url == 403 then
    utilities.send_reply(self, msg, config.errors.quotaexceeded, true)
	return
  elseif img_url == 'NORESULTS' then
    utilities.send_reply(self, msg, config.errors.results, true)
    return
  elseif not img_url then
    utilities.send_reply(self, msg, config.errors.connection, true)
	return
  end
  
  if mimetype == 'image/gif' then
    local file = download_to_file(img_url, 'img.gif')
    result = utilities.send_document(self, msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"}],[{"text":"Nochmal suchen","callback_data":"gImages:'..URL.escape(input)..'"}]]}')
  elseif mimetype == 'image/png' then
    local file = download_to_file(img_url, 'img.png')
    result = utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"gImages:'..URL.escape(input)..'"}]]}')
  elseif mimetype == 'image/jpeg' then
    local file = download_to_file(img_url, 'img.jpg')
    result = utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"gImages:'..URL.escape(input)..'"}]]}')
  end

  if not result then
    utilities.send_reply(self, msg, config.errors.connection, true, '{"inline_keyboard":[[{"text":"Nochmal versuchen","callback_data":"gImages:'..URL.escape(input)..'"}]]}')
	return
  end
end

return gImages
