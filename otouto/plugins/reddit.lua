local reddit = {}

reddit.command = 'reddit [r/subreddit | Suchbegriff]'

function reddit:init(config)
	reddit.triggers = utilities.triggers(self.info.username, config.cmd_pat, {'^/r/'}):t('reddit', true):t('r', true):t('r/', true).table
	reddit.doc = [[*
]]..config.cmd_pat..[[r* _[r/subreddit | Suchbegriff]_: Gibt Top-Posts oder Ergebnisse eines Subreddits aus. Wenn kein Argument gegeben ist, wird /r/all genommen.]]
end

local format_results = function(posts)
	local output = ''
	for _,v in ipairs(posts) do
		local post = v.data
		local title = post.title:gsub('%[', '('):gsub('%]', ')'):gsub('&amp;', '&')
		if title:len() > 256 then
			title = title:sub(1, 253)
			title = utilities.trim(title) .. '...'
		end
		local short_url = 'https://redd.it/' .. post.id
		local s = '[' .. unescape(title) .. '](' .. short_url .. ')'
		if post.domain and not post.is_self and not post.over_18 then
			s = '`[`[' .. post.domain .. '](' .. post.url:gsub('%)', '\\)') .. ')`]` ' .. s
		end
		output = output .. '• ' .. s .. '\n'
	end
	return output
end

reddit.subreddit_url = 'https://www.reddit.com/%s/.json?limit='
reddit.search_url = 'https://www.reddit.com/search.json?q=%s&limit='
reddit.rall_url = 'https://www.reddit.com/.json?limit='

function reddit:action(msg, config)
	-- Eight results in PM, four results elsewhere.
	local limit = 4
	if msg.chat.type == 'private' then
		limit = 8
	end
	local text = msg.text_lower
	if text:match('^/r/.') then
		-- Normalize input so this hack works easily.
		text = msg.text_lower:gsub('^/r/', config.cmd_pat..'r r/')
	end
	local input = utilities.input(text)
	local source, url
	if input then
		if input:match('^r/.') then
			input = utilities.get_word(input, 1)
			url = reddit.subreddit_url:format(input) .. limit
			source = '*/' .. utilities.md_escape(input) .. '*\n'
		else
			input = utilities.input(msg.text)
			source = '*Ergebnisse für* _' .. utilities.md_escape(input) .. '_ *:*\n'
			input = URL.escape(input)
			url = reddit.search_url:format(input) .. limit
		end
	else
		url = reddit.rall_url .. limit
		source = '*/r/all*\n'
	end
	local jstr, res = https.request(url)
	if res ~= 200 then
		utilities.send_reply(msg, config.errors.results)
	else
		local jdat = json.decode(jstr)
		if #jdat.data.children == 0 then
			utilities.send_reply(msg, config.errors.results)
		else
			local output = format_results(jdat.data.children)
			output = source .. output
			utilities.send_message(msg.chat.id, output, true, nil, true)
		end
	end
end

return reddit
