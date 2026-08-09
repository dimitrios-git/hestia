# Container layer — deploy runbook

The Docker Compose stacks that make this host a media/photo server: **Plex**
(video), **Stash** (video), **Immich** (photos, optionally internet-facing behind
**Caddy** for TLS). Deployed to **`/opt/<app>/`** — where this host has always kept
its container apps, alongside the vendor installs that put themselves there
(`google`, `megasync`, `microsoft`, `TradingView`).

These are **layer-(a) system configs**: rendered from `.j2` and written to
root-owned locations, **not** symlinked — the same shape as `system/samba/`. The
canonical deploy is the **`docker_services` Ansible role**; the steps below are the
equivalent manual path (and the role's source of truth).

> Run as the human from the repo root. Privileged steps need `sudo` by design.

## Layout

| Repo template | Rendered to | Mode |
|---|---|---|
| `system/docker/plex/docker-compose.yml.j2` | `/opt/plex/docker-compose.yml` | 0644 |
| `system/docker/stash/docker-compose.yml.j2` | `/opt/stash/docker-compose.yml` | 0644 |
| `system/docker/immich/docker-compose.yml.j2` | `/opt/immich/docker-compose.yml` | 0644 |
| `system/docker/immich/env.j2` | `/opt/immich/.env` | **0600** |
| `system/docker/immich/Caddyfile.j2` | `/opt/immich/Caddyfile` | 0644 |

Adding a service is a `docker_services` entry in `bootstrap/group_vars/all.yml`
plus a template dir here. No role code changes.

## Secrets

This repo is **public**. Every credential the stacks need lives in
**`bootstrap/host_vars/localhost.yml`**, which is **gitignored**, and is rendered in
at deploy time:

| Var | Used by | Notes |
|---|---|---|
| `immich_db_password` | Immich Postgres | **Never regenerate against an existing database** — Immich would lose access to its own data. `setup.sh` preserves an existing value and only generates one on a fresh setup. |
| `plex_claim` | Plex first claim | A plex.tv claim token is valid for **4 minutes**, so it is useless in version control. Leave empty; set it only for the run that claims a fresh install, then clear it. |
| `duckdns_token` | DuckDNS updater | Lets anyone repoint the subdomain. Regenerate at duckdns.org if it leaks. |

The playbook **asserts** the required ones are non-empty rather than deploying a
broken stack.

## Deploy

```bash
cd bootstrap
ansible-playbook site.yml --tags docker --ask-become-pass          # engine + all stacks
ansible-playbook site.yml --tags docker_services --ask-become-pass # stacks only
ansible-playbook site.yml --tags duckdns                           # DNS updater (no root)
```

`docker compose up -d` is declarative, so re-running is safe: only containers whose
config actually changed are recreated. Set `docker_services_converge: false` to
render the files without starting anything.

**Docker group membership needs a re-login.** The role adds you to `docker` (which
is effectively **root-equivalent** — a member can bind-mount `/` into a container).
The `claude` agent user is deliberately left out; it has no sudo either.

## What stays manual

Deliberately, exactly like `smbpasswd` in the samba role and `tailscale up` in the
tailscale role — one-shot, interactive, or secret-bearing steps are not scripted:

- **Plex**: claiming the server (`plex.tv/claim` → `plex_claim` for one run).
- **Immich**: creating the admin account. There is no self-registration with
  password login and no first-user API worth scripting.
- **Immich**: enabling **NVENC** under *Administration → Settings → Video
  Transcoding → Hardware Acceleration*. The devices are wired up by the template,
  but Immich defaults to CPU until you flip it.
- **Immich**: adding the **External Library** (*Administration → External Libraries*)
  with import path **`/mnt/media/pictures`** — the path **as the container sees it**,
  not the host path.
- **Router**: forwarding ports **80 and 443** when `immich_domain` is set.

## Immich: the external library, and the nesting trap

`immich_external_library` is mounted **read-only** (`:ro`), so Immich indexes the
existing photo tree in place and can never modify or delete it. That makes trying
Immich fully reversible — but note the trade-offs:

- Metadata and edits made in Immich stay in **its database only**; they are never
  written back to the files. XMP sidecars don't work on a read-only mount.
- Moving a file within the tree makes Immich treat it as a **new asset** on rescan,
  losing anything attached to it.

On this host `immich_upload_location` is **nested inside** the external library
(`…/Pictures/Immich` inside `…/Pictures`). That is supported, but the External
Library **must** carry the exclusion pattern:

```
**/Immich/**
```

Without it, Immich indexes its own generated thumbnails as new assets on every scan
— the library grows without bound. The `:ro` flag does **not** prevent this: the two
bind mounts are independent, and writes to `/data` succeed regardless.

## Immich: managed library vs. external library

A point that surprises people coming from Plex/Stash: **Immich's managed library is
not a folder you organise.** Plex and Stash scan a tree you arrange; Immich *owns*
`UPLOAD_LOCATION` and files must arrive through the API (mobile app, web, or CLI).
Copying files into it does nothing — they will not appear.

To migrate from the read-only external library to a managed one:

```bash
npm i -g @immich/cli
immich login http://<host>:2283/api <api-key>     # Account Settings -> API Keys
immich upload --dry-run --recursive /path/to/folder
immich upload --album --recursive /path/to/folder  # --album = one album per source folder
```

Delete the external library **first** or every photo exists twice. Don't use
`--delete` on the first pass — verify the uploads landed, then remove originals by
hand. Immich re-derives its own faces and metadata; **digiKam face tags and labels do
not transfer** (they live in `digikam4.db` / `recognition.db` in a format Immich
can't read — keep those files until you're sure).

## TLS / public exposure

`immich_domain` empty (the default) = **no Caddy service at all**, Immich LAN-only on
port 2283. Setting it adds Caddy, which obtains and renews a Let's Encrypt
certificate automatically.

- **Port 80 is not optional** — it carries the HTTP-01 challenge *and* the
  http→https redirect, and renewal (~30 days before expiry) needs it to stay open.
- Forward **only 80 and 443**. Never forward 2283: that bypasses Caddy and serves
  Immich in plaintext.
- Certificates persist in the `caddy-data` volume. Losing it re-requests on every
  restart and runs into Let's Encrypt rate limits.
- Let's Encrypt will not certify a **bare IP**, which is why a hostname (DuckDNS
  here) is required even on a static-IP host.

