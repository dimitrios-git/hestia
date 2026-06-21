# Samba-over-Tailscale share — deploy runbook

Native Windows Explorer access to a `thetower` folder, fast, reachable over the
**trusted home LAN** (full gigabit) or **Tailscale** (encrypted, for remote) —
confined to those at the SMB layer by `hosts allow/deny`. Replaces the old
SFTP-over-Tailscale share. Design rationale: `docs/file-sharing-design.md`.

This is a **layer-(a) system config**: rendered from `smb.conf.j2` and copied to
`/etc/` (not symlinked). The canonical deploy is the **`samba` Ansible role**
(`ansible-playbook site.yml --tags samba --ask-become-pass`), which renders the
template using `samba_lan_subnet` from host_vars. The steps below are the
equivalent **manual** path (and the role's source of truth).

> Run as `dimitrios` from the repo root. Steps need `sudo` (privileged steps are
> the human's job by design). Review before running.

## Facts (this host)

Placeholders below are redacted — substitute this host's real values (the LAN
subnet lives in `bootstrap/host_vars/localhost.yml`; find the IPs with
`tailscale ip -4` and `ip -o -4 addr`):

- `thetower` Tailscale IP: **`<tailscale-ip>`** (`tailscale ip -4`), interface **`tailscale0`**.
- LAN IP / subnet: **`<lan-ip>`** / **`<lan-subnet>`** (e.g. `192.0.2.0/24`).
- Share path: **`/srv/smbshare`**; dedicated principal: user+group **`smbshare`**.
- Windows mounts: **`\\thetower\share`** (MagicDNS) or **`\\<tailscale-ip>\share`**
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
sudo mkdir -p /srv/smbshare
sudo chown smbshare:smbshare /srv/smbshare
sudo chmod 2770 /srv/smbshare                   # setgid: new files inherit the group
sudo setfacl    -m g:smbshare:rwx /srv/smbshare # current
sudo setfacl -d -m g:smbshare:rwx /srv/smbshare # default (inherited by new files)
```

## 4. Samba password for the share user (interactive)

```sh
sudo smbpasswd -a smbshare      # set a password (this is what Windows authenticates with)
sudo smbpasswd -e smbshare      # enable
```

## 5. Deploy this config

`smb.conf.j2` is a template — substitute this host's LAN subnet for the
`{{ samba_lan_subnet }}` placeholder as you install it (the Ansible role does this
for you from host_vars):

```sh
sudo cp -n /etc/samba/smb.conf /etc/samba/smb.conf.orig   # back up distro default once
LAN_SUBNET=192.0.2.0/24          # <-- this host's LAN subnet
sed -e "s#{{ samba_lan_subnet }}#$LAN_SUBNET#" \
    -e "s#{{ samba_tailscale_cgnat }}#100.64.0.0/10#" \
    system/samba/smb.conf.j2 | sudo install -m 0644 /dev/stdin /etc/samba/smb.conf
sudo testparm -s                 # validate syntax (should print "Loaded services")
```

## 6. Firewall — OPTIONAL (skip it; `hosts allow/deny` is the real control)

Samba 4.22 **won't bind to the Tailscale tun** (`interfaces = lo <ip>/32` +
`bind interfaces only` binds loopback only — the point-to-point `/32` has no
broadcast), so `smbd` **listens on all interfaces** and access is confined at the
**SMB layer** by `hosts allow = 127.0.0.1 <lan-subnet> 100.64.0.0/10` +
`hosts deny = 0.0.0.0/0` (loopback + home LAN + Tailscale may authenticate;
everything else is rejected before auth). The LAN is **deliberately allowed** — on
the trusted home network it gives full gigabit vs the tunnel's ~575 Mbit (see
`docs/file-sharing-design.md` §3.2). A host firewall here is pure
defense-in-depth and is **not required** for this share.

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
timeout 3 bash -c 'cat </dev/null >/dev/tcp/<lan-ip>/445' && echo "LAN OPEN"
timeout 3 bash -c 'cat </dev/null >/dev/tcp/<tailscale-ip>/445' && echo "tunnel OPEN"
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
{ "action": "accept", "src": ["<laptop-tailscale-ip>"], "dst": ["<tailscale-ip>:445"] }
```

## 10. Windows side

Map **two** drives and use whichever fits:
- **Home (full gigabit):** `\\<lan-ip>\share`
- **Remote (over Tailscale):** `\\<tailscale-ip>\share`

Credentials `smbshare` + the password from step 4. (RDP/Remmina is unaffected —
this is only the file-transfer path.)

## Rollback

```sh
sudo systemctl disable --now smbd
sudo mv /etc/samba/smb.conf.orig /etc/samba/smb.conf   # if you want the distro default back
# remove /srv/smbshare, the smbshare user/group, and the Tailscale ACL grant as desired
```
