#!/bin/bash
# wallpaper.sh <dark|light> — the default-wallpaper engine (wallpaper verdict,
# 2026-07): per-output mesh loop videos via mpvpaper. Run from the
# generated sway theme fragment as `exec_always` — so it re-runs on every
# `swaymsg reload`, which is load-bearing twice over: it re-asserts the
# wallpaper AND re-kills the swaybg that `output * bg` respawns ABOVE the
# wallpaper layer on reload (background-layer stacking is timing-dependent;
# caught live in the trial). No-ops cleanly when mpvpaper or the assets are
# absent — the theme fragment's solid ground simply stays.
#
# Assets: ~/.local/share/backgrounds/hestia/<flavour>-<variant>-<WxH>.mp4
# (the `wallpapers` role downloads the host's wallpaper_flavour set — plain-mesh
# or flash-mesh — and stamps `default-flavour`; static .png companions ship
# too, for wpaperd/swaybg use). Per output: exact resolution match, else the
# largest available (mpv scales cleanly).

variant=${1:?usage: wallpaper.sh <dark|light>}
DIR="$HOME/.local/share/backgrounds/hestia"

command -v mpvpaper >/dev/null 2>&1 || exit 0
[ -d "$DIR" ] || exit 0

# Which mesh flavour to play — the wallpapers role stamps its wallpaper_flavour
# host_var into the marker (plain-mesh = quiet default, flash-mesh = accent
# flashes); absent marker = plain-mesh (pre-flavour installs).
flavour=$(cat "$DIR/default-flavour" 2>/dev/null) || flavour=plain-mesh
case $flavour in *-mesh) ;; *) flavour=plain-mesh ;; esac

# name + current mode per output
outputs=$(swaymsg -t get_outputs --raw 2>/dev/null | python3 -c '
import json, sys
for o in json.load(sys.stdin):
    m = o.get("current_mode") or {}
    if o.get("active") and m:
        print(o["name"], m["width"], m["height"])
') || exit 0
[ -n "$outputs" ] || exit 0

pick_file() {  # $1 W, $2 H -> best mp4 of the flavour+variant
    local exact="$DIR/$flavour-$variant-${1}x${2}.mp4"
    if [ -f "$exact" ]; then echo "$exact"; return; fi
    local best="" best_px=0 f wh w h
    for f in "$DIR/$flavour-$variant-"*.mp4; do
        [ -f "$f" ] || continue
        wh=${f##*-}; wh=${wh%.mp4}; w=${wh%x*}; h=${wh#*x}
        if [ $((w * h)) -gt "$best_px" ]; then best_px=$((w * h)); best="$f"; fi
    done
    echo "$best"
}

running=false
while read -r out w h; do
    file=$(pick_file "$w" "$h")
    [ -n "$file" ] || continue
    # already papering this output with this file? (script's own cmdline never
    # contains "mpvpaper", so no pgrep -f self-match)
    if pgrep -f "mpvpaper .*$out $file" >/dev/null 2>&1; then
        running=true
        continue
    fi
    pkill -f "mpvpaper .*$out " 2>/dev/null   # stale variant/file on this output
    mpvpaper -f -p -o "no-audio loop" "$out" "$file"
    running=true
done <<< "$outputs"

# The wallpaper owns the background layer now — retire the solid-ground swaybg
# (it stacks above the wallpaper when respawned by a reload). Small settle so a
# reload-respawned swaybg exists before the kill.
if $running; then
    sleep 1
    pkill -x swaybg 2>/dev/null
fi
exit 0
