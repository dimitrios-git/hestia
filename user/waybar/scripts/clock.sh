#!/usr/bin/env bash
# Waybar custom/clock — replaces the built-in `clock` module so its text can
# shrink on a narrow bar (see lib-density.sh). full: date + time + seconds.
# compact: drop the date. minimal: drop seconds too. The on-click calendar
# toggle (user/waybar/config) is unaffected — this only changes bar TEXT.

. "$HOME/.config/waybar/scripts/lib-density.sh"

case "$(hestia_density)" in
    full)    fmt='+%a %d, %H:%M:%S' ;;
    compact) fmt='+%H:%M:%S' ;;
    *)       fmt='+%H:%M' ;;
esac

# Same clock glyph the old built-in module's format string used, emitted by
# codepoint (weather.sh's convention) rather than a literal PUA character in
# this file.
icon=$(/usr/bin/printf '\U000F08AE')
text=$(date "$fmt")
# The \n is a literal 2-char JSON escape baked into the VALUE here, not into
# printf's format string below — printf itself interprets \n in its OWN
# format argument as a real newline, which would land as an invalid raw
# control character inside the JSON string (caught live, first draft).
tooltip="$(date '+%A, %d %B %Y  %Z')\nclick, or \$mod+t, for a keyboard-navigable calendar"

printf '{"text":"<span size=\x27xx-large\x27 rise=\x27-3072\x27>%s</span> %s","tooltip":"%s"}\n' \
    "$icon" "$text" "$tooltip"
