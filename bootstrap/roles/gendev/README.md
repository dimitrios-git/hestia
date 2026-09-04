# `gendev` role — m68k-elf GCC + SGDK for Mega Drive homebrew

Installs **[gendev](https://github.com/kubilus1/gendev)**, a self-contained
GCC 9.3.0 cross-compiler targeting `m68k-elf` plus **SGDK** (the Sega Genesis
Development Kit) — the toolchain thecodingidiot's **r02-the-scaler** chapter
needs to build for the Sega Genesis/Mega Drive. Rides **`enable_tci`** (no
toggle of its own — same as the console-emulator entries in the `tci` apt
group and the `blastem` role).

```sh
ansible-playbook site.yml --tags gendev --ask-become-pass -e enable_tci=true
```

## Why a role and not a manifest entry

`gendev` isn't packaged in Debian apt at all. Upstream publishes a GitHub
release with a Linux **`.deb`** asset (`gendev_<ver>_all.deb`) that installs
straight to `/opt/gendev` — exactly the path the chapter's own instructions
assume (`export GENDEV=/opt/gendev`), confirmed by inspecting the `.deb`'s
file list (`dpkg-deb -c`) before ever installing it: ~1000 files rooted at
`./opt/gendev/`.

## What it does

1. Downloads the pinned `.deb` (sha256-verified against `gendev_deb_sha256`
   in `defaults/main.yml`) — same shape as the `openrgb` role.
2. Installs it via `apt: deb:` (not a bare `dpkg -i`), which resolves the
   package's declared `Depends` (`texinfo`, `default-jre`, `make`) against the
   machine's normal apt sources. `default-jre` is the heavy one — SGDK's
   asset-conversion tools are Java-based.
3. Idempotent via `package_facts` — a re-run is a no-op once `gendev` shows up
   installed, same check as `openrgb`.

**Architecture:** the `.deb` declares `Architecture: all`, but that's a
mislabel — its bundled `m68k-elf-gcc` binaries are real x86_64 ELF
executables (`file /opt/gendev/bin/m68k-elf-gcc` confirms it), so apt would
happily "install" it on arm64 and leave a silently non-functional toolchain.
The role guards this explicitly and skips on any arch but `x86_64`.

## Manual afterwards

The chapter's own instructions have the reader `export GENDEV=/opt/gendev`
themselves, once, in their shell rc. This role doesn't inject that into
`.bashrc` — it's a chapter-scoped, personal choice, not a system default —
it just makes sure `/opt/gendev` exists with a working toolchain in it. The
role prints a reminder of the export at the end of the run.

## Bumping the pinned version

gendev's release tags are stable version numbers (unlike BlastEm's nightly
hash-in-filename scheme), so bumping is a straightforward pin update:

1. Check <https://github.com/kubilus1/gendev/releases> for the current tag.
2. Download the new `gendev_<ver>_all.deb`, `sha256sum` it.
3. Update `gendev_version` / `gendev_deb_sha256` in `defaults/main.yml`.
4. The "already installed" check is by package NAME, not version — bumping
   the pin alone won't force a reinstall on a re-run. To force an update:
   `sudo apt remove gendev` first (then re-run the role).

## Updates

Not apt-managed (no repo) — a re-run does **not** upgrade an
already-installed `gendev`. Treat version bumps as occasional, deliberate pin
updates.
