#!/bin/bash
# Runs the project's own checks — the ones its package.json declares — so an
# applied row is proven by the same gates a maintainer runs, not by the audit's.
# `.audit-code/config.env` may set AUDIT_CHECKS="type test:type lint test" to
# pick the scripts by name; otherwise the first script found in each category:
#   types      type-check typecheck check-types types type tsc
#   type tests test:type test:types test:typecheck
#   lint       lint
#   tests      test:unit test
#   apply-check.sh [--only <category>…]
# Prints a Markdown table (script, exit, seconds) and exits 1 when any fails.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2
WT="$(cd "$(dirname "$0")" && pwd)/with-timeout.sh"
[[ -f package.json ]] || { echo "apply-check: no package.json"; exit 2; }
[[ -f .audit-code/config.env ]] && source .audit-code/config.env
if [[ -f pnpm-lock.yaml ]]; then PM=(pnpm -s run); command -v pnpm >/dev/null || PM=(npx --yes pnpm -s run)
elif [[ -f yarn.lock ]]; then PM=(yarn -s); command -v yarn >/dev/null || PM=(npx --yes yarn -s)
elif [[ -f bun.lockb || -f bun.lock ]]; then PM=(bun run)
else PM=(npm run -s); fi
scripts=$(python3 -c "import json; print('\n'.join(json.load(open('package.json')).get('scripts', {})))")
pick() { for s in "$@"; do echo "$scripts" | grep -qxF "$s" && { echo "$s"; return; }; done; }
if [[ -n "${AUDIT_CHECKS:-}" ]]; then checks=($AUDIT_CHECKS)
else
  checks=()
  for s in "$(pick type-check typecheck check-types types type tsc)" "$(pick test:type test:types test:typecheck)" "$(pick lint)" "$(pick test:unit test)"; do
    [[ -n "$s" ]] && checks+=("$s")
  done
fi
(( ${#checks[@]} > 0 )) || { echo "apply-check: the project declares no type, lint or test script; set AUDIT_CHECKS in .audit-code/config.env"; exit 2; }
echo "| script | exit | seconds |"; echo "| --- | --- | --- |"
fail=0
for s in "${checks[@]}"; do
  t0=$(date +%s); "$WT" 1200 "${PM[@]}" "$s" >"/tmp/audit-code-check-$s.log" 2>&1; rc=$?
  echo "| \`$s\` | $rc | $(( $(date +%s) - t0 )) |"; (( rc == 0 )) || fail=1
done
(( fail == 0 )) || echo "logs: /tmp/audit-code-check-<script>.log"
exit $fail
