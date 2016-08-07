local tagesschau = {}

tagesschau.triggers = {
  "tagesschau.de/([A-Za-z0-9-_-_-/]+).html"
}

tagesschau.inline_triggers = tagesschau.triggers
  
local BASE_URL = 'https://www.tagesschau.de/api'

local makeOurDate = function(dateString)
  local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+)%:(%d+)%:(%d+)"
  local year, month, day, hours, minutes, seconds = dateString:match(pattern)
  return day..'.'..month..'.'..year..' um '..hours..':'..minutes..':'..seconds
end

function tagesschau:get_tagesschau_article(article)
  local url = BASE_URL..'/'..article..'.json'
  local res,code  = https.request(url)
  local data = json.decode(res)
  if code == 404 then return "Artikel nicht gefunden!" end
  if code ~= 200 then return "HTTP-Fehler" end
  if not data then return "HTTP-Fehler" end
  if data.type ~= "story" then
    print('Typ "'..data.type..'" wird nicht unterstützt')
    return nil
  end
  
  local title = data.topline..': '..data.headline
  local news = data.shorttext
  local posted_at = makeOurDate(data.date)..' Uhr'
  
  local text = '<b>'..title..'</b>\n<i>'..posted_at..'</i>\n'..news
  if data.banner[1] then
    return text, data.banner[1].variants[1].modPremium, data.shortheadline, data.shorttext
  else
    return text, nil, data.shortheadline, data.shorttext
  end
end

function tagesschau:inline_callback(inline_query, config, matches)
  local article = matches[1]
  local full_url = 'http://www.tagesschau.de/'..article..'.html'
  local text, img_url, headline, shorttext = tagesschau:get_tagesschau_article(article)
  if text == 'HTTP-Fehler' or text == 'Artikel nicht gefunden!' then utilities.answer_inline_query(self, inline_query) return end

  if text:match('"') then
    text = text:gsub('"', '\\"')
  end
  if shorttext:match('"') then
    shorttext = shorttext:gsub('"', '\\"')
  end
  if headline:match('"') then
    headline = headline:gsub('"', '\\"')
  end
  
  local text = text:gsub('\n', '\\n')
  local results = '[{"type":"article","id":"11","title":"'..headline..'","description":"'..shorttext..'","url":"'..full_url..'","thumb_url":"https://anditest.perseus.uberspace.de/inlineQuerys/tagesschau/tagesschau.jpg","thumb_width":150,"thumb_height":150,"hide_url":true,"reply_markup":{"inline_keyboard":[[{"text":"Artikel aufrufen","url":"'..full_url..'"}]]},"input_message_content":{"message_text":"'..text..'","parse_mode":"HTML"}}]'
  utilities.answer_inline_query(self, inline_query, results, 7200)
end

function tagesschau:action(msg, config, matches)
  local article = matches[1]
  local text, image_url = tagesschau:get_tagesschau_article(article)
  if image_url then
    utilities.send_typing(self, msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url)
    utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
  end
  utilities.send_reply(self, msg, text, 'HTML')
end

return tagesschau