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

Two things worth saying in the prose, because they are the usual failure modes:
the **plugdev re-login**, and that **udev rules only bind devices plugged in
afterwards**. A reader who plugs the TL866 in first and skips the re-login gets
permission errors that look like a broken build.

WSL caveat worth checking before publishing: WSL2 has no native USB passthrough —
reaching a USB programmer needs [usbipd-win](https://github.com/dorssel/usbipd-win)
on the Windows side, and udev under WSL is [not started by default in older
builds](https://learn.microsoft.com/en-us/windows/wsl/wsl-config). Building
minipro under WSL works fine; *talking to the hardware* may not, and the chapter
should probably say so rather than let a WSL reader discover it mid-project.
