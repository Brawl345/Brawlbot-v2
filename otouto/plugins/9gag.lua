local ninegag = {}

local HTTP = require('socket.http')
local URL = require('socket.url')
local JSON = require('dkjson')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

ninegag.command = '9gag'

function ninegag:init(config)
	ninegag.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('9gag', true):t('9fag', true).table
	ninegag.inline_triggers = {
	  "^9gag"
	}
	ninegag.doc = [[*
]]..config.cmd_pat..[[9gag*: Gibt ein zufälliges Bild von den momentan populärsten 9GAG-Posts aus]]
end

local url = "http://api-9gag.herokuapp.com/"

function ninegag:get_9GAG()
  local b,c = HTTP.request(url)
  if c ~= 200 then return nil end
  local gag = JSON.decode(b)
  -- random max json table size
  local i = math.random(#gag)
  
  local link_image = gag[i].src
  local title = gag[i].title
  local post_url = gag[i].url
  return link_image, title, post_url
end

function ninegag:inline_callback(inline_query, config)
  local res, code = HTTP.request(url)
  if code ~= 200 then return end
  local gag = JSON.decode(res)
  
  local results = '['
  for n in pairs(gag) do
    local title = gag[n].title:gsub('"', '\\"')
    results = results..'{"type":"photo","id":"'..math.random(100000000000000000)..'","photo_url":"'..gag[n].src..'","thumb_url":"'..gag[n].src..'","caption":"'..title..'","reply_markup":{"inline_keyboard":[[{"text":"9GAG aufrufen","url":"'..gag[n].url..'"}]]}}'
	if n < #gag then
	 results = results..','
	end
  end
  local results = results..']'
  utilities.answer_inline_query(self, inline_query, results, 300)
end

function ninegag:action(msg, config)
  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  local url, title, post_url = ninegag:get_9GAG()
  if not url then
	utilities.send_reply(self, msg, config.errors.connection)
	return
  end

  local file = download_to_file(url)
  utilities.send_photo(self, msg.chat.id, file, title, msg.message_id, '{"inline_keyboard":[[{"text":"Post aufrufen","url":"'..post_url..'"}]]}')
end

return ninegag
