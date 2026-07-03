# Theming hestia

hestia's default look is a **dark theme** on the `#1a1a1a` ground, accent
**wildcharm red `#d7005f`**, and a saturated **16-colour palette from the `wildcharm`
vim colorscheme**; since M7 a **light variant** (`#f5f5f5` ground, same accent) can
drive the desktop too. This doc is the **process** for bringing a new app onto that
look. The colours themselves live in one place — **`themes/wildcharm/palette.yml`**
(the single source of truth) — so this doc never repeats hex values; it tells you how
to apply them.

> The **dark/light variant system** and **cross-platform syntax-highlighting
> coherence** (vim, bat, Shiki/web, VS Code) are governed by
> **`docs/theme-roadmap.md`** (layer model, decision log, milestones, backlog). For
> *syntax* colours specifically, map an app from the palette's **`syntax:`** role
> table (layer 2), not ad hoc from the ANSI names.

> **The variant switch (M7).** `theme_variant: dark|light` in the bootstrap
> (group_vars default `dark`; setup.sh asks; flip in `host_vars`, re-run the
> playbook — `--tags dotfiles,sway_session` — and **re-login**). It selects which
> GENERATED per-app fragment (`theme-dark`/`theme-light`, rendered by
> `themes/wildcharm/render.py`) gets symlinked to the app's variant-neutral
> `theme.*` path, and what the rendered configs carry (`GTK_THEME` in start-sway,
> the gtk-3.0 settings.ini theme name). When theming an app that has
> ground/surface colours, prefer the fragment-pair pattern over baking dark
> literals into the config.

> **How the non-generated configs work.** Outside the generated fragments the
> palette is applied **by hand**: you read the right value from `palette.yml` and
> write the literal hex into the app's own config, which is then deployed by the
> bootstrap (symlinked or rendered). Configs stay directly editable. The exceptions —
> **rendered by `render.py`**, never hand-edit, `render.py --check` catches drift —
> are the TM-family artifacts and the per-app colour files: the
> kitty/sway/waybar/mako/wofi/zathura fragments, the swaylock/swaynag whole-file
> pairs, and the vifm/bat/glow theme pairs. (cmus's variant colours ride its
> Ansible-rendered `rc.j2`; the KDE schemes ride the `qt_theme` role.)

## The per-app process

1. **Identify** the app's colour mechanism. Common shapes:
   - *Terminal/TUI* (kitty, cmus, cava, vifm) → an ANSI 16-colour table or `colorN` slots.
   - *GTK/CSS* (waybar, wofi) → a stylesheet with `color`/`background-color`.
   - *key=value config* (mako, swaylock, zathura) → named colour options.
   - *Own colorscheme format* (vim `wildcharm`, vifm `.vifm`, glow glamour JSON).
   - *GTK app theme* (GNOME/libadwaita) → named theme colours / `gtk.css` — the hard case.
2. **Map** each colour surface to a palette entry:
   - GUI chrome → a **role** (`bg`, `surface`, `border`, `text`, `dim`, `accent`, …).
   - Terminal colour slots → the matching **`ansi`** name.
   Decide the mapping in role/ANSI *names* first; it makes intent reviewable.
3. **Apply** the hex from `palette.yml`. Copy the literal value (strip the leading `#` for
   tools that want bare `RRGGBB`, e.g. swaylock). **Never invent a shade** — if the app
   genuinely needs one the palette lacks, **add it to `palette.yml` first** (with a comment),
   then use it. That keeps the SSOT complete.
4. **Deploy** via the bootstrap manifest (`bootstrap/group_vars/all.yml`):
   - Static config → add to **`dotfile_links`** (symlinked; stays direct-editable).
   - Only if it must carry a host/identity/path value → **`templated_configs`** (`.j2`).
   - If you touched `dotfile_links`, run **`bootstrap/gen-symlink-table.py`** to regenerate
     the symlink table in `CLAUDE.md`.
5. **Verify** live — reload the app and eyeball **every state** (idle/active/hover/error,
   focused/unfocused, etc.), not just the happy path.
6. **Document** — add or update the app's section in `CLAUDE.md`, and **tick the status
   table** below.

## Status

Legend: ✅ themed · 🟡 partial · ⬜ not yet.

