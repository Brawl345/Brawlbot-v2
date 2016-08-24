local respond = {}

function respond:init(config)
    respond.triggers = {
	"([Ff][Gg][Tt].? [Ss][Ww][Ii][Ff][Tt])",
	"([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee][Ss])",
	"([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee][Rr])",
	"([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee])",
	"^[Bb][Oo][Tt]%??$",
	"^/([Ll][Oo][Dd])$",
	"^/([Ll][Ff])$",
	"^/([Kk][Aa])$",
	"^/([Ii][Dd][Kk])$",
	"^/([Nn][Bb][Cc])$",
	"^/([Ii][Dd][Cc])$",
	"^%*([Ff][Rr][Oo][Ss][Cc][Hh])%*",
	"^/([Ff][Rr][Oo][Ss][Cc][Hh])$",
	"^%(([Ii][Nn][Ll][Oo][Vv][Ee])%)$",
	"^/[Ww][Aa][Tt]$"
	}
	
	respond.inline_triggers = {
	"^([Ll][Oo][Dd])$",
	"^([Ll][Ff])$",
	"^([Kk][Aa])$",
	"^([Ii][Dd][Kk])$",
	"^([Nn][Bb][Cc])$",
	"^([Ii][Dd][Cc])$",
	}
end

respond.command = 'lod, /lf, /nbc, /wat'

function respond:inline_callback(inline_query, config, matches)
  local text = matches[1]
  if string.match(text, "[Ll][Oo][Dd]") then
	face = 'ಠ_ಠ'
  elseif string.match(text, "[Ll][Ff]") then
	face = '( ͡° ͜ʖ ͡°)'
  elseif string.match(text, "[Nn][Bb][Cc]") or string.match(text, "[Ii][Dd][Cc]") or string.match(text, "[Kk][Aa]") or string.match(text, "[Ii][Dd][Kk]")  then
	face = '¯\\\\\\_(ツ)_/¯'
  end
  results = '[{"type":"article","id":"8","title":"'..face..'","input_message_content":{"message_text":"'..face..'"}}]'
  utilities.answer_inline_query(inline_query, results, 9999)
end

function respond:action(msg, config, matches)
  local user_name = get_name(msg)
  local receiver = msg.chat.id
  local BASE_URL = 'https://anditest.perseus.uberspace.de/plugins/respond'
  if user_name == "DefenderX" then user_name = "Deffu" end
	
  if string.match(msg.text, "[Ff][Gg][Tt].? [Ss][Ww][Ii][Ff][Tt]") then
    utilities.send_message(receiver, 'Dünnes Eis, '..user_name..'!')
	return
  elseif string.match(msg.text, "([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee][Ss])") then
    utilities.send_message(receiver, '*einziges')
	return
  elseif string.match(msg.text, "([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee][Rr])") then
    utilities.send_message(receiver, '*einziger')
    return
  elseif string.match(msg.text, "([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee])") then
    utilities.send_message(receiver, '*einzige')
	return
  elseif string.match(msg.text, "[Bb][Oo][Tt]%??") then
    utilities.send_reply(msg, '*Ich bin da, '..user_name..'!*', true)
    return
  elseif string.match(msg.text, "[Ll][Oo][Dd]") then
    utilities.send_message(receiver,  'ಠ_ಠ')
    return
  elseif string.match(msg.text, "[Ll][Ff]") then
    utilities.send_message(receiver,  '( ͡° ͜ʖ ͡°)')
    return
  elseif string.match(msg.text, "[Nn][Bb][Cc]") or string.match(msg.text, "[Ii][Dd][Cc]") or string.match(msg.text, "[Kk][Aa]") or string.match(msg.text, "[Ii][Dd][Kk]")  then
    utilities.send_message(receiver,  [[¯\_(ツ)_/¯]])
	return
  elseif string.match(msg.text, "[Ff][Rr][Oo][Ss][Cc][Hh]") then
    utilities.send_message(receiver,  '🐸🐸🐸')
    return
  elseif string.match(msg.text, "[Ii][Nn][Ll][Oo][Vv][Ee]") then
    local file = download_to_file(BASE_URL..'/inlove.gif')
    utilities.send_document(receiver, file)
    return
  elseif string.match(msg.text, "[Ww][Aa][Tt]") then
    local WAT_URL = BASE_URL..'/wat'
    local wats = {
      "/wat1.jpg",
      "/wat2.jpg",
      "/wat3.jpg",
	  "/wat4.jpg",
	  "/wat5.jpg",
	  "/wat6.jpg",
	  "/wat7.jpg",
	  "/wat8.jpg"
    }
  	local random_wat = math.random(5)
	local file = download_to_file(WAT_URL..wats[random_wat])
    utilities.send_photo(receiver, file, nil, msg.message_id)
	return
  end
  
end

return respond