local xkcd = {}

local http = require('socket.http')
local json = require('dkjson')
local utilities = require('otouto.utilities')

xkcd.command = 'xkcd [i]'

function xkcd:init(config)
  xkcd.triggers = {
	"^/xkcd (%d+)",
	"xkcd.com/(%d+)"
  }
  xkcd.doc = [[*
]]..config.cmd_pat..[[xkcd* _[i]_: Gibt diesen XKCD-Comic aus]]
end

function xkcd:get_xkcd(id)
  local res,code  = http.request("http://xkcd.com/"..id.."/info.0.json")
  if code ~= 200 then return nil end
  local data = json.decode(res)
  local link_image = data.img
  if link_image:sub(0,2) == '//' then
    link_image = link_image:sub(3,-1)
  end
  return link_image, data.title, data.alt
end

function xkcd:action(msg, config)
  local url, title, alt = xkcd:get_xkcd(matches[1])
  if not url then utilities.send_reply(self, msg, config.errors.connection) return end
  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  local file = download_to_file(url)
  utilities.send_photo(self, msg.chat.id, file, title..'\n'..alt, msg.message_id)
end

return xkcd
