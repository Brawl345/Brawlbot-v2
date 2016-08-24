local wikia = {}

wikia.triggers = {
  "https?://(.+).wikia.com/wiki/(.+)"
}
  
local BASE_URL = '.wikia.com/api/v1/Articles/Details?abstract=400'

function send_wikia_article(wikia, article)
  local url = 'http://'..wikia..BASE_URL..'&titles='..article
  local res,code  = http.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  if string.match(res, "Not a valid Wikia") then return 'Dieses Wikia existiert nicht!' end
  local data = json.decode(res)

  local keyset={}
  local n=0
  for id,_ in pairs(data.items) do
    n=n+1
    keyset[n]=id
  end
  
  local id = keyset[1]
  if not id then return 'Diese Seite existiert nicht!' end

  local title = data.items[id].title
  local abstract = data.items[id].abstract
  local article_url = data.basepath..data.items[id].url
  
  local text = '*'..title..'*:\n'..abstract..' [Weiterlesen]('..article_url..')'
  return text
end

function wikia:action(msg, config, matches)
  local wikia = matches[1]
  local article = matches[2]
  utilities.send_reply(msg, send_wikia_article(wikia, article), true)
end

return wikia