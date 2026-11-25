#!/bin/sh
# Mirrors Hyprland's per-instance logs from tmpfs (/run/user/1000/hypr/) to
# persistent storage every 2s, so a black-screen failure + reboot doesn't
# destroy the only diagnostic evidence. Started by hypr-log-saver.service.
DEST="$HOME/hypr-logs"
mkdir -p "$DEST"
while :; do
    for f in /run/user/1000/hypr/*/hyprland.log; do
        [ -f "$f" ] || continue
        inst=$(basename "$(dirname "$f")")
        cp -u "$f" "$DEST/$inst-hyprland.log" 2>/dev/null
    done
    sleep 2
done
