 -- This plugin should go at the end of your plugin list in
 -- config.lua, but not after greetings.lua.

local help = {}

local help_text

function help:init(config)
  help.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('hilfe', true):t('help', true).table
  help.inline_triggers = {
    "^hilfe (.+)",
	"^help (.+)"
  }
end

function help:inline_callback(inline_query, config)
  local query = matches[1]
  
  for _,plugin in ipairs(self.plugins) do
	if plugin.command and utilities.get_word(plugin.command, 1) == query and plugin.doc then
	  local doc = plugin.doc
	  local doc = doc:gsub('"', '\\"')
	  local doc = doc:gsub('\\n', '\\\n')
	  local chosen_plugin = utilities.get_word(plugin.command, 1)
	  local results = '[{"type":"article","id":"'..math.random(100000000000000000)..'","title":"Hilfe für '..chosen_plugin..'","description":"Hilfe für das Plugin \\"'..chosen_plugin..'\\" wird gepostet.","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/help/hilfe.jpg","input_message_content":{"message_text":"'..doc..'","parse_mode":"Markdown"}}]'
	  local results, err = utilities.answer_inline_query(self, inline_query, results, 600)
	end
  end
  utilities.answer_inline_query(self, inline_query)
end

function help:action(msg, config)
	local commandlist = {}
	help_text = '*Verfügbare Befehle:*\n• '..config.cmd_pat

	for _,plugin in ipairs(self.plugins) do
		if plugin.command then
		    
			table.insert(commandlist, plugin.command)
		end
	end

	table.insert(commandlist, 'hilfe [Befehl]')
	table.sort(commandlist)
	help_text = help_text .. table.concat(commandlist, '\n• '..config.cmd_pat) .. '\nParameter: <benötigt> [optional]'

	help_text = help_text:gsub('%[', '\\[')
	local input = utilities.input(msg.text_lower)

	-- Attempts to send the help message via PM.
	-- If msg is from a group, it tells the group whether the PM was successful.
	if not input then
		local res = utilities.send_message(self, msg.from.id, help_text, true, nil, true)
		if not res then
			utilities.send_reply(self, msg, 'Bitte schreibe mir zuerst [privat](http://telegram.me/' .. self.info.username .. '?start=help) für eine Hilfe.', true)
		elseif msg.chat.type ~= 'private' then
			utilities.send_reply(self, msg, 'Ich habe dir die Hilfe per PN gesendet!.')
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
