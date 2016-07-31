local surrogate = {}

surrogate.triggers = {
  "^/s (%-%d+) +(.+)$",
  "^/s (%d+) +(.+)$"
}

function surrogate:action(msg)
  -- Supergroups don't work!?
  utilities.send_message(self, matches[1], matches[2], true, nil, true)
  return
end

return surrogate
