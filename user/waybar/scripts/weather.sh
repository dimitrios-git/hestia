#!/bin/sh
# Waybar custom/weather — wttr.in. Bar: a monochrome Nerd Font weather glyph +
# temperature. Tooltip: location, condition, feels-like, humidity, wind. `weather.sh
# show` opens the full multi-day forecast in a pager (the on-click handler). Location
# is wttr.in's IP geolocation (no location configured). Caches the last good reading to
# tmpfs and falls back to it on a network failure; prints nothing (Waybar hides the
# module) when there's no data at all. Refresh interval (30 min) is in the waybar config.

cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-weather.json"

# Map the wttr.in condition TEXT (%C) to an nf-md-weather glyph (monochrome — takes the
# bar's text colour, and uses the same icon span as the other modules so it aligns). The
# glyph is emitted by codepoint via GNU `/usr/bin/printf '\U…'`, so there's no literal
# PUA character in this file (edit-safe). Clear/sunny picks the night glyph after dark.
weather_glyph() {
    _h=$(date +%H 2>/dev/null); _h=${_h#0}; _night=0
    case "$_h" in ''|*[!0-9]*) ;; *) { [ "$_h" -lt 6 ] || [ "$_h" -ge 19 ]; } && _night=1 ;; esac
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        *thunder*)                              _cp=000f0593 ;;  # weather-lightning
        *snow*|*sleet*|*blizzard*|*ice*|*icy*)  _cp=000f0598 ;;  # weather-snowy
        *rain*|*drizzle*|*shower*)              _cp=000f0597 ;;  # weather-rainy
        *fog*|*mist*|*haze*|*freezing*)         _cp=000f0591 ;;  # weather-fog
        *overcast*)                             _cp=000f0590 ;;  # weather-cloudy
        *partly*|*patchy*)                      _cp=000f0595 ;;  # weather-partly-cloudy
        *cloud*)                                _cp=000f0590 ;;  # weather-cloudy
        *sunny*|*clear*)  [ "$_night" = 1 ] && _cp=000f0594 || _cp=000f0599 ;;  # night / sunny
        *)                                      _cp=000f0590 ;;  # default: cloudy
    esac
    /usr/bin/printf "\\U$_cp"
}

if [ "$1" = show ]; then
    # Full forecast in a pager. Guard the empty case (no network / rate-limited): pipe
    # less an empty stream and it exits instantly, flashing the floatterm shut.
    exec sh -c 'f=$(curl -s --max-time 15 "wttr.in"); if [ -n "$f" ]; then printf "%s\n" "$f" | less -RS; else printf "weather unavailable (network?)\n"; sleep 3; fi'
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
            # Monochrome glyph in the standard icon span (same as cpu/gpu/etc.) so the
            # temperature aligns by construction — no rise hack needed.
            text="<span size='xx-large' rise='-3072'>$(weather_glyph "$ctext")</span> $(esc "$temp")"
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
