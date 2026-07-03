# hestia — VS Code theme (dark + light)

The wildcharm-derived hestia theme as a VS Code extension. The theme JSONs are
**generated** — `themes/wildcharm/render.py` renders them from `palette.yml` +
`scopes.yml` (never edit them by hand). The token colours are byte-identical to
what bat and the web code blocks (stoa/thecodingidiot) render; the dark UI
chrome maps the palette roles (canvas `bg`, panels `surface`, accent status
bar/buttons — the same identity as vifm/cmus/less) plus the 16-colour ANSI
table for the integrated terminal.

**The light theme is editor-only for now**: syntax + a few safe chrome colours;
everything else falls back to VS Code's stock light UI. The light *desktop*
ramp (surfaces/borders) deliberately doesn't exist yet — roadmap M7
(`docs/theme-roadmap.md`); the chrome fills in when it does.

## Install

**The bootstrap does this** (`vscode_theme` role): it packages the `.vsix` and
installs it whenever this extension's version differs from what VS Code
reports, and self-skips on machines without the `code` binary (VS Code itself
is not in the apt manifest — it comes from Microsoft's repo, outside the
bootstrap). After a theme change lands: pull, then
`ansible-playbook site.yml --tags vscode_theme` (or a full run), then reload
VS Code windows.

Manual equivalent — a `.vsix` is required either way; **a folder symlinked
into `~/.vscode/extensions` does NOT register** on current VS Code (verified
on 1.127: the extensions manifest only trusts installed extensions):

```sh
cd user/vscode/hestia
npx @vscode/vsce package
code --install-extension ./hestia-theme-*.vsix   # add --force for same-version
```

Then pick **hestia dark** / **hestia light** in *Preferences: Color Theme*
(a one-time choice — installs/upgrades don't switch your active theme).

Verify against the golden sample: open
`themes/wildcharm/golden/sample.ts` — it must agree hue-for-hue with
`vim themes/wildcharm/golden/sample.ts` and with bat.
