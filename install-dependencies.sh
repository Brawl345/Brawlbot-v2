# Install Lua, Luarocks, and otouto dependencies. Works in Ubuntu, maybe Debian.
# Installs Lua 5.3 if Ubuntu 16.04. Otherwise, 5.2.

#!/bin/sh

if [ $(lsb_release -r | cut -f 2) == "16.04" ]; then
    luaver="5.3"
    rocklist="luasocket luasec multipart-post lpeg dkjson redis-lua fakeredis oauth xml feedparser serpent"
else
    luaver="5.2"
    rocklist="luasocket luasec multipart-post lpeg dkjson redis-lua fakeredis oauth xml feedparser serpent luautf8"
fi

echo "Dieses Skript ist für Ubuntu, es wird wahrscheinlich auch für Debian funktionieren."
echo "Dieses Skript benötigt Root-Rechte, um folgende Pakete zu installieren:"
echo "lua$luaver liblua$luaver-dev git libssl-dev fortune-mod fortunes redis-server unzip make"
echo "Es werden auch Root-Rechte benötigt, um LuaRocks in /usr/local/"
echo "mit den folgenden Rocks zu installieren:"
echo $rocklist
echo "Drücke ENTER, um fortzufahren, oder Strg-C zum Beenden."
read

sudo apt-get update
sudo apt-get install -y lua$luaver liblua$luaver-dev git libssl-dev fortune-mod fortunes redis-server unzip make
git clone http://github.com/keplerproject/luarocks
cd luarocks
./configure --lua-version=$luaver --versioned-rocks-dir --lua-suffix=$luaver
make build
sudo make install
for rock in $rocklist; do
    sudo luarocks-$luaver install $rock
done
sudo -k
cd ..
cp config.lua.example config.lua

echo "Vorgang beendet! Nutze ./launch.sh, um den Bot zu starten."
echo "Setze vorher dein Bot-Token in der config.lua."
