# Terminal multiplexers: one connection, many terminals

The gap this closes: working from a corporate laptop's WSL Ubuntu app, SSH'd
into hephaestus, "another terminal" meant a whole new WSL window and a fresh
SSH login — no splitting/tabbing within one connection, and nothing survived
a dropped connection. Three contenders installed side by side behind
`enable_multiplexers`, no incumbent to unseat. A fourth, adjacent piece —
**mosh** — was trialled in the same pass, since it solves the *other* half of
the same problem (the connection itself, not what runs inside it).

## The contenders

| App | Kind | Verdict |
|---|---|---|
| **tmux** | terminal, C | **Winner.** Mature, prefix-key model, vi-style copy-mode/navigation, huge ecosystem (TPM, tmux-resurrect/continuum) |
| **zellij** | terminal, Rust | Runner-up, **kept + themed**. Nicer out of the box — one keypress makes a working pane, on-screen keybind hints — but more opinionated, less control |
| **screen** | terminal, C | Dropped. The original; needs three actions to do what tmux/zellij do in one, no theme/plugin ecosystem, and no genuine advantage over either of the others to justify keeping |

zellij losing the primary slot isn't the same as zellij being *bad* — it has no
cited technical flaw, just a different, more opinionated tradeoff than tmux.
That's the same call the file-manager evaluation made keeping ranger + yazi
themed and installed after vifm won: a losing candidate only gets dropped
outright when it has a real, cited deal-breaker (as screen does here, and as
nsxiv/viu/qimgv did in the image-viewer evaluation) — not merely for losing a
preference. tmux is the **chosen default**; zellij ships alongside it,
installed and themed, for anyone who prefers its ergonomics.

**Adjacent, not competing:** [mosh](https://mosh.org/) (`enable_mosh`) replaces
the *transport* under an SSH-authenticated session with a roaming, local-echo
UDP connection — it's meant to run *underneath* tmux, not instead of it. Both
were trialled together, live, from an actual work laptop.

## The ride

The whole trial ran for real: WSL Ubuntu on a work ThinkPad, mosh into
hephaestus over the internet (the work laptop was deliberately kept off the
private Tailscale mesh — a different trust boundary from the household
devices), tmux inside that.

**Session 1 — tmux, cold.** `mosh hephaestus` prompted for the TOTP code
before connecting — confirmation that mosh's bootstrap goes through the same
hardened, 2FA-gated sshd as any other login (`enable_ssh_server` +
`ssh_require_totp`, see `system/ssh/README.md`); mosh adds a transport, not a
new auth surface. `tmux new -s jcb` produced tmux's default status line —
misread on first look, and the misread was itself informative: `[jcb]` on the
left is the *session* name, `1: claude*` is *window* 1 named after its
foreground process (tmux auto-renames a window to match whatever's running in
it — it isn't "the first app," it's "whatever's active right now"), and the
truncated text at the far right ("Evaluate terminal m…") turned out to be a
*third*, independent thing — the **pane title**, an OS-level terminal-title
escape sequence set by the running program, truncated to 21 characters by
tmux's stock `status-right` format. Three different name concepts (session /
window / pane) stacked in one status line, easy to conflate on a first read.

**Detach/reattach, the boring way.** `Ctrl+b d` to detach, `exit` to kill the
remote shell entirely (which is what actually ends a mosh session — mosh's
own SSH connection had already closed right after the bootstrap handshake;
there's no persistent SSH connection sitting there for `exit` to kill). New
WSL terminal, `mosh hephaestus`, TOTP again, `tmux a -t jcb` — landed right
back in the exact same session, mid-conversation. This is what tmux alone
already buys you: cheap, boring, and mosh had nothing to do with it.

**Detach/reattach, the interesting way.** With the session still attached
(no `exit`, no detach), wifi was switched off on the laptop for ~20 seconds.
mosh's own client-rendered status bar appeared ("server last contacted Ns
ago") — an honest signal, not silence pretending everything's fine — and
typed characters kept appearing in the terminal *while the network was down*,
via mosh's speculative local echo (it predicts and displays your input before
the round trip confirms it, then reconciles once the server actually
replies). Wifi back on: the bar disappeared, the predicted input was already
where it belonged. No reconnect, no re-`tmux a`, no re-TOTP. A plain SSH+tmux
session would have gone silent/frozen at the wifi drop and needed a full
manual reconnect-and-reattach — the exact gap mosh is for.

**zellij.** `zellij -s eval`, `Alt+n` for a new pane: one keypress produced a
fully live, usable shell — no separate "now put a terminal in it" step. The
bottom bar shows available keys contextually as you go. Reaction: "reminded
me of a common zsh styling... the pane creation, movement and use is so nice
out of box." Detach (`Ctrl+o d`) / reattach (`zellij attach eval`) worked as
expected, backed by zellij's own built-in session serialization (no
tmux-resurrect-equivalent plugin needed).

