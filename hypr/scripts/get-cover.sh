#!/bin/bash

TITLE="$1"
ARTIST="$2"

QUERY=$(python - <<EOF
import urllib.parse
print(urllib.parse.quote("$ARTIST $TITLE"))
EOF
)

URL="https://itunes.apple.com/search?term=$QUERY&entity=song&limit=1"

COVER=$(curl -s "$URL" | jq -r '.results[0].artworkUrl100 // empty')

if [ -z "$COVER" ]; then
  exit 0
fi

COVER_HD="${COVER/100x100/500x500}"

FILE="/tmp/eww_music_cover.jpg"

curl -s "$COVER_HD" -o "$FILE"

echo "$FILE"
