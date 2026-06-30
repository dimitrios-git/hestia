#!/bin/sh
# imv-vifm-return.sh [quit|up|play] — run by imv (config-vifm) when imv was
# launched from vifm's image/video browse. Kept as a script so imv binds stay
# trivial (`exec …/imv-vifm-return.sh [mode]`): imv splits binds on ';' and
# parses each part as an imv command, and inline shell quoting in a bind gets
# mangled — a bare script path has nothing to misparse.
#
# Resolves imv's `$imv_current_index` to the ORIGINAL file via the session map
# imv-browse.sh wrote (line N = imv item N) — because for a video, imv shows a
# thumbnail, so $imv_current_file is the thumb, not the video. ($imv_pid is the
# imv instance.)
#
#   (no arg)  live sync — move vifm's cursor onto the current item (each j/k)
#   quit      also restore vifm's dual-pane preview, then close imv (q)
#   up        restore the preview + take vifm UP one dir, then close imv (h)
#   play      if the current item is a video, open it in mpv (Enter)
#
# :goto SELECTS without opening (a plain `--remote <file>` would re-open it).
# vifm --remote no-ops if no vifm server is running.

session="${XDG_RUNTIME_DIR:-/tmp}/imv-vifm-session.list"
orig=$(sed -n "${imv_current_index}p" "$session" 2>/dev/null)
[ -n "$orig" ] || orig=$imv_current_file   # fallback (images-only / no map)

is_video() {
    printf '%s' "$1" | grep -qiE '\.(mp4|mkv|avi|mov|webm|flv|m4v|mpe?g|wmv|ts|m2v|ogv|3gp|vob)$'
}

close_imv() {
    # ask imv to quit, then guarantee the window closes. Guard the pid: empty/0/
    # non-numeric must NOT reach `kill` (kill 0 signals the whole process group).
    case "$imv_pid" in
        '' | 0 | *[!0-9]*) return ;;
    esac
    imv-msg "$imv_pid" quit 2>/dev/null
    kill "$imv_pid" 2>/dev/null
}

case "$1" in
    quit)
        vifm --remote -c 'vsplit' -c 'view!' -c "goto '$orig'"
        close_imv
        ;;
    up)
        # up one dir from the ORIGINAL's folder (absolute), not vifm's current
        # dir — the user may have moved vifm's cwd while imv was open.
        vifm --remote -c 'vsplit' -c 'view!' -c "goto '$(dirname "$orig")'"
        close_imv
        ;;
    play)
        # Enter: promote a video to mpv (images do nothing — already full-screen).
        is_video "$orig" && setsid -f mpv -- "$orig" >/dev/null 2>&1
        ;;
    *)
        vifm --remote -c "goto '$orig'"
        ;;
esac
