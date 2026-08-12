#!/bin/bash
# Retorna o nome da música atual para a barra do Waybar

status=$(playerctl status 2>/dev/null)
if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
    echo ""
    exit 0
fi

title=$(playerctl metadata title 2>/dev/null)
artist=$(playerctl metadata artist 2>/dev/null)

if [ -z "$title" ]; then
    echo ""
    exit 0
fi

# Trunca se ficar muito grande
max_len=45
full=""
if [ -n "$artist" ]; then
    full="$title - $artist"
else
    full="$title"
fi

if [ "${#full}" -gt "$max_len" ]; then
    full="${full:0:$max_len}…"
fi

echo "$full"
