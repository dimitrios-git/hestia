# Bootstrap (Ansible)

Reproduces this machine from the dotfiles repo on a fresh Debian (Sway) install.
Engine + manifest decision: `../docs/repo-structure-design.md`.

**For a fresh install, follow `../docs/install-runbook.md`** — the ordered
start-to-finish narrative (which role when + the manual steps interleaved). This
file is the per-role reference.

**Status: growing.** Implemented: `packages` (apt), `dotfiles` (symlinks from the
manifest), `fonts` (Nerd Fonts → `~/.local/share/fonts`), `localbin` (pinned prebuilt
release binaries → `~/.local/bin`, e.g. bluetuith), `samba` (the layer-(a)
Samba-over-Tailscale share), `claude_user`
(the dedicated agent user + shared trees + repo ACLs — the *plumbing* of
docs/claude-user-design.md; identity is a manual step, below), and `credentials`
(the gnome-keyring launcher-untangle for login auto-unlock of SSH + GPG).

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
    fonts/              # Nerd Fonts (Lilex, BigBlueTerm437) into ~/.local/share/fonts (no root)
    localbin/           # pinned GitHub-release binaries (bluetuith) into ~/.local/bin (no root)
    samba/              # Samba share: /etc/samba/smb.conf + /srv/smbshare (become)
    claude_user/        # dedicated `claude` agent user + /srv/devshare + repo ACLs (become)
    credentials/        # login auto-unlock: gnome-keyring launcher-untangle (become)
  gen-symlink-table.py  # regenerate CLAUDE.md's symlink + rendered-template tables from the manifest
  setup-claude-identity.sh   # Phase 4 of the claude-user setup (to become a role)
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
> `~/.local/state/estia/.dotfiles-backed-up`; `dotfiles_backup=false` to skip), and a
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
| `enable_samba` | `samba` | `sharing: [samba]` | Samba-over-Tailscale share (`/etc`, `/srv/smbshare`) |
| `enable_claude_user` | `claude_user` | — | dedicated `claude` agent user + shared tree + ACLs |
| `enable_credentials` | `credentials` | `credentials: [gnome-keyring, libsecret-tools]` | login auto-unlock of SSH + GPG |
| `enable_libreoffice` | *(none — package-only)* | `office: [libreoffice]` | LibreOffice for vifm's office-doc opener (**default off** — heavy) |

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

Running estia as *your* machine, not dimitrios's? Three layers, none of which touch
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

- **NVIDIA driver** (`nvidia-smi`) — vendor driver, host-specific.
- **NVM + Node** — installed per-user, not from apt.
- **vim-plug** + `:PlugInstall`; **Claude Code** native installer.
- (bluetuith and the Nerd Fonts used to be here — now the `localbin` and `fonts` roles.)
- **Tailscale** (own apt repo) — the Samba share's remote reach. (Full list:
  install-runbook §8.) (LibreOffice is no longer manual — it's the opt-in
  `enable_libreoffice` toggle above, default off.)
- **System configs** under `../system/` — deployed by copy as root (see those
  runbooks); a `system` role will wrap them.
- **`claude` identity** (the `claude_user` role does the user/group/ACL plumbing;
  these stay manual — interactive or external):
  1. `sudo -u claude bash bootstrap/setup-claude-identity.sh` — generates claude's
     SSH + passwordless GPG keys and git config; prints the two public keys.
  2. Create the GitHub **bot account**, upload the SSH (auth) + GPG keys, add it as
     a repo collaborator.
  3. `claude`'s `~/.ssh/config`: pin `IdentityFile ~/.ssh/id_claude` + `IdentitiesOnly yes`.
  4. Install Claude Code as claude (native installer) and `claude` once to log in
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
