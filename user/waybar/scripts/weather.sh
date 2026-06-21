#!/bin/sh
# Waybar custom/weather — wttr.in. Bar: condition emoji + temperature. Tooltip:
# location, condition, feels-like, humidity, wind. `weather.sh show` opens the full
# multi-day forecast in a pager (the on-click handler). Location is wttr.in's IP
# geolocation (no location configured). Caches the last good reading to tmpfs and
# falls back to it on a network failure; prints nothing (Waybar hides the module) when
# there's no data at all. Refresh interval (30 min — wttr.in etiquette) is in the
# waybar config.

cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-weather.json"

if [ "$1" = show ]; then
    exec sh -c 'curl -s "wttr.in" | less -R'
fi

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

data=$(curl -fsS --max-time 8 "wttr.in/?format=%c|%t|%C|%f|%h|%w|%l" 2>/dev/null)

# Valid only with the 7 expected pipe-fields and a temperature.
case "$data" in
    *"|"*"|"*"|"*"|"*"|"*"|"*)
        set -f; oldifs=$IFS; IFS='|'; set -- $data; IFS=$oldifs; set +f
        cond=$(printf '%s' "$1" | sed 's/ *$//')   # drop wttr.in's trailing space
        temp=$2; ctext=$3; feels=$4; hum=$5; wind=$6; loc=$7
        if [ -n "$temp" ]; then
            text="$(esc "$cond") $(esc "$temp")"
            tip="$(esc "$loc")\\n$(esc "$ctext"), $(esc "$temp") (feels $(esc "$feels"))\\n$(esc "$hum") humidity · $(esc "$wind")"
            json=$(printf '{"text":"%s","tooltip":"%s"}' "$text" "$tip")
            printf '%s\n' "$json" > "$cache"
            printf '%s\n' "$json"
            exit 0
        fi
        ;;
esac

# Network/parse failure -> last good reading, else nothing (module hides).
[ -r "$cache" ] && cat "$cache"
exit 0
