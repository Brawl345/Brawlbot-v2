#!/bin/bash
# Dieses Skript installiert den Bot auf Uberspace.
# Lua 5.2 (falls nicht vorhanden) und LuaRocks werden installiert und Redis wird gestartet,
# zudem wird die config.lua des Bots angepasst.
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $HOME

if [ -n "$1" ]; then
  echo "Überspringe Lua"
else
  # LUA 5.2
  if [ -d "/package/host/localhost/lua-5.2" ]; then
	echo "export PATH=/package/host/localhost/lua-5.2/bin:\$PATH" >> $HOME/.bash_profile
	INSTALLED_DIR="/package/host/localhost/lua-5.2"
  else
	echo "Dieser Uberspace hat kein Lua 5.2, kompiliere selbst..."
	wget https://www.lua.org/ftp/lua-5.2.4.tar.gz
	tar -xvf lua-5.2.*.tar.gz
	rm lua-5.2.*.tar.gz
	cd lua-5.2.*
	make linux
	if [ ! -f "src/lua" ]; then
	  echo "Kompilierung nicht erfolgreich. Breche ab..."
	  exit 1
	fi
	mkdir -p $HOME/lua5.2
	make install INSTALL_TOP=$HOME/lua5.2
	echo "export PATH=\$HOME/lua5.2/bin:\$PATH" >> $HOME/.bash_profile
	INSTALLED_DIR="$HOME/lua5.2"
  fi
  cd $HOME
  rm -rf lua-5.2.*
  source $HOME/.bash_profile
  echo "LUA 5.2 ist installiert!"
fi

cd $HOME

# LuaRocks
if [ -n "$2" ]; then
  echo "Überspringe LuaRocks"
else
  echo "Installiere LuaRocks"
  git clone http://github.com/keplerproject/luarocks luarocks-git
  cd luarocks-git
  ./configure --lua-version=5.2 --versioned-rocks-dir --with-lua=$INSTALLED_DIR --prefix=$HOME/luarocks
  make build
  make install
  if [ ! -f "$HOME/luarocks/bin/luarocks-5.2" ]; then
	  echo "Kompilierung nicht erfolgreich. Breche ab..."
	  exit 1
  fi
  echo "export PATH=\$HOME/luarocks/bin:\$PATH" >> $HOME/.bash_profile
  cd $HOME
  rm -rf luarocks-git
  source $HOME/.bash_profile
  luarocks-5.2 path >> $HOME/.bash_profile
  source $HOME/.bash_profile
  echo "Luarocks ist installiert!"
fi

cd $HOME

# LuaRocks-Module
if [ -n "$3" ]; then
  echo "Überspringe LuaRocks-Module"
else
  echo "Installiere LuaRocks-Module"
  rocklist="luasocket luasec multipart-post lpeg dkjson redis-lua fakeredis oauth xml feedparser serpent luautf8"
  for rock in $rocklist; do
    luarocks-5.2 install $rock --local
  done
  echo "Alle LuaRocks-Module wurden installiert!"
fi

cd $SCRIPTDIR

# Redis
if [ -n "$4" ]; then
  echo "Überspringe Redis"
else
  echo "Setze Redis auf"
  test -d ~/service || uberspace-setup-svscan
  uberspace-setup-redis 
  # Passe Config an
  NAME=$(whoami)
  sed s/"use_socket = false,"/"use_socket = true,"/ config.lua.example > config.lua
  sed -i s/"socket_path = 'unix:\/\/\/home\/path\/to\/your\/redis\/sock',"/"socket_path = \'unix:\/\/\/home\/$NAME\/.redis\/sock',"/g config.lua
  echo "Redis aufgesetzt!"
fi

echo "Alles fertig! Vergiss nicht, noch deinen Bot-Token und deine Telegram-ID in der config.lua zu ergänzen!"
echo "Führe bitte vorher noch einmal"
echo "source ~/.bash_profile"
echo "aus oder melde dich ab und wieder an."

exit 0
