# `openrgb` role — ASUS Aura USB motherboard RGB control

Installs **OpenRGB**, the open-source RGB lighting controller, to drive the
**Aura USB** LED controller most ASUS motherboards have shipped internally
since the X470 generation — onboard lighting plus the 12V RGB / 5V ARGB
headers, all one USB HID device wired through an internal header (no external
cable). Opt-in and **off by default** (`enable_openrgb: false`), and
**hardware-detected** by `setup.sh` — it probes for the USB `(vendor,product)`
pair `0b05:19af` in sysfs and pre-answers the prompt, the same shape as the
`nvidia`/`razer` detection.

## What it does

1. Downloads OpenRGB's own pinned **Debian trixie `.deb`** from its Codeberg
   release (sha256-verified against `openrgb_deb_sha256` in
   `defaults/main.yml`) — **not** an apt repo. `openrgb` isn't in Debian
   trixie's stable apt (only `sid`, checked 2026-08), and upstream doesn't
   publish one either; this is a single pinned file, not the unpinnable
   rolling-latest `.deb` shape the `trading`/`mega` roles deal with (OpenRGB
   tags real, fixed release assets, so a normal version-bump pin works).
2. Installs it via `apt` from the local path, which resolves `Depends`
   (libqt5\*, libhidapi, libmbedtls, ...) against the machine's normal apt
   sources — all satisfiable from trixie's stable repo, no extra source
   needed.
3. The package's own postinst installs the udev rules
   (`/usr/lib/udev/rules.d/60-openrgb.rules`, `TAG+="uaccess"` via
   systemd-logind) — confirmed live that **no `plugdev`-style group** is
   needed (unlike the `razer` role), and access works in the same session
   with no reboot.
4. Deploys a tracked XDG autostart entry (`files/OpenRGB-autostart.desktop` →
   `~/.config/autostart/OpenRGB.desktop`), reasserted every run so it
   self-heals. Same shape as what OpenRGB's own `--autostart-enable` writes
   (verified live — a plain autostart `.desktop`, no systemd unit involved),
   just reproducible from the repo instead of an imperative one-off CLI call.

**Architecture:** amd64-only (matches the upstream `.deb` build); the role
skips other arches.

## The I2C/SMBus warning is expected, ignore it

`openrgb --list-devices` prints a warning about I2C/SMBus interfaces failing
to initialize — that's for RGB **DRAM** and **GPU** control via SMBus, which
needs the `i2c-dev` + `i2c-piix4`/`i2c-i801` kernel modules loaded. The Aura
USB controller doesn't go through I2C at all (it's a native USB HID device),
so it works regardless of that warning. Only chase it if you also want
OpenRGB to control RAM/GPU lighting.

## Razer overlap

OpenRGB also detects any connected Razer gear (Mouse Dock, mice, ...) via HID
— it's not blind to them, it just isn't asked to do anything with them here.
**Polychromatic** (the `razer` role) already owns Razer lighting; don't drive
the same device from both tools at once.

## No default effect

The role autostarts OpenRGB, but picks no colour, effect, or profile for you —
that's a personal/aesthetic choice, not a reproducibility one. Out of the box
the autostart entry is just `openrgb --startminimized` (tray-only, applies
nothing). To make a specific look persist across logins:

1. Set it up in the OpenRGB GUI, then **Settings > Save Profile** (as
   `<name>.orp`).
2. Add `--profile <name>` to the `Exec=` line in
   `files/OpenRGB-autostart.desktop` and re-run the role (or edit
   `~/.config/autostart/OpenRGB.desktop` directly for a quick local test —
   the next role run will overwrite it with whatever the repo file says).

Many of OpenRGB's *modes* (static, breathing, rainbow, ...) run on the Aura
controller's own onboard MCU once set, and keep going even without OpenRGB
running or after a reboot — same as AURA Sync/Armoury Crate on Windows. The
autostart entry mainly matters for reapplying `Direct` mode (per-LED colours
pushed live by OpenRGB itself) or a profile that spans multiple devices.

## Variables

| var | default | meaning |
|---|---|---|
| `enable_openrgb` | `false` | gate the role (group_vars/host_vars; `setup.sh` asks, hardware-detected) |
| `openrgb_version` | `1.0rc3` | upstream release tag (the `release_candidate_<ver>` part of the Codeberg URL) |
| `openrgb_commit` | `6fbcf62` | short git commit suffix in the release asset's filename |
| `openrgb_deb_sha256` | (pinned) | sha256 of the exact `.deb`, computed at pin time (upstream publishes none) |

## Run standalone

```sh
ansible-playbook bootstrap/site.yml --tags openrgb -e enable_openrgb=true
```

## Bumping the pinned version

OpenRGB's release filenames carry a git commit hash, so there's no predictable
"latest" URL to template — bump by hand:

1. Check <https://openrgb.org/releases.html> for the current trixie amd64
   build, or browse the Codeberg release tags directly.
2. `wget` the new `.deb`, `sha256sum` it.
3. Update `openrgb_version` / `openrgb_commit` / `openrgb_deb_sha256` in
   `defaults/main.yml`.
4. The "already installed" check is by package NAME, not version, so bumping
   the pin alone won't force a re-install on a re-run. To force an update:
   `sudo apt remove openrgb` first (then re-run the role), or just `dpkg -i`
   the new `.deb` by hand.

## Updates

Not apt-managed (no repo) — a re-run of this role does **not** upgrade an
already-installed `openrgb` (see the bump note above). Treat version bumps as
occasional, deliberate pin updates, not something `apt upgrade` handles.
