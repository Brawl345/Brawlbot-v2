local entergroup = {}

entergroup.triggers = {
  '^//tgservice (new_chat_member)$',
  '^//tgservice (left_chat_member)$'
}

function entergroup:chat_new_user(msg, self)
  local user_name = msg.new_chat_member.first_name
  local chat_title = msg.chat.title
  if msg.from.username then
    at_name = ' (@'..msg.from.username..')'
  else
    at_name = ''
  end
  if msg.from.id == msg.new_chat_member.id then -- entered through link
    added_by = ''
  else
    added_by = '\n'..msg.from.name..at_name..' hat dich hinzugefügt!'
  end
  if msg.new_chat_member.id == self.info.id then -- don't say hello to ourselves
    return
  end
  local text = 'Hallo '..user_name..', willkommen bei <b>'..chat_title..'</b>!'..added_by
  utilities.send_reply(msg, text, 'HTML')
end

function entergroup:chat_del_user(msg)
  if msg.left_chat_member.id == msg.from.id then -- silent ignore, if user wasn't kicked
    return
  end
  local user_name = msg.left_chat_member.first_name
  if msg.from.username then
    at_name = ' (@'..msg.from.username..')'
  else
    at_name = ''
  end
  local text = '<b>'..user_name..'</b> wurde von <b>'..msg.from.first_name..'</b>'..at_name..' aus der Gruppe gekickt.'
  utilities.send_reply(msg, text, 'HTML')
end

function entergroup:action(msg, config, matches)
  if not is_service_msg(msg) then return end -- Bad attempt at trolling!
  
  if matches[1] == 'new_chat_member' then
    entergroup:chat_new_user(msg, self)
  elseif matches[1] == 'left_chat_member'then
    entergroup:chat_del_user(msg)
  end
end

return entergroup
