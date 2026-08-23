#!/usr/bin/env bash
# Waybar custom/language — replaces the built-in `sway/language` module so
# the layout code can drop to icon-only on a narrow bar.
#
# {short} isn't something swaymsg exposes directly (the built-in module
# derives it internally) — this abbreviates xkb_active_layout_name itself:
# the text inside trailing parentheses if there is one ("English (US)" ->
# "US"), else the first two letters uppercased ("Greek" -> "GR"). NOT
# verified against a real keyboard device — this rig's headless sway reports
# zero input devices (`swaymsg -t get_inputs` -> `[]`, no libinput seat), so
# only the parsing logic itself was exercised, against fabricated JSON, not
# real abbreviation text. Worth eyeballing live after deploy.

. "$HOME/.config/waybar/scripts/lib-density.sh"

# Same glyph the old built-in module's format string used, emitted by
# codepoint (weather.sh's convention).
icon=$(/usr/bin/printf '\U000F05CA')

name=$(swaymsg -t get_inputs 2>/dev/null | python3 -c '
import json, sys
try:
    inputs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
kb = next((i for i in inputs if i.get("type") == "keyboard" and i.get("xkb_active_layout_name")), None)
if kb:
    print(kb["xkb_active_layout_name"])
' 2>/dev/null)

# No keyboard reporting a layout -> hide, matching every other script
# module's convention (weather.sh/audio.sh/usb.sh: no data, no output).
[ -n "$name" ] || exit 0

short=$(printf '%s' "$name" | sed -n 's/.*(\([^)]*\)).*/\1/p')
[ -n "$short" ] || short=$(printf '%s' "$name" | cut -c1-2 | tr '[:lower:]' '[:upper:]')

case "$(hestia_density)" in
    minimal) text="<span size='xx-large' rise='-3072'>$icon</span>" ;;
    *)       text="<span size='xx-large' rise='-3072'>$icon</span> $short" ;;
esac

printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$name"
