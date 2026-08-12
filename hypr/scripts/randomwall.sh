#!/bin/bash

IMG1="$HOME/Pictures/wallpapers/wallpaper.webp"
IMG2="$HOME/Pictures/wallpapers/wallpaper2.png"

if swww query | grep -q "wallpaper2.png"; then
    swww img "$IMG1" --transition-type grow
else
    swww img "$IMG2" --transition-type grow
fi
