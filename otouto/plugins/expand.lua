local expand = {}

local http = require('socket.http')
local utilities = require('otouto.utilities')

function expand:init(config)
  expand.triggers = {
    "^/expand (https?://[%w-_%.%?%.:/%+=&]+)$"
  }

  expand.doc = [[*
]]..config.cmd_pat..[[expand* _<Kurz-URL>_: Verlängert Kurz-URL (301er/302er)]]
end

expand.command = 'expand <Kurz-URL>'

function expand:action(msg, config, matches)
   local response_body = {}
   local request_constructor = {
      url = matches[1],
      method = "HEAD",
      sink = ltn12.sink.table(response_body),
      headers = {},
      redirect = false
   }

   local ok, response_code, response_headers, response_status_line = http.request(request_constructor)
   if ok and response_headers.location then
      utilities.send_reply(self, msg, response_headers.location)
      return
   else
      utilities.send_reply(self, msg, "Fehler beim Erweitern der URL.")
      return
   end
end

return expand
