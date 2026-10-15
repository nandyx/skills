# Run — excalidraw (excalidraw/excalidraw, React/TS monorepo)

Public repo, `master`, the last 8 commits as the delta (`--base HEAD~8`). 2026-10-14, reviewers and verifier on Claude Sonnet, dispatched as `general-purpose` sub-agents from Claude Code. `yarn install` done so the project's eslint ran (0 warnings on added lines). Normative docs found: CLAUDE.md, AGENTS.md, .github/copilot-instructions.md. Two reviewers declared they read `App.tsx` (11 446 lines) and other large edited files through every diff hunk with context instead of whole.

## Header

```
**Mode:** branch · **Base:** 2559257 · **Files:** 34 · **Added lines:** 2726 · **Surface:** ui
files: 34 · added lines: 2726 · surface: ui · lenses: structure, types-and-state, styling-and-i18n · reviewers: yes (threshold 8 code files or 300 added code lines)
Sweeps: 7/10 · candidates: 67 · skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env),9 (no UI files or no tailwind),10 (no UI files or no @utility registry)
Reviewers: 3 agents + verifier · Candidates: 90 · Survive: 7 · Discarded: 73 · Out of scope: 10
```

## Time and tokens

| step | wall-clock | tokens |
| --- | --- | --- |
| sweeps (script) | 14 s | — |
| reviewers (parallel) | 5 min 30 s | ≈81K · 199K · 213K |
| verifier | 9 min 07 s | ≈172K |

Sweep rows marked `pre-existing on base`: 40 of 71.

## Survivors

The three class `A` rows (ST-1, TS-4, TS-6) were applied as one commit each and opened as a draft PR upstream: https://github.com/excalidraw/excalidraw/pull/12298 (`yarn test:typecheck` 0 errors; selection, crop and frame test files pass, 113 tests). The four class `B` rows were not proposed: they move code inside a refactor that landed days earlier, and that call belongs to the maintainers.

