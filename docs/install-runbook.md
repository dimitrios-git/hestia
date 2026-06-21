# Fresh-install runbook

End-to-end order to reproduce this machine from the repo: which Ansible role to
run when, and the manual steps interleaved between them (interactive, secret-
handling, or external — deliberately not automated). Designed to be followed
top-to-bottom on a fresh Debian box.

> **Convention:** `[ansible]` = a role (idempotent; dry-run first with `--check`).
> `[manual]` = a one-time human step. `[reboot]` / `[relogin]` = session restart
> required before the next step works. Run everything from the repo unless noted.

> **Shortcut:** `bootstrap/setup.sh` does all the `[ansible]` steps in one go —
> installs Ansible, asks the feature/host questions (§1–§2 here), and runs the
> playbook. The `[manual]` steps below (identity, Samba password, pinentry, dark
> mode, credential keyring) still have to be done by hand; this runbook is the
> authoritative order for them. Use `setup.sh` for the easy path, this for detail.

## 0. Prerequisites (base system) — `[manual]`

Assumed already installed (out of scope for this repo):
- Debian (trixie) with the **Sway** session reachable via **greetd + tuigreet**.
- A working network; `git`, `sudo`, and your user account.

```sh
sudo apt update && sudo apt install -y git ansible
git clone git@github.com:dimitrios-git/estia.git ~/Development/estia
cd ~/Development/estia/bootstrap
```

> Cloning over SSH needs a key on GitHub first; or clone over HTTPS for read-only
> and switch the remote to SSH later.

## 1. Packages — `[ansible]`

```sh
ansible-playbook site.yml --tags packages --ask-become-pass
```
Installs the apt set (Wayland stack, terminal tools, samba, gnome-keyring, …).
**Not** apt: NVIDIA driver, NVM/Node, bluetuith, Claude Code — see §8. (Nerd Fonts
are installed by the `fonts` role.)

## 2. Dotfiles (symlinks) — `[ansible]`

```sh
ansible-playbook site.yml --tags dotfiles --check --diff   # preview
ansible-playbook site.yml --tags dotfiles                  # apply
```
Symlinks the plain configs and **renders** the path-generalised ones
(`templated_configs`) into `$HOME`. No root. On a configured machine this is
`changed=0`. **Destructive on a populated `$HOME`:** it replaces existing dotfiles —
but first backs up any pre-existing *real* file to `<file>.bak` (symlinked) or a
timestamped backup (rendered), so nothing is silently lost. (`setup.sh` also warns +
gates a first run; preview safely with `--check --diff`.)

> **Per-host values:** a few configs read host-specific values with sensible
> defaults — `cmus_music_dir` (default `~/Music`) and the Samba `samba_lan_subnet`.
> Override what differs in an untracked `bootstrap/host_vars/localhost.yml` (copy
> `…/localhost.yml.example`); otherwise the defaults render. host_vars > group_vars,
> so your override always wins.

> **Git ignore model** (the `user/git/.gitignore_global` this step just symlinked is
> layer 1 of three — know which layer a new ignore belongs in):
> 1. **`~/.gitignore_global`** (`core.excludesfile`) — only *never-commit-anywhere*
>    noise: OS/editor cruft + `.claude/settings.local.json`. It applies on **this
>    machine only**, so it never travels to clones/collaborators/CI.
> 2. **committed `.gitignore`** — shared *project* ignores that everyone with the
>    repo should get (e.g. estia's `bootstrap/host_vars/*.yml`).
> 3. **`.git/info/exclude`** — *this clone only*, e.g. keeping your agent's files
>    out of a repo you don't own (`printf '.claude/\nCLAUDE.md\n' >> .git/info/exclude`).
>
> Consequence: `.gitignore` and `.editorconfig` are **deliberately not** in the
> global file — they're meant to be committed and shared per-repo.

## 3. Pinentry + dark mode — `[manual]`

```sh
sudo update-alternatives --set pinentry /usr/bin/pinentry-tty
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
```
The first stops `pinentry-curses` leaking mouse-tracking codes; the second makes
portal-aware apps (Firefox) honour dark mode.

## 4. Your identity (SSH + GPG) — `[manual]`

Generate/import your **own** keys (the repo carries none). Then:
- Put the SSH public key on GitHub; confirm `ssh -T git@github.com`.
- Note your **GPG key id** and **keygrip** (`gpg --list-secret-keys --with-keygrip`).
- **No file edits needed** — `setup.sh` collects your identity (git name/email,
  `git_signingkey`, `gpg_keygrip`, `ssh_key_file`) into host_vars and renders it
  into `user/git/.gitconfig` + the credential-unlock scripts. It auto-detects most of it
  (existing git config, your first GPG secret key + keygrip, your `~/.ssh/id_*`),
  so usually you just confirm. (Re-run `setup.sh` after generating keys.)

## 5. Samba share — `[ansible]` + `[manual]`

```sh
ansible-playbook site.yml --tags samba --check --ask-become-pass   # preview
ansible-playbook site.yml --tags samba --ask-become-pass           # apply
sudo smbpasswd -a smbshare && sudo smbpasswd -e smbshare           # [manual] Windows auth pw
```
First set this host's LAN subnet so the share's `hosts allow` is right: copy
`bootstrap/host_vars/localhost.yml.example` to `localhost.yml` and set
`samba_lan_subnet` (untracked — the real value stays out of the repo). The role
renders `smb.conf.j2` from it.

## 6. Dedicated `claude` user — `[ansible]` + `[manual]` + `[relogin]`

```sh
ansible-playbook site.yml --tags claude_user --check --ask-become-pass   # preview
ansible-playbook site.yml --tags claude_user --ask-become-pass           # apply
```
Then claude's identity (interactive / external — see `claude-user-design.md` §10):
```sh
sudo -u claude bash setup-claude-identity.sh        # keys + git config; prints 2 pubkeys
sudo -u claude tee /home/claude/.ssh/config >/dev/null <<'EOF'
Host github.com
    IdentityFile ~/.ssh/id_claude
    IdentitiesOnly yes
EOF
sudo -u claude chmod 600 /home/claude/.ssh/config
```
- Create the GitHub **bot account**, upload claude's SSH (auth) + GPG keys, add it
  as a repo collaborator.
- Authenticate claude's `gh` as the bot (for the PR workflow — see
  `working-with-claude.md`). Signed in as the bot, make a classic PAT with scopes
  `repo` + `read:org`, then, as claude:
  ```sh
  read -rs GH_TOKEN     # paste the token (hidden)
  printf '%s' "$GH_TOKEN" | gh auth login --hostname github.com --git-protocol ssh --with-token
  unset GH_TOKEN; gh api user --jq .login   # expect: dimitrios-claude
  ```
