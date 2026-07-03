# Theme roadmap — dark + light, coherent syntax highlighting everywhere

The long-term goal: hestia grows a **light variant** alongside the dark theme, and
**syntax highlighting means the same thing on every platform** — vim, bat, Shiki
(web code blocks in the stoa monorepo), a future real VS Code theme, and whatever
comes next. This is a multi-session effort; this doc is the system that keeps it
from turning into spaghetti. It records the architecture, the decisions, the
milestone state, and the known-inconsistency backlog. `docs/theming.md` remains
the per-app *process* for GUI chrome; this doc governs the **syntax/highlighting
pipeline and the variant work**.

## The layer model

Three layers. **Edits happen only in layers 1–2; layer 3 artifacts are outputs**
— when generation exists they are rendered, and until then they are hand-copied,
but either way a layer-3 file is never the place a colour decision lives.

1. **The palette** — `themes/wildcharm/palette.yml`. Raw colours (the ANSI 16 +
   `extended`) and UI roles (`bg`, `surface`, `accent`, …). Will grow a `light:`
   variant with the *same role names* (milestone 3), sourced from upstream
   wildcharm's `background=light` branch with hestia's deviations applied
   symmetrically.
2. **The syntax-role table** — the `syntax:` section of `palette.yml`. ~15
   semantic roles (`keyword`, `string`, `comment`, `type`, …), each resolved to a
   palette colour per variant. "Strings are bright_green, everywhere" is a
   statement in this table, not a convention scattered across five configs.
3. **Per-platform artifacts** — each platform maps the syntax roles into its own
   format:
   - **vim/nvim** → highlight groups (today: built-in `wildcharm` via the
     `hestia` wrapper — already conformant by definition, see the decision below).
   - **TextMate-scope family** (bat `.tmTheme`, Shiki theme JSON, VS Code theme)
     → **one shared role→scope mapping**; a Shiki theme JSON *is* a VS Code
     theme JSON, so the web theme and the editor theme are the same artifact
     plus VS Code UI-chrome colours from the roles.
   - **glow** → glamour JSON (markdown-only subset).

   Rules: an artifact carries a header naming its source + palette version; a
   platform quirk or exception lives in that platform's *mapping*, never patched
   into an output; **never invent a shade** — add it to `palette.yml` first
   (unchanged from `docs/theming.md`).

## Decision log

- **2026-07-03 — canonical syntax mapping is `wildcharm.vim` (dark variant).**
  The alternative was the bat `.tmTheme`'s hand-tuned look (accent-red bold
  keywords, blue functions, cyan types), which had diverged from what vim shows.
  Chosen for fidelity — the same principle that dropped Debian red for
  wildcharm's own `#d7005f` — and because upstream wildcharm ships a designed
  **light** counterpart for this mapping (`background=light` branch), so the
  light variant is a derivation, not an invention. Consequences: vim stays a
  thin wrapper; **bat and glow get realigned** (milestone 4); the bat look's
  divergences are itemised in the backlog below.
- **2026-07-03 — hestia deviations carry over to the syntax layer**: comments use
  `dim #8c8c8c` (upstream `#767676` fails AA on hestia surfaces); backgrounds
  and default text come from the roles (`bg #0a0a0a`, `text #e0e0e0`), not
  upstream's pure `#000000`/`#d0d0d0`.
- **2026-07-03 — wildcharm's `Special`/`Todo` purple admitted as
  `extended.purple`, lifted `#875fff` → `#af5fff`** (xterm 99 → 135, red channel
  one 256-palette step). Upstream's purple was tuned against pure `#000000` and
  lands at 4.24:1 on hestia's `surface_alt` — below AA. Same treatment `dim`
  received; hue-true (nearest violet neighbour that clears AA: 4.89:1).
- **2026-07-03 — `diff_delete` deviates to `bright_red #ff5f87`** (upstream
  `Removed` is `#d7005f`). In hestia the accent is a *fill* colour and
  `bright_red` is the accent-coloured *text* (`roles.link`); `#d7005f` fails AA
  as plain text (3.36:1 on `surface_alt`), and git diff + the bat theme already
  use `bright_red` for deletions — this codifies existing practice.
