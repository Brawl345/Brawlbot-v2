 -- This plugin should go at the end of your plugin list in
 -- config.lua, but not after greetings.lua.

local help = {}

local help_text

function help:init(config)
  help.triggers = {
    "^/hilfe (.+)",
	"^/help (.+)",
	"^/(hilfe)_(.+)",
	"^/hilfe$"
  }
  help.inline_triggers = {
    "^hilfe (.+)",
	"^help (.+)"
  }
end

function help:inline_callback(inline_query, config, matches)
  local query = matches[1]
  
  for _,plugin in ipairs(self.plugins) do
	if plugin.command and utilities.get_word(plugin.command, 1) == query and plugin.doc then
	  local doc = plugin.doc
	  local doc = doc:gsub('"', '\\"')
	  local doc = doc:gsub('\\n', '\\\n')
	  local chosen_plugin = utilities.get_word(plugin.command, 1)
	  local results = '[{"type":"article","id":"9","title":"Hilfe für '..chosen_plugin..'","description":"Hilfe für das Plugin \\"'..chosen_plugin..'\\" wird gepostet.","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/help/hilfe.jpg","input_message_content":{"message_text":"'..doc..'","parse_mode":"Markdown"}}]'
	  utilities.answer_inline_query(self, inline_query, results, 600, nil, nil, 'Hilfe anzeigen', 'hilfe_'..chosen_plugin)
	end
  end
  utilities.answer_inline_query(self, inline_query)
end

function help:action(msg, config, matches)
  if matches[2] then
    input = matches[2]
  elseif matches[1] ~= '/hilfe' then
    input = matches[1]
  else
    input = nil
  end
  

  -- Attempts to send the help message via PM.
  -- If msg is from a group, it tells the group whether the PM was successful.
  if not input then
	local commandlist = {}
	local help_text = '*Verfügbare Befehle:*\n• '..config.cmd_pat
	for _,plugin in ipairs(self.plugins) do
	  if plugin.command then
	    commandlist[#commandlist+1] = plugin.command
	  end
	end

	commandlist[#commandlist+1] = 'hilfe [Befehl]'
	table.sort(commandlist)
	local help_text = help_text .. table.concat(commandlist, '\n• '..config.cmd_pat) .. '\nParameter: <benötigt> [optional]'
	local help_text = help_text:gsub('%[', '\\[')

	local res = utilities.send_message(self, msg.from.id, help_text, true, nil, true)
	if not res then
	  utilities.send_reply(self, msg, 'Bitte schreibe mir zuerst [privat](http://telegram.me/' .. self.info.username .. '?start=help) für eine Hilfe.', true)
	elseif msg.chat.type ~= 'private' then
	  utilities.send_reply(self, msg, 'Ich habe dir die Hilfe privat gesendet!.')
	end
	return
  end

  for _,plugin in ipairs(self.plugins) do
    if plugin.command and utilities.get_word(plugin.command, 1) == input and plugin.doc then
	  local output = '*Hilfe für* _' .. utilities.get_word(plugin.command, 1) .. '_ *:*' .. plugin.doc
	  utilities.send_message(self, msg.chat.id, output, true, nil, true)
	  return
	end
  end

  utilities.send_reply(self, msg, 'Für diesen Befehl gibt es keine Hilfe.')
end

return help