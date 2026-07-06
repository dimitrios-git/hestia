#!/bin/bash
# audio.sh — waybar custom/audio (replaces the built-in pulseaudio module,
# 2026-07): the built-in renders an EMPTY padded box when no audio server is
# reachable (caught in the showcase's headless screenshots), while every
# script widget hides by printing nothing. This one follows the script
# convention: no default sink -> no output -> module hidden.
#
# status (default): JSON {text, tooltip, class} — volume with the nf-md
# speaker glyph, or the muted glyph + "muted" (class `muted` recolours via
# theme.css icon_muted). Glyphs are emitted BY CODEPOINT via printf (the PUA
# caveat — editors silently strip literal glyphs; same recipe as weather.sh).
# Subcommands wired to the module's mouse bindings + the sway volume keys:
#   toggle-mute | up | down   — wpctl + an instant RTMIN+8 refresh
#   mixer                     — pulsemixer floatterm toggle (pgrep pattern)
# interval 1 stays as the fallback sync for changes made elsewhere.

ICON_VOL=$(/usr/bin/printf '\U000F057E')
ICON_MUTE=$(/usr/bin/printf '\U000F0581')
SINK=@DEFAULT_AUDIO_SINK@

refresh() { pkill -RTMIN+8 -x waybar 2>/dev/null; }

# shellcheck disable=SC2015  # mixer: the repo's established floatterm toggle idiom
case ${1-} in
    toggle-mute) wpctl set-mute "$SINK" toggle 2>/dev/null && refresh; exit 0 ;;
    up)          wpctl set-volume -l 1.0 "$SINK" 2%+ 2>/dev/null && refresh; exit 0 ;;
    down)        wpctl set-volume "$SINK" 2%- 2>/dev/null && refresh; exit 0 ;;
    mixer)       pgrep -x pulsemixer >/dev/null && pkill -x pulsemixer || kitty --class floatterm -e pulsemixer; exit 0 ;;
esac

# no audio server / no default sink -> hide (print nothing)
out=$(wpctl get-volume "$SINK" 2>/dev/null) || exit 0
[ -n "$out" ] || exit 0

vol=$(awk '{printf "%.0f", $2 * 100}' <<< "$out")
desc=$(wpctl inspect "$SINK" 2>/dev/null | sed -n 's/.*node\.description = "\(.*\)"$/\1/p' | head -1)
desc=${desc//[\"\\]/}   # keep the JSON well-formed
# pipewire with ZERO soundcards still provides its auto_null fallback sink
# ("Dummy Output") — a machine without audio hardware hides the widget rather
# than showing a phantom volume (verified live: the fallback reports 100%)
[ "$desc" = "Dummy Output" ] && exit 0
[ -n "$desc" ] || desc="Default sink"

if [[ $out == *MUTED* ]]; then
    text="<span size='xx-large' rise='-3072'>$ICON_MUTE</span> muted"
    cls=muted
else
    text=$(printf "<span size='xx-large' rise='-3072'>%s</span> %2d%%" "$ICON_VOL" "$vol")
    cls=""
fi
printf '{"text": "%s", "tooltip": "%s — %s%%", "class": "%s"}\n' "$text" "$desc" "$vol" "$cls"
