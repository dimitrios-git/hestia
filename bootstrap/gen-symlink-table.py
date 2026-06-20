#!/usr/bin/env python3
"""Regenerate CLAUDE.md's Active-symlinks table from the bootstrap manifest.

group_vars/all.yml (dotfile_links) is the single source of truth; this keeps the
human-facing table in CLAUDE.md from drifting out of sync with it. Idempotent —
run after editing dotfile_links. The table lives between the BEGIN/END markers in
CLAUDE.md (add them once if missing). See bootstrap/README.md.
"""
import pathlib
import re
import yaml

REPO = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = REPO / "bootstrap" / "group_vars" / "all.yml"
CLAUDE = REPO / "CLAUDE.md"
BEGIN = "<!-- BEGIN active-symlinks (generated from bootstrap/group_vars/all.yml by bootstrap/gen-symlink-table.py — do not edit by hand) -->"
END = "<!-- END active-symlinks -->"

links = yaml.safe_load(MANIFEST.read_text())["dotfile_links"]
rows = ["| Repo file | Symlinked to |", "|---|---|"]
for link in links:
    dest = re.sub(r"\{\{\s*target_home\s*\}\}", "~", link["dest"])
    rows.append(f"| `{link['src']}` | `{dest}` |")
block = BEGIN + "\n" + "\n".join(rows) + "\n" + END

text = CLAUDE.read_text()
pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.DOTALL)
if not pattern.search(text):
    raise SystemExit("BEGIN/END active-symlinks markers not found in CLAUDE.md")
new = pattern.sub(lambda _: block, text)
if new != text:
    CLAUDE.write_text(new)
    print(f"CLAUDE.md table regenerated from {len(links)} manifest links.")
else:
    print(f"CLAUDE.md already in sync ({len(links)} links).")
