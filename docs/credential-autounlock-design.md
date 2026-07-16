# Design: Headless auto-unlock of SSH + GPG at login

> **Status:** **IMPLEMENTED 2026-06-19** (Path A — gnome-keyring). §§1–9 below are
> the original design/reasoning; **§10 records what was actually built and the two
> places reality differed from the plan.** Read §10 for the working setup. (The
> PAM stack itself needed no edit — Debian pre-wires `pam_gnome_keyring` in
> `/etc/pam.d/greetd` as a safe `optional` module, so there was no lock-out risk.)

## 1. Goal (and a corrected framing)

The constraint was always **"no GUI app," never "no keyring."** Auto-unlocking
SSH + GPG at login is a welcome convenience *if* it's headless. The payoff: the
per-boot `ssh-add` and `gpg-unlock` (and most of the pinentry-wedge dance)
**disappear** — keys are ready by the time any shell, push, or commit runs,
including Claude Code's.

## 2. How login auto-unlock works

A chain: the greeter authenticates you with your **login password via PAM** → a
**PAM module** in that stack hands the password to an agent/store → the store
**unlocks the key passphrases**, once, at login.

- The keyring **daemon is headless** (a background service).
- The **only** GUI piece is the keyring's *prompter* dialog, which fires **only
  when PAM did not unlock** the store. With PAM auto-unlock at login it never
  appears → fully headless in steady state.
- **greetd is PAM-based**, so this wires into `/etc/pam.d/greetd` like any display
  manager. greetd was never the blocker — it was simply unconfigured.

## 3. The crux: login password vs. key passphrase (issues #1 and #2)

Two fundamentally different models:

| Model | How | Passphrase = login password? |
|---|---|---|
| **Direct-match** (`pam_gnupg`, `libpam-ssh`) | PAM feeds the **login password itself** as the key passphrase | **Required** — forces them equal |
| **Wrapped-store** (gnome-keyring) | Login password unlocks an **encrypted keyring** that *holds* the real passphrases | **Not required** — passphrases are arbitrary |

**This is the key clarification:** last turn I implied matching is inherent. It
is **not** — it's only inherent to the *direct-match* modules. The **wrapped-store
(keyring)** model uses the login password to unlock a *container*, and the
container holds your existing, distinct passphrases.

- **Issue #1 (your passwords ≠ passphrases):** with the wrapped-store model you
  **keep your current passphrases unchanged** — you enter each once when first
  storing it in the keyring; thereafter login unlocks the keyring and the stored
  passphrase loads the key. No "hard decision," no key changes.
- **Issue #2 (the spin must support non-matching users):** the wrapped-store model
  supports non-matching **by construction** — so it's the right default for a
  distributable spin. Direct-match becomes an optional "simple mode" for users who
  *prefer* zero keyring daemon and are happy to set passphrase = login password.

## 4. Recommended architecture — gnome-keyring (headless) + a GPG bridge

- **gnome-keyring-daemon** (headless): provides the **login keyring**, a **Secret
  Service**, and an **SSH agent**.
- **PAM:** add `pam_gnome_keyring` to `/etc/pam.d/greetd` (`auth` + `session
  auto_start`) → the login keyring unlocks with your login password at login.
- **SSH:** point `SSH_AUTH_SOCK` at gnome-keyring's agent. Your key's (arbitrary)
  passphrase is stored in the keyring once (headlessly via `secret-tool`, no GUI),
  then auto-loaded every login. *(Replaces Debian's `ssh-agent.socket` for
  `dimitrios` — reverses an earlier choice, deliberately.)*
- **GPG:** gnome-keyring dropped GPG years ago, so bridge it: store the GPG
  passphrase in the Secret Service, and a **session-start hook** runs
  `gpg-preset-passphrase` (needs `allow-preset-passphrase` in `gpg-agent.conf`) to
  preset it into `gpg-agent` by keygrip. Arbitrary GPG passphrase, auto-warmed at
  login. *(This is the most custom piece.)*

Net result at login: SSH key loaded + GPG cache warm, no prompts, no GUI.

## 5. What this changes / retires

- **Per-boot `ssh-add` + `gpg-unlock`:** gone (automatic at login).
- **`user/git/gpg-wrapper.sh`** (pinentry-mode error under `$CLAUDECODE`): kept, but
  becomes a rarely-hit safety net since the cache is pre-warmed.
- **SSH agent:** Debian `ssh-agent.socket` → gnome-keyring's agent (for dimitrios).
- **Secret Service** now exists → `~/.bash_secrets` tokens *could* migrate into it
  (a separate, optional task — relates to [[secrets-handling]]).
- Complements [[claude-dedicated-user]]: the `claude` user keeps its own
  passwordless key; this auto-unlock is for dimitrios's interactive login.

## 6. The spin: per-user choice (the issue-#2 requirement)

