# Fresh-install runbook

End-to-end order to reproduce this machine from the repo: which Ansible role to
run when, and the manual steps interleaved between them (interactive, secret-
handling, or external — deliberately not automated). Designed to be followed
top-to-bottom on a fresh Debian box.

> **Convention:** `[ansible]` = a role (idempotent; dry-run first with `--check`).
> `[manual]` = a one-time human step. `[reboot]` / `[relogin]` = session restart
> required before the next step works. Run everything from the repo unless noted.

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
**Not** apt: NVIDIA driver, NVM/Node, Nerd Fonts, bluetuith, Claude Code — see §8.

## 2. Dotfiles (symlinks) — `[ansible]`

```sh
ansible-playbook site.yml --tags dotfiles --check --diff   # preview
ansible-playbook site.yml --tags dotfiles                  # apply
```
Symlinks every config from the manifest into `$HOME`. No root. On a configured
machine this is `changed=0`.

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
- **Update the host-specific values** in `gnupg/credential-unlock.sh` — `KEYGRIP`,
  `SIGNKEY`, and the `id_dimitrios` filename — to match your new key, and the
  `signingkey`/`gpg.program` paths in `git/.gitconfig`.

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
# store the passphrases the login hook reads (silent prompts — kept out of the repo):
secret-tool store --label='ssh: id_dimitrios' autounlock ssh keyfile id_dimitrios
secret-tool store --label='gpg: signing'      autounlock gpg keygrip <YOUR-KEYGRIP>
```
**`[reboot]`** — on next login the keyring auto-unlocks and the Sway hook loads
SSH + warms GPG. Verify: `ssh-add -l` shows your key and a `git commit -S` signs
with no prompt.

## 8. Remaining manual / external bits — `[manual]`

Not Ansible-managed (vendor, per-user, or interactive):
- **NVIDIA driver** (for `nvidia-smi` / the waybar GPU module) — host-specific.
- **NVM + Node** — per-user installer; needed by `markdown-preview.nvim`'s build.
- **vim-plug**: `curl -fLo ~/.vim/autoload/plug.vim --create-dirs <url>`, then
  `:PlugInstall` in vim/nvim; treesitter parsers need `gcc`.
- **Nerd Fonts** (BigBlueTerm437 / Lilex) into `~/.local/share/fonts`, then
  `fc-cache -f`.
- **bluetuith** binary into `~/.local/bin` (not in apt).
- **Claude Code** for your own user (native installer) if not already present.
- Enable services: `sudo systemctl enable --now bluetooth power-profiles-daemon`.

## Validation

After a reboot: bar renders on its own, dark mode holds, `ssh-add -l` + a signed
commit work with no prompt, `\\thetower\share` mounts, and `sudo -iu claude` →
`claude` runs as the agent. Re-running any role with `--check` should be
`changed=0`.
