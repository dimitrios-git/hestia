# Design: programmatic video content for thecodingidiot

## 1. Motivation

`showcase/` chapters already turn a real evaluation trace into reader-facing
content, screenshots included, syndicated to charalampidis.pro/stoa unchanged.
The gap: everything in that pipeline is static (markdown + PNGs). Terminal
workflows, desktop tours, and animated content (the mesh wallpaper) all lose
their most legible dimension — motion — when flattened to a screenshot. This
doc scopes a **video** counterpart to the screenshot pipeline: script a
demo, narrate it with programmatically-generated speech, capture it, publish
it through the same channel showcase chapters already use.

Not in scope: editing/pacing taste, thumbnail curation, or anything that
needs a human's judgment about what's *interesting* to show. This is a
capture + narration + mux pipeline, not a video producer.

## 2. Key insight — this is `hestia-shot` plus two new pieces, not a rebuild

`user/bin/hestia-shot` (`docs/claude-env-parity-design.md` §7) already solves
the hard infrastructure problem: a throwaway **nested sway** on the
`WLR_BACKENDS=headless` + `WLR_RENDERER=pixman` backend, its own
`dbus-run-session`, the real theme staged in from the clone, a scene launched
and waited-for, captured, torn down cleanly. It already has a **`HESTIA_HOOK`**
extension point — a shell snippet `eval`'d after the scene maps and before
capture, built for exactly "drive this app into a state first." That hook is
structurally the same thing a scripted `wtype` action sequence would be for
video; the only reason it doesn't already produce video is that the capture
step is a single `grim` call instead of a bracketed recording.

`wf-recorder` (Debian apt, `0.5.0-2`, not installed) depends on
`wlr-screencopy-v1` — the **same protocol `grim` already proves works against
the headless output**, live, every time a showcase screenshot gets re-shot.
That's the load-bearing fact this whole design leans on. (Worth a five-minute
spike to confirm empirically before building on it — "the same protocol"
is strong evidence, not a guarantee.)

So the actual net-new work is two things `hestia-shot` doesn't have today:

1. A **record capture mode** (bracket `wf-recorder` around a *timeline* of
   actions, instead of one `grim` shot after one hook).
2. A **storyboard compiler** — narration text → speech → per-beat durations →
   a derived action timeline → a driven recording → a muxed final video.
   This is new, and it's where the real design work is (§5).

## 3. Architecture — three layers, cleanly separated

```
storyboard.yml  --[compile]-->  audio track + timed hook script
                                          |
                                          v
                          hestia-shot <scene> --record out.mp4
                          (the EXISTING rig, capture mode added)
                                          |
                                          v
                          mux (ffmpeg): video + audio, aligned
                          by construction (§5), not by luck
                                          |
                                          v
                          showcase/<chapter>/video/, referenced
                          from the chapter markdown like an image
```

- **Layer 1 — the rig (`hestia-shot`).** Owns compositor bring-up, theming,
  scene definitions, teardown. Gains a capture-mode axis (`shoot` | `record`)
  orthogonal to its existing scene axis (`desktop` | `vifm` | `url` | …) —
  you can record *any* existing scene, not just new record-specific ones.
- **Layer 2 — the storyboard compiler.** A new script (Python — this needs
  real data structures and `ffprobe`/duration math, not shell). Reads a
  declarative storyboard, renders narration, measures it, derives the action
  timeline, invokes layer 1, muxes the result. Doesn't know anything about
  sway/Wayland — it only ever talks to `hestia-shot`'s CLI + `HESTIA_HOOK`.
- **Layer 3 — publish.** Output lands where showcase assets already land
  (§7), referenced from a chapter the same way `showcase/img/*.png` already
  is.

## 4. The storyboard format

A scene needs more than the single-shot hook's "one eval blob" — it needs an
**ordered sequence of beats**, each pairing narration with the action(s) that
should happen while it plays:

```yaml
# showcase/video/vifm-git-helpers.storyboard.yml (illustrative shape)
scene: vifm
path: /tmp/demo-repo
voice: en_US-hestia   # placeholder name, see §5
beats:
  - say: >
      vifm's gc command jumps straight to the files this branch changed
      against main, no manual diffing.
    actions:
      - wtype: ":gc"
      - key: Return
  - say: >
      Pressing gr jumps back to the repository root from anywhere in that list.
    actions:
      - key: g
      - key: r
```

Each beat's `actions` list is a sequence of `wtype`/`key`/`sleep` steps run
in order; the beat's *total* on-screen hold time is derived from its
narration's rendered audio duration (§5), not hand-tuned per beat — a script
change (rewording narration) automatically re-times the action pacing too.
The compiler turns this into exactly the kind of shell snippet
`HESTIA_HOOK` already accepts — no new mechanism inside `hestia-shot` itself
beyond the record capture mode.

