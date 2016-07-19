local respond = {}

local https = require('ssl.https')
local utilities = require('otouto.utilities')
local bindings = require('otouto.bindings')

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
	results = '[{"type":"article","id":"'..math.random(100000000000000000)..'","title":"ಠ_ಠ","input_message_content":{"message_text":"ಠ_ಠ"}}]'
  elseif string.match(text, "[Ll][Ff]") then
	results = '[{"type":"article","id":"'..math.random(100000000000000000)..'","title":"( ͡° ͜ʖ ͡°)","input_message_content":{"message_text":"( ͡° ͜ʖ ͡°)"}}]'
  elseif string.match(text, "[Nn][Bb][Cc]") or string.match(text, "[Ii][Dd][Cc]") or string.match(text, "[Kk][Aa]") or string.match(text, "[Ii][Dd][Kk]")  then
    results = '[{"type":"article","id":"'..math.random(100000000000000000)..'","title":"¯\\\\\\_(ツ)_/¯","input_message_content":{"message_text":"¯\\\\\\_(ツ)_/¯"}}]'
  end
  utilities.answer_inline_query(self, inline_query, results, 9999)
end

function respond:action(msg, config, matches)
  local user_name = get_name(msg)
  local receiver = msg.chat.id
  local GDRIVE_URL = 'https://de2319bd4b4b51a5ef2939a7638c1d35646f49f8.googledrive.com/host/0B_mfIlDgPiyqU25vUHZqZE9IUXc'
  if user_name == "DefenderX" then user_name = "Deffu" end
	
  if string.match(msg.text, "[Ff][Gg][Tt].? [Ss][Ww][Ii][Ff][Tt]") then
    utilities.send_message(self, receiver, 'Dünnes Eis, '..user_name..'!')
	return
  elseif string.match(msg.text, "([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee][Ss])") then
    utilities.send_message(self, receiver, '*einziges')
	return
  elseif string.match(msg.text, "([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee][Rr])") then
    utilities.send_message(self, receiver, '*einziger')
    return
  elseif string.match(msg.text, "([Ee][Ii][Nn][Zz][Ii][Gg][Ss][Tt][Ee])") then
    utilities.send_message(self, receiver, '*einzige')
	return
  elseif string.match(msg.text, "[Bb][Oo][Tt]%??") then
    utilities.send_reply(self, msg, '*Ich bin da, '..user_name..'!*', true)
    return
  elseif string.match(msg.text, "[Ll][Oo][Dd]") then
    utilities.send_message(self, receiver,  'ಠ_ಠ')
    return
  elseif string.match(msg.text, "[Ll][Ff]") then
    utilities.send_message(self, receiver,  '( ͡° ͜ʖ ͡°)')
    return
  elseif string.match(msg.text, "[Nn][Bb][Cc]") or string.match(msg.text, "[Ii][Dd][Cc]") or string.match(msg.text, "[Kk][Aa]") or string.match(msg.text, "[Ii][Dd][Kk]")  then
    utilities.send_message(self, receiver,  [[¯\_(ツ)_/¯]])
	return
  elseif string.match(msg.text, "[Ff][Rr][Oo][Ss][Cc][Hh]") then
    utilities.send_message(self, receiver,  '🐸🐸🐸')
    return
  elseif string.match(msg.text, "[Ii][Nn][Ll][Oo][Vv][Ee]") then
    local file = download_to_file(GDRIVE_URL..'/inlove.gif')
    utilities.send_document(self, receiver, file)
    return
  elseif string.match(msg.text, "[Ww][Aa][Tt]") then
    local WAT_URL = GDRIVE_URL..'/wat'
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
    utilities.send_photo(self, receiver, file)
	return
  end
  
end

return respond