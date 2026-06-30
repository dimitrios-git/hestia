#!/usr/bin/env sh
# screenshot.sh — region screenshot, saved either locally or to the shared tree.
#
# Bound in the sway config to Print (local) and $mod+Print (shared). A SHARED
# shot lands in /srv/clipshare, which the unprivileged `claude` user can Read
# (devshare group + the tree's default ACLs) — this is the supported way to
# show Claude Code an image: it runs as a separate user, walled off from this
# session's Wayland clipboard, so a Ctrl+V image paste into it can't work. A
# LOCAL shot stays in ~/Pictures/Screenshots and is never exposed to claude.
#
# The saved file's PATH is copied to the Wayland clipboard (as text) on every
# shot. This is what makes the claude workflow one step: after $mod+Print, just
# paste the path into Claude Code and it reads the file from /srv/clipshare.
# Copying the path is fine across the user boundary — the wall only stops claude
# from *reading* this clipboard; the script runs as the human and writes to the
# human's own clipboard. (Only the Wayland *image* clipboard is unreachable to
# claude, which is exactly why we hand over a path, not an image.)
#
# Usage: screenshot.sh [local|shared]   (default: local)
#
# `shared` falls back to the local dir when /srv/clipshare isn't provisioned
# (a spin without the claude_user feature), so the binding works either way —
# the notification shows where the file actually landed.

set -eu

local_dir="$HOME/Pictures/Screenshots"

case "${1:-local}" in
    shared)
        if [ -d /srv/clipshare ] && [ -w /srv/clipshare ]; then
            dir=/srv/clipshare
        else
            dir="$local_dir"
        fi
        ;;
    *)
        dir="$local_dir"
        ;;
esac
mkdir -p "$dir"

# Region select; exit cleanly if slurp is cancelled (Esc/right-click).
geom=$(slurp) || exit 0
out="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
grim -g "$geom" "$out"

# Copy the saved path (no trailing newline) to the clipboard so it can be pasted
# straight away — e.g. into Claude Code for a shared shot. Non-fatal under set -e
# so a clipboard hiccup never loses the (already-saved) screenshot or its notice.
printf '%s' "$out" | wl-copy || true

notify-send "Screenshot saved" "$out
path copied to clipboard"
