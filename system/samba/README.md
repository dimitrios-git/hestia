# Samba-over-Tailscale share — deploy runbook

Native Windows Explorer access to a `thetower` folder, fast, reachable **only**
over the Tailscale tunnel. Replaces the old SFTP-over-Tailscale share. Design
rationale: `docs/file-sharing-design.md`.

This is a **layer-(a) system config**: deployed by **copy** to `/etc/` (not
symlinked). The steps below are the manual precursor to the planned Ansible role.

> Run as `dimitrios` from the repo root. Steps need `sudo` (privileged steps are
> the human's job by design). Review before running.

## Facts (this host)

- `thetower` Tailscale IP: **`100.91.148.26`**, interface **`tailscale0`**.
- Share path: **`/srv/share`**; dedicated principal: user+group **`smbshare`**.
- Windows mounts: **`\\thetower\share`** (MagicDNS) or **`\\100.91.148.26\share`**
  (by IP — use this if MagicDNS is flaky; see the resolv.conf health note).

## 1. Install Samba

```sh
sudo apt update && sudo apt install -y samba
```

## 2. Dedicated share principal (least privilege, no login)

```sh
sudo groupadd -f smbshare
# system account, no home, no shell — Samba-only identity:
sudo useradd -r -M -s /usr/sbin/nologin -g smbshare smbshare 2>/dev/null || true
sudo usermod -aG smbshare dimitrios          # local access for you (re-login to take effect)
```

## 3. Share directory with setgid + default ACLs

```sh
sudo mkdir -p /srv/share
sudo chown smbshare:smbshare /srv/share
sudo chmod 2770 /srv/share                   # setgid: new files inherit the group
sudo setfacl    -m g:smbshare:rwx /srv/share # current
sudo setfacl -d -m g:smbshare:rwx /srv/share # default (inherited by new files)
```

## 4. Samba password for the share user (interactive)

```sh
sudo smbpasswd -a smbshare      # set a password (this is what Windows authenticates with)
sudo smbpasswd -e smbshare      # enable
```

## 5. Deploy this config

```sh
sudo cp -n /etc/samba/smb.conf /etc/samba/smb.conf.orig   # back up distro default once
sudo install -m 0644 system/samba/smb.conf /etc/samba/smb.conf
sudo testparm -s                 # validate syntax (should print "Loaded services")
```

## 6. Firewall — OPTIONAL (skip it; the interface bind is the real control)

`bind interfaces only = yes` already confines `smbd` to `lo` + `tailscale0`, so
it is never exposed on the LAN regardless of any firewall. A host firewall here
is pure defense-in-depth and is **not required** for this share.

Note: **don't install ufw** — it's an Ubuntu-origin frontend, not Debian-native.
Debian's native framework is **nftables** (already installed; `nft`). Tailscale
manages its own netfilter rules (`NetfilterMode 2`), so any host firewall must be
written to coexist (allow `tailscale0`, loopback, established — don't drop the
tunnel). If a host-level default-deny is ever wanted, add a **tracked
`system/nftables/nftables.conf`** rather than ad-hoc rules. For now, skip this
step.

## 7. Start — and always RESTART after a config change

`enable --now` does NOT restart an already-running smbd (the apt install starts
it with the default config), so it would keep the old bind. Use `restart`:

```sh
sudo systemctl enable smbd
sudo systemctl restart smbd          # picks up our interfaces/bind config
sudo systemctl --no-pager status smbd
```

Disable the services the `samba` metapackage pulls in but a standalone file
share does NOT need (less attack surface): the AD domain controller and NetBIOS.

```sh
sudo systemctl disable --now samba-ad-dc nmbd     # AD DC + NetBIOS name service
# winbind (domain membership) is also unneeded for standalone; left enabled is
# harmless, but it can be disabled too if you also clean its nsswitch.conf entry.
```

## 8. Verify it's listening and reachable

Samba 4.22 won't bind to the tun, so smbd listens on all interfaces; `hosts
allow/deny` confines who may authenticate (loopback + LAN + Tailscale).

```sh
ss -tln 'sport = :445'                                             # expect 0.0.0.0:445
timeout 3 bash -c 'cat </dev/null >/dev/tcp/192.168.0.100/445' && echo "LAN OPEN"
timeout 3 bash -c 'cat </dev/null >/dev/tcp/100.91.148.26/445' && echo "tunnel OPEN"
```

Both should be OPEN; a client outside `hosts allow` is rejected before auth.

## 9. Tailscale ACL — usually NOTHING to do

Tailscale's **default policy is allow-all** between your own nodes. Unless you
have *deliberately* written a restrictive ACL, the ThinkPad can already reach
`thetower:445`, and **no change is needed** — the security comes from
`hosts allow/deny` + SMB auth, not from a Tailscale ACL. (Your old "SFTP only via
Tailscale" was the *service binding*, like this share, not a Tailscale rule.)

Only if you maintain a custom ACL (admin console → **Access controls**), add a
grant for tcp/445 from the laptop to thetower:

```jsonc
{ "action": "accept", "src": ["100.74.39.11"], "dst": ["100.91.148.26:445"] }
```

## 10. Windows side

Map **two** drives and use whichever fits:
- **Home (full gigabit):** `\\192.168.0.100\share`
- **Remote (over Tailscale):** `\\100.91.148.26\share`

Credentials `smbshare` + the password from step 4. (RDP/Remmina is unaffected —
this is only the file-transfer path.)

## Rollback

```sh
sudo systemctl disable --now smbd
sudo mv /etc/samba/smb.conf.orig /etc/samba/smb.conf   # if you want the distro default back
# remove /srv/share, the smbshare user/group, and the Tailscale ACL grant as desired
```
