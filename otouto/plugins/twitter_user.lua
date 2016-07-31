local twitter_user = {}

function twitter_user:init(config)
	if not cred_data.tw_consumer_key then
		print('Missing config value: tw_consumer_key.')
		print('twitter_user.lua will not be enabled.')
		return
	elseif not cred_data.tw_consumer_secret then
		print('Missing config value: tw_consumer_secret.')
		print('twitter_user.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token then
		print('Missing config value: tw_access_token.')
		print('twitter_user.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token_secret then
		print('Missing config value: tw_access_token_secret.')
		print('twitter_user.lua will not be enabled.')
		return
	end
	
	twitter_user.triggers = {
	  "twitter.com/([A-Za-z0-9-_-.-_-]+)$"
	}
end

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

function twitter_user:resolve_url(url)
  local response_body = {}
  local request_constructor = {
    url = url,
    method = "HEAD",
    sink = ltn12.sink.table(response_body),
    headers = {},
    redirect = false
  }

  local ok, response_code, response_headers, response_status_line = http.request(request_constructor)
  if ok and response_headers.location then
    return response_headers.location
  else
    return url
  end
end

function twitter_user:action(msg)
  local twitter_url = "https://api.twitter.com/1.1/users/show/"..matches[1]..".json"
  local response_code, response_headers, response_status_line, response_body = client:PerformRequest("GET", twitter_url)
  local response = json.decode(response_body)
  if response_code ~= 200 then return end
  
  local full_name = response.name
  local user_name = response.screen_name
  if response.verified then
    user_name = user_name..' ✅'
  end
  if response.protected then
    user_name = user_name..' 🔒'
  end
  local header = full_name.. " (@" ..user_name.. ")\n"
  
  local description = unescape(response.description)
  if response.location then
    location = response.location
  else
    location = ''
  end
  if response.url and response.location ~= '' then
    url = ' | '..twitter_user:resolve_url(response.url)..'\n'
  elseif response.url and response.location == '' then
    url = twitter_user:resolve_url(response.url)..'\n'
  else
    url = '\n'
  end
  
  local body = description..'\n'..location..url
  
  local favorites = comma_value(response.favourites_count)
  local follower = comma_value(response.followers_count)
  local following = comma_value(response.friends_count)
  local statuses = comma_value(response.statuses_count)
  local footer = statuses..' Tweets, '..follower..' Follower, '..following..' folge ich, '..favorites..' Tweets favorisiert'
  
  local pic_url = string.gsub(response.profile_image_url_https, "normal", "400x400")
  utilities.send_typing(self, msg.chat.id, 'upload_photo')
  local file = download_to_file(pic_url)
  
  local text = header..body..footer
  if string.len(text) > 199 then -- can only send captions with < 200 characters
    utilities.send_photo(self, msg.chat.id, file, nil, msg.message_id)
	utilities.send_reply(self, msg, text)
	return
  else
    utilities.send_photo(self, msg.chat.id, file, text, msg.message_id)
	return
  end
end

return twitter_user
