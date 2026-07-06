#!/bin/sh
# imv-browse.sh <cursor-file> <dir> — vifm's image/video browse launcher, opened
# by the image AND video filextype handlers (Enter/l, or vifm's builtin `i`).
#
# Browses images AND videos in one imv window. imv can't play video, so each
# video is shown as a cached **poster-frame thumbnail with a ▶ overlay**; imv
# just sees images. A session map (one `display<US>original` pair per line,
# US = 0x1f) lets everything downstream resolve imv's current item back to the
# real file: the live cursor sync (imv-vifm-return.sh), and Enter→mpv on a
# video. Resolution is BY DISPLAY PATH ($imv_current_file), NOT by index: imv
# silently DROPS entries it can't load (one corrupt image / unsupported
# format), shifting every later index — resolved-by-index, one bad file made
# every subsequent poster "belong" to the wrong video (caught live). For the
# path to be a unique key, uncached videos each get their OWN placeholder
# hardlink (<thumbkey>.pend.jpg — imv canonicalizes symlinks, so those would
# all report as placeholder.jpg; hardlinks report verbatim).
#
# PRIORITY ORDER (redesigned 2026-07 after a 2000-video directory locked the
# whole flow for minutes): the SELECTED file first, the session second,
# thumbnails last. Only the cursor file's poster is generated synchronously
# (bounded: one file); every other uncached video shows a shared generic
# ▶ placeholder and imv launches IMMEDIATELY. A single idle-priority
# (nice/ionice) background worker then backfills the real posters
# sequentially, so the NEXT visit to the directory has them — placeholders
# already shown in the current imv session stay placeholders (imv's list is
# fixed at launch). The display list is mapped in ONE python pass, not a
# per-file shell loop — the loop's ~6 forks per file were a second,
# independent multi-second hang on huge dirs. A PID-checked launch lock
# makes an Enter-storm harmless:
# while one launch is in flight, further invocations exit instead of stacking
# imv windows (the old pgrep-only check misses the pre-imv window).
#
# Re-press while imv is open: jump it to the cursor file (imv-msg goto <index>,
# index from the session map) and focus — no second pane. If the cursor file
# is NOT in the open session (vifm moved to another directory, or the file is
# new), the old imv is torn down and a fresh session launches on this dir.
#
# TWO-WAY SYNC: imv→vifm is event-driven (each j/k bind execs
# imv-vifm-return.sh). vifm→imv can't be — vifm has no cursor-move autocmd
# (only DirEnter) — so a detached WATCHER (__watch mode) polls the launching
# vifm's cursor over `--remote-expr 'expand("%c:p")'` (~5ms a call) while imv
# lives, and gotos imv to it. So vifm keeps its powers during a browse:
# `/search` + `n`, marks, `gs` — the cursor lands, imv follows. Feedback-fight
# guard (imv j/k → vifm goto → watcher must NOT push imv back): the return
# script records each imv-originated sync in a marker file the watcher skips,
# and the watcher only acts on a cursor position STABLE for two consecutive
# polls (a fast imv-side scroll never presents a stable, unmarked position).

cur=$1
dir=$2

# Drive THE LAUNCHING vifm instance, not whichever registered the "vifm" server
# name first: vifmrc exports $VIFM_SERVER_NAME (v:servername) to its children,
# and imv inherits it through us for imv-vifm-return.sh. Without this, a second
# open vifm got the collapse/sync commands meant for this one.
sname=${VIFM_SERVER_NAME:-vifm}
vremote() { vifm --server-name "$sname" --remote "$@"; }

cache="${XDG_CACHE_HOME:-$HOME/.cache}/imv-vifm-thumbs"
rt="${XDG_RUNTIME_DIR:-/tmp}"
# Per-vifm-instance session state (suffixed by the server name), so browse
# sessions from different vifm windows coexist. The thumbnail cache, its
# worker + genlock, and the queue stay GLOBAL (shared resource).
session="$rt/imv-vifm-session.$sname.list"
launchlock="$rt/imv-vifm-launch.$sname.lock"
watchlock="$rt/imv-vifm-watch.$sname.lock"
lastsync="$rt/imv-vifm-lastsync.$sname"
imvpidf="$rt/imv-vifm-imv.$sname.pid"
genlock="$rt/imv-vifm-thumbgen.lock"
mkdir -p "$cache"

