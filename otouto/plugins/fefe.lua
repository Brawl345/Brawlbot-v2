local fefe = {}

fefe.triggers = {
  "blog.fefe.de/%?ts=%w%w%w%w%w%w%w%w"
}

function fefe:post(id)
  local url = 'https://'..id
  local results, code = https.request(url)
  if code ~= 200 then return "HTTP-Fehler" end
  if string.match(results, "No entries found.") then return "Eintrag nicht gefunden." end

  local line = string.sub( results, string.find(results, "<li><a href[^\n]+"))
  local text = line:gsub("<div style=.+", "")
  -- remove link at begin
  local text = text:gsub("<li><a href=\"%?ts=%w%w%w%w%w%w%w%w\">%[l]</a>", "")
  -- replace "<p>" with newline; "<b>" and "</b>" with "*"
  local text = text:gsub("<p>", "\n\n"):gsub("<p u>", "\n\n")
  -- format quotes and links markdown-like
  local text = text:gsub("<blockquote>", "\n\n> "):gsub("</blockquote>", "\n\n")

  return text
end

function fefe:action(msg, config, matches)
  utilities.send_reply(msg, fefe:post(matches[1]), 'HTML')
end

return fefe