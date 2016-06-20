local webshot = {}

local helpers = require('OAuth.helpers')
local utilities = require('otouto.utilities')
local https = require('ssl.https')
local ltn12 = require('ltn12')
local json = require('dkjson')
local bindings = require('otouto.bindings')

local base = 'https://screenshotmachine.com/'
local url = base .. 'processor.php'

function webshot:init(config)
	webshot.triggers = {
    "^/webshot ([T|t|S|s|E|e|N|n|M|m|L|l|X|x|F|f]) ([%w-_%.%?%.:,/%+=&#!]+)$",
	"^/scrot ([T|t|S|s|E|e|N|n|M|m|L|l|X|x|F|f]) ([%w-_%.%?%.:,/%+=&#!]+)$",
    "^/webshot ([%w-_%.%?%.:,/%+=&#!]+)$",
	"^/scrot ([%w-_%.%?%.:,/%+=&#!]+)$"
	}
	webshot.doc = [[*
]]..config.cmd_pat..[[scrot* _<URL>_: Fertigt Bild mit Größe 1024x768 (X) an
*]]..config.cmd_pat..[[scrot* _[T|S|E|N|M|L|X|F]_ _<URL>_: Fertigt Bild mit bestimmter Größe an (T = tiny, F = full)]]
end

webshot.command = 'scrot [T|S|E|N|M|L|X|F] <URL>'

function webshot:get_webshot_url(param, size)
   local response_body = {}
   local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body),
      headers = {
         referer = base,
         dnt = "1",
         origin = base,
         ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.41 Safari/537.36"
      },
      redirect = false
   }

   local arguments = {
      urlparam = param,
      size = size,
	  cacheLimit = "0"
   }

   request_constructor.url = url .. "?" .. helpers.url_encode_arguments(arguments)

   local ok, response_code, response_headers, response_status_line = https.request(request_constructor)
   if not ok or response_code ~= 200 then
      return nil
   end

   local response = table.concat(response_body)
   return string.match(response, "href='(.-)'")
end

function webshot:action(msg, config, matches)
   if not matches[2] then
     webshot_url = matches[1]
	 size = "X"
   else
     webshot_url = matches[2]
	 size = string.upper(matches[1])
   end
   utilities.send_typing(self, msg.chat.id, 'upload_photo')
   local find = webshot:get_webshot_url(webshot_url, size)
   if find then
      local imgurl = base .. find
	  local file = download_to_file(imgurl)
	  if size == "F" then
	    utilities.send_document(self, msg.chat.id, file, nil, msg.message_id)
		return
	  else
        utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
	  end
   else
     utilities.send_reply(self, msg, config.errors.connection)
   end
end

return webshot