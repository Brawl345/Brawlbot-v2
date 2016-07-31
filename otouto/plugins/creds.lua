local creds_manager = {}

function creds_manager:init(config)
    creds_manager.triggers = {
      "^(/creds)$",
	  "^(/creds add) ([^%s]+) (.+)$",
	  "^(/creds del) (.+)$",
	  "^(/creds rename) ([^%s]+) (.+)$"
	}
	creds_manager.doc = [[*
]]..config.cmd_pat..[[creds*: Zeigt alle Logindaten und API-Keys
*]]..config.cmd_pat..[[creds* _add_ _<Variable>_ _<Schlüssel>_: Speichert Schlüssel mit dieser Variable ein
*]]..config.cmd_pat..[[creds* _del_ _<Variable>_: Löscht Schlüssel mit dieser Variable
*]]..config.cmd_pat..[[creds* _rename_ _<Variable>_ _<Neue Variable>_: Benennt Variable um, behält Schlüssel bei
]]
end

creds_manager.command = 'creds'

local hash = "telegram:credentials"

-- See: http://www.lua.org/pil/19.3.html
function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then
	  return nil
    else
	  return a[i], t[a[i]]
    end
  end
  return iter
end

function creds_manager:reload_creds()
  cred_data = redis:hgetall(hash)
end

function creds_manager:list_creds()
  creds_manager:reload_creds()
  if redis:exists("telegram:credentials") == true then
    local text = ""
    for var, key in pairsByKeys(cred_data) do
      text = text..var..' = '..key..'\n'
    end
    return text
  else
    create_cred()
	return "Es wurden noch keine Logininformationen gespeichert, lege Tabelle an...\nSpeichere Keys mit /creds add [Variable] [Key] ein!"
  end
end

function creds_manager:add_creds(var, key)
  print('Saving credential for '..var..' to redis hash '..hash)
  redis:hset(hash, var, key)
  creds_manager:reload_creds()
  return 'Gespeichert!'
end

function creds_manager:del_creds(var)
  if redis:hexists(hash, var) == true then
    print('Deleting credential for '..var..' from redis hash '..hash)
    redis:hdel(hash, var)
	creds_manager:reload_creds()
    return 'Key von "'..var..'" erfolgreich gelöscht!'
  else
    return 'Du hast keine Logininformationen für diese Variable eingespeichert.'
  end
end

function creds_manager:rename_creds(var, newvar)
  if redis:hexists(hash, var) == true then
    local key = redis:hget(hash, var)
	if redis:hsetnx(hash, newvar, key) == true then
	  redis:hdel(hash, var)
	  creds_manager:reload_creds()
	  return '"'..var..'" erfolgreich zu "'..newvar..'" umbenannt.'
	else
	  return "Variable konnte nicht umbenannt werden: Zielvariable existiert bereits."
	end
  else
    return 'Die zu umbennende Variable existiert nicht.'
  end
end

function creds_manager:action(msg, config, matches)
  local receiver = msg.from.id
  if receiver ~= config.admin then
    utilities.send_reply(self, msg, config.errors.sudo)
	return
  end

  if msg.chat.type ~= 'private' then
    utilities.send_reply(self, msg, 'Dieses Plugin solltest du nur [privat](http://telegram.me/' .. self.info.username .. '?start=creds) verwenden!', true)
    return
  end
  
  if matches[1] == "/creds" then
    utilities.send_reply(self, msg, creds_manager:list_creds())
    return
  elseif matches[1] == "/creds add" then
    local var = string.lower(string.sub(matches[2], 1, 50))
    local key = string.sub(matches[3], 1, 1000)
	utilities.send_reply(self, msg, creds_manager:add_creds(var, key))
    return
  elseif matches[1] == "/creds del" then
    local var = string.lower(matches[2])
	utilities.send_reply(self, msg, creds_manager:del_creds(var))
    return
  elseif matches[1] == "/creds rename" then
    local var = string.lower(string.sub(matches[2], 1, 50))
    local newvar = string.lower(string.sub(matches[3], 1, 1000))
	utilities.send_reply(self, msg, creds_manager:rename_creds(var, newvar))
    return
  end
end

return creds_manager
