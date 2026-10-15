# Changelog

## 1.0.1 — 2026-10-14

First two runs on public repos, written up in `docs/runs/` (the three class `A` rows from excalidraw became upstream draft PR excalidraw/excalidraw#12298): excalidraw (React/TS, 34 files, 90 candidates → 7 survive) and nestjs/nest (Node/TS, 15 files, 31 candidates → 1 survives). What they changed:

- Sweep 1 skips comment lines (five JSDoc sentences had matched `as any` / `!` on nest).
- Sweep 4 skips with a reason when the project has no eslint config or binary (nest lints with oxlint).
- `audit-summary.sh` counts by the verdict column, not by the id's shape (a verifier wrote `OS-1 [structure]`).
- Reviewers may read a file over 1 500 lines by diff hunks with context, and must say so in the hand-back (`App.tsx`, 11 446 lines).
- Verifier: a compiler found outside the repo may be used read-only and must be named in Verified facts.

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
