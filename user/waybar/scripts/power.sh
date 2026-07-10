#!/bin/sh
# Waybar custom/power — session/power actions (the ⏻ at the bar's far right).
# `power.sh menu` opens a wofi dmenu: Lock / Logout / Suspend / Reboot /
# Shutdown. Lock and Suspend act immediately; the destructive three (Logout
# ends the Wayland session, Reboot, Shutdown) first raise a `swaynag -t
# warning` confirm — the themed full-orange banner (user/swaynag/config-*)
# with an explicit action button, so a misclick can't take the machine down.
# No sudo anywhere: suspend/reboot/poweroff go through systemd-logind's
# polkit allowance for the active session; logout is `swaymsg exit`.
#
# Toggle contract (same as $mod+d / the other bar popups): a re-click while
# the menu is open closes it instead of stacking another wofi. (The argv
# carries the unique prompt; pkill -f excludes its own pid, so no self-match.)
#
# Glyphs are emitted by codepoint via GNU `/usr/bin/printf '\U…'` (the
# weather.sh pattern), so no literal PUA sits in the script for an editing
# tool to strip.

[ "$1" = menu ] || exit 0

# Toggle: close an already-open power menu instead of stacking another.
pkill -u "$USER" -f 'wofi.*-p Power' 2>/dev/null && exit 0

glyph() { /usr/bin/printf "\\U$1"; }

lock="$(glyph 000F033E)  Lock"
logout="$(glyph 000F0343)  Logout"
suspend="$(glyph 000F0904)  Suspend"
reboot="$(glyph 000F0450)  Reboot"
shutdown="$(glyph 000F0425)  Shutdown"

# -W/-H override the launcher-sized 600x400 from ~/.config/wofi/config so the
# 5-action list gets a compact window. Height, not -L: wofi's line accounting
# undercounts (L=6 showed only 4 rows), 270 fits all five (verified by shot).
sel=$(printf '%s\n%s\n%s\n%s\n%s\n' \
        "$lock" "$logout" "$suspend" "$reboot" "$shutdown" \
      | wofi --dmenu -i -p Power -W 320 -H 270) || exit 0

# confirm MESSAGE BUTTON-LABEL COMMAND — swaynag auto-reads the themed config,
# so the warning renders as the full-orange banner with a black-text message.
# The command is run **detached** (`setsid -f`): swaynag executes a button's
# command and then EXITS immediately, and a command still running at that instant
# is reaped with it. That's fine for instant actions (`swaymsg exit`), but it
# silently killed `systemctl reboot`/`poweroff` mid-flight — they need a logind
# D-Bus round-trip to land, so the button "fired" and the machine did nothing
# (a race the mate-polkit auth agent's added latency tipped over the edge, 2026-07;
# CanReboot said yes and the swaynag button fired, but the process died before the
# call completed). setsid runs it in a new session so swaynag's exit can't reap it.
confirm() {
    swaynag -t warning -m "$1" -B "$2" "setsid -f $3" -s Cancel
}

case $sel in
    "$lock")     exec swaylock -f ;;
    "$suspend")  exec systemctl suspend ;;
    "$logout")   confirm "End the Wayland session? Unsaved work in open apps will be lost." "Yes, log out" "swaymsg exit" ;;
    "$reboot")   confirm "Reboot the machine?" "Reboot" "systemctl reboot" ;;
    "$shutdown") confirm "Shut down the machine?" "Shut down" "systemctl poweroff" ;;
esac
