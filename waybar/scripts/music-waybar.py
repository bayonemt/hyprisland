#!/usr/bin/env python3
"""Retorna o nome da música atual para o módulo custom/music da Waybar."""

import subprocess
import sys


def run(args):
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=5
        ).stdout.strip()
    except Exception:
        return ""


def get_player_list():
    out = run(["playerctl", "-l"])
    return [p for p in out.splitlines() if p.strip()] if out else []


def get_status(player):
    return run(["playerctl", "status", "-p", player])


def get_metadata(key, player):
    return run(["playerctl", "metadata", "-p", player, key])


def main():
    players = get_player_list()
    if not players:
        print("")
        return

    # Prioriza player que está tocando
    active_player = None
    for p in players:
        if get_status(p) == "Playing":
            active_player = p
            break

    # Se nenhum Playing, usa o primeiro Paused
    if not active_player:
        for p in players:
            if get_status(p) == "Paused":
                active_player = p
                break

    # Último recurso: primeiro player da lista
    if not active_player:
        active_player = players[0]

    status = get_status(active_player)
    if status not in ("Playing", "Paused"):
        print("")
        return

    title = get_metadata("title", active_player)
    artist = get_metadata("artist", active_player)

    if not title:
        print("")
        return

    full = f"{title} - {artist}" if artist else title
    if len(full) > 45:
        full = full[:44] + "…"

    print(full)


if __name__ == "__main__":
    main()
