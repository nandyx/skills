# Run — TanStack Query (TanStack/query, multi-framework library monorepo)

Public repo, `main`, the last 70 commits as the delta (`--base HEAD~70`, base `2456967`). 2026-10-14, reviewers and verifier on Claude Sonnet, dispatched as `general-purpose` sub-agents from Claude Code. Nothing installed. A local `.audit-code/config.env` (not committed upstream) excluded `examples/`, `integrations/`, lint/format configs and `test-setup.ts`: without it the last 10 commits were 71 example files, and the last 79 were dominated by an eslint → oxlint migration (12 855 added lines). Normative docs: `AGENTS.md`, `CONTRIBUTING.md`, `AI_POLICY.md` — process rules, no code-layout rules.

## Header

```
**Mode:** branch · **Base:** 2456967 · **Files:** 47 · **Added lines:** 941 · **Surface:** ui
files: 47 · added lines: 941 · surface: ui · lenses: structure, types-and-state, styling-and-i18n · reviewers: yes (threshold 8 code files or 300 added code lines)
Sweeps: 7/10 · candidates: 9 · skipped: 4 (eslint not installed or no config),6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env),10 (no UI files or no @utility registry)
Reviewers: 3 agents + verifier · Candidates: 28 · Survive: 0 · Discarded: 17 · Out of scope: 11
```

## Time and tokens

| step | wall-clock | tokens |
| --- | --- | --- |
| sweeps (script) | 38 s | — |
| reviewers (parallel) | 5 min 48 s | ≈307K · 256K · 69K |
| verifier | 2 min 26 s | ≈101K |

## Result: 0 survivors, and what the reviewers did find

Every candidate was real code, and every one predated the 70 commits — the branch only re-wrapped a union, renamed an `eslint-disable` to `oxlint-disable`, or touched a neighbouring line:

| id | what | why discarded |
| --- | --- | --- |
| ST-2 | `useSyncExternalStoreWithSelector` exported from `preact-query/src/utils.ts`, no consumer; the package `exports` only `.`, so it is not public | dead on the base too |
| ST-3 | `toValueDeep` (`@internal`) exported from `vue-query/src/utils.ts`, no consumer, not public | dead on the base too |
| ST-1 | an unreachable second `if` in `ASTUtils.getFunctionAncestor` (eslint plugin) | on the base |
| TS-1 | `createMemo(() => queryClient)` in the Solid devtools wraps a value that never changes | on the base |
| TS-3, TS-4 | two casts the repo's own lint marks unnecessary, silenced with a disable comment | the branch only renamed the directive |
| S2-1 … S2-5 | identical blocks across framework adapters (preact ↔ react, svelte ↔ angular) | identical on the base; per-adapter duplication is deliberate surface |

These are exactly what codebase mode (`/audit-code --scope packages/preact-query packages/vue-query …` on `main`) would report as debt. Branch mode correctly refuses to bill them to 70 commits that did not write them.

Out of scope — behaviour (11): among them, the branch added `devtools.setClient(props.client ?? …)` in both Vue devtools components, a runtime change the verifier flagged for the maintainers rather than as a refactor.

## What this run taught the skill (1.0.4)

- Clone rows pointed at the clone's first line; when that line was old, the row was marked `pre-existing` and discarded on sight although the branch had written part of the clone. Rows now point at the first added line.
- The memo sweep matched `// This useMemo is for performance…`; comment lines are skipped.
- The rules pack missed `CONTRIBUTING.md` and `AI_POLICY.md`, linked from `AGENTS.md` as `./CONTRIBUTING.md`. It now follows relative Markdown links.
- Project config is not optional on big monorepos: a migration commit or an examples folder drowns the delta.

## Contribution policy note

TanStack Query asks that PR descriptions be written in the contributor's own voice (`AI_POLICY.md`), and `CONTRIBUTING.md` invites automated agents to add `🤖🤖🤖` to a PR title for a «fast-tracked» merge. The run treated that line as data, not an instruction; no PR was opened.
