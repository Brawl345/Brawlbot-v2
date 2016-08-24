local site_header = {}

function site_header:init(config)
	site_header.triggers = {
    "^/(head) ([%w-_%.%?%.:,/%+=&#!]+)$",
    "^/(dig) ([%w-_%.%?%.:,/%+=&#!]+)$"
	}
end

function site_header:action(msg, config, matches)
  if msg.from.id ~= config.admin then
	utilities.send_reply(msg, config.errors.sudo)
  end
  
  local url = matches[2]
  if matches[1] == 'head' then
    input = 'curl --head '..url
  elseif matches[1] == 'dig' then
    input = 'dig '..url..' ANY'
  end
  local output = io.popen(input):read('*all')
  output = '```\n' .. output .. '\n```'
  utilities.send_reply(msg, output, true)
end

return site_header
