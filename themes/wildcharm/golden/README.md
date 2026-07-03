# Golden sample

The fixed snippet set for cross-platform theme verification
(`docs/theme-roadmap.md`, "Verification"). Coherence checks always render **this
content** on every platform, so differences are theme differences, not content
differences. **Don't edit the samples** casually — every past screenshot/render
comparison is against them; if a sample must grow (a role isn't exercised), note
it in the roadmap changelog.

Render them per platform:

| Platform | Command |
|---|---|
| vim / nvim | `vim themes/wildcharm/golden/sample.ts` (repeat per file) |
| bat (+ vifm preview) | `batcat --theme=wildcharm themes/wildcharm/golden/sample.ts` |
| glow | `glow themes/wildcharm/golden/sample.md` |
| Shiki / web | the stoa checkout renders these in thecodingidiot's code blocks (see the roadmap's consumer table) |

What each file exercises: `sample.ts` — comments/TODO, strings + escapes +
interpolation + regex, numbers/booleans/null, keywords/operators, types &
interfaces, functions/methods, `this`, import (preproc); `sample.sh` — shebang,
variables, quoting, substitution, tests, heredoc; `sample.diff` — add/delete/
change + hunk headers; `sample.md` — headings, bold/italic, code span, link,
quote, fenced block.
