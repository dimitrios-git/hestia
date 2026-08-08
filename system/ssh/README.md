# SSH hardening + fail2ban — deploy runbook

Keys-only sshd, no root login, and a **TOTP second factor for connections from the
internet** (key alone from the LAN and the tailnet). Plus fail2ban to keep the logs
readable.

Layer-(a) system config: a rendered **drop-in** at `/etc/ssh/sshd_config.d/`, never
an edit to Debian's own `sshd_config`. Roles: **`ssh_server`** + **`fail2ban`**.

> **Read the ordering section before running anything.** Disabling password auth
> before a key works is the one mistake here that is genuinely hard to undo.

## Why a drop-in, and why `10-`

Debian's stock `sshd_config` has `Include /etc/ssh/sshd_config.d/*.conf` on its
**first line**, and sshd takes the **first** value it sees for most keywords. A
drop-in that sorts early therefore overrides everything below it, and survives a
package upgrade replacing `sshd_config`.

## Ordering — do not skip

The role enforces this with asserts, but understand it anyway:

1. **A key must be authorised first.** The role reads
   `~/.ssh/{{ ssh_key_file }}.pub` and installs it into `authorized_keys`, then
   **re-reads the file and refuses to continue if it is still empty**.
2. **Verify key login in a SECOND terminal, keeping the first open.** If something
   is wrong, the open session is the way back in.
3. **Only then** does `PasswordAuthentication no` take effect.
4. The handler **reloads** rather than restarts sshd — established sessions survive,
   so a bad config cannot kill the session that is applying it.
5. If the merged config fails `sshd -t`, the role **removes its own drop-in** and
   fails, leaving sshd exactly as it was.

On this host there is also console access and Tailscale SSH, so a lockout is
recoverable — but on a remote box it would not be.

## 1. Key-only first (no TOTP yet)

```yaml
# host_vars/localhost.yml
enable_ssh_server: true
enable_fail2ban: true
ssh_require_totp: false      # not yet — enrol first, see below
```

```sh
cd bootstrap
ansible-playbook site.yml --tags packages,ssh --check --ask-become-pass   # preview
ansible-playbook site.yml --tags packages,ssh --ask-become-pass           # apply
```

`packages` is included because `openssh-server` and `libpam-google-authenticator`
come from the manifest's `ssh_server` apt group, not from the role. On a machine
where they are already installed, `--tags ssh` alone is enough.

Verify from another machine **before closing your current session**:

```sh
ssh -o PreferredAuthentications=publickey dimitrios@192.168.1.130   # must succeed
ssh -o PreferredAuthentications=password  dimitrios@192.168.1.130   # must be REFUSED
```

## 2. Enrol TOTP, then require it

Enrolment is **manual and interactive** — the secret and the scratch codes must
never enter the repo, exactly like `smbpasswd` and `tailscale up`:

```sh
google-authenticator -t -d -f -r 3 -R 30 -W
```

Flags: time-based, disallow token reuse, write the file, rate-limit to 3 logins per
30s, narrow the time window. It prints a QR code — **scan it into Bitwarden**
(Bitwarden has a built-in authenticator, so the codes live with the password) — and
a set of **scratch codes**. Save those somewhere that is not this machine; they are
the only way in if you lose the authenticator.

Then flip the toggle and re-run:

```yaml
ssh_require_totp: true
```

```sh
ansible-playbook site.yml --tags ssh --ask-become-pass
```

The role **refuses** to enable TOTP if `~/.google_authenticator` does not exist —
otherwise sshd would demand a code you cannot produce, from every non-trusted
network.

Verify, again keeping a session open: an SSH from the LAN should still be key-only;
from outside it should ask for a verification code after the key.

## 3. Expose it

Forward **external 2222 → internal 22** at the router. sshd keeps listening on 22
so nothing changes for LAN and tailnet clients; only the outside sees 2222.

```sh
ssh -p 2222 dimitrios@dimitrios.duckdns.org
```

A non-standard external port is **not** a security measure — it is a log-noise
measure. It removes essentially all of the drive-by scanning that would otherwise
bury genuine attempts in `journalctl -u ssh`.

Client-side convenience:

```
# ~/.ssh/config
Host home
    HostName dimitrios.duckdns.org
    Port 2222
    User dimitrios
    IdentityFile ~/.ssh/id_dimitrios
```

## What the PAM edit does

For `AuthenticationMethods publickey,keyboard-interactive`, the
keyboard-interactive stage runs PAM. Debian's `/etc/pam.d/sshd` pulls in
`common-auth`, which prompts for the **Unix password** — so left alone, the second
factor would be the account password, not the TOTP code, defeating "keys only".

The role therefore comments out `@include common-auth` in `/etc/pam.d/sshd` and adds
`auth required pam_google_authenticator.so`. That stage becomes TOTP-and-nothing-else.
The module is required **without `nullok`**: a user with no enrolled secret is
denied rather than waved through, which is why the enrolment assert exists.

## fail2ban

`/etc/fail2ban/jail.local` (never `jail.conf` — that gets replaced on upgrade).

- **`backend = systemd`** is not optional on Debian 12+: sshd logs to the journal,
  not `/var/log/auth.log`, and the default `auto` backend can silently pick a log
  file that never updates — a jail that matches nothing while appearing healthy.
- **`ignoreip`** covers loopback, the LAN and the Tailscale CGNAT range. Banning
  yourself from your own LAN is the classic fail2ban self-inflicted wound.
- **`recidive`** catches the patient scanner that paces itself under the per-jail
  `findtime`, escalating repeat offenders to a week.

Be clear about what this buys: against a key-only sshd, fail2ban stops almost
nothing that could otherwise have succeeded. **Key-only auth is the security
boundary; fail2ban makes the evidence readable.**

```sh
sudo fail2ban-client status            # jails
sudo fail2ban-client status sshd       # bans
sudo fail2ban-client set sshd unbanip 192.168.1.50
```

## Still open

- **No jail for Caddy/Immich yet.** Immich is internet-facing and has no 2FA of its
  own (v3.1.0 is password + OIDC only), so repeated `401`s are worth banning. That
  needs access logging turned on in the Caddyfile plus a filter regex, and is
  tracked in CLAUDE.md's TODO rather than half-done here.
- **Tailscale already provides remote SSH** without exposing anything. Public SSH
  is a deliberate choice for a fallback path that does not depend on Tailscale
  being up — worth re-examining if that fallback stops earning its risk.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Permission denied (publickey)` after enabling | The key never landed in `authorized_keys`, or `ssh_key_file` in host_vars names the wrong key. Get in via console/Tailscale and check. |
| Asked for a password despite `PasswordAuthentication no` | That's the **TOTP** prompt (`Verification code:`), not the account password — PAM keyboard-interactive looks similar. |
| Asked for the *account* password at the second stage | The `@include common-auth` edit didn't apply. Check `/etc/pam.d/sshd`. |
| TOTP rejected with correct-looking codes | Clock skew. TOTP needs the host clock accurate within ~30s — check `timedatectl`. |
| Locked out entirely | Console, or `ssh` over Tailscale (`100.91.148.26`), which the Match block leaves key-only. Then `sudo rm /etc/ssh/sshd_config.d/10-hestia.conf && sudo systemctl reload ssh`. |
