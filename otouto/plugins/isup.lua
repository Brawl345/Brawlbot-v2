local isup = {}

function isup:init(config)
  isup.triggers = {
    "^/isup (.*)$",
    "^/ping (.*)$"
  }
	
  isup.doc = [[*
]]..config.cmd_pat..[[isup* _<URL>_: Prüft, ob die URL up ist]]
end

function isup:is_up_socket(ip, port)
  print('Connect to', ip, port)
  local c = socket.try(socket.tcp())
  c:settimeout(3)
  local conn = c:connect(ip, port)
  if not conn then
    return false
  else
    c:close()
    return true
  end
end

function isup:is_up_http(url)
  -- Parse URL from input, default to http
  local parsed_url = URL.parse(url,  { scheme = 'http', authority = '' })
  -- Fix URLs without subdomain not parsed properly
  if not parsed_url.host and parsed_url.path then
    parsed_url.host = parsed_url.path
    parsed_url.path = ""
  end
  -- Re-build URL
  local url = URL.build(parsed_url)

  local protocols = {
    ["https"] = https,
    ["http"] = http
  }
  local options =  {
    url = url,
    redirect = false,
    method = "GET"
  }
  local response = { protocols[parsed_url.scheme].request(options) }
  local code = tonumber(response[2])
  if code == nil or code >= 400 then
    return false
  end
  return true
end

function isup:isup(url)
  local pattern = '^(%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?):?(%d?%d?%d?%d?%d?)$'
  local ip,port = string.match(url, pattern)
  local result = nil

  -- /isup 8.8.8.8:53
  if ip then
    port = port or '80'
    result = isup:is_up_socket(ip, port)
  else
    result = isup:is_up_http(url)
  end
  return result
end

function isup:action(msg, config)
  if isup:isup(matches[1]) then
    utilities.send_reply(self, msg, matches[1]..' ist UP! ✅')
    return
  else
    utilities.send_reply(self, msg, matches[1]..' ist DOWN! ❌')
    return
  end
end

return isup
