# hestia roadmap — the desktop catalog

hestia grew as a fix-what-annoys-me dotfiles repo. It now works well enough that
the everyday-annoyance backlog is nearly empty — which is exactly when a project
stalls, because there's no longer a forcing function. This doc is the replacement
forcing function: it turns "make hestia production-ready" from a vibe into a
**catalog of every piece of the desktop, each with a maturity state you can see at
a glance**. Pick a hollow row, fill its gates, repeat.

It supersedes the ad-hoc `## TODO / planned work` block in `CLAUDE.md` for
*category-level* planning. (That block can keep cross-cutting structural notes; the
per-application "what have we actually decided" state lives here.)

Two neighbours:
- **`docs/theming.md`** — the per-app *process* for the look, with its own status
  table. That table is gate 3 (Themed) of this catalog, in more detail.
- **`showcase/`** — the *reader-facing* write-up of a concluded evaluation. A
  finished showcase chapter is gate 6 (Showcased) of this catalog.

This catalog is also two things beyond planning:
- **The spec for the future installer.** The `setup.sh` questionnaire is outdated
  and slated to become a Python app. Each row here — a category, its default, its
  alternatives, its opt-in toggle — is one section of that questionnaire. Build the
  catalog and the installer has a data model to render instead of re-deriving it.