| App | Mechanism | Dark | Light | Notes |
|---|---|---|---|---|
| kitty | ANSI 16 + roles | ✅ | ✅ | the canonical 16-colour definition — **GENERATED fragment pair** `theme-{dark,light}.conf` (render.py), `include`d by kitty.conf; the variant is picked by `theme_variant` (M7) |
| sway | `$bg/$surface/…` vars | ✅ | ✅ | window borders, urgent, desktop bg + the gsettings appearance execs — **GENERATED fragment pair** `theme-{dark,light}.conf` (render.py), `include`d by the config (M7) |
| waybar | GTK CSS | ✅ | ✅ | bar + tooltips; colours as `@define-color` tokens — **GENERATED fragment pair** `theme-{dark,light}.css` (render.py), `@import`ed by style.css (M7) |
| swaylock | key=value config | ✅ | ✅ | **GENERATED whole-file pair** `config-{dark,light}` (render.py; no include support) — all indicator states; light insides flip `sunken` to white |
| swaynag | key=value + `[type]` | ✅ | ✅ | **GENERATED whole-file pair** `config-{dark,light}` (render.py) — exit/warning/error dialogs, the per-type restatement comes free from the emitter loop |
| mako | key=value config | ✅ | ✅ | notifications, urgent variant — colours in the **GENERATED** `theme-{dark,light}.conf` pair (render.py), `include=`d LAST by the config; behaviour keys stay direct-edit |
| wofi | GTK CSS | ✅ | ✅ | launcher — colour tokens in the **GENERATED** `theme-{dark,light}.css` pair (render.py), `@import`ed by style.css |
| cava | gradient config | ✅ | ✅ n/a | accent-anchored cool sweep through wildcharm hues (accent → magenta → blue → cyan). **Ruled variant-invariant** (M7): `background = default` follows the terminal, the bars are saturated fills (no AA text rule); revisit only if the cyan top visually washes out on light |
| cmus | cterm slots (rc) | ✅ | ✅ | accent tracks ANSI red (variant-invariant); the ABSOLUTE 256-cube greys/error/dir indices flip with `theme_variant` in the rendered `rc.j2` (M7), mirroring vifm's variant values |
| vifm | `.vifm` colorscheme | ✅ | ✅ | file-type colours from the ANSI set, **plus per-glob `:highlight` rules mirroring `~/.dircolors`'s extension layer** (vifm has no LS_COLORS; since 0.7.1 both render from the same `filetype_colors()` table, so they agree by construction) — archives/images/video/audio/docs match `ls`; preview pane on by default (`view!`, `w` toggles); catch-all `fileviewer` runs `scripts/preview.sh` for syntax-highlighted code preview (bat, wildcharm) with binary/dir fallback; images show text info (mediainfo) — in-pane rendering was dropped (kitty graphics didn't display in vifm and made scrolling laggy); open in imv instead. **GENERATED colorscheme pair** `wildcharm-{dark,light}.vifm` (render.py; dest keeps the `wildcharm` name so vifmrc is variant-blind); on light the common groups (Directory/Link/Executable, audio/docs) drop from the bright to the BASE ANSI slots for readability — upstream wildcharm's own light design does the same |
| bat | `.tmTheme` syntax theme | ✅ | ✅ | **GENERATED pair** `user/bat/themes/wildcharm-{dark,light}.tmTheme` (dest keeps the `wildcharm` stem bat selects) — by `themes/wildcharm/render.py` from `palette.yml` + `scopes.yml` (never hand-edit; re-render after a palette/scope change, `--check` detects drift); compiled into bat's cache by the dotfiles role (`bat cache --build`); drives vifm's code preview. Debian ships the binary as `batcat` |
| glow | glamour JSON | ✅ | ✅ | markdown render theme — **GENERATED pair** `wildcharm-{dark,light}.json` since M7 (dest keeps the name glow.yml points at); realigned M4 — the embedded **chroma** block follows the `syntax:` table, the markdown *chrome* (accent headings, h1 fill, pink links/inline code) keeps its identity but only with palette values |
| vim / nvim | `hestia` colorscheme (wildcharm wrapper) | ✅ | ✅ | `user/vim/colors/hestia.vim` loads built-in `wildcharm` then overrides the ground/text per `&background` (dark `#1a1a1a`/`#e0e0e0`, light `#f5f5f5`/`#1a1a1a` — M7); the variant comes from the symlinked `~/.vim/hestia-background.vim` selector sourced by `.vimrc` (falls back dark). `.vimrc` enables `termguicolors` so the gui values render exactly. In `~/.vim/colors` so Vim + Neovim share it. Plus render-markdown accent (nvim; heading wash per variant) |
| ls / file listing | `dircolors` (LS_COLORS) | ✅ | ✅ | **GENERATED pair** `user/bash/.dircolors-{dark,light}` (render.py, 0.7.1) — file-**type** colours come from the SAME `filetype_colors()` table as vifm's generated colorscheme, so `ls` and vifm agree **by construction** in both variants (dark: dir 39, link 44, exec 41, …; light: the readable base-slot drops — dir 25, link 30, exec 28); plus the restrained wildcharm extension layer (archives/images/video/audio/docs). `.bashrc` already loads `~/.dircolors` (the variant symlink) |
| git | `[color]` in `.gitconfig` | ✅ | 🟡 | hex (24-bit) palette, **aligned to the bash prompt** so the accent means one thing everywhere: branch → yellow `#d78700`, staged/added → green, dirty (changed/untracked) → accent `#d7005f`. Diff lines stay bright red/green (line-level, off the accent — git's default `old`=red would otherwise be `#d7005f`). The prompt itself needs no theming — its ANSI codes already render via the wildcharm terminal palette (branch yellow, dirty counts accent) |
| less / man | `LESS`/`MANPAGER` `-D` colours (`.bashrc`) | ✅ | ✅ n/a | `--use-color` `-D` classes on the palette: bold→accent red (man headers/commands), underline→blue (args), search→black-on-yellow (**matches vim's search** — less's default was black-on-bright-green), **prompt/status bar→bright-white on accent** (less's default was cyan, which clashed with the accent terminal cursor parked beside it; now matches vifm/cmus status bars), line-nums→grey, errors→bright red. (Earlier fixed a `$D` bug that had dropped the underline colour in interactive less.) **`more`** has no colour options (n/a); **`systemctl`** is already on-palette — `SYSTEMD_COLORS` only toggles colour on/off, its semantic green/red render via the terminal (n/a) |
| docker / buildkit | `BUILDKIT_COLORS` (`.bashrc`) | ✅ | 🟡 | build-log colours as exact-hex RGB triples (the var takes names or `R,G,B`): run→blue `#0087d7`, warning→yellow `#d78700`, error→accent `#d7005f`, cancel→grey `#767676` (default buildkit blue is unreadable on the dark ground). Only buildkit's output is configurable; `docker ps`/compose tables aren't — they render via the terminal palette like `systemctl` |
| zathura | key=value config | ✅ | ✅ | colours in the **GENERATED** `theme-{dark,light}` pair (render.py), `include`d by zathurarc; UI chrome + document recolour (ON on dark — pages invert to the ground; OFF on light — pages are already light; `r` toggles either way). The M7 render also fixed a latent Debian-red `rgba(206,0,86,…)` active-search highlight |
| GTK3 apps (Remmina, GIMP, FF file chooser) | recoloured adw-gtk3 theme | ✅ | ✅ | `gtk_theme` role builds **both** `hestia` (light) + `hestia-dark` (adw-gtk3 + `#d7005f`); the session picks per `theme_variant` via `GTK_THEME` in start-sway + the gsettings/settings.ini theme name (M7) |
| GTK4 / libadwaita apps (gnome-calculator, nautilus) | libadwaita | 🟡 | 🟡 | dark only — accent **locked on libadwaita 1.7** (trixie is frozen at 1.7.6); libadwaita **≥1.8** accepts an arbitrary-hex `:root { --accent-bg-color }`, which `gtk-4.0/gtk.css` already stages → exact red **auto-activates on the move to Debian 14** (forky/sid carry 1.9.1). Not a Yaru-fixable gap; see CLAUDE.md GTK section |
| Icons (app / folder / places) | Yaru (Suru) icon theme | ✅ | ✅ n/a | **`yaru_icons` role** (opt-in `enable_yaru_icons`, default off) installs **`Yaru-hestia`** into `~/.local/share/icons` as a **prebuilt** sha256-verified release artifact (`yaru-hestia-v2`; no per-machine build — the `claude` agent renders it; recipe in the role README). Folder accent **pre-compensated to `#d00043`** so Yaru's ~15% white overlay lands the front on true **`#d7265f`** (R/B exact on `#d7005f`, green floors at 38) — verified by sampling a rendered `places/folder.png`. Selected via `gtk-icon-theme-name` + the gsettings `icon-theme` key. |
| Qt / KDE apps (Kdenlive) | hestia KDE colour scheme (`kdeglobals`) | 🟡 | ✅ | **`qt_theme` role** renders the wildcharm palette as a KDE colour scheme (accent `#d7005f`) into `~/.config/kdeglobals` **and** `~/.local/share/color-schemes/Hestia.colors`. KDE-Frameworks apps read the colours directly (KColorScheme) and list the scheme (KColorSchemeManager — e.g. **Kdenlive**'s theme selector); no Kvantum, no root, no env var. Chose the colour-scheme route over Kvantum — a KDE app needs only the scheme to hit exact `#d7005f`. Kdenlive doesn't follow the system scheme on its own (it keeps its own choice in `kdenliverc [UiSettings] ColorSchemePath`), so the role also pre-selects it via `kwriteconfig6` — a fresh bootstrap comes up themed with no manual pick. **Bare-Qt (non-KDE) apps** (qBittorrent, VLC's Qt UI, …) ignore `kdeglobals` and still need a **qt6ct** platform-theme + `QT_QPA_PLATFORMTHEME` in the session (⬜) — deferred until such an app lands. Confirmed on Kdenlive 24.12 (KF6) |
| Firefox + firefoxpwa PWAs | GTK3 (via `GTK_THEME`) | ✅ | ✅ | chrome/menus/file chooser follow hestia-dark; only in-page web form controls might need `userContent` (if ever) |
| VS Code | theme extension (`user/vscode/hestia/`) | ✅ | ✅ | dark + light themes **GENERATED** by `render.py`; dark = full role-mapped UI chrome + ANSI-16 terminal, light = editor-only until the light desktop ramp (roadmap M7). Verified live on VS Code 1.127 (2026-07-03). **Bootstrap-wired**: the `vscode_theme` role packages + installs the `.vsix` on version change, self-skipping when the `code` binary is absent (VS Code itself is not in the apt manifest); manual procedure in the extension README |

Add a row when you start a new app; flip it to ✅ when it passes step 5.
