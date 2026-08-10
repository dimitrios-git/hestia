#!/bin/sh
# Force microsoft-edge through XWayland's Ozone/X11 backend instead of Chromium's
# native-Wayland one — --ozone-platform=x11 fixes the hover/repaint flicker on
# this NVIDIA/wlroots setup (:hover state changes — links, transparent divs); it's
# the same shape of bug as Steam's native-Wayland client backend (see the `steam`
# role), a Chromium-family app's own Wayland integration being unstable on
# wlroots. --disable-gpu-compositing fixes a SEPARATE flicker that only showed up
# once forced onto XWayland (live-confirmed 2026-08-10) — this is narrower than a
# full --disable-gpu: it forces Chromium's own UI compositing to software while
# leaving WebGL/canvas GPU rendering untouched (verified with a WebGL-heavy site —
# no perf hit). Root cause for BOTH flickers ruled out as plain GPU rendering
# first (a bare --disable-gpu didn't help either) — see CLAUDE.md's Chromium-
# family XWayland gotcha for the full story.
#
# Deployed by the `edge` Ansible role to ~/.local/bin/microsoft-edge, ahead of the
# real binary in $PATH (.bashrc prepends ~/.local/bin). PATH below is restricted to
# the standard system dirs (excluding ~/.local/bin) so the exec resolves the REAL
# microsoft-edge binary, not this wrapper again.
exec env PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" microsoft-edge --ozone-platform=x11 --disable-gpu-compositing "$@"
