local channel = {}

channel.command = 'ch <Kanal> \\n <Nachricht>'
channel.doc = [[*
/ch*_ <Kanal>_|_[Inline-Keyboard]_
_<Nachricht>_

Sendet eine Nachricht in den Kanal. Der Kanal kann per Username oder ID bestimmt werden, Markdown wird unterstützt. Du musst Administrator oder Besitzer des Kanals sein.
 
Inline-Keyboards sind OPTIONAL, in dem Falle einfach den Strich weglassen. Es werden NUR URL-Buttons unterstützt! Eine Beispielsyntax für einen Button findest du [auf GitHub](https://gist.githubusercontent.com/Brawl345/e671b60e24243da81934/raw/Inline-Keyboard.json).
 
*Der Kanalname muss mit einem @ beginnen!*]]

function channel:init(config)
    channel.triggers = {
	  "^/ch @([A-Za-z0-9-_-]+)|(.+)\n(.*)",
	  "^/ch @([A-Za-z0-9-_-]+)\n(.*)"
	}
end

function channel:action(msg, config)
  local input = utilities.input(msg.text)
  local output
  local chat_id = '@'..matches[1]
  local admin_list, gca_results = utilities.get_chat_administrators(chat_id)

  if admin_list then
	local is_admin = false
	for _, admin in ipairs(admin_list.result) do
	  if admin.user.id == msg.from.id then
		is_admin = true
	  end
	end
	if is_admin then
	  if matches[3] then
	    text = matches[3]
		reply_markup = matches[2]
		-- Yeah, channels don't allow this buttons currently, but when they're ready
		-- this plugin will also be ready :P
		-- Also, URL buttons work!? Maybe beta?
		if reply_markup:match('"callback_data":"') then
		  utilities.send_reply(msg, 'callback_data ist in Buttons nicht erlaubt.')
		  return
		elseif reply_markup:match('"switch_inline_query":"') then
		  utilities.send_reply(msg, 'switch_inline_query ist in Buttons nicht erlaubt.')
		  return
		end
	  else
	    text = matches[2]
		reply_markup = nil
	  end
	  local success, result = utilities.send_message(chat_id, text, true, nil, true, reply_markup)
	  if success then
	    output = 'Deine Nachricht wurde versendet!'
	  else
	    output = 'Sorry, ich konnte deine Nachricht nicht senden.\n`' .. result.description .. '`'
	  end
    else
	  output = 'Es sieht nicht so aus, als wärst du der Administrator dieses Kanals.'
    end
  else
	output = 'Sorry, ich konnte die Administratorenliste nicht abrufen!\n`'..gca_results.description..'`'
  end
  utilities.send_reply(msg, output, true)
end

return channel
