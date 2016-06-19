local qr = {}

local http = require('socket.http')
local URL = require('socket.url')
local utilities = require('otouto.utilities')

function qr:init(config)
	qr.triggers = {
    '^/qr "(%w+)" "(%w+)" (.+)$',
    "^/qr (.+)$"
	}
	qr.doc = [[*
]]..config.cmd_pat..[[qr* _<Text>_: Sendet QR-Code mit diesem Text
*]]..config.cmd_pat..[[qr* _"[Hintergrundfarbe]"_ _"[Datenfarbe]"_ _[Text]_
Farbe mit Text: red|green|blue|purple|black|white|gray
Farbe als HEX: ("a56729" ist braun)
oder Farbe als Dezimalwert: ("255-192-203" ist pink)]]
end

qr.command = 'qr <Text>'

function qr:get_hex(str)
  local colors = {
    red = "f00",
    blue = "00f",
    green = "0f0",
    yellow = "ff0",
    purple = "f0f",
    white = "fff",
    black = "000",
    gray = "ccc"
  }

  for color, value in pairs(colors) do
    if color == str then
      return value
    end
  end

  return str
end

function qr:qr(text, color, bgcolor)

  local url = "http://api.qrserver.com/v1/create-qr-code/?"
    .."size=600x600"  --fixed size otherways it's low detailed
    .."&data="..URL.escape(utilities.trim(text))

  if color then
    url = url.."&color="..qr:get_hex(color)
  end
  if bgcolor then
    url = url.."&bgcolor="..qr:get_hex(bgcolor)
  end

  local response, code, headers = http.request(url)

  if code ~= 200 then
	return nil
  end

  if #response > 0 then
	return url
  end

  return nil
end

function qr:action(msg, config, matches)
  local text = matches[1]
  local color
  local back

  if #matches > 1 then
    text = matches[3]
    color = matches[2]
    back = matches[1]
  end

  local image_url = qr:qr(text, color, back)
  if not image_url then utilities.send_reply(self, msg, config.errors.connection) return end
  local file = download_to_file(image_url, 'qr.png')
  utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
end

return qr
