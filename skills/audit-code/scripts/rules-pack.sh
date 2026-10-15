#!/bin/bash
# Writes the mechanical half of the rules pack, so reviewers and verifier
# measure against what the project declares, not against what a session
# remembers. The lead fills the SESSION sections by reading the docs listed.
#   rules-pack.sh [--out <dir>]            default out: /tmp/audit-code
# Writes:
#   rules-pack.md    sections; `not defined` where the project declares nothing
#   rules-pack.env   DS_CANONICAL, DS_WRAPPER, FORBIDDEN, DS_EXEMPT, ALIASES,
#                    UTILITIES, TAILWIND, LOCALES_DIRS, I18N_HOOK — read by audit-sweeps.sh
# Normative docs: CLAUDE.md, AGENTS.md, .cursor/rules/*, .github/copilot-instructions.md,
# every docs/*.md they link, and every path listed in .audit-code/rules.md.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="/tmp/audit-code"
[[ "${1:-}" == "--out" ]] && OUT="${2:?--out needs a dir}"
mkdir -p "$OUT"
MD="$OUT/rules-pack.md"; ENV="$OUT/rules-pack.env"
prune=(-not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*')

docs=$( {
  for d in CLAUDE.md AGENTS.md .github/copilot-instructions.md; do [[ -f "$d" ]] && echo "$d"; done
  ls .cursor/rules/*.md .cursor/rules/*.mdc 2>/dev/null
  for d in CLAUDE.md AGENTS.md; do [[ -f "$d" ]] && grep -oE '(docs|doc|\.github|\.claude|\.cursor)/[A-Za-z0-9_./-]+\.mdc?' "$d"; done
  [[ -f .audit-code/rules.md ]] && grep -oE '^[-*] *`?[A-Za-z0-9_./-]+\.mdc?' .audit-code/rules.md | sed -E 's/^[-*] *`?//'
} | sort -u | while read -r d; do [[ -f "$d" ]] && echo "$d"; done )
nested=$(find . -mindepth 2 -maxdepth 5 \( -name AGENTS.md -o -name CLAUDE.md \) "${prune[@]}" -not -path '*/examples/*' -not -path '*/test/*' -not -path '*/tests/*' -not -path '*/fixtures/*' 2>/dev/null | sed 's#^\./##' | sort)

aliases=$(find . -maxdepth 4 -name "tsconfig*.json" "${prune[@]}" 2>/dev/null | sort | while read -r t; do
  python3 - "$t" <<'PY' 2>/dev/null
import json, re, sys
raw = open(sys.argv[1]).read()
raw = re.sub(r"//[^\n]*", "", raw); raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S); raw = re.sub(r",(\s*[}\]])", r"\1", raw)
try: d = json.loads(raw)
except Exception: sys.exit(0)
for k, v in (d.get("compilerOptions", {}).get("paths") or {}).items():
    print(f"- `{k}` → `{', '.join(v)}` ({sys.argv[1]})")
PY
done)
n_aliases=$(echo "$aliases" | grep -c . || true)

pkgs=$(find . -maxdepth 4 -name package.json "${prune[@]}" 2>/dev/null)
ds_canonical=""; ds_wrapper=""
if [[ -n "$pkgs" ]]; then
  ds_canonical=$(cat $pkgs 2>/dev/null | grep -oE '"@[a-z0-9-]+/(ds|design-system|design)[a-z0-9-]*"' | tr -d '"' | sort -u | head -3 | paste -sd'|' -)
  if [[ -n "$ds_canonical" ]]; then
    ds_wrapper=$(for p in $pkgs; do grep -qE "\"(${ds_canonical})\"" "$p" && grep -qE '"name": *"@[^"]*/ui' "$p" && grep -oE '"name": *"[^"]+"' "$p" | sed -E 's/"name": *"([^"]+)"/\1/'; done | sort -u | paste -sd'|' -)
  fi
fi

locales=$(find . -maxdepth 6 -type d \( -name locales -o -name i18n -o -name messages -o -name translations \) "${prune[@]}" 2>/dev/null | sort | paste -sd',' -)
i18n_hook=$(grep -rhoE "\buse[A-Z][A-Za-z]*Lang\b|\buseTranslation\b|\buseIntl\b|\buseTranslations\b" --include=*.tsx --include=*.ts --include=*.vue --include=*.svelte . 2>/dev/null | sort | uniq -c | sort -rn | head -3 | awk '{print $2 " (" $1 ")"}' | paste -sd', ' -)

utilities=$(grep -rhoE "^@utility [a-zA-Z0-9-]+" --include=*.css . 2>/dev/null | awk '{print $2}' | sort -u)
n_util=$(echo "$utilities" | grep -c . || true)
tw_config=$(find . -maxdepth 4 -name "tailwind.config.*" "${prune[@]}" 2>/dev/null | paste -sd', ' -)
tailwind=no
if [[ -n "$tw_config" ]] || grep -rqlE '^@import ["'"'"']tailwindcss|^@tailwind ' --include=*.css . 2>/dev/null; then tailwind=yes; fi

rule_lines=$(for d in $docs; do grep -nEi "never|forbidden|banned|deprecated|must not|only through|do not|don't" "$d" | sed "s#^#$d:#"; done | head -60)

{
  echo "# rules pack"
  echo
  echo "Mechanical sections written by \`rules-pack.sh\`; sections marked SESSION are filled by the lead after reading the docs listed. \`not defined\` means the project declares nothing, and the lens item that depends on it is skipped, never guessed."
  echo
  echo "## Normative docs read"
  if [[ -n "$docs" ]]; then echo "$docs" | sed 's/^/- /'; else echo "not defined (no CLAUDE.md, AGENTS.md or .audit-code/rules.md)"; fi
  if [[ -n "$nested" ]]; then
    echo
    echo "Nested agent docs — each applies to the files under its own directory; read the ones whose directory contains a file in scope:"
    echo "$nested" | sed 's/^/- /'
  fi
  echo
  echo "## Alias registry"
  if [[ -n "$aliases" ]]; then echo "$aliases"; else echo "not defined"; fi
  echo
  echo "## Design system"
  echo "- canonical package: ${ds_canonical:-not defined}"
  echo "- wrapper alias (only allowed entry point): ${ds_wrapper:-not defined}"
  echo "- component catalog: SESSION — path of the catalog doc, or not defined"
  echo "- icon library: SESSION — or not defined"
  echo "- forbidden libraries: SESSION — list them and append \`FORBIDDEN='lib-a|lib-b'\` to rules-pack.env; or not defined"
  echo "- allowed deep imports of the canonical package: SESSION — set \`DS_EXEMPT='@scope/ds/icons'\` in rules-pack.env; or not defined"
  echo
  echo "## Architecture ruleset"
  echo "SESSION — every explicit rule about layers and what each may import or do, quoted with its source line; or not defined. Candidate lines found in the docs:"
  if [[ -n "$rule_lines" ]]; then echo "$rule_lines" | sed 's/^/    /' | cut -c1-200; else echo "    (none matched)"; fi
  echo
  echo "## i18n"
  echo "- locales: ${locales:-not defined}"
  echo "- hook: ${i18n_hook:-not defined}"
  echo "- namespace convention: SESSION — or not defined"
  echo "- files where translation calls are forbidden: SESSION — or not defined"
  echo
  echo "## Token registry"
  echo "- tailwind: $tailwind${tw_config:+ ($tw_config)}"
  echo "- @utility names: $n_util${utilities:+ ($(echo "$utilities" | head -8 | paste -sd', ' -)…)}"
  echo
  echo "## Deprecated or banned APIs"
  echo "SESSION — the list from the normative docs, or not defined"
} > "$MD"

{
  echo "DS_CANONICAL='${ds_canonical}'"
  echo "DS_WRAPPER='${ds_wrapper}'"
  echo "FORBIDDEN=''"
  echo "DS_EXEMPT=''"
  echo "ALIASES=${n_aliases}"
  echo "UTILITIES=${n_util}"
  echo "TAILWIND=${tailwind}"
  echo "LOCALES_DIRS='${locales}'"
  echo "I18N_HOOK='${i18n_hook%% *}'"
} > "$ENV"

echo "rules-pack: docs $(echo "$docs" | grep -c .) · nested $(echo "$nested" | grep -c .) · aliases $n_aliases · DS ${ds_canonical:-none} → ${ds_wrapper:-none} · tailwind $tailwind · utilities $n_util · locales $(echo "$locales" | tr ',' '\n' | grep -c .) · SESSION sections: 6 → $MD"
