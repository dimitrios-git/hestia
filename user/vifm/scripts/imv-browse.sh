#!/bin/sh
# imv-browse.sh <cursor-file> <dir> — vifm's image-browse launcher (key `i`),
# integrated with imv on a tiling WM.
#
# First press (no imv yet): collapse vifm to one pane, split sway, and open imv
# tiled to the RIGHT, on the directory's images passed as an EXPLICIT, sorted
# list (so imv's index order is known to us, since imv 4.5 can't sort), starting
# at the cursor file.
#
# Subsequent press (imv already open): jump that same imv to the cursor file —
# imv-msg goto <index>, where the index is the file's position in the identical
# sorted list — and focus imv. No second pane; it loads the image you pressed
# `i` on, and continued j/k browsing still works (real index, not an append).
#
# Pairs with user/imv/config-vifm (live cursor sync on j/k; q returns to vifm).
# Note: only tracks imv instances opened through here — an imv opened via Enter
# uses a different (directory) order, so the index wouldn't match.

cur=$1
dir=$2

# Deterministic image list of $dir, one absolute path per line. Run identically
# at launch and on re-press so the computed index matches imv's list. Ordered to
# match vifm's view: `sort -V` is natural/numeric ordering (vifm has `set
# sortnumbers`, so img2 sorts before img10 — a plain byte sort diverged and made
# the synced cursor hop); dotfiles excluded since vifm hides them by default.
# (vifm's exact list isn't reachable — expand("%a") is empty over --remote.)
images() {
    find "$dir" -maxdepth 1 -type f ! -name '.*' 2>/dev/null \
        | grep -iE '\.(jpe?g|png|gif|bmp|tiff?|webp|avif|ico|svg)$' \
        | sort -V
}

pid=$(pgrep -x imv-wayland | head -1)
if [ -n "$pid" ]; then
    # imv is open: select the cursor file by its 1-based index, then focus imv.
    idx=$(images | grep -nxF -- "$cur" | head -1 | cut -d: -f1)
    [ -n "$idx" ] && imv-msg "$pid" goto "$idx"
    swaymsg '[app_id="imv"] focus' >/dev/null 2>&1
    exit 0
fi

# First open: set up the integrated layout, then launch imv on the sorted list.
vifm --remote -c only
swaymsg split horizontal
# Build a space-safe argv from the sorted images (one per line).
set --
while IFS= read -r f; do
    [ -n "$f" ] && set -- "$@" "$f"
done <<EOF
$(images)
EOF
exec env imv_config="$HOME/.config/imv/config-vifm" imv-wayland -n "$cur" "$@"
