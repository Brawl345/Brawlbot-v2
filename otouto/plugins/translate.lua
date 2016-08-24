local translate = {}
local mime = require("mime")
require("./otouto/plugins/pasteee")

translate.command = 'translate [Text]'

function translate:init(config)
	if not cred_data.bing_key then
		print('Missing config value: bing_key.')
		print('translate.lua will not be enabled.')
		return
	end
	translate.triggers = {
    "^/translate ([%w]+),([%a]+) (.+)",
    "^/translate (to%:)([%w]+) (.+)",
    "^/translate (.+)",
	"^/getlanguages$",
	"^/(whatlang) (.+)"
	}
	translate.doc = [[*
]]..config.cmd_pat..[[translate* _[Text]_: Übersetze Text in deutsch
*]]..config.cmd_pat..[[translate* to:Zielsprache _[Text]_: Übersetze Text in Zielsprache
*]]..config.cmd_pat..[[translate* Quellsprache,Zielsprache _[Text]_: Übersetze Text von beliebiger Sprache in beliebige Sprache
*]]..config.cmd_pat..[[getlanguages*: Postet alle verfügbaren Sprachcodes
*]]..config.cmd_pat..[[whatlang* _[Text]_: Gibt erkannte Sprache zurück]]
end

local bing_key = cred_data.bing_key
local accountkey = mime.b64(bing_key..':'..bing_key)

function translate:translate(source_lang, target_lang, text)
  if not target_lang then target_lang = 'de' end
  local url = 'https://api.datamarket.azure.com/Bing/MicrosoftTranslator/Translate?$format=json&Text=%27'..URL.escape(text)..'%27&To=%27'..target_lang..'%27&From=%27'..source_lang..'%27'
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body),
      headers = {
	    Authorization = "Basic "..accountkey
	  }
  }
  local ok, response_code, response_headers, response_status_line = https.request(request_constructor)
  if not ok or response_code ~= 200 then return 'Ein Fehler ist aufgetreten.' end

  local trans = json.decode(table.concat(response_body)).d.results[1].Text

  return trans
end

function translate:detect_language(text)
  local url = 'https://api.datamarket.azure.com/Bing/MicrosoftTranslator/Detect?$format=json&Text=%27'..URL.escape(text)..'%27'
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body),
      headers = {
	    Authorization = "Basic "..accountkey
	  }
  }
  local ok, response_code, response_headers, response_status_line = https.request(request_constructor)
  if not ok or response_code ~= 200 then return 'en' end
  
  local language = json.decode(table.concat(response_body)).d.results[1].Code
  print('Erkannte Sprache: '..language)
  return language
end

function translate:get_all_languages()
  local url = 'https://api.datamarket.azure.com/Bing/MicrosoftTranslator/GetLanguagesForTranslation?$format=json'
  local response_body = {}
  local request_constructor = {
      url = url,
      method = "GET",
      sink = ltn12.sink.table(response_body),
      headers = {
	    Authorization = "Basic "..accountkey
	  }
  }
  local ok, response_code, response_headers, response_status_line = https.request(request_constructor)
  if not ok or response_code ~= 200 then return 'Ein Fehler ist aufgetreten.' end
  
  local lang_table = json.decode(table.concat(response_body)).d.results
  
  local languages = ""
  for i in pairs(lang_table) do
    languages = languages..lang_table[i].Code..'\n'
  end
  
  local link = upload(languages)
  return '[Sprachliste auf Paste.ee ansehen]('..link..')'
end

function translate:action(msg, config, matches)
  utilities.send_typing(msg.chat.id, 'typing')
  
  if matches[1] == '/getlanguages' then
    utilities.send_reply(msg, translate:get_all_languages(), true)
	return
  end
  
  if matches[1] == 'whatlang' and matches[2] then
    local text = matches[2]
	local lang = translate:detect_language(text)
	utilities.send_reply(msg, 'Erkannte Sprache: '..lang, true)
	return
  end

  -- Third pattern
  if #matches == 1 then
    print("First")
    local text = matches[1]
	local language = translate:detect_language(text)
	utilities.send_reply(msg, translate:translate(language, nil, text))
    return
  end

  -- Second pattern
  if #matches == 3 and matches[1] == "to:" then
    print("Second")
    local target = matches[2]
    local text = matches[3]
	local language = translate:detect_language(text)
	utilities.send_reply(msg, translate:translate(language, target, text))
    return
  end

  -- First pattern
  if #matches == 3 then
    print("Third")
    local source = matches[1]
    local target = matches[2]
    local text = matches[3]
	utilities.send_reply(msg, translate:translate(source, target, text))
    return
  end

end

return translate