- **A content pipeline for [charalampidis.pro](https://charalampidis.pro).** Every
  row that reaches gate 6 is a "we compared N tools and here's why X won" article,
  written while the scars are fresh (see *How an evaluation runs*). You don't write
  articles; you write verdicts that happen to be articles.

## The maturity ladder

Every category passes through the same six **gates**. A category is
**production-ready when gates 1–5 are met**; gate 6 is the publish bonus that also
feeds stoa.

| # | Gate | Met when |
|---|------|----------|
| 1 | **Chosen** | A default is picked and deployed by the bootstrap |
| 2 | **Configured** | It runs on a real hestia config, not stock defaults |
| 3 | **Themed** | It's on the palette per `docs/theming.md` (or theming is N/A) |
| 4 | **Researched** | Contenders were trialled and a verdict + rationale is recorded |
| 5 | **Documented** | It has a `CLAUDE.md` section a maintainer can work from |
| 6 | **Showcased** | A `showcase/` chapter is written and syndicated to stoa |

Gate 4 is the one most current categories are missing — a tool that was picked
years ago "because it's lightweight" and never revisited (mako is the canonical
example) has gates 1–3 and 5 but a **hollow gate 4**. Turning hestia
production-ready is, mostly, the work of closing gate 4 across the catalog: making
each default a *researched* decision rather than an inherited one.

**Two axes, not one ladder.** The gates split into a *research* axis (4 Researched,
6 Showcased — was there a real trial, is the verdict written?) and an
*implementation* axis (1 Chosen, 2 Configured, 3 Themed — is the shipped default
deployed, configured, themed?). They're semi-independent: a category can have a
showcase chapter (gate 6) while its winner is barely configured (gate 2 hollow).
File managers is the cautionary example — the evaluation answered *which* tools but
never hardened them, so an earlier `●●●●●●` score was wrong; the honest read is
`●◐◐●●◐`. Don't let a written verdict flatter the implementation.

Legend used in the catalog below:

`●` met  ·  `◐` partial, or decided deliberately but without a formal trial  ·
`○` not met (the tool exists, the gate doesn't)  ·  `–` not applicable

The six-cell string reads **1·Chosen 2·Configured 3·Themed 4·Researched
5·Documented 6·Showcased**. Rows with no tool yet are **gaps** — the "complete
desktop environment" backlog — and carry candidate tools in the note.

> **First-pass state.** The gate marks below are my honest first read from the
> current configs; treat them as a starting point to correct, not gospel. Adjusting
> a row *is* using the doc.

## How an evaluation runs (the lightweight gate)

The reason decisions went unwritten is that the write-up was a chore owed *after*
the work, when the details had faded. Invert it — **open the write-up at the start,
and gate the merge on it:**

1. **Open the stub first.** When you begin evaluating a category, the first commit
   adds/updates its row here and creates a stub `showcase/<category>.md` with just
   the **contenders table** (candidate · verdict-TBD · one line). The doc is now the
   workspace you're already in.
2. **Log scars as they happen.** Every gotcha, every "caught live," every dead end
   goes into the chapter's *ride* section in the moment — that's the part that
   doubles as the article, and it's only accurate while fresh.
3. **The gate:** the verdict PR **does not merge until the chapter's verdict section
   is filled** and this catalog's row is updated. Same discipline as "don't merge if
   the config doesn't actually run" — the write-up is a required artifact of the
   work, not an afterthought.

That's the whole ritual: no templates, no tooling — just *stub-first, merge-gated*.
It rides the workflow you already use (`showcase/README.md` already says chapters
ship in/beside the verdict PR; this makes it non-optional).

## Log, don't force — the app logs

Closing every gate on every app *right now* is a push model — a forced march where
each app is a cliff, which invites avoidance. The catalog runs on a **pull** model
instead: an app that works well enough sits at "acceptable" and carries a **log** of
what would make it *ultimate* (every gate closed, genuinely polished). You append a
line the instant you notice a gap — under **no obligation to fix it then**. Later,
when you have the appetite, you pick an app and burn down its log.

- **Capture is cheap; action is deferred.** No cliff, no chore.
- **The log lists only apps with open items.** An app at ultimate has no entry, so
  the backlog *shrinks* as you polish and *grows* as you spot things — application
  support grows organically, not by decree.
- **It pairs with the gates.** The catalog table is the *dashboard* (where each app
  is, at a glance); the log is the *backlog* — the itemised "what closes this hollow
  gate" behind the marks.

The logs live in [*Path to ultimate*](#path-to-ultimate--the-app-logs) at the foot
of this doc. Burning one down is a *pull* — pick an app you have appetite for, not
the next chore in a queue.

## The catalog

### Desktop shell

| Category | Default | Gates | Note |
|---|---|:---:|---|
| Compositor / WM | sway | `●●●◐●○` | Foundational Wayland choice; deep config |
| Bar / panel | waybar | `●●●○●○` | Deeply configured; never trialled vs alternatives |
| Launcher | wofi | `●●●○●○` | |
| **Notification daemon** | **mako** | `●●●○●○` | **Snap "lightweight" pick — vs dunst / swaync / fnott** |
| Lock screen | swaylock | `●●●◐●○` | First app themed through theming.md |
| Idle / caffeine | swayidle | `●●–◐●○` | Behaviour, not colour (theme N/A) |
| Wallpaper | mpvpaper + mesh | `●●●●●●` | **Fully closed — evaluated + showcased** |
| Screenshot | grim / slurp | `●●–◐●○` | |
| Screen recording | — none | | Candidate: wf-recorder |
| Clipboard manager | — none | | Candidate: cliphist |
| On-screen display (vol/brightness) | — none | `◐◐–○◐○` | Faked with notify-send today |
| Output hotplug | — none | | Candidate: kanshi |
| Portals / screen-share | xdg-desktop-portal | `●●–◐●○` | wlr + gtk routing |
| Polkit auth agent | mate-polkit | `●●◐◐●○` | GTK agent for GUI privilege prompts (nemo Open-as-Root, disk mounts, pkexec) — sway ran none before; started from the sway config |
| Login / session | greetd + tuigreet | `●●◐◐●○` | |

### Terminal & editing

| Category | Default | Gates | Note |
|---|---|:---:|---|
| Terminal emulator | kitty | `●●●○●○` | Never trialled vs foot / alacritty / wezterm |
| Shell | bash | `●●–○●○` | Inherited; zsh / fish never weighed |
| Prompt | custom bash | `●●●○◐○` | Part of `.bashrc`; vs starship |
| Multiplexer | — none | | Candidate: tmux / zellij |
| Editor / IDE | vim + nvim | `●●●◐●○` | Deeply configured |
| Pager | less | `●◐–○◐○` | |

### Files & media

| Category | Default | Gates | Note |
|---|---|:---:|---|
| File manager (TUI + GUI) | vifm + nemo | `●◐●●●◐` | vifm (TUI primary) + nemo (GUI default) both hardened & themed (nemo confirmed dark with the `#d7005f` accent). **nautilus is now a 2nd production-ready keeper and a live default-contender** — pending decision, accent-blocked to blue until Debian 14 (see the [app log](#path-to-ultimate--the-app-logs)). Showcase verdict still open (the nemo-vs-nautilus default). thunar/dolphin/rest untested |
| Image viewer | imv + ristretto | `●●●●●◐` | Evaluated; showcase chapter pending |
| **Media / video player** | **mpv** | `●●◐○◐○` | **Snap pick — never researched** |
| Music player | cmus + cava | `●●●○●◐` | Deep config; showcase pending |
| Audio visualizer | cava | `●●●○●◐` | Rides the music window |
| Document / PDF | zathura | `●●●○●○` | |
| Markdown | glow | `●●●○●○` | |
| Archive manager | — none | | Candidate: file-roller / ouch |
| Disk / mount | udisksctl | `●●–◐●○` | |

### Appearance

| Category | Default | Gates | Note |
|---|---|:---:|---|
| Fonts | Lilex / BigBlueTerm Nerd Font | `●●–○●○` | Chosen; never researched vs alternatives |
| GTK theme | hestia (adw-gtk3) | `●●●●●◐` | Deep investigation = researched; showcase pending |
| Icon theme | Yaru-hestia | `●●●●●○` | |
| Cursor theme | Breeze | `●●●◐●○` | |
| Qt / KDE theme | kdeglobals / Kvantum | `◐◐◐○◐○` | Partial — the open Qt track |

### Applications

| Category | Default | Gates | Note |
|---|---|:---:|---|
| Web browser | firefox-esr | `●●●○●○` | Themed via GTK; never researched |
| Email | thunderbird | `●●●○●○` | Deep theming; opt-in `email` group |
| Office | libreoffice | `●◐–○●○` | Opt-in, heavy |
| Calculator | qalc | `●●–◐●○` | Corrected from gnome-calculator |
| Password manager | gnome-keyring | `●●–○◐○` | Secrets only; no KeePassXC-class tool |
| Calendar / contacts / notes / PKM | — none | | Big gap for a "complete" desktop |

### System & infrastructure

| Category | Default | Gates | Note |
|---|---|:---:|---|
| Bootstrap / config-mgmt | Ansible | `●●–●●○` | Engine decision recorded (the meta-layer) |
| Audio server | pipewire | `●●–○●○` | |
| Network | NetworkManager | `●●–○●○` | |
| Bluetooth | bluetuith + bluez | `●●◐○●○` | |
| VPN / mesh | tailscale | `●●–◐●○` | |
| File sharing | samba | `●●–◐●○` | Design doc recorded |
| System monitor | htop | `●●◐○●○` | vs btop |
| Power management | power-profiles-daemon | `●●–○●○` | |
| Backup | — none | | Candidate: restic / borg |
| Firewall | — none | | Candidate: nftables / ufw |
| Containers | — none | | Candidate: podman |

## Reading the catalog

- **Fully closed (all six gates):** wallpapers. The model for what "done" looks
  like — a researched default, themed, documented, and a showcase chapter shipped.
  (File managers *looked* closed because it has a chapter, but its winner was never
  hardened — see *Two axes, not one ladder* above and the app log below. A written
  verdict is not a finished implementation.)
- **Production-ready but not showcased (1–5):** the write-up is the only thing
  standing between these and a stoa article.
- **Hollow gate 4 (the bulk):** works well, looks right, but the default is
  inherited rather than earned. This is the main body of remaining work — and the
  richest article seam.
- **Gaps (no tool):** the categories a *complete* desktop still needs. Each is a
  greenfield evaluation with no incumbent to unseat.

Roughly a third of the catalog is closed or ready, a third is hollow-gate-4 snap
decisions, and a third are gaps. That distribution is the roadmap: promote snap
decisions to researched ones, fill gaps deliberately, and let each promotion pay out
as a showcase chapter.

## Path to ultimate — the app logs

The per-app backlog behind the catalog's hollow gates (see *Log, don't force*).
**Only apps with open items appear here** — an app at ultimate has no entry. Append
a line the moment you notice a gap; act when you have appetite. Each item names the
gate it would close.

### nemo *(chosen GUI default — file managers)*

Hardened + themed (2026-07): session wiring in `user/sway/nemo-setup.sh` (default
terminal → kitty, default folder handler, the cinnamon-desktop-editor launcher
action disabled), and confirmed **dark with the exact `#d7005f` accent** live (GTK3
via the recoloured adw-gtk3, once the GTK_THEME/portal color-scheme saga closed). The
benign `gtk theme is not known to have nemo support` startup warning is cosmetic
(nemo's hardcoded theme list) — won't-fix. One item remains:

- **No tracked config** — add a `user/nemo/` config (default view, actions, dconf
  keys) so nemo reaches gate 2 (Configured) rather than only theme-inheriting.
  *(closes gate 2)*

### nautilus *(GTK4/libadwaita — file-managers alternative, now a default-contender)*

Became production-ready as a side effect of the GTK4/libadwaita dark-mode fixes
(2026-07): clean, minimal, dark. Under consideration as the default GUI manager over
nemo — better-looking + more minimal, but nemo has the easier functionality. No rush:
the decision partly resolves itself at Debian 14.

- **The accent constraint (the deciding wrinkle)** — nautilus is libadwaita 1.7, so
  it's stuck on the **default blue accent**; it can't take hestia's `#d7005f` until
  libadwaita ≥1.8 / Debian 14 (the staged `gtk-4.0/gtk.css` is inert until then). So
  today nautilus is dark-but-off-brand while nemo is fully on the hestia identity —
  the concrete reason nemo stays default for now. Revisit at Debian 14, when the
  accent catches up and aesthetics-vs-functionality is the only axis left.
- **Pending decision → the file-managers showcase verdict** — nemo vs nautilus as the
  default GUI manager is the open call that concludes the (still provisional)
  file-managers chapter. Capture the trade-off there when it's made.

### ranger *(alternative — kept for comparison, file managers)*

Config is a 12-line stub. Image preview is wired (kitty), the rest is not.

- **No `scope.sh`** — video/PDF/media-info/archive previews are missing (only image
  preview works). *(gate 2)*
- **No `rifle.conf`** — opener rules are unset, so `l`/Enter falls to defaults.
  *(gate 2)*

### yazi *(alternative — kept for comparison, file managers)*

- **Theming shallow** — a theme file exists but was never tested in detail against
  the wildcharm identity. *(gate 3)*
- **No detailed config** — keymap/openers/preview left at defaults. *(gate 2)*
