local leave_group = {}

leave_group.triggers = {
  '^//tgservice group_chat_created$',
  '^//tgservice supergroup_chat_created$'
}

local report_to_admin = true -- set to false to not be notified, when Bot leaves groups without you

function leave_group:check_for_admin(msg, config)
  local result = bindings.request('getChatMember', {
		chat_id = msg.chat.id,
		user_id = config.admin
	} )
  if not result.ok then
    print('Konnte nicht prüfen, ob Admin in Gruppe ist! Verlasse sie sicherheitshalber...')
	return false
  end
  if result.result.status ~= "member" and result.result.status ~= "administrator" and result.result.status ~= "creator" then
    return false
  else
    return true
  end
end

function leave_group:action(msg, config)
  if not is_service_msg(msg) then return end -- Bad attempt at trolling!
  local admin_in_group = leave_group:check_for_admin(msg, config)
  if not admin_in_group then
	print('Admin ist nicht in der Gruppe, verlasse sie deshalb...')
	utilities.send_reply(msg, 'Dieser Bot wurde in eine fremde Gruppe hinzugefügt. Dies wird gemeldet!\nThis bot was added to foreign group. This incident will be reported!')
	local result = bindings.request('leaveChat', {
	  chat_id = msg.chat.id
	} )
	local chat_name = msg.chat.title
	local chat_id = msg.chat.id
	local from = msg.from.name
	local from_id = msg.from.id
	if report_to_admin then
	  utilities.send_message(config.admin, '#WARNUNG: Bot wurde in fremde Gruppe hinzugefügt:\nGruppenname: '..chat_name..' ('..chat_id..')\nHinzugefügt von: '..from..' ('..from_id..')')
	end
  end
end

return leave_group
