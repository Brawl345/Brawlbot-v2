#!/bin/sh
# Run Brawlbot.
# If none, give an error and a friendly suggestion.
# If Lua was found, restart Brawlbot five seconds after halting each time.

if type lua5.2 >/dev/null 2>/dev/null; then
    while true; do
        lua5.2 main.lua
        echo "Brawlbot wurde angehalten. ^C zum Beenden."
        sleep 5s
    done
elif type lua >/dev/null 2>/dev/null; then
    while true; do
        lua main.lua
        echo "Brawlbot wurde angehalten. ^C zum Beenden."
        sleep 5s
    done
else
    echo "Lua nicht gefunden."
	echo "Falls du Ubuntu verwendest, führe vorher ./install-dependencies.sh aus."
fi
