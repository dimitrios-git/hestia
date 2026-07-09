#!/usr/bin/env bash
# comment; TODO: builtins, vars, operators
set -euo pipefail

readonly MAX=10
declare -a items=()

greet() {
  local name="${1:-world}"
  if [[ "$name" == "root" ]] && (( MAX > 5 )); then
    printf 'hi %s\n' "$name"
    return 0
  fi
  for i in "${items[@]}"; do echo "$i"; done
}

greet "$@"
