# Sway session launch chain (`greetd` → `start-sway`)

greetd starts the desktop by running `tuigreet … --cmd start-sway`; `start-sway` then
sets the Wayland session environment and `exec`s sway. Both files are tracked here and
deployed by the **`sway_session`** bootstrap role
(`ansible-playbook site.yml --tags sway_session`):

| Tracked file | Deployed to | Mode |
|---|---|---|
| `system/sway-session/start-sway` | `/usr/local/bin/start-sway` | `0755` |
| `system/sway-session/greetd-config.toml` | `/etc/greetd/config.toml` | `0644` |

Changing the greetd config takes effect on the **next login** — the role does **not**
restart greetd (that would kill the running session). Reboot / re-login to apply.

## NVIDIA workarounds are conditional

The proprietary-driver env (`GBM_BACKEND=nvidia-drm`,
`__GLX_VENDOR_LIBRARY_NAME=nvidia`, `WLR_NO_HARDWARE_CURSORS=1`,
`NVIDIA_DRIVER_CAPABILITIES=all`) and the `--unsupported-gpu` flag are applied **only
when an NVIDIA GPU is live** — detected at launch via `/dev/nvidia0` or the `nvidia`
entry in `/proc/modules`. On an AMD/Intel box none of that is exported (those vars
would otherwise break rendering), so the same script is correct everywhere. The
generic Wayland env (`XDG_*`, `MOZ_ENABLE_WAYLAND`, `GTK_THEME`) is always set.

Pairs with the opt-in `nvidia` role (`enable_nvidia`), but doesn't depend on it — the
guard is on the *running* hardware, not the install toggle.

## Still manual

Installing greetd + tuigreet themselves (the apt packages) and enabling the greetd
service are out of scope (base-system prereq, runbook §0). Once they're present, the
role reproduces the whole launch chain (greetd config + launcher).
