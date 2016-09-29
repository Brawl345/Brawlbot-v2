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

local api_key = cred_data.iframely_api_key

function preview:inline_callback(inline_query, config, matches)
  local preview_url = matches[1]
  local res, code = https.request('https://iframe.ly/api/oembed?url='..URL.escape(preview_url)..'&api_key='..api_key)
  if code ~= 200 then abort_inline_query(inline_query) return end
  local data = json.decode(res)
  
  if data.title then
    title = data.title:gsub('"', '\\"')
  else
    title = 'Kein Titel'
  end
  
  if data.description then
    description = data.description:gsub('"', '\\"')
	description_in_text = '\n'..description
  else
	description_in_text = ''
    description = 'Keine Beschreibung verfügbar'
  end

  if data.provider_name then
    provider_name = data.provider_name:gsub('"', '\\"')
  else
    provider_name = preview_url:match('^%w+://([^/]+)') -- we only need the domain
  end
  
  if data.thumbnail_url then
    thumb = data.thumbnail_url
    width = data.thumbnail_width
    height = data.thumbnail_height
  else
    thumb = 'https://anditest.perseus.uberspace.de/inlineQuerys/generic/internet.jpg'
    width = 150
    height = 150
  end
  
  local message_text = '<b>'..title..'</b>'..description_in_text..'\n<i>- '..provider_name..'</i>'

  local results = '[{"type":"article","id":"77","title":"'..title..'","description":"'..description..'","url":"'..preview_url..'","thumb_url":"'..thumb..'","thumb_width":'..width..',"thumb_height":'..height..',"hide_url":true,"reply_markup":{"inline_keyboard":[[{"text":"Webseite aufrufen","url":"'..preview_url..'"}]]},"input_message_content":{"message_text":"'..message_text..'","parse_mode":"HTML","disable_web_page_preview":true}}]'
  utilities.answer_inline_query(inline_query, results, data.cache_age)
end

function preview:action(msg)
  local input = utilities.input_from_msg(msg)
  if not input then
	utilities.send_reply(msg, preview.doc, true)
	return
  end

  input = utilities.get_word(input, 1)
  if not input:match('^https?://.+') then
	input = 'http://' .. input
  end

  local res = http.request(input)
  if not res then
	utilities.send_reply(msg, 'Bitte gebe einen validen Link an.')
	return
  end

  if res:len() == 0 then
	utilities.send_reply(msg, 'Sorry, dieser Link lässt uns keine Vorschau erstellen.')
	return
  end

  -- Invisible zero-width, non-joiner.
  local output = '<a href="' .. input .. '">' .. utilities.char.zwnj .. '</a>'
  utilities.send_message(msg.chat.id, output, false, nil, 'HTML')
end

return preview