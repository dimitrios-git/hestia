# hestia

> **Reproducible, themed Debian/Sway workstation-as-code — built collaboratively by a human and an AI-as-user.**

**hestia** (Greek **Εστία** — *Hestia*, goddess of the **hearth**) is the hearth of
one personal machine: a whole **Debian + Sway (Wayland)** workstation captured as
code and rebuilt from scratch by an **Ansible bootstrap** — not just dotfiles, but
packages, system (`/etc`) configs, users, ACLs, and services. Two things make it
more than a config repo:

- **Workstation-as-code.** `git clone` + one playbook reconstructs the machine —
  the Wayland desktop, terminal tooling, a Samba-over-Tailscale share, headless
  login credential auto-unlock — converging toward a distributable Debian spin
  (`docs/repo-structure-design.md`).
- **Human + AI-as-user.** Claude Code runs as its **own unprivileged Linux user**
  (`claude`) — its own SSH key, GPG signature, and GitHub identity. It's a
  collaborator behind a **kernel-enforced** trust boundary, not a process wearing
  my account. We work through git: it opens pull requests, I review and merge.

Everything sits on one **unified theme**: dark ground `#1a1a1a`, accent **red
`#d7005f`**, and a saturated 16-colour palette derived from the `wildcharm` vim
colorscheme — defined once in `themes/hestia/palette.yml`
and applied app-by-app via the process in [`docs/theming.md`](docs/theming.md)
(terminal apps, sway, waybar, swaylock/swaynag, zathura, and a custom GTK theme).

## Configs included

User-layer configs are symlinked into `~`/`~/.config`; system configs are deployed
to `/etc` by the bootstrap (copied/templated, not symlinked).

| Directory | Tool | Deployed to |
|---|---|---|
| `user/vim/` | Vim (vim-plug, CoC, Copilot) | `~/.vimrc` |
| `user/nvim/` | Neovim (shares the Vim config) | `~/.config/nvim/` |
| `user/bash/` | Bash (prompt, aliases, vi mode) | `~/.bashrc` |
| `user/git/` | Git | `~/.gitconfig`, `~/.gitignore_global` |
| `user/gnupg/` | GPG agent + credential auto-unlock hook | `~/.gnupg/gpg-agent.conf` |
| `user/sway/` | Sway compositor | `~/.config/sway/config` |
| `user/waybar/` | Waybar status bar (+ `scripts/`) | `~/.config/waybar/` |
| `user/mako/` | Mako notifications | `~/.config/mako/config` |
| `user/wofi/` | Wofi launcher | `~/.config/wofi/` |
| `user/swaylock/` | Swaylock lockscreen | `~/.config/swaylock/config` |
| `user/swaynag/` | Swaynag dialogs (exit/warn/error) | `~/.config/swaynag/config` |
| `user/kitty/` | Kitty terminal (+ music session) | `~/.config/kitty/` |
| `user/cmus/` | cmus music player | `~/.config/cmus/rc` |
| `user/cava/` | cava audio visualiser | `~/.config/cava/config` |
| `user/vifm/` | Vifm file manager | `~/.config/vifm/` |
| `user/imv/` | imv image viewer | `~/.config/imv/config` |
| `user/zathura/` | Zathura document viewer (PDF/EPUB/…) | `~/.config/zathura/zathurarc` |
| `user/glow/` | Glow markdown renderer + theme | `~/.config/glow/` |
| `user/xdg-desktop-portal/` | Screen-sharing portal routing | `~/.config/xdg-desktop-portal/` |
| `user/gtk/` | GTK 3/4 theme settings + accent overlay | `~/.config/gtk-3.0/`, `~/.config/gtk-4.0/` |
| `user/bin/` | Helper scripts (e.g. `claude-access`) | `~/.local/bin/` |
| `user/claude/` | Claude Code config (agent user): keybindings + permission policy | `~/.claude/keybindings.json`, `~/.claude/settings.json` |
| `system/` | System configs (e.g. Samba, the Sway launcher) | `/etc/`, `/usr/local/bin/` (root, not symlinked) |
| `themes/` | Theme single-source-of-truth (`hestia/palette.yml`) | — (consumed by `docs/theming.md`) |
| `bootstrap/` | The Ansible installer + manifest | — |
| `docs/` | Design docs + the install runbook + theming guide | — |

