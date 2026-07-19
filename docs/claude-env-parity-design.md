# Design: claude environment parity (same tools, same configs)

> **Status:** Proposed — design for making the **`claude`** agent user's terminal
> environment reproducibly match dimitrios's, deployed from the *same* Ansible
> sources rather than hand-staged. Feeds a **phased implementation** (multiple
> PRs; see §8). Extends [`claude-user-design.md`](claude-user-design.md), which
> owns the user/trust boundary this must not erode.

## 1. Motivation — "I see this, you see that"

dimitrios and `claude` collaborate on this repo long-term. When their
environments diverge, every "does it look right?" costs a round-trip: a config
change is live for one principal and absent for the other, screenshots come out
wrong, and a bug reproduces for one and not the other. The divergence surfaced
concretely while re-shooting the showcase screenshots — `claude`'s home was
**partially and inconsistently themed** (vifm/kitty/bat/glow configs present but
*without their theme files*; cmus/ranger/nvim configs absent; `wpaperd`/`awww`
missing), so it could not faithfully reproduce the violet desktop.

The repo already flags this as a latent TODO: the shared `.bashrc` reaches
`claude`'s home today "via a **stopgap symlink** (the bootstrap will own this once
claude's env is automated)" (CLAUDE.md, Bash section). This design is that
automation, generalised.

**Goal:** `claude`'s terminal environment is a **reproducible deploy from the same
sources**, so parity holds *by construction* — not by luck or manual staging. This
removes ~99% of environment-difference friction: what dimitrios sees, `claude`
sees (or close enough that a screenshot is faithful).

## 2. Key insight — it's configs, not binaries

The tool **binaries are already shared**: vifm, kitty, cmus, ranger, vim/nvim,
`imv` (as `imv-wayland`), `bat` (as `batcat`), sway, waybar, mako, wofi, swaylock,
grim, chromium — all installed **system-wide by the `packages` role (apt)**, so
`claude` already has them on `PATH`. What diverges is:

- **the per-user config layer** — the dotfiles + theme fragments, only ever
  deployed to dimitrios's `$HOME`; and
- **a few per-user tools** — the `localbin` binaries (`wpaperd`/`awww`) that install
  into `~/.local/bin`, only run for dimitrios (though `yazi`/`bluetuith` happen to
  be present for `claude` already).

So this is a **deploy/parameterisation job, not a toolchain install.** The heavy
lifting (packages, the tool binaries) is done; we just need to run the *per-user*
layer for `claude` too.

## 3. The model — same roles, parameterised by principal

Reuse the existing roles; do **not** fork a parallel "claude configs" tree.

- The **`dotfiles`** role already deploys via **`target_home`** (it symlinks
  `dotfile_links` and renders `templated_configs` under `{{ target_home }}`).
- The **`localbin`** role already installs into **`{{ target_home }}/.local/bin`**.
- The **`claude_user`** role already runs work **as `claude`** via
  `sudo -H -u {{ claude_user }}` (the `-H` dodges the unprivileged-become
  temp-file gotcha).

So a **"deploy claude's environment" pass** runs `dotfiles` (+ `localbin`) with
`target_home=/home/claude`, `become: true` / `become_user: claude`, over a
**claude-appropriate manifest subset** (§4). No new mechanism.

**Deploy source: `claude`'s own clone** (`/srv/devshare/hestia`) — decided. The
symlinks resolve into `claude`'s workspace, matching the repo's direct-edit
philosophy, with a real payoff: **`claude`'s live env tracks whatever branch
`claude` is working on**, so a theme change is visible to the agent *before* it's
pushed, and screenshots reflect the branch under review. (Contrast dimitrios,
whose dotfiles deploy from his own clean clone at `~/Development/hestia`.)

- **Caveat, named on purpose:** a half-finished edit on a topic branch is then
  *live* for `claude`. For a headless agent that's a feature (test your change in
  your own terminal), and the blast radius is `claude`'s own workspace only. It is
  never dimitrios's env — the two clones stay independent.

## 4. Scope — what deploys to `claude`, in three tiers

### Tier A — deploy now (terminal + theme) — the collaboration surface

The tools we actually work in together, plus the hestia theme so `claude`'s
terminal renders the same violet identity:

- **Editors:** vim/nvim (+ the `hestia` colorscheme — already present; formalise).
- **File managers / TUIs:** vifm (+ `hestia.vifm` colours), ranger, yazi.
- **Terminal:** kitty (+ `theme.conf` fragment).
- **Pagers / preview:** bat (+ `hestia.tmTheme`), glow (+ `hestia.json`), cmus.
- **Shell:** the shared `.bashrc` (identity-adaptive — see §5), `.dircolors`
  (variant pair), and git **aliases / non-identity** config.
- **The theme fragments** for all of the above (`theme_variant: dark` for claude).

This is what makes `claude`'s terminal match dimitrios's. It retires the `.bashrc`
stopgap symlink.

### Tier B — deploy for the **screenshot rig** (on demand, not a daily session)

`claude` is **headless** — it runs no persistent graphical session. But to shoot
faithful showcase screenshots (desktop composites, TUI-in-context) it needs the
desktop tools available and a way to stand up a throwaway compositor:

