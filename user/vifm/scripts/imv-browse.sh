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
# First open: collapse vifm to one pane, split sway, generate any missing video
# thumbnails (cached by path+mtime, in parallel), then open imv tiled RIGHT on
# the explicit, sorted DISPLAY list (real images + video thumbnails), at the
# cursor file. Re-press while imv is open: jump it to the cursor file
# (imv-msg goto <index>, index from the session map) and focus — no second pane.

cur=$1
dir=$2

# Drive THE LAUNCHING vifm instance, not whichever registered the "vifm" server
# name first: vifmrc exports $VIFM_SERVER_NAME (v:servername) to its children,
# and imv inherits it through us for imv-vifm-return.sh. Without this, a second
# open vifm got the collapse/sync commands meant for this one.
vremote() { vifm --server-name "${VIFM_SERVER_NAME:-vifm}" --remote "$@"; }

cache="${XDG_CACHE_HOME:-$HOME/.cache}/imv-vifm-thumbs"
session="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-session.list"
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
    # centred ▶ play button, ~28% of the poster's height so it scales with the
    # thumbnail (videos stay distinguishable from images at any size).
    ph=$(magick identify -format '%h' "$tmp" 2>/dev/null); [ -n "$ph" ] || ph=400
    d=$((ph * 28 / 100)); [ "$d" -lt 60 ] && d=60
    magick "$tmp" \
        \( -size "${d}x${d}" xc:none \
           -fill 'rgba(0,0,0,0.45)' -draw "circle $((d/2)),$((d/2)) $((d/2)),$((d/20))" \
           -fill 'rgba(255,255,255,0.9)' \
           -draw "polygon $((d*38/100)),$((d*30/100)) $((d*38/100)),$((d*70/100)) $((d*74/100)),$((d/2))" \) \
        -gravity center -compose over -composite "$t" 2>/dev/null || mv "$tmp" "$t"
    rm -f "$tmp"
}

# Display path imv should show for a file: itself for images, its thumb (if it
# generated) for videos.
display_of() {
    if is_video "$1"; then
        t=$(thumb_for "$1"); [ -s "$t" ] && printf '%s' "$t" || printf '%s' "$1"
    else
        printf '%s' "$1"
    fi
}

pid=$(pgrep -u "$USER" -x imv-wayland | head -1)
if [ -n "$pid" ]; then
    # imv already open: select the cursor file by its index in the session map.
    idx=$(grep -nxF -- "$cur" "$session" 2>/dev/null | head -1 | cut -d: -f1)
    [ -n "$idx" ] && imv-msg "$pid" goto "$idx"
    swaymsg '[app_id="imv"] focus' >/dev/null 2>&1
    exit 0
fi

origs=$(media)
printf '%s\n' "$origs" > "$session"

# Generate missing video thumbnails, up to 4 in parallel.
n=0
while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_video "$f" || continue
    t=$(thumb_for "$f"); [ -s "$t" ] && continue
    gen_thumb "$f" &
    n=$((n + 1)); [ $((n % 4)) -eq 0 ] && wait
done <<EOF
$origs
EOF
wait

# First open: integrated layout, then imv on the DISPLAY list at the cursor file.
vremote -c only
swaymsg split horizontal
set --
while IFS= read -r f; do
    [ -n "$f" ] && set -- "$@" "$(display_of "$f")"
done <<EOF
$origs
EOF
exec env imv_config="$HOME/.config/imv/config-vifm" imv-wayland -n "$(display_of "$cur")" "$@"
