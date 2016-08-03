local echo = {}

echo.command = 'echo <Text>'

function echo:init(config)
	echo.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('echo', true).table
	echo.inline_triggers = {
	  "^e (.+)",
	  "^bold (.+)"
	}
	echo.doc = [[*
]]..config.cmd_pat..[[echo* _<Text>_: Gibt den Text aus]]
end

function echo:inline_callback(inline_query, config, matches)
  local text = matches[1]
  local results = '['

  -- enable custom markdown button
  if text:match('%[.*%]%(.*%)') or text:match('%*.*%*') or text:match('_.*_') or text:match('`.*`') then
    results = results..'{"type":"article","id":"'..math.random(100000000000000000)..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/echo/custom.jpg","title":"Eigenes Markdown","description":"'..text..'","input_message_content":{"message_text":"'..text..'","parse_mode":"Markdown"}},'
  end

  local results = results..'{"type":"article","id":"'..math.random(100000000000000000)..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/echo/fett.jpg","title":"Fett","description":"*'..text..'*","input_message_content":{"message_text":"*'..text..'*","parse_mode":"Markdown"}},{"type":"article","id":"'..math.random(100000000000000000)..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/echo/kursiv.jpg","title":"Kursiv","description":"_'..text..'_","input_message_content":{"message_text":"_'..text..'_","parse_mode":"Markdown"}},{"type":"article","id":"'..math.random(100000000000000000)..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/echo/fixedsys.jpg","title":"Feste Breite","description":"`'..text..'`","input_message_content":{"message_text":"`'..text..'`","parse_mode":"Markdown"}}]'
  utilities.answer_inline_query(self, inline_query, results, 0)
end

function echo:action(msg)
  local input = utilities.input(msg.text)
  if not input then
	utilities.send_message(self, msg.chat.id, echo.doc, true, msg.message_id, true)
  else
	local output
	if msg.chat.type == 'supergroup' then
	  output = '*Echo:*\n"' .. utilities.md_escape(input) .. '"'
	  utilities.send_message(self, msg.chat.id, output, true, nil, true)
	  return 
	end
  utilities.send_message(self, msg.chat.id, input, true, nil, true)
  end
end

return echo
