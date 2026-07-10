#!/bin/sh
# vifm quick-view dispatcher — the catch-all `fileviewer {*}` in vifmrc.
# Syntax-highlights text/code with bat (hestia theme + git change gutter),
# and degrades cleanly:
# directory listing for dirs, file-type + hexdump peek for binaries, and plain
# head(1) when bat isn't installed. Always exits 0 so vifm never shows an error.
#
#   $1 = file path (vifm %f)   $2 = pane width (%pw)   $3 = pane height (%ph)
#
# bat needs the hestia theme built into its cache once: `bat cache --build`
# after ~/.config/bat/themes/hestia.tmTheme is in place (the dotfiles role
# does this). Until then bat falls back to its default theme.

f="$1"
w="${2:-80}"
h="${3:-40}"

# Belt-and-suspenders: if $1 isn't a real path, don't run `file` on it. The
# vifmrc catch-all passes %c:p (always a path), but were a vifm macro to expand
# to nothing the args would shift and a pane dimension would land in $1 — that's
# the historical `cannot open '48'` on the ".." entry. Bail with a blank preview.
[ -e "$f" ] || [ -L "$f" ] || exit 0

# bat is `bat` on most distros but `batcat` on Debian/Ubuntu — accept either.
BAT=""
if command -v bat >/dev/null 2>&1; then
    BAT=bat
elif command -v batcat >/dev/null 2>&1; then
    BAT=batcat
fi

# Truncate each preview line to $w visible columns, ANSI-aware (SGR escapes don't
# count toward width). WHY: vifm 0.14 has no nowrap option for the preview and
# WRAPS long lines; bat (like most tools) emits full-length lines and leaves
# clipping to the terminal — so bat's own --wrap=never has no effect in the notty
# preview pipe. We clip here so long lines match vim/neovim `nowrap` instead of
# wrapping the pane. awk (not python) keeps the per-cursor-move preview snappy.
clip_cols() {
    awk -v w="$w" '{
        n=0; out=""; i=1; L=length($0)
        while (i<=L) {
            if (substr($0,i,1)=="\033" && substr($0,i+1,1)=="[") {
                # consume an SGR escape (ESC [ ... m) without counting width
                j=i+2
                while (j<=L && index("0123456789;",substr($0,j,1))>0) j++
                out=out substr($0,i,j-i+1); i=j+1
            } else { if (n>=w) break; out=out substr($0,i,1); i++; n++ }
        }
        print out "\033[0m"
    }'
}

bat_view() {
    # --style=numbers,changes: line numbers + bat's git gutter (+ added,
    # ~ modified) — a quick cue for UNCOMMITTED edits (working tree vs HEAD; NOT
    # branch-vs-base — that's what :gd in vifmrc is for). Needs bat built with git
    # support + the file in a repo; bat degrades to no gutter otherwise (incl.
    # non-git files, so no wasted column). On the claude-owned /srv/devshare repos
    # it relies on the same safe.directory whitelist as git (libgit2 reads it); if
    # libgit2 can't read the repo it just omits the gutter — never errors.
    # Piped through clip_cols so long lines are truncated (not wrapped) in the pane.
    "$BAT" --color=always --style=numbers,changes --paging=never --wrap=never \
           --theme=hestia --terminal-width="$w" --line-range=":$h" -- "$f" | clip_cols
}

if [ -d "$f" ]; then
    # Directory: a coloured tree, two levels deep (the yazi/ranger-style dir
    # preview, 2026-07), capped to the pane height. tree -C colours via
    # LS_COLORS, so it matches ls and vifm's own file-type colours by
    # construction (all three render from the generated ~/.dircolors). .git is
    # pruned (pure noise at this depth); falls back to the old flat listing if
    # tree is ever absent (it's in the apt manifest).
    if command -v tree >/dev/null 2>&1; then
        tree -C -a -L 2 --dirsfirst --noreport -I .git -- "$f" 2>/dev/null | head -n "$h"
    else
        ls -A --group-directories-first -- "$f" 2>/dev/null || ls -A -- "$f"
    fi
    exit 0
fi

mime=$(file -Lb --mime-type -- "$f" 2>/dev/null)

case "$mime" in
    inode/x-empty)
        echo "(empty file)"
        ;;
    text/* | application/json | application/javascript | application/xml \
    | application/x-shellscript | application/x-yaml | application/x-toml \
    | application/x-perl | application/x-php | application/x-ruby \
    | *+json | *+xml)
        if [ -n "$BAT" ]; then
            bat_view
        else
            head -n "$h" -- "$f"
        fi
        ;;
    *)
        # Binary (or unknown): describe it, then a short hex peek.
        file -Lb -- "$f"
        echo
        if command -v hexdump >/dev/null 2>&1; then
            peek=$((h - 4)); [ "$peek" -lt 4 ] && peek=4
            hexdump -C -- "$f" 2>/dev/null | head -n "$peek"
        fi
        ;;
esac

exit 0
