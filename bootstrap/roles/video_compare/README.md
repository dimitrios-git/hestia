# video_compare

Builds [pixop/video-compare](https://github.com/pixop/video-compare) from
source and installs it to `~/.local/bin` (no root). Opt-in via
`enable_video_compare` (default `false`).

## NVIDIA/Wayland flicker → forced software rendering

The real built binary lands at `~/.local/bin/video-compare-bin`, shadowed by
a wrapper at `~/.local/bin/video-compare`
(`files/video-compare-wrapper.sh`) that forces `SDL_RENDER_DRIVER=software`.

video-compare's default renderer (`SDL_RENDERER_ACCELERATED |
SDL_RENDERER_PRESENTVSYNC`) hits an NVIDIA-550 Wayland GL texture-streaming
race, live-confirmed on hephaestus (2026-08): moving the mouse flickers a
flash of the background colour at the seam between the left/right video
panes, in every display mode (Split/HStack/VStack — the flicker axis follows
the stacking axis). Ruled out before landing on this fix:
- `-W`/`--window-fit-display` (removes an oversized-window downscale) — no
  change.
- The compositor-wide `WLR_RENDERER=vulkan` mitigation
  (`system/sway-session/start-sway.j2`) — no change. That fixes wlroots' own
  implicit-sync *compositing*; video-compare's SDL2 renderer runs its own
  separate GL context with its own streaming-texture upload timing, a
  different sync domain the compositor renderer choice doesn't reach.
- `SDL_RENDER_DRIVER=software` — confirmed flicker-free. It sidesteps GL/EGL
  entirely (CPU blit via `wl_shm`), at the cost of CPU-bound scaling/blit
  instead of GPU acceleration — an acceptable trade for a comparison tool.

The role deploys this wrapper unconditionally on every run (not gated by the
version marker), so a pre-existing install from before the wrapper existed
(binary installed straight as `video-compare`) self-heals into the new
`video-compare-bin` + wrapper layout without needing a version bump.

## Why build-from-source

- No Debian apt package exists.
- Upstream's GitHub releases only publish Windows `.zip` builds — no Linux
  binary to fetch and sha256-pin the way `localbin` does for other tools.
- The upstream `make install` target writes to `/usr/local/bin` via
  `install -s` (root). This role builds in a temp dir and copies the result
  into `~/.local/bin` instead, so no root is needed for the install step
  itself — only for the build-time apt dependencies.

## Dependencies

The `video_compare` apt group (gated on the same toggle, via
`package_group_features`) installs the FFmpeg + SDL2 dev headers the build
needs: `libavformat-dev libavcodec-dev libavfilter-dev libavutil-dev
libswscale-dev libswresample-dev libsdl2-dev libsdl2-ttf-dev`.
`build-essential` and `git` are already core packages (`editors`/`vcs_gpg`
groups), so they aren't repeated here.

## Pinning

Upstream tags by date (e.g. `20260708`), not semver — `video_compare_version`
in `defaults/main.yml` pins the build. Bump it to update; the role rebuilds
because the idempotency marker is per-version
(`~/.local/state/hestia/video-compare/<version>`).

## Usage

```
video-compare left.mp4 right.mp4
```

See upstream's README for the full flag set (frame-diff, side-by-side vs.
split, subtitles, etc).
