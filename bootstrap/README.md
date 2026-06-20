# Bootstrap (Ansible)

Reproduces this machine from the dotfiles repo on a fresh Debian (Sway) install.
Engine + manifest decision: `../docs/repo-structure-design.md`.

**For a fresh install, follow `../docs/install-runbook.md`** — the ordered
start-to-finish narrative (which role when + the manual steps interleaved). This
file is the per-role reference.

**Status: growing.** Implemented: `packages` (apt), `dotfiles` (symlinks from the
manifest), `samba` (the layer-(a) Samba-over-Tailscale share), `claude_user`
(the dedicated agent user + shared trees + repo ACLs — the *plumbing* of
docs/claude-user-design.md; identity is a manual step, below), and `credentials`
(the gnome-keyring launcher-untangle for login auto-unlock of SSH + GPG).

## Layout

```
bootstrap/
  site.yml              # top-level playbook
  ansible.cfg           # inventory + roles_path
  inventory.ini         # localhost, local connection
  group_vars/all.yml    # THE MANIFEST — packages + dotfile symlinks + paths
  roles/
    packages/           # apt install (become)
    dotfiles/           # symlink the manifest into $HOME (no root)
    samba/              # Samba share: /etc/samba/smb.conf + /srv/share (become)
    claude_user/        # dedicated `claude` agent user + /srv/dev + repo ACLs (become)
    credentials/        # login auto-unlock: gnome-keyring launcher-untangle (become)
  gen-symlink-table.py  # regenerate CLAUDE.md's symlink table from the manifest
  setup-claude-identity.sh   # Phase 4 of the claude-user setup (to become a role)
```

## Use

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

After editing `dotfile_links`, regenerate CLAUDE.md's symlink table so the docs
can't drift from the manifest:

```sh
python3 gen-symlink-table.py
```


## NOT handled by Ansible (manual / out of scope — documented in CLAUDE.md)

- **NVIDIA driver** (`nvidia-smi`) — vendor driver, host-specific.
- **NVM + Node** — installed per-user, not from apt.
- **vim-plug** + `:PlugInstall`; **Claude Code** native installer.
- **Nerd Fonts** (`~/.local/share/fonts` + `fc-cache`); **bluetuith** binary.
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
     repo): `secret-tool store --label='ssh: id_dimitrios' autounlock ssh keyfile id_dimitrios`
     and `secret-tool store --label='gpg: signing' autounlock gpg keygrip <KEYGRIP>`.
  See `../docs/credential-autounlock-design.md` §10.
- **pinentry alternative**: `sudo update-alternatives --set pinentry /usr/bin/pinentry-tty`.
- **Dark mode**: `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`.