**Immich has no built-in 2FA** (v3.1.0: `passwordLogin` + OIDC only) and no
public-registration toggle — with password login, only an admin creates accounts.
An internet-facing instance therefore rests on one long password and staying
patched. For real 2FA the route is an OIDC provider (Authelia/Authentik) in front,
with Caddy `forward_auth`.

## Updating

```bash
cd /opt/immich && sudo docker compose pull && sudo docker compose up -d
```

`immich_version` defaults to `release`, which is **rolling** — a `pull` can cross a
major version with one-way database migrations. Pin it to a tag (e.g. `v3.1.0`) in
host_vars for reproducible restarts, and read the release notes before moving it.
Back up `immich_db_data_location` (the Postgres dir) before a major bump.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `ECONNREFUSED …:5432` on first boot | The server raced Postgres through `initdb`. Harmless — `restart` recovers it. The `condition: service_healthy` in the template is what prevents it on subsequent cold boots. |
| `SSL_ERROR_RX_RECORD_TOO_LONG` | Browser spoke HTTPS to a plaintext port. Use `https://<domain>` with no port, not `:2283`. |
| ACME `Timeout during connect` | 80/443 are not reaching the host — check the router forwards, then whether the ISP blocks inbound 80/443 (common on residential lines; the fix is a DNS-01 challenge, which needs a Caddy image built with the DuckDNS plugin). |
| Caddy: `address already in use` on :80 | Something else owns port 80 — on Debian, often `apache2` pulled in as a dependency of `libapache2-mod-php`. `sudo systemctl disable --now apache2`. |
| Thumbnails feel slow | They live under `immich_upload_location`. On a spinning/pooled volume that is the bottleneck; relocating just the thumbnail dir to SSD is the fix. |
