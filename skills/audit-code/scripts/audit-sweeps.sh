#!/bin/bash
# Runs every deterministic sweep of audit-code in one command and writes the
# candidates for the verifier, so a skipped sweep is visible: the last line says
# how many ran. Two modes, picked from where you stand:
#   branch    a branch other than main: the working tree against main (merge-base),
#             uncommitted work included. `--base <ref>` overrides.
#   codebase  on main with a clean tree, or `--scope <path>…` anywhere: the code
#             as it is, against the project's own rules. No delta, no "pre-existing".
#   audit-sweeps.sh [--base <ref>] [--scope <path>…] [--out <dir>] [--dry-run]
# Writes under --out (default /tmp/audit-code):
#   files.txt         every file in scope        code_files.txt   code files only
#   added_lines.txt   path:line:text             candidates.md    one row per hit
#   header.txt        the lines the report header copies
#   chunks/<n>.txt    codebase mode over the cap: one reviewer round per chunk
# Reads, when present: <out>/rules-pack.env (rules-pack.sh), .audit-code/config.env
# (thresholds), .audit-code/sweeps.md (project sweeps, see assets/sweeps.example.md).
# Thresholds live here and in .audit-code/config.env, nowhere else.
set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$SCRIPTS/.." && pwd)"
WT="$SCRIPTS/with-timeout.sh"

AUDIT_REVIEWER_FILES=8
AUDIT_REVIEWER_LINES=300
AUDIT_CODEBASE_MAX_FILES=60
AUDIT_CODE_EXT='ts|tsx|js|jsx|mjs|cjs|vue|svelte'
AUDIT_UI_EXT='tsx|jsx|vue|svelte'
AUDIT_EXCLUDE='(/__[A-Za-z]+__/|^__[A-Za-z]+__/|\.(test|test-d|spec|stories|d)\.|/node_modules/|/dist/|/build/)'
[[ -f .audit-code/config.env ]] && source .audit-code/config.env

BASE=""; OUT="/tmp/audit-code"; DRY=no; SCOPE=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:?--base needs a ref}"; shift 2;;
    --scope) shift; while [[ $# -gt 0 && "$1" != --* ]]; do SCOPE+=("$1"); shift; done;;
    --out) OUT="${2:?--out needs a dir}"; shift 2;;
    --dry-run) DRY=yes; shift;;
    *) echo "usage: audit-sweeps.sh [--base <ref>] [--scope <path>…] [--out <dir>] [--dry-run]" >&2; exit 2;;
  esac
done
mkdir -p "$OUT"
FILES="$OUT/files.txt"; CODE="$OUT/code_files.txt"; LINES="$OUT/added_lines.txt"; CAND="$OUT/candidates.md"; HEADER="$OUT/header.txt"
[[ -f "$OUT/rules-pack.env" ]] && source "$OUT/rules-pack.env"

