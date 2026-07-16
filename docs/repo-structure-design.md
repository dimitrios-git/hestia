# Design: Repo structure for a reproducible Debian spin

> **Status:** Implemented — the migration is complete (§7). Path generalisation
> (§5) and parameterisation (§6) are done, and the structure landed as the flat
> **`user/`** layout — `users/<name>/` + `defaults/` were dropped as YAGNI (§7),
> since parameterisation had already absorbed their jobs. Like the sibling docs,
> written to feed the bootstrap effort and a future LinkedIn write-up.

## 1. Why restructure

The repo is outgrowing "one person's dotfiles" and heading toward a
**distributable Debian spin**. The current model — a flat per-app directory,
each symlinked into `~` / `~/.config` — cannot express what the spin needs:

- **System configs** in `/etc` (root-owned) — `smb.conf`, `sshd_config`,
  systemd units. Symlinking these from a user repo is fragile and unsafe.
- **Multiple principals** — `dimitrios` *and* the coming `claude@thetower` agent
  user ([[claude-dedicated-user]] / `docs/claude-user-design.md`).
- **Defaults vs. personal overrides** — a spin ships a base; a person customises
  on top.
- **Machine-specific paths** — hardcoded absolutes (e.g. cmus's
  `/mnt/cold-data/files/Music/Audio/`) can't ship to another machine or user.

The pressure is already concrete: the Samba/`sshd` work needs layer (a); the
dedicated user needs layer (d); path generalisation needs templating.

## 2. The layered model

Four config layers, each with its own **deployment mechanism** and **owner**:

