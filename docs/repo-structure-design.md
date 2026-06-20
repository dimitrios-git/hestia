# Design: Repo structure for a reproducible Debian spin

> **Status:** Draft design — supersedes the current flat dotfiles layout *once
> migrated*. Like the sibling docs, written to feed the bootstrap effort and a
> future LinkedIn write-up. The migration is **phased on purpose** (see §6); do
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
defaults/               # (b) base — DEFERRED until a non-dimitrios consumer exists (§6)
users/
  dimitrios/            # (c) — today's app dirs move here verbatim
    vim/ bash/ git/ sway/ waybar/ …
  claude/               # (d) — minimal agent config (lands with the user)
themes/                 # palette + assets (wildcharm); eventual templated
                        #   theming system (§8.3) is deferred
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
`gpg.program` wrapper path, the `gpg-agent.conf` symlink target, glow's style
path.

**Mechanism, in priority order:**
1. **Runtime `$HOME`/XDG** where the format allows it (bash, scripts) — no
   templating, stays directly editable.
2. **Bootstrap-time templating** for formats that can't expand variables (git's
   `excludesfile`, absolute `exec` paths in waybar) — a `host-vars` file supplies
   `HOME`, `REPO_PATH`, `MUSIC_DIR`, etc., and Ansible renders them.

Principle: template only what *must* be machine-specific; everything else stays
plain and symlinked.

## 6. Phased migration (no big-bang, no empty scaffolding)

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

## 7. Migration mechanics & safety

- `git mv` preserves history across the moves.
- The **re-link script** reads the manifest, repoints each symlink, and
  **verifies every link resolves** before finishing.
- **Live-desktop risk:** moving files breaks the existing symlinks mid-flight. Do
  Phase 2 in a recoverable session; since the *contents* are unchanged, a broken
  link is fixed by re-running the relink — low blast radius, but verify Sway/
  waybar/etc. still load before committing.
- CLAUDE.md's "File layout" section and "Active symlinks" table are rewritten to
  describe layers and (ideally) generated from the manifest.

## 8. Decisions (resolved 2026-06-19)

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

## 9. Relationship to the other docs

- `claude-user-design.md` — defines **layer (d)** and the shared-tree/ACL model.
- `file-sharing-design.md` — the **first instance of layer (a)** (`/etc`) and the
  `/etc`-tracking question this doc answers.
- [[dotfiles-project-vision]] — the *why* (spin + complete, themed coverage).
