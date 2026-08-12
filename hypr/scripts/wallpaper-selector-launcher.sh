#!/bin/bash
# Wrapper que garante que o wallpaper-selector sempre abra

SCRIPT="$HOME/.config/hypr/scripts/wallpaper-selector.py"
LOCK="/tmp/wallpaper-selector.lock"

# Fecha qualquer janela aberta
hyprctl dispatch closewindow class:wallpaper-selector >/dev/null 2>&1

# Mata processos pendentes
pgrep -f 'wallpaper-selector.py$' | xargs -r kill -9 2>/dev/null

# Remove lock obsoleto
rm -f "$LOCK"

# Aguarda um pouco
sleep 0.2

# Executa
exec "$SCRIPT"
