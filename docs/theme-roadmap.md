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
   - **vim/nvim** → highlight groups (`user/vim/colors/hestia.vim`, **GENERATED**
     from the palette by `render.py` since 2026-07 — self-contained, was a
     `wildcharm` wrapper; dark reproduces wildcharm, light on the AA values).
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

- **2026-07-09 — phase B kickoff: builtins + parameters (italic, stack-wide).**
  First tasteful DETAIL on top of the phase-A parity. `*.builtin`
  (function/constant/type) and `variable.parameter` now render in their coarse
  role's COLOUR but ITALIC — distinction without a new hue, keeping the tight
  wildcharm palette. Coherent across the stack from one SSOT: nvim links the
  `@*.builtin`/`@variable.parameter` captures to new `hestiaBuiltin*`/`hestiaParam`
  intermediate groups (plain names, defined-but-unused in Vim); `scopes.yml`
  splits `support.*` / `constant.language` / `variable.parameter` into italic
  rules for bat/Shiki/VSCode. Shiki (VSCode-grade grammars) expresses it in more
  places than bat. Extends the pre-existing `variable.language` (self/this)
  italic. Added C/C++/Java treesitter parsers (`trees.lua`). No palette values
  (font-style only) → stays 0.8.0. **thecodingidiot needs a re-vendor** of the
  regenerated `dist/shiki/*.json` to pick this up (cross-repo, see hestia.ts).
  Next phase-B candidates: members/properties, function call-vs-def, decorators,
  and unifying operators (vim leaves them plain, bat/Shiki colour them blue).
- **2026-07-09 — treesitter/LSP parity for nvim (phase A).** nvim highlights
  code via finer-grained `@*` captures whose defaults OVER-colour vs Vim
  (builtins/constructors → Special purple, punctuation → Delimiter, operators →
  Operator blue). Linked the `@*` captures (and the `@lsp.type.*` that don't
  chain) to the standard groups Vim uses, so nvim renders with hestia's group
  identity — keywords blue, strings green, constants pink (not purple),
  types yellow, functions magenta; symbolic operators / punctuation / plain &
  member variables / module names / call sites → Normal (verified against
  vim-python: it leaves `= + ==` plain, colours `and`/keywords blue — the table
  matches). Exact token parity is impossible (vim-regex and treesitter tokenise
  differently, and vim's own operator colouring is language-specific — e.g.
  lua.vim colours symbolic operators; nvim renders those calmer, which is the
  parity-over-richness intent). Diagnostics (`Diagnostic*` + underlines) mapped
  to the palette. **Phase B** (richer treesitter detail, balanced across the
  hestia app stack — bat/VSCode/…) is deferred as a gradual effort. Links are
  variant-invariant and harmless in Vim (the `@*` groups go unused there).
