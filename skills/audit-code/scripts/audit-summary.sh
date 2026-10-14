#!/bin/bash
# Counts the rows of a run by script, so the report header never depends on an
# agent's arithmetic. Prints the header lines audit-sweeps.sh wrote plus the
# verdict counts when verdicts.md exists.
#   audit-summary.sh [--out <dir>]
set -u
OUT="/tmp/audit-code"
[[ "${1:-}" == "--out" ]] && OUT="${2:?--out needs a dir}"
[[ -f "$OUT/header.txt" ]] && cat "$OUT/header.txt"
rows() { grep -E '^\| [^|]+ \|' "$1" | grep -vE '^\| *(id|---) *\|' || true; }
cand=0; [[ -f "$OUT/candidates.md" ]] && cand=$(rows "$OUT/candidates.md" | grep -c . || true)
line="Candidates: $cand"
if [[ -f "$OUT/verdicts.md" ]]; then
  s=$(rows "$OUT/verdicts.md" | grep -cE '^\| [^|]+ \| *survives' || true)
  d=$(rows "$OUT/verdicts.md" | grep -cE '^\| [^|]+ \| *discarded' || true)
  o=$(rows "$OUT/verdicts.md" | grep -cE '^\| [^|]+ \| *out[- ]of[- ]scope' || true)
  line="$line · Survive: $s · Discarded: $d · Out of scope: $o"
fi
echo "$line"
