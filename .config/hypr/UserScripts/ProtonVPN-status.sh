#!/usr/bin/env bash
# Waybar custom module — ProtonVPN status via NetworkManager

vpn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null \
      | grep '^ProtonVPN' | grep ':vpn:activated' | head -1)

if [[ -n "$vpn" ]]; then
    server=$(echo "$vpn" | cut -d: -f1)
    echo "{\"text\":\"󰦝 ${server}\",\"class\":\"connected\",\"tooltip\":\"ProtonVPN: ${server}\"}"
else
    echo "{\"text\":\"󰦞\",\"class\":\"disconnected\",\"tooltip\":\"ProtonVPN: disconnected\"}"
fi
