local preview = {}

preview.command = 'preview <link>'

function preview:init(config)
	preview.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('preview', true).table
	preview.inline_triggers = {
	  "^pr (https?://[%w-_%.%?%.:/%+=&%~%%#]+)$"
	}
	preview.doc = [[*
]]..config.cmd_pat..[[preview* _<URL>_
Erstellt einen Preview-Link]]
end

function preview:inline_callback(inline_query, config, matches)
  local preview_url = matches[1]
  local res, code = https.request('https://brawlbot.tk/apis/simple_meta_api/?url='..URL.escape(preview_url))
  if code ~= 200 then utilities.answer_inline_query(self, inline_query) return end
  local data = json.decode(res)
  if data.remote_code >= 400 then utilities.answer_inline_query(self, inline_query) return end
  
  if data.title then
    title = data.title
  else
    title = 'Kein Titel'
  end
  
  if data.description then
    description = data.description
	description_in_text = '\n'..description
  else
	description_in_text = ''
    description = 'Keine Beschreibung verfügbar'
  end

  if data.only_name then
    only_name = data.only_name
  else
    only_name = preview_url:match('^%w+://([^/]+)') -- we only need the domain
  end
  
  local message_text = '<b>'..title..'</b>'..description_in_text..'\n— '..only_name

  local results = '[{"type":"article","id":"77","title":"'..title..'","description":"'..description..'","url":"'..preview_url..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/generic/internet.jpg","thumb_width":150,"thumb_height":150,"hide_url":true,"reply_markup":{"inline_keyboard":[[{"text":"Webseite aufrufen","url":"'..preview_url..'"}]]},"input_message_content":{"message_text":"'..message_text..'","parse_mode":"HTML","disable_web_page_preview":true}}]'
  utilities.answer_inline_query(self, inline_query, results, 3600, true)
end

function preview:action(msg)
  local input = utilities.input_from_msg(msg)
  if not input then
	utilities.send_reply(self, msg, preview.doc, true)
	return
  end

  input = utilities.get_word(input, 1)
  if not input:match('^https?://.+') then
	input = 'http://' .. input
  end

  local res = http.request(input)
  if not res then
	utilities.send_reply(self, msg, 'Bitte gebe einen validen Link an.')
	return
  end

  if res:len() == 0 then
	utilities.send_reply(self, msg, 'Sorry, dieser Link lässt uns keine Vorschau erstellen.')
	return
  end

  -- Invisible zero-width, non-joiner.
  local output = '<a href="' .. input .. '">' .. utilities.char.zwnj .. '</a>'
  utilities.send_message(self, msg.chat.id, output, false, nil, 'HTML')
end

return preview