#!/bin/bash
# Block until kdewallet is unlocked, then exec the given command.
until dbus-send --session --print-reply \
    --dest=org.kde.kwalletd6 /modules/kwalletd6 \
    org.kde.KWallet.isOpen string:"kdewallet" 2>/dev/null | grep -q "boolean true"; do
    sleep 1
done
exec "$@"
