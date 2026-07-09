# Bootstrap (Ansible)

Reproduces this machine from the dotfiles repo on a fresh Debian (Sway) install.
Engine + manifest decision: `../docs/repo-structure-design.md`.

**For a fresh install, follow `../docs/install-runbook.md`** — the ordered
start-to-finish narrative (which role when + the manual steps interleaved). This
file is the per-role reference.

**Status: growing.** Implemented: `packages` (apt), `dotfiles` (symlinks from the
manifest), `fonts` (Nerd Fonts → `~/.local/share/fonts`), `localbin` (pinned prebuilt
release binaries → `~/.local/bin`: bluetuith, hcloud, tofu/OpenTofu, cf-terraforming), `gtk_theme` (the hestia GTK3 theme
— recoloured adw-gtk3 → `~/.local/share/themes/hestia[-dark]`), `sway_session` (the
`/usr/local/bin/start-sway` launcher — NVIDIA flags applied only when an NVIDIA GPU is
live), `tailscale` (the Tailscale mesh VPN from its own apt repo — `tailscale up` stays
manual), `samba` (the layer-(a)
Samba share — adds the Tailscale range to `hosts allow` only when `enable_tailscale` is also on), `claude_user`
(the dedicated agent user + shared trees + repo ACLs + claude's local identity —
keys + git config; only the GitHub onboarding stays manual, below), `credentials`
(the gnome-keyring launcher-untangle for login auto-unlock of SSH + GPG), and the
opt-in `nvidia` (proprietary driver from non-free — default off, needs a reboot).

## Layout

```
bootstrap/
  setup.sh              # ONE-SHOT ENTRY POINT — installs Ansible, asks questions, runs the playbook
  site.yml              # top-level playbook
  ansible.cfg           # inventory + roles_path
  inventory.ini         # localhost, local connection
  group_vars/all.yml    # THE MANIFEST — toggles + packages + dotfile symlinks + templated configs + paths
  host_vars/            # per-host answers (localhost.yml — untracked; .example committed)
  local.yml.example     # template for the untracked local.yml personalization seam (docs/personalizing.md)
  roles/
    packages/           # apt install (become)
    dotfiles/           # symlink plain configs + render templated_configs into $HOME (no root)
    fonts/              # Nerd Fonts (Lilex, BigBlueTermPlus) into ~/.local/share/fonts (no root)
    localbin/           # pinned GitHub-release binaries (bluetuith, hcloud, tofu) into ~/.local/bin (no root)
    gtk_theme/          # hestia GTK3 theme: recoloured adw-gtk3 into ~/.local/share/themes (no root)
    yaru_icons/         # opt-in: install the prebuilt #d7005f Yaru icon theme into ~/.local/share/icons (sha256 download, no root)
    sway_session/       # deploy system/sway-session/start-sway -> /usr/local/bin (become)
    tailscale/          # Tailscale mesh VPN from its own apt repo (become; `tailscale up` manual)
    samba/              # Samba share: /etc/samba/smb.conf + /srv/smbshare (become)
    claude_user/        # `claude` agent user + /srv/devshare + /srv/clipshare + ACLs + identity (keys, git config) (become)
    credentials/        # login auto-unlock: gnome-keyring launcher-untangle (become)
    nvidia/             # opt-in proprietary NVIDIA driver from non-free, backports by default for explicit sync (become; default off)
  gen-symlink-table.py  # regenerate CLAUDE.md's symlink + rendered-template tables from the manifest
```

## Use

**Easiest — `setup.sh`** (installs Ansible if missing, asks a few questions with
auto-detected defaults, writes `host_vars/localhost.yml`, runs the playbook;
re-runnable, and passes extra args through to `ansible-playbook`):

```sh
cd bootstrap && ./setup.sh
./setup.sh --help                      # flags + usage
./setup.sh --check --diff              # true DRY-RUN: preview everything, change nothing
./setup.sh --no-backup                 # don't back up configs it replaces
./setup.sh --yes                       # reuse saved answers, skip Q&A (resume a failed run)
./setup.sh --tags dotfiles --check     # preview just the dotfiles re-link
```