# THIS session's imv PID, or nothing. The launcher execs imv, so its own $$
# BECOMES imv's PID — recorded in $imvpidf before the exec, validated here
# against /proc comm (PID reuse). Never found by pgrep: a bare
# `pgrep imv-wayland` matches ANY imv — a standalone one, or another vifm
# window's session — and the new-directory teardown used to KILL it
# (caught live: opening a preview in a second vifm closed the first imv).
our_imv() {
    p=$(cat "$imvpidf" 2>/dev/null)
    case $p in '' | *[!0-9]*) return 1 ;; esac
    [ "$(cat "/proc/$p/comm" 2>/dev/null)" = "imv-wayland" ] || return 1
    printf '%s' "$p"
}

vid_re='\.(mp4|mkv|avi|mov|webm|flv|m4v|mpe?g|wmv|ts|m2v|ogv|3gp|vob)$'
img_re='\.(jpe?g|png|gif|bmp|tiff?|webp|avif|ico|svg)$'

is_video() { printf '%s' "$1" | grep -qiE "$vid_re"; }

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

# The blank "no preview" tile (plain ground, no ▶): appended as one EXTRA
# last item of every imv list; the watcher steers imv onto it whenever
# vifm's cursor is not on a media file of this session, so imv goes visibly
# empty instead of freezing on the last image (or paying a relaunch).
blank="$cache/blank.jpg"
gen_blank() {
    [ -s "$blank" ] && return
    tmp="$blank.$$.jpg"
    magick -size 960x540 xc:'#1a1a1a' "$tmp" 2>/dev/null || return
    mv "$tmp" "$blank" 2>/dev/null
}

# Generate a video thumbnail (poster frame + ▶ overlay) if not already cached.
gen_thumb() {
    f=$1; t=$(thumb_for "$f")
    [ -s "$t" ] && return
    tmp="$t.$$.jpg"   # .jpg so ffmpeg/ffmpegthumbnailer infer the output format
    # timeout: a corrupt file / stalled network mount must never wedge the
    # launch (cursor poster is synchronous) or dead-end the backfill queue
    if command -v ffmpegthumbnailer >/dev/null 2>&1; then
        timeout 15 ffmpegthumbnailer -i "$f" -o "$tmp" -s 1280 -q 8 2>/dev/null
    else
        # fallback: a frame ~1s in, else the very first frame (short clips)
        timeout 15 ffmpeg -y -loglevel error -ss 1 -i "$f" -frames:v 1 \
            -vf "scale='min(1280,iw)':-2" "$tmp" </dev/null 2>/dev/null
        [ -s "$tmp" ] || timeout 15 ffmpeg -y -loglevel error -i "$f" -frames:v 1 \
            -vf "scale='min(1280,iw)':-2" "$tmp" </dev/null 2>/dev/null
    fi
    [ -s "$tmp" ] || { rm -f "$tmp"; return; }
    overlay_play "$tmp"
    mv "$tmp" "$t" 2>/dev/null
}

# Display path imv should show for a file: itself for images; for videos the
# cached poster, else the video's OWN placeholder hardlink (never the raw
# video — imv can't decode it). Must mirror build_lists' mapping. ONLY for
# one-off lookups (the cursor file, `-n`): each call costs ~6 subprocesses,
# so the full list goes through build_lists below instead.
display_of() {
    if is_video "$1"; then
        t=$(thumb_for "$1")
        [ -s "$t" ] && printf '%s' "$t" || printf '%s' "${t%.jpg}.pend.jpg"
    else
        printf '%s' "$1"
    fi
}

