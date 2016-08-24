local shell = {}

function shell:init(config)
	shell.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('sh', true).table
end

function shell:action(msg, config)
  if not is_sudo(msg, config) then
	utilities.send_reply(msg, config.errors.sudo)
	return
  end

  local input = utilities.input(msg.text)
  if not input then
	utilities.send_reply(msg, 'Bitte gib ein Kommando ein.')
	return
  end
  input = input:gsub('—', '--')

  local output = run_command(input)
  if output:len() == 0 then
	output = 'Ausgeführt.'
  else
	output = '<pre>\n' .. output .. '\n</pre>'
  end
  output = output:gsub('<pre>%\n', '<pre>')
  output = output:gsub('%\n%\n</pre>', '</pre>')
  utilities.send_message(msg.chat.id, output, true, msg.message_id, 'HTML')
end

return shell
