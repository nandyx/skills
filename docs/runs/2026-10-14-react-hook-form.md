# Run — react-hook-form, codebase mode

First codebase-mode run with agents. `react-hook-form/react-hook-form`, `master`, `--scope src` (no branch, no base: the code as it is against the project's rules). 2026-10-14, reviewers and verifier on Claude Sonnet, dispatched as `general-purpose` sub-agents from Claude Code. `pnpm install` done, so the project's eslint, `tsc` and jest were available. Normative docs: `CONTRIBUTING.md` (eslint + prettier, `pnpm type`, `pnpm test:type`, `pnpm test`, api-extractor); no architecture rules.

## Header

```
**Mode:** codebase · **Scope:** src · **Files:** 112 · **Added lines:** 9116 · **Surface:** ui
files: 112 · added lines: 9116 · surface: ui · lenses: structure, types-and-state, styling-and-i18n · reviewers: yes · chunks: 3
Sweeps: 6/10 · candidates: 160 · skipped: 5 (no tsconfig paths),6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env),9 (no UI files or no tailwind),10 (no UI files or no @utility registry)
Reviewers: 5 agents + verifier · Candidates: 211 · Survive: 32 · Discarded: 139 · Out of scope: 40
```

## Time and tokens

| step | wall-clock | tokens |
| --- | --- | --- |
| sweeps (script) | 7 s | — |
| reviewers (5 in parallel: structure ×2, types-and-state ×2 over 3 chunks, styling once over 7 UI files) | 6 min | ≈162K · 149K · 195K · 136K · 62K |
| verifier (compiled every cast row alone in a scratch copy, then all 32 together + jest) | 17 min 41 s | ≈247K |

## Survivors (32)

- **26 class A**: 21 type assertions the compiler already proves (each compiled alone and together: `tsc` 0, type tests 0, jest 1 575 green), two dead internal exports (`safeJSON` in `utils/json.ts`, the `Observer` type export), a `useMemo` with no identity consumer, and three cast restructurings (`getEventValue` guard, `hasOwn` as a type guard, one bound `Field` cast).
- **6 class B**: two shared helpers to extract (`isFieldArrayRootErrorShape`, a form-state snapshot), `isFileList` used in three utils, an internal duplicated block in `useFieldArray`, and unused path helper types in `types/path/common.ts` (a policy call: only its own type test uses them).

## Applied

The 21 pure removals became one focused draft PR, one commit each: https://github.com/react-hook-form/react-hook-form/pull/13871. Gates on the branch: `pnpm type` 0, `pnpm test:type` 0, jest 129 suites / 1 575 tests, eslint 0 problems on the 9 files (as on `master`), prettier clean, and `tsc --declaration --emitDeclarationOnly` identical to `master` (only source maps differ). The other five A rows (dead code, the memo, restructurings) and the six B rows are separate topics and were left for separate PRs, per CONTRIBUTING's one-topic rule.

## What this run taught the skill

- **Chunks (1.0.5).** Every folder used to become its own chunk; 130 files gave 5 chunks and 15 reviewers. Chunks are now balanced and keep folders together, and the styling lens runs once over the UI files.
- **Default exclusions (1.0.5).** `__typetest__/` (type tests) counted as code; every `__name__/` folder is excluded now.
- **Compile checks need a scratch copy (1.0.6).** «The code already proves the type» is only evidence when the compiler says so. The verifier now makes a copy outside the tree, records the baseline, applies each row alone, and restores it. 10 sweep rows the reviewers had called deliberate turned out removable; 3 reviewer rows failed with TS2345 and were discarded.
- **Codebase mode is where PRs come from on mature repos.** Four branch-mode runs on merged history produced one PR; the first codebase-mode run produced 26 class A rows.