## 5. TTS + audio/video sync — the actual design problem

Trying to have `wf-recorder` and live TTS *playback* run in real-time
lockstep is fragile — it couples two independently-jittery real-time
systems (compositor frame timing, audio playback timing) for no reason.
Instead: **precompute, don't synchronize live.**

1. For each beat, render its `say` text to a WAV file via the TTS engine.
2. `ffprobe` each WAV for its exact duration.
3. Build the action timeline so each beat's on-screen hold time ≥ its
   narration's duration (+ a small buffer) — the recording is driven
   entirely by these precomputed numbers, so it and the narration are
   aligned **by construction**, not by luck.
4. Record the video (silent) via `hestia-shot <scene> --record` using that
   derived timeline as the hook.
5. Concatenate the per-beat WAVs into one track (their durations are exactly
   the numbers that drove the video timeline, so beat *N*'s audio starts
   exactly when beat *N*'s on-screen segment starts).
6. Mux with `ffmpeg -i video.mp4 -i audio.wav -c:v copy -c:a aac out.mp4`.

This sidesteps live sync entirely — video and audio share one source of
truth (the per-beat durations) instead of trying to stay in step with each
other at capture time.

**TTS engine — recommendation, not a decision.** Default to a **local,
offline engine** (e.g. Piper — ONNX neural voices, prebuilt Linux binaries,
no API key, no per-generation cost, deterministic output so re-running a
storyboard reproduces the same audio) via the existing `localbin_binaries`
pattern (pinned release, sha256-verified — same shape as `bluetuith`/`yazi`).
A cloud TTS API (higher quality, but needs a secret in `~/.bash_secrets` and
a network dependency) stays a documented opt-in escape hatch, not the
default — mirrors the repo's general shape (local/self-contained default,
heavier vendor option opt-in) rather than a hard technical requirement.
**Open question for you: is Piper-quality narration acceptable for
published tci content, or does this need a cloud voice from day one?**

## 6. GPU-heavy / animated content — a boundary to draw, not a merge

The mesh wallpaper (`themes/plain-mesh/`) is **already** a programmatic video
pipeline for tci — but a fundamentally different kind: a deterministic,
frame-stepped headless-chromium bake where motion frequencies are
"snapped to integer cycles" specifically so the loop is seamless. That
precision is *why* it's frame-stepped instead of real-time-captured — a
real-time `wf-recorder` pass over the same animating page would reintroduce
exactly the frame-drop/jitter risk the bake pipeline was built to avoid.

**Boundary:** already-deterministic animated content (the mesh, or anything
like it) keeps using its own bake pipeline. This new rig is for **content
that's inherently interactive/live** — a terminal workflow, a UI walkthrough,
a browser page being *navigated* rather than just sitting there animating —
where there's no deterministic alternative because a human-shaped sequence
of actions is the whole point. `hestia-shot`'s existing `url` scene (chromium
as a Wayland client in the nested sway, NVIDIA EGL passthrough for WebGL,
compositor itself still pixman) already covers the "record a live web page"
case for when that's genuinely what's needed.

## 7. Publish integration

Matches how showcase screenshots already work: `showcase/<chapter>.md`
already carries `![alt](img/foo.png)` inline. Video needs a places-to-land
convention — proposal: `showcase/video/<chapter>/<clip>.mp4`, referenced from
the chapter markdown with a plain link (or an HTML5 `<video>` tag if stoa's
syndication tolerates raw HTML in a chapter — **needs checking against how
stoa actually renders a showcase chapter**, since the whole point is
syndicating unchanged). Resolution/codec should be picked to match whatever
stoa's video embed actually expects, once that's confirmed — not guessed
now.

## 8. Repo placement (open question)

Two reasonable options, not resolved here:
- **`themes/video-capture/`** — sibling to `themes/plain-mesh/`, consistent
  with "content-generation pipelines for tci live under `themes/`."
- **A new top-level `content/video/`** — if this is meant to grow into a
  general content-production area beyond just this one pipeline.

Leaning toward the first (precedent > new top-level dir for one pipeline),
but this is exactly the kind of call worth pinning down before code exists
to move.

## 9. Phased plan

Staged so each phase is independently verifiable, same discipline as the
env-parity rig build:

