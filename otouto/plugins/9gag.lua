local ninegag = {}

local HTTP = require('socket.http')
local URL = require('socket.url')
local JSON = require('dkjson')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

ninegag.command = '9gag'

function ninegag:init(config)
	ninegag.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('9gag', true):t('9fag', true).table
	ninegag.doc = [[*
]]..config.cmd_pat..[[9gag*: Gibt ein zufälliges Bild von den momentan populärsten 9GAG-Posts aus]]
end

function ninegag:get_9GAG()
  local url = "http://api-9gag.herokuapp.com/"
  local b,c = HTTP.request(url)
  if c ~= 200 then return nil end
  local gag = JSON.decode(b)
  -- random max json table size
  local i = math.random(#gag)  local link_image = gag[i].src
  local title = gag[i].title
  return link_image, title, post_url
end

function ninegag:action(msg, config)
  local url, title = ninegag:get_9GAG()
  if not url then
	utilities.send_reply(self, msg, config.errors.connection)
	return
  end

  local file = download_to_file(url)
  bindings.sendPhoto(self, {chat_id = msg.chat.id, caption = title}, {photo = file} )
  os.remove(file)
  print("Deleted: "..file)
end

return ninegag
