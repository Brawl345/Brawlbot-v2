local get = {}

get.command = 'get <Variable>'

function get:init(config)
	get.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('get', true).table
	get.doc = [[*
]]..config.cmd_pat..[[get*: Gibt alle Variablen aus
*]]..config.cmd_pat..[[get* _<Variable>_: Gibt _Variable_ aus
Nutze `!set <Variable> <Wert>` zum Setzen von Variablen]]
end

function get:get_value(msg, var_name)
  local hash = get_redis_hash(msg, 'variables')
  if hash then
    local value = redis:hget(hash, var_name)
    if not value then
      return'Nicht gefunden; benutze /get, um alle Variablen aufzulisten.'
    else
      return var_name..' = '..value
    end
  end
end

function get:list_variables(msg)
  local hash = get_redis_hash(msg, 'variables')
  print(hash)
  
  if hash then
    print('Getting variable from redis hash '..hash)
    local names = redis:hkeys(hash)
    local text = ''
	for i=1, #names do
	  variables = get:get_value(msg, names[i])
      text = text..variables.."\n"
    end
	if text == '' or text == nil then
	  return 'Keine Variablen vorhanden!'
	else
      return text
	end
  end
end

function get:action(msg)
  local input = utilities.input(msg.text)
  if input then
    output = get:get_value(msg, input:match('(.+)'))
  else
    output = get:list_variables(msg)
  end

  utilities.send_message(msg.chat.id, output, true, nil, true)
end

return get
