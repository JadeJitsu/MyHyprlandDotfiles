#!/usr/bin/env bash
# activity-status.sh — print the current activity name for the bar indicator.
#
# Reads the state file written by activity-switch.sh; if it's missing or
# stale, infers the activity from the focused workspace (same rules as the
# switcher). Prints e.g. "Work" or "Personal" on one line.
set -euo pipefail

# Keep in sync with activity-switch.sh
ACTIVITIES=(work personal)
declare -A ACTIVITY_WORKSPACES=(
    [work]="1 2 3 4"
    [personal]="5 6 7 8"
)
# Bar labels: the intervalCommand plugin's Material icon is static per
# instance, so the per-activity "icon" is an emoji embedded in the output.
# The emoji are UTF-8 literals on purpose: bash printf '\U...' prints the
# escape literally under the C locale, which is what DMS runs widgets with.
declare -A ACTIVITY_LABELS=(
    [work]="💼 Work"
    [personal]="🏠 Personal"
)

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprland-activity"
current="$(cat "$STATE_FILE" 2>/dev/null || true)"

if [[ -z "$current" || -z "${ACTIVITY_WORKSPACES[$current]:-}" ]]; then
    current=""
    active_ws="$(hyprctl -j activeworkspace | jq -r '.name // empty')"
    for a in "${ACTIVITIES[@]}"; do
        for w in ${ACTIVITY_WORKSPACES[$a]}; do
            if [[ "$w" == "$active_ws" ]]; then
                current="$a"
                break 2
            fi
        done
    done
    current="${current:-${ACTIVITIES[0]}}"
fi

# Unknown activity names fall back to a capitalized plain name.
echo "${ACTIVITY_LABELS[$current]:-${current^}}"
