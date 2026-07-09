# system/polkit

Root-owned polkit rules deployed to `/etc/polkit-1/rules.d/`. polkit reads `*.rules`
(JavaScript) in lexical order; the first rule returning a definitive result wins, and
`.rules` results take precedence over the `.policy` defaults shipped by packages.

## `49-hestia-power.rules`

**Why it exists.** The `claude` agent user runs with **lingering enabled** (a permanent
systemd user session — see the `claude_user` role), so `loginctl` always shows more than
one active session. logind then requires the `*-multiple-sessions` polkit actions
(`reboot-multiple-sessions`, `power-off-multiple-sessions`, `halt-multiple-sessions`)
for the human's reboot/shutdown, and those default to `auth_admin_keep` — an admin
password prompt. The waybar **power menu** (`user/waybar/scripts/power.sh`) fires the
action from a `swaynag` button with no polkit agent attached, so **Reboot / Shutdown
silently no-op** (Cancel and Suspend still work).

**What it does.** Grants those three actions to an **active** session whose user is in
the **`sudo`** group — i.e. exactly the person who could already `sudo reboot`. It only
removes the GUI dead-end; it is no weaker than the existing sudo access.

**Deployment.** By the **`claude_user`** role (which is what enables claude's linger),
copied to `/etc/polkit-1/rules.d/49-hestia-power.rules`. `polkitd` picks up rule changes
live (no reload). Without the `claude_user` role there is no lingering agent user, so the
multiple-sessions promotion doesn't happen and the rule isn't needed — hence it ships
with that role, gated on `enable_claude_user`.

**Test.** With claude lingering, from the desktop power menu (or `systemctl reboot` in the
active graphical session, no sudo) the machine reboots without an auth prompt. Check the
action would otherwise be blocked with:
`pkcheck --action-id org.freedesktop.login1.reboot-multiple-sessions --process $$`.
