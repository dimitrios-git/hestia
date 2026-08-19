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
3. **The storyboard compiler, silent first.** ✅ **DONE (2026-08-18), scope
   narrowed — see §11.** `user/bin/hestia-video`: YAML (labelled beats of
   `text`/`key`/`pause` actions) → ONE flattened `hestia-type` call wired as
   `HESTIA_HOOK` → `hestia-shot --record`. No duration-derivation step — §11
   explains why that's not a gap, just a consequence of skipping audio.
   Piloted end-to-end against a real thecodingidiot chapter (stoa's
   `tools/video-capture/scenes/f04-your-first-program.yml`): opens vim on a
   blank file, types `hello.c` exactly matching the chapter's own code
   block (byte-for-byte, frame-checked), saves, compiles, runs, shows
   `Hello, world.` — 21.7s clip, verified by extracting and eyeballing
   frames, not just a non-empty file.
4. **TTS integration.** **PAUSED, not scoped for now — owner decision, see
   §11.** May come back later; don't build proactively.
5. **Publish integration.** **NOT STARTED.** Land a `showcase/video/`-style
   convention once there's an actual player/embed story for a silent
   capture-pipeline clip (thecodingidiot's `<Explainer>` today is
   Manim-specific) — deliberately deferred past the pilot, not blocked on
   anything technical.

## 11. Scope pivot (2026-08-18) — sound punted, storyboard compiler simplified

Owner call: don't build phases 4-5 as originally scoped. thecodingidiot has
no audio anywhere yet (the Manim explainer pipeline is silent too, the
curriculum's games have none either) and audio/video muxing is cheap to add
later — so narration stays punted until owner-initiated, not built ahead of
need. **Don't propose TTS/audio work proactively.**

This isn't just "skip a phase" — it changes what phase 3 needed to be.
§5's whole design problem (precompute TTS durations so recording and
narration sync "by construction," instead of live A/V lockstep) evaporates
without audio: a silent compiler has nothing to synchronize against. What's
left is much smaller than §4's original shape implied — `hestia-video` is
that smaller thing, not a stub of the original plan.

**The actual target use case**, named explicitly by the owner: the
curriculum explains concepts and gives code blocks, but a code block gets
copy-pasted — it doesn't teach the "blank file → working program" skill
(scaffolding, writing incrementally, compiling, running) that was the
owner's own hardest part of learning to code. A silent recording of vim
being driven like a real person typing teaches that; static text
structurally can't. Named competitive framing: most of the owner's
coding-school peers learned from YouTube; a pure-reading-experience
curriculum is at a real disadvantage against that regardless of writing
quality.

**A real gotcha found piloting this, and how it actually got fixed** (owner
feedback after seeing the first pilot render): the deployed hestia vimrc's
`filetype plugin indent on` auto-indents on Enter/`{`/`}` for many
filetypes — literal leading whitespace typed on top of that produces WRONG,
accumulating indentation (confirmed live: 4-space C source came out 6, then
10 spaces per subsequent line). The first fix (`:setlocal noai nocin nosi
indentexpr=` typed as the first on-camera action) worked, but the owner
correctly rejected it as the wrong LAYER to fix it at: it's a config
workaround visible in the recording, and — the bigger issue — the whole
recorded session was running under whichever real user's `$HOME` happened
to invoke `hestia-video`, so the clip's shell prompt leaked that user's
real identity (`claude`) too, plus a random `mkdtemp` path. All three are
one root cause: nothing about this scene was isolated from the invoking
user's real environment, the same problem `hestia-shot` already solved for
waybar/alacritty (stages resolved theme copies into `$WORK` instead of
trusting the deployed configs) but never extended to bash+vim.

