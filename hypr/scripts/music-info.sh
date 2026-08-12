#!/bin/bash

playerctl metadata --format '{
"title": "{{title}}",
"artist": "{{artist}}",
"artUrl": "{{mpris:artUrl}}"
}'
