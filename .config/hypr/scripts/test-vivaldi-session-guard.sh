#!/bin/bash
# Test for ~/.local/bin/vivaldi-session-guard.sh
# Synthetic processes only — no real browser or compositor involved.
# Hermetic: each run uses its own dir so stale fixtures can't interfere.
set -u
T=/tmp/session-guard-test/run$$
GUARD="$HOME/.local/bin/vivaldi-session-guard.sh"
MARKER="$T/browser-clean-exit"
mkdir -p "$T"
trap 'pkill -9 -f "$T/fake_" 2>/dev/null' EXIT

fail() { echo "FAIL: $1"; exit 1; }

[ -x "$GUARD" ] || fail "guard script missing or not executable: $GUARD"

# Fake session leader: lives until we kill it
cat > "$T/fake_session" <<'EOF'
#!/bin/sh
while :; do sleep 1; done
EOF
# Fake browser: records a clean exit when it catches TERM
cat > "$T/fake_browser" <<EOF
#!/bin/sh
trap 'echo clean > $MARKER; exit 0' TERM INT
while :; do sleep 1; done
EOF
chmod +x "$T/fake_session" "$T/fake_browser"

"$T/fake_session" & SPID=$!
"$T/fake_browser" & BPID=$!
sleep 0.5

SESSION_PROC=fake_session BROWSER_RE="$T/fake_browser" "$GUARD" & GPID=$!
sleep 1

# Guard must NOT kill the browser while the session is alive
kill -0 "$BPID" 2>/dev/null || fail "browser killed while session still alive"
[ ! -e "$MARKER" ] || fail "browser exited while session still alive"

# Session dies -> guard must trigger a clean browser exit
kill "$SPID"
i=0
while [ $i -lt 50 ] && [ ! -e "$MARKER" ]; do sleep 0.1; i=$((i+1)); done
[ -e "$MARKER" ] || fail "browser did not exit cleanly within 5s of session death"

# Guard should have exited by now (its wait loop ends once the browser is gone)
i=0
while [ $i -lt 30 ] && kill -0 "$GPID" 2>/dev/null; do sleep 0.1; i=$((i+1)); done
kill -0 "$GPID" 2>/dev/null && fail "guard still running 3s after browser exit"

# No session at all -> guard must exit 0 quickly, touch nothing
"$T/fake_browser" & BPID2=$!
sleep 0.3
SESSION_PROC=fake_session BROWSER_RE="$T/fake_browser" timeout 3 "$GUARD" \
  || fail "guard did not exit 0 within 3s when no session proc exists"
sleep 0.5
kill -0 "$BPID2" 2>/dev/null || fail "browser killed when no session proc existed"
kill "$BPID2" 2>/dev/null

echo "PASS: all assertions held"
