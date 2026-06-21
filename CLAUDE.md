# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

Personal dotfiles for a Debian-based Linux system running the **Sway (Wayland)** desktop. No build system, no tests, no linting — changes take effect by editing the files directly (the active ones are symlinked into `~` / `~/.config`). Reproducing the machine from scratch is driven by an **Ansible bootstrap** (`bootstrap/`, now five roles — see *Bootstrap & system reproduction*); the ordered fresh-install runbook is `docs/install-runbook.md`.

The repo is growing from *one person's dotfiles* toward a **reproducible Debian spin** with multiple principals and `/etc` system configs; the target layered structure is `docs/repo-structure-design.md` (phased, not yet migrated).

The configs are converging on one unified theme: near-black background `#0a0a0a`, accent **official Debian red `#ce0056`** (PANTONE Strong Red C), and a saturated 16-colour palette derived from the **`wildcharm`** vim colorscheme. Keep new theming consistent with this.

## Running as the `claude` agent user

Claude Code runs here as a dedicated, unprivileged **`claude`** Linux user (own `0700` home `/home/claude`, member of the **`devshare`** group, **not** in sudo) — a kernel-enforced trust boundary, not a behavioural one. Full design: `docs/claude-user-design.md` (implemented 2026-06-20); day-to-day workflow: `docs/working-with-claude.md`. What matters when working in this repo:

- **This checkout (`/srv/devshare/estia`) is claude's own clone** in the shared `/srv/devshare` tree — claude's *workspace*, **not** the live system. The dotfiles are symlinked from **dimitrios's** clone at **`~/Development/estia`**, which is the deployment source. Edits made here reach the running system only when **dimitrios pulls** after reviewing a pushed branch — so an edit here is **not** live. Never treat `/srv/devshare/estia` as the deployment source. (Any `/home/dimitrios/...` literals still left in configs — currently `waybar/gpu.sh`'s exec path and cmus's music dir — target dimitrios's deployment clone, not this one; they're being path-generalised per `docs/repo-structure-design.md` §5.)
- **Collaboration is git-mediated, two principals.** claude commits and signs as **itself**, pushes a topic branch, and opens a **pull request** as the GitHub bot **`dimitrios-claude`** (`gh pr create`; commits show **Verified**); dimitrios reviews, **merge-commits** (preserves the signed commits; via `gh pr merge --admin`), and pulls to deploy. claude **never** self-merges — and *cannot*: a `main` ruleset (*Restrict updates*, admin-only bypass) blocks the agent from pushing to or merging `main` server-side, so its only route is opening a PR. The concrete loop (and the `gh`/PAT auth) is in `docs/working-with-claude.md`.
- **claude's identity:** own SSH key `~/.ssh/id_claude`, own **passwordless** GPG key `4AA9DD310356AD0E`, git author `Claude (dimitrios's agent) <claude@charalampidis.pro>`.
- **Signing is frictionless for claude** — the passwordless key needs **no pinentry, no agent cache, no `gpg-unlock`, and not `gpg-wrapper.sh`**. All that machinery in *Secrets & commit signing* below is **dimitrios's**; it does not apply when running as claude.
- **Isolation:** claude **cannot** read dimitrios's home, `~/.ssh`, `~/.gnupg`, or `~/.bash_secrets` (different UID; `0750`/`0700`/`0600`). Confirm any time: `ls ~dimitrios` → Permission denied.
- **`bin/claude-access`** (`grant|revoke|list`, symlinked to `~/.local/bin/`) is the escape hatch to give claude ACL access to a path **outside** `/srv/devshare` (e.g. a project in the human's home), with a tracked registry. Prefer the clone-and-sync model; reach for it only when in-place editing is truly needed.
- **claude can install its own user-level tooling.** Because `claude` is a separate user with its own `/home/claude`, it can freely install whatever a task needs **into its own home** — npm/pip `--user`, cargo, a downloaded binary into `~/.local/bin`, etc. — without `sudo` and without touching dimitrios's environment. (System-wide `apt` installs still need the human; those stay dimitrios's job.)

## File layout and naming convention

Each tool has its own subdirectory. Active configs are either:
- **Dot-prefixed** in the repo, symlinked into `$HOME` — `vim/.vimrc` → `~/.vimrc`, `bash/.bashrc` → `~/.bashrc`, `git/.gitignore_global` → `~/.gitignore_global`.
- **Plain files under the app dir**, symlinked into `~/.config/<app>/` — sway, waybar, mako, wofi, cava, cmus, kitty, imv, vifm, glow (`wildcharm.json`), nvim, xdg-desktop-portal.
- **Rendered (not symlinked)** — a small **path-generalised** set rendered from `.j2` by the bootstrap (`git/.gitconfig`, `glow/glow.yml`); see *Rendered (templated) configs* below.
- **`bin/`** — small helper scripts symlinked into `~/.local/bin/` (currently `claude-access`; see *Running as the `claude` agent user*).
- **`system/`** — layer-(a) **system configs** (e.g. `system/samba/smb.conf`) deployed by **copy** to `/etc/` (root-owned, **not** symlinked), now driven by the `samba` Ansible role. The target four-layer model (system / defaults / per-user) is `docs/repo-structure-design.md`; each `system/` subdir keeps a `README.md` runbook.
- **`bootstrap/`**, **`docs/`** — the Ansible installer + the design docs/runbooks (cross-cutting, not a per-tool config).

Two `/srv` trees live outside the repo but are part of the setup: **`/srv/devshare`** (the human↔`claude` shared dev tree — group `devshare`, setgid + default ACLs; this clone lives here) and **`/srv/smbshare`** (the Samba share — group `smbshare`; `docs/file-sharing-design.md`).

### Active symlinks

_Generated from the bootstrap manifest (`bootstrap/group_vars/all.yml`) — **do not edit by hand**; run `bootstrap/gen-symlink-table.py` after changing `dotfile_links` or `templated_configs` (it regenerates both this table and the rendered-templates one below)._

<!-- BEGIN active-symlinks (generated from bootstrap/group_vars/all.yml by bootstrap/gen-symlink-table.py — do not edit by hand) -->
| Repo file | Symlinked to |
|---|---|
| `vim/.vimrc` | `~/.vimrc` |
| `bash/.bashrc` | `~/.bashrc` |
| `git/.gitignore_global` | `~/.gitignore_global` |
| `gnupg/gpg-agent.conf` | `~/.gnupg/gpg-agent.conf` |
| `nvim/init.vim` | `~/.config/nvim/init.vim` |
| `nvim/lua/trees.lua` | `~/.config/nvim/lua/trees.lua` |
| `sway/config` | `~/.config/sway/config` |
| `waybar/config` | `~/.config/waybar/config` |
| `waybar/style.css` | `~/.config/waybar/style.css` |
| `mako/config` | `~/.config/mako/config` |
| `wofi/config` | `~/.config/wofi/config` |
| `wofi/style.css` | `~/.config/wofi/style.css` |
| `cava/config` | `~/.config/cava/config` |
| `cmus/rc` | `~/.config/cmus/rc` |
| `kitty/kitty.conf` | `~/.config/kitty/kitty.conf` |
| `kitty/music.session` | `~/.config/kitty/music.session` |
| `imv/config` | `~/.config/imv/config` |
| `vifm/vifmrc` | `~/.config/vifm/vifmrc` |
| `vifm/colors/wildcharm.vifm` | `~/.config/vifm/colors/wildcharm.vifm` |
| `glow/wildcharm.json` | `~/.config/glow/wildcharm.json` |
| `xdg-desktop-portal/sway-portals.conf` | `~/.config/xdg-desktop-portal/sway-portals.conf` |
| `bin/claude-access` | `~/.local/bin/claude-access` |
<!-- END active-symlinks -->

### Rendered (templated) configs

_Path-generalised configs (`docs/repo-structure-design.md` §5): rendered from a `.j2` by the `dotfiles` role instead of symlinked, so no `/home/<user>` literal is baked in (direct-edit is lost for these — keep the set small). Generated from the manifest's `templated_configs` — **do not edit by hand**; run `bootstrap/gen-symlink-table.py`._

<!-- BEGIN rendered-templates (generated from bootstrap/group_vars/all.yml by bootstrap/gen-symlink-table.py — do not edit by hand) -->
| Repo template | Rendered to |
|---|---|
| `git/.gitconfig.j2` | `~/.gitconfig` |
| `glow/glow.yml.j2` | `~/.config/glow/glow.yml` |
<!-- END rendered-templates -->

`git/.gitconfig` points the global excludes file at `~/.gitignore_global`.

## Secrets & commit signing

> This section describes **dimitrios's** interactive setup (the passphrase-protected key + the pinentry-wedge machinery built around it). When running as the **`claude`** user, signing is **passwordless** and none of the wrapper / cache / `gpg-unlock` flow applies — see *Running as the `claude` agent user*.

- **Secrets** (API tokens, etc.) live in **`~/.bash_secrets`** — untracked, mode 600, sourced at the end of `bash/.bashrc`. Never commit secret values; a bootstrap script must not carry this file.
- **Commits are GPG-signed** (key `EB90A5A2D628F2A6`). Signing is routed through **`git/gpg-wrapper.sh`** (set as `gpg.program` in `git/.gitconfig.j2`, templated from `{{ repo_root }}` so it follows the clone — no manual update on move). In a normal terminal it execs `gpg` untouched, using **`pinentry-tty`** (configured in **`gnupg/gpg-agent.conf`**, symlinked to `~/.gnupg/`) with a **~session-length cache TTL** (`34560000`) — because login auto-unlock (below) warms the agent at login, so the security boundary is the unlocked session + screen lock, not the TTL; GPG now matches ssh-agent's persist-until-logout.
- **Why the wrapper:** inside Claude Code (`$CLAUDECODE` set) gpg-agent would launch pinentry on `GPG_TTY` — which is Claude's own terminal (`/dev/pts/0`), **not** the calling process's stdin — and **seize it** (you can't type the passphrase or control the prompt; `pinentry-tty` does *not* avoid this, the tty takeover is the problem). So under `$CLAUDECODE` the wrapper adds `--pinentry-mode error`: a **warm** cache signs silently, a **cold** cache fails fast (`gpg: signing failed: No pinentry`, exit 2) instead of wedging. When a harness commit fails this way, run **`gpg-unlock`** (a `bash/.bashrc` function — signs a throwaway message so gpg-agent prompts once via pinentry-tty; reads the key from git config, so no hash to remember; refuses to run under `$CLAUDECODE`) in a normal terminal, then the harness can sign again within the cache window.
- **Bootstrap / pinentry default:** the tracked `gpg-agent.conf` forces `pinentry-tty` per-agent, but the *system* `pinentry` alternative defaults to **`pinentry-curses`** (leaks mouse-tracking escape codes). Pin it belt-and-suspenders with `sudo update-alternatives --set pinentry /usr/bin/pinentry-tty`. Avoid `pinentry-curses` and `pinentry-gnome3` (the latter falls back to curses outside GNOME).
- **Login auto-unlock (SSH + GPG):** `pam_gnome_keyring` unlocks the gnome-keyring login keyring at login; the Sway-`exec` hook **`gnupg/credential-unlock.sh`** then loads the SSH key (via an SSH_ASKPASS helper reading the keyring) and warms gpg-agent (loopback sign), so **no per-boot `ssh-add`/`gpg-unlock`** — including for the harness. Passphrases live in the keyring (`secret-tool store … autounlock ssh/gpg …`). Full story incl. the gnome-keyring launcher-untangle needed to make PAM the sole unlocker: `docs/credential-autounlock-design.md` §10. The wrapper + `gpg-unlock` remain as fail-clean fallbacks for a cold cache.

## Bootstrap & system reproduction (`bootstrap/`)

A fresh machine is reproduced by an **Ansible** playbook (engine decision: `docs/repo-structure-design.md`). The ordered start-to-finish narrative — which role when, with the interactive/external manual steps interleaved — is **`docs/install-runbook.md`**; the per-role reference is `bootstrap/README.md`.

- **Single source of truth: `bootstrap/group_vars/all.yml`** — the manifest listing every dotfile symlink (`dotfile_links`) and the apt package set (`apt_packages`). The "Active symlinks" table above is **generated** from it by `bootstrap/gen-symlink-table.py`; run that after editing `dotfile_links` rather than hand-editing the table.
- **Per-host personal values** (e.g. the Samba `samba_lan_subnet`) live in an **untracked** `bootstrap/host_vars/<inventory_host>.yml` (template: the committed `…example`), kept out of this public repo by `.gitignore`. Ansible auto-loads it; role defaults carry RFC 5737 placeholders so a checkout is runnable without it.
- **Roles** (`bootstrap/site.yml`, sliceable by `--tags`): `packages` (apt), `dotfiles` (symlink the manifest into `$HOME`, no root), `samba` (layer-(a) `/etc/samba/smb.conf` + `/srv/smbshare` share), `claude_user` (the `claude` user + `devshare` group + shared tree + repo ACLs — the *plumbing*; identity is manual), `credentials` (gnome-keyring launcher-untangle for login auto-unlock). Each is idempotent — re-run with `--check` to verify `changed=0`.
- **Deliberately NOT Ansible-managed** (interactive, secret-handling, vendor, or per-user — all in the runbook): the NVIDIA driver, NVM/Node, vim-plug + `:PlugInstall`, Nerd Fonts, the bluetuith binary, Claude Code itself; the `smbpasswd` Windows password; claude's identity keys + GitHub bot; the keyring/passphrase storage for credential auto-unlock.
- **Samba share** (`system/samba/smb.conf.j2`, `docs/file-sharing-design.md`): SMB-over-Tailscale to a Windows laptop, POSIX-ACL permission model. The `samba` role **renders** the template (LAN subnet from host_vars) → `/etc/samba/smb.conf`. smbd listens on all interfaces (Samba 4.22 can't bind the Tailscale tun); access is confined at the SMB layer by `hosts allow/deny` (loopback + home LAN + Tailscale range) + SMB3 floor + a `nologin` `smbshare` principal.

## TODO / planned work

- **Repo → distributable spin roadmap.** The whole arc — path generalisation (remaining: `waybar/gpu.sh` exec path, cmus music dir), role feature-flags + a configurable installer, and the layered `users/`/`defaults/` migration — is tracked in **`docs/repo-structure-design.md` §5–§7** (the single source; don't re-list it here). Phased on purpose — don't big-bang the structural move. Done so far: Samba LAN subnet (host_vars), **glow's style path**, and **git config** (`git/.gitconfig.j2` — `gpg.program` from `repo_root`, `excludesfile` via git-native `~`) — all in the manifest's `templated_configs`.
- **Version-control systemd user services.** Other user services worth reproducing on a fresh install live only in `~/.config/systemd/user/` and aren't tracked here yet. Bring them into the repo under a `systemd/` dir, symlinked into `~/.config/systemd/user/`, and add them to the bootstrap manifest (`bootstrap/group_vars/all.yml` → `dotfile_links`; the Active symlinks table regenerates from it). (`ssh-agent` is **not** one of these — it uses Debian's shipped socket-activated unit, nothing custom; see the Bash section.)

## Tool configurations

### Vim (`vim/.vimrc`)
Uses **vim-plug** for plugins. To install plug.vim on a fresh system:
```sh
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```
Then open Vim and run `:PlugInstall`. CoC extensions install automatically via `g:coc_global_extensions`. The config targets both Vim and Neovim — some plugins are conditional on `has('nvim')`.

Key plugins: `coc.nvim` (LSP/completion), `ctrlp.vim` (fuzzy finder), `vim-fugitive` (git), `copilot.vim` (requires Vim ≥ 9.0.0185), NERDTree. Theme: `wildcharm` (dark).

**Markdown viewing** — three layers:
- `:Glow` (or `<leader>md` = `\md`, markdown buffers only) renders the current file in **glow** as a full-screen pager in the **same terminal** (suspends Vim until `q`, like vifm), via `:!glow -p %`. Works in **both Vim and Neovim** — this is the plain-Vim path. Calls `GlowPreview()`; glow gets a real TTY so theming comes from `~/.config/glow/glow.yml` (see Glow section).
- `render-markdown.nvim` — live **in-buffer** rendering, **Neovim only** (needs treesitter/Lua, absent in plain Vim). Set up in a `has('nvim')` Lua block; headings themed to `#ce0056`. Dormant until `:PlugInstall`.
- `markdown-preview.nvim` — browser-tab live preview, **Neovim only**; kept as the escape hatch for diagrams/math.

