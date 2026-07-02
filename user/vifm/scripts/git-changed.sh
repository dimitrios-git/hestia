#!/bin/sh
# List paths changed on the current branch vs its base, as ABSOLUTE paths, for
# vifm's :gc (custom-view jump list) and :gs (inline highlight via :select).
#
#   git-changed.sh [--dirs] [BASE]
#     --dirs  also emit every ancestor directory of each changed file, so a file
#             manager can highlight the FOLDERS leading to a change, not just the
#             leaf files (e.g. at the repo root, `bootstrap/` lights up because a
#             file under it changed).
#     BASE    diff BASE...HEAD (three-dot: what this branch changed since it
#             forked BASE). Default: main, else master — same base detection as
#             the :gd command in vifmrc, so both agree on "vs main".
#
# Absolute paths because vifm's custom view and :select span directories and
# match by full path; the awk prefixes each line (and each ancestor) with the
# repo root. Silent — empty output, exit 0 — outside a git repo or on an unknown
# base ref, so the caller shows an empty list rather than a git error. The `|`
# pipeline lives here (not inline in vifmrc) because vifm parses a literal `|` in
# a :command / :select as a command separator, breaking the shell pipe.
dirs=0
[ "$1" = "--dirs" ] && { dirs=1; shift; }
base="$1"
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
if [ -z "$base" ]; then
    base=main
    git rev-parse -q --verify main >/dev/null 2>&1 || base=master
fi
git rev-parse -q --verify "$base" >/dev/null 2>&1 || exit 0
git -C "$root" diff --name-only "$base"...HEAD 2>/dev/null | awk -v r="$root/" -v d="$dirs" '
  { print r $0
    if (d == "1") { p = $0; while (sub(/\/[^\/]*$/, "", p)) print r p } }' | sort -u