- The desktop tools + their theme: waybar, mako, wofi, the wallpaper tooling
  (`wpaperd`/`awww` via `localbin`), the GTK theme, imv.
- A **nested headless sway** harness: `WLR_BACKENDS=headless` +
  `WLR_HEADLESS_OUTPUTS` at a chosen resolution, a minimal sway config that
  `include`s the hestia theme fragment and launches waybar, captured with `grim`.

This is the piece that **dissolves the parked screenshot work** (PR4): with the
current theme deployed to `claude`'s home and a headless compositor on demand, the
TUI shots become faithful and claude-shootable; only a true full daily-desktop
composite might still want dimitrios's live session.

### Tier C — **NEVER** deploy to `claude` (identity / secrets / privilege)

The one thing that must *not* be "the same config." `claude` keeps its **own**
identity (owned by the `claude_user` role); parity must not copy dimitrios's:

- **Secrets:** `~/.bash_secrets` — never deployed. `claude` sources its own only
  if it ever has one (the shared `.bashrc` already guards the `source` on
  existence).
- **Git identity / signing:** the rendered `~/.gitconfig` carries dimitrios's
  `user.email` + **signing key**; `claude` gets its *own* gitconfig from the
  `claude_user` role. Never render dimitrios's into `claude`'s home.
- **SSH / GPG:** `claude`'s `id_claude` + its own passwordless GPG key
  (`4AA9DD310356AD0E`) come from `claude_user`. Dimitrios's keys, `~/.ssh`,
  `~/.gnupg`, and the credential-unlock scripts (which bake his **keygrip** /
  SSH key file) are out of scope entirely.
- **Anything privileged:** `claude` is **not** in sudo and stays that way. Nothing
  in its deployed config may assume `sudo`/`pkexec`. The `system/` (`/etc`,
  root-owned) configs — samba, sway-session/greetd — are out of scope for a
  per-user deploy.

**Net: `claude` gets the same *look* and *tools*, never the same *keys* or
*privileges*.** The kernel-enforced trust boundary is untouched.

## 5. The security boundary (non-negotiable)

Parity is a convenience layer *on top of* the `claude-user-design.md` trust model;
it may not weaken it. The rules:

1. **No secret ever leaves dimitrios's boundary.** `~/.bash_secrets`, keys, and
   keygrips are not in the claude manifest subset — by omission, not by filter.
2. **Own identity only.** Every identity-bearing config (`gitconfig`, credential
   scripts) is either produced by `claude_user` with *claude's* values or excluded.
   The parity deploy touches only **identity-neutral** tool/theme configs.
3. **No privilege.** `claude` remains non-sudo; the deploy runs as `claude` into
   `claude`'s own `0700` home. No `become: root` step writes into `claude`'s env.
4. **The shared `.bashrc` is safe to share** precisely because it's already
   identity-adaptive (colours the prompt by `$USER`/`$EUID`) and sources
   `~/.bash_secrets` *only if present*. Sharing the rc does not share the secrets.

A one-line test to keep honest after each deploy: `ls ~dimitrios` from `claude`
still returns **Permission denied**, and `claude`'s `git config user.email` is
still `claude`'s.

## 6. Mechanism details

- **Manifest scoping.** Tag each `dotfile_links` / `templated_configs` entry with
  the principals it targets — e.g. a `principals: [dimitrios, claude]` (default
  `[dimitrios]`) — so the claude subset is *derived from the one manifest*, not a
  second hand-maintained list that would drift. The claude pass filters on the tag.
  (Alternative considered: a separate `claude_dotfile_links` list — rejected, it
  re-introduces the drift the single-source manifest exists to kill.)
- **Deploy source / repo root.** The claude pass sets `repo_root` to `claude`'s
  clone so symlinks resolve into `/srv/devshare/hestia`.
- **Variant.** `claude` deploys `theme_variant: dark` (a `claude_theme_variant`,
  default `dark`, if we ever want it configurable).
- **Gating.** A toggle (rides `enable_claude_user`, or its own
  `enable_claude_env`) so a spin without the agent skips it cleanly.
- **Idempotent.** Re-run `--check` → `changed=0`, same standard as every role.
- **Retire the stopgap.** This deploy *owns* `claude`'s `.bashrc` symlink,
  replacing the manual one (and the CLAUDE.md note updates to match).

## 7. The screenshot rig (Tier B) — **built** (`user/bin/hestia-shot`)

Implemented as **`user/bin/hestia-shot`** (deployed to `claude`'s `~/.local/bin`
via the Tier-A subset). One command spins up a throwaway nested compositor, paints
the theme, runs the scene, captures it, and tears the whole thing down:

```
hestia-shot desktop  out.png     # waybar + mesh wallpaper + tiled vifm (composite)
hestia-shot vifm     out.png [p] # vifm alone (any single-app scene)
hestia-shot ranger|yazi out.png
hestia-shot app "cmus" out.png   # any command in a themed kitty
hestia-shot vim "+15 sample.py" out.png   # plain vim on the repo colorscheme, borderless
                                          # (fullscreened kitty — the hestia.vim screenshot scene)
hestia-shot url  <url|file> out.png   # a web page (chromium in-sway; re-shot flash-preview)
```

