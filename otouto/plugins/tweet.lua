local tweet = {}

require('otouto/plugins/twitter')

tweet.command = 'tweet <Name>'

function tweet:init(config)
	if not cred_data.tw_consumer_key then
		print('Missing config value: tw_consumer_key.')
		print('tweet.lua will not be enabled.')
		return
	elseif not cred_data.tw_consumer_secret then
		print('Missing config value: tw_consumer_secret.')
		print('tweet.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token then
		print('Missing config value: tw_access_token.')
		print('tweet.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token_secret then
		print('Missing config value: tw_access_token_secret.')
		print('tweet.lua will not be enabled.')
		return
	end
	
	tweet.triggers = {
      "^/tweet ([%w_%.%-]+)$",
      "^/tweet ([%w_%.%-]+) (last)$"
	}
	tweet.doc = [[*
]]..config.cmd_pat..[[tweet* _<Name>_: Zufälliger Tweet vom User mit diesem Namen
*]]..config.cmd_pat..[[tweet* _<Name>_ _[last]_: Aktuellster Tweet vom User mit diesem Namen]]
end

local twitter_url = "https://api.twitter.com/1.1/statuses/user_timeline.json"

local consumer_key = cred_data.tw_consumer_key
local consumer_secret = cred_data.tw_consumer_secret
local access_token = cred_data.tw_access_token
local access_token_secret = cred_data.tw_access_token_secret

local client = OAuth.new(consumer_key, consumer_secret, {
    RequestToken = "https://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "https://api.twitter.com/oauth/access_token"
}, {
    OAuthToken = access_token,
    OAuthTokenSecret = access_token_secret
})

function tweet:get_random_tweet(base)
  local response_code, response_headers, response_status_line, response_body = client:PerformRequest("GET", twitter_url, base)
  if response_code ~= 200 then
    return "Konnte nicht verbinden, evtl. existiert der User nicht?"
  end

  local response = json.decode(response_body)
  if #response == 0 then
    return "Konnte keinen Tweet bekommen, sorry"
  end
  
  local i = math.random(#response)
  rand_tweet = response[i]
  return get_tweet(rand_tweet)
end

function tweet:action(msg, config, matches)
  utilities.send_typing(msg.chat.id, 'typing')
  local base = {tweet_mode = 'extended'}
  base.screen_name = matches[1]

  local count = 200
  local all = false
  if #matches > 1 and matches[2] == 'last' then
    count = 1
  end
  base.count = count

  local text, images, videos = tweet:get_random_tweet(base)
  if not images or not videos then
    utilities.send_reply(msg, text)
    return
  end
  
  -- send the parts 
  utilities.send_reply(msg, text, 'HTML')
  for k, v in pairs(images) do
    local file = download_to_file(v)
	utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
  end
  for k, v in pairs(videos) do
    local file = download_to_file(v)
	utilities.send_video(msg.chat.id, file, nil, msg.message_id)
  end
end

return tweet