- **2026-07-09 (0.8.0) — vimdiff FILLS in the palette, Claude-style.** New
  `diff:` section (dark + light): the `DiffAdd/DiffChange/DiffText/DiffDelete`
  *backgrounds*, a low-saturation tinted row that KEEPS the code's syntax
  highlighting on top (consumer sets `guifg=NONE`) — verified via `:TOhtml`
  that added-line tokens keep their syntax colours on the tint. Replaces
  wildcharm's fg-tinting (which recoloured every diff line green/red, losing
  syntax). add=green, delete=maroon, change=blue, text=brighter blue (Changed
  == blue, matching `syntax.diff_change`). Consumed by hestia.vim only for now;
  distinct from `syntax.diff_*` (git-diff-language TEXT in bat/Shiki). Exempt
  from the AA plain-text gate (fills). Third of the vim own-it phases (after
  the self-contained detach #177 and the render.py target #178).
- **2026-07-03 — wofi cannot take CSS fragments; use its colors file.** The
  0.7.0 `@import "theme.css"` approach rendered wofi transparent: wofi
  preprocesses the stylesheet TEXT itself (its `--wofi-color<n>` macro pass)
  and hands the result to GTK, so a relative @import never resolves. Corrected
  to wofi's native mechanism: a GENERATED `colors-{dark,light}` file
  (newline-separated hexes, NO comments possible — the one artifact without a
  provenance header; slot order lives in render.py `WOFI_SLOTS` + the style.css
  header), `--wofi-color<n>` macros in style.css, `colors=colors` in the wofi
  config (relative paths resolve against ~/.config/wofi). Platform-quirk rule
  upheld: the quirk lives in wofi's mapping, not the palette.

- **2026-07-03 (0.7.1) — light ANSI color1 IS the accent** (`#d7005f`, deviating
  from upstream light's `#af0000`): hestia's identity is `accent == ANSI
  color01` and it must hold in both variants — caught live when cmus's bars
  (which fill with terminal colour 1) rendered plain dark red on the light
  desktop while waybar/VS Code (accent-as-hex) stayed magenta-red. Upstream's
  `#af0000` lives on as light `syntax.constant`. Re-rendered: kitty light
  `color1`, VS Code light `terminal.ansiRed`.
- **2026-07-03 (0.7.1) — dircolors generated, both variants**, from the SAME
  `filetype_colors()` table as the vifm colorscheme — closing the day-old
  backlog item: `ls` and vifm now agree **by construction** in both variants
  (the "kept in sync by hand" era ends). Dark output value-identical to the
  retired hand-written `.dircolors`; light uses the readable base-slot drops
  (dir 25, link/audio 30, exec 28, …). Light Link == Fifo (both base cyan) —
  accepted, fifos are rare.

- **2026-07-03 (M7 PR2/0.7.0) — the whole desktop chrome is now generated.**
  render.py grew emitters for mako/wofi/zathura (include fragments), swaylock/
  swaynag (whole-file pairs — no include support), vifm (`wildcharm-{dark,light}
  .vifm`, dest keeps the `wildcharm` name), bat (`render_tmtheme(variant)` pair)
  and glow (glamour JSON pair) — each dark output proven **value-identical** to
  the hand-written file it retired (glow/bat byte-identical modulo provenance;
  zathura differs only by the logged rgba fix). The VS Code chrome dict was
  unified (one role-mapped dict, per-variant tables) — light got the full
  chrome, dark stayed byte-identical. Admissions forced: `extended.sunken
  #111111` (+ light `#ffffff` counterpart) and `extended.ink #000000`
  (variant-invariant text on light fills).
- **2026-07-03 (M7 PR2) — light TUI mapping rules.** The cursor bar inverts
  (dark: `ink` on `ui_grey #9e9e9e`; light: `accent_fg` on `ui_dark #5f5f5f`) —
  vifm CurrLine/TopLineSel and cmus selections share it. File-type colours stay
  ANSI-slot-faithful EXCEPT the common groups (Directory/Link/Executable,
  audio/docs/markdown), which drop from the bright to the BASE slots on light —
  the bright slots are dark-tuned (bright_green is 2.7:1 on the light ground)
  and upstream wildcharm's own light design makes the same move (light String
  is the base green). Consequence: `ls` (variant-invariant dircolors) and vifm
  agree exactly on dark only — backlog item below.
- **2026-07-03 (M7 PR2) — zathura recolour is a dark-mode feature**: ON on the
  dark desktop (pages invert to the ground), OFF on light (pages are already
  light); both variants carry sensible recolor-* values so `r` still toggles.
  The render also fixed the latent Debian-red `rgba(206,0,86,…)` active-search
  highlight (pre-dated the accent change).
- **2026-07-03 (M7 PR2) — qt_theme grew the light scheme**: defaults
  restructured to `qt_theme_schemes: {dark: Hestia, light: Hestia Light}`;
  BOTH `.colors` files are always installed (selectable in-app), kdeglobals +
  the Kdenlive pre-pick follow the active `theme_variant`. Dark `negative`
  moved off the never-admitted `#da4453` onto `ansi.bright_red #ff5f87` — the
  same semantic error red VS Code/vifm use (palette-law cleanup, logged dark
  delta).
- **2026-07-03 (M7 PR2) — cava ruled variant-invariant**: `background =
  default` follows the terminal, the gradient bars are saturated fills (no AA
  text rule applies); revisit only if the cyan top washes out on light live.
- **2026-07-03 (M7/0.6.0) — light desktop ground `#f5f5f5`, ramp below it on
  xterm greys.** The light desktop (M7 PR1) softens the ground off pure white —
  the mirror of dark's `#000000→#1a1a1a` lift (and like `#1a1a1a`, not an xterm
  colour); ramp: `surface #e4e4e4` (254, wildcharm light's own Pmenu),
  `surface_alt #dadada` (253), `border #c6c6c6` (251), `muted #4e4e4e` (239).
  The M3 "light bg stays pure `#ffffff`" decision survives via a new light-only
  **`code_surface: #ffffff`** role — the web code surface keeps white (raised
  on tci's warm page), the desktop gets the softened ground; render.py's shiki
  target reads `code_surface`, everything canvas-like reads `bg`.
- **2026-07-03 (M7/0.6.0) — the light AA gate moved to `#f5f5f5`**, which
  pushed three M3 syntax values (tuned against white) under 4.5:1 — minimal
  hue-true xterm steps, same rules as ever: `string #008700→#005f00` (22,
  7.30:1), `type #af5f00→#875f00` (94, 5.25:1), `diff_add #00875f→#005f5f`
  (23, 6.87:1). **diff_add now collides with preproc** — accepted: light
  already shares values (`special == string_special`, `error == diff_delete`),
  and imports vs added-diff-lines never co-occur ambiguously; the only
  AA-passing hue-true alternative didn't exist.
- **2026-07-03 (M7/0.6.0) — light `dim` decoupled from `comment`**: dim
  `#6c6c6c→#626262` (241) so it clears bg (5.59) AND surface (4.80) — the
  exact mirror of dark dim's profile (5.18/4.50, fails surface_alt);
  `syntax.comment` stays `#6c6c6c` (code sits on the ground, 4.82:1). M3 had
  defined them equal; UI dim also sits on raised surfaces, comments don't.
  Also: accent-as-text (the light link) clears the ground (4.75:1) but NOT
  surface (4.07) — links on raised light surfaces underline or use text.
- **2026-07-03 (M7/0.6.0) — `light.ansi` transcribed verbatim** from upstream
  wildcharm.vim's light `g:terminal_ansi_colors` (kitty light + future
  terminal-app consumers). Upstream quirks kept by the never-invent rule
  (color7 "white" = mid-grey `#8a8a8a`, color0 = pure black). Note light bg ≠
  color0 — the dark-side `bg == color0` watch item has no light counterpart.
- **2026-07-03 (M7/0.6.0) — off-palette config literals remapped/admitted**
  (generation of the kitty/sway/waybar fragments forced the rulings): kitty
  `active_border_color #2a2a2a` → `surface #262626`; waybar `#cccccc` → `text`,
  `#c8c8c8` → `muted`, `#666666` → `bright_black #767676` (all three were
  never-admitted greys — small deliberate dark visual deltas). Admitted to
  `extended:`: the wildcharm UI greys `ui_grey #9e9e9e` (247) + `line_grey
  #585858` (240) with light counterparts `line_grey #b2b2b2` (249) + `ui_dark
  #5f5f5f` (59), and render-markdown's `heading_bg #1a0a12` (retroactive) with
  light counterpart `#ffd7d7` (upstream light DiffDelete bg).
- **2026-07-03 (M7) — the switch is an Ansible variable, not a runtime
  helper**: scalar `theme_variant: dark|light` (group_vars default dark;
  setup.sh asks; host_vars overrides). Flip = re-run the playbook
  (`--tags dotfiles,sway_session`) + re-login. Selection mechanism: generated
  per-app fragment pairs with **variant-picked manifest `src`, variant-neutral
  dest** (`theme-{{ theme_variant }}.conf → theme.conf`) — the manifest srcs
  are already Jinja-interpolated, zero role changes. A runtime
  `hestia-mode dark|light` helper (kitty `@ set-colors`, gsettings flip
  without re-login) stays future work.
- **2026-07-03 (M7) — vim stays conformant-by-definition on light too**: the
  hestia.vim wrapper gains only the light Normal/TabLineFill override
  (`#f5f5f5`/`#1a1a1a`); syntax comes from upstream wildcharm's native light
  branch verbatim — including values below the palette's AA gate (upstream
  light String `#008700` is 4.31:1 on the soft ground), exactly as dark vim
  shows upstream's `#767676` comments. The gate governs *generated* consumers.
