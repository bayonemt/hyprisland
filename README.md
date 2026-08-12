# hyprisland

My personal Hyprland + Waybar setup, built around a custom [Quickshell](https://quickshell.org/) popup that started as a "now playing" widget and grew into a small control-center hub with three tabs:

- **Música** — MPRIS player (art, title/artist, seek bar, shuffle/prev/play-pause/next/loop), reads whichever player is active via `Quickshell.Services.Mpris`.
- **Notificações** — `mako` notification history, with per-item and clear-all dismissal (mako has no native "delete from history" command, so removed ids are tracked in a small local watermark file).
- **Ajustes** — quick settings: volume slider + mute, mic mute, and a "não perturbar" toggle that flips a `mako` mode.

It's opened by clicking the small note icon in the waybar bar (`custom/music-popup` module), which toggles a flag file that a persistent Quickshell process polls.

## Layout

This mirrors `~/.config/`, so each top-level folder here maps 1:1 to a folder there:

```
waybar/       -> ~/.config/waybar
quickshell/   -> ~/.config/quickshell
hypr/         -> ~/.config/hypr
mako/         -> ~/.config/mako
```

### `quickshell/qs-music-popup/`

The hub widget itself:

- `Main.qml` — the `FloatingWindow`, polls a `/tmp/qs-music-popup-visible` flag file to show/hide.
- `HubPopup.qml` — tab bar (Música / Notif. / Ajustes) + fixed-size container for whichever tab is active.
- `MusicPopup.qml` — the MPRIS player tab.
- `NotificationsPanel.qml` — the notification history tab.
- `QuickSettingsPanel.qml` — the quick settings tab.

Toggled via `hypr/scripts/toggle-music-popup.sh`, launched at Hyprland startup (`exec-once` in `hyprland.conf`) with `--start-hidden`.

**Note on window sizing:** the popup window is a *fixed* size (`380x270`, set via `windowrulev2 = size ...` in `hyprland.conf`/`hyprland.lua`), not dynamically sized from QML content. I tried letting Quickshell's `implicitHeight` drive the actual window size and it wasn't reliable on this Hyprland setup — the live surface didn't reliably resize after the window was already mapped. If you reuse this and your tab content is taller/shorter, you'll need to recalculate and adjust that fixed size.

### `quickshell/qs-calendar-popup/`

A similar small popup showing a calendar, same toggle-via-flag-file pattern.

### Not included: `qs-wallpaper-picker`

`hyprland.conf` has window rules for a `wallpaper-picker` title, which come from [magetsu002/qs-wallpaper-picker](https://github.com/magetsu002/qs-wallpaper-picker) — a separate third-party Quickshell project I use, not my own code, so it's not duplicated in here. Grab it from its own repo if you want it.

## Dependencies

- [Hyprland](https://hyprland.org/)
- [Waybar](https://github.com/Alexays/Waybar)
- [Quickshell](https://quickshell.org/)
- [mako](https://github.com/emersion/mako) (notifications)
- `pactl` (PipeWire-Pulse) for the volume/mic controls in Ajustes
- `playerctl` (used by the older `waybar/scripts/*.py`/`.sh` helpers — the Quickshell music tab itself talks to MPRIS directly and doesn't need it)
- `python3` + `requests` if you want the legacy `waybar/scripts/music_popup.py` (GTK/PySide6 popup with synced lyrics, superseded by the Quickshell hub, kept for reference)

## Installing

Back up your existing configs first, then symlink (or copy) each folder:

```sh
ln -s ~/hyprisland/waybar ~/.config/waybar
ln -s ~/hyprisland/quickshell ~/.config/quickshell
ln -s ~/hyprisland/hypr ~/.config/hypr
ln -s ~/hyprisland/mako ~/.config/mako
```

Reload Hyprland (`hyprctl reload`) and restart Waybar/mako. Adjust the hardcoded window positions/sizes in `hypr/hyprland.conf` (`move`/`size` window rules) for your own monitor layout.

## Known rough edges

- `waybar/config.jsonc` defines `cpu`, `memory`, `temperature`, `network` and `battery` modules that aren't currently wired into `modules-left/center/right` — left there for reference/reuse.
- `waybar/scripts/music-popup.py`, `music_popup.py`, `music.sh`, `music-waybar.py` are the pre-Quickshell iterations of the music widget (bash/playerctl, then a PySide6 GTK popup with synced lyrics). Superseded by `quickshell/qs-music-popup/`, kept around for reference.
- This machine has no wifi/bluetooth adapter or controllable backlight, so the Ajustes tab intentionally doesn't have those toggles — add them yourself if your hardware has them (`nmcli`, `bluetoothctl`, `brightnessctl`/`ddcutil`).
