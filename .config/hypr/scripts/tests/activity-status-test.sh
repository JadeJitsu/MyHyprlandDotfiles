#!/usr/bin/env bash
# Tests for activity-status.sh, run against the fake hyprctl in fakebin/.
# Usage: ./activity-status-test.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../activity-status.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export FAKE_HYPRLAND_STATE="$tmp/state.json"
export FAKE_HYPRLAND_LOG="$tmp/dispatch.log"
export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
export PATH="$HERE/fakebin:$PATH"
# DMS runs widgets without locale vars (C locale), where bash printf '\U...'
# prints the escape literally. Simulate that so label generation must be
# locale-independent.
export LC_ALL=C LANG=C

# Minimal state: focused monitor, workspaces 1 and 5, one window each.
cat > "$FAKE_HYPRLAND_STATE" <<'EOF'
{
  "monitors": [{"name": "eDP-1", "id": 0, "focused": true}],
  "next_ws_id": 100,
  "workspaces": [
    {"id": 1, "name": "1", "monitor": "eDP-1", "window_ids": [1001]},
    {"id": 5, "name": "5", "monitor": "eDP-1", "window_ids": [1005]}
  ],
  "windows": [
    {"id": 1001, "class": "winA", "title": "A", "workspace": {"id": 1, "name": "1"}},
    {"id": 1005, "class": "winE", "title": "E", "workspace": {"id": 5, "name": "5"}}
  ],
  "active_window_id": 1001,
  "active_workspace_id": 1
}
EOF

pass=0
fail=0
check_output() { # <description> <expected>
    local actual
    actual="$("$SCRIPT")"
    if [[ "$actual" == "$2" ]]; then
        echo "ok   - $1"
        pass=$((pass + 1))
    else
        echo "FAIL - $1 (expected '$2', got '$actual')"
        fail=$((fail + 1))
    fi
}

# The bar indicator embeds a per-activity emoji in the output, since the
# plugin's Material icon is a static per-instance setting.
WORK_LABEL="💼 Work"
PERSONAL_LABEL="🏠 Personal"

echo "== test 1: state file present =="
echo "work" > "$XDG_RUNTIME_DIR/hyprland-activity"
check_output "state file 'work' -> Work label"        "$WORK_LABEL"
echo "personal" > "$XDG_RUNTIME_DIR/hyprland-activity"
check_output "state file 'personal' -> Personal label" "$PERSONAL_LABEL"

echo "== test 2: no state file, infer from focused workspace =="
rm -f "$XDG_RUNTIME_DIR/hyprland-activity"
jq '.active_workspace_id = 1' "$FAKE_HYPRLAND_STATE" > "$FAKE_HYPRLAND_STATE.tmp" && mv "$FAKE_HYPRLAND_STATE.tmp" "$FAKE_HYPRLAND_STATE"
check_output "focused ws 1 -> Work label"             "$WORK_LABEL"
jq '.active_workspace_id = 5' "$FAKE_HYPRLAND_STATE" > "$FAKE_HYPRLAND_STATE.tmp" && mv "$FAKE_HYPRLAND_STATE.tmp" "$FAKE_HYPRLAND_STATE"
check_output "focused ws 5 -> Personal label"         "$PERSONAL_LABEL"

echo "== test 3: garbage state file falls back to inference =="
echo "nonsense" > "$XDG_RUNTIME_DIR/hyprland-activity"
check_output "invalid state, focused ws 5 -> Personal label" "$PERSONAL_LABEL"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
