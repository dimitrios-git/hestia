#!/bin/sh
# Reliable waybar launch for Sway. Works around the boot race where waybar starts
# before the compositor is ready to map its layer-shell surface, so the bar never
# renders until a `$mod+Shift+c` reload. Replaces the old `exec_always pkill
# waybar; waybar`: kill any running instance, give the session a moment to settle
# AND wait for sway to report an active output, then exec waybar. Used by an
# exec_always line in sway/config — see CLAUDE.md (Waybar).
pkill -x waybar 2>/dev/null

# brief settle, then wait (up to ~5s) for at least one active output
sleep 0.5
i=0
while [ "$i" -lt 50 ]; do
    swaymsg -t get_outputs 2>/dev/null | grep -q '"active": true' && break
    sleep 0.1
    i=$((i + 1))
done

exec waybar
