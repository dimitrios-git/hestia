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

Not wired into the bootstrap (VS Code isn't part of the base system). Manual:

```sh
# symlink straight into the extensions dir (dev-style install):
ln -s "$(pwd)/user/vscode/hestia" ~/.vscode/extensions/dimitrios.hestia-theme
```

Then reload VS Code and pick **hestia dark** / **hestia light** in
*Preferences: Color Theme*. Alternatively package a `.vsix` with `vsce package`
in this directory and `code --install-extension hestia-theme-*.vsix`.

Verify against the golden sample: open
`themes/wildcharm/golden/sample.ts` — it must agree hue-for-hue with
`vim themes/wildcharm/golden/sample.ts` and with bat.
