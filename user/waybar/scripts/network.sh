#!/usr/bin/env bash
# Waybar custom/network — replaces the built-in `network` module so wifi's
# signal percentage can drop to icon-only on a narrow bar. Ethernet/
# disconnected are already icon-only in the original built-in module (nothing
# to shrink there) and stay that way. Feature-matches the built-in's 3 states
# via nmcli (NetworkManager) instead of waybar's own native introspection.

. "$HOME/.config/waybar/scripts/lib-density.sh"

# Same glyphs the old built-in module's format-wifi/-ethernet/-disconnected
# used, emitted by codepoint (weather.sh's convention).
icon_wifi=$(/usr/bin/printf '\U000F05A9')
icon_eth=$(/usr/bin/printf '\U000F0200')
icon_disc=$(/usr/bin/printf '\U000F05AA')

status=$(nmcli -t -f TYPE,STATE,DEVICE device status 2>/dev/null)
# Exact "connected" (not "connected (externally)", which is how nmcli marks
# tun/bridge/veth devices like tailscale/docker) — a genuine NM-managed link.
wifi_dev=$(awk -F: '$1=="wifi" && $2=="connected"{print $3; exit}' <<<"$status")
eth_dev=$(awk -F: '$1=="ethernet" && $2=="connected"{print $3; exit}' <<<"$status")

ip_of() { nmcli -t -f IP4.ADDRESS device show "$1" 2>/dev/null | head -1 | cut -d: -f2- | cut -d/ -f1; }

if [ -n "$wifi_dev" ]; then
    # active,ssid,signal — "active" flags which AP row is the one we're
    # actually joined to (nmcli lists every visible network otherwise).
    line=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '$1=="yes"{print; exit}')
    essid=$(cut -d: -f2 <<<"$line")
    signal=$(cut -d: -f3 <<<"$line")
    ip=$(ip_of "$wifi_dev")
    case "$(hestia_density)" in
        minimal) text="<span size='xx-large' rise='-3072'>$icon_wifi</span>" ;;
        *)       text=$(printf "<span size='xx-large' rise='-3072'>%s</span> %2d%%" "$icon_wifi" "${signal:-0}") ;;
    esac
    tooltip="$essid (${signal:-0}%)\n$ip"
elif [ -n "$eth_dev" ]; then
    text="<span size='xx-large' rise='-3072'>$icon_eth</span>"
    tooltip="$eth_dev: $(ip_of "$eth_dev")"
else
    text="<span size='xx-large' rise='-3072'>$icon_disc</span>"
    tooltip="Disconnected"
fi

printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$tooltip"
