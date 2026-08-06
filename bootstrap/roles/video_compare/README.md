# video_compare

Builds [pixop/video-compare](https://github.com/pixop/video-compare) from
source and installs it to `~/.local/bin/video-compare` (no root). Opt-in via
`enable_video_compare` (default `false`).

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
