#!/bin/bash
QS_DIR="$HOME/.config/quickshell/qs-calendar-popup"
FLAG_FILE="/tmp/qs-calendar-popup-visible"

# Ensure the flag file exists
[ -f "$FLAG_FILE" ] || echo 0 > "$FLAG_FILE"

is_running() {
    pgrep -f "quickshell -p ${QS_DIR}/Main\.qml" >/dev/null 2>&1
}

start_hidden() {
    echo 0 > "$FLAG_FILE"
    if ! is_running; then
        cd "$QS_DIR" || exit 1
        nohup quickshell -p "$QS_DIR/Main.qml" --no-duplicate >/tmp/qs-calendar-popup.log 2>&1 &
        disown
    fi
}

toggle() {
    if ! is_running; then
        start_hidden
        sleep 0.4
    fi
    current=$(cat "$FLAG_FILE" 2>/dev/null || echo 0)
    if [ "$current" = "1" ]; then
        echo 0 > "$FLAG_FILE"
    else
        echo 1 > "$FLAG_FILE"
    fi
}

case "${1:-}" in
    --start-hidden)
        start_hidden
        ;;
    *)
        toggle
        ;;
esac
