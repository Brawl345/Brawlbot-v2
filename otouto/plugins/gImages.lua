 -- You need a Google API key and a Google Custom Search Engine set up to use this, in config.google_api_key and config.google_cse_key, respectively.
 -- You must also sign up for the CSE in the Google Developer Console, and enable image results.

local gImages = {}

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

function gImages:is_blacklisted(msg)
  _blacklist = redis:smembers("telegram:img_blacklist")
  local var = false
  for v,word in pairs(_blacklist) do
    if string.find(string.lower(msg), string.lower(word)) then
      print("Wort steht auf der Blacklist!")
      var = true
      break
    end
  end
  return var
end

-- Yes, the callback is copied from below, but I can't think of another method :\
function gImages:callback(callback, msg, self, config, input)
  if not msg then return end
  utilities.answer_callback_query(callback, 'Suche nochmal nach "'..URL.unescape(input)..'"')
  utilities.send_typing(msg.chat.id, 'upload_photo')
  local hash = 'telegram:cache:gImages'
  local results = redis:smembers(hash..':'..string.lower(URL.unescape(input)))
  
  if not results[1] then
    print('doing web request')
    results = gImages:get_image(input)
	if results == 403 then
	  utilities.send_reply(msg, config.errors.quotaexceeded, true)
	  return
    elseif not results then
      utilities.send_reply(msg, config.errors.results, true)
	  return
    end
    gImages:cache_result(results, input)
  end

  -- Random image from table
  local i = math.random(#results)
  
  -- Thanks to Amedeo for this!
  local failed = true
  local nofTries = 0
  
  while failed and nofTries < #results do
    if results[i].image then
      img_url = results[i].link
      mimetype = results[i].mime
      context = results[i].image.contextLink
    else -- from cache
      img_url = results[i]
	  mimetype = redis:hget(hash..':'..img_url, 'mime')
	  context = redis:hget(hash..':'..img_url, 'contextLink')
    end

    -- It's important to save the image with the right ending!
    if mimetype == 'image/gif' then
      file = download_to_file(img_url, 'img.gif')
    elseif mimetype == 'image/png' then
     file = download_to_file(img_url, 'img.png')
    elseif mimetype == 'image/jpeg' then
      file = download_to_file(img_url, 'img.jpg')
    else
      file = nil
    end
	
	if not file then
	  nofTries = nofTries + 1
	  i = i+1
	  if i > #results then
	    i = 1
	  end
	else
	  failed = false
	end

  end
  
  if failed then
    utilities.send_reply(msg, 'Fehler beim Herunterladen eines Bildes.', true)
	return
  end
  
  if mimetype == 'image/gif' then
    result = utilities.send_document(msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"@'..self.info.username..' gImages:'..input..'"}]]}')
  else
    result = utilities.send_photo(msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"@'..self.info.username..' gImages:'..input..'"}]]}')
  end

  if not result then
    utilities.send_reply(msg, config.errors.connection, true, '{"inline_keyboard":[[{"text":"Nochmal versuchen","callback_data":"@'..self.info.username..' gImages:'..input..'"}]]}')
	return
  end
end

function gImages:get_image(input)
  local apikey = cred_data.google_apikey -- 100 requests is RIDICULOUS, Google!
  local cseid = cred_data.google_cse_id
  local BASE_URL = 'https://www.googleapis.com/customsearch/v1'
  local url = BASE_URL..'/?searchType=image&alt=json&num=10&key='..apikey..'&cx='..cseid..'&safe=high'..'&q=' .. input .. '&fields=items(link,mime,image(contextLink))'
  local jstr, res = https.request(url)
  local jdat = json.decode(jstr).items
  
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
  
  return jdat
end

function gImages:cache_result(results, text)
  local cache = {}
  for v in pairs(results) do
    cache[v] = results[v].link
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
	  utilities.send_message(msg.chat.id, gImages.doc, true, msg.message_id, true)
	  return
	end
  end
  
  print ('Checking if search contains blacklisted word: '..input)
  if gImages:is_blacklisted(input) then
    utilities.send_reply(msg, 'Vergiss es! ._.')
	return
  end

  utilities.send_typing(msg.chat.id, 'upload_photo')

  local hash = 'telegram:cache:gImages'
  local results = redis:smembers(hash..':'..string.lower(input))
  
  if not results[1] then
    print('doing web request')
    results = gImages:get_image(URL.escape(input))
	if results == 403 then
	  utilities.send_reply(msg, config.errors.quotaexceeded, true)
	  return
    elseif not results or results == 'NORESULTS' then
      utilities.send_reply(msg, config.errors.results, true)
	  return
    end
    gImages:cache_result(results, input)
  end

  -- Random image from table
  local i = math.random(#results)
  
  -- Thanks to Amedeo for this!
  local failed = true
  local nofTries = 0
  
  while failed and nofTries < #results do
    if results[i].image then
      img_url = results[i].link
      mimetype = results[i].mime
      context = results[i].image.contextLink
    else -- from cache
      img_url = results[i]
	  mimetype = redis:hget(hash..':'..img_url, 'mime')
	  context = redis:hget(hash..':'..img_url, 'contextLink')
    end

    -- It's important to save the image with the right ending!
    if mimetype == 'image/gif' then
      file = download_to_file(img_url, 'img.gif')
    elseif mimetype == 'image/png' then
     file = download_to_file(img_url, 'img.png')
    elseif mimetype == 'image/jpeg' then
      file = download_to_file(img_url, 'img.jpg')
    else
      file = nil
    end
	
	if not file then
	  nofTries = nofTries + 1
	  i = i+1
	  if i > #results then
	    i = 1
	  end
	else
	  failed = false
	end

  end
  
  if failed then
    utilities.send_reply(msg, 'Fehler beim Herunterladen eines Bildes.', true)
	return
  end
  
  if mimetype == 'image/gif' then
    result = utilities.send_document(msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"@'..self.info.username..' gImages:'..URL.escape(input)..'"}]]}')
  else
    result = utilities.send_photo(msg.chat.id, file, nil, msg.message_id, '{"inline_keyboard":[[{"text":"Seite aufrufen","url":"'..context..'"},{"text":"Bild aufrufen","url":"'..img_url..'"},{"text":"Nochmal suchen","callback_data":"@'..self.info.username..' gImages:'..URL.escape(input)..'"}]]}')
  end

  if not result then
    utilities.send_reply(msg, config.errors.connection, true, '{"inline_keyboard":[[{"text":"Nochmal versuchen","callback_data":"@'..self.info.username..' gImages:'..URL.escape(input)..'"}]]}')
	return
  end
end

return gImages
