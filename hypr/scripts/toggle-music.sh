#!/bin/bash

if eww active-windows | grep -q music_popup; then
  eww close music_popup
else
  TITLE=$(playerctl metadata title)
  ARTIST=$(playerctl metadata artist)

  COVER=$(/home/pedro/.config/hypr/scripts/get-cover.sh "$TITLE" "$ARTIST")

  eww update music_title="$TITLE"
  eww update music_artist="$ARTIST"
  eww update music_cover="$COVER"

  eww open music_popup
fi