1. **Spike — confirm `wf-recorder` works against the headless backend.** ✅
   **CONFIRMED (2026-08-18):** a throwaway `WLR_BACKENDS=headless` nested
   sway, `wf-recorder -f out.mp4` against its Wayland socket while a
   terminal printed an incrementing counter — the resulting h264 mp4
   (`ffprobe`: 960x540, 16 real frames) shows genuinely evolving content
   frame-to-frame (verified by extracting and eyeballing frames, not just
   checking the file's non-empty). No `--no-dmabuf` or other flag needed;
   it worked against the software `pixman` renderer out of the box.
2. **`hestia-shot` gains a record capture mode.** ✅ **DONE (2026-08-18):**
   capture mode inferred from `$OUT`'s extension (`.mp4`/`.mkv`/`.webm` →
   record); `wf-recorder` brackets the existing hook instead of running
   before a single `grim` shot. Verified end to end against the real `vifm`
   scene with a hand-written `HESTIA_HOOK` (three `normal! jjj`/`kkkkkk`
   cursor moves) — the recorded clip shows the cursor genuinely moving
   through the sequence, matched frame-for-frame against the expected
   position. Two real bugs surfaced and fixed along the way, both worth
   knowing about if this rig is extended further:
   - **The pre-existing `$WD` (Wayland display) resolution was silently
     wrong whenever a real desktop session already exists** — its
     `ls wayland-* | head -1` picked `wayland-1` (the REAL desktop) over
     the nested rig's own higher-numbered socket, because sway/wlroots
     doesn't renumber from 1 when wayland-1 is already taken by someone
     else. This is a **pre-existing bug in the shoot path too**, invisible
     until now because the `claude` agent (the rig's only user so far) has
     no real desktop session to collide with — dimitrios does. Caught
     LIVE: the first record-mode test captured the real desktop (this very
     editing session) instead of the isolated scene — deleted immediately,
     not just noted. Worse, wlroots' own `$WAYLAND_DISPLAY` in its process
     environment is *also* stale in this situation (reports the name it
     first tried, not the one it fell back to), so reading it from
     `/proc/$SWAYPID/environ` doesn't work either. Fixed with a
     before/after `comm -13` socket-list diff — the one signal that's
     actually reliable regardless of what else is running.
   - **`wf-recorder`'s default damage-tracking capture silently stops
     requesting frames** against this headless/pixman backend after the
     first frame or two — confirmed by a `grim` shot taken at the identical
     point in an identical hook correctly showing the updated scene, while
     `wf-recorder` kept re-encoding a frozen first frame. It also failed to
     terminate promptly on `SIGINT` in this state. `--no-damage` (steady
     frame requests instead of damage-driven ones) fixed both — confirmed
     with the same test showing genuine, continuous scene changes and a
     clean, fast shutdown. Recorded as a **required** flag in `hestia-shot`,
     not an optional tuning knob.
   - **A related utility landed alongside this phase: `user/bin/hestia-type`**
     (a `HESTIA_HOOK` companion, not part of the rig itself) — drives `wtype`
     with human-shaped per-character timing (jitter around a target WPM,
     extra beats after spaces/punctuation, a small tax on shifted characters)
     instead of a flat `-d N` delay, so a typed action in a recorded demo
     reads like a person typing it rather than a metronome. Surfaced a
     genuine nested-rig input-drop quirk along the way — confirmed absent on
     a real desktop, so it's rig-specific, not a `wtype` bug — but **two
     rounds of live evidence on its exact shape disagree**: the tool's first
     build needed every `-s` pause compensated (a mid-text pause dropped the
     "-" in "-u"); generating the actual published demo (2026-08-18) showed
     that default *creating* visible duplicate characters instead, with only
     the sequence's very first unit ever actually dropped. Rather than treat
     either round as settled, `hestia-type` now exposes both as
     `--drop-compensation {opener,every-pause,none}` — `opener` (matching
     round 2) is the default; `every-pause` (round 1's behaviour) stays
     available if a mid-sequence drop resurfaces. The storyboard compiler
     (next phase) is expected to render each beat's typed actions through
     this tool rather than hand-rolled `wtype` calls.
3. **The storyboard compiler, silent first.** YAML → derived action
   timeline → recorded clip, no audio yet. Verifies layer 2's timeline
   derivation without also debugging TTS at the same time.
4. **TTS integration.** Pick the engine (§5's open question), wire in
   per-beat rendering + `ffprobe` duration + the mux step. First real
   narrated clip end to end.
5. **Publish integration.** Land the `showcase/video/` convention (§7),
   confirm against stoa's actual rendering, ship one real chapter's clip.

## 10. Open questions

- **TTS engine** — Piper (local, default-recommended) vs. a cloud API
  (higher quality, needs a secret). §5.
- **Repo placement** — `themes/video-capture/` vs. a new `content/` top
  level. §8.
- **stoa's video rendering** — does raw HTML5 `<video>` in a showcase
  chapter survive syndication, and what resolution/codec does it actually
  want? Needs checking against the real stoa app, not assumed.
- ~~**`wf-recorder` on headless**~~ — RESOLVED (phase 1 spike, 2026-08-18):
  confirmed working against the pixman headless backend, no extra flags.
