# Terminal multiplexers: one SSH connection, many terminals

*Evaluation in progress — this is a stub (see `docs/roadmap.md`'s "How an
evaluation runs"). The verdict, the ride, and screenshots land here when the
trial concludes.*

The gap this closes: working from a corporate laptop's WSL Ubuntu app,
SSH'd into the home Linux PC, "another terminal" meant a whole new WSL
window and a fresh SSH login — no splitting/tabbing within one connection,
nothing surviving a dropped connection. Three contenders installed side by
side behind `enable_multiplexers`, no incumbent to unseat (`docs/roadmap.md`'s
long-open "Multiplexer" gap).

## The contenders

| App | Kind | Verdict |
|---|---|---|
| **tmux** | terminal, C | TBD — mature, deeply scriptable, huge plugin ecosystem (TPM, tmux-resurrect/continuum, catppuccin/tmux) |
| **zellij** | terminal, Rust | TBD — modern, discoverable (on-screen keybind hints), built-in themes + built-in session resurrection, no plugin manager needed |
| **screen** | terminal, C | TBD — the original; no plugin/theme ecosystem, included for a firsthand comparison |

**Adjacent, not competing:** [Mosh](https://mosh.org/) (`enable_mosh`) solves a
related but different problem — a roaming/sleeping laptop's dropped SSH
connections — and is meant to run *underneath* whichever multiplexer wins
here, not to replace one.