**Real fix, landed same round**: `user/video-rig/` — a versioned, nobody's-
personal-identity `bashrc` + `vimrc-{dark,light}` pair. `hestia-video`
stages these as a throwaway `$HOME` (`stage_rig_home()`) for just the
recorded shell's child process (`env HOME=<staged> bash`, wrapping the
`app` scene's command — no `hestia-shot` changes needed, its existing
`app "<command>"` flexibility already covers this). The rig vimrc skips
`filetype indent` entirely (loads `filetype plugin on` only) rather than
disabling autoindent after the fact — the conflict never exists, so no
on-camera command is needed at all. `colorscheme hestia` resolves via a
FRESH COPY of `user/vim/colors/hestia.vim` staged into `$HOME/.vim/colors/`
each run (not a symlink to anyone's real `~/.vim`). Owner-specified
constraints for the profile: prompt is bare `$ ` (no username/host/path at
all — the strictest of three options offered), vimrc keeps hestia's real
colorscheme/line-numbers/cursorline for visual consistency with existing
showcase content but none of the personal plugin/keymap layer. Re-piloted
against the same f04 chapter scene end-to-end (frame-checked again): clip
now shows only `$ vim hello.c` / `$ gcc hello.c -o hello` / `$ ./hello` /
`Hello, world.` — no identity, no path, no config command, anywhere.

## 12. Typing-engine round (2026-08-18, sixth) — pacing, typos, scaffold-first

Owner feedback on the isolated-profile pilot: the typing itself read as too
fast/uniform even for an experienced typist, who both makes occasional
mistakes and pauses between words/sentences. Typo simulation had been
deliberately avoided earlier specifically because of live-narration timing
risk — moot now that audio is out of scope (§11). Owner also named a
real coding-habit gap: real coders scaffold structure (signature + both
braces) before filling in a function body — "I don't believe there's
anybody that writes the `}` last."

**Split across the same two layers as everything else in this pipeline**:
- `hestia-type` (character-level): widened `WORD_PAUSE_MS`
  ((30,160)→(60,240)) and `PUNCT_PAUSE_MS` ((150,420)→(200,550)); added
  `--typo-rate` (default 0.03) — a per-letter chance of a plausible
  QWERTY-adjacent-key slip, typed, held briefly, then `BackSpace`'d and
  retyped correctly. Only fires on letters, by design (punctuation/digit
  typos risk confusing editor/matching state for no realism gain).
- `hestia-video` (line-level): `hestia-type` never sees more than one line
  at a time (multi-line `text:` is already split into separate `key:Return`
  actions by `flatten_actions` before `hestia-type` runs), so a "thinking
  about the next line" pause is this tool's job, not `hestia-type`'s — new
  `line_pause_ms` (default `(250, 800)`), inserted after every Return
  synthesized from a newline INSIDE a `text:` value (not after an explicit
  `key: Return` the script wrote itself).
- **Scaffold-first is not an engine feature at all** — it's purely how a
  scene's actions are ordered: type the skeleton (`{` and `}` together),
  `Escape`, `O` to open a line above the `}` and insert the body there.
  Demonstrated in the pilot script (stoa `tools/video-capture/scenes/
  f04-your-first-program.yml`), documented as a convention in
  `tools/video-capture/README.md`, no new mechanism needed.

**A real bug surfaced building the scaffold-first demo, caught by actually
compiling the recorded file instead of trusting frame screenshots**: the
first pilot render of the scaffolded version LOOKED right frame-by-frame
(braces appeared, a new line opened, body typed in) but `gcc` on the
resulting file failed — `key: O` had silently produced a lowercase `o`, so
the body landed AFTER the closing brace, at file scope. Isolated live test
(`hestia-shot app bash` shoot mode, typing `key:O` at a bare prompt):
confirmed `wtype -k O` types literal `o`, not `O` — `-k`'s keysym-name
lookup is case-INSENSITIVE for a bare letter, no error, no automatic
Shift. Every capital letter used anywhere in this pipeline before now went
through the CHARACTER path (`-d MS <char>`, from a `text:` action or the
per-char loop), never `-k <single-uppercase-letter>` — this is the first
scene to use an uppercase single-letter `key:` action, which is why the
bug was invisible until now. Fix, in `hestia-type`'s `build_argv`: a
`key:` action whose value is exactly one character now routes through the
same character-emission path as `text:`, instead of `-k NAME` — multi-
character named keysyms (`Return`, `Escape`, `BackSpace`, ...) are
unaffected, they have no character form to route through anyway.

**Verification this round went one level deeper than frame-eyeballing**:
rendered with `--keep-workdir`, then `cat`'d and `gcc -Wall -Wextra`'d the
actual resulting `hello.c` directly — byte-identical to the chapter's code
block, compiles with zero warnings, `./hello` prints `Hello, world.`. A
frame also caught a live typo-in-progress (`prij` mid-typing `printf`,
about to self-correct) — the mechanism is visibly real, not just
unit-tested in isolation.

## 13. Recording quality + prompt branding (2026-08-18, seventh)

Owner watched the pilot clip and flagged perceived colour drift on
syntax-highlighted text (the orange `int`/`void` in particular). Turned
out to be encoder defaults, not a real theme/colour-space problem:
`hestia-shot`'s record mode ran `wf-recorder` with zero tuning, defaulting
to `yuv420p` (quarter chroma resolution — the actual cause of both the
perceived colour bleed AND the softness the owner also noticed) at a very
low ~139kbps for a 1280x720 clip.

Considered and ruled out: rendering at a higher resolution and downscaling
(the supersampling trick `tools/manim` gets for free, since it's a
deterministic vector re-render). Doesn't transfer here — this is a
real-time capture on the already-fragile headless/pixman rig, so a higher
resolution risks the SAME frame-timing/input-drop fragility
`hestia-type`'s drop-compensation already exists to work around. Different
lever needed.

**Fix**: `wf-recorder --no-damage -x yuv444p -p crf=18 -p preset=slow`
— full chroma resolution (no subsampling) at a real quality target
instead of the default. Verified with a same-seed before/after frame
crop, upscaled 6x: visibly crisper text edges, no more colour bleed into
the background. Cost: ~139kbps → ~164kbps (~18% bigger) — negligible for
this content, and the slower preset still completed the render in real
time with no dropped-frame symptoms on this rig. Landed as the new
DEFAULT for record mode (same "required, not a tuning knob" status as
`--no-damage` itself) — shoot mode's `grim` call is untouched.

**Also**: the video-rig `.bashrc` prompt gained hestia's own exit-status-
coloured `$` (green success / red failure) — same `PROMPT_COMMAND`+
`prompt_exit_status_color()` mechanism as the REAL personal `.bashrc`
(`user/bash/.bashrc`), with every other segment that prompt has (user,
path, git branch/status) deliberately left out — the colour is hestia's
branding, not operator identity, so it doesn't conflict with the earlier
"bare `$`, no identity" decision (§11). Verified live both ways: a
successful command keeps `$` green, `false` turns the next one red.

## 14. Editor switch: Vim → Neovim (2026-08-18, eighth)

Owner's own read on the recording-quality thread (§13): the remaining
colour difference between a video's syntax highlighting and the site's own
code blocks isn't really fixable at the encoder level — Vim's legacy
regex-based `:syntax` and the site's Shiki (TextMate-grammar) highlighter
are just different classification engines, and the hestia theme project
already did the real work of keeping their PALETTES coherent (`docs/
theme-roadmap.md`'s vim/bat/Shiki/VS Code layer). What's left is which
GROUPS get assigned to which tokens, not the colours themselves. Owner's
proposal: record in Neovim instead — its built-in `vim.treesitter`
(structural, AST-based parsing) classifies tokens with more context than
Vim's pattern matching, closer in spirit to how Shiki resolves tokens too,
even though the two don't share an underlying engine.

Verified cheaply before committing to it: `nvim` (0.10.4) is already
installed, the hestia colourscheme is already documented as identical
across Vim/Neovim, and the invoking user's own personal Neovim setup
already has `nvim-treesitter` configured with `c` in its parser list — the
compiled `parser/c.so` was already sitting on disk. Confirmed live
(isolated `hestia-shot app` shoot-mode test, no full record needed) that
`vim.treesitter.start()` — Neovim's CORE treesitter API, not the community
`nvim-treesitter` plugin — highlights correctly with just a compiled
parser on the runtimepath; Neovim ships highlight query files for common
languages (including C) built in, no extra query files needed.

**Isolation extended, not reinvented**: `user/video-rig/nvimrc-{dark,
light}.lua` — same "no personal plugins/keymaps, hestia colourscheme,
bare essentials" posture as `vimrc-{dark,light}`. `hestia-video`'s
`stage_rig_home()` now also stages `$HOME/.config/nvim/init.lua` +
`colors/hestia.vim` + a best-effort copy of any compiled treesitter
parsers found under the invoking user's own `~/.local/share/nvim/...`
(binaries this repo doesn't vendor — falls back to legacy `:syntax`
cleanly, never a hard failure, if none are found on a given machine).

**Two real indent bugs, not one, both confirmed live before landing**:
1. Neovim, UNLIKE Vim, defaults `autoindent=true` — the same
   accumulating-indent symptom as the Vim rig's original bug (§11), but a
   DIFFERENT setting. Fixed with an explicit `vim.o.autoindent = false`.
2. That alone wasn't enough — Neovim's OWN bundled `ftplugin/c.vim` sets
   `cindent=true` unconditionally as part of `filetype plugin on`, NOT
   gated behind the separate `filetype ... indent on` layer the way Vim's
   `indent/c.vim` is. The "skip filetype indent" fix that worked for the
   Vim rig does NOT carry over — `cindent`/`smartindent` have to be
   re-asserted `false` INSIDE a `FileType` autocmd callback (they get set
   reactively when the ftplugin loads, which runs before a plain top-
   level option-setting line would take effect).

Both caught by the same discipline established in §12 — rendering with
`--keep-workdir` and diffing the actual output file against the chapter's
code block, not trusting frame screenshots. First attempt compiled and
ran fine (C doesn't care about whitespace) but came out at 8-then-12-space
indentation instead of a flat 4 — a `diff` catches this instantly, a
frame screenshot at this display size easily wouldn't.

The pilot scene now types `nvim hello.c` — honestly, not aliased behind
`vim` — matching the doc paragraph added to `f01-the-terminal/12-vim.mdx`
(en-GB + en-US, stoa repo) explaining Neovim as a "going further" aside
alongside `vimtutor`, so a viewer who notices `nvim` in a recording isn't
left wondering why it's a name the curriculum never mentioned.

## 15. Live-typed, self-deleting explanatory comments (2026-08-19, ninth)

New experiment, owner-proposed: turn the pilot into a teaching device
without narration — write a real C comment explaining a line or concept
live, hold it on screen long enough to read, then erase it live, leaving
the file exactly as it would be without the aside. A code block alone
shows *what* to type; this shows the "why" a reader would otherwise only
get from someone talking over the recording — which this pipeline
deliberately doesn't do (§11).

**Planned before building, not built first** — owner interrupted an
in-progress implementation start ("Don't implement yet, let's plan this")
specifically to lock the design first. Worth remembering as a standing
preference: for a genuinely new mechanism (not a bugfix to something
already agreed), design + confirm before code, even mid-turn.

**Two shapes, one `comment:` action** (`hestia-video`), chosen by the
presence of `lines_up`:
- **inline** — a plain string, or a mapping with no `lines_up`. Appended
  at the CURRENT cursor position (typically right after a line just
  typed) as `" /* text */"`, held, then removed with exactly as many
  `BackSpace` presses as characters were typed. Insertion count equals
  deletion count by construction — no hand-counted `BackSpace` to get
  wrong in a scene's YAML.
- **block** — a mapping WITH `lines_up`: how many lines above the CURRENT
  cursor the top of the code being explained sits. Moves up, opens a line
  (`O`), types the (possibly multi-line) comment, holds, moves to the
  comment's own first line, deletes exactly its own line count with `dd`,
  moves back down to resume where the scene left off. Each of the
  author's own newline-separated segments becomes its own complete
  `/* ... */` line — no word-wrapping/reflow, matching how `text:` never
  reflows either.

**C-only, `/* */` exclusively, verified against the actual codebase, not
assumed**: grepped every code block across `f04-writing-c` — 100%
`/* */`, zero `//`, including a comment standing alone above a data block
(never a K&R-style `/* \n * ... \n */` continuation form either). Owner's
own reason, better than "matches existing style" alone: `/* */` is the
original ISO C89/C90 comment syntax; `//` is a C++ import C didn't
standardise until C99 — this curriculum teaches traditional, portable C.

**Pacing — the one genuinely new `hestia-type` primitive**: a `wpm:N`
action, changing the typing rate from that point forward in the SAME
invocation (previously `--wpm` was fixed for a whole scene). Owner's
insight: a long comment is being read WHILE it's typed, not just during
the hold after, so it doesn't need code's more deliberate pace — typing
ramps with length (`comment_wpm = min(340, scene_wpm + 0.5 × chars)`),
hold time is generous and capped rather than linear
(`min(4000, 1200 + 150 × words)`), and typo rate is untouched — the
existing fixed per-character probability already produces proportionally
more typos in longer text for free. All numbers are starting points, same
as every other pacing constant here — tune after watching a render, not
treated as final on paper.

**Deletion variety (visual-select, normal-mode `h`/`0`+`d` for inline;
visual-line for block) explicitly deferred** — owner's own framing:
implement one reliable mechanic per style now, architect so a `method:`
field can pick or randomise among alternatives later, don't build the
variety this round.

**`relativenumber` added to all four rig configs** (vim + nvim, dark +
light) — not just cosmetic: it's how a scene author computes `lines_up`
while writing the YAML (read the number off a real editor, same as owner
does day to day), and it's now visibly authentic in the recording too.

**Two real bugs found only by rendering and checking the actual output
file, not the dry-run argv or frame screenshots**:
1. Motion/command keystrokes (`3k`, `4dd`) were nearly routed through the
   same `text:` path as prose — caught during design, before code: that
   path's typo injection assumes INSERT-mode editing (wrong char → notice
   → BackSpace → retype); firing it mid-command would send an unintended
   vim command (a mistyped digit or motion letter changes what gets
   deleted or where the cursor lands) instead of a harmless correctable
   typo. Fixed by giving motion/command sequences their own path
   (`emit_command`) — individual `key:` presses, which are never typo'd.
2. The first real render of the block form corrupted the file — it
   LOOKED right on paper (navigation math checked out) but the deletion
   commands (`1k2dd2j`) showed up as literal garbage characters in
   `hello.c` instead of deleting anything. Root cause: no `key: Escape`
   after typing the block comment's content, so the "delete it" commands
   were STILL sent in insert mode and got typed as text instead of
   interpreted as motions. Fixed with an explicit `Escape` between typing
   the block and navigating to delete it — inline doesn't need this (its
   `BackSpace` cleanup runs while still in insert mode, by design).

Verified end-to-end on the real pilot scene after both fixes: rendered
with `--keep-workdir`, `hello.c` diffed byte-identical against the
chapter's own code block, compiled clean with `gcc -Wall -Wextra`, ran
correctly. Frame-checked too: the syntax highlighter only colours a
comment once it's syntactically closed (the `*/` typed) — an in-progress
`/* pulls in...` reads as plain text until closed, then retroactively
recolours the instant `*/` lands. Not a bug, just how incremental
highlighting works — and it reads as fairly natural on screen.

## 16. Comment immediate-closing + auto-pairs (2026-08-19, tenth)

Owner watched the live-comment feature (§15) render and flagged a real
problem: typing a comment straight through left-to-right (`/* ` then the
whole explanation then finally ` */`) leaves it syntactically UNCLOSED for
the entire time the explanation is being typed — Neovim's treesitter
highlighting genuinely misbehaves during that window ("the parser goes
mad with the coloring"), not just "reads as plain text until closed" as
originally assumed watching the first render. Owner's fix, generalised
correctly beyond just comments: establish a PATTERN of typing the closing
delimiter immediately after the opening one, then filling content in
between — the same principle real auto-pair-equipped editors already
apply to `()[]{}""`, so do the same there too.

**Comments**: `hestia-video`'s `emit_comment_line` (replacing the old
`wrap_c_comment`) now types `/*  */` (note: two spaces between the `*`s)
as one unit, moves the cursor back 3 with `key: Left`, types the actual
content between the two spaces, then moves forward 3 with `key: Right` to
return to the true end — same visible final string as before
(`/* content */`), same exact-count `BackSpace`/`dd` cleanup as before
(insertion/deletion counts are unaffected by internal typing order), just
never syntactically unclosed at any point while typing. Verified live:
the whole comment — including the still-being-typed middle — stays
correctly coloured throughout, not just once `*/` lands.

**Brackets/parens/quotes**: checked the owner's own personal profile
first rather than guessing — it uses `coc.nvim`'s `coc-pairs` extension
(`user/vim/.vimrc:177`). Deliberately NOT installed here: `coc.nvim` is a
full LSP/completion framework (Node.js-backed, manages a dozen
extensions, language servers) — far too heavy for a rig that's
deliberately plugin-free. Instead, `user/video-rig/{vimrc,nvimrc}-{dark,
light}` gained ~15-line hand-rolled equivalents (Vimscript `<expr>`
`inoremap`s / Lua `vim.keymap.set` with `expr=true`) replicating just the
BEHAVIOUR: an opener inserts its closer immediately with the cursor
between them; a closer, when it's already the very next character, moves
over it instead of duplicating. Deliberately NOT "smart" — no backspace-
deletes-an-empty-pair-together behaviour — `BackSpace` always removes
exactly one character, which `comment:`'s exact-count cleanup depends on.

`/* */` is explicitly NOT handled by the general bracket-pair keymaps,
and that's deliberate, not an oversight: `a / *ptr` (division then a
pointer dereference) also contains the two-character sequence `/` `*` — a
naive editor-level auto-pair rule on that trigger risks inserting a
phantom `*/` into real C code that isn't a comment at all. `hestia-video`
handles `/* */` itself instead (`emit_comment_line`), where the tool
KNOWS it's typing a comment rather than guessing from two characters in a
stream — a narrower, unambiguous fix at the layer that actually has the
context to make it safely.

