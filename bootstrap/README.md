# Bootstrap (Ansible)

Reproduces this machine from the dotfiles repo on a fresh Debian (Sway) install.
Engine + manifest decision: `../docs/repo-structure-design.md`.

**For a fresh install, follow `../docs/install-runbook.md`** — the ordered
start-to-finish narrative (which role when + the manual steps interleaved). This
file is the per-role reference.

**Status: growing.** Implemented: `packages` (apt), `dotfiles` (symlinks from the
manifest), `fonts` (Nerd Fonts → `~/.local/share/fonts`), `samba` (the layer-(a)
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
  roles/
    packages/           # apt install (become)
    dotfiles/           # symlink plain configs + render templated_configs into $HOME (no root)
    fonts/              # Nerd Fonts (Lilex, BigBlueTerm437) into ~/.local/share/fonts (no root)
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
./setup.sh --check --diff              # true DRY-RUN: preview everything, change nothing
./setup.sh --tags dotfiles --check     # preview just the dotfiles re-link
```

Extra args flow through to `ansible-playbook`. With **`--check`**, `setup.sh` writes
your answers to a *temp* file (not the real `host_vars`) and only previews — so a
dry-run changes nothing on the system *or* in the repo.

> ⚠️ **Destructive on a fresh `$HOME`.** The `dotfiles` role force-replaces existing
> dotfiles (`~/.bashrc`, `~/.config/*`, …). It **backs up** any pre-existing real file
> first (`<file>.bak`, or a timestamped backup for rendered configs), and a **first
> run** (no `host_vars` yet) warns and requires typing `yes`. Preview with `--check --diff`.

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

Disabling a feature also **skips its apt packages** (via `package_group_features`
in the manifest) — so `enable_samba=false` installs no `samba`. (`acl` stays in the
base set; `claude_user`/`claude-access` need it regardless.)

```sh
# skip a role for this run (string is coerced via `| bool`):
ansible-playbook site.yml -e enable_samba=false --ask-become-pass

# or set it per host (persistent) in host_vars/<host>.yml:
#   enable_claude_user: false
```

After editing `dotfile_links` or `templated_configs`, regenerate CLAUDE.md's
symlink + rendered-template tables so the docs can't drift from the manifest:

```sh
python3 gen-symlink-table.py
```


## NOT handled by Ansible (manual / out of scope — documented in CLAUDE.md)

- **NVIDIA driver** (`nvidia-smi`) — vendor driver, host-specific.
- **NVM + Node** — installed per-user, not from apt.
- **vim-plug** + `:PlugInstall`; **Claude Code** native installer.
- **bluetuith** binary (`~/.local/bin`, not in apt). (Nerd Fonts are now the `fonts` role.)
- **Tailscale** (own apt repo) — the Samba share's remote reach; **libreoffice**
  (heavy, optional) — vifm's office-doc opener. (Full list: install-runbook §8.)
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
