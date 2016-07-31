local tweet = {}

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
      "^/tweet (id) ([%w_%.%-]+)$",
      "^/tweet (id) ([%w_%.%-]+) (last)$",
      "^/tweet (id) ([%w_%.%-]+) (last) ([%d]+)$",
      "^/tweet (name) ([%w_%.%-]+)$",
      "^/tweet (name) ([%w_%.%-]+) (last)$",
      "^/tweet (name) ([%w_%.%-]+) (last) ([%d]+)$"
	}
	tweet.doc = [[*
]]..config.cmd_pat..[[tweet* id _[id]_: Zufälliger Tweet vom User mit dieser ID
*]]..config.cmd_pat..[[tweet* id _[id]_ last: Aktuellster Tweet vom User mit dieser ID
*]]..config.cmd_pat..[[tweet* name _[Name]_: Zufälliger Tweet vom User mit diesem Namen
*]]..config.cmd_pat..[[tweet* name _[Name]_ last: Aktuellster Tweet vom User mit diesem Namen]]
end

tweet.command = 'tweet name <User>'

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

local twitter_url = "https://api.twitter.com/1.1/statuses/user_timeline.json"

function tweet:analyze_tweet(tweet)
   local header = "Tweet von " .. tweet.user.name .. " (@" .. tweet.user.screen_name .. ")\nhttps://twitter.com/statuses/" .. tweet.id_str
   local text = tweet.text

   -- replace short URLs
   if tweet.entities.urls then
      for k, v in pairs(tweet.entities.urls) do
         local short = v.url
         local long = v.expanded_url
         text = text:gsub(short, long)
      end
   end

   -- remove urls
   local urls = {}
   if tweet.extended_entities and tweet.extended_entities.media then
      for k, v in pairs(tweet.extended_entities.media) do
         if v.video_info and v.video_info.variants then  -- If it's a video!
            table.insert(urls, v.video_info.variants[1].url)
         else -- If not, is an image
            table.insert(urls, v.media_url)
         end
         text = text:gsub(v.url, "")  -- Replace the URL in text
		 text = unescape(text)
      end
   end

   return header, text, urls
end

function tweet:send_all_files(self, msg, urls)
   local data = {
      images = {
         func = send_photos_from_url,
         urls = {}
      },
      gifs = {
         func = send_gifs_from_url,
         urls = {}
      },
      videos = {
         func = send_videos_from_url,
         urls = {}
      }
   }

   local table_to_insert = nil
   for i,url in pairs(urls) do
      local _, _, extension = string.match(url, "(https?)://([^\\]-([^\\%.]+))$")
      local mime_type = mimetype.get_content_type_no_sub(extension)
      if extension == 'gif' then
         table_to_insert = data.gifs.urls
      elseif mime_type == 'image' then
         table_to_insert = data.images.urls
      elseif mime_type == 'video' then
         table_to_insert = data.videos.urls
      else
         table_to_insert = nil
      end
      if table_to_insert then
         table.insert(table_to_insert, url)
      end
   end
   for k, v in pairs(data) do
      if #v.urls > 0 then
      end
      v.func(receiver, v.urls)
   end
end

function tweet:sendTweet(self, msg, tweet)
   local header, text, urls = tweet:analyze_tweet(tweet)
   -- send the parts
   local text = unescape(text)
   send_reply(self, msg,  header .. "\n" .. text)
   tweet:send_all_files(self, msg, urls)
   return nil
end

function tweet:getTweet(self, msg, base, all)
   local response_code, response_headers, response_status_line, response_body = client:PerformRequest("GET", twitter_url, base)

   if response_code ~= 200 then
      return "Konnte nicht verbinden, evtl. existiert der User nicht?"
   end

   local response = json.decode(response_body)
   if #response == 0 then
      return "Konnte keinen Tweet bekommen, sorry"
   end
   if all then
      for i,tweet in pairs(response) do
         tweet:sendTweet(self, msg, tweet)
      end
   else
      local i = math.random(#response)
      local tweet = response[i]
      tweet:sendTweet(self, msg, tweet)
   end

   return nil
end

function tweet:isint(n)
  return n==math.floor(n)
end

function tweet:action(msg, config, matches)
   local base = {include_rts = 1}

   if matches[1] == 'id' then
      local userid = tonumber(matches[2])
      if userid == nil or not tweet:isint(userid) then
	     utilities.send_reply(self, msg, "Die ID eines Users ist eine Zahl, du findest sie, indem du den Namen [auf dieser Webseite](http://gettwitterid.com/) eingibst.", true)
         return
      end
      base.user_id = userid
   elseif matches[1] == 'name' then
      base.screen_name = matches[2]
   else
      return ""
   end

   local count = 200
   local all = false
   if #matches > 2 and matches[3] == 'last' then
      count = 1
      if #matches == 4 then
         local n = tonumber(matches[4])
         if n > 10 then
		    utilities.send_reply(self, msg, "Du kannst nur 10 Tweets auf einmal abfragen!")
            return
         end
         count = matches[4]
         all = true
      end
   end
   base.count = count

   utilities.send_reply(self, msg, tweet:getTweet(self, msg, base, all))
end

return tweet