**Compatibility with every existing scene, verified not assumed**: since
every scene so far already types BOTH characters of any pair explicitly
(nothing relied on auto-completion), the "skip over the closer instead of
duplicating" rule means no existing scene needed rewriting — including
the scaffold-first sequence's riskiest case, typing `{` then `Return`
then `}` on separate lines, where the auto-inserted `}` (same line as the
`{` at first) gets pushed to its own line by the `Return` exactly as
intended, and the scene's own subsequent `}` keystroke correctly skips
over the one already there instead of adding a second. Confirmed by
re-rendering the full real pilot scene end to end: `hello.c` still diffs
byte-identical against the chapter's own code block, compiles clean with
`gcc -Wall -Wextra`, runs correctly.

## 17. Locale convention for comment: text (2026-08-19, eleventh)

Owner asked for a convention for translating `comment:` text into other
locales, ahead of actually needing one — thecodingidiot's locale
translation work is broadly paused (en-GB-only focus until the curriculum
itself is solid, see the tci-content-routines project history), so this
is deliberately plumbing, not a request to translate anything now.

Modelled on `tools/manim`'s own locale pattern rather than invented from
scratch: a Manim scene keeps ONE shared `construct()` and swaps a `TEXT`
dict per locale subclass (`BinaryAndNandGreek(BinaryAndNand)`) — the
animation/timeline structure never duplicates, only the strings do.
`comment:`'s YAML equivalent: a `text` value is either a plain string
(typed identically for every locale — untouched, every existing script
still works exactly as before) or a `{locale: string}` mapping:

```yaml
- comment:
    text:
      en-GB: "pulls in the standard I/O header, so printf is available"
      el-GR: "..."
```

`hestia-video` gains `--locale LOCALE` (also settable as a script-level
`locale:` key, CLI wins) — default `en-GB`, matching the project's own
base-locale convention (`content/en-GB/` is what every other locale
falls back from). `resolve_locale_text()` falls back to the `en-GB` entry
for any locale key not yet present, so a scene can grow locale coverage
one comment at a time without ever blocking a render on a translation
that hasn't landed — same spirit as the site's own per-chapter (not
per-string) translation cadence, just at finer grain since a single scene
file holds many independent comments.

**Deliberately NOT translated by this mechanism**: the CODE itself —
every `text:` action typing real C stays exactly as authored, in every
locale, since C keywords/syntax aren't language-dependent. Only
`comment:`'s explanatory prose varies. Whoever DOES eventually translate
a comment should reuse the chapter's own established vocabulary from
`apps/thecodingidiot/content/TRANSLATION.md` and the real translated
`.mdx` files rather than re-translating independently — the exact
practice already established for Manim's locale scenes (§ in
`tools/manim/README.md`'s "Locale variants" section, stoa repo).

**Rendered output naming is NOT auto-derived** — `hestia-video` already
requires an explicit `-o`, and stays that way; follow `tools/manim`'s own
`<basename>-<locale>` convention by hand (e.g.
`f04-your-first-program-el.mp4`), same as light/dark variants already do.

