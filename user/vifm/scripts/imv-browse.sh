#!/bin/sh
# imv-browse.sh <cursor-file> <dir> — vifm's image/video browse launcher, opened
# by the image AND video filextype handlers (Enter/l, or vifm's builtin `i`).
#
# Browses images AND videos in one imv window. imv can't play video, so each
# video is shown as a cached **poster-frame thumbnail with a ▶ overlay**; imv
# just sees images. A session map (one original path per line, line N = imv item
# N) lets everything downstream resolve imv's `$imv_current_index` back to the
# real file: the live cursor sync (imv-vifm-return.sh), and Enter→mpv on a video.
#
# PRIORITY ORDER (redesigned 2026-07 after a 2000-video directory locked the
# whole flow for minutes): the SELECTED file first, the session second,
# thumbnails last. Only the cursor file's poster is generated synchronously
# (bounded: one file); every other uncached video shows a shared generic
# ▶ placeholder and imv launches IMMEDIATELY. A single idle-priority
# (nice/ionice) background worker then backfills the real posters
# sequentially, so the NEXT visit to the directory has them — placeholders
# already shown in the current imv session stay placeholders (imv's list is
# fixed at launch). A PID-checked launch lock makes an Enter-storm harmless:
# while one launch is in flight, further invocations exit instead of stacking
# imv windows (the old pgrep-only check misses the pre-imv window).
#
# Re-press while imv is open: jump it to the cursor file (imv-msg goto <index>,
# index from the session map) and focus — no second pane.

cur=$1
dir=$2

# Drive THE LAUNCHING vifm instance, not whichever registered the "vifm" server
# name first: vifmrc exports $VIFM_SERVER_NAME (v:servername) to its children,
# and imv inherits it through us for imv-vifm-return.sh. Without this, a second
# open vifm got the collapse/sync commands meant for this one.
vremote() { vifm --server-name "${VIFM_SERVER_NAME:-vifm}" --remote "$@"; }

cache="${XDG_CACHE_HOME:-$HOME/.cache}/imv-vifm-thumbs"
session="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-session.list"
launchlock="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-launch.lock"
genlock="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-thumbgen.lock"
mkdir -p "$cache"

vid_re='\.(mp4|mkv|avi|mov|webm|flv|m4v|mpe?g|wmv|ts|m2v|ogv|3gp|vob)$'
img_re='\.(jpe?g|png|gif|bmp|tiff?|webp|avif|ico|svg)$'

is_video() { printf '%s' "$1" | grep -qiE "$vid_re"; }

# Ordered media list of $dir (images + videos), one path per line. Natural sort
# (`sort -V`) + no dotfiles, to match vifm's view (`set sortnumbers`, hidden off).
media() {
    find "$dir" -maxdepth 1 -type f ! -name '.*' 2>/dev/null \
        | grep -iE "$img_re|$vid_re" | sort -V
}

# Cache path for a video's thumbnail (keyed on realpath + mtime).
thumb_for() {
    key=$(printf '%s\037%s' "$(readlink -f -- "$1")" "$(stat -c %Y -- "$1" 2>/dev/null)" \
          | sha1sum | cut -c1-40)
    printf '%s/%s.jpg' "$cache" "$key"
}

# Centred ▶ play button onto $1 (in place), ~28% of the poster's height so it
# scales with the thumbnail (videos stay distinguishable from images).
overlay_play() {
    ph=$(magick identify -format '%h' "$1" 2>/dev/null); [ -n "$ph" ] || ph=400
    d=$((ph * 28 / 100)); [ "$d" -lt 60 ] && d=60
    magick "$1" \
        \( -size "${d}x${d}" xc:none \
           -fill 'rgba(0,0,0,0.45)' -draw "circle $((d/2)),$((d/2)) $((d/2)),$((d/20))" \
           -fill 'rgba(255,255,255,0.9)' \
           -draw "polygon $((d*38/100)),$((d*30/100)) $((d*38/100)),$((d*70/100)) $((d*74/100)),$((d/2))" \) \
        -gravity center -compose over -composite "$1" 2>/dev/null
}

# The shared generic tile shown for videos whose poster isn't cached yet:
# hestia ground + the ▶ overlay, built once.
placeholder="$cache/placeholder.jpg"
gen_placeholder() {
    [ -s "$placeholder" ] && return
    tmp="$placeholder.$$.jpg"
    magick -size 960x540 xc:'#1a1a1a' "$tmp" 2>/dev/null || return
    overlay_play "$tmp"
    mv "$tmp" "$placeholder" 2>/dev/null
}

