#!/bin/bash
# Prints every line the working tree ADDED against the base, one per line as
# `path:line:text`, so a check judges only what the branch wrote and never the
# neighbours a file already had. A file the base does not have contributes
# every line. Optional prefixes narrow the files, like changed-files.sh.
#   changed-lines.sh --base <ref> [prefix…]
# Exits 0 with no output when nothing was added.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
BASE=""
if [[ "${1:-}" == "--base" ]]; then
  BASE="${2:?usage: changed-lines.sh --base <ref> [prefix…]}"; shift 2
fi
[[ -n "$BASE" ]] || BASE=$("$SCRIPTS/default-base.sh")

files=$("$SCRIPTS/changed-files.sh" --base "$BASE" "$@")
[[ -n "$files" ]] || exit 0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  if git cat-file -e "$BASE:$file" 2>/dev/null; then
    git diff -U0 "$BASE" -- "$file" | awk -v f="$file" '
      /^@@/ { split($3, a, ","); line = substr(a[1], 2) + 0; next }
      /^\+\+\+/ { next }
      /^\+/ { print f ":" line ":" substr($0, 2); line++; next }
      /^-/ { next }
      { line++ }'
  else
    awk -v f="$file" '{ print f ":" NR ":" $0 }' "$file"
  fi
done <<< "$files"