Verified: dry-run resolution (en-GB default, an explicit el-GR override,
and a missing-locale fallback to en-GB) all produce the expected text;
a live render (`--locale el-GR`) confirmed Greek text types and holds
correctly through the real `wtype`/Neovim pipeline, and cleans up to
exactly the pre-comment state (frame-checked, not assumed) — the
BackSpace-count cleanup is character-count-based (Python `len()` on a
Unicode string), which is correct regardless of a language's UTF-8 byte
width, not something that needed special-casing.

## 18. Inline-comment overflow → auto block conversion (2026-08-19, twelfth)

The 640×480 pilot (§14/§17) surfaced a real readability gap: owner
watched the rendered video and found that a long inline `comment:` wraps
inside nvim's own soft-wrap at the smaller resolution — still readable,
but not the intended effect, since it was designed to *look* like a
short annotation, not a wrapped paragraph. Owner asked for a precise
measurement before implementing rather than eyeballing it.

**Measured directly**, not estimated: rendered an isolated `winwidth(0)`
probe at 640×480 with the rig's actual 11pt font —
`winwidth(0)=65, &numberwidth=4, usable=61` columns. Confirmed the
owner's separate assumption (80-char lines) genuinely doesn't fit at
this resolution; 61 is the real budget. `usable_cols(res)` in
`hestia-video` reproduces this from any `res:` via a linear scale off
the measured 640×480 baseline (`PX_PER_COL = 640/65`, `GUTTER_COLS = 4`),
returning `None` when a scene has no `res:` set — auto-fallback is
opt-out-by-absence, not a separate flag.