# Generate a video thumbnail (poster frame + ▶ overlay) if not already cached.
gen_thumb() {
    f=$1; t=$(thumb_for "$f")
    [ -s "$t" ] && return
    tmp="$t.$$.jpg"   # .jpg so ffmpeg/ffmpegthumbnailer infer the output format
    if command -v ffmpegthumbnailer >/dev/null 2>&1; then
        ffmpegthumbnailer -i "$f" -o "$tmp" -s 1280 -q 8 2>/dev/null
    else
        # fallback: a frame ~1s in, else the very first frame (short clips)
        ffmpeg -y -loglevel error -ss 1 -i "$f" -frames:v 1 \
            -vf "scale='min(1280,iw)':-2" "$tmp" </dev/null 2>/dev/null
        [ -s "$tmp" ] || ffmpeg -y -loglevel error -i "$f" -frames:v 1 \
            -vf "scale='min(1280,iw)':-2" "$tmp" </dev/null 2>/dev/null
    fi
    [ -s "$tmp" ] || { rm -f "$tmp"; return; }
    overlay_play "$tmp"
    mv "$tmp" "$t" 2>/dev/null
}

# Display path imv should show for a file: itself for images; for videos the
# cached poster, else the shared placeholder (never the raw video — imv can't
# decode it).
display_of() {
    if is_video "$1"; then
        t=$(thumb_for "$1"); [ -s "$t" ] && printf '%s' "$t" || printf '%s' "$placeholder"
    else
        printf '%s' "$1"
    fi
}

# Internal: `imv-browse.sh __backfill <listfile>` — the detached worker.
# Generates missing posters for every video in the list, one at a time, at
# idle CPU/IO priority, then removes the list. Lock-guarded by PID so only
# one worker runs at a time.
if [ "$cur" = "__backfill" ]; then
    qf=$dir
    echo $$ > "$genlock"
    trap 'rm -f "$genlock" "$qf"' EXIT INT TERM
    renice -n 19 -p $$ >/dev/null 2>&1
    ionice -c 3 -p $$ 2>/dev/null
    while IFS= read -r f; do
        [ -n "$f" ] && is_video "$f" && gen_thumb "$f"
    done < "$qf"
    exit 0
fi

pid=$(pgrep -u "$USER" -x imv-wayland | head -1)
if [ -n "$pid" ]; then
    # imv already open: select the cursor file by its index in the session map.
    idx=$(grep -nxF -- "$cur" "$session" 2>/dev/null | head -1 | cut -d: -f1)
    [ -n "$idx" ] && imv-msg "$pid" goto "$idx"
    swaymsg '[app_id="imv"] focus' >/dev/null 2>&1
    exit 0
fi

# Launch lock: only ONE first-open may be in flight. A repeated Enter while
# this launch prepares (the pgrep above can't see imv yet) exits silently
# instead of stacking a second launch. PID-checked, so a crashed launcher
# leaves no dead-end.
if [ -e "$launchlock" ] && kill -0 "$(cat "$launchlock" 2>/dev/null)" 2>/dev/null; then
    exit 0
fi
echo $$ > "$launchlock"
trap 'rm -f "$launchlock"' EXIT INT TERM

origs=$(media)
printf '%s\n' "$origs" > "$session"

gen_placeholder
# The SELECTED file gets its real poster now (one file, bounded); everyone
# else gets it from the background worker below.
is_video "$cur" && gen_thumb "$cur"

# Backfill the rest in a single detached worker (self-invocation with the
# __backfill mode above): idle CPU/IO priority, strictly sequential, so it is
# invisible next to the foreground session. Lock-guarded — if a worker is
# already busy (this dir or another), skip; the next visit retries. The
# worker outlives this script (which execs imv) and holds no tty.
if ! { [ -e "$genlock" ] && kill -0 "$(cat "$genlock" 2>/dev/null)" 2>/dev/null; }; then
    qf="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-thumbqueue.$$"
    printf '%s\n' "$origs" > "$qf"
    setsid -f "$(readlink -f -- "$0")" __backfill "$qf" >/dev/null 2>&1
fi

# First open: integrated layout, then imv on the DISPLAY list at the cursor file.
vremote -c only
swaymsg split horizontal
set --
while IFS= read -r f; do
    [ -n "$f" ] && set -- "$@" "$(display_of "$f")"
done <<EOF
$origs
EOF
rm -f "$launchlock"; trap - EXIT INT TERM
exec env imv_config="$HOME/.config/imv/config-vifm" imv-wayland -n "$(display_of "$cur")" "$@"
