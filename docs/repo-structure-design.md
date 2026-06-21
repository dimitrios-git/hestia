# Design: Repo structure for a reproducible Debian spin

> **Status:** Draft design — supersedes the current flat dotfiles layout *once
> migrated*. Like the sibling docs, written to feed the bootstrap effort and a
> future LinkedIn write-up. The migration is **phased on purpose** (see §7); do
> not big-bang it.

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

```
system/                 # (a) /etc — copied as root by bootstrap
  samba/smb.conf
  ssh/sshd_config
  systemd/…
defaults/               # (b) base — DEFERRED until a non-dimitrios consumer exists (§7)
users/
  dimitrios/            # (c) — today's app dirs move here verbatim
    vim/ bash/ git/ sway/ waybar/ …
  claude/               # (d) — minimal agent config (lands with the user)
themes/                 # palette + assets (wildcharm); eventual templated
                        #   theming system (§9.3) is deferred
docs/                   # design docs (already here)
bootstrap/              # the installer (see §4) + the symlink/path manifest
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
cmus music dir, `gitconfig` `excludesfile`, `waybar/gpu.sh` path, the
`gpg.program` wrapper path, glow's style path, and `sway/config`'s two `exec`
paths (`gnupg/credential-unlock.sh`, `sway/start-waybar.sh`) — the last found by a
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

**Status: nearly complete.** The symlink *destinations* were already `$HOME`-based
(the manifest's `target_home`), and the inventory above is done — each resolved
from a var at deploy time:

| Item | Mechanism | How |
|---|---|---|
| Samba LAN subnet | 2 (host_vars) | `system/samba/smb.conf.j2` ← `samba_lan_subnet` |
| glow style path | 2 (`target_home`) | `glow/glow.yml.j2`, rendered |
| git `gpg.program` | 2 (`repo_root`) | `git/.gitconfig.j2` (a path *inside the clone*) |
| git `excludesfile` | 1 (native `~`) | git tilde-expands its pathname configs |
| waybar `gpu.sh` exec | 1 (`$HOME`) | script symlinked into `~`; waybar runs `exec` via `sh -c` |
| cmus music dir | 2 (host_vars) | `cmus/rc.j2` ← `cmus_music_dir` (default `~/Music`) |

Lesson worth keeping: the two cases first *assumed* to need templating (git
`excludesfile`, waybar `exec`) both expand natively — reach for mechanism 1 first
and verify before reaching for a `.j2`. Templating was only truly needed for paths
no format expands: a clone-internal path (`repo_root`) and host-specific data
(`host_vars`).

**Remaining (the original inventory missed these — found by a `grep` sweep):**
`sway/config` has two clone-absolute `exec` paths — `gnupg/credential-unlock.sh`
and `sway/start-waybar.sh`. sway runs `exec`/`exec_always` via `sh -c`, so these
are the **same mechanism-1 fix as waybar `gpu.sh`**: symlink the two scripts into
`~` (manifest) and reference them via `$HOME`. (Lesson: inventory by `grep`, not
memory.)

## 6. The configurable installer (the end goal)

Path generalisation (§5) makes the configs *portable*; this step makes the
bootstrap *consumable by someone who isn't `dimitrios`* — an installer driven by
**user-entered inputs** and **feature toggles** instead of assumptions about this
one machine. That is what turns "my reproducible setup" into a distributable spin.
Three layers, each building on what already exists:

1. **Path generalisation (§5) — the prerequisite.** Nothing host-specific is baked
   into rendered output; it all comes from vars. (Started — see above.)
2. **Role feature-flags.** Each role becomes optional behind a boolean —
   `enable_samba`, `enable_claude_user`, `enable_screensharing`, … — gating it with
   `when:`. The roles are already cleanly separable (sliceable by `--tags` today),
   so this is mostly wiring + sensible defaults: *"Include the Samba share?"* /
   *"Set up the `claude` agent user?"* become **config, not edits to the playbook**.
3. **An inputs front-end.** Collect the answers once — username/`$HOME`, GPG key id
   + keygrip, Tailscale/LAN, music dir, plus the toggles above — and feed them to
   Ansible. Options (open — not yet decided):
   - **`vars_prompt`** in the playbook — zero extra tooling, interactive, but not
     re-runnable unattended.
   - **An answers file** (`host_vars/<host>.yml`, or `-e @answers.yml`) — idempotent,
     re-runnable, diffable; the interactive part is a one-time `configure` step that
     writes it. **Leaning here:** it extends the host_vars pattern already in use
     (the Samba subnet lives there) and preserves unattended re-runs.
   - **A small TUI** wrapping the answers file — nicer UX, more to maintain; a later
     nicety, not the foundation.

**Ties to the layered model:** feature-flags + an answers file are exactly what
make a real `defaults/` layer (§3; deferred per §9.4) worthwhile — defaults ship
the base, the answers override per install. Until a non-`dimitrios` consumer exists
this stays a *goal*; but path generalisation (§5) is the concrete first step and is
worth doing regardless (it also de-personalises the now-public repo).

## 7. Phased migration (no big-bang, no empty scaffolding)

Each phase is tied to a **concrete need** — we don't create layers before
something fills them.

- **Phase 0 — done:** `docs/` exists.
- **Phase 1 — system/ (next real need):** add `system/` for the imminent
  `smb.conf` + `sshd_config` from the file-sharing work. Introduce the
  manifest + a re-link script. **No mass move yet.**
- **Phase 2 — users/dimitrios/:** `git mv` the current app dirs under
  `users/dimitrios/`, re-link from the manifest in one **verified** pass, rewrite
  CLAUDE.md's layout/table (or generate it). This is the disruptive step —
  isolate it.
- **Phase 3 — users/claude/:** lands with the dedicated-user setup.
- **Phase 4 — defaults/ + full templating:** only when the spin actually ships
  to a **non-`dimitrios`** target. Until then `users/dimitrios/` *is* the de
  facto default; a separate `defaults/` would be empty ceremony (**YAGNI**).

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
3. **`themes/` — build a real theming system, but deferred.** ✅ Intent: a
   central palette (the wildcharm 16-colour set + `#0a0a0a`/`#ce0056`) defined
   once and **rendered into each app's config**. It rides the *same* Ansible/
   Jinja2 templating chosen in §4/§5, so it's a natural later extension, not a new
   mechanism. For now `themes/` just organises theme assets; the templated system
   is its own sub-design, picked up after the structural migration.
4. **`defaults/` — deferred.** ✅ Not created until a non-`dimitrios` consumer
   exists (YAGNI); `users/dimitrios/` is the de facto default until then.

## 10. Relationship to the other docs

- `claude-user-design.md` — defines **layer (d)** and the shared-tree/ACL model.
- `file-sharing-design.md` — the **first instance of layer (a)** (`/etc`) and the
  `/etc`-tracking question this doc answers.
- [[dotfiles-project-vision]] — the *why* (spin + complete, themed coverage).
