#!/bin/sh
# Force chromium through XWayland's Ozone/X11 backend instead of Chromium's
# native-Wayland one. Root-caused 2026-08-10: the native-Wayland Ozone backend
# has a hover/repaint flicker bug on this NVIDIA/wlroots setup (flashes on
# :hover state changes — links, transparent divs) that survives --disable-gpu /
# --disable-gpu-compositing, ruling out GPU rendering as the cause. It's the
# same shape of bug as Steam's native-Wayland client backend (see the `steam`
# role) — a Chromium-family app's own Wayland integration being unstable on
# wlroots, fixed by sidestepping it via XWayland rather than fixing the
# integration itself. See CLAUDE.md's Chromium-family XWayland gotcha.
#
# Deployed by the `chromium_x11` Ansible role to ~/.local/bin/chromium, ahead of
# the real binary in $PATH (.bashrc prepends ~/.local/bin). PATH below is
# restricted to the standard system dirs (excluding ~/.local/bin) so the exec
# resolves the REAL chromium binary, not this wrapper again.
exec env PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" chromium --ozone-platform=x11 "$@"
