# `minipro` role — EEPROM programmer CLI, built from source

Installs **[minipro](https://gitlab.com/DavidGriffith/minipro)**, the open-source
CLI for the **TL866xx / T48 / T56** family of EEPROM programmers. Required by
thecodingidiot's **f03b-the-2600-hardware** chapter to burn assembled 6502
binaries onto an AT28C256.

Opt-in via **`enable_minipro`** (default `false`) — it is hardware-specific and
useless without a programmer on the USB bus.

```sh
ansible-playbook site.yml --tags packages,minipro --ask-become-pass
```

`packages` is included because the build dependencies come from the manifest's
`minipro` apt group, not from this role.

## Why a role and not a manifest entry

**`minipro` is not packaged for Debian or Ubuntu.** Verified 2026-08-09:

| Source | Query | Result |
|---|---|---|
| packages.debian.org | all suites (bookworm, trixie, sid, experimental), all components | **no match** |
| packages.ubuntu.com | all releases, all components (main/universe/multiverse) | **no match** |
| local `apt-cache` on trixie | `main contrib non-free non-free-firmware` enabled | **no match** |

So `sudo apt install minipro` fails on **every** target — Debian, Ubuntu, and
Ubuntu-under-WSL alike. Build-from-source is the only install path, which is the
same situation as the `video_compare` role and the reason this is a role.

## What it does

1. Installs build deps from the `minipro` apt group: `pkg-config`,
   `libusb-1.0-0-dev`, `zlib1g-dev` (`build-essential` and `git` are already core).
2. Clones the pinned tag (`minipro_version`, currently **0.7.4**, released
   2025-08-02) into a temp dir, `make`, `make install PREFIX=/usr/local`.
3. Installs the shipped **udev rules** to `/etc/udev/rules.d/`, then reloads and
   retriggers udev. Without these the programmer node is root-only and every
   `minipro` call needs `sudo`.
4. Adds the user to **`plugdev`**, the group those rules grant access to.

Idempotent via a per-version marker at `/var/lib/hestia/minipro/<version>`; bump
`minipro_version` to rebuild.

### The udev trap (verified against 0.7.4, 2026-08-09)

`make install` *appears* to handle udev rules itself, but on Debian it silently
does not. The Makefile guards that step with `if [ -n "$(UDEV_DIR)" ]`, and

```make
UDEV_DIR = $(shell pkg-config --variable=udevdir udev)
```

needs **`udev.pc`** — which on trixie ships in **`systemd-dev`**, *not* in
`libudev-dev`. Nothing pulls `systemd-dev` in, so `pkg-config` returns empty, the
entire udev block is skipped, and the programmer stays root-only with **no error
message**. The failure looks like broken hardware or a bad build.

So the role installs the rules explicitly, to `/etc/udev/rules.d/` — the
admin-precedence location, and what upstream's README tells users to do anyway.
That step is load-bearing; don't "simplify" it away as duplicating `make install`.

All **three** rules are installed, because they are complementary, not
alternatives:

| Rule | Does |
|---|---|
| `60-minipro.rules` | tags matching USB devices with `ENV{ID_MINIPRO}="1"` |
| `61-minipro-plugdev.rules` | `MODE="660" GROUP="plugdev"` on anything so tagged |
| `61-minipro-uaccess.rules` | `TAG+="uaccess"` — logind grants the active seat's user |

`60` alone grants no access at all; either `61` supplies it. Installing just the
first leaves the device unreadable.

`/usr/local` rather than `~/.local` (where `video_compare` lands) because this
install is root-bound anyway — the udev rules live in `/etc`.

## Manual afterwards

- **Re-login.** `plugdev` membership only applies to new sessions.
- **Plug the programmer in after the rules are installed**, or run
  `sudo udevadm trigger`. Rules only apply to devices that enumerate after they
  load.
- **T56 owners:** `sudo make install-algorithm` downloads extra algorithm data.
  Not run here — it is a network fetch specific to one model.

Nothing in this role can verify a working burn; it installs the toolchain, not a
device.

## Note for the thecodingidiot chapter

`f03b-the-2600-hardware/01-setup.mdx` currently says:

> `minipro` is the open-source CLI for the TL866II Plus programmer. Install it
> from the apt repository: `sudo apt install minipro`

**That command fails for every reader.** The chapter targets Linux
(Debian/Ubuntu) and WSL (Ubuntu), and the package exists in neither. The
replacement it needs is upstream's own procedure:

```sh
sudo apt install build-essential pkg-config git libusb-1.0-0-dev zlib1g-dev
git clone https://gitlab.com/DavidGriffith/minipro.git
cd minipro
make
sudo make install

# non-root access to the programmer
sudo cp udev/*.rules /etc/udev/rules.d/
sudo udevadm trigger
sudo usermod -a -G plugdev $USER   # takes effect after the next login
```

Note the `cp udev/*.rules` line is **not optional and not redundant** with
`sudo make install`, for the reason in *The udev trap* above — on Debian the
Makefile's own udev step silently no-ops. A reader who trusts `make install`
alone ends up with a root-only device.

Three things worth saying in the prose, because they are the usual failure modes:
the **plugdev re-login**; that **udev rules only bind devices plugged in
afterwards** (or after `udevadm trigger`); and that the rules must be copied
**explicitly**. A reader who plugs the TL866 in first and skips the re-login gets
permission errors that look like broken hardware.

WSL caveat worth checking before publishing: WSL2 has no native USB passthrough —
reaching a USB programmer needs [usbipd-win](https://github.com/dorssel/usbipd-win)
on the Windows side, and udev under WSL is [not started by default in older
builds](https://learn.microsoft.com/en-us/windows/wsl/wsl-config). Building
minipro under WSL works fine; *talking to the hardware* may not, and the chapter
should probably say so rather than let a WSL reader discover it mid-project.
