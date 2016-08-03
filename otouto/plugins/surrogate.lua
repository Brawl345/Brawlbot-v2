local surrogate = {}

surrogate.triggers = {
  "^/s (%-%d+) +(.+)$",
  "^/s (%d+) +(.+)$",
  "^/s (@[A-Za-z0-9-_-.-._.]+) +(.+)"
}

function surrogate:action(msg, config, matches)
  if not is_sudo(msg, config) then
    utilities.send_reply(self, msg, config.errors.sudo)
	return
  end
  utilities.send_message(self, matches[1], matches[2], true, nil, true)
  return
end

return surrogate
