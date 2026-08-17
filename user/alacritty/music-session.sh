#!/bin/sh
# hestia music session — cava (visualiser) stacked over cmus (player), the same
# layout as the old kitty --session music.session (kitty's own session/layout
# format). Rebuilt on tmux since Alacritty (the default terminal since the
# terminal-emulator evaluation, see showcase/terminal-emulator.md) has no
# session/layout feature of its own — tmux is hestia's default multiplexer
# anyway, so this composes two already-chosen defaults instead of inventing a
# third mechanism.
#
# Bound to $mod+m in user/sway/config as:
#   alacritty -e ~/.config/alacritty/music-session.sh
#
# Idempotent: a second $mod+m press attaches the existing session in a new
# window instead of stacking a duplicate cava+cmus pair (an improvement over
# the old kitty binding, which had no such guard). Quitting cmus kills the
# whole tmux session (cava included), so the window closes together — same
# teardown behaviour as the kitty version.
SESSION=hestia-music

if tmux has-session -t "$SESSION" 2>/dev/null; then
    exec tmux attach -t "$SESSION"
fi

tmux new-session -d -s "$SESSION" -n music 'cava'
# split-window's new pane (cmus) becomes the active one automatically — no
# explicit select-pane needed (and pane INDICES depend on the user's own
# pane-base-index setting, so hardcoding one here would be fragile).
tmux split-window -v -p 70 -t "$SESSION:music" "cmus; tmux kill-session -t $SESSION"
exec tmux attach -t "$SESSION"