# The whole-directory pass, ONE python process (the per-file shell version —
# grep+readlink+stat+sha1sum+cut per file — cost ~7s of pure fork overhead on
# a 2000-video directory): lists the media, sorts it, writes the session map
# (display<US>original pairs) and the backfill queue (ONLY the videos still
# missing a poster, so a fully-cached directory spawns no worker at all), and
# prints the display list — same display rules as display_of, byte-identical
# sha1 keys. Each uncached video gets its own placeholder HARDLINK
# (<key>.pend.jpg) so its display path is a unique key (see header); stale
# pend links are pruned here — the pass only ever runs with no imv open, so
# none of them is on screen.
#
# THE ORDER REPLICATES VIFM 0.14 EXACTLY (sort.c + utils/utf8.c for
# `sort +name` with `set sortnumbers`): sort key = NFKD compat-decomposition
# of the name (utf8proc — why "Ä" sorts with "A", before "B"), compared by
# skip-leading-zeros + glibc strverscmp (called via ctypes: the very same
# libc function, not a reimplementation). `sort -V` was only an
# approximation — coreutils filevercmp has its own extension rule and no
# unicode normalization — and every divergence made the imv->vifm synced
# cursor JUMP. Verified byte-identical against a live vifm on an adversarial
# name set (case, leading zeros, spaces vs dots, unicode).
# Keep the regexes in sync with vid_re/img_re above.
build_lists() {
    python3 - "$cache" "$placeholder" "$dir" "$session" "$1" <<'PYEOF'
import sys, os, re, hashlib, ctypes, unicodedata, functools
cache, placeholder, dirp, session, qf = (os.fsencode(a) for a in sys.argv[1:6])
vid = re.compile(rb"\.(mp4|mkv|avi|mov|webm|flv|m4v|mpe?g|wmv|ts|m2v|ogv|3gp|vob)$", re.I)
img = re.compile(rb"\.(jpe?g|png|gif|bmp|tiff?|webp|avif|ico|svg)$", re.I)

libc = ctypes.CDLL("libc.so.6")
libc.strverscmp.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
libc.strverscmp.restype = ctypes.c_int
# utf8proc's UTF8PROC_IGNORE strips default-ignorables; the common set
IGNORABLE = dict.fromkeys(map(ord, "­​‌‍⁠﻿"))

def key(nb):
    try:
        s = unicodedata.normalize("NFKD", nb.decode("utf-8", "surrogateescape"))
        b = s.translate(IGNORABLE).encode("utf-8", "surrogateescape")
    except Exception:
        b = nb
    i = 0
    while b[i:i+1] == b"0" and b[i+1:i+2].isdigit():
        i += 1
    return b[i:]

names = [e.name for e in os.scandir(dirp)
         if e.is_file() and not e.name.startswith(b".")
         and (vid.search(e.name) or img.search(e.name))]
names.sort(key=functools.cmp_to_key(lambda a, b: libc.strverscmp(key(a), key(b))))

# prune stale pend hardlinks (no imv is open when this pass runs)
for e in os.scandir(cache):
    if e.name.endswith(b".pend.jpg"):
        try:
            os.unlink(e.path)
        except OSError:
            pass

out, queue = sys.stdout.buffer, []
with open(session, "wb") as smap:
    for n in names:
        f = os.path.join(dirp, n)
        if vid.search(n):
            try:
                k = hashlib.sha1(os.path.realpath(f) + b"\x1f"
                                 + str(int(os.stat(f).st_mtime)).encode()).hexdigest()[:40]
            except OSError:
                k = None
            disp = None
            if k is not None:
                t = os.path.join(cache, k.encode() + b".jpg")
                try:
                    if os.path.getsize(t) > 0:
                        disp = t
                except OSError:
                    pass
            if disp is None:
                queue.append(f)
                disp = placeholder              # last-resort shared fallback
                if k is not None:
                    pend = os.path.join(cache, k.encode() + b".pend.jpg")
                    try:
                        os.link(placeholder, pend)
                        disp = pend
                    except FileExistsError:
                        disp = pend
                    except OSError:
                        pass
        else:
            disp = f
        smap.write(disp + b"\x1f" + f + b"\n")
        out.write(disp + b"\n")
with open(qf, "wb") as fh:
    fh.write(b"\n".join(queue) + (b"\n" if queue else b""))
PYEOF
}

# Internal: `imv-browse.sh __backfill <listfile>` — the detached worker.
# Generates the missing posters (the list is pre-filtered by display_list),
# one at a time, at idle CPU/IO priority, then removes the list. Lock-guarded
# by PID so only one worker runs at a time.
if [ "$cur" = "__backfill" ]; then
    qf=$dir
    echo $$ > "$genlock"
    trap 'rm -f "$genlock" "$qf"' EXIT INT TERM
    renice -n 19 -p $$ >/dev/null 2>&1
    ionice -c 3 -p $$ 2>/dev/null
    while IFS= read -r f; do
        [ -n "$f" ] && gen_thumb "$f"
    done < "$qf"
    exit 0