**screen.** `screen -S eval`, split vertically with `Ctrl+a |` — and the new
region comes up **empty**. screen separates *regions* (viewports) from
*windows* (the things running in them), so getting a usable second pane took
three actions: split, `Ctrl+a Tab` to move into the new region, `Ctrl+a c` to
actually start a shell there. Reaction: "as expected the experience is not as
good, but not that bad either" — functional, dated, no real reason to prefer
it over either of the other two.

**tmux, tried last, on its own terms.** `Ctrl+b |`/`Ctrl+b -` to split,
`Ctrl+b hjkl` to move — one action per pane, same as zellij, but every split
direction is an explicit choice rather than zellij's single opinionated
`Alt+n`. The deciding reaction: *"tmux felt more at home than the other
two"* — the prefix-key model maps onto the same mental model as Sway's
`$mod`-key workspace switching (`Ctrl+b` then `1` ≈ `$mod` then `1`), and the
vi-style pane navigation matches `set -o vi` bash and vim across the rest of
hestia. zellij's single-key convenience is faster to *learn*; tmux's
prefix-then-choose model gives more control once the muscle memory is there,
and that muscle memory was already half-built from Sway.

## How hestia ships it

- **tmux** (`user/tmux/.tmux.conf`, `enable_multiplexers`, default on): mouse
  support, vi-style copy-mode and pane navigation (`h/j/k/l`), 1-indexed
  windows/panes, splits bound to the mnemonic `|`/`-` (in addition to tmux's
  stock `%`/`"`), and a TPM bootstrap for `tmux-resurrect`/`tmux-continuum`
  (session persistence across a reboot — TPM itself stays a one-time manual
  `git clone`, deliberately not Ansible-managed, same as vim-plug). Themed via
  a hand-authored `theme-{dark,light}.conf` pair (`docs/theming.md`) —
  session-name and active-window chips filled in the hestia accent
  (`#7c3aed`/white text, mirroring kitty's active-tab treatment), pane
  borders on the idle/active split used elsewhere (swaylock's ring states).
- **zellij** (`user/zellij/config.kdl`, same `enable_multiplexers` toggle,
  installed via the pinned `localbin` release binary): mouse mode, Wayland
  clipboard (`wl-copy`), and its own built-in session serialization (the
  native equivalent of tmux-resurrect, no plugin needed). Themed via a
  hand-authored `hestia-{dark,light}.kdl` theme pair, auto-loaded from
  `~/.config/zellij/themes/` and selected variant-blind with `theme "hestia"`
  — the same idle/active-border and accent-fill choices as tmux's theme,
  translated into zellij's far more granular per-UI-role schema (0.44; each
  role takes RGB decimal `base`/`background`/`emphasis_0..3`, not a flat ANSI
  palette).
- **mosh** (apt package only, `enable_mosh`, default on): needs a UDP port
  range forwarded on the router to hephaestus's LAN IP (same shape as the
  existing SSH 2222→22 forward — `mosh` picks a free port from that range per
  session) and, from any network you don't fully control (a work LAN), only
  needs outbound UDP to be allowed — that's the network's call, not this
  repo's.

## Gotchas

- **A window "name" and a pane "title" are two different things.** tmux
  auto-renames the *window* after its foreground process; the *pane title* is
  a separate OS-level terminal-title escape sequence some programs set
  directly. Both can show in the status line at once and look like the same
  field until you know to look for the two truncation/format differences.
- **screen's regions start empty.** A fresh split is just a viewport — you
  still need `Ctrl+a c` to put a shell in it. tmux and zellij both give you a
  live shell in the same keystroke that creates the pane.
- **Mosh's local echo is a prediction, not a confirmation.** What you see
  appear during a network gap is what mosh *expects* the server will do with
  your input — fine for typing text, but don't treat it as proof a command
  actually ran until the connection catches up and reconciles.
- **`exit` isn't a mosh-specific recovery test.** Mosh's own SSH connection
  closes right after the bootstrap handshake — there's no persistent SSH
  session for `exit` to kill. What `exit` at the remote prompt actually ends
  is the shell, which then tears down the mosh session as a side effect. The
  real differentiator test is an *involuntary* network interruption (this
  ride used a wifi toggle) with no `exit` involved.
- **mosh's TOTP prompt on connect isn't a separate feature** — it's evidence
  that mosh's bootstrap goes through the exact same hardened, 2FA-gated sshd
  as a normal SSH login (`system/ssh/`). Mosh adds a resilient transport on
  top of that trust boundary; it doesn't add a new one.

## Screenshots

Pending — this trial ran entirely over a remote terminal session (a work
laptop's WSL client into hephaestus), so there was no local desktop to
capture from. A themed terminal capture of the tmux status bar can be added
later without re-running the trial.
