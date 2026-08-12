#!/bin/bash
# Uso: minimize-all.sh hide   -> guarda o workspace atual e vai pra um
#                                workspace vazio (efeito "mostrar área
#                                de trabalho")
#      minimize-all.sh show   -> volta pro workspace guardado. O
#                                workspace vazio some sozinho (o
#                                Hyprland destrói workspaces vazios ao
#                                sair deles).
#
# Nota: nesta versão do Hyprland (config em Lua, v0.55+), "hyprctl
# dispatch" pela CLI espera uma expressão Lua (hl.dsp.*) em vez do
# formato clássico "dispatcher,args".

STATE_FILE="/tmp/minimize-all-origin-ws"
SCRATCH_WS="9999"

MODE="${1:?uso: minimize-all.sh hide|show}"

case "$MODE" in
    hide)
        WS=$(hyprctl activeworkspace -j | jq -r '.id')
        # já estamos no workspace de "área de trabalho vazia"? não faz nada
        [ "$WS" = "$SCRATCH_WS" ] && exit 0
        echo "$WS" > "$STATE_FILE"
        hyprctl dispatch "hl.dsp.focus({ workspace = \"${SCRATCH_WS}\" })" >/dev/null
        ;;
    show)
        ORIGIN="1"
        [ -f "$STATE_FILE" ] && ORIGIN=$(cat "$STATE_FILE")
        hyprctl dispatch "hl.dsp.focus({ workspace = \"${ORIGIN}\" })" >/dev/null
        ;;
    *)
        echo "uso: minimize-all.sh hide|show" >&2
        exit 1
        ;;
esac
