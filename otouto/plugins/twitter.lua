local twitter = {}

local utilities = require('otouto.utilities')
local HTTPS = require('ssl.https')
local JSON = require('dkjson')
local redis = (loadfile "./otouto/redis.lua")()
local OAuth = (require "OAuth")
local bindings = require('otouto.bindings')

function twitter:init(config)
	if not cred_data.tw_consumer_key then
		print('Missing config value: tw_consumer_key.')
		print('twitter.lua will not be enabled.')
		return
	elseif not cred_data.tw_consumer_secret then
		print('Missing config value: tw_consumer_secret.')
		print('twitter.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token then
		print('Missing config value: tw_access_token.')
		print('twitter.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token_secret then
		print('Missing config value: tw_access_token_secret.')
		print('twitter.lua will not be enabled.')
		return
	end
	
	twitter.triggers = {
		'twitter.com/[^/]+/statuse?s?/([0-9]+)'
	}
	twitter.doc = [[*Twitter-Link*: Postet Tweet]]
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

function twitter:action(msg)
  
  if not msg.text:match('twitter.com/[^/]+/statuse?s?/([0-9]+)') then
    return
  end
  local id = msg.text:match('twitter.com/[^/]+/statuse?s?/([0-9]+)')

  local twitter_url = "https://api.twitter.com/1.1/statuses/show/" .. id.. ".json"
  local response_code, response_headers, response_status_line, response_body = client:PerformRequest("GET", twitter_url)
  local response = JSON.decode(response_body)
  
  local full_name = response.user.name
  local user_name = response.user.screen_name
  if response.user.verified then
    verified = ' ✅'
  else
    verified = ''
  end
  -- MD: local header = 'Tweet von '..full_name..' ([@' ..user_name.. '](https://twitter.com/'..user_name..')'..verified..')\n'
  local header = 'Tweet von '..full_name..' (@' ..user_name..verified..')\n'
  
  local text = response.text
  
  -- favorites & retweets
  if response.retweet_count == 0 then
    retweets = ""
  else
    retweets = response.retweet_count..'x retweeted'
  end
  if response.favorite_count == 0 then
    favorites = ""
  else
    favorites = response.favorite_count..'x favorisiert'
  end
  if retweets == "" and favorites ~= "" then
    footer = favorites
  elseif retweets ~= "" and favorites == "" then
    footer = retweets
  elseif retweets ~= "" and favorites ~= "" then
    footer = retweets..' - '..favorites
  else
    footer = ""
  end
  
  -- replace short URLs
  if response.entities.urls then
    for k, v in pairs(response.entities.urls) do 
        local short = v.url
        local long = v.expanded_url
        text = text:gsub(short, long)
    end
  end

  -- remove images
  local images = {}
  local videos = {}
  if response.entities.media and response.extended_entities.media then
    for k, v in pairs(response.extended_entities.media) do
        local url = v.url
        local pic = v.media_url_https
		if v.video_info then
		  if not v.video_info.variants[3] then
		    local vid = v.video_info.variants[1].url
			table.insert(videos, vid)
		  else
		    local vid = v.video_info.variants[3].url
		    table.insert(videos, vid)
		  end
		end
        text = text:gsub(url, "")
        table.insert(images, pic)
    end
  end
  
    -- quoted tweet
  if response.quoted_status then
    local quoted_text = response.quoted_status.text
	local quoted_name = response.quoted_status.user.name
	local quoted_screen_name = response.quoted_status.user.screen_name
	if response.quoted_status.user.verified then
      quoted_verified = ' ✅'
    else
	  quoted_verified = ''
	end
	-- MD:	quote = 'Als Antwort auf '..quoted_name..' ([@' ..quoted_screen_name.. '](https://twitter.com/'..quoted_screen_name..')'..quoted_verified..'):\n'..quoted_text
	quote = 'Als Antwort auf '..quoted_name..' (@' ..quoted_screen_name..quoted_verified..'):\n'..quoted_text
	text = text..'\n\n'..quote..'\n'
  end
  
  -- send the parts 
  local text = unescape(text)
  utilities.send_reply(self, msg, header .. "\n" .. text.."\n"..footer)
  for k, v in pairs(images) do
    local file = download_to_file(v)
    bindings.sendPhoto(self, {chat_id = msg.chat.id}, {photo = file} )
	os.remove(file)
    print("Deleted: "..file)
  end
  for k, v in pairs(videos) do
    local file = download_to_file(v)
	bindings.sendVideo(self, {chat_id = msg.chat.id}, {video = file} )
	os.remove(file)
    print("Deleted: "..file)
  end
end

return twitter
