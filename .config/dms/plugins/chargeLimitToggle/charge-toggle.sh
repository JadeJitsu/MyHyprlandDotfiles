#!/bin/sh
# charge-toggle.sh — get/set/toggle the TUXEDO battery charge-end threshold
# via tccd's D-Bus interface (keeps tccd in sync; do not write sysfs directly).
#
# Usage:
#   charge-toggle.sh get          print current charge-end threshold (0-100)
#   charge-toggle.sh set <n>      set threshold to n, then print it
#   charge-toggle.sh toggle       100 -> 80, anything else -> 100; print "old -> new"
set -eu

DEST=com.tuxedocomputers.tccd
OBJPATH=/com/tuxedocomputers/tccd
IFACE=com.tuxedocomputers.tccd

get() {
    dbus-send --system --print-reply --dest="$DEST" "$OBJPATH" \
        "$IFACE.GetChargeEndThreshold" | awk '/^ *int32/ {print $2; exit}'
}

set_to() {
    dbus-send --system --print-reply --dest="$DEST" "$OBJPATH" \
        "$IFACE.SetChargeEndThreshold" "int32:$1" >/dev/null
}

case "${1:-}" in
    get)
        get
        ;;
    set)
        set_to "${2:?usage: charge-toggle.sh set <0-100>}"
        get
        ;;
    toggle)
        cur=$(get)
        next=$(( cur >= 100 ? 80 : 100 ))
        set_to "$next"
        echo "$cur -> $next"
        ;;
    *)
        echo "usage: $0 get|set <n>|toggle" >&2
        exit 2
        ;;
esac
