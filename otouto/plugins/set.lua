local set = {}

set.command = 'set <Variable> <Wert>'

function set:init(config)
	set.triggers = utilities.triggers(self.info.username, config.cmd_pat):t('set', true).table
	set.doc = [[*
]]..config.cmd_pat..[[set* _<Variable>_ _<Wert>_: Speichert eine Variable mit einem Wert
*]]..config.cmd_pat..[[set* _<Variable>_ _nil_: Löscht Variable
Nutze `/get <Variable>` zum Abrufen]]
end

function set:save_value(msg, name, value)
  local hash = get_redis_hash(msg, 'variables')
  if hash then
    print('Saving variable to redis hash '..hash)
    redis:hset(hash, name, value)
    return "Gespeichert: "..name.." = "..value
  end
end

function set:delete_value(msg, name)
  local hash = get_redis_hash(msg, 'variables')
  if redis:hexists(hash, name) == true then
    print('Deleting variable from redis hash '..hash)
    redis:hdel(hash, name)
    return 'Variable "'..name..'" erfolgreich gelöscht!'
  else
    return 'Du kannst keine Variable löschen, die nicht existiert .-.'
  end
end

function set:action(msg)
  local input = utilities.input(msg.text)
  if not input or not input:match('([^%s]+) (.+)') then
    utilities.send_message(msg.chat.id, set.doc, true, msg.message_id, true)
    return
  end
  
  local name = input:match('([^%s]+) ')
  local value = input:match(' (.+)')
  
  if value == "nil" then
    output = set:delete_value(msg, name)
  else
    output = set:save_value(msg, name, value)
  end
  
  utilities.send_message(msg.chat.id, output, true, nil, true)
end

return set
