local hackernews = {}

hackernews.triggers = {
  "news.ycombinator.com/item%?id=(%d+)"
}

local BASE_URL = 'https://hacker-news.firebaseio.com/v0'

function hackernews:send_hackernews_post (hn_code)
  local url = BASE_URL..'/item/'..hn_code..'.json'
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res)
  
  local by = data.by
  local title = data.title
  
  if data.url then
    url = '\n[Link besuchen]('..data.url..')'
  else
    url = ''
  end

  if data.text then
    post = '\n'..unescape_html(data.text)
	post = string.gsub(post, '<p>', ' ')
  else
    post = ''
  end
  local text = '*'..title..'* von _'..by..'_'..post..url
  
  return text
end

function hackernews:action(msg, config, matches)
  local hn_code = matches[1]
  utilities.send_reply(self, msg, hackernews:send_hackernews_post(hn_code), true)
end

return hackernews
