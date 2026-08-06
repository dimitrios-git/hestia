#!/bin/sh
# Force SDL2's software (CPU) renderer — video-compare's default
# SDL_RENDERER_ACCELERATED|SDL_RENDERER_PRESENTVSYNC path hits an NVIDIA-550
# Wayland GL texture-streaming race that flickers a solid background colour at
# the seam between the left/right video regions on mouse motion. Live-verified
# on hephaestus: NOT fixed by the compositor-wide WLR_RENDERER=vulkan mitigation
# (system/sway-session/start-sway.j2) — that fixes wlroots' OWN implicit-sync
# compositing, but video-compare's SDL2 renderer runs its own separate GL
# context with its own streaming-texture upload timing, a different sync
# domain. SDL_RENDER_DRIVER=software sidesteps GL/EGL entirely (CPU blit via
# wl_shm) and was confirmed flicker-free live; the tradeoff is CPU-bound
# scaling/blit instead of GPU-accelerated. Deployed by the `video_compare`
# Ansible role (bootstrap/roles/video_compare) to ~/.local/bin/video-compare,
# shadowing the real binary installed alongside it as video-compare-bin.
exec env SDL_RENDER_DRIVER=software "$(dirname "$0")/video-compare-bin" "$@"
