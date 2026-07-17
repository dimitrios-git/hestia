# `mega` role — MEGA Desktop (MEGAsync)

Installs **MEGA Desktop** (`megasync`) from MEGA's official signed apt repo.
Opt-in and **off by default** (`enable_mega: false`) — a proprietary cloud-sync
client, a per-host choice like `chrome`/`trading`.

## What it does

Same vendor-repo shape as the `chrome` / `firefoxpwa` / `tailscale` roles (root,
`become`):

1. Installs the MEGA signing key (ASCII-armored) to
   `/usr/share/keyrings/meganz.asc` — no dearmor (trixie apt reads armored
   `.asc` in `signed-by`).
2. Writes `/etc/apt/sources.list.d/megasync.list` pointing at MEGA's **flat**
   repo for the running Debian release (`…/repo/Debian_<VERSION_ID>/ ./` — the
   trailing `./` is the flat-repo marker; the version is auto-detected from
   `/etc/os-release`, so the path tracks the machine).
3. `apt install` the packages in `mega_packages` (default: `megasync`).

**Architecture:** the repo publishes **amd64 and arm64**; the role runs on both
and self-skips other arches (i386/armhf have no vendor build).

**Signing key (verify):** MegaLimited `<support@mega.co.nz>`, fingerprint
`B01C 8118 8048 0C85 4C73 EC7E 1A66 4B78 7094 A482` (rsa4096, expires
2032-01-10).

## Variables

| var | default | meaning |
|---|---|---|
| `enable_mega` | `false` | gate the role (group_vars/host_vars; `setup.sh` asks) |
| `mega_packages` | `[megasync]` | packages to install from the repo |

Add a file-manager integration by overriding `mega_packages` in host_vars — e.g.
`[megasync, nemo-megasync]` for the nemo right-click menu + sync emblems (hestia's
default GUI FM is nemo). Other integrations in the repo: `nautilus-megasync`,
`thunar-megasync`, `dolphin-megasync`, plus `megacmd` (CLI). A FM integration
Depends on that FM being installed, so only add it when the matching file manager
is present (nemo rides `enable_file_managers`).

## Run standalone

```sh
ansible-playbook bootstrap/site.yml --tags mega -e enable_mega=true
```

## Manual (stays yours — the role only installs)

Launching + signing in + choosing what syncs is **in-app on first run**, like
`smbpasswd` / `tailscale up`:

1. Start **MEGAsync** (app menu, or `megasync &`), sign into your MEGA account.
2. Add a **synced folder** and point it at your storage location — e.g.
   `/mnt/cloud-data/files/MEGA` (create the directory first; the role does not,
   as it is host-specific storage).

The account, sync pairs, and bandwidth settings all live in MEGAsync's own
config under `~/.local/share/data/Mega Limited/` — not tracked here.

## Updates

apt-managed — `megasync` updates with `apt upgrade` (a re-run of this role
reasserts the reproducible key + sources file). No manual `.deb` re-download.
