local hello = {}

hello.triggers = {
  "^[Ss][Aa][Gg] [Hh][Aa][Ll][Ll][Oo] [Zz][Uu] (.*)$"
}

function hello:action(msg, config, matches)
  utilities.send_reply(self, msg, 'Hallo, '..matches[1]..'!')
end

return hello
