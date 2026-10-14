#!/bin/bash
# Counts the rows of a run by script, so the report header never depends on an
# agent's arithmetic. Prints the header lines audit-sweeps.sh wrote plus the
# verdict counts when verdicts.md exists.
#   audit-summary.sh [--out <dir>]
set -u
OUT="/tmp/audit-code"
[[ "${1:-}" == "--out" ]] && OUT="${2:?--out needs a dir}"
[[ -f "$OUT/header.txt" ]] && cat "$OUT/header.txt"
cand=0; [[ -f "$OUT/candidates.md" ]] && cand=$(grep -cE '^\| [A-Z]+[0-9]*-[0-9]+ \|' "$OUT/candidates.md" || true)
line="Candidates: $cand"
if [[ -f "$OUT/verdicts.md" ]]; then
  s=$(grep -cE '^\| [A-Z]+[0-9]*-[0-9]+ \| *survives' "$OUT/verdicts.md" || true)
  d=$(grep -cE '^\| [A-Z]+[0-9]*-[0-9]+ \| *discarded' "$OUT/verdicts.md" || true)
  o=$(grep -cE '^\| [A-Z]+[0-9]*-[0-9]+ \| *out-of-scope' "$OUT/verdicts.md" || true)
  line="$line · Survive: $s · Discarded: $d · Out of scope: $o"
fi
echo "$line"
