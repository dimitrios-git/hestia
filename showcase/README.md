# The hestia showcase

What's inside hestia, what was tried, and why the winners won.

This is the *reader-facing* documentation — distinct from [`docs/`](../docs/),
which holds the design documents and runbooks for people building hestia
itself. Each chapter here covers one application category and preserves the
**trace of the evaluation**: the contenders, the trial as it actually
happened (including the failures and the gotchas that cost hours), the
verdict, and how hestia configures the winner. Screenshots show how things
look; every claim links back to the configs that implement it.

Chapters double as articles — they're written in plain markdown with relative
image paths so they can syndicate to [charalampidis.pro](https://charalampidis.pro)
unchanged.

## Chapters

| Chapter | The one-liner |
|---|---|
| [Wallpapers](wallpapers.md) | Three engines trialled, none survived as "just a wallpaper tool" — the verdict became a generated mesh rendered from hestia's own design system, painted as a static frame (the looping video leaked memory, so the still won) |
| [File managers](file-managers.md) | Seven contenders against vifm — the incumbent won on speed, stole the losers' best ideas, and the trial's failures fixed Qt theming for everything |

**Deep dives** — single-tool pages behind a chapter, for the load-bearing
pieces: [vifm](vifm.md) (the file-managers moat, itemised with live examples).

**Coming:** image viewers
(ristretto and the three that fell), music (cmus + cava as one window),
notifications (mako + the Waybar bell), theming (one palette, thirty-four
generated artifacts).

## Chapter anatomy

Every chapter follows the same skeleton, so the series reads uniformly:

1. **What this category covers** in hestia, and the state before the ride
2. **The contenders** — a table: candidate, verdict, one line of why
3. **The ride** — the trial as narrative: what was tested, what broke, what
   was learned; this is the part that doubles as an article
4. **How hestia ships it** — the winner's wiring, linked into `user/`,
   `bootstrap/`, `themes/`
5. **Gotchas** — the hard-won, searchable list
6. **Screenshots** — dark variant primary; light where the difference matters

New chapters ship in (or right beside) the evaluation's verdict PR, while the
scars are fresh.
