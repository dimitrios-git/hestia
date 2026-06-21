# Making estia yours

estia ships **dimitrios's** machine as the working default — goal 1 is to rebuild
*that* box fast, so his app/font/config lists are the tracked default. But every
value, list, and config is meant to be overridable **as data**, so someone else can
run estia as their own system without editing any role or playbook *logic* (goal 2).

Three layers, increasing in depth. You never touch `bootstrap/roles/` or `site.yml`.

## 1. Flip toggles, override values & lists — `host_vars`

`setup.sh` writes your answers to the untracked `bootstrap/host_vars/localhost.yml`
(host_vars > group_vars, so your value always wins). Edit that file directly too:

- **Feature toggles:** `enable_samba`, `enable_claude_user`, `enable_credentials`,
  `enable_libreoffice` — turn whole features on/off.
- **Host values:** `samba_lan_subnet`, `cmus_music_dir`, the git identity,
  `ssh_key_file`.
- **Wholesale list overrides** (free — no code): anything in `group_vars/all.yml` can
  be replaced in host_vars. Want different fonts or a different package set? Set your
  own `nerd_fonts:`, `localbin_binaries:`, or even the `apt_packages:` map. You're
  overriding the *data* the roles consume, not the roles.

Re-run `./setup.sh` (or `--yes` to reuse saved answers) to apply.

## 2. Install anything else — `bootstrap/local.yml` (untracked)

For software and tweaks beyond the defaults — extra apps, a third-party apt repo, a
Flatpak, a downloaded binary, a systemd unit, any command — drop an **Ansible tasks
file** at `bootstrap/local.yml`. It's **gitignored**, so it never collides with the
tracked repo or reaches the public upstream, and `site.yml` runs it **last**, after
the base system is in place. Any task with `become: true` reuses the sudo password
`setup.sh` already collected — no second prompt.

```sh
cp bootstrap/local.yml.example bootstrap/local.yml
$EDITOR bootstrap/local.yml
./setup.sh --yes                 # or:  ansible-playbook site.yml --tags local
```

`local.yml.example` shows GIMP (apt), a Flathub app, a vendor apt repo, and a
`~/.local/bin` binary. This single seam covers everything — there's no per-tool knob
to learn, and it grows with you instead of needing a new `extra_*` variable each time.

> For a **pinned, checksum-verified** release binary you want tracked behaviour for,
> prefer adding an entry to `localbin_binaries` (layer 1) over a raw `get_url` here.

## 3. Fork the configs — `user/`

The deepest layer: the app configs under `user/` are just files. Edit them (or the
`.j2` templates the bootstrap renders) to change a tool's actual behaviour or theme —
the same way you'd tweak any dotfiles. This is expected and unabstracted; it's your
repo now.

---

**Rule of thumb:** override *values/lists* in `host_vars` (layer 1), add *new
software/actions* in `bootstrap/local.yml` (layer 2), change *how a tool behaves* by
editing `user/` (layer 3).
