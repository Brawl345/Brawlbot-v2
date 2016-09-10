#!/bin/sh
# Installiert Lua, Luarocks und andere Abhängigkeiten. Sollte auch auf Debian funktionieren.

rocklist="luasocket luasec multipart-post lpeg dkjson redis-lua fakeredis oauth xml feedparser serpent luautf8"

echo "Dieses Skript ist für Ubuntu, es wird wahrscheinlich auch für Debian funktionieren."
echo "Dieses Skript benötigt Root-Rechte, um folgende Pakete zu installieren:"
echo "lua5.2 liblua5.2-dev git libssl-dev fortune-mod fortunes redis-server unzip make"
echo "Es werden auch Root-Rechte benötigt, um LuaRocks in /usr/local/"
echo "mit den folgenden Rocks zu installieren:"
echo $rocklist
echo "Drücke ENTER, um fortzufahren, oder Strg-C zum Beenden."
read smth

sudo apt-get update
sudo apt-get install -y lua5.2 liblua5.2-dev git libssl-dev fortune-mod fortunes redis-server unzip make
git clone http://github.com/keplerproject/luarocks
cd luarocks
./configure --lua-version=5.2 --versioned-rocks-dir --lua-suffix=5.2
make build
sudo make install
for rock in $rocklist; do
    sudo luarocks-5.2 install $rock
done
sudo -k
cd ..

echo "Vorgang beendet! Nutze ./launch.sh, um den Bot zu starten."
echo "Setze vorher dein Bot-Token in der config.lua.example und kopiere sie nach config.lua."
