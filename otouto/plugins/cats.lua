local cats = {}

local HTTP = require('socket.http')
local utilities = require('otouto.utilities')

cats.command = 'cat [gif]'

function cats:init(config)
	if not cred_data.cat_apikey then
		print('Missing config value: cat_apikey.')
		print('cats.lua will be enabled, but there are more features with a key.')
	end

	cats.triggers = {
      "^/cat$",
	  "^/cat (gif)$"
	}
	
	cats.doc = [[*
]]..config.cmd_pat..[[cat*: Postet eine zufällige Katze
*]]..config.cmd_pat..[[cat* _gif_: Postet eine zufällige, animierte Katze]]
end


local apikey = cred_data.cat_apikey or "" -- apply for one here: http://thecatapi.com/api-key-registration.html

function cats:action(msg, config)
  if matches[1] == 'gif' then
    local url = 'http://thecatapi.com/api/images/get?type=gif&apikey='..apikey
	local file = download_to_file(url, 'miau.gif')
    utilities.send_document(self, msg.chat.id, file, nil, msg.message_id)
  else
    local url = 'http://thecatapi.com/api/images/get?type=jpg,png&apikey='..apikey
	local file = download_to_file(url, 'miau.png')
    utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
  end
end

return cats
