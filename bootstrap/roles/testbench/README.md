# `testbench` role — theming fixtures

Opt-in (`enable_testbench`, default **false**), **no root**, idempotent. Generates
a disposable demo folder (`testbench_dir`, default `~/theme-testbench`) so theming
work can be verified from ONE reproducible place instead of ad-hoc files:

- **`code/`** — short per-language samples, each dense with the constructs that
  reveal *syntax*-theme differences (comments line/block/doc/TODO, strings +
  escapes + interpolation, numbers int/float/hex, booleans/null, keywords,
  symbolic vs word operators, function def vs call, builtins func/type/const,
  parameters, self/this, type annotations, decorators/attributes, member access,
  macros). Open the same file in vim / nvim / bat / VS Code (and the web via
  Shiki) and compare — they render from the same `palette.yml` + `scopes.yml`.
- **`files/`** — one fixture per `ls`/dircolors *file-type* category (extensions
  for archives/images/video/audio/docs/markdown/code; directory, sticky+other-
  writable, sticky-only, other-writable, setgid dir; executable/setuid/setgid
  files; valid + broken symlink; hardlink; FIFO; unix socket; empty; dotfile;
  extension-less). Verifies `ls --color` / vifm / yazi / ranger colouring.

The deployed folder carries its own `README.md` (the role's `files/INDEX.md`)
with the exact commands to try.

## Maintaining it

- **Add a language:** drop a `sample.<ext>` into `files/code/` (keep it short and
  packed with the revealing constructs above). It's copied verbatim.
- **Add a file-type fixture:** an extension → append to `testbench_ext_files`
  (`defaults/main.yml`); anything with a special mode / node type → add a task in
  `tasks/main.yml` (see the symlink/FIFO/socket/sticky examples).
- **Escapes:** the samples are static files — a literal `\n` in a sample stays
  literal (they're copied, not templated).

Block/char **device** nodes (dircolors `bd`/`cd`) need root (`mknod`) and are
deliberately omitted (this role is no-root); inspect real ones under `/dev`.
