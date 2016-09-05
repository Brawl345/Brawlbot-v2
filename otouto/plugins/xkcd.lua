local xkcd = {}

xkcd.command = 'xkcd [i]'
xkcd.base_url = 'https://xkcd.com/info.0.json'
xkcd.strip_url = 'https://xkcd.com/%s/info.0.json'

function xkcd:init(config)
  xkcd.triggers =  {
	"xkcd.com/(%d+)",
	"^/xkcd (%d+)",
	"^/xkcd (r)",
	"^/xkcd"
  }
	xkcd.doc = [[*
]]..config.cmd_pat..[[xkcd* _[i]_: Gibt den aktuellen XKCD-Comic aus, oder die Nummer, wenn eine gegeben ist. Wenn "r" übergeben wird, wird ein zufälliger Comic zurückgegeben.]]
  local jstr = https.request(xkcd.base_url)
  if jstr then
	local data = json.decode(jstr)
	if data then
	  xkcd.latest = data.num
	end
  end
  xkcd.latest = xkcd.latest or 1700
end

function xkcd:action(msg, config, matches)
  if matches[1] == 'r' then
    input = math.random(xkcd.latest)
  elseif tonumber(matches[1]) then
    input = tonumber(matches[1])
  else
    input = xkcd.latest
  end

  local url = xkcd.strip_url:format(input)
  local jstr, code = https.request(url)
  if code == 404 then
	utilities.send_reply(msg, config.errors.results)
  elseif code ~= 200 then
	utilities.send_reply(msg, config.errors.connection)
  else
	local data = json.decode(jstr)
	local output = string.format(
	  '<b>%s</b> (<a href="%s">%s</a>)\n<i>%s</i>',
	  utilities.html_escape(utilities.fix_utf8(data.safe_title)),
	  utilities.html_escape(data.img),
	  data.num,
	  utilities.html_escape(utilities.fix_utf8(data.alt))
	)
	utilities.send_message(msg.chat.id, output, false, nil, 'html')
  end
end

return xkcd