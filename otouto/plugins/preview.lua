local preview = {}

preview.command = 'preview <link>'

function preview:init(config)
	preview.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('preview', true).table
	preview.doc = [[```
]]..config.cmd_pat..[[preview <link>
Returns a full-message, "unlinked" preview.
```]]
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