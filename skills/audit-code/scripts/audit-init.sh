#!/bin/bash
# Creates .audit-code/ in the current repo: thresholds, the list of normative
# docs and a starter file of project sweeps for the surface you pick. Never
# overwrites a file that exists.
#   audit-init.sh [--surface frontend|backend|both]     default both
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
SURFACE=both
[[ "${1:-}" == "--surface" ]] && SURFACE="${2:?--surface needs frontend|backend|both}"
case "$SURFACE" in frontend|backend|both) ;; *) echo "usage: audit-init.sh [--surface frontend|backend|both]" >&2; exit 2;; esac
mkdir -p .audit-code
created=()
put() { local dst="$1"; shift; if [[ -e "$dst" ]]; then echo "kept    $dst"; else "$@" > "$dst"; created+=("$dst"); echo "created $dst"; fi; }
put .audit-code/config.env cat "$SKILL/assets/config.example.env"
put .audit-code/rules.md cat "$SKILL/assets/rules.example.md"
put .audit-code/register.md cat "$SKILL/assets/register.example.md"
case "$SURFACE" in
  frontend) put .audit-code/sweeps.md cat "$SKILL/assets/sweeps.frontend.md";;
  backend)  put .audit-code/sweeps.md cat "$SKILL/assets/sweeps.backend.md";;
  both)     put .audit-code/sweeps.md cat "$SKILL/assets/sweeps.frontend.md" "$SKILL/assets/sweeps.backend.md";;
esac
echo "Edit .audit-code/rules.md (your normative docs), .audit-code/register.md (work already planned) and .audit-code/sweeps.md (delete the sweeps you do not want). Run \`scripts/audit-sweeps.sh --dry-run\` to see what will run."
