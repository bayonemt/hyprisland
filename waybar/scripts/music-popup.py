#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
POPUP_SCRIPT = SCRIPT_DIR / "music_popup.py"
LOCK_FILE = Path("/tmp/music-popup.lock")


def close_existing_windows():
    """Fecha janelas existentes do popup via Hyprland."""
    try:
        subprocess.run(
            ["hyprctl", "dispatch", "closewindow", "class:music-popup"],
            capture_output=True,
            timeout=3,
        )
    except Exception:
        pass


def kill_existing_processes():
    """Mata processos Python do popup."""
    marker = "waybar/scripts/music_popup.py"
    try:
        result = subprocess.run(
            ["pgrep", "-f", marker],
            capture_output=True,
            text=True,
        )
        for line in result.stdout.splitlines():
            try:
                pid = int(line.strip())
                if pid != os.getpid():
                    os.kill(pid, signal.SIGTERM)
            except (ValueError, ProcessLookupError):
                pass
    except Exception:
        pass


def main():
    close_existing_windows()
    time.sleep(0.2)
    kill_existing_processes()
    time.sleep(0.2)

    try:
        LOCK_FILE.unlink()
    except FileNotFoundError:
        pass

    subprocess.Popen([sys.executable, str(POPUP_SCRIPT)])


if __name__ == "__main__":
    main()
