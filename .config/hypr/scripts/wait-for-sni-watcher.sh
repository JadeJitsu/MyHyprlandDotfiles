#!/bin/bash
# Block until an org.kde.StatusNotifierWatcher (waybar's tray host) is
# registered on the session bus, then exec the given command.
#
# Replaces fixed `sleep N` delays for SNI tray clients launched via Hyprland
# exec-once. Those clients (e.g. arch-update-tray) don't wait/retry for the
# watcher themselves - if it isn't up yet at launch, they register nothing and
# exit silently, with zero trace in journalctl/dmesg. A sleep is a guess about
# waybar's init time, which varies with boot-time disk/CPU load (confirmed:
# `sleep 3` was enough on 2026-08-09 but lost the race on 2026-08-10 with no
# code change). Polling the actual condition, same pattern as wait-kwallet.sh,
# removes the guesswork.
until dbus-send --session --print-reply \
    --dest=org.freedesktop.DBus /org/freedesktop/DBus \
    org.freedesktop.DBus.NameHasOwner string:"org.kde.StatusNotifierWatcher" 2>/dev/null \
    | grep -q "boolean true"; do
    sleep 0.5
done
exec "$@"
