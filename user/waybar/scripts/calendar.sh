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

ACCENT=$'\033[38;2;124;58;237m'
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
    printf '%s%s %s%s\n\n' "$ACCENT" "$(date -d "$yr-$mon-01" +%B)" "$yr" "$RESET"
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

    printf '\n%sh/l month   j/k year   r today   q quit%s\n' "$DIM" "$RESET"
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