- **2026-07-03 — THE BG-LIFT VERDICT: promoted (palette 0.5.0).** After living
  with the experiment (PR #125), the lifted ground won every comparison —
  vifm's clearer borders/splits, and the VS Code canvas twice felt wrong at
  `#0a0a0a`. Key insight that shaped the promotion: *the colour that kept
  winning was the code-block surface, so it became the ground itself* — the
  web code surface stays `#1a1a1a` (raised on tci's darker page) and now
  equals `roles.bg`, which means the syntax tables needed **no** re-lifting
  (all roles already clear AA on `#1a1a1a`; the earlier warning assumed the
  code surface would lift too). Only the UI ramp rebuilt, on xterm-native
  greys: `surface #262626` (xterm 235 — wildcharm's own CursorLine),
  `surface_alt #303030` (236, now hover/line-highlight/alt-rows only),
  `border #3a3a3a` (237). Ramp steps are even (~1.15× each).
- **2026-07-03 (0.5.0) — `bg == ANSI color0` accepted** (`#1a1a1a`). Common in
  terminal themes; the practical risk (color0-painted TUI panels blending with
  the ground) never materialised during the experiment. Watch item in the
  backlog; if an invisible-text case appears, shift color0, not the ground.
- **2026-07-03 (0.5.0) — vim `Normal` fg lifted to `roles.text #e0e0e0`**
  (was wildcharm's `#d0d0d0`; closes the backlog item — kitty/waybar/vifm
  already used roles.text). Also fixed alongside: `.vimrc` now enables
  `termguicolors` when `COLORTERM` says truecolor — vim had been rendering the
  cterm fallback (`#1c1c1c`, one 256-step off the ground), caught by pixel-
  sampling a screenshot during the verdict discussion.
- **2026-07-03 (0.5.0) — `dim` usage guidance**: it clears AA on `bg` (5.18)
  and `surface` (4.50) but not `surface_alt` (3.92) — transient hover surfaces
  carry `text`/`muted` only. Encoded in the palette comments; the render gate
  checks syntax roles against the ground.

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
- **2026-07-03 (M3) — light-variant deviations**, same rules as dark (AA against
  the light surfaces, minimal xterm-256 steps): `text` softened `#000000` →
  `#1a1a1a` (the mirror of dark's bg softening); `comment` `#8a8a8a` → `#6c6c6c`
  (upstream is 3.45:1 on white; xterm 242 lands 5.25:1 ≈ dark's 5.18:1);
  `preproc` `#008787` → `#005f5f` (4.36→7.49:1, one cube step); `diff_add`
  `#5faf5f` → `#00875f` (2.70→4.53:1, mirrors the dark string-vs-diff green
  family); `diff_change` `#0087d7` → `#005fd7` (3.86→5.80:1). Everything else is
  upstream verbatim — notably the light purple needs no lift.
- **2026-07-03 (M3) — light `bg` stays pure `#ffffff`, a deliberate asymmetry**
  with dark's softened ground: the only light consumer is the web code surface,
  which sits raised on tci's warm `#fefcf8` page — a softened grey-white reads
  dirty there, not softer. Revisit if a desktop light consumer ever appears.
- **2026-07-03 (M3) — no light `link` role: the accent doubles as text on light
  grounds** (`#d7005f` is 5.18:1 on white). The dark-side `link #ff5f87` exists
  only because the accent fails as text on dark surfaces.
- **2026-07-03 (M3) — light scope kept to what has a consumer**: syntax table +
  the roles web code blocks need. The light desktop ramp (surface/border/…) is
  deliberately NOT invented ahead of a consumer that would verify it live.

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
| vim / nvim | `user/vim/colors/hestia.vim` (**GENERATED** from palette.yml by render.py, self-contained since 2026-07; was a wildcharm wrapper) | hestia | ✅ palette-driven; Claude-style diff fills (0.8.0); treesitter `@*`/LSP/diagnostics linked for nvim↔vim parity (phase A). Remaining: plugin groups; phase-B richer treesitter detail |
| bat (+ vifm preview) | `user/bat/themes/wildcharm-{dark,light}.tmTheme` (GENERATED pair, M7 PR2) | hestia | ✅ realigned M4, generated since 0.4.0; light pair since 0.7.0 |
| glow | `user/glow/wildcharm-{dark,light}.json` (GENERATED pair, M7 PR2) | hestia | ✅ realigned M4, generated since 0.7.0 |
| Shiki (web code blocks) | hestia-dark/-light theme JSON pair | **stoa** — vendors the GENERATED `themes/wildcharm/dist/shiki/*.json` (copied into `apps/thecodingidiot/lib/themes/`, thin `hestia.ts` wrapper), wired in `lib/mdx-options.ts`; `--code-surface` matches the pair in that app's `globals.css` | 🟡 **stoa re-vendor pending**: 0.6.0 changed three light syntax values (the `#f5f5f5`-gate deviations; the light `editor.background` stays `#ffffff` via `code_surface`) — copy the regenerated pair over |
| VS Code | `user/vscode/hestia/` extension (GENERATED themes) | hestia | ✅ dark + light full chrome (M7 PR2); verified live on 1.127 (dark, 2026-07-03) — light chrome pending the M7 live pass |
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
- [x] **M3 — light variant.** `light:` section in `palette.yml` (0.3.0): roles
  subset + full light `syntax:` from the upstream table (+ five deviations, see
  the decision log); `hestia-light` Shiki theme vendored into stoa/tci, dual
  config now the hestia pair (stoa PR — see consumer table). In stoa the two
  variants were refactored into ONE role→scope mapping with per-variant colour
  tables (`lib/themes/hestia.ts`), so the scope decisions can't drift between
  dark and light — the embryo of the M6 generator. tci is the light proving
  ground; the desktop stays dark.
- [x] **M4 — realign existing consumers.** bat tmTheme rebuilt to MIRROR the
  shared TextMate scope map (same rules as the web Shiki pair — including the
  M2 storage→Type fix and the dropped meta.function-call); glow audited (it
  predated the palette: its chroma block was full of invented near-miss shades)
  and realigned — chroma to the canonical syntax table, chrome (headings/links/
  inline code) onto palette values, keeping glow's markdown-rendering accent
  identity. Both verified live on the golden samples via ANSI-escape inspection
  (all old colours at zero; glow's 256-colour fallback maps losslessly because
  wildcharm's hexes ARE xterm-256 colours). One residue: the 256-colour
  fallback renders comment dim as xterm 245 `#8a8a8a` (the AA-lifted `#8c8c8c`
  has no exact xterm home) — truecolor terminals are exact.
- [x] **M5 — VS Code theme.** `user/vscode/hestia/` — extension with both
  variants, JSONs **generated** (M6). Dark ships full UI chrome from the roles
  (accent status bar/buttons like vifm/cmus/less, `surface` panels, ANSI-16
  integrated terminal); **light is editor-only** — chrome falls back to VS
  Code's stock light UI until the light desktop ramp exists (M7). Not wired
  into the bootstrap (VS Code isn't base-system); install per the extension
  README. **Verified live on VS Code 1.127 (2026-07-03)** — both themes load
  and render; install must go via `.vsix` (`vsce package` +
  `code --install-extension`; a folder symlinked into `~/.vscode/extensions`
  does not register on current VS Code). *Amended 2026-07-03: the "not
  bootstrap-wired" call was reversed after the manual vsix copy-lag cost three
  round-trips — the `vscode_theme` role now packages + installs on version
  change, gated on the `code` binary rather than a manifest entry (VS Code
  itself stays outside the apt manifest — it's Microsoft-repo software).*
- [x] **M6 — generation (TextMate family).** The scope map became data
  (`themes/wildcharm/scopes.yml`, layer 2½) and `themes/wildcharm/render.py`
  renders every TM-family artifact from it + `palette.yml`: bat's tmTheme, the
  web Shiki pair (`dist/shiki/`, vendored by stoa), and the VS Code themes —
  same tokenColors everywhere, per-target chrome (bat/VS Code canvas =
  `roles.bg`; web code surface = `surface_alt`). The **AA gate runs inside the
  render** (a palette edit that breaks a role fails the build) and
  `render.py --check` detects stale artifacts. Equivalence proven at adoption:
  regenerated bat output byte-identical to M4's, generated Shiki JSONs
  render byte-identical HTML to M3's hand-written pair. Python, not the
  deferred Ansible/Jinja2 route — same pattern as `gen-symlink-table.py`.
  Outside the generator still (hand-applied): glow (chrome-heavy, small chroma
  block), vifm, kitty, and the GUI chrome configs — fold in if/when churn
  justifies it.
- [x] **M7 PR1 — light desktop: ramp + switch + core session.** (a) the light
  desktop ramp designed and landed (palette 0.6.0 — ground `#f5f5f5`,
  `code_surface` split, ramp/dim decisions in the log above); (c) the **switch
  mechanism decided and built as an Ansible variable** — `theme_variant:
  dark|light` (setup.sh question, host_vars, group_vars default dark) driving
  variant-picked manifest symlinks of GENERATED per-app fragment pairs
  (render.py grew kitty/sway/waybar emitters), `GTK_THEME` in a now-templated
  start-sway.j2, and a templated gtk-3.0 settings.ini; (b) partially: kitty,
  sway, waybar, vim (background selector + hestia.vim light branch) — the GTK
  light theme (`hestia`) already existed from the gtk_theme role. The runtime
  `hestia-mode` helper idea was set aside (decision log).
- [x] **M7 PR2 — light desktop: the long tail.** All of it landed (0.7.0):
  render.py emitters for mako/wofi/swaylock/swaynag/zathura/vifm/bat/glow (dark
  outputs value-identical to the retired hand-written files); cmus rc.j2
  variant indices; qt_theme `Hestia Light` (+ both schemes always installed);
  VS Code full light chrome (extension 0.7.0); cava ruled variant-invariant;
  the theming.md table grew the light column; the zathura Debian-red bug and
  the `sunken`/`ink` admissions fixed en route. Remaining M7 item: the **live
  verification pass** over both variants (dimitrios, per PR checklist).

## Backlog — known inconsistencies

Record what you notice here (token + platform + where seen); fix at layer 1–2 or
the platform mapping, never in an artifact.

- ~~The M1 audit's bat-vs-canonical divergence table (12 rows: accent-bold
  keywords, blue functions, cyan types, magenta preproc, muted punctuation,
  accent headings, blue links, …)~~ — **resolved in M4** (bat rebuilt on the
  shared scope map; none of the bat choices were promoted — canonical won
  everywhere). vifm's preview follows bat, so it realigned with it.
- ~~glow `wildcharm.json` unaudited~~ — **resolved in M4**: it predated the
  palette entirely (invented near-miss shades throughout); chroma realigned to
  the canonical table, chrome moved onto palette values.
- Minor, accepted: on 256-colour terminals, downsampled renders show comment
  dim as xterm 245 `#8a8a8a` — the AA-lifted `#8c8c8c` has no exact xterm home.
  Truecolor terminals (kitty) are exact.
- ~~vim Normal fg vs `roles.text`~~ — **RESOLVED in 0.5.0**: the wrapper lifts
  `Normal guifg` to `roles.text #e0e0e0` (see the decision log).
- ~~vifm's panel greys not recorded in `palette.yml`~~ — **RESOLVED in 0.6.0**
  (M7 PR1): `#585858`/`#9e9e9e` admitted as `extended.line_grey`/`ui_grey`
  (+ light counterparts); `#262626`/`#303030` were already `surface`/
  `surface_alt`. The vifm colours file itself renders from them in M7 PR2.
- ~~bg lift experiment (2026-07-03, PR #125)~~ — **RESOLVED: promoted as
  palette 0.5.0** (see the decision log). The feared syntax re-lifting never
  happened: the code surface didn't move (it became the ground), so the AA
  constraints stayed at `#1a1a1a`.
- ~~Light `ls` vs vifm divergence (M7 PR2)~~ — **RESOLVED in 0.7.1**: dircolors
  became a generated variant pair sharing vifm's `filetype_colors()` table.
- **WATCH — `bg == ANSI color0` (`#1a1a1a`, since 0.5.0).** If a TUI ever
  paints color0 text/panels invisibly against the ground, shift color0 (and
  vifm/dircolors consumers of it), not the ground.

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

- **0.7.1** (2026-07-03) — light `ansi.red` → the accent (identity fix, cmus
  caught it live); `.dircolors` generated as a variant pair from the shared
  vifm file-type table (backlog item closed).
- **0.7.0** (2026-07-03) — **the long tail generated (M7 PR2)**: emitters for
  mako/wofi/zathura fragments, swaylock/swaynag whole-file pairs, vifm/bat/glow
  theme pairs (retiring their hand-written files — dark value-identical); VS
  Code light = full chrome (unified dict); `extended.sunken`/`ink` admissions
  (+ light `sunken #ffffff`); zathura rgba bugfix; qt_theme light scheme +
  dark `negative` → `bright_red`; cmus variant indices (rc.j2, not render.py).
- **0.6.0** (2026-07-03) — **the light desktop ramp (M7 PR1)**: light ground
  `#ffffff` → `#f5f5f5` with the web code surface split out as
  `light.roles.code_surface #ffffff`; light `surface/surface_alt/border/muted`
  defined (xterm 254/253/251/239); light `dim` → `#626262` (decoupled from
  comment); three light syntax deviations for the new gate ground
  (string/type/diff_add — diff_add==preproc collision accepted); `light.ansi`
  (upstream verbatim); `extended` admissions `ui_grey/line_grey/heading_bg` +
  light counterparts. render.py grew desktop-chrome emitters
  (kitty/sway/waybar fragment pairs). stoa re-vendor of the shiki pair pending.
- **0.5.0** (2026-07-03) — **the bg-lift promotion**: ground `#0a0a0a` →
  `#1a1a1a` (== the web code surface, which doesn't move; == ANSI color0,
  accepted watch item); surface ramp rebuilt on xterm greys (`#262626` /
  `#303030` / `#3a3a3a`); vim Normal fg → `roles.text`; syntax tables
  unchanged (AA constraints stayed at `#1a1a1a`). Propagated across every
  consumer + regenerated artifacts in one sweep.
- **0.4.0** (2026-07-03) — the TM scope map extracted to `scopes.yml` (layer 2½
  data) and `render.py` introduced: bat/Shiki/VS Code artifacts are now
  generated, with the AA gate inside the render and a `--check` drift mode. No
  colour changes (equivalence proven byte-for-byte at adoption).
- **0.3.0** (2026-07-03) — light variant added (`light:` roles subset + syntax
  table; canonical = wildcharm.vim light with five logged deviations: text
  softened, comment/preproc/diff_add/diff_change darkened for AA). Light scope
  deliberately limited to consumers that exist (web code blocks).
- **0.2.0** (2026-07-03) — syntax-role layer added (canonical = wildcharm.vim
  dark, with logged deviations: comment→dim, purple lifted to `#af5fff`,
  diff_delete→bright_red); `extended.purple`; versioning introduced.
  Pre-existing state retroactively = 0.1.0.
