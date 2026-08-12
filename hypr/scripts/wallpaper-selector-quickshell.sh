#!/bin/bash
# Wrapper para o qs-wallpaper-picker (Quickshell).
# Comportamento: se já estiver aberto, fecha graciosamente; senão, gera thumbnails e abre.

QS_DIR="$HOME/.config/quickshell/qs-wallpaper-picker"
LOCK_FILE="/tmp/qs-wallpaper-picker.lock"
QS_CMD="quickshell -p ${QS_DIR}/Main.qml"

# Fecha janela existente graciosamente via Hyprland
hyprctl dispatch closewindow title:wallpaper-picker 2>/dev/null || true
hyprctl dispatch closewindow class:wallpaper-picker 2>/dev/null || true

# Aguarda o quickshell encerrar naturalmente (evita janelas fantasmas)
for i in {1..10}; do
    if ! pgrep -f "quickshell -p ${QS_DIR}/Main\.qml" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done

# Se ainda persistir, mata à força
pkill -9 -f "quickshell -p ${QS_DIR}/Main\.qml" 2>/dev/null || true
pkill -9 -f "bash -c.*WALL_FILE=" 2>/dev/null || true
pkill -9 -f "matugen_reload\.sh" 2>/dev/null || true

rm -f "$LOCK_FILE"

# Gera/atualiza thumbnails e mapa
"$QS_DIR/scripts/generate_thumbs.sh"

# Abre nova instância
cd "$QS_DIR" || exit 1
exec quickshell -p "$QS_DIR/Main.qml"