**The mechanism**: `flatten_actions` now threads a `LineColumn` tracker
through the action list (advances on `text:` content and on
`key: Return/O/o`, deliberately blind to any other motion — every
`comment:` in practice sits immediately after the `text:` it annotates,
so a narrow tracker is enough; general vim-motion tracking isn't
tractable here and wasn't needed). `emit_comment` receives the current
column and the scene's `cols` budget; when a would-be inline comment's
projected length (`column + len(" /*  */") + len(text)`, plus a small
`INLINE_OVERFLOW_MARGIN` safety buffer) exceeds `cols`, it word-wraps
the text with `textwrap.wrap()` and renders it as a block instead —
same content, same explanatory intent, just placed on its own line(s)
above the code instead of soft-wrapping mid-line.

**The mode bug this caught** (real, found by inspecting the actual
rendered file, not just the dry-run key sequence): a deliberately
authored block `comment:` (explicit `lines_up:`) is, by this codebase's
existing convention, always triggered from NORMAL mode — the author's
own script escapes first. But an inline `comment:` is always triggered
mid-INSERT, right after the `text:` it follows. Auto-conversion crosses
that boundary: it reuses the block-mode `O`/`dd` machinery from a
context that's still in INSERT mode. First attempt sent `O` as a
literal typed capital letter instead of "open line above," which
silently ate part of the file (confirmed via a real render + file read,
not just the dry-run's printed key sequence — the dry-run alone would
have looked plausible). Fixed by bracketing auto-converted block
comments with `key: Escape` (insert → normal, before `O`) going in and
`emit_command("A", ...)` (normal → insert at true end-of-line) coming
out — a deliberately-authored block comment doesn't need either, since
its caller already owns mode on both sides.

Verified end-to-end against the real pilot scene
(`tools/video-capture/scenes/f04-your-first-program.yml`, stoa repo),
whose one existing inline comment (57 chars at column 19) genuinely
crosses the 61-column budget and now auto-converts: real render with
`--keep-workdir`, resulting `hello.c` read back byte-identical to the
chapter's own code block, and `gcc -Wall -Wextra` compiles and runs it
clean. Also checked the two guard cases: a short inline comment at the
same resolution stays inline (no false-positive conversion), and a
scene with no `res:` skips the check entirely (`cols=None`).

## 19. Resolution bump to 1024x768 for real 80-char headroom (2026-08-19, thirteenth)

Owner asked whether bumping resolution would get to a genuine 80-column
budget (the pilot's own stated target width), rather than relying on
§18's auto-fallback alone. Measured — not estimated — 5 real
resolutions with the same `winwidth(0)` probe methodology, rendered
through the actual rig at each size:

| `res:` | `winwidth(0)` | usable cols |
|---|---|---|
| 640x480 | 65 | 61 |
| 768x576 (4:3 "576p") | 80 | 76 |
| 800x600 | 83 | 79 |
| 832x624 | 87 | 83 |
| 1024x768 (XGA) | 108 | 104 |

Two real findings from having 5 data points instead of 1:

1. **768x576 ("576p" at 4:3) does NOT reach 80 columns** — only 76.
   800x600 gets to 79 (a single column short). The smallest resolution
   in this set that comfortably clears 80 is 832x624 (83); 1024x768
   clears it with real headroom (104).
2. **Column count is not linear in pixel width** — §18's
   `PX_PER_COL`/`GUTTER_COLS` single-point extrapolation from the
   640x480 measurement alone predicts 100 cols at 1024x768; the real
   number is 104. Fitting a line through all 5 measured points shows why:
   there's a roughly fixed PIXEL overhead (window chrome/decoration,
   ballpark ~55px) that a pure `width/cell_px` model doesn't account
   for, so the single-point scale systematically undershoots at larger
   sizes. Not a huge error, but enough to wrongly force a handful of
   otherwise-fine inline comments into block form.

Fix: `hestia-video` gained `MEASURED_USABLE_COLS`, a lookup table of the
5 real measurements above; `usable_cols()` checks it first and only
falls back to the old linear estimate (documented as approximate) for a
`res:` nobody's measured yet. This is the same "measure the real thing,
don't extrapolate" discipline as §14's Neovim indent bugs and §18's
mode-boundary bug — the fallback formula exists for convenience, not
because it's trusted.

Owner picked **1024x768 (XGA)** — comfortably past 80 columns, still
4:3, still well below `1280x720` in both dimensions. Pilot scene's
`res:` updated; re-rendered with `--keep-workdir`, `hello.c` read back
byte-identical to the chapter's own code block, `gcc -Wall -Wextra`
compiles and runs clean — same verification discipline as every prior
round. At this resolution the pilot's one inline comment (57 chars) no
longer crosses the (now much larger) budget, so it stays inline exactly
as originally authored — confirming the auto-fallback machinery from
§18 correctly does nothing when nothing needs to change, not just that
it correctly converts when something does.

Re-transcoded via `tools/video-capture/optimize.sh` into the live
chapter's `public/video/f04-writing-c/` — same VP9/H.264/poster pipeline
as before, no script changes needed (CRF-based, not
resolution-specific).

**Follow-up, same round**: owner asked for the rig to also render a
`colorcolumn` bar at 80, matching their real personal config
(`user/vim/.vimrc`: `set colorcolumn=80,120,160`, sourced by both their
real Vim and Neovim via `user/nvim/init.vim`'s `source ~/.vimrc`). Added
`colorcolumn=80` to all four rig configs (`vimrc-{dark,light}`,
`nvimrc-{dark,light}.lua`) — deliberately just the 80 mark, not
120/160, since fitting inside 80 columns is this pipeline's whole
concern, not the 120/160 marks that matter for the owner's own
general-purpose editing. No new highlight needed — `hestia.vim` already
defines `ColorColumn` for both variants (dark `guibg=#303030`, light
`guibg=#e4e4e4`), picked up automatically once the option is set.
Verified by extracting a real frame from a re-render (not assumed from
the config diff): bar renders correctly in both dark and light,
confirmed visible in the pilot's own published poster frame.
Re-rendered the pilot again after this change (file still verified
byte-identical + compiles), re-transcoded, re-published.

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
