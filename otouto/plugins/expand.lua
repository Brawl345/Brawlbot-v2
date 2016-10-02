local expand = {}

function expand:init(config)
  expand.triggers = {
    "^/expand (https?://[%w-_%.%?%.:/%+=&]+)$"
  }
  expand.inline_triggers = {
    "^ex (https?://[%w-_%.%?%.:/%+=&]+)$"
  }

  expand.doc = [[*
]]..config.cmd_pat..[[expand* _<Kurz-URL>_: Verlängert Kurz-URL (301er/302er)]]
end

expand.command = 'expand <Kurz-URL>'

function expand:inline_callback(inline_query, config, matches)
  local ok, response_headers = expand:url(matches[1])
  if not response_headers.location then 
    title = 'Konnte nicht erweitern'
    url = matches[1]
	description = 'Sende stattdessen die kurze URL'
  else
    title = 'Verlängerte URL'
    url = response_headers.location
	description = url
  end
  
  local results = '[{"type":"article","id":"7","title":"'..title..'","description":"'..description..'","url":"'..url..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/generic/internet.jpg","thumb_width":165,"thumb_height":150,"hide_url":true,"input_message_content":{"message_text":"'..url..'"}}]'
  utilities.answer_inline_query(inline_query, results, 3600)
end

function expand:url(long_url)
   local request_constructor = {
      url = long_url,
      method = "HEAD",
      sink = ltn12.sink.null(),
      redirect = false
   }

   local ok, response_code, response_headers = http.request(request_constructor)
   return ok, response_headers
end

function expand:action(msg, config, matches)
   local ok, response_headers = expand:url(matches[1])
   if ok and response_headers.location then
      utilities.send_reply(msg, response_headers.location)
      return
   else
      utilities.send_reply(msg, "Fehler beim Erweitern der URL.")
      return
   end
end

return expand
