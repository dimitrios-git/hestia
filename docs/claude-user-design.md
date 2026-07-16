# Design: Running Claude Code as its own Linux user

> **Status:** **IMPLEMENTED 2026-06-20.** §§1–9 are the design/reasoning;
> **§10 records what was actually built, the deviations from plan, and the
> verification.** For the **day-to-day workflow** (entering claude's context,
> sharing a project), see `working-with-claude.md`. This document is written to
> seed a LinkedIn article once the setup is confirmed in daily use.
>
> **See also:** [`claude-env-parity-design.md`](claude-env-parity-design.md) —
> deploying claude's *terminal environment* (tools + configs + theme) from the same
> Ansible sources as dimitrios's, so the two principals see the same thing. It builds
> on the trust boundary defined here (identity/secrets/privilege stay claude's own).

## 1. Motivation — why not just run the agent as me?

The framing question (and the spine of the write-up): **if an agent has real
intelligence, do we handle it as a *program* or as a *user*?** A program runs as
you, inside your account, with your identity. A user is a separate principal —
own login, own keys, own git identity — that you *collaborate* with. This design
takes the second answer to its logical end: `claude` is its own Linux user, and
you work together the way two people do (separate clones, sync via git), not by
letting a subprocess wear your identity.

Claude Code currently runs as `dimitrios`: same UID, same home, same everything.
For most tasks that is fine. But as the agent takes on more autonomy on a
*personal* machine, "the agent **is** me" is a weak trust model:

- **Sloppiness risk.** Humans (and agents) make mistakes. An agent that owns
  your account can read every secret and overwrite every file, and a bad step
  is as destructive as if you'd typed it yourself.
- **No real attribution.** Everything the agent does is indistinguishable from
  your own actions in file ownership, shell history, git authorship, and logs.
  There is no audit boundary.

The goal is to move the human↔agent trust boundary from **behavioural**
("the agent behaves well") to **kernel-enforced** ("the agent is a separate,
unprivileged principal that *cannot* reach what it isn't granted"). Traceability
then falls out for free: every action is honestly attributed to a distinct
identity — in file ownership, git history, GPG signatures, GitHub, and journald.

This is the classic Unix **least-privilege service account**, applied to an AI
agent.

## 2. The core insight

Two things make this clean rather than painful:

1. **A separate user dissolves problems we currently manage by trust.** Secret
   isolation stops being "mode 600 and please don't commit it" and becomes
   "different UID — the kernel won't open the file." The GPG *pinentry-wedge*
   we fought (agent and human sharing one terminal/agent) disappears because the
   agent has its own session entirely.
2. **A passwordless GPG key for the agent removes the last moving part.** Because
   `claude` signs with its *own* key and we accept it being passphrase-less, the
   agent needs **no pinentry, no agent cache, no unlock** — it signs silently as
   itself, forever. (See §8: this makes the `gpg-wrapper.sh` machinery we built
   irrelevant *for the agent*, though it stays for the human.)

## 3. Identity model (decided)

`claude` acts **as itself** everywhere — this is a settled decision:

| Concern | Mechanism |
|---|---|
| Commit authorship | Own git `user.name` / `user.email` — `Claude (dimitrios's agent) <claude@thetower>` |
| Commit signature | Own **GPG key** (passwordless — see §2/§5) |
| Push / transport auth | Own **SSH key** (`~claude/.ssh/id_claude`, ed25519) |
| GitHub presence | **Dedicated bot account** (decided) |

Key realisation: **provenance is carried by the git author + GPG signature**
(both `claude`'s), *not* by which GitHub account pushes. We go a step further than
the minimum and give `claude` its **own dedicated GitHub bot account** (decided):
it carries PR- and review-level attribution too, not just commit-level, and the
bot is added as a collaborator (or via its own SSH key) on the repos it works on.
The git author identity is `Claude (dimitrios's agent) <claude@thetower>`.

## 4. Architecture

### 4.1 Users & groups
- **`claude`** — unprivileged user, home `/home/claude`, shell bash, **not** in
  `sudo`.
- **`devshare`** group (recommended name; the prior SFTP share reused the broad
  default `users` group instead — a dedicated group is cleaner) — members
  `dimitrios` + `claude`, used to share the collaboration tree.

### 4.2 Filesystem & secret isolation
- **Prerequisite (decided — tighten):** `/home/dimitrios` is currently `775`
  (world-traversable). Tighten to **`750`**. With that, `claude` cannot traverse
  the human's home. `.ssh`/`.gnupg` are already `700` and `.bash_secrets` `600`,
  so the per-file controls hold; the home-dir mode is the gap. (Targeted ACLs for
  specific paths — see §4.3 — are then added back deliberately, not by default.)
- `claude` **cannot read** `dimitrios`'s `~/.bash_secrets`, `~/.ssh`, `~/.gnupg`
  (different UID; 600/700).
- `claude` gets its **own** `~/.ssh/id_claude`, `~/.gnupg` (own key), and its own
  `~/.bash_secrets` if it ever needs tokens.

### 4.3 Shared collaboration tree

**Prior art on this machine (the SFTP share).** Before the distro hop, a similar
human↔service sharing problem was solved with a clean, conventional pattern
(reconstructed from the 2026-06-15 backup):
- OpenSSH `internal-sftp` with `Match User sftpuser` →
  `ChrootDirectory /srv/sftp/%u`, `ForceCommand internal-sftp` in `sshd_config`.
- `sftpuser` shared the **`users`** group with `dimitrios`.
- Sharing was a **bind mount** (not an ACL): `/home/dimitrios/Public` →
  `/srv/sftp/sftpuser/Public` in `fstab`.
- The chroot base (`/srv/sftp/sftpuser`) was **root-owned** — an OpenSSH chroot
  requirement.

So the established convention here is **`/srv` as the neutral, root-owned base +
bind-mount a specific home subdir in + a shared group for access.** The new
shared tree keeps the `/srv` base and shared-group idea but uses **ACLs instead
of bind mounts** (the bind mounts were only forced by the SFTP chroot). That
SFTP share is itself being replaced by Samba-over-Tailscale + ACLs — see
`file-sharing-design.md` — so the whole machine converges on one ACL-based
permission model under `/srv`.

**Decided layout:**
- **Shared dev tree: `/srv/devshare`** (matches the existing `/srv` convention),
  owned `:devshare`, **setgid** (`chmod 2775`) so new files inherit the group,
  plus **default ACLs** (`setfacl -d -m g:devshare:rwx`). New collaborative repos
  live here directly — both users access via the group, no bind mount needed.
- **`hestia`: targeted ACL (decided), left in place.** It stays at
  `/home/dimitrios/Development/hestia`; grant `claude` a minimal path ACL —
  *traverse-only* on the chain (`setfacl -m u:claude:x /home/dimitrios` and on
  `Development/`, giving search but **not** read/listing) and `rwX` on the repo
  itself. This punches a single, named hole through the new `750` home without
  opening it. (Alternative, consistent with the prior-art pattern: bind-mount the
  repo into `/srv/devshare` to keep home perms pristine — noted, not chosen.)
- **Git multi-user sharp edges** (must be handled or git breaks):
  - `safe.directory` entry for the shared repos in each user's git config
    (git refuses "dubious ownership" otherwise).
  - `core.sharedRepository = group` so git writes group-writable objects.
  - umask / ACL alignment so neither user creates files the other can't rewrite.

### 4.4 Accessing `claude` (headless, terminal-first)
- `claude` has **no graphical session.** From a Sway pane, `dimitrios` enters
  claude's context with **`machinectl shell claude@`** — a clean PAM/systemd
  login session with a proper `$XDG_RUNTIME_DIR` (preferred over `su -`, which
  doesn't set up a full session, or `ssh localhost`, which needs sshd). Then runs
  `claude` there.
- This suits the tiling / terminal-app direction that prompted the idea.
- **Out of scope (future):** giving `claude` GUI access to *test* an app would
  need sharing the `WAYLAND_DISPLAY` socket via ACL — deliberately deferred.

### 4.5 Privilege model
- **Zero `sudo` by default.** Add narrow, audited `sudoers.d` drop-ins only for
  concrete, named needs as they arise — each one logged.
- Privileged steps (package installs, the bootstrap itself) stay **dimitrios's**
  job: `claude` proposes, the human runs them.

## 5. Threat model (boundary summary)

**`claude` CAN:** edit the shared repos, commit/push **as itself**, run
unprivileged code, read world-readable system files.

**`claude` CANNOT:** read dimitrios's secrets / keys / private files, `sudo`,
sign as dimitrios, or impersonate dimitrios on GitHub.

**Residual risks (document honestly):**
- *Passwordless GPG key* → anyone who can read claude's key file can sign as the
  bot. Blast radius is limited to the bot identity; the key is isolated in
  `~claude/.gnupg` (700). Accepted trade-off for zero-friction signing.
- *Shared tree* → `claude` can modify code `dimitrios` later runs (an
  in-boundary supply-chain vector). Mitigated by review / git diff.
- *Claude's own GitHub write scope* → keep it minimal (deploy key per repo).

## 6. Reproducibility / bootstrap hooks

Every step below becomes a line in the planned Debian bootstrap script (see the
project's bootstrap goal), so the whole human↔agent setup is reproducible:
`useradd claude`; `groupadd devshare`; group memberships; shared-tree
`mkdir` + setgid + default ACLs; generate claude's SSH + GPG keys; lay down
claude's minimal dotfiles; tighten `/home/dimitrios` perms.

## 7. What this changes in the *current* repo

- The `user/git/gpg-wrapper.sh` + `pinentry-tty` + cache machinery we built **stays
  for dimitrios's interactive commits**, but is **irrelevant for the agent**
  (claude's passwordless key needs no pinentry/cache). Worth stating plainly so
  it isn't mistaken for dead code later.
- Hard-coded `/home/dimitrios` paths (gitconfig `excludesfile`, `user/waybar/gpu.sh`,
  `gpg.program`, the `gpg-agent.conf` symlink target) surface as needing
  parameterisation — the *same* work the bootstrap script already needs.

## 8. Decisions (resolved 2026-06-19)

1. **Identity** — git author + GPG UID = `Claude (dimitrios's agent) <claude@thetower>`. ✅
2. **GitHub** — dedicated **bot account** (collaborator on the repos it works on). ✅
3. **Shared-tree path** — **`/srv/devshare`**, modelled on the existing `/srv` SFTP
   convention (§4.3). ✅
4. **`hestia`** — **targeted ACL**, left in place (traverse-only into the
   home chain + `rwX` on the repo). ✅
5. **`/home/dimitrios` `775 → 750`** — tighten (prerequisite). ✅

Remaining minor sub-choices (not blocking): the shared **group name**
(`devshare` recommended for clarity vs. reusing the existing broad `users` group
the SFTP share used); and the bot's GitHub **account name** / commit email domain
(`@thetower` is a local hostname — a routable noreply may be wanted if the bot
ever needs email).

## 9. Documentation discipline (for the article)

This is intended to become a written piece once proven. As we implement:
- Record **why**, not just **what** — the trust-model shift is the story.
- Capture the **journey** (including this design's origin: the GPG-pinentry-wedge
  saga that made "separate user" obviously right).
- Keep the **threat model** and **residual risks** honest — that candour is what
  makes such an article credible.
- Only publish once **dimitrios confirms the setup works well** in daily use.

## 10. Implementation (DONE 2026-06-20) — what was built

Executed in phases, each verified before the next.

**Phase 1 — user + isolation.** `groupadd devshare`; `useradd -m -d /home/claude
-s /bin/bash -G devshare claude`; `passwd -l claude` (no direct login); `chmod 700
/home/claude`; `usermod -aG devshare dimitrios`. claude is **not** in sudo.
*Verified:* `sudo -u claude cat ~dimitrios/.bash_secrets` → **Permission denied**
(the kernel-enforced boundary, the whole point).

**Phase 2 — `/srv/devshare` shared tree.** `mkdir`, `chgrp devshare`, `chmod 2770`,
`setfacl -m` + `-d -m g:devshare:rwx`. *Verified:* a file claude creates there
comes out group `devshare`, rw — bidirectional sharing, no ownership tangles.

**Phase 3 — hestia in place via ACL.** `setfacl -m u:claude:x` on
`/home/dimitrios` and `/Development` (traverse-only — claude passes through but
**cannot list** the home), then the repo itself made a devshare/setgid/default-ACL
tree. Git multi-user hygiene: `core.sharedRepository=group`, `safe.directory` for
both users. *Verified:* claude can rw + `git` the repo, but `ls /home/dimitrios` →
Permission denied.

**Phase 4 — identity.** `bootstrap/setup-claude-identity.sh` (idempotent): own
ed25519 SSH key `id_claude`, own **passwordless** ed25519 GPG key
`4AA9DD310356AD0E`, git config signing as itself. A GitHub **bot account**
`dimitrios-claude` (separate email) holds the SSH (auth) + GPG keys and is a repo
collaborator. claude's `~/.ssh/config` pins `IdentityFile id_claude`. *Verified:*
SSH → `Hi dimitrios-claude!`; commit **55748ad** authored by claude, **sig G**,
pushed as the bot, shows **Verified** on GitHub.

**Phase 5 — running as claude.** `loginctl enable-linger claude`; Claude Code
native installer (self-contained, no Node) into claude's home; authenticated via
the **headless device-code flow** (no browser on claude — copy-paste the code,
exactly the no-GUI principle). `claude-shell` (a `user/bash/.bashrc` function) drops
dimitrios into claude's context (`sudo -iu claude`, starting in `/srv/devshare`).

### Deviations from the plan (worth the article)
- **Email `claude@charalampidis.pro`**, not the placeholder `claude@thetower` —
  routable, links commits on GitHub, and reusable for the future agent-email idea.
- **Access via `sudo -iu claude`**, not `machinectl shell` — `systemd-container`
  wasn't installed; a login shell is enough for a CLI and avoids the dependency.
- **claude's `.local/bin` PATH** "warning" from the installer is moot — the Debian
  skel `.profile` adds it on login (how `claude-shell` enters).
- **Gotcha:** the GPG-key regen left a *stale second key* with the old
  `claude@thetower` UID; deleted by fingerprint. Lesson: delete the old key
  *before* regenerating, or `--quick-generate-key` makes a new one alongside.

### Residual / follow-ups
- Fold every Phase 1–5 step into the **Ansible bootstrap** (`bootstrap/` started).
- claude's GPG key is passwordless (accepted: blast radius = the bot identity,
  key in claude's 700 home). claude can edit code dimitrios later runs (in-boundary
  supply-chain) — mitigated by review.
- `machinectl`/proper session is a possible upgrade if claude ever needs its own
  `XDG_RUNTIME_DIR`/dbus (e.g. for GUI app-testing — deliberately out of scope).
- **TODO — have a dedicated conversation about Claude Code *configuration* and
  persist it as workstation-as-code.** claude's `~/.claude/settings.json` was
  hand-edited on the box (a `permissions` block: `defaultMode: acceptEdits` + an
  allow-list so reads/edits/git/gh/pnpm/etc. stop prompting inside its own repos,
  with a deny-list keeping `gh pr merge`, any push to `main`, `sudo`, and secrets
  gated — preserving the PR-review trust boundary). That edit lives only on the
  machine; it should be **templated into the Ansible bootstrap** like everything
  else, so a rebuild reproduces claude's whole Claude Code config — `settings.json`
  (permissions, theme/tui), the user/project `CLAUDE.md`, any MCP config, and the
  headless-auth bootstrap — not just the OS user. Scope that conversation: what's
  safe to bake into the repo vs. kept machine-local (tokens/auth never committed),
  and how the permission allow/deny policy is reviewed as it evolves.
