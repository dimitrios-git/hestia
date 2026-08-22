#!/bin/sh
# Force Steam through XWayland — its native-Wayland client backend is unstable on
# wlroots compositors here (corrupted menus/cursor, and a full sway crash resizing
# a tiled window alongside it). See CLAUDE.md's `steam` role gotcha section for the
# full story. Deployed by the `steam` Ansible role (bootstrap/roles/steam) to
# ~/.local/bin/steam, which sits ahead of /usr/games in $PATH (.bashrc prepends
# ~/.local/bin), so a plain `steam` in a terminal picks this up instead. The
# desktop-launcher override (steam-x11.desktop.j2) points here too, rather than
# duplicating this logic, so both paths stay in sync.
#
# PRIME render-offload to NVIDIA, when present: on a multi-GPU host (an AMD/Intel
# iGPU as the sway render-primary + an NVIDIA dGPU, see start-sway.j2's GPU
# render-path selection), a GL/Vulkan app with no offload hint defaults to
# whichever GPU wlroots/Mesa considers primary — not what you want for real game
# performance. Live-tested 2026-08-22 on hephaestus: with these vars, Steam +
# games render on the NVIDIA RTX 4060 as expected (confirmed via nvidia-smi: real
# clocks/power draw, out of its idle P8 state) — no new corruption beyond the
# already-documented NVIDIA-scanout flicker (start-sway.j2), which V-Sync
# noticeably mitigates during actual gameplay (menus, often uncapped even with
# V-Sync on the 3D scene, still flicker).
#
# Gated on NVIDIA actually being live, same check as start-sway.j2 — forcing
# __GLX_VENDOR_LIBRARY_NAME at all on a host with no NVIDIA driver installed
# doesn't just no-op, it can hard-fail GLX init entirely (libglvnd doesn't
# gracefully fall back to another vendor once one is explicitly forced), which
# would break Steam's own UI on an AMD/Intel-only host.
if [ -e /dev/nvidia0 ] || grep -qE '^nvidia ' /proc/modules 2>/dev/null; then
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
fi

exec env XDG_SESSION_TYPE=x11 /usr/games/steam "$@"
