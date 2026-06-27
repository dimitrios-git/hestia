# Theming hestia

hestia has one look: a **dark theme** on near-black `#0a0a0a`, accent **wildcharm
red `#d7005f`**, and a saturated **16-colour palette from the `wildcharm` vim
colorscheme**. This doc is the **process** for bringing a new app onto that look. The
colours themselves live in one place — **`themes/wildcharm/palette.yml`** (the single
source of truth) — so this doc never repeats hex values; it tells you how to apply them.

> **How the system works today.** The palette is applied **by hand**: you read the right
> value from `palette.yml` and write the literal hex into the app's own config, which is
> then deployed by the bootstrap (symlinked or rendered). Configs stay directly editable.
> A future Ansible/Jinja2 step could render `palette.yml` straight into configs and remove
> the hand-copying (`docs/repo-structure-design.md` §9.3) — `palette.yml` is already
> shaped for that — but that engine is **deferred**; for now, follow the steps below.

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

| App | Mechanism | Status | Notes |
|---|---|---|---|
| kitty | ANSI 16 + roles | ✅ | the canonical 16-colour definition |
| sway | `$bg/$surface/…` vars | ✅ | window borders, urgent |
| waybar | GTK CSS | ✅ | bar + tooltips |
| swaylock | key=value config | ✅ | `user/swaylock/config`; all indicator states |
| swaynag | key=value + `[type]` | ✅ | `user/swaynag/config`; exit/warning/error dialogs |
| mako | key=value config | ✅ | notifications, urgent variant |
| wofi | GTK CSS | ✅ | launcher |
| cava | gradient config | ✅ | accent-anchored cool sweep through wildcharm hues (accent → magenta → blue → cyan) |
| cmus | cterm slots (rc) | ✅ | accent tracks ANSI red |
| vifm | `.vifm` colorscheme | ✅ | file-type colours from the ANSI set, **plus per-glob `:highlight` rules mirroring `~/.dircolors`'s extension layer** (vifm has no LS_COLORS, so they're kept in sync by hand) — archives/images/video/audio/docs match `ls`; preview pane on by default (`view!`, `w` toggles); catch-all `fileviewer` runs `scripts/preview.sh` for syntax-highlighted code preview (bat, wildcharm) with binary/dir fallback; images show text info (mediainfo) — in-pane rendering was dropped (kitty graphics didn't display in vifm and made scrolling laggy); open in imv instead |
| bat | `.tmTheme` syntax theme | ✅ | `user/bat/themes/wildcharm.tmTheme` (scopes mapped from `palette.yml`); compiled into bat's cache by the dotfiles role (`bat cache --build`); drives vifm's code preview. Debian ships the binary as `batcat` |
| glow | glamour JSON | ✅ | markdown render theme |
| vim / nvim | `hestia` colorscheme (wildcharm wrapper) | ✅ | `user/vim/colors/hestia.vim` loads built-in `wildcharm` then overrides the bg to hestia near-black `#0a0a0a`; accent is wildcharm's own `#d7005f`. In `~/.vim/colors` so Vim + Neovim share it. Plus render-markdown accent (nvim) |
| ls / file listing | `dircolors` (LS_COLORS) | ✅ | `user/bash/.dircolors` — file-**type** colours mirror vifm's highlights exactly (same 256-indices: dir 39, link 44, exec 41, …) so `ls` and vifm agree; plus a restrained wildcharm extension layer (archives/images/video/audio/docs). `.bashrc` already loads it |
| zathura | key=value config | ✅ | `user/zathura/zathurarc`; UI chrome + document recolour (dark mode on, `r` toggles) |
| GTK3 apps (Remmina, GIMP, FF file chooser) | recoloured adw-gtk3 theme | ✅ | `gtk_theme` role builds `hestia-dark` (adw-gtk3 + `#d7005f`); dark + exact red |
| GTK4 / libadwaita apps (gnome-calculator, nautilus) | libadwaita | 🟡 | dark only — accent **locked on libadwaita 1.7** (trixie is frozen at 1.7.6); libadwaita **≥1.8** accepts an arbitrary-hex `:root { --accent-bg-color }`, which `gtk-4.0/gtk.css` already stages → exact red **auto-activates on the move to Debian 14** (forky/sid carry 1.9.1). Not a Yaru-fixable gap; see CLAUDE.md GTK section |
| Icons (app / folder / places) | Yaru (Suru) icon theme | ✅ | **`yaru_icons` role** (opt-in `enable_yaru_icons`, default off) installs **`Yaru-hestia`** into `~/.local/share/icons` as a **prebuilt** sha256-verified release artifact (`yaru-hestia-v2`; no per-machine build — the `claude` agent renders it; recipe in the role README). Folder accent **pre-compensated to `#d00043`** so Yaru's ~15% white overlay lands the front on true **`#d7265f`** (R/B exact on `#d7005f`, green floors at 38) — verified by sampling a rendered `places/folder.png`. Selected via `gtk-icon-theme-name` + the gsettings `icon-theme` key. |
| Qt / KDE apps | Kvantum / `kdeglobals` | ⬜ | the Qt companion to Adwaita — **Kvantum** is the custom-`#d7005f`-accent route (or a recoloured Breeze); separate track, later |
| Firefox + firefoxpwa PWAs | GTK3 (via `GTK_THEME`) | ✅ | chrome/menus/file chooser follow hestia-dark; only in-page web form controls might need `userContent` (if ever) |

Add a row when you start a new app; flip it to ✅ when it passes step 5.
