# `android_studio` role — Android development environment

Installs **Android Studio** + puts the deploy user in the **`kvm`** group for
accelerated emulation. Opt-in and **off by default** (`enable_android_dev:
false`) — a per-host dev-toolchain choice, same rationale as `enable_golang`.
Raised by the thecodingidiot Android app work (a React Native/Expo app, first
Android project on this host), but nothing here is thecodingidiot-specific —
it's generic Android dev tooling.

## What it does

1. The apt-only pieces (`openjdk-21-jdk` — needed for Gradle/`npx expo
   run:android`; **21, not 17** — Debian trixie's apt doesn't carry 17 at all,
   only 21/25, verified 2026-08-14 via `apt-cache search`; 21 is the current
   LTS and fully supported by AGP/Gradle, 25 felt needlessly bleeding-edge;
   `cpu-checker` — provides `kvm-ok`) live in the manifest
   (`apt_packages.android`, gated by `enable_android_dev` via
   `package_group_features`), same split as the `docker` role: the shared
   `packages` role installs them in one resolver pass, this role does the
   parts apt does not.
2. Adds the deploy user to the **`kvm`** group (`/dev/kvm` is `root:kvm`
   `0660`) — without this the Android Emulator falls back to slow
   unaccelerated rendering, or Android Studio's own AVD Manager reports no
   acceleration at all. **Not** root-equivalent (unlike `docker`'s group),
   just `/dev/kvm` access. Whether the CPU/BIOS actually supports
   virtualization is a separate, informational check (`kvm-ok`, from
   `cpu-checker`) — this role doesn't gate on it, since Android Studio + `adb`
   is still useful for a real USB-connected device even without a fast
   emulator.
3. Downloads Android Studio's own pinned Linux tarball (**sha256-verified** —
   see *Bumping the pinned version* for how that hash was obtained; Google
   ships no apt package or repo, so this is the same pinned-download shape as
   `gtk_theme`'s adw-gtk3) and installs it as `~/.local/share/android-studio`
   — no root. A version bump removes the previous install wholesale before
   installing the new one (no accumulation), same posture as the rest of the
   repo's pinned-download roles.
4. Deploys a rendered app-menu launcher
   (`templates/android-studio.desktop.j2` → `~/.local/share/applications/
   android-studio.desktop`), reasserted every run so it self-heals.

## Deliberately NOT automated

- **The Android Studio first-run setup wizard** (fetches the actual Android
  SDK + a default emulator system image) — interactive by nature, same as
  Steam's or MEGAsync's own first-run.
- **Creating an AVD (emulator image)** — a personal choice (device profile,
  API level, Google APIs vs. Play Store image), done via Android Studio's own
  Device Manager.
- **Node/npm/Expo CLI** — out of scope by the same repo-wide rule that
  excludes NVM/Node generally (see CLAUDE.md's *Deliberately NOT
  Ansible-managed* list); `npx` fetches Expo's CLI on demand, no global
  install needed.

## Variables

| var | default | meaning |
|---|---|---|
| `enable_android_dev` | `false` | gate the role + the `android` apt group (group_vars/host_vars) |
| `android_studio_version` | `2026.1.3.8` | the `ide-zips` URL path segment (currently Quail 3 Patch 1) |
| `android_studio_label` | `quail3-patch1` | the human-readable slug in the release filename |
| `android_studio_sha256` | (pinned) | sha256 of the exact tarball, verified by direct download at pin time |
| `android_dev_user` | `{{ target_user }}` | who gets added to the `kvm` group |

## Run standalone

```sh
ansible-playbook bootstrap/site.yml --tags android_studio -e enable_android_dev=true
```

## Bumping the pinned version

Android Studio has no predictable "latest" URL (the path segment is a real
build number, not a rolling alias) — bump by hand:

1. Check <https://developer.android.com/studio> for the current stable Linux
   `.tar.gz` — note the version/build number and label in the filename.
2. Download it yourself and compute the hash directly —
   `curl -L -o as.tar.gz <url> && sha256sum as.tar.gz` — rather than trusting
   a value copied from a webpage (the checksum currently pinned here was
   verified exactly this way, 2026-08-14).
3. Update `android_studio_version` / `android_studio_label` /
   `android_studio_sha256` in `defaults/main.yml`.
4. The "already installed" check is by **version marker**
   (`~/.local/state/hestia/android-studio/<version>`), so bumping the pin
   alone is enough to force a re-run to reinstall — no manual removal needed
   first (unlike `openrgb`'s package-name check).

## Updates

Not apt-managed (no repo) — Android Studio's own in-app updater can update
itself between pin bumps; that drifts the installed version from
`android_studio_version` until the pin is next bumped to match, same as any
other pinned-download role in this repo.
