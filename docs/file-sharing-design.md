# Design: thetower ↔ Windows file sharing (Samba over Tailscale + ACLs)

> **Status:** Draft design — replaces the pre-distro-hop SFTP share, not yet
> implemented. Like `claude-user-design.md`, written thoroughly enough to feed
> both the Debian bootstrap effort and the planned LinkedIn write-up.

## 1. Context & current state

- **`thetower`** (Debian / Sway, daily driver) needs to exchange files with a
  **dedicated Windows laptop on the LAN**, which `dimitrios` controls via
  **Remmina (RDP)**.
- **Why not Remmina's own file sharing:** RDP drive redirection (Remmina's
  built-in host↔client sharing) is **very slow**.
- **Current path:** **SFTP**, deliberately restricted to the **Tailscale**
  (WireGuard mesh) tunnel — only SFTP (tcp/22) is allowed between the two
  tailnet nodes. Faster than RDP redirection, but **Windows Explorer can't mount
  SFTP natively**, so it needs a client (WinSCP / SSHFS-Win) — the standing
  inconvenience.

## 2. Goal

Native **Windows File Explorer** access (mapped network drive), fast, **without
weakening** the "only over Tailscale, never the raw LAN" security posture.

## 3. Decision — Samba (SMB) confined to the tunnel, POSIX ACLs

Decided: **Samba**, listening **only on the Tailscale interface**, with **POSIX
ACLs** as the permission model.

### 3.1 Why Samba over SFTP
- Windows Explorer mounts SMB **natively** (`\\<tailscale-host>\share` → drive
  letter) — removes the client inconvenience that is *intrinsic* to SFTP.
- **Fast** over Tailscale: WireGuard is low-overhead and usually establishes a
  **direct peer-to-peer** path between the two nodes (not relayed), so near-LAN
  speed.
- Honours **POSIX ACLs** → one uniform permission model shared with the
  `claude` `/srv/dev` tree (see `claude-user-design.md` §4.3). No bind mounts:
  the SFTP chroot that *forced* bind mounts in the old setup is gone.

### 3.2 Security — LAN + Tailscale, confined at the SMB layer
**Reality check (Samba 4.22): interface-binding does not work** — Samba refuses
to bind to the Tailscale tun device (`interfaces = lo <ip>/32` + `bind interfaces
only` binds loopback only, point-to-point `/32`, no broadcast). So:
- **smbd listens on all interfaces**, and access is confined at the **SMB layer**
  by `hosts allow = 127.0.0.1 192.168.0.0/24 100.64.0.0/10` + `hosts deny =
  0.0.0.0/0`: only loopback, the **trusted home LAN**, and the **Tailscale** range
  may authenticate; everything else is rejected before auth.
- **Why the LAN is allowed (decision, 2026-06-19):** Tailscale *always*
  WireGuard-encrypts, even on a same-LAN path, capping throughput (~575 Mbit vs
  the LAN's 950 — proven by iperf3). On the controlled home LAN the security cost
  of direct SMB is minimal and the speed win is ~2×, so we map **two Windows
  drives**: the LAN IP (`\\192.168.0.100\share`, full gigabit) when home, the
  Tailscale IP (`\\100.91.148.26\share`) when remote.
- A tunnel-only variant (block the LAN with an `nftables` `445` drop) was built
  and then **dropped** with this decision — the LAN is wanted, not blocked.
- **Tailscale ACL:** nothing to do (default allow-all between your own nodes).
- **Protocol floor:** `server min protocol = SMB3`; SMB1 disabled.
- **Dedicated principal:** `smbshare` — own `smbpasswd`, a least-privilege
  `nologin` account, scoped to the share path.

### 3.3 Permission model (ACLs — no bind mount, no force-user)
- Share path **`/srv/share`** (the existing `/srv` convention), owned by group
  **`smbshare`**, **setgid** (`2770`), with **default ACLs**
  (`setfacl -d -m g:smbshare:rwx`) so new files inherit group + rw.
- **Both principals share via the group:** `dimitrios` is added to `smbshare`
  (needs a re-login / `newgrp` to take effect) and the Samba user *is* `smbshare`.
  Files from either side inherit group `smbshare` + rwx, so each can read/write
  the other's files — bidirectional, with **no bind mount and no `force user`**.
- **`~/Public` continuity:** `~/Public` is a **symlink to `/srv/share`** — the
  ACL-era replacement for the old bind mount (a lightweight pointer, not a kernel
  mount). The familiar XDG public folder still works while the share path stays
  neutral and outside the now-`750` home.

### 3.4 Outcome (deployed 2026-06-19)
Working end to end: the ThinkPad maps the share natively in Explorer. `iperf3`
settled the speed question definitively: the LAN does full **gigabit (950 Mbit)**
both ways, the Tailscale tunnel ~**575 Mbit** (WireGuard's userspace-CPU cost on
the laptop). So the ~40 MB/s seen over the tunnel is the *tunnel's* cost — not
Samba, disk (thetower NVMe reads 2 GB/s), or the NICs (both link at gigabit).
That result is exactly what drove the two-mapping decision: **LAN IP for full
gigabit at home, Tailscale for remote.**

## 4. What gets retired / changed
- **Not carried over** from the pre-hop system: the `sshd_config`
  `Match User sftpuser` chroot block and the `fstab` bind mount of
  `/home/dimitrios/Public` (they lived only on the old install).
- **Tailscale ACL:** no change needed — default allow-all already permits SMB
  between your nodes (see §3.2).
- **Optional:** keep SFTP/SSH as a secondary CLI path if ever wanted; not
  required, since both machines live on the tailnet.

## 5. Honest trade-offs
- **SMB listens on the LAN, and we deliberately allow LAN clients** (the home LAN
  is trusted). Mitigated by `hosts allow/deny` (only loopback + LAN + Tailscale
  may authenticate) + SMB3 + a dedicated `nologin` principal. For a controlled
  LAN this is acceptable, and the payoff is full gigabit vs the tunnel's ~575
  Mbit.
- **Remote access** still rides Tailscale (encrypted), at ~575 Mbit. Off-LAN /
  off-tailnet access isn't provided — both fine for this use.

## 6. Reproducibility / bootstrap & an open question
Bootstrap steps: `apt install samba`; create the `smbshare` user/group + add
`dimitrios` to it; `mkdir /srv/share` + setgid + default ACLs; `smbpasswd` the
user; copy `smb.conf` to `/etc`; `systemctl restart smbd` and **disable** the
unneeded `samba-ad-dc` + `nmbd`; symlink `~/Public → /srv/share`. Step-by-step:
`system/samba/README.md`.

**Open point — tracking `/etc` configs.** `smb.conf` (and, when we touch it,
`sshd_config`) live in `/etc`, not a user home — they don't fit the repo's
"symlink into `~`/`~/.config`" convention. This is the same question the
systemd-units and bootstrap items raise: the repo is growing from *user dotfiles*
toward *whole-system reproducibility*. Decide a convention (e.g. a `system/` or
`etc/` tree the bootstrap **copies** into place with root, rather than
symlinks) — tracked as part of the bootstrap effort.
