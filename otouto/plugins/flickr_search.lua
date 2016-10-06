local flickr_search = {}

function flickr_search:init(config)
	if not cred_data.flickr_apikey then
		print('Missing config value: flickr_apikey.')
		print('flickr_search.lua will not be enabled.')
		return
	end

  flickr_search.triggers = {
	"^/flickr (.+)$"
  }
end

flickr_search.command = 'flickr <Suchbegriff>'

local apikey = cred_data.flickr_apikey
local BASE_URL = 'https://api.flickr.com/services/rest'

function flickr_search:get_flickr(term)
  local url = BASE_URL..'/?method=flickr.photos.search&api_key='..apikey..'&format=json&nojsoncallback=1&privacy_filter=1&safe_search=3&media=photos&sort=relevance&is_common=true&per_page=20&extras=url_l,url_o&text='..term
  local b,c = https.request(url)
  if c ~= 200 then return nil end
  local photo = json.decode(b).photos.photo
  if not photo[1] then return nil end

  -- truly randomize
  math.randomseed(os.time())
  -- random max json table size
  local i = math.random(#photo)

  local link_image = photo[i].url_l or photo[i].url_o
  local orig_image = photo[i].url_o or link_image
  local title = photo[i].title
  if title:len() > 200 then
    title = title:sub(1, 197) .. '...'
  end

  return link_image, title, orig_image
end

function flickr_search:callback(callback, msg, self, config, input)
  utilities.send_typing(msg.chat.id, 'upload_photo')
  local input = URL.unescape(input)
  utilities.answer_callback_query(callback, 'Suche nochmal nach "'..input..'"')
  local url, title, orig = flickr_search:get_flickr(input)

  if not url then utilities.answer_callback_query(callback, 'Konnte nicht mit Flickr verbinden :(', true) return end

  if string.ends(url, ".gif") then
    utilities.send_document(msg.chat.id, url, title, msg.message_id, '{"inline_keyboard":[[{"text":"Im Browser öffnen","url":"'..orig..'"},{"text":"Nochmal suchen","callback_data":"flickr_search:'..URL.escape(input)..'"}]]}')
	return
  else
    utilities.send_photo(msg.chat.id, url, title, msg.message_id, '{"inline_keyboard":[[{"text":"Bild öffnen","url":"'..orig..'"}, {"text":"Nochmal suchen","callback_data":"flickr_search:'..URL.escape(input)..'"}]]}')
	return
  end
end

function flickr_search:action(msg, config, matches)
  utilities.send_typing(msg.chat.id, 'upload_photo')
  local url, title, orig = flickr_search:get_flickr(matches[1])
  if not url then utilities.send_reply(msg, config.errors.results) return end

  if string.ends(url, ".gif") then
    utilities.send_document(msg.chat.id, url, title, msg.message_id, '{"inline_keyboard":[[{"text":"Im Browser öffnen","url":"'..orig..'"},{"text":"Nochmal suchen","callback_data":"flickr_search:'..URL.escape(matches[1])..'"}]]}')
	return
  else
    utilities.send_photo(msg.chat.id, url, title, msg.message_id, '{"inline_keyboard":[[{"text":"Bild öffnen","url":"'..orig..'"}, {"text":"Nochmal suchen","callback_data":"flickr_search:'..URL.escape(matches[1])..'"}]]}')
	return
  end
end

return flickr_search