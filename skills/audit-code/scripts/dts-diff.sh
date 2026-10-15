#!/bin/bash
# Compares the type declarations a TypeScript project emits on a base ref with
# the ones it emits on a tree (the working tree, or a verifier's scratch copy),
# so «no change to the public types» is a command and not a claim. Nothing is
# written to the repo: the base is extracted with `git archive` under --out.
#   dts-diff.sh [--base <ref>] [--tree <dir>] [--tsconfig <path>] [--out <dir>]
#     --base      default HEAD
#     --tree      default the repo's working tree
#     --tsconfig  default tsconfig.json (relative to the repo root)
#     --out       default /tmp/audit-code/dts
# Prints one line and exits:
#   0  `d.ts: identical (<n> files)`
#   1  `d.ts: <k> of <n> files differ` followed by the differing paths; the
#      verifier decides, per path, whether it is reachable from the package's
#      `exports` map (public) or internal
#   2  `d.ts: not comparable (<why>)`
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2
ROOT="$PWD"; WT="$(cd "$(dirname "$0")" && pwd)/with-timeout.sh"
BASE=HEAD; TREE="$ROOT"; TSCONFIG=tsconfig.json; OUT=/tmp/audit-code/dts
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:?}"; shift 2;;
    --tree) TREE="$(cd "${2:?}" && pwd)"; shift 2;;
    --tsconfig) TSCONFIG="${2:?}"; shift 2;;
    --out) OUT="${2:?}"; shift 2;;
    *) echo "usage: dts-diff.sh [--base <ref>] [--tree <dir>] [--tsconfig <path>] [--out <dir>]" >&2; exit 2;;
  esac
done
[[ -f "$TREE/$TSCONFIG" ]] || { echo "d.ts: not comparable (no $TSCONFIG in $TREE)"; exit 2; }
if [[ -x "$ROOT/node_modules/.bin/tsc" ]]; then TSC=("$ROOT/node_modules/.bin/tsc"); else TSC=(npx --yes -p typescript tsc); fi
rm -rf "$OUT"; mkdir -p "$OUT/base-src" "$OUT/base" "$OUT/tree"
git archive "$BASE" | tar -x -C "$OUT/base-src" || { echo "d.ts: not comparable (git archive $BASE failed)"; exit 2; }
[[ -d "$ROOT/node_modules" ]] && ln -s "$ROOT/node_modules" "$OUT/base-src/node_modules"
emit() { (cd "$1" && "$WT" 600 "${TSC[@]}" -p "$TSCONFIG" --declaration --emitDeclarationOnly --noEmit false --declarationMap false --sourceMap false --incremental false --composite false --outDir "$2" >/dev/null 2>&1); }
emit "$OUT/base-src" "$OUT/base"; emit "$TREE" "$OUT/tree"
n=$(find "$OUT/tree" -name '*.d.ts' | wc -l | tr -d ' ')
nb=$(find "$OUT/base" -name '*.d.ts' | wc -l | tr -d ' ')
(( n > 0 && nb > 0 )) || { echo "d.ts: not comparable (tsc emitted base $nb / tree $n declaration files)"; exit 2; }
changed=$(python3 - "$OUT/base" "$OUT/tree" <<'CMP'
import pathlib, sys
b, w = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
fb = {p.relative_to(b).as_posix(): p for p in b.rglob("*.d.ts")}
fw = {p.relative_to(w).as_posix(): p for p in w.rglob("*.d.ts")}
for k in sorted(fb.keys() | fw.keys()):
    if k not in fw: print(f"{k} (removed)")
    elif k not in fb: print(f"{k} (added)")
    elif fb[k].read_bytes() != fw[k].read_bytes(): print(k)
CMP
)
if [[ -z "$changed" ]]; then echo "d.ts: identical ($n files)"; exit 0; fi
echo "d.ts: $(echo "$changed" | grep -c .) of $n files differ"
echo "$changed" | sed 's/^/  /'
exit 1
