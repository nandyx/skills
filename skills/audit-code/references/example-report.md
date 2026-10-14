# Example report

Produced over the fixture that `tests/smoke.sh` builds: five code files, 25 added lines, seven planted issues, no eslint and no `node_modules`. The header and the sweep rows are the scripts' output verbatim. The delta is under the reviewer threshold, so no reviewer ran; the verdicts follow `references/agents/verifier.md` row by row and show the three outcomes a candidate can have.

---

# audit — feat/planted

**Mode:** branch · **Base:** 404a226 · **Files:** 5 · **Added lines:** 25 · **Surface:** ui
Sweeps: 14/15 · candidates: 12 · skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env)
Reviewers: verifier only · Candidates: 12 · Survive: 4 · Discarded: 4 · Out of scope: 4

## Findings

| id | Class | Files | Change | Evidence | Apply |
| --- | --- | --- | --- | --- | --- |
| S5-1 | A | `src/features/card/Card.tsx:2` | `import { formatPrice } from '@app/utils/format'` | `tsconfig.json paths: @app/* → src/*`; `ls src/utils/format.ts` → exists; no bundler config in the repo, tsconfig is the only resolver | yes |
| S10-1 | A | `src/features/card/Card.tsx:8` | `bg-[var(--brand)]` → `bg-brand` | `grep -n "@utility bg-brand" src/styles/app.css` → `2:@utility bg-brand { background: var(--brand); }` | yes |
| S2-1 | B | `src/features/list/useList.ts:3-7`, `src/features/list/useOther.ts:3-7` | extract lines 3–7 into one `summarize(data)` helper in `src/features/list/summarize.ts`; both hooks call it | `diff <(sed -n 3,7p src/features/list/useList.ts) <(sed -n 3,7p src/features/list/useOther.ts)` → 0 differing lines; line 2 (the cast) differs and stays in each hook | yes |
| S3-1 | B | `src/features/cycle/a.ts`, `src/features/cycle/b.ts` | each file calls the other at call time only; move both into `src/features/cycle/index.ts` or break the edge by passing `b` into `a` | `npx madge --circular --basedir . --extensions ts src/features/cycle` → `1) src/features/cycle/a.ts > src/features/cycle/b.ts`; both files in scope | yes |

**Riskiest:** S3-1 — breaking a cycle changes module evaluation order; it goes last, after the type-check passes on the other three.

Order: S5-1 → S10-1 → gate (type-check) → S2-1 → gate (type-check, the two hooks' tests if any) → S3-1 → gate.

## Out of scope — behaviour

| id | files | what | evidence |
| --- | --- | --- | --- |
| S1-1 | `src/features/list/useList.ts:2` | `items as any` hides a real mismatch: the parameter is `unknown[]` and the code reads `.name` on its elements | no guard, no `satisfies`, no narrower input type anywhere in the file; narrowing it means deciding what `items` really is |
| S1-2 | `src/features/list/useList.ts:3` | `data[0]!.name` asserts a non-empty array nothing proves | `empty = total === 0` is computed two lines later, so the code itself admits the array can be empty |
| S1-3 | `src/features/list/useOther.ts:2` | `as unknown as { name: string }[]` — same mismatch as S1-1 with a double cast | same |
| S1-4 | `src/features/list/useOther.ts:3` | same as S1-2 | same |

## Already planned

(none — the fixture has no `.audit-code/register.md`)

## False positives discarded

| id | reason | evidence |
| --- | --- | --- |
| S7-1 | pre-existing on base | `git show 404a226:src/features/card/Card.tsx \| grep -c useMemo` → 1; the memo was there before the branch |
| P1-1 | pre-existing on base | `git show 404a226:src/features/card/Card.tsx \| grep -c "interface CardProps"` → 1 |
| S8-1 | second and third components are one-liners | `Badge` and `Footer` are one line each (`sed -n 11,12p src/features/card/Card.tsx`); the lens bar is «a second component close to the parent's size», a one-line helper is not a hit |
| S9-1 | not verifiable | the counter-check «prove the computed CSS on the target platform» needs the project's Tailwind build; `ls node_modules/tailwindcss` → no such file, so `text-center ≡ text-align: center` cannot be proven here and the row is not promoted by hand |

## Verified facts

| claim | how it was checked | result |
| --- | --- | --- |
| `Card.tsx` does not import another feature's internals (CLAUDE.md rule 1) | `grep -n "from '" src/features/card/Card.tsx` | imports `react` and `../../utils/format`; `utils/` is not a feature |
| `@app/*` is the only alias and it resolves to `src/*` | `rules-pack.md § Alias registry` | 1 entry, `tsconfig.json` |
| the duplication is between two files both in scope | `grep -c useList.ts\|useOther.ts code_files.txt` | 2 |
| sweep 6 skipped for a reason, not a failure | `header.txt` | `skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env)` — the fixture has no design-system package |

## Verification the user runs

- After S5-1 and S10-1: `npx tsc --noEmit` → 0 errors; `grep -rn "\.\./\.\./utils" src` → 0.
- After S2-1: `npx tsc --noEmit`; `grep -c "summarize(" src/features/list/*.ts` → 3 (one definition, two calls).
- After S3-1: `npx madge --circular --extensions ts src/features/cycle` → `✔ No circular dependency found!`
- Visual pass: `Card` renders with the same computed background (`bg-brand` is the registered utility for `var(--brand)`); the inline `textAlign` stays until S9-1 can be proven in a repo with Tailwind installed.
