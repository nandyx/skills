# Changelog

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
