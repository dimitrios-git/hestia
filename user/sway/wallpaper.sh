#!/bin/bash
# wallpaper.sh <dark|light> — the default-wallpaper engine (wallpaper verdict,
# 2026-07). Engine RE-PICKED 2026-07: the original mpvpaper-played video loop
# leaked memory without bound — a 4K loop grew to ~14 GB RSS over 3 days here —
# which is an unfixed UPSTREAM regression in mpv's loop path (mpv #15099,
# surfaced by mpvpaper #101), not a config bug. So the verdict's runner-up
# wpaperd (the stills engine) now paints the STATIC t=0 mesh PNGs that ship
# beside the loop videos: the mesh ground stays, minus the decoder-forever cost
# and the leak. (The .mp4 loops still download but go unused.)
#
# Run from the generated sway theme fragment as `exec_always` — so it re-runs
# on every `swaymsg reload`, load-bearing twice over: it re-asserts the engine
# (restarts wpaperd if it died; regenerates its config) AND re-kills the swaybg
# that `output * bg` respawns ABOVE the wallpaper layer on reload
# (background-layer stacking is timing-dependent; caught live in the trial).
# No-ops cleanly when wpaperd or the assets are absent — the theme fragment's
# solid ground simply stays.
#
# Assets: ~/.local/share/backgrounds/hestia/<flavour>-<variant>-<WxH>.png
# (the `wallpapers` role downloads the host's wallpaper_flavour set — plain-mesh
# or flash-mesh — and stamps `default-flavour`). Per output: exact resolution
# match, else the largest available (wpaperd's `fill` mode scales cleanly).

variant=${1:?usage: wallpaper.sh <dark|light>}
DIR="$HOME/.local/share/backgrounds/hestia"
# wpaperd reads this at startup (via -c) and hot-reloads it on change. It lives
# on tmpfs, NOT at ~/.config/wpaperd/config.toml — that path is a symlink into
# the repo (the standalone/manual default), and this engine must not write it.
CONFIG="${XDG_RUNTIME_DIR:-/tmp}/hestia-wpaperd.toml"

command -v wpaperd >/dev/null 2>&1 || exit 0
[ -d "$DIR" ] || exit 0

# Retire a leftover mpvpaper from the previous (video) engine, if any — so the
# switch takes effect on a plain reload, not just a fresh login.
pkill -u "$USER" -x mpvpaper 2>/dev/null

# Which mesh flavour to play — the wallpapers role stamps its wallpaper_flavour
# var into the marker (flash-mesh = the default since 2026-07; plain-mesh = the
# quiet alternative); an absent marker falls back to plain-mesh, because
# pre-flavour installs only ever downloaded the plain assets.
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

largest_file() {  # -> largest png of the flavour+variant ("" if none)
    local best="" best_px=0 f wh w h
    for f in "$DIR/$flavour-$variant-"*.png; do
        [ -f "$f" ] || continue
        wh=${f##*-}; wh=${wh%.png}; w=${wh%x*}; h=${wh#*x}
        if [ $((w * h)) -gt "$best_px" ]; then best_px=$((w * h)); best="$f"; fi
    done
    echo "$best"
}

pick_file() {  # $1 W, $2 H -> exact-resolution png, else the largest
    local exact="$DIR/$flavour-$variant-${1}x${2}.png"
    if [ -f "$exact" ]; then echo "$exact"; return; fi
    largest_file
}

# Build a self-contained wpaperd config: one static per-output section pointing
# at that output's best mesh PNG, plus an `[any]` catch-all (the largest PNG) so
# a monitor hotplugged mid-session still gets papered. `fit-border-color` shows
# the whole frame and fills any letterbox with the sampled border colour (the
# mesh border ≈ the ground, so bars are invisible); an exact-resolution match is
# 1:1 with no bars at all, and same-aspect fallbacks scale to a clean full fill
# — only an aspect-mismatch fallback shows the (ground-coloured) bars. wpaperd's
# mode enum has no "fill"/"cover" (stretch/center/fit/tile/fit-border-color
# only) — an invalid value makes wpaperd reject the WHOLE config and paint
# black. Explicit output sections win over `[any]`.
tmp="$CONFIG.tmp.$$"
: > "$tmp"
printf '[default]\nmode = "fit-border-color"\n\n' >> "$tmp"
biggest=$(largest_file)
[ -n "$biggest" ] && printf '[any]\npath = "%s"\n\n' "$biggest" >> "$tmp"
n=0
while read -r out w h; do
    file=$(pick_file "$w" "$h")
    [ -n "$file" ] || continue
    printf '[%s]\npath = "%s"\n\n' "$out" "$file" >> "$tmp"
    n=$((n + 1))
done <<< "$outputs"
if [ "$n" -eq 0 ]; then rm -f "$tmp"; exit 0; fi
mv -f "$tmp" "$CONFIG"

# Start the daemon if it isn't up (fresh login, or it died); an already-running
# wpaperd picks up the rewritten config via its own hot-reload watch.
if ! pgrep -u "$USER" -x wpaperd >/dev/null 2>&1; then
    wpaperd -d -c "$CONFIG"
fi

# The wallpaper owns the background layer now — retire the solid-ground swaybg
# (it stacks above the wallpaper when respawned by a reload). Small settle so a
# reload-respawned swaybg exists before the kill.
sleep 1
pkill -u "$USER" -x swaybg 2>/dev/null
exit 0
