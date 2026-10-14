#!/bin/bash
# Prints one path per line for every file the working tree changed against the
# base: committed, staged, unstaged and untracked (an untracked file whose
# content the base already has is dropped). Renames resolve to the new path.
# Optional prefixes narrow the result.
#   changed-files.sh --base <ref> [prefix…]
# Exits 0 with no output when nothing changed, so callers must guard.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BASE=""
if [[ "${1:-}" == "--base" ]]; then
  BASE="${2:?usage: changed-files.sh --base <ref> [prefix…]}"; shift 2
fi
[[ -n "$BASE" ]] || BASE=$("$(dirname "$0")/default-base.sh")

tracked=$(git diff --name-only --diff-filter=d "$BASE" 2>/dev/null)
fresh=""
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  blob=$(git rev-parse -q --verify "$BASE:$file" 2>/dev/null) || { fresh+="$file"$'\n'; continue; }
  [[ "$blob" == "$(git hash-object "$file")" ]] || fresh+="$file"$'\n'
done < <(git ls-files --others --exclude-standard 2>/dev/null)

all=$(printf '%s\n%s' "$tracked" "$fresh" | grep -v '^$' | sort -u)
if [[ $# -eq 0 ]]; then echo "$all" | grep -v '^$' || true; exit 0; fi
pattern=$(printf '%s\n' "$@" | sed 's|/*$||' | sed 's/[.[\*^$]/\\&/g' | sed 's|^\(.*\)$|^\1(/\|$)|' | paste -sd'|' -)
echo "$all" | grep -E "$pattern" || true
