local yourls = {}

function yourls:init(config)
  if not cred_data.yourls_site_url then
    print('Missing config value: yourls_site_url.')
    print('yourls.lua will not be enabled.')
    return
  elseif not cred_data.yourls_signature_token then
    print('Missing config value: yourls_signature_token.')
    print('yourls.lua will not be enabled.')
    return
  end

  yourls.triggers = {
	"^/yourls (https?://[%w-_%.%?%.:/%+=&]+)"
  }
end

local SITE_URL = cred_data.yourls_site_url
local signature = cred_data.yourls_signature_token
local BASE_URL = SITE_URL..'/yourls-api.php'

function yourls:prot_url(url)
   local url, h = string.gsub(url, "http://", "")
   local url, hs = string.gsub(url, "https://", "")
   local protocol = "http"
   if hs == 1 then
      protocol = "https"
   end
   return url, protocol
end

function yourls:create_yourls_link(long_url, protocol)
  local url = BASE_URL..'?format=simple&signature='..signature..'&action=shorturl&url='..long_url
  if protocol == "http" then
    link,code  = http.request(url)
  else
    link,code  = https.request(url)
  end
  if code ~= 200 then
    link = 'Ein Fehler ist aufgetreten. '..link
  end
  return link
end

function yourls:action(msg, config, matches)
  local long_url = matches[1]
  local baseurl, protocol = yourls:prot_url(SITE_URL)
  utilities.send_reply(self, msg, yourls:create_yourls_link(long_url, protocol))
  return
end

return yourls