fi

# Internal: `imv-browse.sh __watch <dir>` — the vifm→imv cursor watcher (see
# header). Waits for imv to appear (spawned just before the launcher execs
# it), then follows the launching vifm's cursor until imv exits. PID-locked
# so only one watcher runs. Also the session's chaperone: vifm LEAVING <dir>
# closes imv (restoring the dual-pane preview first), and a cursor parked on
# anything that isn't this session's media (unsupported file, a directory,
# `..`) steers imv onto the trailing blank tile — visibly empty, no stale
# image, no relaunch.
if [ "$cur" = "__watch" ]; then
    echo $$ > "$watchlock"
    trap 'rm -f "$watchlock"' EXIT INT TERM
    # wait for THIS session's imv (the launcher's exec'd PID) — never pgrep,
    # which could latch onto a standalone imv or another session's
    imvpid=
    i=0
    while [ $i -lt 50 ]; do
        imvpid=$(our_imv) && break
        imvpid=
        i=$((i + 1)); sleep 0.1
    done
    [ -n "$imvpid" ] || exit 0
    blankidx=$(( $(wc -l < "$session" 2>/dev/null || echo 0) + 1 ))
    prev= last= dirmiss=0
    while kill -0 "$imvpid" 2>/dev/null; do
        sleep 0.15
        # expand() returns macro-expanded values SHELL-ESCAPED ("my\ pictures")
        # while $dir/$cur/the session map hold raw paths — unescape or every
        # comparison fails in any folder with a space (caught live: imv closed
        # the instant it opened there, "pictures worked, my pictures didn't").
        d=$(vifm --server-name "${VIFM_SERVER_NAME:-vifm}" \
                 --remote-expr 'expand("%d")' 2>/dev/null | sed 's/\\\(.\)/\1/g')
        if [ -n "$d" ] && [ "$d" != "$dir" ]; then
            # vifm seems to have moved to another folder. Close ONLY on two
            # consecutive such reads of an absolute path — one garbled/error
            # read (a busy server) must not kill the session.
            case $d in
                /*) dirmiss=$((dirmiss + 1)) ;;
                *)  dirmiss=0 ;;
            esac
            if [ "$dirmiss" -ge 2 ]; then
                # session over: restore the dual-pane preview and close imv
                # (imv's death also ends this loop; kill = wedged-imv fallback).
                vremote -c 'vsplit' -c 'view!'
                imv-msg "$imvpid" quit 2>/dev/null
                sleep 0.5
                kill "$imvpid" 2>/dev/null
                exit 0
            fi
            continue
        fi
        dirmiss=0
        c=$(vifm --server-name "${VIFM_SERVER_NAME:-vifm}" \
                 --remote-expr 'expand("%c:p")' 2>/dev/null | sed 's/\\\(.\)/\1/g')
        [ -n "$c" ] || continue
        if [ "$c" != "$prev" ]; then prev=$c; continue; fi   # not stable yet
        [ "$c" = "$last" ] && continue                        # already synced
        if [ "$c" = "$(cat "$lastsync" 2>/dev/null)" ]; then
            # imv-originated move: absorb it and CONSUME the marker — left in
            # place it would also block a later genuine vifm return to this
            # same file (re-check before rm narrows the race with a marker
            # being rewritten by a concurrent imv keypress).
            [ "$c" = "$(cat "$lastsync" 2>/dev/null)" ] && rm -f "$lastsync"
            last=$c; continue
        fi
        idx=$(cur="$c" awk -F '\037' 'index($0, "\037") && substr($0, index($0, "\037") + 1) == ENVIRON["cur"] { print NR; exit }' "$session" 2>/dev/null)
        # not this session's media -> the blank tile (last imv item)
        imv-msg "$imvpid" goto "${idx:-$blankidx}" >/dev/null 2>&1
        last=$c
    done
    exit 0
fi

if pid=$(our_imv); then
    # THIS session's imv is open: select the cursor file by its line number
    # in the session map (imv's goto only takes an index — if imv dropped an
    # unloadable entry this can land one off, and the next j/k sync
    # self-corrects; the path-keyed resolution the other direction uses is
    # in imv-vifm-return.sh). Focus by PID — [app_id="imv"] would grab
    # whichever imv sway finds first.
    idx=$(cur="$cur" awk -F '\037' 'index($0, "\037") && substr($0, index($0, "\037") + 1) == ENVIRON["cur"] { print NR; exit }' "$session" 2>/dev/null)
    if [ -n "$idx" ]; then
        imv-msg "$pid" goto "$idx"
        swaymsg "[pid=$pid] focus" >/dev/null 2>&1
        exit 0
    fi
    # Cursor file isn't in the open session — vifm is in another directory
    # (or the file appeared after launch): retire OUR imv (only ours — a
    # standalone imv or another vifm's session is untouchable) and fall
    # through to a fresh launch on the current dir. (imv-msg quit skips
    # imv's q bind, so no layout restore fires — we re-split just below.)
    imv-msg "$pid" quit 2>/dev/null
    sleep 0.2
    kill "$pid" 2>/dev/null
fi

# Launch lock: only ONE first-open may be in flight. A repeated Enter while
# this launch prepares (the our_imv check above can't see imv yet) exits silently
# instead of stacking a second launch. PID-checked, so a crashed launcher
# leaves no dead-end.
if [ -e "$launchlock" ] && kill -0 "$(cat "$launchlock" 2>/dev/null)" 2>/dev/null; then
    exit 0
fi
echo $$ > "$launchlock"
trap 'rm -f "$launchlock"' EXIT INT TERM

gen_placeholder
gen_blank
# The SELECTED file gets its real poster now (one file, bounded); everyone
# else gets it from the background worker below.
is_video "$cur" && gen_thumb "$cur"

# One pass: media list in vifm's exact order, session map, display list for
# imv, and the queue of posters still missing (runs after the cursor's
# gen_thumb, so its fresh poster is already seen).
qf="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-thumbqueue.$$"
display=$(build_lists "$qf")

# Backfill the missing posters in a single detached worker (self-invocation
# with the __backfill mode above): idle CPU/IO priority, strictly sequential,
# so it is invisible next to the foreground session. Lock-guarded — if a
# worker is already busy (this dir or another), skip; the next visit retries.
# The worker outlives this script (which execs imv) and holds no tty.
if [ -s "$qf" ] \
   && ! { [ -e "$genlock" ] && kill -0 "$(cat "$genlock" 2>/dev/null)" 2>/dev/null; }; then
    setsid -f "$(readlink -f -- "$0")" __backfill "$qf" >/dev/null 2>&1
else
    rm -f "$qf"
fi

# First open: integrated layout, then imv on the DISPLAY list at the cursor
# file. argv is built by ONE newline field-split (glob off) — the incremental
# `set -- "$@" f` read-loop recopies the whole list per item, O(N^2): ~1s of
# pure shell at 2700 files. (Newlines in filenames are already unsupported —
# the session map is line-based.)
vremote -c only
swaymsg split horizontal
set -f; IFS='
'
# shellcheck disable=SC2086  # the split IS the point
set -- $display
set +f; unset IFS
# the blank "no preview" tile rides along as one extra LAST item (indexes
# 1..N still equal the session map's lines; the watcher gotos N+1)
set -- "$@" "$blank"

# vifm→imv cursor watcher (the __watch mode above): spawned detached just
# before imv, it waits for the imv PID, then follows vifm's cursor until imv
# exits. Seed the imv-origin marker with the cursor file so the watcher's
# first stable read (= where we're opening) isn't treated as a user move.
printf '%s' "$cur" > "$lastsync"
if ! { [ -e "$watchlock" ] && kill -0 "$(cat "$watchlock" 2>/dev/null)" 2>/dev/null; }; then
    setsid -f "$(readlink -f -- "$0")" __watch "$dir" >/dev/null 2>&1
fi

rm -f "$launchlock"; trap - EXIT INT TERM
# exec preserves the PID: $$ IS the imv PID. Recorded per server name so
# every later command (re-press, watcher, teardown) targets exactly THIS
# session's imv and no other instance.
echo $$ > "$imvpidf"
exec env imv_config="$HOME/.config/imv/config-vifm" imv-wayland -n "$(display_of "$cur")" "$@"