`setup.sh`'s own flags are **`--no-backup`** (skip backing up replaced configs —
i.e. `-e dotfiles_backup=false`), **`-y`/`--yes`** (skip the questionnaire and reuse
the saved `host_vars` as-is — handy to resume after a failed run; errors if there are
no saved answers yet), and **`-h`/`--help`**; everything else flows through to
`ansible-playbook`. With **`--check`** it writes your answers to a *temp* file (not
the real `host_vars`) and only previews — so a dry-run changes nothing on the system
*or* in the repo (the destructive-replace notice still shows, since it's a simulation).

**Sudo:** `setup.sh` prompts for the sudo password **up front** with its own retry
loop (validating each try via `sudo -S -v`, 3 attempts) and hands it to ansible via
`--become-password-file` pointing at a **tmpfs file** (`$XDG_RUNTIME_DIR` or
`/dev/shm` — RAM-backed so it never touches a physical disk; mode `0600`; removed
immediately after the run). A mistyped password just re-prompts instead of aborting
the play (ansible's `--ask-become-pass` is single-shot — one typo kills the whole
run). NOPASSWD/passwordless sudo skips the prompt (the probe runs `sudo -k` first so
a warm timestamp can't pass as passwordless). Two approaches that *don't* work, for
the record: a cached `sudo -v` timestamp (sudo's `tty_tickets` keys it to the shell's
tty, but ansible's become runs on a different tty), and a process-substitution
password file `<(…)` (ansible re-opens the path by name and `/dev/fd/N` resolves to an
unopenable `pipe:[inode]`). Driving Ansible directly, below, still uses
`--ask-become-pass`.

> ⚠️ **Destructive on a fresh `$HOME`.** The `dotfiles` role force-replaces existing
> dotfiles (`~/.bashrc`, `~/.config/*`, …). On the **first deploy only** it copies any
> pre-existing real config to `<file>.bak` next to it (one per file, ever — marker at
> `~/.local/state/hestia/.dotfiles-backed-up`; `dotfiles_backup=false` to skip), and a
> **first run** (no `host_vars`) warns + requires typing `yes`. Preview with `--check --diff`.

Or drive Ansible directly:

```sh
sudo apt install ansible          # one-time
cd bootstrap

# dry-run the symlinks (safe — shows what would change, changes nothing):
ansible-playbook site.yml --tags dotfiles --check --diff

# apply just the symlinks:
ansible-playbook site.yml --tags dotfiles

# full run (installs packages too — prompts for sudo):
ansible-playbook site.yml --ask-become-pass
```

On an already-configured machine, `--tags dotfiles` should report **no changes**
(every link already correct) — that's the validation that the manifest matches
reality.

## Feature toggles

`packages` + `dotfiles` are core (always run). The optional roles are gated by
`enable_*` booleans (defaults in `group_vars/all.yml`, all `true`), so you choose
the setup without editing the playbook — the first slice of the configurable
installer (`../docs/repo-structure-design.md` §6):

| Toggle | Role | Apt group skipped when off | What it sets up |
|---|---|---|---|
| `enable_samba` | `samba` | `sharing: [samba]` | Samba file share (`/etc`, `/srv/smbshare`); allows the Tailscale range when `enable_tailscale` is also on, else LAN-only |
| `enable_tailscale` | `tailscale` | — (own apt repo, not an apt-group package) | Tailscale mesh VPN — the share's transport + remote reach; `tailscale up` auth stays manual |
| `enable_claude_user` | `claude_user` | `claude: [gh]` | dedicated `claude` agent user + shared trees (`/srv/devshare` + `/srv/clipshare` screenshot drop) + ACLs + local identity (SSH/GPG keys + git config; GPG gated by `claude_sign_commits`) + `gh` for the PR workflow |
| `enable_credentials` | `credentials` | `credentials: [gnome-keyring, libsecret-tools]` | login auto-unlock of SSH + GPG |
| `enable_libreoffice` | *(none — package-only)* | `office: [libreoffice]` | LibreOffice for vifm's office-doc opener (**default off** — heavy) |
| `enable_yaru_icons` | `yaru_icons` | — | install the prebuilt `#d7005f` Yaru **icon** theme (**default off**) — a sha256-verified ~27 MB download into `~/.local`, no root, no build toolchain (the theme is built on demand by the `claude` agent and published as a hestia release; see the role README) |
| `enable_nvidia` | `nvidia` | — | proprietary NVIDIA driver from non-free (**default off** — host-specific, needs a reboot; setup.sh detects a card) |

Disabling a feature also **skips its apt packages** (via `package_group_features`
in the manifest) — so `enable_samba=false` installs no `samba`. (`acl` stays in the
base set; `claude_user`/`claude-access` need it regardless.) `enable_libreoffice`
is the odd one out — it gates **only** the `office` apt group (no role) and is the
sole toggle that defaults **off**, since libreoffice is heavy (~hundreds of MB) and
purely optional.

```sh
# skip a role for this run (string is coerced via `| bool`):
ansible-playbook site.yml -e enable_samba=false --ask-become-pass

# or set it per host (persistent) in host_vars/<host>.yml:
#   enable_claude_user: false
```

## Personalizing (making it your own system)

Running hestia as *your* machine, not dimitrios's? Three layers, none of which touch
`roles/` or `site.yml` (full story: `../docs/personalizing.md`):

1. **host_vars** — flip the toggles above, set your values, or wholesale-override any
   manifest list (`apt_packages:`, `nerd_fonts:`, `localbin_binaries:`).
2. **`bootstrap/local.yml`** — an untracked (gitignored) Ansible *tasks* file for
   installing anything else (apps, repos, flatpaks, binaries, services). `site.yml`
   runs it **last** if present; `become:` tasks reuse setup.sh's sudo password. Start
   from `local.yml.example`. Run it with the rest, or alone via `--tags local`.
3. **`../user/`** — fork the app configs themselves.

After editing `dotfile_links` or `templated_configs`, regenerate CLAUDE.md's
symlink + rendered-template tables so the docs can't drift from the manifest:

```sh
python3 gen-symlink-table.py
```


## NOT handled by Ansible (manual / out of scope — documented in CLAUDE.md)

- (NVIDIA driver — now the opt-in `nvidia` role / `enable_nvidia`; only the **reboot**
  after it stays manual.)
- **NVM + Node** — installed per-user, not from apt.
- **vim-plug** + `:PlugInstall`; **Claude Code** native installer.
- (bluetuith and the Nerd Fonts used to be here — now the `localbin` and `fonts` roles.)
- **`tailscale up`** — only the node auth (interactive SSO / auth-key) is manual; the
  Tailscale *package* is now installed by the `tailscale` role from its own apt repo
  (`enable_tailscale`, default on). (Full list: install-runbook §8.) (LibreOffice is no
  longer manual either — the opt-in `enable_libreoffice` toggle above, default off.)
- **System configs** under `../system/` — deployed by copy as root (see those
  runbooks); a `system` role will wrap them.
- **`claude` identity** — the `claude_user` role now does the **local** half (SSH +
  passwordless GPG keys, `~/.ssh/config`, git config — `tasks/identity.yml`, gated by
  `claude_sign_commits` for the GPG part) and **prints** the remaining steps. Only the
  **GitHub side** stays manual (account + key uploads + PAT need a human):
  1. Create the GitHub **bot account**, upload the SSH (auth) + GPG keys the run printed,
     and invite it as a push collaborator (the run prints the `gh api … collaborators` command).
  2. Authenticate claude's `gh` as the bot (classic PAT, scopes `repo` + `read:org`).
  3. Install Claude Code as claude (native installer) and `claude` once to log in
     (headless device-code flow). See `../docs/claude-user-design.md` §10.
- **Samba share password**: the `samba` role does everything *except* the
  interactive `sudo smbpasswd -a smbshare && sudo smbpasswd -e smbshare` (the
  Windows auth password — kept out of the repo). Run it once by hand.
- **Credential auto-unlock** (the `credentials` role does the launcher-untangle;
  these stay manual — interactive / secret-handling, and a re-login):
  1. Recreate the login keyring so PAM keys it to the login password:
     `mv ~/.local/share/keyrings/login.keyring{,.bak}` (+ `user.keystore`,
     `default`), then log out/in.
  2. Store the passphrases the hook reads (prompts silently — keep them out of the
     repo). The `keyfile`/`keygrip` attributes must match your host_vars
     `ssh_key_file`/`gpg_keygrip`: `secret-tool store --label='ssh key' autounlock ssh keyfile <ssh_key_file>`
     and `secret-tool store --label='gpg signing' autounlock gpg keygrip <gpg_keygrip>`.
  See `../docs/credential-autounlock-design.md` §10.
- **pinentry alternative**: `sudo update-alternatives --set pinentry /usr/bin/pinentry-tty`.
- **Dark mode**: `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`.
