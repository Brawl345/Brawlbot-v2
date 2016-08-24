local tex = {}

tex.command = 'tex <LaTeX>'

function tex:init(config)
	tex.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('tex', true).table
	tex.doc = [[*
]]..config.cmd_pat..[[tex* _<LaTeX>_: Konvertiert LaTeX in ein Bild]]
end

function tex:action(msg, config)
  local input = utilities.input(msg.text)
  if not input then
    if msg.reply_to_message and msg.reply_to_message.text then
      input = msg.reply_to_message.text
    else
	  utilities.send_message(msg.chat.id, tex.doc, true, msg.message_id, true)
	  return
	end
  end

  utilities.send_typing(msg.chat.id, 'upload_photo')
  local eq = URL.escape(input)

  local url = "http://latex.codecogs.com/png.download?"
    .."\\dpi{300}%20\\LARGE%20"..eq
  local file = download_to_file(url, 'latex.png')
  utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
end

return tex
