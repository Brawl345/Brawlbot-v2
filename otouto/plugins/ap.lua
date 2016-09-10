local ap = {}

ap.triggers = {
  "hosted.ap.org/dynamic/stories/(.+)"
}

function ap:get_article(article)
  local url = 'http://hosted.ap.org/dynamic/stories/'..article
  local res, code = http.request(url)
  if code ~= 200 then return 'HTTP-Fehler '..code..' ist aufgetreten.' end
  
  local headline = res:match('<span class%=\"headline entry%-title\">(.-)</span>')
  if not headline then return end
  
  -- TODO: How to match all occurences? AP uses the same class for all paragraphs
  -- but string.match only returns the first one oO
  local article = unescape(utilities.trim(res:match('<p class%=\"ap%-story%-p\">(.-)</p>')))
  
  local pic_url = res:match('<img src%=\"(/photos/.-)" alt%=\"AP Photo\"')
  
  local text = '<b>'..headline..'</b>\n'..article
  return text, pic_url
end

function ap:action(msg, config, matches)
  local article_id = matches[1]
  local article, pic = ap:get_article(article_id)
  if not article then
    utilities.send_reply(msg, config.errors.connection)
	return
  end
  
  if pic then
    local pic = pic:gsub('-small', '-big')
    local photo = download_to_file('http://hosted.ap.org'..pic)
    utilities.send_photo(msg.chat.id, photo, nil, msg.message_id)
  end
  utilities.send_reply(msg, article, 'HTML')
end

return ap