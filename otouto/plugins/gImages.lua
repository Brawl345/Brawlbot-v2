 -- You need a Google API key and a Google Custom Search Engine set up to use this, in config.google_api_key and config.google_cse_key, respectively.
 -- You must also sign up for the CSE in the Google Developer Console, and enable image results.

local gImages = {}

local HTTPS = require('ssl.https')
local URL = require('socket.url')
local JSON = require('dkjson')
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

	gImages.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('img', true):t('i', true):t('insfw', true).table
	gImages.doc = [[```
]]..config.cmd_pat..[[img <Suchbegriff>
Sucht Bild mit Google und versendet es (SafeSearch aktiv)
Alias: ]]..config.cmd_pat..[[i
```]]
end

gImages.command = 'img <Suchbegriff>'

function gImages:action(msg, config)
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
  local apikey = cred_data.google_apikey
  local cseid = cred_data.google_cse_id
  local BASE_URL = 'https://www.googleapis.com/customsearch/v1'
  local url = BASE_URL..'/?searchType=image&alt=json&num=10&key='..apikey..'&cx='..cseid..'&safe=high'..'&q=' .. URL.escape(input)
  local jstr, res = HTTPS.request(url)
  
  if res ~= 200 then
    utilities.send_reply(self, msg, config.errors.connection)
    return
  end
  
  local jdat = JSON.decode(jstr)
  if jdat.searchInformation.totalResults == '0' then
	utilities.send_reply(self, msg, config.errors.results)
    return
  end

  local i = math.random(jdat.queries.request[1].count)
  local img_url = jdat.items[i].link
  
  local file = download_to_file(img_url)
  utilities.send_photo(self, msg.chat.id, file, img_url)
end

return gImages