# ---- mode -------------------------------------------------------------------
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
MODE=branch; NOTE=""
if [[ ${#SCOPE[@]} -gt 0 ]]; then
  MODE=codebase
else
  [[ -n "$BASE" ]] || BASE=$("$SCRIPTS/default-base.sh")
  BASE=$(git merge-base "$BASE" HEAD 2>/dev/null || git rev-parse "$BASE")
  "$SCRIPTS/changed-files.sh" --base "$BASE" > "$FILES"
  if [[ ! -s "$FILES" ]]; then
    if [[ "$current" == main || "$current" == master ]]; then
      MODE=codebase; SCOPE=(.)
    else
      echo "Nothing to audit: working tree matches $(git rev-parse --short "$BASE") ($current has no delta against the base)."
      echo "Use --base <ref> to audit a range already merged, or --scope <path> to audit a folder as it is."
      exit 0
    fi
  elif [[ "$BASE" == "$(git rev-parse HEAD)" && ( "$current" == main || "$current" == master ) ]]; then
    NOTE="uncommitted work on $current"
  fi
fi

if [[ "$MODE" == codebase ]]; then
  git ls-files -- "${SCOPE[@]}" 2>/dev/null | grep -E "\.($AUDIT_CODE_EXT)$" | grep -vE "$AUDIT_EXCLUDE" | sort -u > "$FILES"
  cp "$FILES" "$CODE"
  : > "$LINES"
  while IFS= read -r f; do [[ -f "$f" ]] && awk -v f="$f" '{ print f ":" NR ":" $0 }' "$f"; done < "$CODE" >> "$LINES"
  BASE_LABEL="**Mode:** codebase · **Scope:** $(printf '%s ' "${SCOPE[@]}" | sed 's/ $//')"
  if [[ ! -s "$CODE" ]]; then
    echo "Nothing to audit: no code files (${AUDIT_CODE_EXT}) under $(printf '%s ' "${SCOPE[@]}")minus the exclusions in .audit-code/config.env."
    exit 0
  fi
else
  grep -E "\.($AUDIT_CODE_EXT)$" "$FILES" | grep -vE "$AUDIT_EXCLUDE" > "$CODE" || true
  "$SCRIPTS/changed-lines.sh" --base "$BASE" | grep -F -f <(sed 's/$/:/' "$CODE") > "$LINES" || true
  BASE_LABEL="**Mode:** branch · **Base:** $(git rev-parse --short "$BASE")${NOTE:+ ($NOTE)}"
fi

n_files=$(grep -c . "$CODE" || true)
n_lines=$(grep -c . "$LINES" || true)
UI="$OUT/ui_files.txt"; grep -E "\.($AUDIT_UI_EXT)$" "$CODE" > "$UI" || true
n_ui=$(grep -c . "$UI" || true)
surface=backend; lenses="structure, types-and-state"
if (( n_ui > 0 )); then surface=ui; lenses="structure, types-and-state, styling-and-i18n"; fi
reviewers=no
if [[ "$MODE" == codebase ]] || (( n_files > AUDIT_REVIEWER_FILES || n_lines > AUDIT_REVIEWER_LINES )); then reviewers=yes; fi

# codebase mode over the cap: chunk by top-level folder (two path segments)
chunks=1; rm -rf "$OUT/chunks"
if [[ "$MODE" == codebase ]] && (( n_files > AUDIT_CODEBASE_MAX_FILES )); then
  mkdir -p "$OUT/chunks"
  python3 - "$CODE" "$OUT/chunks" "$AUDIT_CODEBASE_MAX_FILES" <<'CHUNKPY'
import math, os, sys
from collections import OrderedDict
files = [l.strip() for l in open(sys.argv[1]) if l.strip()]
out, cap = sys.argv[2], int(sys.argv[3])
groups = OrderedDict()
for f in sorted(files):
    groups.setdefault(os.path.dirname(f) or ".", []).append(f)
target = math.ceil(len(files) / math.ceil(len(files) / cap))
chunks, cur = [], []
for fs in groups.values():
    if cur and len(cur) + len(fs) > target:
        chunks.append(cur); cur = []
    while len(fs) > target:
        chunks.append(fs[:target]); fs = fs[target:]
    cur += fs
if cur: chunks.append(cur)
for i, c in enumerate(chunks, 1):
    with open(os.path.join(out, f"{i:02d}.txt"), "w") as fh: fh.write("\n".join(c) + "\n")
CHUNKPY
  chunks=$(ls "$OUT/chunks" | wc -l | tr -d ' ')
fi

# ---- project sweeps (parsed once, run below) ----------------------------------
PS_DIR="$OUT/project-sweeps"; rm -rf "$PS_DIR"; mkdir -p "$PS_DIR"
n_project=0
if [[ -f .audit-code/sweeps.md ]]; then
  python3 - .audit-code/sweeps.md "$PS_DIR" <<'PY'
import re, sys, pathlib
src, out = pathlib.Path(sys.argv[1]).read_text().splitlines(), pathlib.Path(sys.argv[2])
rows, cur, body, inblock = [], None, [], False
def flush():
    if cur and body:
        (out / f"{cur['id']}.sh").write_text("\n".join(body) + "\n")
        rows.append(cur)
for line in src:
    m = re.match(r"^## +(P\d+) +· +(.+?) +· +class +([ABC]) +· +scope +(files|lines)\s*$", line)
    if m:
        flush(); cur = {"id": m[1], "name": m[2], "class": m[3], "scope": m[4], "cc": "", "change": ""}; body = []; continue
    if cur is None: continue
    if line.startswith("```"):
        inblock = not inblock; continue
    if inblock: body.append(line); continue
    for key in ("counter-check", "change"):
        if line.lower().startswith(key + ":"): cur["cc" if key == "counter-check" else "change"] = line.split(":", 1)[1].strip()
flush()
with open(out / "manifest.tsv", "w") as f:
    for r in rows: f.write("\t".join([r["id"], r["name"], r["class"], r["scope"], r["cc"], r["change"]]) + "\n")
PY
  [[ -f "$PS_DIR/manifest.tsv" ]] && n_project=$(grep -c . "$PS_DIR/manifest.tsv" || true)
fi
TOTAL=$((10 + n_project))

# ---- plan (what runs, what is skipped and why) --------------------------------
has_npx=no; command -v npx >/dev/null 2>&1 && has_npx=yes
declare -a plan_run=() plan_skip=()
want() { plan_run+=("$1"); }
skip() { plan_skip+=("$1 ($2)"); }
want "1 type safety"
if [[ $has_npx == yes ]] && (( n_files > 1 )); then want "2 duplication"; else skip 2 "npx missing or single file"; fi
if [[ $has_npx == yes ]] && (( n_files > 0 )); then want "3 import cycles"; else skip 3 "npx missing or no files"; fi
has_eslint=no
if [[ -x node_modules/.bin/eslint ]] && [[ -n "$(find . -maxdepth 3 \( -name 'eslint.config.*' -o -name '.eslintrc*' \) -not -path '*/node_modules/*' 2>/dev/null | head -1)" ]]; then has_eslint=yes; fi
if [[ $has_npx == yes && $has_eslint == yes ]] && (( n_files > 0 )); then want "4 lint warnings"; else skip 4 "eslint not installed or no config"; fi
if (( ${ALIASES:-0} > 0 )); then want "5 alias-able import"; else skip 5 "no tsconfig paths"; fi
if [[ -n "${DS_CANONICAL:-}${FORBIDDEN:-}" ]]; then want "6 DS bypass / forbidden"; else skip 6 "no DS_CANONICAL/FORBIDDEN in rules-pack.env"; fi
if (( n_ui > 0 )); then want "7 memo without consumer"; want "8 several components per file"; else skip 7 "no UI files"; skip 8 "no UI files"; fi
if (( n_ui > 0 )) && [[ "${TAILWIND:-no}" == yes ]]; then want "9 static inline style"; else skip 9 "no UI files or no tailwind"; fi
if (( n_ui > 0 )) && (( ${UTILITIES:-0} > 0 )); then want "10 arbitrary var(--)"; else skip 10 "no UI files or no @utility registry"; fi

{
  echo "$BASE_LABEL · **Files:** $n_files · **Added lines:** $n_lines · **Surface:** $surface"
  echo "files: $n_files · added lines: $n_lines · surface: $surface · lenses: $lenses · reviewers: $reviewers (threshold $AUDIT_REVIEWER_FILES code files or $AUDIT_REVIEWER_LINES added code lines)$( (( chunks > 1 )) && echo " · chunks: $chunks (structure and types-and-state once per chunk, styling-and-i18n once over ui_files.txt; $OUT/chunks/)")"
} > "$HEADER"

if [[ $DRY == yes ]]; then
  cat "$HEADER"
  echo "would run ($(( ${#plan_run[@]} + n_project ))/$TOTAL): $(IFS=,; echo "${plan_run[*]}")$( (( n_project > 0 )) && echo ", project: $(cut -f1,2 "$PS_DIR/manifest.tsv" | tr '\t' ' ' | paste -sd',' -)")"
  [[ ${#plan_skip[@]} -gt 0 ]] && echo "would skip: $(IFS=,; echo "${plan_skip[*]}")"
  echo "code files → $CODE · added lines → $LINES"
  exit 0
fi

# ---- candidates ----------------------------------------------------------------
{
  echo "# candidates — sweeps"
  echo
  echo "$(head -1 "$HEADER")"
  echo
  echo "## Candidates"
  echo "| id | lens | class | files | change | rule violated | proposed counter-check |"
  echo "| --- | --- | --- | --- | --- | --- | --- |"
} > "$CAND"

ran=0; skipped=("${plan_skip[@]}")
# row <id-prefix> <class> <name> <counter-check> <change>; hits on stdin as path:line[:text]
row() {
  local n="$1" cls="$2" name="$3" cc="$4" change="$5" k=0 loc text desc
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    k=$((k + 1))
    loc="${hit%%:*}:$(echo "$hit" | cut -d: -f2)"
    text=$(echo "$hit" | cut -d: -f3- | sed -e 's/^ *//' -e 's/|/\\|/g' | cut -c1-160)
    desc="$text"; [[ -n "$change" && -n "$text" ]] && desc="$change — \`$text\`"; [[ -n "$change" && -z "$text" ]] && desc="$change"
    if [[ "$MODE" == branch ]]; then
      if [[ "$loc" == *:0 ]]; then desc="whole file · $desc"; elif ! grep -qF "$loc:" "$LINES"; then desc="pre-existing on base · $desc"; fi
    fi
    printf '| %s-%s | sweep | %s | `%s` | %s | sweep %s · %s | %s |\n' "$n" "$k" "$cls" "$loc" "$desc" "$n" "$name" "$cc" >> "$CAND"
  done
}
ran_sweep() { ran=$((ran + 1)); }
each_file() { while IFS= read -r f; do [[ -f "$f" ]] && "$@" "$f"; done < "$CODE"; }
each_ui_file() { while IFS= read -r f; do [[ -f "$f" ]] && "$@" "$f"; done < "$UI"; }
ui_lines() { grep -F -f <(sed 's/$/:/' "$UI") "$LINES" 2>/dev/null || true; }
export -f each_file each_ui_file ui_lines; export CODE LINES UI
MOVED='`git show <base>:<path>` — moved code carries its debt'
in_plan() { printf '%s\n' "${plan_run[@]}" | grep -q "^$1 "; }

# S1 type safety on added lines
grep -En ":[[:space:]]*any\b|\bas any\b|as unknown as|\bas [A-Z]\w*|[]A-Za-z_)]![[:space:]]*[.;),]|@ts-(ignore|expect-error)" "$LINES" | cut -d: -f2- | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|/?\*)" \
  | row S1 A "type safety" "Stub or wrapper with a looser signature — read the real \`.d.ts\`; a cast hiding a real mismatch → out of scope" "narrow to the type the code already proves"; ran_sweep
# S2 duplication between files in scope (jscpd, JSON report, clones with both files in scope)
if in_plan 2; then
  dirs=$(sed -E 's#/[^/]+$##' "$CODE" | sort -u | tr '\n' ' ')
  rm -rf "$OUT/jscpd"
  "$WT" 180 npx --yes jscpd --min-lines 4 --min-tokens 40 --reporters json --output "$OUT/jscpd" --silent --absolute --format "typescript,tsx,javascript,jsx" $dirs >/dev/null 2>&1
  python3 - "$OUT/jscpd/jscpd-report.json" "$CODE" "$PWD" "$LINES" "$MODE" <<'PY' 2>/dev/null | row S2 B "duplication" "Duplication — \`diff\` the two blocks, enumerate the differing lines" "extract the identical block once; nearly identical ≠ identical"
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
code = set(l.strip() for l in open(sys.argv[2]) if l.strip()); root = sys.argv[3].rstrip("/") + "/"
added = set()
for l in open(sys.argv[4]):
    parts = l.split(":", 2)
    if len(parts) >= 2 and parts[1].isdigit(): added.add((parts[0], int(parts[1])))
branch = sys.argv[5] == "branch"
def first_added(name, start, n):
    return next((i for i in range(start, start + max(n, 1)) if (name, i) in added), None)
for c in d.get("duplicates", []):
    a, b = c["firstFile"], c["secondFile"]
    an, bn = a["name"].replace(root, ""), b["name"].replace(root, "")
    if an not in code or bn not in code: continue
    n = c.get("lines", 0) or 0
    if not branch:
        print(f"{an}:{a['start']}:clone of {n or '?'} lines with {bn}:{b['start']}"); continue
    la, lb = first_added(an, a["start"], n), first_added(bn, b["start"], n)
    if la is not None:
        print(f"{an}:{la}:clone of {n or '?'} lines ({an}:{a['start']}) with {bn}:{b['start']}")
    elif lb is not None:
        print(f"{bn}:{lb}:clone of {n or '?'} lines ({bn}:{b['start']}) with {an}:{a['start']}")
PY
  ran_sweep
fi
# S3 import cycles among the directories in scope (madge)
if in_plan 3; then
  dirs=$(sed -E 's#/[^/]+$##' "$CODE" | sort -u | tr '\n' ' ')
  "$WT" 180 npx --yes madge --circular --basedir . --extensions ts,tsx,js,jsx $dirs 2>/dev/null | grep -E "^[0-9]+\) " | sed -E 's/^[0-9]+\) (.*)/\1:0:cycle \1/' \
    | awk -v code="$CODE" 'BEGIN { while ((getline l < code) > 0) inb[l]=1 } { split($0, parts, ":0:cycle "); m=split(parts[1], fs, " > "); ok=1; for (i=1;i<=m;i++) if (!(fs[i] in inb)) ok=0; if (ok) print }' \
    | row S3 B "import cycles" "Architecture or boundary rule — a cycle only partly in scope is \`Apply: no\`" "move the shared type or constant to its own file"
  ran_sweep
fi
# S4 lint warnings on added lines (eslint per config dir, JSON, intersected with added lines)
if in_plan 4; then
  python3 - "$CODE" "$WT" <<'PY' 2>/dev/null \
    | awk -F: 'NR==FNR { added[$1 ":" $2]=1; next } ($1 ":" $2) in added' "$LINES" - \
    | row S4 A "lint warnings on added lines" "$MOVED" "fix the warning on the added line"
import json, os, subprocess, sys
from collections import defaultdict
files = [l.strip() for l in open(sys.argv[1]) if l.strip()]; wt = sys.argv[2]
names = ("eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "eslint.config.ts", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc")
def cfg_dir(path):
    d = os.path.dirname(os.path.abspath(path))
    while True:
        if any(os.path.exists(os.path.join(d, n)) for n in names): return d
        if d == os.getcwd() or d == "/": return os.getcwd()
        d = os.path.dirname(d)
groups = defaultdict(list)
for f in files: groups[cfg_dir(f)].append(f)
root = os.getcwd()
for d, fs in groups.items():
    rel = [os.path.relpath(os.path.abspath(f), d) for f in fs]
    try:
        out = subprocess.run([wt, "300", "npx", "--no-install", "eslint", "--format", "json", *rel], cwd=d, capture_output=True, text=True).stdout
        data = json.loads(out[out.index("["):])
    except Exception: continue
    for r in data:
        p = os.path.relpath(r["filePath"], root)
        for m in r.get("messages", []):
            print(f"{p}:{m.get('line', 0)}:{m.get('ruleId') or 'error'} — {m.get('message', '')[:80]}")
PY
  ran_sweep
fi
# S5 deep relative import an alias covers (only where a tsconfig declares paths)
if in_plan 5; then
  grep -En "from ['\"](\.\./){2,}" "$LINES" | cut -d: -f2- | row S5 A "alias-able import" "Alias-able import — resolve both against the workspace tsconfig paths and the bundler config" "use the alias from the registry when one resolves to the same file"; ran_sweep
fi
# S6 DS wrapper bypass and forbidden imports (needs rules-pack.env)
if in_plan 6; then
  alt="${DS_CANONICAL:-}"; [[ -n "${FORBIDDEN:-}" ]] && alt="${alt:+$alt|}$FORBIDDEN"
  grep -En "from ['\"]($alt)(/[^'\"]*)?['\"]" "$LINES" | { if [[ -n "${DS_EXEMPT:-}" ]]; then grep -vE "from ['\"]($DS_EXEMPT)"; else cat; fi; } | cut -d: -f2- \
    | row S6 A "DS wrapper bypass / forbidden import" "DS wrapper bypass — the wrapper must re-export the symbol; a forbidden library is \`Apply: no\`" "import through \`${DS_WRAPPER:-the wrapper alias}\`"
  ran_sweep
fi
# S7 useMemo / useCallback without an identity consumer
if in_plan 7; then
  each_ui_file grep -EHn "\b(useMemo|useCallback)\b" | grep -vE ":[0-9]+:[[:space:]]*(import |//|/?\*)" | row S7 A "memo without consumer" "\"Simplify to the canonical equivalent\" — grep the memoised name in its consumers for an identity dependency" "drop the memo when nothing depends on identity"; ran_sweep
fi
# S8 several components in one UI file
if in_plan 8; then
  while IFS= read -r f; do [[ -f "$f" ]] || continue; c=$(grep -cE "^(export )?(default )?function [A-Z]\w*\(|^(export )?const [A-Z]\w* = \(" "$f"); (( c > 2 )) && echo "$f:0:$c components"; done < "$UI" \
    | row S8 B "several components in one file" "Several components in one file — read the second one's size" "each extra component to its own file with a barrel"; ran_sweep
fi
# S9 inline style with a static utility-class equivalent
if in_plan 9; then
  ui_lines | grep -En "style=\{\{[^}]*:\s*['\"][^'\"]+['\"]" | cut -d: -f2- | row S9 A "static inline style" "\"Simplify to the canonical equivalent\" — prove the computed CSS on the target platform" "replace with the class that compiles to the same CSS"; ran_sweep
fi
# S10 arbitrary [var(--x)] for a project-owned variable
if in_plan 10; then
  ui_lines | grep -En "\[var\(--[a-z]" | grep -vE "var\(--(radix|rn|reka)-" | cut -d: -f2- | row S10 A "arbitrary [var(--)]" "grep the \`@utility\` in the styles; absent → new utility, \`Apply: no\`" "use the registered utility"; ran_sweep
fi
# P* project sweeps from .audit-code/sweeps.md
if (( n_project > 0 )); then
  while IFS=$'\t' read -r pid pname pclass pscope pcc pchange; do
    [[ -n "$pid" ]] || continue
    "$WT" 120 bash "$PS_DIR/$pid.sh" 2>/dev/null | row "$pid" "$pclass" "$pname" "${pcc:-\"Does not follow the convention\" — count the precedent across the repo}" "$pchange"; ran_sweep
  done < "$PS_DIR/manifest.tsv"
fi

total_hits=$(grep -cE "^\| (S|P)[0-9]+-" "$CAND" || true)
sk=""; [[ ${#skipped[@]} -gt 0 ]] && sk=" · skipped: $(IFS=,; echo "${skipped[*]}")"
echo "Sweeps: $ran/$TOTAL · candidates: $total_hits$sk" >> "$HEADER"
sed -n '2,3p' "$HEADER"
