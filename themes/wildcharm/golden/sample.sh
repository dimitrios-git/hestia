#!/usr/bin/env bash
# Golden sample — shell. Variables, quoting, substitution, tests, a heredoc.
set -euo pipefail

PALETTE="${1:-themes/wildcharm/palette.yml}"
count=0

if [[ ! -f "$PALETTE" ]]; then
  echo "missing palette: $PALETTE" >&2
  exit 1
fi

while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  count=$((count + 1))
done < "$PALETTE"

cat <<EOF
palette : $(basename "$PALETTE")
lines   : $count
checked : $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