| id | class | files | change | evidence |
| --- | --- | --- | --- | --- |
| S2-7 | B | `packages/element/src/frame.ts:951` | extract the identical block once; nearly identical ≠ identical — `clone of 11 lines with packages/element/src/frame.ts:985` | `diff <(sed -n 951,961p packages/element/src/frame.ts) <(sed -n 985,995p packages/element/src/frame.ts)` → only the opening line and one blank line differ; the body (`isElementInFrame(...{ targetFrame: frame, checkedGroups })`, `for (groupId of element.groupIds) checkedGroups?.set(groupId, shouldCli… |
| ST-1 | A | `packages/excalidraw/components/App.selection.ts:348`, `packages/excalidraw/components/App.selection.ts:455` | drop the `export` keyword from `getSelectionStateAddingElements` and `getSelectionStateRemovingElements`; they are consumed only by `AppSelection.add` and `AppSelection.remove` in the same file | `git grep -nw -e getSelectionStateAddingElements -e getSelectionStateRemovingElements` → only App.selection.ts:348, :455 (definitions) and :577, :599 (in-file calls); no `.md`/`.mdx`/docs hit; `ExcalidrawImperativeAPI.selection` is `Pick<..., "select"\|"add"\|"remove"\|"clear">` (types.ts:1396-1398)… |
| ST-2 | B | `packages/excalidraw/components/App.selection.ts:243-249`, `packages/excalidraw/components/App.selectionTool.ts:1475-148 | add `export const getSelectableGroupId = (element, editingGroupId)` to `App.selection.ts` (returns `groupIds[indexOf(editingGroupId) > -1 ? slice(0, i) : all].at(-1)`), use it in `getFramesSelectedViaGroups` (`App.selection.ts`) and make `AppSelectionTool.getS | `diff <(sed -n 243,249p App.selection.ts) <(sed -n 1477,1483p App.selectionTool.ts)` → only the local name differs (`elementGroupIds` vs `groupIds`); fallback differs (skip vs `element.id`); `git grep -n getFramesSelectedViaGroups 2559257` → 0 so the `App.selection.ts` copy is new (`git blame` → e65… |
| ST-3 | B | `packages/excalidraw/actions/actionBoundText.tsx:386-407`, `packages/excalidraw/components/App.wrap.ts:65-70` | export `rebind` from `actionBoundText.tsx` (moved verbatim from `App.wrap.ts`, which then imports it next to `bindTextToContainer`), and in `wrapTextsInContainers` replace the two `if (…Binding?.elementId === textElement.id) { …Binding = { …Binding, elementId: | `sed -n 386,407p actionBoundText.tsx` vs `App.wrap.ts:65-70`: same «swap `elementId` when it equals X»; the inline block is on base (`git show 2559257:packages/excalidraw/actions/actionBoundText.tsx \| sed -n 316,340p`) while `rebind` is new in App.wrap.ts (`git grep -n 'const rebind' 2559257` → 0);… |
| TS-4 | A | `packages/excalidraw/components/App.selection.ts:745-747` | remove the cast `as readonly (ExcalidrawElement \| string)[]` after the `isReadonlyArray(elementsOrIds) ? elementsOrIds : [elementsOrIds]` ternary: `isReadonlyArray` is `value is readonly any[]` over the union `ElementsOrIds`, so the true branch narrows to `re | `git grep -n 'isReadonlyArray(elementsOrIds)' 2559257` → 0 (new line); `isReadonlyArray` is `value is readonly any[]` (common/src/utils.ts:1149); in-memory tsc with the `as readonly (ExcalidrawElement \| string)[]` cast removed → 0 diagnostics, and a probe `const p: number = elementOrId` reports `st… |
| TS-5 | B | `packages/excalidraw/actions/actionBoundText.tsx:341`, `packages/excalidraw/components/App.wrap.ts:145-161` | drop the explicit `: ActionResult` annotation of `wrapTextsInContainers` (its only `return` is an object literal, so inference gives the object arm without `false`), then in `AppWrap.toggle` drop `result &&` and `result.appState?.` (`appState` is always set in | single `return` object literal in `wrapTextsInContainers` (actionBoundText.tsx:336-436); in-memory tsc with `: ActionResult` dropped, `result &&` and `result.appState?.` removed in App.wrap.ts → 0 diagnostics for the whole program (baseline also 0); callers: actionBoundText.tsx:322 and App.wrap.ts:1… |
| TS-6 | A | `packages/element/src/cropElement.ts:191` | narrow the parameters of the local `uncrops` from `(side: string, opposite: string)` to the union of side letters the four call sites pass (`"n" \| "s" \| "e" \| "w"`) | `git grep -n 'uncrops' 2559257 -- packages` → 0 (new); the four calls pass `"w","e"`, `"n","s"`, `"e","w"`, `"s","n"` (cropElement.ts:197-200); in-memory tsc with params typed `"n" \| "s" \| "e" \| "w"` → 0 diagnostics for the whole program |

## Why the rest was discarded

| reason | rows |
| --- | --- |
| pre-existing on base | 48 |
| moved code | 16 |
| convention | 4 |
| false positive | 2 |
| not new | 2 |
| no written rule | 1 |

Out of scope — behaviour: 10 rows (real bugs or behaviour questions the verifier confirmed and the plan does not touch; see the run's `verdicts.md`).

## Verified facts

- Typecheck baseline at HEAD is clean — in-memory `ts.createProgram` over `tsconfig.json` (no file written) → 0 diagnostics; every mutation above was tested the same way against that baseline
- Intra-package imports in `packages/excalidraw` are relative, not aliased — `git grep -hE 'from "\.\.?/' -- 'packages/excalidraw/*.ts' 'packages/excalidraw/*.tsx' | wc -l` → 2177 vs 4 self-alias imports; the alias rule in CLAUDE.md governs cross-package imports
- `import type App from "./App"` is the repo's pattern for the `App.*.ts` helpers — `git grep -l 'import type App from' 2559257 -- packages | wc -l` → 26 files on base; all new `App.selection`/`App.wrap` cycle edges close through it and are erased at runtime
- No import-cycle rule is written anywhere — `git grep -niE 'cycle|circular' AGENTS.md CLAUDE.md .github/copilot-instructions.md` → only an unrelated «CPU cycles» line; `.eslintrc.json` has no `import/no-cycle`
- The branch does add one new value-import cycle, `cropElement.ts → resizeElements.ts → binding → collision → shape → renderElement → cropElement` (OS-4); it resolves because every use is inside a function body
- `0 as Radians` is the repo idiom — `git grep -n '0 as Radians' 2559257 -- 'packages/*.ts' 'packages/*.tsx'` → 23 hits on base, no named zero-angle constant
- `App.selection.ts` has no other unused export beyond the two in ST-1 among the new `getSelectionState*` helpers: `getSelectionStateForElements` has consumers in actionBoundText.tsx, actionDuplicateSelection.tsx, App.wrap.ts, App.duplicate.ts
- HelpDialog.tsx and CommandPalette.tsx did not gain a component — sweep-8 regex count is unchanged (6 → 6, 5 → 5)
- Sweep S2 rows marked `pre-existing on base` (38 of 39) were discarded on sight without re-measuring; S2-7 is the only clone the branch introduced
