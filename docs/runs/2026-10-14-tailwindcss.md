# Run — tailwindcss (tailwindlabs/tailwindcss, TypeScript library)

Public repo, `main`, the last 15 commits as the delta (`--base HEAD~15`, base `fa81d69`). 2026-10-14, reviewers and verifier on Claude Sonnet, dispatched as `general-purpose` sub-agents from Claude Code. No normative docs in the repo (no CLAUDE.md, AGENTS.md or Cursor rules), so every lens item that needs a written rule was skipped. Nothing installed: the repo lints with `turbo lint`, not a root eslint, so sweep 4 skipped with that reason. Three files over 1 500 lines (`ast.ts`, `canonicalize-candidates.ts`, `utilities.ts`) were read by diff hunks with context, declared by both reviewers.

## Header

```
**Mode:** branch · **Base:** fa81d69 · **Files:** 12 · **Added lines:** 413 · **Surface:** backend
files: 12 · added lines: 413 · surface: backend · lenses: structure, types-and-state · reviewers: yes (threshold 8 code files or 300 added code lines)
Sweeps: 3/10 · candidates: 2 · skipped: 4 (eslint not installed or no config),5 (no tsconfig paths),6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env),7 (no UI files),8 (no UI files),9 (no UI files or no tailwind),10 (no UI files or no @utility registry)
Reviewers: 2 agents + verifier · Candidates: 7 · Survive: 0 · Discarded: 5 · Out of scope: 2
```

## Time and tokens

| step | wall-clock | tokens |
| --- | --- | --- |
| sweeps (script) | 4 s | — |
| reviewers (parallel) | 3 min 40 s | ≈163K · 155K |
| verifier | 55 s | ≈71K |

## What the first sweep pass taught the skill

Before 1.0.1's last fix the duplication sweep returned **114 clones**, all between large files on the base and none touched by the branch. The sweep now keeps a clone only when one of its two blocks contains an added line; the same run returned 0 duplication rows.

## Verdicts

| id | verdict | evidence |
| --- | --- | --- |
| S1-1 | discarded — moved code | `git show fa81d69:packages/tailwindcss/src/compat/apply-compat-hooks.ts \| grep -n 'module: any'` → line 38; the branch hoisted the inline type into a `LoadModule` alias |
| S3-1 | discarded — pre-existing on base | the `index.ts` ↔ `apply-compat-hooks.ts` cycle exists on the base |
| ST-1 | discarded — pre-existing on base | `skipUrlReplacer(rawUrl, aliases?)` with one-argument callers is on the base at `urls.ts:153`; the branch only shifted its line |
| ST-2 | discarded — pre-existing on base | `doUrlReplace(..., funcName = 'url')` with callers that never pass it is on the base at `urls.ts:119` |
| TS-1 | discarded — moved code | same `module: any` as S1-1 |
| OS-1 (structure) | out-of-scope — behaviour | `compareOrder` in `canonicalize-candidates.ts` sorts `null` last, the CLI's `defaultSort` sorts it first; merging them would change sort output |
| OS-1 (types-and-state) | out-of-scope — behaviour | a behaviour question in `integrations/utils.ts`, see the run's `verdicts.md` |

ST-1 and ST-2 are real dead parameters. They were discarded because the branch did not write them: on `main` (codebase mode) or with `--include-pre-existing` they would be candidates. That is the rule working, not a miss.

## Result

**0 survivors.** A small, disciplined delta on a library with no written conventions: the lenses had nothing to cite, and everything the sweeps and reviewers raised was debt the 15 commits only touched or moved. No PR.