- **Driven scenes:** a `HESTIA_HOOK` env command runs after the window maps and
  before capture (the vifm scene launches with a fixed `--server-name`, so the hook
  can `vifm --remote -c :gs` etc. to reach a state). This is how `vifm-preview`/`-gc`/
  `-gs`/`-gd` were re-shot against a throwaway git demo repo.
- **The `url` scene** renders a page with **chromium as a Wayland client inside the
  nested sway**, captured by grim — **not** chromium's own `--headless --screenshot`,
  which is **broken in claude's env** (the paint/CDP path hangs; even the wallpaper
  `render.js` puppeteer path times out on `page.goto`, while plain `--dump-dom`
  works). WebGL renders via the NVIDIA EGL stack (swiftshader fallback); sway-side
  `fullscreen` fills the output with no gaps/border and no chromium "exit fullscreen"
  banner. This is how the flash-mesh tuning-page shot is produced.

What made it work (the load-bearing details):
- **`WLR_BACKENDS=headless` + `WLR_RENDERER=pixman`** — a virtual output, software
  rendering, **no GPU/DRM/EGL** needed (claude has no seat; pixman sidesteps it).
- **`dbus-run-session -- sway …`** — waybar (and portals) need a session bus;
  without one the bar silently fails to map. The rig wraps the whole session.
- **Wallpaper via `output … bg <png> fill`** — a pre-rendered mesh PNG, so no live
  render. Picks `claude`'s **deployed** `~/.local/share/backgrounds/hestia` asset
  (the Tier-B `wallpapers` role), falling back to the in-repo showcase mesh, then
  solid ground. (Tier B also gives claude `wpaperd`/`awww` via `localbin` for parity.)
- **Colours from the palette** — the rig `sed`s `$accent`/`$bg` out of the generated
  `user/sway/theme-<variant>.conf` and sets `client.focused` from them, and points
  waybar at a staged dir that resolves the `theme-<variant>.css` pair to `theme.css`
  (the way the bootstrap symlink does). So it renders the **real** theme from the
  clone — no hardcoded hexes.
- **Clean teardown** — launched under `setsid` (own process group); teardown does a
  graceful `swaymsg exit` then a group kill, so waybar/kitty (grandchildren of
  `dbus-run-session`) never leak. Verified: `changed=0` strays after each run.

Same discipline as the existing TUI **pty-testing** note (CLAUDE.md, repo overview),
extended from "scrape a TUI" to "screenshot a themed Wayland surface." A re-shoot is
now a one-line command, not a one-off.

## 8. Phased plan (multiple PRs)

Deliberately staged so each PR is solid and verifiable on its own.

1. **PR A — this design doc.** ✅ (#240) — parked the screenshot work until the rig exists.
2. **PR B — Tier A deploy.** ✅ (#241) — manifest `claude: true` tagging + the "deploy
   claude's environment" pass (terminal + theme); `.bashrc` stopgap retired. Verified:
   `claude`'s home comes up themed (violet `hestia.vifm`, kitty `theme.conf`,
   cmus/ranger/nvim present) and the Tier C exclusions held (own gitconfig untouched,
   no `.bash_secrets`, `ls ~dimitrios` denied).
3. **PR C — Tier B rig.** ✅ — `user/bin/hestia-shot` (the headless-sway rig, §7) +
   the Tier-B `localbin` (`wpaperd`/`awww`) + `wallpapers` (mesh assets) pass for
   `claude`, gated `enable_claude_rig`. Verified live: the full desktop composite
   (waybar + mesh wallpaper + tiled vifm) and single-app scenes render violet-themed
   and tear down with zero strays.
4. **PR D — re-shoot the parked screenshots** using the rig (folds the former PR4
   back in: the 10 red-era images + the `showcase/README.md` "seamlessly-looping"
   → static fix). ← **next**

## 9. Open questions / resolved

- **Manifest tag shape** — RESOLVED (PR B): a per-entry `claude: true` flag, with the
  subset derived via `selectattr('claude','defined')` (null-safe; one manifest, no
  second list). A `principals: [...]` list was the alternative; the boolean flag is
  simpler for a two-principal split.
- **How much of Tier B** — RESOLVED: the **full desktop composite** (waybar + wallpaper
  + tiled apps), so `desktop-dark`-class images are reproducible, not just TUIs.
- **GTK theme for claude** — DEFERRED to PR D: the `gtk_theme` role for claude (GUI
  file-manager shots — nemo/nautilus) isn't needed for the TUI/composite rig, so it's
  added when PR D actually re-shoots the GUI images.
- **Branch-tracking hygiene** — since `claude`'s live env follows its working branch, a
  broken config mid-edit is live for claude — acceptable (its own workspace); worth a
  line in `working-with-claude.md`.
- **Persistent vs on-demand** — the rig is **throwaway-only** (`setsid` group, killed
  after each shot); `claude` never runs a persistent graphical session (the headless
  security posture).
