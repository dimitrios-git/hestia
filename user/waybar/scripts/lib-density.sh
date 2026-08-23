# Shared width-tier detection for waybar's script-driven modules. Sourced
# (not exec'd) by clock.sh / network.sh / language.sh / weather.sh / audio.sh.
#
# Queried LIVE per poll against the currently focused sway output (falls back
# to the last output seen if none reports focused, e.g. a brief startup
# race) — deliberately NOT a host_var/static setting: the same machine can
# have a small laptop panel and a large external monitor at once, and a
# static per-host density would be wrong for whichever one it didn't match.
# No jq/python dependency — swaymsg's `-t get_outputs` key order always puts
# an output's own "rect" block before its own "focused" key, so a single
# awk pass can track "the width just seen" and act on it the moment
# "focused": true shows up, no real JSON parsing needed.
#
# hestia_density() prints one of: full | compact | minimal
hestia_density() {
    w=$(swaymsg -t get_outputs 2>/dev/null | awk '
        /"rect": {/        { in_rect = 1; next }
        in_rect && /"width":/ { gsub(/[^0-9]/, "", $0); width = $0 + 0; in_rect = 0; next }
        /"focused": true/  { print width; found = 1; exit }
        END { if (!found && width > 0) print width }
    ')
    case "$w" in '' | *[!0-9]*) w=1920 ;; esac
    # Tuned against hestia-shot's own measured resolutions (docs/
    # video-capture-design.md §19) and common real displays — a laptop
    # panel (~1366) lands in compact, the 1280x720 capture demo that
    # prompted this lands in minimal. Adjust freely; nothing else depends
    # on these exact numbers.
    if   [ "$w" -ge 1600 ]; then echo full
    elif [ "$w" -ge 1100 ]; then echo compact
    else echo minimal
    fi
}
