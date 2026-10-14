#!/bin/bash
# Prints the ref the audit compares against when the caller gives none:
# `main`, then `master` (local, then origin/). Prints HEAD when the checked-out
# branch is that base itself, so on main only uncommitted work is the delta.
#   default-base.sh
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
base=""
for b in main master; do
  if git show-ref --verify --quiet "refs/heads/$b"; then base="$b"; break; fi
  if git show-ref --verify --quiet "refs/remotes/origin/$b"; then base="origin/$b"; break; fi
done
base="${base:-HEAD}"
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
[[ "$current" == "${base#origin/}" ]] && base="HEAD"
echo "$base"
