#!/bin/sh
# Force Steam through XWayland — its native-Wayland client backend is unstable on
# wlroots compositors here (corrupted menus/cursor, and a full sway crash resizing
# a tiled window alongside it). See CLAUDE.md's `steam` role gotcha section for the
# full story. Deployed by the `steam` Ansible role (bootstrap/roles/steam) to
# ~/.local/bin/steam, which sits ahead of /usr/games in $PATH (.bashrc prepends
# ~/.local/bin), so a plain `steam` in a terminal picks this up instead.
exec env XDG_SESSION_TYPE=x11 /usr/games/steam "$@"
