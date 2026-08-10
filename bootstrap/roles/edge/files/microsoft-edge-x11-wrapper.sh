#!/bin/sh
# Force microsoft-edge through XWayland's Ozone/X11 backend instead of Chromium's
# native-Wayland one — --ozone-platform=x11 fixes the main hover/repaint flicker
# on this NVIDIA/wlroots setup (:hover state changes — links, transparent divs),
# live-confirmed 2026-08-10. It's the same shape of bug as Steam's native-Wayland
# client backend (see the `steam` role), a Chromium-family app's own Wayland
# integration being unstable on wlroots.
#
# A separate, occasional residual flicker remains on XWayland that this does NOT
# fix. Two mitigations were tried and both turned out to be FALSE POSITIVES on a
# full re-login retest: XWAYLAND_NO_GLAMOR=1 (start-sway.j2, reverted to a
# commented-out escape hatch) and --disable-gpu-compositing (tried in this
# wrapper, removed). Accepted as a known limitation, same category as Steam's own
# unfixed CEF webview flicker — see CLAUDE.md's Chromium-family XWayland gotcha.
#
# Deployed by the `edge` Ansible role to ~/.local/bin/microsoft-edge, ahead of the
# real binary in $PATH (.bashrc prepends ~/.local/bin). PATH below is restricted to
# the standard system dirs (excluding ~/.local/bin) so the exec resolves the REAL
# microsoft-edge binary, not this wrapper again.
exec env PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" microsoft-edge --ozone-platform=x11 "$@"
