local pasteee = {}

function pasteee:init(config)
	if not cred_data.pasteee_key then
		print('Missing config value: pasteee_key.')
		print('pasteee.lua will not be enabled, listquotes won\'t be available.')
		return
	end
	
    pasteee.triggers = {
    "^/pasteee (.*)$"
	}
	pasteee.doc = [[*
]]..config.cmd_pat..[[pasteee* _<Text>_: Postet Text auf Paste.ee]]
end

pasteee.command = 'pasteee <Text>'

local key = cred_data.pasteee_key

function upload(text, noraw)
  local url = "https://paste.ee/api"
  local pet = post_petition(url, 'key='..key..'&paste='..text..'&format=json')
  if pet.status ~= 'success' then return 'Ein Fehler ist aufgetreten: '..pet.error, true end
  if noraw then
    return pet.paste.link
  else
    return pet.paste.raw
  end
end

function pasteee:action(msg, config, matches)
  local text = matches[1]
  local link, iserror = upload(text)
  if iserror then
    utilities.send_reply(msg, link)
	return
  end
  utilities.send_reply(msg, '[Text auf Paste.ee ansehen]('..link..')', true)
end

return pasteee