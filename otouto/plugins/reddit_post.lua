local reddit_post = {}

reddit_post.triggers = {
  "reddit.com/r/([A-Za-z0-9-/-_-.]+)/comments/([A-Za-z0-9-/-_-.]+)"
}

local BASE_URL = 'https://www.reddit.com'

function reddit_post:get_reddit_data(subreddit, reddit_code)
  local url = BASE_URL..'/r/'..subreddit..'/comments/'..reddit_code..'.json'
  local res,code  = https.request(url)
  if code ~= 200 then return nil end
  local data = json.decode(res)
  return data
end

function reddit_post:send_reddit_data(data)
  local title = utilities.md_escape(data[1].data.children[1].data.title)
  local author = utilities.md_escape(data[1].data.children[1].data.author)
  local subreddit = utilities.md_escape(data[1].data.children[1].data.subreddit)
  if string.len(data[1].data.children[1].data.selftext) > 300 then
    selftext = string.sub(unescape(data[1].data.children[1].data.selftext:gsub("%b<>", "")), 1, 300) .. '...'
  else
    selftext = unescape(data[1].data.children[1].data.selftext:gsub("%b<>", ""))
  end
  if not data[1].data.children[1].data.is_self then
    url = data[1].data.children[1].data.url
  else
    url = ''
  end
  local score = comma_value(data[1].data.children[1].data.score)
  local comments = comma_value(data[1].data.children[1].data.num_comments)
  local text = '*'..author..'* in */r/'..subreddit..'* _('..score..' Upvotes - '..comments..' Kommentare)_:\n'..title..'\n'..selftext..url
  return text
end


function reddit_post:action(msg, config, matches)
  local subreddit = matches[1]
  local reddit_code = matches[2]
  local data = reddit_post:get_reddit_data(subreddit, reddit_code)
  if not data then utilities.send_reply(self, msg, config.errors.connection) return end
  
  local text = reddit_post:send_reddit_data(data)
  if not text then utilities.send_reply(self, msg, config.errors.connection) return end
  
  utilities.send_reply(self, msg, text, true)
end

return reddit_post
