# Changelog

## 1.0.7 — 2026-10-14

What the react-hook-form PR showed the skill should do itself:

- **Why these matter.** The report carries one line per kind of finding, from `references/why.md` (for example: a redundant `as` switches the compiler off at that point and hides the error if the type changes later).
- **`--apply A` by topic.** Class `A` rows are grouped by kind into one branch each, one commit per row in the project's commit convention, and a `pr-<topic>.md` notes file per branch. Reshaping rows are their own topic. It never pushes or opens a PR.
- **`scripts/apply-check.sh`.** Runs the project's own `type` / `test:type` / `lint` / `test` scripts (or `AUDIT_CHECKS`) with the project's package manager and prints the gate table.
- **`scripts/dts-diff.sh`.** Emits the type declarations of the base (via `git archive`, nothing written to the repo) and of the tree, and compares them file by file. New mandatory counter-check for changes inside published packages; the verifier runs it on its scratch copy.
- **Contribution policy in the rules pack.** Lines about PR descriptions, AI-assisted work, signed commits and changesets are collected; when a project requires human-written descriptions (next.js, TanStack Query), `--apply A` writes technical notes, never a description.

## 1.0.6 — 2026-10-14

From the react-hook-form codebase run (211 candidates → 32 survivors, draft PR react-hook-form/react-hook-form#13871):

- Verifier: when a row needs the compiler («the code already proves the type», a narrowed type, a deleted export), it makes a scratch copy outside the tree, records the baseline type-check, applies the row alone, re-runs and restores. A row survives only with the baseline's diagnostics.

## 1.0.5 — 2026-10-14

First codebase-mode run with agents (react-hook-form `src/`, 112 files):

- Chunks are balanced and keep folders together (`ceil(files / cap)` chunks). Before, every folder became its own chunk: 130 files gave 5 chunks and would have dispatched 15 reviewers.
- `styling-and-i18n` runs once over `ui_files.txt`; only `structure` and `types-and-state` run per chunk.
- Default exclusions cover every `__name__/` folder (`__tests__`, `__mocks__`, `__typetest__`, `__fixtures__`) and `*.test-d.*`.

## 1.0.4 — 2026-10-14

From the TanStack Query run:

- Duplication rows point at the clone's first added line. A clone that started on an old line was marked `pre-existing on base` and discarded on sight although the branch had written part of it (five rows).
- Memo sweep skips comment lines (`// This useMemo is for performance…` matched).
- Rules pack follows relative Markdown links from `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` (`[CONTRIBUTING.md](./CONTRIBUTING.md)` was missed), and lists a `CONTRIBUTING.md` that speaks to AI or agent contributions.

## 1.0.3 — 2026-10-14

Fourth public run: next.js (33 files, 26 candidates → 1 survivor, class C, `Apply: no — public via deep import`; no PR).

- `rules-pack.sh` lists every nested `AGENTS.md` / `CLAUDE.md`; the reviewer reads the ones whose directory contains a file in scope (next.js keeps the React Compiler memo rule in `apps/bundle-analyzer/AGENTS.md`).
- Reviewer: the read-by-hunks exception applies only above 1 500 lines, stated as a hard threshold.

## 1.0.2 — 2026-10-14

- Counter-check «Export with no consumer» reads the package's `exports` map: a wildcard or a path reaching the file makes the symbol public by deep import (`Apply: no`). Found on nestjs/nest, where the run's only survivor deleted such an export; withdrawn before a PR.

## 1.0.1 — 2026-10-14

First two runs on public repos, written up in `docs/runs/` (the three class `A` rows from excalidraw became upstream draft PR excalidraw/excalidraw#12298): excalidraw (React/TS, 34 files, 90 candidates → 7 survive) and nestjs/nest (Node/TS, 15 files, 31 candidates → 1 survives). What they changed:

- Sweep 1 skips comment lines (five JSDoc sentences had matched `as any` / `!` on nest).
- Sweep 4 skips with a reason when the project has no eslint config or binary (nest lints with oxlint).
- `audit-summary.sh` counts by the verdict column, not by the id's shape (a verifier wrote `OS-1 [structure]`).
- Reviewers may read a file over 1 500 lines by diff hunks with context, and must say so in the hand-back (`App.tsx`, 11 446 lines).
- Verifier: a compiler found outside the repo may be used read-only and must be named in Verified facts.
- Duplication sweep keeps only clones that touch an added line in branch mode (tailwindcss: 114 base-only clones → 0). Third public run: tailwindcss, 7 candidates → 0 survive.

## 1.0.0 — 2026-10-14

First public release of `audit-code`, extracted from a private delivery harness after two measured runs.

- Two modes picked from where you stand: **branch** (working tree against `main`, uncommitted work included) and **codebase** (on `main` with a clean tree, or `--scope <path>`).
- Ten generic sweeps for JS/TS, frontend and backend; project conventions live in `.audit-code/sweeps.md` and run as `P<n>` sweeps.
- Surface detection per file: no UI files in scope → two lenses, UI sweeps skipped with the reason in the header.
- Reviewer threshold: 8 code files or 300 added code lines (tests, stories, `.d.ts` and docs never count). Below it, sweeps feed the verifier directly. Measured: counting `plans/` and tests once dispatched three reviewers for one removed button.
- `pre-existing on base` mark on rows whose line the branch did not add; `--include-pre-existing` keeps them. Measured: ~20 of 25 candidates in two runs were debt the branch only touched.
- `--init`, `--dry-run`, `--apply A`, `audit-summary.sh` (counts by script; an agent once reported 23 for 18 rows).
- Portable `with-timeout.sh` (coreutils, Homebrew or perl).
- Smoke test with a fixture of planted issues; CI with shellcheck and frontmatter validation.

Planned next: `.audit-code/runs.jsonl` (one line per run to calibrate thresholds), project lenses (`.audit-code/lenses/*.md`), `--format pr`, language packs for a 2.0.
