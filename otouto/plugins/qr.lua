local qr = {}

function qr:init(config)
	qr.triggers = {
    '^/qr "(%w+)" "(%w+)" (.+)$',
    "^/qr (.+)$"
	}
	qr.inline_triggers = {
	  "^qr (https?://[%w-_%.%?%.:/%+=&]+)"
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

function qr:qr(text, color, bgcolor, img_format)

  local url = "http://api.qrserver.com/v1/create-qr-code/?"
    .."size=600x600"  --fixed size otherways it's low detailed
    .."&data="..URL.escape(utilities.trim(text))
	
  if img_format then
    url = url..'&format='..img_format
  end

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

function qr:inline_callback(inline_query, config, matches)
  local text = matches[1]
  if string.len(text) > 200 then utilities.answer_inline_query(self, inline_query) return end
  local image_url = qr:qr(text, nil, nil, 'jpg')
  if not image_url then utilities.answer_inline_query(self, inline_query) return end
  
  local id = 600
 
  local results = '[{"type":"photo","id":"'..id..'","photo_url":"'..image_url..'","thumb_url":"'..image_url..'","photo_width":600,"photo_height":600,"caption":"'..text..'"},'
  
  local i = 0
  while i < 29 do
	i = i+1
    local color = math.random(255)
	local bgcolor = math.random(255)
    local image_url = qr:qr(text, color, bgcolor, 'jpg')
	id = id+1
    results = results..'{"type":"photo","id":"'..id..'","photo_url":"'..image_url..'","thumb_url":"'..image_url..'","photo_width":600,"photo_height":600,"caption":"'..text..'"}'
	if i < 29 then
	  results = results..','
	end
  end
  
  local results = results..']'
  utilities.answer_inline_query(self, inline_query, results, 10000)
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
