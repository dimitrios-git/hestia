#!/usr/bin/env bash
# Keyboard-driven calendar for the waybar clock's click handler AND the
# $mod+t keybind in user/sway/config (both toggle the same floatterm-calendar
# window) — replaces waybar's own tooltip-format calendar, which only opens
# on mouse hover and only navigates by mouse-scroll, with no keyboard path at
# all. h/l: previous/next month. j/k: previous/next year. r: back to the
# current month. q/Escape: quit.
#
# Renders the month grid itself with `date` arithmetic instead of shelling
# out to `cal` — `cal` isn't in hestia's package set (it'd be a new apt
# dependency, bsdmainutils, just for this), and GNU date already does all the
# calendar math this needs.

ACCENT_BG=$'\033[48;2;124;58;237m'
WHITE_FG=$'\033[38;2;255;255;255m'
REVERSE=$'\033[7m'
DIM=$'\033[2m'
RESET=$'\033[0m'

mon=$(date +%-m)
yr=$(date +%Y)

draw() {
    local first_dow days_in_month today_y today_m today_d col day

    first_dow=$(date -d "$yr-$mon-01" +%w)                             # 0=Sun..6=Sat
    days_in_month=$(date -d "$yr-$mon-01 +1 month -1 day" +%-d)
    today_y=$(date +%Y); today_m=$(date +%-m); today_d=$(date +%-d)

    clear
    # Full-width purple band + white text -- the same header-bar look as
    # vifm's path bar, not just coloured text (21 cols matches the grid's
    # own row width below, "%2d " x 7).
    header=$(printf '%s %s' "$(date -d "$yr-$mon-01" +%B)" "$yr")
    printf '%s%s%-21s%s\n\n' "$ACCENT_BG" "$WHITE_FG" "$header" "$RESET"
    printf 'Su Mo Tu We Th Fr Sa\n'

    col=0
    while [ "$col" -lt "$first_dow" ]; do printf '   '; col=$((col + 1)); done
    day=1
    while [ "$day" -le "$days_in_month" ]; do
        if [ "$yr" = "$today_y" ] && [ "$mon" = "$today_m" ] && [ "$day" = "$today_d" ]; then
            printf '%s%2d%s ' "$REVERSE" "$day" "$RESET"
        else
            printf '%2d ' "$day"
        fi
        col=$((col + 1))
        if [ "$col" -eq 7 ]; then printf '\n'; col=0; fi
        day=$((day + 1))
    done
    [ "$col" -ne 0 ] && printf '\n'

    # Two short lines instead of one wide one -- narrows the window to the
    # grid's own width instead of the hint's, which was the widest line and
    # forced a wider (mostly empty) floatterm than the content needed.
    printf '\n%sh/l month   j/k year%s\n' "$DIM" "$RESET"
    printf '%sr today     q quit%s\n' "$DIM" "$RESET"
}

draw
while IFS= read -rsn1 key; do
    case "$key" in
        h) mon=$((mon - 1)); [ "$mon" -lt 1 ]  && { mon=12; yr=$((yr - 1)); } ;;
        l) mon=$((mon + 1)); [ "$mon" -gt 12 ] && { mon=1;  yr=$((yr + 1)); } ;;
        j) yr=$((yr - 1)) ;;
        k) yr=$((yr + 1)) ;;
        r) mon=$(date +%-m); yr=$(date +%Y) ;;
        q) break ;;
        $'\e') break ;;
        *) continue ;;
    esac
    draw
done
