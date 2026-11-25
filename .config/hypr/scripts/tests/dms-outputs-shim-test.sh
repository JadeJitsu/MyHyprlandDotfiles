#!/usr/bin/env bash
# Test: Hyprland must never apply a DMS-generated eDP mode with a pinned
# refresh rate. The T14s panel reports 60.001/60.003 Hz across boots; DMS
# pins whichever it last saw into dms/outputs.lua, Hyprland cannot match the
# stale value, disables the panel / crashes -> black screen (2026-11-19).
#
# Fix under test: hyprland.lua requires outputs-safe.lua (pinned mode, no Hz)
# instead of the DMS-generated dms/outputs.lua.
set -u
CONFIG_DIR="$HOME/.config/hypr"
FAIL=0

# 1. hyprland.lua must not require the DMS-generated outputs file
if grep -q 'require("dms\.outputs")' "$CONFIG_DIR/hyprland.lua"; then
    echo "FAIL: hyprland.lua still requires dms.outputs (DMS regenerates it with a jittering @Hz)"
    FAIL=1
else
    echo "PASS: hyprland.lua does not require dms.outputs"
fi

# 2. hyprland.lua must require the safe replacement
if grep -q 'require("outputs-safe")' "$CONFIG_DIR/hyprland.lua"; then
    echo "PASS: hyprland.lua requires outputs-safe"
else
    echo "FAIL: hyprland.lua does not require outputs-safe"
    FAIL=1
fi

# 3. Requiring outputs-safe must register the eDP panel with a mode that has NO @Hz,
#    even when a bad DMS-generated dms/outputs.lua exists on the search path.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/dms"
cat > "$TMP/dms/outputs.lua" <<'EOF'
hl.monitor({ output = "desc:Lenovo Group Limited N140JCA-ELP", mode = "1920x1200@60.003", position = "0x0", scale = 1.25 })
EOF

HYPR_TEST_CONFIG="$CONFIG_DIR" HYPR_TEST_TMP="$TMP" lua5.4 -e '
local hl_monitors = {}
_G.hl = { monitor = function(t) hl_monitors[#hl_monitors + 1] = t end }
package.path = os.getenv("HYPR_TEST_CONFIG") .. "/?.lua;"
           .. os.getenv("HYPR_TEST_TMP") .. "/?.lua;" .. package.path
local ok, err = pcall(require, "outputs-safe")
if not ok then
    print("FAIL: require(outputs-safe) failed: " .. tostring(err))
    os.exit(1)
end
local found = false
for _, m in ipairs(hl_monitors) do
    local out = tostring(m.output or "")
    if out:find("N140JCA") then
        found = true
        local mode = tostring(m.mode or "")
        if mode:find("@") then
            print("FAIL: eDP mode pins a refresh rate: " .. mode)
            os.exit(1)
        end
        print("PASS: eDP mode has no pinned refresh rate: " .. mode)
    end
end
if not found then
    print("FAIL: outputs-safe registered no eDP (N140JCA) monitor")
    os.exit(1)
end
' || FAIL=1

exit $FAIL