### Neovim (`nvim/init.vim`, `nvim/lua/trees.lua`)
Neovim **shares the Vim config** rather than duplicating it. `init.vim` prepends `~/.vim` to `runtimepath` (so `plug.vim` in `~/.vim/autoload` and plugins in `~/.vim/plugged` are reused) and then `source`s `~/.vimrc`. The `has('nvim')` branches in `.vimrc` then activate the Neovim-only plugins (`render-markdown.nvim`, `markdown-preview.nvim`) and `lua require('trees')` (treesitter config in `nvim/lua/trees.lua`).

Fresh-install steps (Debian trixie ships **0.10.4**, recent enough — `apt install neovim`, package is `neovim`, binary is `nvim`):
1. `nvim` → `:PlugInstall` (fetches the nvim-only plugins into the shared `~/.vim/plugged`; `markdown-preview.nvim` runs `npm install`, so Node/NVM must be loaded).
2. Treesitter parsers compile on first run — needs a **C compiler** (`gcc`). `:TSUpdate` if any fail.
3. Open a `.md` file: `render-markdown.nvim` renders in-buffer (headings themed `#ce0056`); `:Glow` still works as the shared full-screen pager.

### Bash (`bash/.bashrc`)
- Vi mode (`set -o vi`); git-aware prompt (cwd, branch, staged/unstaged/untracked counts, exit-status colour).
- Loads **NVM** on startup. Sets `GPG_TTY=$(tty)` (needed for terminal GPG signing) and prepends `~/.local/bin` to `PATH` (guarded against duplicate entries).
- **`gpg-unlock`** function: caches the GPG signing passphrase for the session (prompts once via pinentry-tty), so a cold cache stops failing harness commits. Reads the key from git config; refuses to run under `$CLAUDECODE`. See the signing section.
- **SSH agent:** exports `SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/openssh_agent"`. The agent itself is **Debian's shipped socket-activated user unit** (`/usr/lib/systemd/user/ssh-agent.socket`, already `enable`d — auto-starts on login); we deliberately use that rather than a custom unit. greetd doesn't source `.bashrc`, so this export covers interactive shells (terminals, Ansible). The SSH key is now **auto-loaded at login** by the credential-unlock hook (see the signing section), reading the passphrase from the gnome-keyring login keyring — so no per-boot `ssh-add`. It persists the whole session. (Fallback if the hook ever doesn't run: `ssh-add ~/.ssh/id_dimitrios`.)
- Sources **`~/.bash_secrets`** for secrets (see above).
- No Rust: a previous `curl … | sh` rustup auto-installer block was removed (it could silently reinstall on shell startup). Install toolchains explicitly, never from `.bashrc`.

### Vifm (`vifm/vifmrc`)
Wayland-first file manager. Images → `imv-wayland`, video → `mpv`, PDFs → `zathura`, office docs → `libreoffice`, **Markdown** → **glow** (`:file` offers "Edit in vim"). **Audio** opens in **cmus** (`cmus-remote -f`, play-now) and falls back to `mpv --no-video` when cmus isn't running; `:file` offers queue / mpv alternatives. Preview pane (`w`) uses `chafa` / `pdftotext` / `mediainfo` / `glow` (markdown). Clipboard yank (`yd`/`yf`) uses `wl-copy`. Comment syntax is `"` (vim-style).

The markdown **preview-pane** call passes `-s ~/.config/glow/wildcharm.json` explicitly: glow drops colour when its output is piped (notty mode), so the style must be forced through the pipe. The full-screen **open** action (`glow -p`) runs in a real TTY and picks up the default style from `glow.yml`.

### Glow (`glow/glow.yml.j2`, `glow/wildcharm.json`)
Terminal Markdown renderer (apt: `glow`). Used by Vim (`:Glow`/`<leader>md`) and vifm (open + preview).
- `glow.yml` sets the default `style:` to `wildcharm.json` **by absolute path** — glow can't expand `~`/`$VARS` there. So it's **path-generalised** (not symlinked): the repo carries `glow/glow.yml.j2`, and the `dotfiles` role renders it to `~/.config/glow/glow.yml` with the path templated from `{{ target_home }}` (`docs/repo-structure-design.md` §5; edit the `.j2` + re-run the role to apply). `waybar/gpu.sh`'s absolute path is the same kind of hardcode, still pending the same treatment.
- `wildcharm.json` is a **glamour** style file on the unified theme: H1 is a white-on-`#ce0056` banner, H2 accent red, H3–H6 lighter pink `#f06ba0`, `hr`/links/code accent-tinted, code blocks on `#1a1a1a` with a saturated chroma syntax palette.
- **notty caveat:** glow renders **without colour when piped** (e.g. vifm's preview pane), so consumers that pipe must pass `-s <style>` explicitly to force it; a real TTY (the floatterm, full-screen vifm open) uses the `glow.yml` default automatically.

### imv (`imv/config`)
Minimal image viewer config — shrink-to-fit scaling, vim-style `hjkl`/`np` navigation, `HJKL` to pan when zoomed.

### Git (`git/`)
Default branch `main`, editor `vim`, commits GPG-signed. Global excludes at `~/.gitignore_global` (`git/.gitignore_global`, symlinked): the Claude `settings.local.json` and common macOS/Node/Vim/VS Code artefacts. It deliberately does **not** exclude `.gitignore`/`.editorconfig` — those are meant to be committed and shared per-repo, and a global exclude only applies on this machine so it wouldn't travel to clones/collaborators/CI anyway. Rule of thumb: only *never-commit-anywhere* noise goes in the global file; project ignores belong in a committed `.gitignore` (e.g. this repo's, protecting `bootstrap/host_vars/*.yml`); "just this clone" ignores go in `.git/info/exclude`. `core.excludesfile` uses git-native `~` expansion (`~/.gitignore_global`), and the gitconfig is **rendered** (`git/.gitconfig.j2`, not symlinked) so `gpg.program` templates from `{{ repo_root }}` — neither needs a manual edit on a home/repo move (`docs/repo-structure-design.md` §5). No HTTPS credential helper is configured — auth is over SSH (`git@github.com`), so an HTTPS remote would simply prompt; add `helper = cache` for an in-memory, no-plaintext fallback if ever needed (avoid `helper = store`, which writes plaintext to `~/.git-credentials`). The local `file://` transport is left at Git's CVE-2022-39253-safe default (`protocol.file = user`); if a local-submodule operation ever needs it, scope it per-command with `git -c protocol.file.allow=always …` rather than enabling it globally.

### Sway (`sway/config`)
Wayland compositor config. Notable points:
- **Keyboard** (`input type:keyboard`): `xkb_layout "us,de,gr,bg"` + `xkb_variant ",,,phonetic"` — Bulgarian uses the **traditional phonetic** variant (W → в); commas align variants to layouts. `xkb_options caps:super,grp:alt_shift_toggle` — Caps Lock = Super, **Alt+Shift** cycles layouts.
- **Gaps:** `gaps inner 8` with `gaps top -8` to cancel the gutter under Waybar so tiled windows sit flush (other edges keep the gap). `swaymsg reload` updates gap *defaults* but does **not** re-apply to existing workspaces — apply live with `swaymsg -- gaps top all set -8` (note the `--`, or swaymsg reads `-8` as a flag), or restart sway.
- **XWayland:** `xwayland enable` (needs the `xwayland` package). Changing it requires a **full sway restart**, not a reload.
- `for_window [app_id="floatterm"] floating enable, resize set 800 600` makes Waybar widget popups (`kitty --class floatterm -e <tui>`) open floating.
- **Screen-sharing env export:** `exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE` pushes the session env into the D-Bus/systemd user activation environment so `xdg-desktop-portal` activates with the right context. Required for screen sharing — see the **Screen sharing** section. `exec` (not `exec_always`) runs once at login; it does **not** re-run on `swaymsg reload`, so apply live after editing with the same command.

Apply most config changes with `swaymsg reload`.

### Screen sharing / xdg-desktop-portal (`xdg-desktop-portal/sway-portals.conf`)
Wayland screen sharing (Teams/Edge, OBS, etc.) goes through **PipeWire** + **xdg-desktop-portal**. On Sway the screencast backend is **`xdg-desktop-portal-wlr`** (wlroots); other portal interfaces (file picker, settings) fall to **`xdg-desktop-portal-gtk`**.

- **`sway-portals.conf`** routes interfaces per backend (matched to this session via `XDG_CURRENT_DESKTOP=sway`): `ScreenCast`/`Screenshot` → `wlr`, everything else `default=gtk`. Without explicit routing the portal can misroute screencast to gtk (which can't capture on wlroots) and silently fail. If gtk is ever uninstalled, the `default` must change (wlr only implements ScreenCast/Screenshot — no file picker).
- **Session env:** the portal must inherit `WAYLAND_DISPLAY`/`XDG_CURRENT_DESKTOP` via the Sway `dbus-update-activation-environment` exec line (see Sway section). The portal is **D-Bus-activated on demand** (first screencast request), so the env must be exported *before* it first activates — a fresh login handles this.
- **Monitor-only capture:** the wlr backend reports `AvailableSourceTypes=1` (MONITOR only) — **per-window sharing is not supported** on Sway; share a whole output. Workaround: isolate the app on the second monitor and share that output. May change once the `wlr` portal adopts `ext-image-copy-capture` toplevel sources.
- **Dark mode (color-scheme):** the gtk backend exposes `org.freedesktop.appearance color-scheme` via the **Settings** portal, which Firefox and other portal-aware apps read. Force dark with `gsettings set org.gnome.desktop.interface color-scheme prefer-dark` (needs `dconf-cli` + `libglib2.0-bin`); without it the portal reports `0` (no preference) and apps default to **light**. This surfaced right after the portal was first installed — Firefox flipped to a light theme until the setting was applied.

**External dependencies** (install on a fresh system):
- `pipewire`, `pipewire-pulse`, `wireplumber` (usually present; the audio stack).
- `xdg-desktop-portal` + `xdg-desktop-portal-wlr` (screencast) + `xdg-desktop-portal-gtk` (file picker/other portals).
- `dbus-bin` provides `dbus-update-activation-environment` (used by the Sway env-export exec line).

### Waybar (`waybar/config`, `waybar/style.css`, `waybar/scripts/`)
Top bar; files symlinked into `~/.config/waybar/`. Reload with `killall -SIGUSR2 waybar` (or `killall waybar; waybar &`).

**Single launcher + boot race:** waybar is started by sway's `exec_always sway/start-waybar.sh` and must be the *sole* launcher. Two boot problems, two fixes: (1) a globally-enabled `waybar.service` user unit double-started it — disabled with `sudo systemctl --global disable waybar.service`; (2) even solo, waybar launched before the compositor could map its layer-shell surface, so the bar didn't render until a `$mod+Shift+c` reload. `sway/start-waybar.sh` fixes (2) — it kills any instance, settles, and waits for an active output before `exec waybar`. (The session is greetd-launched, not systemd-managed, so a `graphical-session.target`-ordered user service isn't an option without extra plumbing.)

- **Font:** `BigBlueTerm437 Nerd Font Mono` at 16px (`style.css`). Bitmap-derived — keep sizes at integer pixel-grid values (16/24/32) for crispness.
- **Icon alignment:** module icons are wrapped in inline Pango markup `<span size='xx-large' rise='-3072'>…</span>`. The `rise` is a hand-tuned vertical offset (Pango units, 1/1024 pt); re-tune if the font changes.
- **PUA glyph caveat:** editing tools can silently strip Private-Use-Area (Nerd Font) glyphs, leaving an empty `<span></span>`. If an icon renders as blank space, insert the codepoint via a small Python write and verify, rather than re-typing it.
- **Modules** (right side): `cpu`, `memory`, `custom/gpu`, `power-profiles-daemon`, `pulseaudio`, `sway/language`, `network`, `bluetooth`, `clock`, `custom/debian`. Right-side modules share styling via a grouped CSS selector — add new ones to that group.
- **Click handlers** open floating TUIs as toggles (`pgrep … && pkill … || kitty --class floatterm -e …`) so a second click closes the popup:
  - `network` → `nmtui`; ethernet shows the icon only (device name/IP in the tooltip).
  - `bluetooth` → `bluetuith`; right-click toggles the radio via `rfkill`.
  - `power-profiles-daemon` → left-click cycles profiles natively.
  - `custom/gpu` → toggles `watch -n 1 nvidia-smi` in a floatterm.
- **`custom/gpu`** is backed by `waybar/scripts/gpu.sh` (runs `nvidia-smi`, emits JSON): utilisation % + icon in the bar, card name / temp / VRAM in the tooltip. Referenced by **absolute path** in `exec` (update if the repo moves). **NVIDIA-only and self-hiding:** the script guards on `command -v nvidia-smi` and prints nothing when it (or a card) is absent, so Waybar hides the whole module — icon included — on non-NVIDIA hosts, keeping the config portable. AMD/Intel aren't supported (different tooling: `amdgpu_top`/sysfs, `intel_gpu_top`); making the script vendor-agnostic under the same `custom/gpu` id is a possible future extension.
- **`custom/debian`** is a decorative Debian swirl pinned at the far right (accent red), non-interactive.

**External dependencies** (install on a fresh system):
- `network`: NetworkManager (`nmtui`, `nmcli`) — usually present.
- `bluetooth`: `bluez` (apt) + `bluetuith` (not in apt; binary in `~/.local/bin` from the [bluetuith releases](https://github.com/bluetuith-org/bluetuith/releases)). `systemctl enable --now bluetooth`.
- `power-profiles-daemon`: apt package; `systemctl enable --now power-profiles-daemon`. Works with the `amd-pstate-epp` cpufreq driver (power-saver/balanced/performance). The module hides itself if the daemon's dbus name is absent.
- `custom/gpu`: `nvidia-smi` (NVIDIA driver) + `watch` for the click handler.
- Fonts (`BigBlueTerm437` / `Lilex` Nerd Font) live in `~/.local/share/fonts/`; run `fc-cache -f` after adding.

### Kitty (`kitty/kitty.conf`, `kitty/music.session`)
Terminal. Font `Lilex Nerd Font Mono` at 11pt; `ctrl+shift+=/-/0` adjust size. **Color emoji** (e.g. `✅` in program output) need **`fonts-noto-color-emoji`** (apt) — Nerd Fonts don't carry the Unicode emoji set, so without it emoji render as tofu (double-width empty boxes). kitty reaches it via fontconfig fallback and is presentation-aware (text glyphs like `✓`/`✗` stay in the primary font), so **no `symbol_map`** is set — a broad one would wrongly force those text symbols into the emoji font. 16-colour palette from `wildcharm`; cursor/selection/active-tab/ANSI-red use accent `#ce0056`. `music.session` (bound to `$mod+m` in Sway) lays out **cava** as a short visualiser bar on top and **cmus** below (focused via the `focus` directive); the cmus launch is wrapped so quitting cmus also closes cava, tearing down the whole window.

### cmus (`cmus/rc`)
Startup commands sourced after cmus restores its saved options. wildcharm-matched 256-colour theme; accent tracks terminal colour `1` (`#ce0056`). The file browser opens at `/mnt/cold-data/files/Music/Audio/`. The library is **not** auto-synced: `U` re-scans that folder for newly added tracks (re-add, dedupes), `u` = `update-cache` (prune deleted / refresh changed tags).

### cava (`cava/config`)
Spectrum visualiser. PipeWire input (monitor of the default sink). 8-stop accent gradient in the `#ce0056` family, fine bars (`bar_width 1` / `bar_spacing 0`), `noise_reduction = 88` (int 0–100 scale) + `monstercat` smoothing. A `method = sdl` GPU window (smooth pixel bars + GLSL shaders) is available — cava here is built with SDL2 — if a fancier visualiser is ever wanted.

### mako (`mako/config`) / wofi (`wofi/config`, `wofi/style.css`)
Notification daemon and app launcher (`$mod+d`), both on the unified `#0a0a0a` / `#ce0056` theme. Reload mako with `makoctl reload`; wofi restyles on next launch.
