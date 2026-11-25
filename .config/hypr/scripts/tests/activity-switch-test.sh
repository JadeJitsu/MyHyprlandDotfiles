#!/usr/bin/env bash
# Tests for activity-switch.sh, run against the fake hyprctl in fakebin/.
# Usage: ./activity-switch-test.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../activity-switch.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export FAKE_HYPRLAND_STATE="$tmp/state.json"
export FAKE_HYPRLAND_LOG="$tmp/dispatch.log"
export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
export PATH="$HERE/fakebin:$PATH"

# Initial state: focused monitor eDP-1, workspaces 1-4 with windows, 5-8 absent.
#   ws1: A(1001) B(1002)   ws2: C(1003)   ws3: (empty)   ws4: D(1004)
cat > "$FAKE_HYPRLAND_STATE" <<'EOF'
{
  "monitors": [{"name": "eDP-1", "id": 0, "focused": true}],
  "next_ws_id": 100,
  "workspaces": [
    {"id": 1, "name": "1", "monitor": "eDP-1", "window_ids": [1001, 1002]},
    {"id": 2, "name": "2", "monitor": "eDP-1", "window_ids": [1003]},
    {"id": 3, "name": "3", "monitor": "eDP-1", "window_ids": []},
    {"id": 4, "name": "4", "monitor": "eDP-1", "window_ids": [1004]}
  ],
  "windows": [
    {"id": 1001, "class": "winA", "title": "A", "workspace": {"id": 1, "name": "1"}},
    {"id": 1002, "class": "winB", "title": "B", "workspace": {"id": 1, "name": "1"}},
    {"id": 1003, "class": "winC", "title": "C", "workspace": {"id": 2, "name": "2"}},
    {"id": 1004, "class": "winD", "title": "D", "workspace": {"id": 4, "name": "4"}}
  ],
  "active_window_id": 1001,
  "active_workspace_id": 1
}
EOF

pass=0
fail=0
check() { # <description> <jq expression that must be truthy>
    if jq -e "$2" "$FAKE_HYPRLAND_STATE" >/dev/null; then
        echo "ok   - $1"
        pass=$((pass + 1))
    else
        echo "FAIL - $1"
        fail=$((fail + 1))
    fi
}
check_file() { # <description> <file> <expected content>
    if [[ "$(cat "$2" 2>/dev/null)" == "$3" ]]; then
        echo "ok   - $1"
        pass=$((pass + 1))
    else
        echo "FAIL - $1 (got: '$(cat "$2" 2>/dev/null)')"
        fail=$((fail + 1))
    fi
}

ws_ids() { # <workspace name> -> space-separated window ids on it
    jq -r --arg n "$1" '[.workspaces[] | select(.name == $n) | .window_ids[]] | join(" ")' "$FAKE_HYPRLAND_STATE"
}

echo "== test 1: switch work -> personal =="
"$SCRIPT" personal
check "ws1 windows (A B) moved to ws5"        '[.workspaces[] | select(.name == "5")] | .[0].window_ids | sort == [1001, 1002]'
check "ws2 window (C) moved to ws6"           '[.workspaces[] | select(.name == "6")] | .[0].window_ids == [1003]'
check "ws4 window (D) moved to ws8"           '[.workspaces[] | select(.name == "8")] | .[0].window_ids == [1004]'
check "ws1 is now empty"                      '[.workspaces[] | select(.name == "1")] | .[0].window_ids == []'
check "window records point at new workspace" '[.windows[] | select(.id == 1001)] | .[0].workspace.name == "5"'
check "focus lands on first target workspace" '.active_workspace_id == ([.workspaces[] | select(.name == "5")] | .[0].id)'
check_file "state file records personal"      "$XDG_RUNTIME_DIR/hyprland-activity" "personal"

echo "== test 2: switch personal -> work (round trip) =="
"$SCRIPT" work
check "A B back on ws1"                       '[.workspaces[] | select(.name == "1")] | .[0].window_ids | sort == [1001, 1002]'
check "C back on ws2"                         '[.workspaces[] | select(.name == "2")] | .[0].window_ids == [1003]'
check "D back on ws4"                         '[.workspaces[] | select(.name == "4")] | .[0].window_ids == [1004]'
check "ws5 empty after round trip"            '[.workspaces[] | select(.name == "5")] | .[0].window_ids == []'
check "focus lands on ws1"                    '.active_workspace_id == ([.workspaces[] | select(.name == "1")] | .[0].id)'
check_file "state file records work"          "$XDG_RUNTIME_DIR/hyprland-activity" "work"

echo "== test 3: 'next' cycles work -> personal =="
"$SCRIPT" next
check "next moved windows to personal set"    "[.workspaces[] | select(.name == \"5\")] | .[0].window_ids | sort == [1001, 1002]"
check_file "state file records personal"      "$XDG_RUNTIME_DIR/hyprland-activity" "personal"

echo "== test 4: switching to the current activity is a no-op for windows =="
before="$(ws_ids 5)"
"$SCRIPT" personal
after="$(ws_ids 5)"
if [[ "$before" == "$after" ]]; then
    echo "ok   - windows untouched when target == current"
    pass=$((pass + 1))
else
    echo "FAIL - windows changed when target == current ($before -> $after)"
    fail=$((fail + 1))
fi

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
