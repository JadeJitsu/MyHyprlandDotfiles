#!/usr/bin/env bash
# Toggle the touchpad. State is a flag file that hyprland.lua reads when (re)loading its config;
# runtime `hl.device({ enabled = true })` via eval does not re-enable a disabled device, a reload does.
# Usage: touchpad-toggle.sh [on|off]   (no argument toggles)
flag="${XDG_RUNTIME_DIR:-/tmp}/touchpad-disabled"

case "$1" in
    on)  want=on ;;
    off) want=off ;;
    *)   [[ -e $flag ]] && want=on || want=off ;;
esac

if [[ $want == on ]]; then
    rm -f "$flag"; msg="Touchpad enabled"
else
    : > "$flag"; msg="Touchpad disabled"
fi
hyprctl reload >/dev/null
command -v notify-send >/dev/null && notify-send -t 1500 "$msg"
