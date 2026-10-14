---
name: audit-code
description: Refactor audit with proof for JavaScript and TypeScript projects, frontend and backend. Audits what a branch changed (or the codebase on main) against the project's own written rules and returns a refactor plan with zero behaviour and zero visual delta, where every row survived an executed counter-check. Deterministic sweeps, one reviewer sub-agent per lens (structure, types and state, styling and i18n), one adversarial verifier that runs the mandatory counter-check behind every candidate, three mandatory tables (findings, false positives discarded, verified facts). Use when the user asks to audit, clean up, review quality, find refactors or align a branch or folder with the repo's conventions before a PR, or invokes /audit-code. Read-only by default; --apply A applies the mechanical rows.
license: MIT
compatibility: Requires git, bash, python3 and Node 18+ (npx runs jscpd and madge ad hoc). Sub-agents are used when the runtime has them; an inline fallback is documented.
metadata:
  author: Nandi Legorreta
  version: "1.0.1"
  repository: https://github.com/nandyx/skills
---

# Audit Code

Audit code against the repo's **own written rules** and return an executable refactor plan where every row carries the command that proved it.

You are the lead of the audit, not its only pair of eyes. You delimit the scope, extract the rules, run the mechanical sweeps, and hand the judgement to fresh contexts: one **reviewer** per lens returns candidates, one **verifier** runs the counter-check behind each of them. Nothing is reported without a command and its output behind it, and nobody certifies what they found themselves.

Paths below are relative to this skill's directory (`scripts/`, `references/`). Resolve it once and pass it to the agents as `skill:`.

## Hard rules

- **Never propose a behaviour change.** The bar is zero functional delta and zero visual delta. What looks like a bug goes under `## Out of scope — behaviour`, with evidence and without a change.
- **Only rules the project wrote down.** A lens reports a rule it can quote from `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/`, or the docs listed in `.audit-code/rules.md`. A rule nobody wrote is a preference, and a preference is never a finding.
- **Never report what is already planned.** `.audit-code/register.md` and anything the user names in the prompt go under «Already planned».
- **The verifier always runs; the reviewers run by size.** `scripts/audit-sweeps.sh` prints `reviewers: yes|no` (threshold: 8 code files **or** 300 added code lines — tests, stories, `.d.ts` and docs never count; the numbers live in that script and in `.audit-code/config.env`, nowhere else). Below the threshold the sweeps alone feed the verifier; you do not apply the lenses yourself, because whoever finds does not certify.
- **Read-only by default.** Produce the plan. `--apply A` is the only mode that edits (Step 7).
- **Language.** Finding types, paths, symbols and commands stay in English. Prose follows the user's language.

## Modes and flags

| | |
| --- | --- |
| *(no flag)* on a branch | **branch mode**: the working tree against `main` (merge-base), uncommitted and untracked work included |
| *(no flag)* on `main` or `master` | **codebase mode** when the tree is clean: the code as it is, against the rules. With uncommitted work: branch mode against HEAD, and the header says so |
| `--base <ref>` | branch mode against that ref (a tag, a commit, `origin/main~3` for a range already merged) |
| `--scope <path>…` | codebase mode over those folders, from any branch |
| `--no-ask` | Step 5 asks nothing; rows carry `Apply` and the caller decides |
| `--dry-run` | prints mode, files, lines, surface, who would review and which sweeps would run or skip, without running anything |
| `--init [frontend\|backend\|both]` | creates `.audit-code/` (thresholds, normative docs, register, starter project sweeps) and stops |
| `--apply A` | after the report, applies the surviving class `A` rows, one commit per row, re-running each row's counter-check |
| `--include-pre-existing` | branch mode: rows on lines the branch did not add stay in the verifier's queue instead of being discarded on sight |

Everything the lead and the agents exchange lives under one working directory, recreated every run: `rm -rf /tmp/audit-code && mkdir -p /tmp/audit-code`.