| Layer | What | Deployed how | By |
|---|---|---|---|
| **(a) system** | `/etc`, root-owned (smb.conf, sshd_config, systemd units) | **copied/templated** into place (never symlinked) | bootstrap (root) |
| **(b) defaults** | base config the spin ships pre-personalisation | overlaid under user layers | bootstrap |
| **(c) dimitrios** | personal overrides (today's dotfiles) | **symlinked** into `~`/`~/.config` | user |
| **(d) claude** | the `claude@thetower` agent user's config | symlinked into `/home/claude` | bootstrap/user |

Cross-cutting (not a layer): `themes/`, `docs/`, `bootstrap/`.

**Overlay semantics:** defaults → user override, resolved at **file** granularity
(if the user layer has the file, it wins; else the default ships). File-level
beats trying to merge config bodies — simple and predictable. A few formats
already self-layer (bash `source`, git `include`) and can compose more finely
where wanted.

## 3. Proposed tree

Originally sketched as `system/` + `defaults/` + `users/<name>/`. **As built** it's
simpler — `defaults/` and the per-username level were dropped once parameterisation
replaced the file-layer split (see §7):

```
user/                   # the human's home-deployed configs (flat — not users/<name>/)
  vim/ bash/ git/ gnupg/ sway/ waybar/ glow/ cmus/ … bin/
system/                 # (a) /etc — copied/templated as root by bootstrap
  samba/smb.conf.j2
docs/                   # design docs
bootstrap/              # the installer + the manifest (group_vars/all.yml)
# themes/ — palette SSOT (palette.yml) + render.py theme pipeline (§9.3)
```

## 4. Deployment & tooling

**Engine (decided): Ansible** — already in use here, and it idempotently covers
the *whole* span this needs: `apt` packages, users/groups/ACLs, `/etc` files as
root (`become`), Jinja2 **templating** for machine-specific paths, user-config
**symlinks** (`file: state=link`), and `systemctl enable`. One tool, the entire
bootstrap.

**Preserve direct-edit.** The repo's defining convenience is "edit the symlinked
file and it's live." Ansible keeps that for everything it *symlinks*. Only
genuinely machine-specific files become **templates** (`.j2`, rendered → copied,
so direct-edit is lost for those). **Therefore: keep the templated set as small
as possible** — most files stay plain and symlinked.

**Single source of truth.** A **manifest** (Ansible vars) lists `repo-path →
target` for every symlink and the host-specific path values. CLAUDE.md's "Active
symlinks" table is then *derived from* (or checked against) the manifest, killing
the doc-vs-reality drift we keep hand-patching.

**Alternatives considered:**
- *GNU Stow* — clean symlink farms, but no templating and no `/etc`/root story.
  Solves only part of layer (c)/(d).
- *chezmoi* — strong templating/multi-machine, but its source→`apply` model
  **breaks direct-edit** (you'd edit a source then run `chezmoi apply`), which
  conflicts with this repo's core workflow. Rejected for that reason.

## 5. Path generalisation

Hardcoded absolutes to fix (all currently `/home/dimitrios` or fixed mounts):
cmus music dir, `gitconfig` `excludesfile`, `user/waybar/gpu.sh` path, the
`gpg.program` wrapper path, glow's style path, and `user/sway/config`'s two `exec`
paths (`user/gnupg/credential-unlock.sh`, `user/sway/start-waybar.sh`) — the last found by a
`grep` sweep, not this list, so treat this inventory as a starting point.

**Mechanism, in priority order:**
1. **Runtime `$HOME`/XDG/native expansion** where the format allows it — no
   templating, stays directly editable. This is *wider* than first assumed: bash &
   scripts, git's `excludesfile` (git tilde-expands its pathname configs), and even
   waybar's `exec` (waybar runs it via `sh -c`, so `$HOME` expands).
2. **Bootstrap-time templating** only for formats that expand *nothing* AND whose
   value isn't simply `$HOME` — e.g. git's `gpg.program` (an absolute path *inside
   the clone* → `{{ repo_root }}`) or a host-specific value like the Samba subnet
   (a `host_vars` var). Ansible renders these from the manifest / host_vars.

Principle: template only what *must* be machine-specific; everything else stays
plain and symlinked.

**Status: COMPLETE** (verified by a repo-wide `grep` sweep — no clone/home
absolutes remain in any deployed config). The symlink *destinations* were already
`$HOME`-based (the manifest's `target_home`); every host-specific path now resolves
from a var at deploy time:

| Item | Mechanism | How |
|---|---|---|
| Samba LAN subnet | 2 (host_vars) | `system/samba/smb.conf.j2` ← `samba_lan_subnet` |
| glow style path | 2 (`target_home`) | `user/glow/glow.yml.j2`, rendered |
| git `gpg.program` | 2 (`repo_root`) | `user/git/.gitconfig.j2` (a path *inside the clone*) |
| git `excludesfile` | 1 (native `~`) | git tilde-expands its pathname configs |
| waybar `gpu.sh` exec | 1 (`$HOME`) | script symlinked into `~`; waybar runs `exec` via `sh -c` |
| cmus music dir | 2 (host_vars) | `user/cmus/rc.j2` ← `cmus_music_dir` (default `~/Music`) |
| sway `exec` scripts | 1 (`$HOME`) | `credential-unlock.sh` + `start-waybar.sh` symlinked into `~`; sway runs `exec` via `sh -c` |

Two lessons worth keeping:
- **Reach for mechanism 1 first, verify, *then* template.** Of the cases first
  *assumed* to need templating, three turned out to expand natively (git
  `excludesfile`, waybar `exec`, sway `exec`). Templating was only truly needed for
  paths no format expands: a clone-internal path (`repo_root`) and host-specific
  data (`host_vars`).
- **Inventory by `grep`, not memory.** The original list above missed the two sway
  `exec` paths; a sweep caught them. Re-sweep before declaring "done".

## 6. The configurable installer (the end goal)

Path generalisation (§5) makes the configs *portable*; this step makes the
bootstrap *consumable by someone who isn't `dimitrios`* — an installer driven by
**user-entered inputs** and **feature toggles** instead of assumptions about this
one machine. That is what turns "my reproducible setup" into a distributable spin.
Three layers, each building on what already exists:

1. **Path generalisation (§5) — the prerequisite. ✅ DONE.** Nothing host-specific
   is baked into rendered output; it all comes from vars.
2. **Role feature-flags. ✅ DONE.** The optional roles are gated by `enable_*`
   booleans in `site.yml` (`when: enable_samba | default(true) | bool`, …); defaults
   live in the manifest (`group_vars/all.yml`), all `true` = the full setup. Set one
   false — in host_vars or ad-hoc `-e enable_samba=false` — and the role skips:
   *"Include the Samba share?"* / *"Set up the `claude` agent user?"* are now config,
   not playbook edits. (`packages` + `dotfiles` are core, always run. Gotcha learned:
   `-e` passes **strings**, and ansible-core 2.19 rejects non-boolean conditionals —
   hence the `| bool` coercion.) **Package-group gating ✅ DONE** too: feature-specific
   apt groups (`sharing: [samba]`, `credentials: [gnome-keyring, libsecret-tools]`)
   are mapped to their toggle in `package_group_features`, and the `packages` role
   skips a group whose toggle is off — so a disabled feature drags in no packages.
   (`acl` deliberately stays in base `misc`, not `sharing`: it's used by `claude_user`
   + `claude-access` too, so it must survive `enable_samba=false`.)
3. **An inputs front-end. ✅ DONE (`bootstrap/setup.sh`).** The chosen shape: a
   small **bash `setup.sh`** that is the *single entry point* — it installs Ansible,
   asks the questions (auto-detecting defaults: LAN subnet from `ip route`, music
   dir `~/Music`, …), writes the answers to the untracked **`host_vars/localhost.yml`**,
   then runs the playbook. Re-runnable (it pre-fills from the existing file). The
   **answers-file** approach won over `vars_prompt` (which would prompt every run,
   no unattended re-run) and a TUI (more to maintain) — it extends the host_vars
   pattern already in use and stays diffable. Inputs: the toggles, `samba_lan_subnet`,
   `cmus_music_dir`, and **identity** — `git_user_name`/`git_user_email`/
   `git_signingkey`, `gpg_keygrip`, `ssh_key_file` (rendered into `user/git/.gitconfig.j2`
   and the two credential scripts; setup.sh auto-detects them from existing git
   config, the first GPG secret key + its keygrip, and `~/.ssh/id_*`). With identity
   parameterised, **no personal literals remain in the repo** — the de-personalisation
   the public spin wants. (`credential-unlock.sh` + `keyring-ssh-askpass.sh` moved
   symlink → rendered, both into `~/.config/sway/scripts/` so the `readlink -f`
   sibling-lookup still resolves; the template task grew an optional `mode` so the
   scripts render `0755`.)

**Ties to the layered model:** feature-flags + an answers file are exactly what
make a real `defaults/` layer (§3; deferred per §9.4) worthwhile — defaults ship
the base, the answers override per install. Until a non-`dimitrios` consumer exists
this stays a *goal*; but path generalisation (§5) is the concrete first step and is
worth doing regardless (it also de-personalises the now-public repo).

## 7. Phased migration (no big-bang, no empty scaffolding)

Each phase is tied to a **concrete need** — we don't create layers before
something fills them.

- **Phase 0 — done:** `docs/` exists.
- **Phase 1 — system/ — done:** `system/` holds the layer-(a) `/etc` configs
  (Samba); the manifest drives symlinks + renders. **No mass move yet.**
- **Phase 2 — `user/` (flat) — DONE, but revised.** Originally "`git mv` the app
  dirs under **`users/dimitrios/`**". By the time we got here, §5+§6 had already
  done this phase's *real* jobs — **de-personalisation** and **defaults-vs-overrides**
  — via *parameterisation* (host_vars / templating / `setup.sh`), not a file-layer
  split. So the per-username level (`users/dimitrios/`) lost its purpose: with no
  personal values baked into files, a `users/<name>/` namespace would be a
  single-occupant path level. We moved the app dirs into a **flat `user/`** instead
  — the organisational clarity (human's home configs vs `system/`/`bootstrap/`/`docs/`)
  without the username ceremony. Manifest `src` paths gained the `user/` prefix;
  the CLAUDE.md table regenerated; dests unchanged.
- **Phase 3 — `users/claude/` — dropped (YAGNI).** `claude` is headless: it
  deploys no desktop dotfiles, and its git identity is generated by the
  `claude_user` Ansible role (`tasks/identity.yml`). The layer would be empty.
- **Phase 4 — `defaults/` — dropped (YAGNI).** Overrides are host_vars, and the
  `user/` configs *are* the installable base — a separate `defaults/` is ceremony.

**Net:** the four-layer (system/defaults/users-per-name) model collapsed to
**`user/` + `system/`** once parameterisation replaced the file-layer split. The
layered *reasoning* (§2) still holds; the *implementation* is simpler than first
sketched because §6 absorbed most of it.

## 8. Migration mechanics & safety

- `git mv` preserves history across the moves.
- The **re-link script** reads the manifest, repoints each symlink, and
  **verifies every link resolves** before finishing.
- **Live-desktop risk:** moving files breaks the existing symlinks mid-flight. Do
  Phase 2 in a recoverable session; since the *contents* are unchanged, a broken
  link is fixed by re-running the relink — low blast radius, but verify Sway/
  waybar/etc. still load before committing.
- CLAUDE.md's "File layout" section and "Active symlinks" table are rewritten to
  describe layers and (ideally) generated from the manifest.

## 9. Decisions (resolved 2026-06-19)

1. **Engine — Ansible.** ✅ Already in use; covers apt/users/groups/ACLs/`/etc`/
   templating/symlinks/services idempotently.
2. **Manifest — YAML.** ✅ Ansible vars (not TSV) — keeps one config language
   across the stack (Ansible, Docker, etc.).
3. **`themes/` — build a real theming system, but deferred.** ✅ Intent (as first
   conceived): a central palette (the wildcharm 16-colour set + `#0a0a0a`/`#d7005f`)
   defined once and **rendered into each app's config**. It rides the *same* Ansible/
   Jinja2 templating chosen in §4/§5, so it's a natural later extension, not a new
   mechanism. For now `themes/` just organises theme assets; the templated system
   is its own sub-design, picked up after the structural migration.
   **Update: now built.** `themes/hestia/palette.yml` is the central palette SSOT
   (accent now violet `#7c3aed`; the retired red `#d7005f`, retuned to `#d70000`, is
   the `danger` role; ground lifted `#0a0a0a`→`#1a1a1a`), and **`themes/hestia/render.py`**
   renders it (+ `scopes.yml`) into the per-app theme fragments the bootstrap deploys —
   the TM-family artifacts, the kitty/sway/waybar/mako/wofi/zathura fragments, the
   swaylock/swaynag/vifm/bat/glow pairs, and the vim colorscheme. `docs/theming.md` is
   the per-app process for the configs still applied by hand; the dark/light split and
   syntax coherence are governed by `docs/theme-roadmap.md`. What remains deferred is
   only widening the generated set further, not the mechanism.
4. **`defaults/` — deferred.** ✅ Not created until a non-`dimitrios` consumer
   exists (YAGNI); `users/dimitrios/` is the de facto default until then.

## 10. Relationship to the other docs

- `claude-user-design.md` — defines **layer (d)** and the shared-tree/ACL model.
- `file-sharing-design.md` — the **first instance of layer (a)** (`/etc`) and the
  `/etc`-tracking question this doc answers.
- [[dotfiles-project-vision]] — the *why* (spin + complete, themed coverage).