The authoritative symlink list is the bootstrap manifest (`bootstrap/group_vars/all.yml`); CLAUDE.md's table is generated from it.

## Setup

Reproduced from scratch by an **Ansible bootstrap** (no more hand-run `ln -s`).
One entry point — `setup.sh` installs Ansible, asks a few questions (auto-detecting
sensible defaults), and runs the playbook:

```sh
sudo apt install -y git
git clone git@github.com:dimitrios-git/hestia.git ~/Development/hestia
cd ~/Development/hestia/bootstrap && ./setup.sh
```

`setup.sh` writes your answers (which features to include, LAN subnet, music dir)
to an untracked `host_vars/` file and is re-runnable. Prefer the raw playbook?
`ansible-playbook site.yml --tags dotfiles --check --diff` previews just the
symlinks; `… --ask-become-pass` does a full run. The ordered fresh-install
narrative — which role when, with the **interactive/external manual steps**
(identity keys, Samba password, …) interleaved — is
**[`docs/install-runbook.md`](docs/install-runbook.md)**.

Roles: `packages` (apt), `dotfiles` (symlinks + templated configs), `fonts` (Nerd
Fonts), `localbin` (pinned release binaries, e.g. bluetuith), `gtk_theme` (the
**hestia GTK theme** — recoloured adw-gtk3), `sway_session` (the greetd→sway
launcher), `tailscale` (the mesh VPN), `samba` (the `/etc` system layer),
`claude_user` + `credentials` (see below), `hostname` (set the machine name, when
`system_hostname` is given), plus opt-in `yaru_icons` (the `#d7005f` Yaru icon
theme) and `nvidia`. Each is idempotent — re-run with `--check` to verify.
Details: [`bootstrap/README.md`](bootstrap/README.md).

Secrets are **not** in this repo — they live in `~/.bash_secrets` (untracked), sourced by `.bashrc`.

See [CLAUDE.md](CLAUDE.md) for detailed per-tool notes and external dependencies.

## Commit signing & credential auto-unlock

Commits are **GPG-signed**, and SSH + GPG **auto-unlock at login** (headless, no
GUI): `pam_gnome_keyring` unlocks the login keyring, and a Sway hook
(`user/gnupg/credential-unlock.sh`) loads the SSH key and warms gpg-agent — so **no
per-boot `ssh-add` or `gpg-unlock`**. The GPG cache is session-length; the
security boundary is the unlocked session + screen lock. Full mechanism:
[`docs/credential-autounlock-design.md`](docs/credential-autounlock-design.md).

> Fallback only: if the cache is ever cold, `gpg-unlock` (a `.bashrc` function)
> re-warms it. It refuses to run inside Claude Code, where pinentry would seize
> the terminal — there a cold cache makes signed commits fail fast instead of
> wedging. See [CLAUDE.md](CLAUDE.md).

## Claude Code as a dedicated user

The distinctive part of hestia: Claude Code runs as its own unprivileged,
kernel-isolated **`claude`** Linux user — own SSH key, git identity, and
passwordless GPG signing, committing and pushing as a separate GitHub **bot
account** (commits show **Verified**), unable to read this account's secrets.

We collaborate **through git, as two principals**: `claude` works in its own clone
under `/srv/devshare`, opens pull requests as the bot, and I review and merge —
`main` is branch-protected so **only I can merge** (the boundary is enforced by the
platform, not by trust). Design + rationale:
[`docs/claude-user-design.md`](docs/claude-user-design.md); day-to-day workflow
(entering its context, the PR loop, sharing a project):
[`docs/working-with-claude.md`](docs/working-with-claude.md).

## Vim plugins

Install vim-plug on a fresh system, then run `:PlugInstall` inside Vim:

```sh
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

## License

Copyright (C) 2026 Dimitrios Charalampidis

hestia is free software: you can redistribute it and/or modify it under the terms
of the **GNU General Public License v3.0 or later** as published by the Free
Software Foundation — see [LICENSE](LICENSE). It is distributed in the hope that
it will be useful, but **without any warranty**; without even the implied
warranty of merchantability or fitness for a particular purpose.
