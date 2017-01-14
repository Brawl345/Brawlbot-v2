local wikipedia = {}

wikipedia.command = 'wiki <Begriff>'

function wikipedia:init(config)
	wikipedia.triggers = {
      "^/[Ww]iki(%w+) (search) (.+)$",
      "^/[Ww]iki (search) ?(.*)$",
      "^/[Ww]iki(%w+) (.+)$",
      "^/[Ww]iki ?(.*)$",
      "(%w+).m.wikipedia.org/wiki/(.+)",
  	  "(%w+).wikipedia.org/wiki/(.+)"
	}
	wikipedia.inline_triggers = {
	  "^wiki(%w+) (.+)",
	  "^wiki (.+)"
	}
	wikipedia.doc = [[*
]]..config.cmd_pat..[[wiki* _<Begriff>_: Gibt Wikipedia-Artikel aus
Alias: ]]..config.cmd_pat..[[wikipedia]]
end

local decodetext
do
    local char, gsub, tonumber = string.char, string.gsub, tonumber
    local function _(hex) return char(tonumber(hex, 16)) end

    function decodetext(s)
        s = gsub(s, '%%(%x%x)', _)
        return s
    end
end

local server = {
  -- http://meta.wikimedia.org/wiki/List_of_Wikipedias
  wiki_server = "https://%s.wikipedia.org",
  wiki_path = "/w/api.php",
  wiki_load_params = {
    action = "query",
    prop = "extracts",
    format = "json",
    exchars = 350,
    exsectionformat = "plain",
    explaintext = "",
    redirects = ""
  },
  wiki_search_params = {
    action = "query",
	 list = "search",
    srlimit = 20,
	 format = "json",
  },
  default_lang = "de",
}

function wikipedia:getWikiServer(lang)
  return string.format(server.wiki_server, lang or server.default_lang)
end

--[[
--  return decoded JSON table from Wikipedia
--]]
function wikipedia:loadPage(text, lang, intro, plain, is_search)
  local request, sink = {}, {}
  local query = ""
  local parsed

  if is_search then
    for k,v in pairs(server.wiki_search_params) do
      query = query .. k .. '=' .. v .. '&'
    end
    parsed = URL.parse(wikipedia:getWikiServer(lang))
    parsed.path = server.wiki_path
    parsed.query = query .. "srsearch=" .. URL.escape(text)
  else
    server.wiki_load_params.explaintext = plain and "" or nil
    for k,v in pairs(server.wiki_load_params) do
      query = query .. k .. '=' .. v .. '&'
    end
    parsed = URL.parse(wikipedia:getWikiServer(lang))
    parsed.path = server.wiki_path
    parsed.query = query .. "titles=" .. URL.escape(text)
  end

  -- HTTP request
  request['url'] = URL.build(parsed)
  request['method'] = 'GET'
  request['sink'] = ltn12.sink.table(sink)
  
  local httpRequest = parsed.scheme == 'http' and http.request or https.request
  local code, headers, status = socket.skip(1, httpRequest(request))

  if not headers or not sink then
    return nil
  end

  local content = table.concat(sink)
  if content ~= "" then
    local ok, result = pcall(json.decode, content)
    if ok and result then
      return result
    else
      return nil
    end
  else 
    return nil
  end
end

-- extract intro passage in wiki page
function wikipedia:wikintro(text, lang, is_inline)
  local text = decodetext(text)
  local result = self:loadPage(text, lang, true, true)

  if result and result.query then

    local query = result.query
    if query and query.normalized then
      text = query.normalized[1].to or text
    end

    local page = query.pages[next(query.pages)]

    if page and page.extract then
	  local lang = lang or "de"
	  local title = page.title
	  local title_enc = URL.escape(title)
	  if is_inline then
	    local result = '<b>'..title..'</b>:\n'..page.extract
		local result = result:gsub('\n', '\\n')
		local result = result:gsub('"', '\\"')
        return title, result, '{"inline_keyboard":[[{"text":"Wikipedia aufrufen","url":"https://'..lang..'.wikipedia.org/wiki/'..title_enc..'"}]]}'
	  else
        return '*'..title..'*:\n'..utilities.md_escape(page.extract), '{"inline_keyboard":[[{"text":"Artikel aufrufen","url":"https://'..lang..'.wikipedia.org/wiki/'..title_enc..'"}]]}'
	  end
    else
	  if is_inline then
	    return nil
	  else
        local text = text.." nicht gefunden"
        return text
	  end
    end
  else
    if is_inline then
	  return nil
	else
      return "Ein Fehler ist aufgetreten."
	end
  end
end

-- search for term in wiki
function wikipedia:wikisearch(text, lang)
  local result = wiki:loadPage(text, lang, true, true, true)

  if result and result.query then
    local titles = ""
	 for i,item in pairs(result.query.search) do
      titles = titles .. "\n" .. item["title"]
	 end
	 titles = titles ~= "" and titles or "Keine Ergebnisse gefunden"
	 return titles
  else
    return "Ein Fehler ist aufgetreten."
  end

end

function wikipedia:snip_snippet(snippet)
  local snippet = snippet:gsub("<span class%=\"searchmatch\">", "")
  local snippet = snippet:gsub("</span>", "")
  return snippet
end

function wikipedia:inline_callback(inline_query, config, matches)
  if matches[2] then
    lang = matches[1]
	query = matches[2]
  else
    lang = 'de'
	query = matches[1]
  end
  
  local search_url = 'https://'..lang..'.wikipedia.org/w/api.php?action=query&list=search&srsearch='..URL.escape(query)..'&format=json&prop=extracts&srprop=snippet&&srlimit=5'
  local res, code = https.request(search_url)
  if code ~= 200 then abort_inline_query(inline_query) return end
  local data = json.decode(res).query


  local results = '['
  local id = 700
  for num in pairs(data.search) do
	local title, result, keyboard = wikipedia:wikintro(data.search[num].title, lang, true)
	if not title or not result or not keyboard then abort_inline_query(inline_query) return end
	results = results..'{"type":"article","id":"'..id..'","title":"'..title..'","description":"'..wikipedia:snip_snippet(data.search[num].snippet)..'","url":"https://'..lang..'.wikipedia.org/wiki/'..URL.escape(title)..'","hide_url":true,"thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/wiki/logo.jpg","thumb_width":95,"thumb_height":86,"reply_markup":'..keyboard..',"input_message_content":{"message_text":"'..result..'","parse_mode":"HTML"}}'
	id = id+1
	if num < #data.search then
	 results = results..','
	end
  end
  local results = results..']'
  utilities.answer_inline_query(inline_query, results, 3600)
end

function wikipedia:action(msg, config, matches)
  local search, term, lang
  if matches[1] == "search" then
    search = true
	 term = matches[2]
	 lang = nil
  elseif matches[2] == "search" then
    search = true
	 term = matches[3]
	 lang = matches[1]
  else
    term = matches[2]
	 lang = matches[1]
  end
  if not term then
    term = lang
    lang = nil
  end
  if term == "" then
    utilities.send_reply(msg, wikipedia.doc, true)
    return
  end

  local result
  if search then
    result = wikipedia:wikisearch(term, lang)
  else
    result, keyboard = wikipedia:wikintro(term, lang)
  end
  utilities.send_reply(msg, result, true, keyboard)
end

return wikipedia