- Install Claude Code as claude and log in (headless device-code):
  `sudo -iu claude bash -c 'curl -fsSL https://claude.ai/install.sh | bash'` then
  `sudo -iu claude` → `claude`.

**`[relogin]`** — log out/in so your account picks up the new `devshare` group
(needed to access claude's clones under `/srv/devshare`).

## 7. Credential auto-unlock — `[ansible]` + `[manual]` + `[reboot]`

```sh
ansible-playbook site.yml --tags credentials --ask-become-pass
```
Untangles gnome-keyring's launchers so PAM is the sole unlocker. Then, one-time:
```sh
# recreate the login keyring so PAM keys it to the LOGIN password:
cd ~/.local/share/keyrings && for f in login.keyring user.keystore default; do
  [ -e "$f" ] && mv "$f" "$f.bak"; done
# store the passphrases the login hook reads (silent prompts — kept out of the repo).
# The `keyfile` / `keygrip` attributes MUST match your host_vars `ssh_key_file` /
# `gpg_keygrip` (what setup.sh wrote), since the rendered scripts look them up by that:
secret-tool store --label='ssh key' autounlock ssh keyfile <ssh_key_file>     # e.g. id_ed25519
secret-tool store --label='gpg signing' autounlock gpg keygrip <gpg_keygrip>
```
**`[reboot]`** — on next login the keyring auto-unlocks and the Sway hook loads
SSH + warms GPG. Verify: `ssh-add -l` shows your key and a `git commit -S` signs
with no prompt.

## 8. Remaining manual / external bits — `[manual]`

Not Ansible-managed (vendor, per-user, interactive, or deliberately heavy/optional):
- **NVIDIA driver** (for `nvidia-smi` / the waybar GPU module) — host-specific.
- **NVM + Node** — per-user installer; needed by `markdown-preview.nvim`'s build.
- **vim-plug**: `curl -fLo ~/.vim/autoload/plug.vim --create-dirs <url>`, then
  `:PlugInstall` in vim/nvim. (Treesitter parsers compile on first run — the
  needed compiler, `build-essential`, is now an apt dep, so no extra step.)
- **Tailscale** — for the Samba share's remote (off-LAN) reach. Not apt-native:
  add its own apt repo (`pkgs.tailscale.com`) or run the install script, then
  `tailscale up`. (On-LAN Samba works without it.)
- **LibreOffice** (`libreoffice`) — *optional, heavy* (~hundreds of MB): vifm opens
  office docs with it. Install only if you want that; everything else works without.
- **bluetuith** binary into `~/.local/bin` (not in apt).
- **Claude Code** for your own user (native installer) if not already present.
- Enable services: `sudo systemctl enable --now bluetooth power-profiles-daemon`.

## Validation

After a reboot: bar renders on its own, dark mode holds, `ssh-add -l` + a signed
commit work with no prompt, `\\thetower\share` mounts, and `sudo -iu claude` →
`claude` runs as the agent. Re-running any role with `--check` should be
`changed=0`.
