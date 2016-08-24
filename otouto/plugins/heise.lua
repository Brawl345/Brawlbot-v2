local heise = {}

heise.triggers = {
      "heise.de/newsticker/meldung/(.*).html$"
  }

function heise:get_heise_article(article)
  local url = 'https://query.yahooapis.com/v1/public/yql?q=select%20content,src,strong%20from%20html%20where%20url=%22http://www.heise.de/newsticker/meldung/'..article..'.html%22%20and%20xpath=%22//div[@id=%27mitte_news%27]/article/header/h2|//div[@id=%27mitte_news%27]/article/div/p[1]/strong|//div[@id=%27mitte_news%27]/article/div/figure/img%22&format=json'
  local res,code  = https.request(url)
  local data = json.decode(res).query.results
  if code ~= 200 then return "HTTP-Fehler" end
  
  local title = data.h2
  if data.strong then
    teaser = '\n'..data.strong
  else
    teaser = ''
  end
  if data.img then
    image_url = 'https:'..data.img.src
  end
  local text = '*'..title..'*'..teaser
  
  if data.img then
    return text, image_url
  else
    return text
  end
end

function heise:action(msg, config, matches)
  local article = URL.escape(matches[1])
  local text, image_url = heise:get_heise_article(article)
  if image_url then
    utilities.send_typing(msg.chat.id, 'upload_photo')
    local file = download_to_file(image_url, 'heise_teaser.jpg')
    utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
  end
  utilities.send_reply(msg, text, true)
end

return heise