| File | Written by | Read by |
| --- | --- | --- |
| `files.txt`, `code_files.txt`, `ui_files.txt`, `added_lines.txt`, `header.txt`, `chunks/` | `audit-sweeps.sh` | sweeps, reviewers, report |
| `rules-pack.md`, `rules-pack.env` | `rules-pack.sh` + lead (SESSION sections) | reviewers, verifier, sweeps 5–6, 9–10 |
| `register.md` | lead | reviewers, lead |
| `candidates.<lens>.md` | one per reviewer | lead |
| `candidates.md` | sweeps + the reviewer tables appended by the lead | verifier |
| `verdicts.md` | verifier | lead |

## Step 1 — Rules pack and register

Read the normative docs: `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/*`, `.github/copilot-instructions.md`, every doc they link, and the paths in `.audit-code/rules.md`. Then:

```bash
scripts/rules-pack.sh --out /tmp/audit-code
```

It writes the mechanical half of `rules-pack.md` (docs found, alias registry from every `tsconfig`, design-system package and wrapper from the manifests, locales and i18n hook, Tailwind and `@utility` registry) plus `rules-pack.env` for the sweeps, and leaves the sections marked `SESSION` for you: fill each from the docs it lists, or write «not defined» — a lens whose rule is missing skips itself instead of guessing. Append `FORBIDDEN='lib-a|lib-b'` and `DS_EXEMPT='@scope/ds/icons'` to `rules-pack.env` when the docs name forbidden libraries or allowed deep imports.

Write `/tmp/audit-code/register.md` from `.audit-code/register.md` (if it exists) plus whatever the user said is in flight or deliberately left alone. Empty is a valid register.

## Step 2 — Sweeps: one command, never typed one by one

```bash
scripts/audit-sweeps.sh --out /tmp/audit-code [--base <ref> | --scope <path>…]
```

It picks the mode, measures the delta, runs the ten generic sweeps of `references/sweeps.md` (type safety, duplication, import cycles, lint warnings on added lines, alias-able imports, DS wrapper bypass, memo without consumer, several components per file, static inline styles, arbitrary `var(--)`) plus the project's sweeps from `.audit-code/sweeps.md`, writes every hit as a row of `candidates.md` (`S<n>-<k>` and `P<n>-<k>` ids, class and counter-check per sweep, `pre-existing on base` when the line is not the branch's), and prints the lines the report header copies:

```
files: 11 · added lines: 340 · surface: ui · lenses: structure, types-and-state, styling-and-i18n · reviewers: yes (threshold 8 code files or 300 added code lines)
Sweeps: 14/15 · candidates: 23 · skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env)
```

A skipped sweep is a fact the header carries with its reason, never a failure to hide. `surface: backend` means no UI file is in scope: sweeps 7–10 skip and two lenses run instead of three. In codebase mode over the file cap (60 by default) the script writes `chunks/<n>.txt` by top-level folder and prints `chunks: n`.

If it prints `Nothing to audit`, stop and relay its two suggestions (`--base`, `--scope`).

## Step 3 — Reviewers, one per lens, fresh context

Skip this step when the header says `reviewers: no`.

Dispatch one reviewer per lens the header lists, **all in one message so they run in parallel**, each with the prompt file `references/agents/reviewer.md` and this one-line input:

```
skill: <skill dir> · lens: structure · files: /tmp/audit-code/code_files.txt · rules: /tmp/audit-code/rules-pack.md · register: /tmp/audit-code/register.md · mode: branch <sha> | codebase · out: /tmp/audit-code/candidates.structure.md
```

Same for `types-and-state` and, when `surface: ui`, `styling-and-i18n`. With chunks, one round per chunk (`files:` is the chunk file). Each reviewer reads its lens from `references/lenses/<lens>.md`, every file in full, and returns candidates in the fixed shape plus its `## Out of scope — behaviour` rows and `## Skipped lens items`. When they return, append their tables to `candidates.md`.

How to dispatch depends on the runtime:

- **Claude Code** — the `Agent` tool, `subagent_type: general-purpose`, the prompt file's content followed by the input line. A project may register `references/agents/reviewer.md` as a named agent and pass that type instead.
- **Codex, Cursor and other runtimes with sub-agents or background agents** — the same prompt and input through that facility.
- **No sub-agents** — run each lens yourself, one at a time, writing `candidates.<lens>.md` to disk before opening the next, and write `Reviewers: inline` in the header: the reader must know that finder and certifier shared a context.

Candidates are not findings. Every one of them, sweep hits included, still has to survive Step 4.

## Step 4 — Verification gate

One verifier, **always**, whatever the size. Prompt file `references/agents/verifier.md`, input:

```
skill: <skill dir> · candidates: /tmp/audit-code/candidates.md · rules: /tmp/audit-code/rules-pack.md · mode: branch <sha> | codebase · out: /tmp/audit-code/verdicts.md
```

Add `· include-pre-existing` when the flag was given. It runs the mandatory counter-check of `references/counter-checks.md` for every candidate's kind — not only the one the reviewer proposed — plus `git show <base>:<path>` in branch mode for anything claimed new, confirms or downgrades the class, and writes `verdicts.md`: `survives` with its evidence, `discarded — <reason>`, or `out-of-scope — behaviour`. You never write `verdicts.md`. Without sub-agents, run the verifier role yourself from a fresh read of `candidates.md` only, and keep `Reviewers: inline` in the header.

Then count by script, never by hand:

```bash
scripts/audit-summary.sh --out /tmp/audit-code
```

## Step 5 — Classify by risk, not by severity

Over the rows that survive:

- **A — mechanical**: renames, dead code, narrowed types, import specifiers, class swaps proven identical. Safe in one pass.
- **B — structural**: neutral, but touches component lifecycle, moves code across files or splits a unit. Needs gates between steps.
- **C — cross-package**: moves a symbol between packages, changes what a package exports. Usually its own piece of work.

Out of all three: already planned, needs a product decision, or `Out of scope — behaviour`.

**Ask before writing the plan, not after** (default mode only). Two questions decide its shape and neither is yours to answer: which of A / B / C the user wants applied, and whether anything is in flight that the plan must sequence around. Everything else is a routine judgement call — make it and say so. With `--no-ask`, skip the questions: rows carry `Apply` (`yes` for A and B, `no — <why>` otherwise).

## Step 6 — Report

A refactor plan with an execution order and gates between blocks. The header is the three lines of `header.txt` plus the summary line, verbatim. Then **three tables that are mandatory even when empty**, because an empty table is a measurement and a missing one is a shrug:

```markdown
# audit — <branch or scope>

**Mode:** branch · **Base:** 3f2a9c1 · **Files:** 11 · **Added lines:** 340 · **Surface:** ui
Sweeps: 14/15 · candidates: 23 · skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env)
Reviewers: 3 agents + verifier · Candidates: 23 · Survive: 4 · Discarded: 17 · Out of scope: 2

## Findings
| id | Class | Files | Change | Evidence | Apply |
| --- | --- | --- | --- | --- | --- |
| S5-1 | A | `src/features/card/Card.tsx:2` | import `formatPrice` from `@app/utils/format` | `tsconfig paths @app/* → src/*; vite.config alias idem` → same file | yes |

**Riskiest:** <id> — <why>. It goes last in the order.

## Out of scope — behaviour
## Already planned
## False positives discarded
| id | reason | evidence |
## Verified facts
| claim | how it was checked | result |
```

Close with the verification the user will run: the gates per block, the final greps with their expected counts, and the visual pass that proves zero delta when UI files are involved.

## Step 7 — `--apply A` (only when asked)

For each surviving class `A` row, in report order: make the edit exactly as the `Change` says, re-run the row's counter-check and the project's type-check or test command when one is declared in the normative docs, and commit with `refactor: <id> <change>`. A row whose re-check fails is reverted and moved to `Apply: no — re-check failed: <output>`. B and C are never applied by this skill.
