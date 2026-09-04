# `blastem` role — Genesis/Mega Drive emulator, official tarball

Installs **[BlastEm](https://www.retrodev.com/blastem/)**, the Genesis/Mega
Drive emulator thecodingidiot's **r02-the-scaler** chapter tests homebrew
against, as the **official self-contained tarball** into `~/.local/share`, no
root needed. Rides **`enable_tci`** (no toggle of its own).

```sh
ansible-playbook site.yml --tags blastem -e enable_tci=true
```

## Why a role and not the `tci` apt group (course correction, 2026-09-04)

Hestia originally shipped `blastem` as an ordinary `tci` apt group entry
(#331/#332) — the wrong call. When r02-the-scaler landed, its own Setup page
said, verified directly:

> Use the **official tarball release**, not a distro package. Debian's own
> `blastem` package splits its config file across `/etc/blastem/` and
> `/usr/share/games/blastem/` in a way that only resolves correctly through
> `dpkg`'s own install process — a plain download-and-run of the binary can't
> find its config.

Since hestia's whole point for this apt group is testing thecodingidiot's own
homebrew, the fix is to match what the chapter actually tells readers to do,
not what happened to be convenient (`apt install blastem`). If you deployed
an earlier hestia revision with `enable_tci: true`, remove the stale apt
package by hand — Ansible's `apt` module never removes a package that falls
out of a list:

```sh
sudo apt remove --purge blastem
sudo apt autoremove
```

## What it does

1. Downloads the pinned nightly tarball (sha256-verified against
   `blastem_sha256` in `defaults/main.yml`).
2. Extracts it into a stable `~/.local/share/blastem` (`--strip-components=1`
   drops the upstream archive's version-hash-named top directory). The
   **whole** archive is extracted, not just the `blastem` binary — it needs
   its sibling `default.cfg`/`shaders/` alongside it, confirmed by the
   chapter's own description of the tarball as "one self-contained
   directory". This is why `localbin_binaries`' generic single-member
   extraction (used for yazi, zellij, ...) doesn't fit here.
3. Patches `default.cfg`: `vsync off` → `on`, `gl on` → `off` — both the
   chapter's own recommendation, baked in by default rather than left
   optional. `vsync off` pops a **blocking** startup dialog outright on a
   driver that can't support it; `gl off` forces SDL2's software renderer
   instead of BlastEm's own GL path, avoiding the same class of dialog. A
   real risk on this desktop's NVIDIA/Wayland setup (see
   `docs/tool-configurations.md`'s Sway section) — hestia would rather a
   fresh install never hit a blocking dialog than look prettier on a machine
   that happens to have working GL.
4. Symlinks `~/.local/bin/blastem` → the extracted directory's binary.
   BlastEm resolves its own resource files relative to its **real** binary
   location (confirmed by the chapter's own `BLASTEM=/path/to/blastem`
   env-var pattern in `06-where-things-stand.mdx`, which only makes sense if
   the binary can be referenced from anywhere and still find its config), so
   a symlink works — no wrapper script needed.
5. Idempotent via a per-version marker at
   `~/.local/state/hestia/blastem-<version>` — same shape as the `localbin`
   role's markers. A version bump re-extracts (removing the old directory
   first); a manual `rm` of the marker also forces a re-extract.

**Architecture:** x86_64 only — retrodev.com only publishes a `blastem64`
nightly build. The role skips other arches.

## Bumping the pinned version

BlastEm's nightlies have no GitHub Releases API and no predictable "latest"
URL — the filename embeds a short git commit hash that changes every
nightly build:

1. Browse <https://www.retrodev.com/blastem/nightlies/> for the current
   `blastem64-*.tar.gz`.
2. Download it, `sha256sum` it.
3. Update `blastem_version` / `blastem_sha256` in `defaults/main.yml`.

## Updates

Not apt-managed — a re-run does **not** upgrade an already-extracted
version. Treat version bumps as occasional, deliberate pin updates, same as
`gendev`/`openrgb`.
