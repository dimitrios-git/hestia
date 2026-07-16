# plain-mesh — the hestia default wallpaper

The default desktop background: the **ambient web lattice** from stoa's
thecodingidiot homepage (`CurriculumMap3D.tsx`, the `WebLattice`/`hexField`
backdrop), rendered as **seamless 120 s loop videos** (per resolution, per
`theme_variant`) plus a **static t=0 PNG** companion for each. The **static
frames are what the desktop actually shows** — painted by **wpaperd** via
`user/sway/wallpaper.sh` (wallpaper verdict, 2026-07; the engine was re-picked
from mpvpaper after its looping video leaked memory unboundedly — an unfixed
upstream mpv bug, and mpvpaper was then dropped from the install). The bake
still produces the loop videos, but they're no longer shipped or fetched — the
static frame is the product; the loops are kept only as a render artefact.

"plain" is the family name; flavours join alongside as `<flavour>-mesh-*`,
each on its own release tag, selected per host by the `wallpaper_flavour`
host_var (the role stamps it into the `default-flavour` marker wallpaper.sh
reads). Shipped flavours:

- **plain-mesh** — the quiet lattice alone (`plain-mesh-v1`)
- **flash-mesh** — accent flashes fire through the lattice: nodes ignite in
  `#d7005f` (fast attack, smooth decay) and the pulse bleeds one hop down the
  web edges. Deterministic + loop-periodic (seeded event schedule, wrapped-time
  envelopes; events only pick nodes that project comfortably inside the
  viewport — computed per aspect, so portrait gets its own set). Parameters are
  dimitrios's approved 2026-07 tuning, baked as the defaults in
  `mesh-scene.js` (`flashCount 33, flashDur 3.3, seed 33`; `flash-mesh-v1`).

The scene itself lives in **`mesh-scene.js`** — shared verbatim between the
bake page (`mesh.html`) and the live tuning page (`preview/`), so what you
tune is what bakes. Build the tuning page with `preview/build-preview.sh
[outdir]` (single self-contained HTML, three.js inlined — open via file://,
tune, "show / copy parameters", paste the JSON to bake a new flavour).

## Why the loop is seamless

The lattice motion is pure sinusoids of `t` (no randomness): undulation
`sin(t·ω₁ + x·0.22 + y·0.18)`, group rotation `sin(t·ω₂)`, x-sway
`sin(t·ω₃ + π/2)`. `mesh.html` snaps ω₁..ω₃ to the nearest **integer number of
cycles per LOOP_T** (120 s), so frame N−1 steps into frame 0 like any other
frame — verified: the wrap-around frame delta equals a normal adjacent-frame
delta. Rendering is **frame-stepped** (`window.renderFrame(t)` with an external
deterministic clock), never wall-clock captured, so renders are repeatable
bit-for-bit and any resolution is just a viewport size.

## Rebuilding the assets

One-time setup (needs node + chromium; both on the reference host):

    cd themes/plain-mesh && npm install

Then render a flavour's full matrix (resolutions × dark/light) and encode:

    ./render-matrix.sh /path/to/outdir [plain|flash]

Per-resolution/variant knobs live at the top of `render-matrix.sh`; colours
are the tci ambient values on the hestia grounds (dark: `#cfc8ba` on
`#1a1a1a`; light: `#3a352c` on `#f5f5f5`). Encoding is x264 **crf 14**
preset slow (quality over size — dimitrios's call, 2026-07), yuv420p for
libmpv/hardware-decoder compatibility.

**GPU note (claude / headless):** chromium must be forced onto the NVIDIA EGL
vendor stack — `render.js` sets `__EGL_VENDOR_LIBRARY_FILENAMES=…/10_nvidia.json`
and passes `--use-gl=angle --use-angle=gl-egl`. Without it chromium probes the
DRI render nodes (permission-denied for the agent user → SwiftShader fallback,
~50× slower). ~0.14 s/frame at 4K on the RTX 4060.

## Publishing

The rendered set ships as **`raw:`-style assets on a hestia GitHub release**
(`plain-mesh-v1`), downloaded + sha256-verified per host by the
`wallpapers` role (both variants × the host's `wallpaper_resolutions`) into
`~/.local/share/backgrounds/hestia/`. New render = new release tag + checksum
update in `bootstrap/roles/wallpapers/defaults/main.yml`.
