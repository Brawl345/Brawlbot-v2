#!/bin/sh
# Launch Brawlbot
# Restart Brawlbot five seconds after halted.
while true; do
    lua main.lua
    echo 'otouto has stopped. ^C to exit.'
    sleep 5s
done
