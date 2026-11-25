#!/bin/sh
# Tests for charge-toggle.sh using a fake dbus-send that simulates tccd state.
# Usage: sh tests/charge-toggle.test.sh   (exit 0 = all pass)
set -u

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCRIPT=$DIR/../charge-toggle.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- fake dbus-send: simulates com.tuxedocomputers.tccd charge threshold ---
cat > "$TMP/dbus-send" <<'FAKE'
#!/bin/sh
STATE="$FAKE_TCC_STATE"
for a in "$@"; do
    case "$a" in
        *GetChargeEndThreshold*)
            echo "method return time=1 sender=:1.19 -> destination=:1.116 serial=1 reply_serial=1"
            echo "   int32 $(cat "$STATE")"
            exit 0 ;;
        *SetChargeEndThreshold*)
            : # fall through to value parse below ;;
    esac
done
for a in "$@"; do
    case "$a" in
        int32:*)
            echo "${a#int32:}" > "$STATE"
            echo "method return time=1 sender=:1.19 -> destination=:1.116 serial=2 reply_serial=2"
            echo "   boolean true"
            exit 0 ;;
    esac
done
echo "fake dbus-send: unhandled args: $*" >&2
exit 1
FAKE
chmod +x "$TMP/dbus-send"
export FAKE_TCC_STATE="$TMP/state"

PASS=0; FAIL=0
check() { # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2], got [$3])"; fi
}

run() { PATH="$TMP:$PATH" sh "$SCRIPT" "$@"; }

# get
echo 100 > "$FAKE_TCC_STATE"
check "get returns current value" "100" "$(run get)"

# set
run set 55 >/dev/null
check "set writes new value" "55" "$(cat "$FAKE_TCC_STATE")"
check "set echoes resulting value" "55" "$(run set 55)"

# toggle: 100 -> 80
echo 100 > "$FAKE_TCC_STATE"
out=$(run toggle)
check "toggle 100 -> 80 (state)" "80" "$(cat "$FAKE_TCC_STATE")"
case "$out" in *80*) PASS=$((PASS+1)) ;; *) FAIL=$((FAIL+1)); echo "FAIL: toggle output mentions 80 (got [$out])" ;; esac

# toggle: 80 -> 100
echo 80 > "$FAKE_TCC_STATE"
run toggle >/dev/null
check "toggle 80 -> 100 (state)" "100" "$(cat "$FAKE_TCC_STATE")"

# toggle: arbitrary non-100 value -> 100 (revert to full charging)
echo 60 > "$FAKE_TCC_STATE"
run toggle >/dev/null
check "toggle 60 -> 100 (state)" "100" "$(cat "$FAKE_TCC_STATE")"

# usage error
if run bogus >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "FAIL: unknown subcommand should exit non-zero"
else
    PASS=$((PASS+1))
fi

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
