#!/bin/sh
# Unlock the KDE Wallet ("kdewallet") at Hyprland session start.
# Electron/Chromium apps (e.g. Signal) store their safeStorage key there;
# the PAM password handed to ksecretd at login lets kwalletd6 unlock it.
sleep 3
busctl --user call org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet open sxs kdewallet 0 hyprland-session >/dev/null 2>&1 || true
