#!/bin/bash
# Builds a small TypeScript fixture with planted issues, runs the scripts over
# it in both modes and asserts the hits. No network is needed except for jscpd
# and madge (npx); set SMOKE_OFFLINE=1 to skip those two assertions.
#   tests/smoke.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/audit-code"; S="$SKILL/scripts"
FX="$ROOT/tests/.fixture"; OUT="$ROOT/tests/.out"; rm -rf "$OUT"
fail=0
ok()   { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fail=1; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

rm -rf "$FX"; mkdir -p "$FX"; cd "$FX"
git init -q -b main .; git config user.email smoke@example.com; git config user.name smoke
mkdir -p src/utils src/features/card src/features/list src/features/cycle src/styles .audit-code
cat > tsconfig.json <<'T'
{ "compilerOptions": { "baseUrl": ".", "paths": { "@app/*": ["src/*"] }, "jsx": "react-jsx", "strict": true } }
T
cat > package.json <<'T'
{ "name": "fixture", "private": true, "scripts": { "lint": "node -e \"process.exit(0)\"" }, "dependencies": { "react": "^19.0.0" } }
T
cat > CONTRIBUTING.md <<'T'
# Contributing
Pull request descriptions must be written by a human, in your own voice.
T
cat > CLAUDE.md <<'T'
# Fixture rules
- Components never import another feature's internals directly.
- A private props type is named `Props`.
T
printf '@import "tailwindcss";\n@utility bg-brand { background: var(--brand); }\n' > src/styles/app.css
cat > src/utils/format.ts <<'T'
export function formatPrice(value: number) {
  return `$${value.toFixed(2)}`;
}
T
cat > src/features/card/Card.tsx <<'T'
import { useMemo } from 'react';

interface CardProps { title: string; price: number }

export function Card({ title, price }: CardProps) {
  const label = useMemo(() => title.toUpperCase(), [title]);
  return <div>{label} {price}</div>;
}
T
cp "$SKILL/assets/config.example.env" .audit-code/config.env
cp "$SKILL/assets/sweeps.frontend.md" .audit-code/sweeps.md
git add -A; git commit -qm "base"

# ---- feature branch with planted issues --------------------------------------
git checkout -qb feat/planted
cat > src/features/card/Card.tsx <<'T'
import { useMemo } from 'react';
import { formatPrice } from '../../utils/format';

interface CardProps { title: string; price: number }

export function Card({ title, price }: CardProps) {
  const label = useMemo(() => title.toUpperCase(), [title]);
  return <div className="bg-[var(--brand)]" style={{ textAlign: 'center' }}>{label} {formatPrice(price)}</div>;
}

function Badge({ text }: { text: string }) { return <span>{text}</span>; }
function Footer() { return <footer>end</footer>; }
T
cat > src/features/list/useList.ts <<'T'
export function useList(items: unknown[]) {
  const data = items as any;
  const first = data[0]!.name;
  const total = data.length;
  const empty = total === 0;
  const label = empty ? 'none' : `${total} items`;
  return { first, total, empty, label };
}
T
cat > src/features/list/useOther.ts <<'T'
export function useOther(items: unknown[]) {
  const data = items as unknown as { name: string }[];
  const first = data[0]!.name;
  const total = data.length;
  const empty = total === 0;
  const label = empty ? 'none' : `${total} items`;
  return { first, total, empty, label };
}
T
printf "import { b } from './b';\nexport const a = () => b();\n" > src/features/cycle/a.ts
printf "import { a } from './a';\nexport const b = () => a();\n" > src/features/cycle/b.ts
git add -A; git commit -qm "planted"

echo "== rules pack"
"$S/rules-pack.sh" --out "$OUT"
check "aliases detected"      "grep -q 'ALIASES=1' $OUT/rules-pack.env"
check "tailwind detected"     "grep -q 'TAILWIND=yes' $OUT/rules-pack.env"
check "utility detected"      "grep -q 'UTILITIES=1' $OUT/rules-pack.env"
check "CLAUDE.md listed"      "grep -q '^- CLAUDE.md' $OUT/rules-pack.md"
check "contribution policy"   "grep -q 'written by a human' $OUT/rules-pack.md"

echo "== dry run"
dry=$("$S/audit-sweeps.sh" --out "$OUT" --dry-run)
echo "$dry" | sed 's/^/    /'
check "dry run names mode"    "echo \"\$dry\" | grep -q 'Mode:\*\* branch'"
check "dry run lists sweeps"  "echo \"\$dry\" | grep -q 'would run'"
check "dry run skips DS"      "echo \"\$dry\" | grep -q '6 (no DS_CANONICAL'"

echo "== branch mode"
out=$("$S/audit-sweeps.sh" --out "$OUT"); echo "$out" | sed 's/^/    /'
C="$OUT/candidates.md"
check "surface ui"            "grep -q 'surface: ui' $OUT/header.txt"
check "reviewers no (4 files)" "grep -q 'reviewers: no' $OUT/header.txt"
check "S1 any + cast + bang"  "[ \$(grep -c '^| S1-' $C) -eq 4 ]"
check "S5 deep import"        "grep -q '^| S5-1 .*utils/format' $C"
check "S7 memo pre-existing"  "grep -q '^| S7-1 .*Card.tsx:7. | pre-existing on base' $C"
check "S8 three components"   "grep -q '^| S8-1 .*whole file .*3 components' $C"
check "S9 inline style"       "grep -q '^| S9-1 .*textAlign' $C"
check "S10 var(--brand)"      "grep -q '^| S10-1 .*var(--brand)' $C"
check "P1 CardProps"          "grep -q '^| P1-1 .*CardProps' $C"
check "P3 project sweep ran"  "grep -q 'Sweeps: [0-9]*/15' $OUT/header.txt"
if [[ "${SMOKE_OFFLINE:-0}" != 1 ]]; then
  check "S2 jscpd clone"      "grep -q '^| S2-1 .*clone of' $C"
  check "S3 madge cycle"      "grep -q '^| S3-1 .*cycle' $C"
fi
echo "== apply-check and dts-diff"
ac=$("$S/apply-check.sh"); echo "$ac" | sed 's/^/    /'
check "apply-check runs lint" "echo \"\$ac\" | grep -q '| \`lint\` | 0 |'"
if [[ "${SMOKE_OFFLINE:-0}" != 1 ]]; then
  dd=$("$S/dts-diff.sh" --base main --out "$OUT/dts"); echo "$dd" | sed 's/^/    /'
  check "dts-diff sees the new hook" "echo \"\$dd\" | grep -q 'useList.d.ts (added)'"
  dd2=$("$S/dts-diff.sh" --base HEAD --out "$OUT/dts")
  check "dts-diff identical on HEAD" "echo \"\$dd2\" | grep -q '^d.ts: identical'"
fi
check "summary counts"        "\"$S/audit-summary.sh\" --out $OUT | grep -q 'Candidates: [1-9]'"

echo "== codebase mode (main, clean tree)"
git checkout -q main
out=$("$S/audit-sweeps.sh" --out "$OUT"); echo "$out" | sed 's/^/    /'
check "mode codebase"         "grep -q 'Mode:\*\* codebase' $OUT/header.txt"
check "reviewers yes"         "grep -q 'reviewers: yes' $OUT/header.txt"
check "no pre-existing mark"  "! grep -q 'pre-existing' $OUT/candidates.md"
check "S7 memo on base file"  "grep -q '^| S7-1 ' $OUT/candidates.md"

echo "== scope from a branch"
git checkout -q feat/planted
"$S/audit-sweeps.sh" --out "$OUT" --scope src/features/list >/dev/null
check "scope limits files"    "[ \$(grep -c . $OUT/code_files.txt) -eq 2 ]"

echo "== nothing to audit"
git checkout -qb feat/empty main
msg=$("$S/audit-sweeps.sh" --out "$OUT")
check "empty delta message"   "echo \"\$msg\" | grep -q 'Nothing to audit'"

echo "== init"
rm -rf .audit-code; "$S/audit-init.sh" --surface backend >/dev/null
check "init creates files"    "[ -f .audit-code/config.env ] && [ -f .audit-code/rules.md ] && grep -q 'P11' .audit-code/sweeps.md"

cd "$ROOT"; [[ $fail -eq 0 ]] && echo "smoke: all green" || { echo "smoke: failures"; exit 1; }
