local github = {}

function github:init(config)
    github.triggers = {
      "github.com/([A-Za-z0-9-_-.-._.]+)/([A-Za-z0-9-_-.-._.]+)/commit/([a-z0-9-]+)",
      "github.com/([A-Za-z0-9-_-.-._.]+)/([A-Za-z0-9-_-.-._.]+)/?$"
	}
end

local BASE_URL = 'https://api.github.com'

function github:get_gh_data(gh_code, gh_commit_sha)
  if gh_commit_sha == nil then
    url = BASE_URL..'/repos/'..gh_code
  else
    url = BASE_URL..'/repos/'..gh_code..'/git/commits/'..gh_commit_sha
  end
  local res,code  = https.request(url)
  if code ~= 200 then return "HTTP-FEHLER" end
  local data = json.decode(res)
  return data
end

function github:send_github_data(data)
  if not data.owner then return nil end
  local name = '<b>'..data.name..'</b>'
  local description = '<i>'..data.description..'</i>'
  local owner = data.owner.login
  local clone_url = data.clone_url
  if data.language == nil or data.language == "" then
    language = ''
  else
    language = '\nSprache: '..data.language
  end
  if data.open_issues_count == 0 then
    issues = ''
  else
    issues = '\nOffene Bugreports: '..data.open_issues_count
  end
  if data.homepage == nil or data.homepage == "" then
    homepage = ''
  else
    homepage = '\n<a href="'..data.homepage..'">Homepage besuchen</a>'
  end
  local text = name..' von '..owner..'\n'..description..'\n<pre>git clone '..clone_url..'</pre>'..language..issues..homepage
  return text
end

function github:send_gh_commit_data(gh_code, gh_commit_sha, data)
  if not data.author then return nil end
  local author = data.author.name
  local message = utilities.md_escape(data.message)
  local text = '<code>'..gh_code..'@'..gh_commit_sha..'</code> von <b>'..author..'</b>:\n'..message
  return text
end

function github:action(msg, config, matches)
  local gh_code = matches[1]..'/'..matches[2]
  local gh_commit_sha = matches[3]
  local data = github:get_gh_data(gh_code, gh_commit_sha)
  if not gh_commit_sha then
    output = github:send_github_data(data)
  else
    output = github:send_gh_commit_data(gh_code, gh_commit_sha, data)
  end
  utilities.send_reply(msg, output, 'HTML')
end

return github