local surrogate = {}

surrogate.triggers = {
  "^/s (%-%d+) +(.+)$",
  "^/s (%d+) +(.+)$",
  "^/s (@[A-Za-z0-9-_-.-._.]+) +(.+)"
}

function surrogate:action(msg)
  utilities.send_message(self, matches[1], matches[2], true, nil, true)
  return
end

return surrogate
