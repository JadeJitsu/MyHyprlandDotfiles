#!/usr/bin/env bash
# activity-switch.sh — KDE-Activities-style context switching for Hyprland.
#
# An "activity" is a named group of workspaces. Switching moves every window
# from the current activity's workspaces into the target activity's workspaces
# (paired by index: 1->5, 2->6, ...), then focuses the target's first workspace.
#
# Usage: activity-switch.sh <name|next>
# State (current activity): $XDG_RUNTIME_DIR/hyprland-activity
set -euo pipefail

# --- Activity definitions ---------------------------------------------------
# Add/rename activities here; keep the workspace lists the same length.
ACTIVITIES=(work personal)
declare -A ACTIVITY_WORKSPACES=(
    [work]="1 2 3 4"
    [personal]="5 6 7 8"
)
# -----------------------------------------------------------------------------

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprland-activity"
MAX_MOVES_PER_WORKSPACE=50 # safety valve against a stuck movewindow loop

usage() {
    echo "usage: activity-switch.sh <${ACTIVITIES[*]}|next>" >&2
    exit 1
}
[[ $# -eq 1 ]] || usage

target="$1"
current="$(cat "$STATE_FILE" 2>/dev/null || true)"

# Validate/infer the current activity: trust the state file, else infer from
# the focused workspace, else fall back to the first activity.
is_activity() { [[ -n "$1" && -n "${ACTIVITY_WORKSPACES[$1]:-}" ]]; }
if ! is_activity "$current"; then
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
    [[ -n "$current" ]] || current="${ACTIVITIES[0]}"
fi

if [[ "$target" == "next" ]]; then
    idx=-1
    for i in "${!ACTIVITIES[@]}"; do
        [[ "${ACTIVITIES[$i]}" == "$current" ]] && idx=$i
    done
    if (( idx < 0 )); then
        target="${ACTIVITIES[0]}"
    else
        target="${ACTIVITIES[(idx + 1) % ${#ACTIVITIES[@]}]}"
    fi
fi
is_activity "$target" || usage

# Clients report their monitor as a numeric id, so track the focused
# monitor's id (not its name).
mon="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .id' | head -n1)"
[[ -n "$mon" ]] || { echo "activity-switch: no focused monitor" >&2; exit 1; }

# This Hyprland version routes dispatches through the Lua API
# ("hyprctl dispatch <classic>" no longer works), so we eval the same
# hl.dsp calls the keybinds use. Workspace numbers refer to the focused
# monitor, which is the one we operate on.
focus_ws() { # <workspace number>
    hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $1 }))" >/dev/null
}
move_active_to() { # <workspace number>
    hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = $1 }))" >/dev/null
}
ws_count() { # <workspace number> -> number of windows on it (focused monitor)
    # Note: modern Hyprland renamed "hyprctl windows" to "hyprctl clients".
    local n
    n="$(hyprctl -j clients | jq --arg n "$1" --argjson m "$mon" \
        '[.[] | select(.workspace.name == $n and .monitor == $m)] | length')" || {
        echo "activity-switch: failed to query windows on workspace $1" >&2
        exit 1
    }
    echo "$n"
}

read -r -a src_list <<< "${ACTIVITY_WORKSPACES[$current]}"
read -r -a dst_list <<< "${ACTIVITY_WORKSPACES[$target]}"

if [[ "$target" != "$current" ]]; then
    for i in "${!src_list[@]}"; do
        s="${src_list[$i]}"
        d="${dst_list[$i]}"
        (( $(ws_count "$s") > 0 )) || continue

        # Ensure the destination workspace exists on this monitor, then move
        # windows over one at a time (window.move acts on the active window).
        focus_ws "$d"

        moves=0
        while (( $(ws_count "$s") > 0 && moves < MAX_MOVES_PER_WORKSPACE )); do
            focus_ws "$s"
            move_active_to "$d"
            moves=$((moves + 1))
        done
        (( moves < MAX_MOVES_PER_WORKSPACE )) || {
            echo "activity-switch: hit move limit on workspace $s, aborting" >&2
            exit 1
        }
    done
fi

# Land on the first workspace of the target activity.
focus_ws "${dst_list[0]}"
echo "$target" > "$STATE_FILE"
dms notify "Activity" "$target" 2>/dev/null || notify-send "Activity" "$target" 2>/dev/null || true
