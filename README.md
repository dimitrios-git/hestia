# estia

Personal configuration files for a Debian-based Linux system running the **Sway (Wayland)** desktop.

Unified theme: near-black background `#0a0a0a`, accent **official Debian red `#ce0056`**, and a 16-colour palette derived from the `wildcharm` vim colorscheme.

## Configs included

| Directory | Tool | Symlink target |
|---|---|---|
| `vim/` | Vim (vim-plug, CoC, Copilot) | `~/.vimrc` |
| `nvim/` | Neovim (shares the Vim config) | `~/.config/nvim/` |
| `bash/` | Bash (prompt, aliases, vi mode) | `~/.bashrc` |
| `git/` | Git | `~/.gitconfig`, `~/.gitignore_global` |
| `gnupg/` | GPG agent + credential auto-unlock hook | `~/.gnupg/gpg-agent.conf` |
| `sway/` | Sway compositor | `~/.config/sway/config` |
| `waybar/` | Waybar status bar (+ `scripts/`) | `~/.config/waybar/` |
| `mako/` | Mako notifications | `~/.config/mako/config` |
| `wofi/` | Wofi launcher | `~/.config/wofi/` |
| `kitty/` | Kitty terminal (+ music session) | `~/.config/kitty/` |
| `cmus/` | cmus music player | `~/.config/cmus/rc` |
| `cava/` | cava audio visualiser | `~/.config/cava/config` |
| `vifm/` | Vifm file manager | `~/.config/vifm/` |
| `imv/` | imv image viewer | `~/.config/imv/config` |
| `glow/` | Glow markdown renderer + theme | `~/.config/glow/` |
| `xdg-desktop-portal/` | Screen-sharing portal routing | `~/.config/xdg-desktop-portal/` |
| `system/` | System configs (e.g. Samba) | copied to `/etc/` (not symlinked) |

The authoritative symlink list is the bootstrap manifest (`bootstrap/group_vars/all.yml`); CLAUDE.md's table is generated from it.

## Setup

Reproduced from scratch by an **Ansible bootstrap** (no more hand-run `ln -s`).
The ordered fresh-install narrative — which role when, with the manual steps
interleaved — is **[`docs/install-runbook.md`](docs/install-runbook.md)**. In short:

```sh
sudo apt install -y git ansible
git clone git@github.com:dimitrios-git/estia.git ~/Development/estia
cd ~/Development/estia/bootstrap
ansible-playbook site.yml --tags dotfiles --check --diff   # preview the symlinks
ansible-playbook site.yml --ask-become-pass                # full run
```

Roles: `packages` (apt), `dotfiles` (symlinks), `samba` (the `/etc` system layer),
`claude_user` + `credentials` (see below). Each is idempotent — re-run with
`--check` to verify. Details: [`bootstrap/README.md`](bootstrap/README.md).

Secrets are **not** in this repo — they live in `~/.bash_secrets` (untracked), sourced by `.bashrc`.

See [CLAUDE.md](CLAUDE.md) for detailed per-tool notes and external dependencies.

## Commit signing & credential auto-unlock

Commits are **GPG-signed**, and SSH + GPG **auto-unlock at login** (headless, no
GUI): `pam_gnome_keyring` unlocks the login keyring, and a Sway hook
(`gnupg/credential-unlock.sh`) loads the SSH key and warms gpg-agent — so **no
per-boot `ssh-add` or `gpg-unlock`**. The GPG cache is session-length; the
security boundary is the unlocked session + screen lock. Full mechanism:
[`docs/credential-autounlock-design.md`](docs/credential-autounlock-design.md).

> Fallback only: if the cache is ever cold, `gpg-unlock` (a `.bashrc` function)
> re-warms it. It refuses to run inside Claude Code, where pinentry would seize
> the terminal — there a cold cache makes signed commits fail fast instead of
> wedging. See [CLAUDE.md](CLAUDE.md).

## Claude Code as a dedicated user

Claude Code runs as its own unprivileged, kernel-isolated **`claude`** Linux user
— its own SSH key, git identity, and passwordless GPG signing, committing and
pushing as a separate GitHub bot account (commits show **Verified**), unable to
read this account's secrets. Design + rationale:
[`docs/claude-user-design.md`](docs/claude-user-design.md); day-to-day workflow
(entering its context, sharing a project):
[`docs/working-with-claude.md`](docs/working-with-claude.md).

## Vim plugins

Install vim-plug on a fresh system, then run `:PlugInstall` inside Vim:

```sh
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```