The bootstrap offers two modes at account setup, both wired through greetd PAM:
- **Flexible (default):** gnome-keyring wrapped-store — any passphrase, unlocked by
  the login password.
- **Simple:** `pam_gnupg`/`libpam-ssh` direct-match — no keyring daemon, for users
  who set passphrase = login password.

## 7. Honest security trade-offs

- The login keyring is **only as strong as your login password** (it encrypts the
  store). Weak login password → weak everything. Use a strong one.
- Auto-unlock means **anyone who can unlock your session has your keys ready** —
  so a screen lock (`swaylock`, already bound) + the existing idle-lock matter
  more, not less.
- If gnome-keyring's prompter ever *does* fire (PAM unlock failed), it's a small
  floating GTK dialog under Sway — borderline against "no GUI," but it shouldn't
  appear in normal operation. Documented honestly.

## 8. Reproducibility / deployment (system/ layer)

- **Packages:** `gnome-keyring`, `libpam-gnome-keyring`, `libsecret-tools`
  (`secret-tool`).
- **`/etc/pam.d/greetd`** drop-in — tracked under `system/` (copied as root).
- **`user/gnupg/gpg-agent.conf`:** add `allow-preset-passphrase`.
- **Session-start GPG-preset hook** (small script + keygrip) — tracked.
- **`SSH_AUTH_SOCK`** change in `user/bash/.bashrc` / session env.
- All version-controlled; the bootstrap wires PAM + starts the daemon.

## 9. Open decisions

1. **Confirm gnome-keyring (flexible) as the base** vs. `pam_gnupg` (simple/
   matching). Recommended: gnome-keyring — it dissolves issues #1 and #2 and gives
   a Secret Service.
2. Whether to migrate `~/.bash_secrets` → Secret Service (separate task).
3. Spin default = flexible mode? (recommended).
4. **Test plan first:** wire PAM, keep a **root VT logged in** as a rescue, verify
   login still works *and* the keyring unlocks, *then* commit. Never push an
   untested login-PAM change.

## 10. Implementation (DONE 2026-06-19) — what actually works

Path A, working end to end: at login the SSH key is loaded and gpg-agent is warm
with **zero** manual `ssh-add` / `gpg-unlock` (including for Claude Code).

**The real blocker + fix.** The login keyring wouldn't unlock because gnome-keyring
was started by a *tangle* of competing launchers (systemd
`gnome-keyring-daemon.service`/`.socket`, three
`/etc/xdg/autostart/gnome-keyring-*.desktop`, plus `gcr-ssh-agent`) **before** PAM
could hand it the password — so it came up locked and `secret-tool` hung on a GUI
prompter that isn't there. The fix made `pam_gnome_keyring` the **sole** starter:
- `sudo systemctl --global disable gnome-keyring-daemon.service gnome-keyring-daemon.socket`
- `~/.config/autostart/gnome-keyring-{pkcs11,secrets,ssh}.desktop` with `Hidden=true`
- recreate the login keyring (move the old `*.keyring` aside) so PAM keys it to the login password

After that the daemon comes up as `gnome-keyring-daemon --daemonize --login`
(PAM-started, password in hand) and the login keyring unlocks.

**Two places reality differed from the §4 plan:**
1. **SSH — not gnome-keyring's agent** (its ssh component is gone). We keep the
   Debian ssh-agent and load the key from the keyring via an **SSH_ASKPASS** helper
   (`user/gnupg/keyring-ssh-askpass.sh`). Simpler, version-proof.
2. **GPG — not `gpg-preset-passphrase`** (it caches into a slot the *signing* path
   doesn't consult — sign failed "No pinentry" despite `keyinfo cached=1`). A
   **loopback sign of /dev/null** with the keyring passphrase warms the *normal*
   cache and signs cleanly (and validates the passphrase).

**Tracked pieces:** `user/gnupg/credential-unlock.sh.j2` (Sway-`exec` login hook) +
`user/gnupg/keyring-ssh-askpass.sh.j2` — both **rendered** by the dotfiles role into
`~/.config/sway/scripts/` (they carry identity values, so `.j2` templates, not plain
symlinks); `user/gnupg/gpg-agent.conf` (`allow-loopback-pinentry` + long TTL),
`user/sway/config` exec line. Passphrases stored once via
`secret-tool store … autounlock ssh/gpg …`.

**Cache TTL = ~session-length (`34560000`).** With auto-unlock the boundary is the
**unlocked login session + screen lock**, not the GPG TTL — GPG now matches
ssh-agent's "loaded until logout". A short TTL can't work (no pinentry to
re-prompt; the hook runs only at login), and a long TTL **must not assume the user
keeps screen locking** — the lock, not the TTL, is the control for an unattended
session. The agent dies on logout/reboot (clearing everything); the hook re-warms
at next login. `gpg-wrapper.sh` stays as a fail-clean safety net for the rare cold
cache.