- **2026-07-03 — `error`/`todo` are reverse/fill roles**, exempt from the
  plain-text AA rule: the colour is a background or rendered reverse (vim Error
  is `#d7005f` on white reverse; bat renders invalid as white on `accent_dark`).
  Platform mappings must pair them (`accent_fg`/white), never use them as bare
  foregrounds.

## Upstream reference — wildcharm.vim, both variants

Transcribed from `/usr/share/vim/vim91/colors/wildcharm.vim` (vim 9.1; the
scheme lives in the official vim/colorschemes repo, by Maxim Kim). This is the
raw source for layer 2 — dark is applied now; **light is the milestone-3 input**
(do not re-derive it later, it's already here). Vim default links fold into
these groups: Function→Identifier, Number/Boolean/Character→Constant,
Operator/Keyword→Statement, Delimiter/SpecialChar→Special.

| vim group | dark | light |
|---|---|---|
| Normal fg / bg | `#d0d0d0` / `#000000` | `#000000` / `#ffffff` |
| Comment | `#767676` | `#8a8a8a` |
| String | `#00d75f` | `#008700` |
| Constant | `#ff5f87` | `#af0000` |
| Identifier / Function | `#ff87ff` | `#870087` |
| Statement (keywords, operators) | `#00afff` | `#005faf` |
| Type | `#ffaf00` | `#af5f00` |
| PreProc | `#00d7d7` | `#008787` |
| Special / Todo | `#875fff` | `#5f00d7` |
| Added / Changed / Removed | `#00af5f` / `#0087d7` / `#d7005f` | `#5faf5f` / `#0087d7` / `#d70000` |
| Error | `#d7005f` on `#ffffff` reverse | `#d70000` on `#ffffff` reverse |
| LineNr | `#585858` | `#b2b2b2` |
| CursorLine bg | `#262626` | `#eeeeee` |
| Search | `#000000` on `#00d75f` | `#ffffff` on `#008700` |

Both variants draw from the standard xterm-256 palette; they are designed
siblings. The light hestia deviations (bg softened from pure white? AA-checked
greys?) are **milestone-3 decisions** — record them in the decision log when made.

## Consumers

| Consumer | Artifact | Repo | Status |
|---|---|---|---|
| vim / nvim | `user/vim/colors/hestia.vim` (thin wrapper over built-in wildcharm) | hestia | ✅ conformant by definition (dark) |
| bat (+ vifm preview) | `user/bat/themes/wildcharm.tmTheme` | hestia | 🟡 themed, **diverges** from canonical — realign in M4 |
| glow | `user/glow/wildcharm.json` | hestia | 🟡 themed, divergence unaudited — audit + realign in M4 |
| Shiki (web code blocks) | hestia-dark/-light theme JSON pair | **stoa** — vendored copy at `apps/thecodingidiot/lib/themes/hestia-dark.ts`, wired in `lib/mdx-options.ts` (rehype-pretty-code `{ dark, light }` takes theme objects); `--code-surface` retuned in that app's `globals.css` | 🟡 dark shipped (stoa PR #92, from v0.2.0) / light = M3 |
| VS Code | same JSON + UI-chrome colours | hestia (publish later) | ⬜ M5 |

Cross-repo consumers get **stamped copies** (header: source file + palette
version) — the repos can't import from each other, and the stamp is what makes
drift detectable.

## Milestones

One milestone ≈ one session ≈ one PR. Update the status here in the same PR.

- [x] **M1 — formalise layer 2 (dark).** `syntax:` table in `palette.yml` from
  the canonical mapping; `extended.purple`; palette versioning; this doc.
  (PR: feat/theme-syntax-roles)
- [x] **M2 — first generated consumer: Shiki dark.** `hestia-dark` authored from
  the `syntax:` table (scope selectors from the bat tmTheme, re-coloured to
  canonical), vendored into stoa/tci with `github-light` kept for light
  (stoa PR #92); golden sample added here (this PR). Hand-authored — revisit a
  generator at M6. Live verification caught one mapping fix, now encoded in the
  theme: `storage.*` follows vim's `StorageClass→Type` link (C `int`/`static`,
  TS `const`/`let` render type-yellow), except `storage.type.function`/`.class`
  which stay keyword-blue.
- [ ] **M3 — light variant.** `light:` palette roles + light `syntax:`
  resolution from the upstream table above (+ documented hestia deviations);
  `hestia-light` Shiki theme; tci dual-theme config on hestia pair. tci is the
  light-mode proving ground — the hestia desktop stays dark.
- [ ] **M4 — realign existing consumers.** bat tmTheme re-coloured to canonical
  (scope selectors stay); glow audited + realigned; one consumer per session is
  fine. Live-verify via vifm preview / glow on the golden sample.
- [ ] **M5 — VS Code theme.** Wrap the Shiki JSON with `colors:` UI chrome from
  the roles. Mostly free after M2/M3.
- [ ] **M6 (open-ended) — generation.** Fold artifacts into the deferred Jinja2
  render (`docs/repo-structure-design.md` §9.3) as hand-copying starts to hurt
  (the matrix doubles with light). Not a prerequisite for M2–M5.

## Backlog — known inconsistencies

Record what you notice here (token + platform + where seen); fix at layer 1–2 or
the platform mapping, never in an artifact. Current entries, from the M1 audit —
all are the bat tmTheme vs canonical divergences (resolved by M4):

| Role | canonical (wildcharm.vim) | bat tmTheme today |
|---|---|---|
| keyword / storage | bright_blue `#00afff` | accent `#d7005f` bold |
| string | bright_green `#00d75f` | green `#00af5f` |
| number | bright_red `#ff5f87` (Constant) | yellow `#d78700` |
| language constant | bright_red `#ff5f87` | bright_yellow `#ffaf00` |
| function | bright_magenta `#ff87ff` | blue `#0087d7` |
| type | bright_yellow `#ffaf00` | cyan `#00afaf` |
| preproc / import | bright_cyan `#00d7d7` | magenta `#d787d7` |
| operator | bright_blue (→Statement) | text `#e0e0e0` |
| punctuation | text (vim leaves it Normal) | muted `#adadad` |
| markup heading | bold text (vim Title) | accent `#d7005f` bold |
| markup link | `roles.link #ff5f87` (hestia role) | bright_blue `#00afff` underline |
| error/invalid | accent on white, reverse | white on accent_dark `#9b0040` |

Some bat choices may *win* on re-inspection (e.g. muted punctuation is easy on
the eyes) — if so, promote the choice into the `syntax:` table (a decision-log
entry + version bump), then realign vim… which would mean forking the wrapper.
Default is canonical wins; promote only deliberately.

- glow `wildcharm.json`: not yet audited against the canonical table (M4).
- vifm's code preview follows bat, so it inherits bat's divergence until M4.

## Verification

- **Golden sample** — `themes/wildcharm/golden/` (see its README for per-platform
  render commands): a fixed snippet set — TypeScript, shell, diff, markdown —
  rendered on every platform for eyeball comparison. Coherence checks always run
  against the same content; don't edit the samples casually.
- **Contrast**: every plain-text `syntax:` foreground must clear **WCAG AA
  (4.5:1)** against `roles.bg` *and* `roles.surface_alt` (code-block surface) in
  its variant; reverse/fill roles (`error`, `todo`) are checked as pairings
  instead. Scriptable at generation time — the M1 run of exactly this check
  caught the purple and diff_delete deviations logged above (as the manual
  version once caught the `#767676` comment grey). Check light-variant values
  against the light surfaces in M3.
- Per-app live verification stays as `docs/theming.md` step 5.

## Versioning

`palette.yml` carries a `version:` (semver-ish). Bump **minor** when roles/values
are added, **patch** for a value tweak, and record one line here. Layer-3
artifacts and cross-repo copies stamp the version they were generated from.

- **0.2.0** (2026-07-03) — syntax-role layer added (canonical = wildcharm.vim
  dark, with logged deviations: comment→dim, purple lifted to `#af5fff`,
  diff_delete→bright_red); `extended.purple`; versioning introduced.
  Pre-existing state retroactively = 0.1.0.
