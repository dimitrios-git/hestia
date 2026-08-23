#!/usr/bin/env bash
# Waybar custom/language — replaces the built-in `sway/language` module so
# the layout code can drop to icon-only on a narrow bar.
#
# {short} isn't something swaymsg exposes directly (the built-in module
# derives it internally) — this abbreviates xkb_active_layout_name itself.
# First cut used "whatever's in the trailing parens", which broke live: many
# xkb variants put a DESCRIPTIVE name there instead of a country code (e.g.
# Bulgarian's "traditional phonetic" layout reports as "Bulgarian
# (traditional phonetic)", not "Bulgarian (BG)"), so the bar printed the
# whole phrase. Now, in order: (1) the parenthetical when it's short enough
# to plausibly BE a code (<=4 chars — "US", "UK", "intl"); (2) a small
# hardcoded language-name -> ISO 639-1 lookup for languages actually in use
# here (deliberately NOT an exhaustive database — add to it as needed, not
# ahead of need); (3) the first two letters of the language name itself,
# lowercase, as the last-resort fallback. A hard cut to 4 chars afterwards
# is a safety net against any layout name shape not seen yet. Always
# lowercased at the end, matching locale-code convention (en/us/bg, not
# EN/US/BG).

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

paren=$(printf '%s' "$name" | sed -n 's/.*(\([^)]*\)).*/\1/p')
lang=$(printf '%s' "$name" | sed 's/ *(.*//')   # text before the first "(" (or the whole name if none)

if [ -n "$paren" ] && [ "${#paren}" -le 4 ]; then
    short=$paren
else
    case "$lang" in
        Bulgarian) short=bg ;;
        Greek)     short=el ;;
        German)    short=de ;;
        French)    short=fr ;;
        Spanish)   short=es ;;
        Italian)   short=it ;;
        Russian)   short=ru ;;
        Polish)    short=pl ;;
        *)         short=$(printf '%s' "$lang" | cut -c1-2) ;;
    esac
fi
short=$(printf '%s' "$short" | cut -c1-4 | tr '[:upper:]' '[:lower:]')   # safety net + lowercase, regardless of branch above

case "$(hestia_density)" in
    minimal) text="<span size='xx-large' rise='-3072'>$icon</span>" ;;
    *)       text="<span size='xx-large' rise='-3072'>$icon</span> $short" ;;
esac

printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$name"
