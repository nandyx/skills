# skills

Agent skills by [Nandi Legorreta](https://github.com/nandyx). One so far.

| Skill | What it does | Install |
| --- | --- | --- |
| [**audit-code**](./skills/audit-code/SKILL.md) | Refactor audit with proof for JS/TS projects: every row in the plan survived an executed counter-check | `npx skills add nandyx/skills --skill audit-code` |

---

# audit-code

**Refactor audit with proof.** It audits what your branch changed (or your codebase, on `main`) against the rules *your* repo wrote down, and returns a refactor plan with **zero behaviour and zero visual delta** where every row carries the command that proved it. Review skills hand you hypotheses. This one hands you the ones that survived an attempt to kill them, and the list of the ones that did not.

```
**Mode:** branch · **Base:** 404a226 · **Files:** 5 · **Added lines:** 25 · **Surface:** ui
Sweeps: 14/15 · candidates: 12 · skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env)
Reviewers: verifier only · Candidates: 12 · Survive: 4 · Discarded: 4 · Out of scope: 4

## Findings
| id    | Class | Files                        | Change                                     | Evidence                                              | Apply |
| S5-1  | A     | src/features/card/Card.tsx:2 | import formatPrice from '@app/utils/format' | tsconfig paths @app/* → src/*; ls src/utils/format.ts | yes   |
| S2-1  | B     | useList.ts:3-7 ↔ useOther.ts | extract the 5 identical lines once         | diff → 0 differing lines; line 2 differs and stays    | yes   |

## False positives discarded
| S7-1  | pre-existing on base      | git show 404a226:src/features/card/Card.tsx | grep -c useMemo → 1          |
| S9-1  | not verifiable            | ls node_modules/tailwindcss → no such file; computed CSS cannot be proven here |
```

Full sample, produced from the test fixture: [`references/example-report.md`](./skills/audit-code/references/example-report.md).

## Install

Works with any agent that reads [Agent Skills](https://agentskills.io): Claude Code, Codex, Cursor, OpenCode, Copilot and others.

```bash
# this project (committed with the repo, shared with the team)
npx skills add nandyx/skills --skill audit-code

# every project on this machine
npx skills add nandyx/skills --skill audit-code -g

# a specific agent (default: the ones it detects)
npx skills add nandyx/skills --skill audit-code -a codex
```

Claude Code can also install it as a plugin:

```
/plugin marketplace add nandyx/skills
/plugin install audit-code@nandyx-skills
```

Then, in your repo, once:

```
/audit-code --init frontend      # or backend, or both
```

It creates `.audit-code/` with the thresholds, the list of your normative docs, a register of work already planned and a starter file of project sweeps. Edit the three Markdown files; delete every sweep your docs cannot back.

Requirements: git, bash, python3, Node 18+. `jscpd` and `madge` run through `npx` on demand and are never added to your manifest.

## Use

```
/audit-code                     # on a branch: the working tree against main, uncommitted work included
/audit-code                     # on main with a clean tree: the whole codebase against your rules
/audit-code --scope src/billing # one folder, from any branch
/audit-code --base v2.3.0       # a range already merged
/audit-code --dry-run           # what would run, who would review, nothing executed
/audit-code --apply A           # after the report: apply the mechanical rows, one commit each, re-checked
```

The skill is read-only unless you say `--apply A`. Classes `B` (structural) and `C` (cross-package) are never applied by it.

## Four terms

- **Sweep** — a deterministic command over the files or lines in scope (a regex, `jscpd`, `madge`, your eslint). Ten generic ones ship; your conventions go in `.audit-code/sweeps.md`. A sweep hit is a candidate, never a finding.
- **Lens** — one checklist a reviewer reads every file through: `structure`, `types-and-state`, and `styling-and-i18n` when UI files are in scope. A lens only applies items whose rule the project wrote down.
- **Candidate** — what a sweep or a reviewer proposes: the exact edit, the rule it cites, and a command that would prove or kill it.
- **Counter-check** — the mandatory command per kind of finding ([table](./skills/audit-code/references/counter-checks.md)). The verifier runs it; the row survives because the command said so, never because the reviewer sounded sure.

## How it works

```
rules-pack.sh ─┐
               ├─▶ audit-sweeps.sh ─▶ candidates.md ─┐
.audit-code/ ──┘        │                             │
                        ▼                             ▼
            reviewers: yes? ──▶ 2–3 reviewer agents ─┘──▶ verifier agent ─▶ verdicts.md ─▶ report
            (8 files or 300 lines)   one per lens          counter-check per row     3 tables
```

1. **Rules pack.** What your repo declares: `CLAUDE.md`, `AGENTS.md`, `.cursor/rules`, the docs they link, `tsconfig` paths, design-system package and wrapper, locales, Tailwind utilities. Anything not declared is «not defined», and the lens item that needs it skips itself.
2. **Sweeps.** One command runs them all and prints how many ran. A skipped sweep is visible in the header with its reason.
3. **Reviewers.** Above the size threshold, one fresh-context agent per lens reads every file in full and proposes candidates. Below it, the sweeps alone feed the verifier: whoever finds does not certify.
4. **Verifier.** Always. Adversarial by design: it runs the mandatory counter-check for each candidate's kind, `git show <base>:<path>` for anything claimed new, and writes `survives`, `discarded — <reason>` or `out-of-scope — behaviour`.
5. **Report.** Findings by risk class (`A` mechanical, `B` structural, `C` cross-package), the riskiest named and last, plus three tables that are mandatory even when empty: **Out of scope — behaviour**, **False positives discarded**, **Verified facts**.

## What it never does

- Propose a behaviour change. What looks like a bug is listed under *Out of scope — behaviour* with evidence, never fixed.
- Report a rule nobody wrote down. Preferences are not findings.
- Blame a branch for debt it only moved. Rows on lines the branch did not add are marked `pre-existing on base` and discarded unless you pass `--include-pre-existing`.
- Let an agent count. `audit-summary.sh` counts the rows.
- Install anything into your project, start a server, or edit code outside `--apply A`.

## Supported projects

| Project | Support | What changes |
| --- | --- | --- |
| React, React Native, Next, Vue, Svelte in TS/JS | Full | Three lenses, all ten sweeps |
| Node/TS backend (Nest, Express, Fastify, Deno, Bun) | Full | Two lenses; UI sweeps skip with `no UI files` in the header |
| Monorepo mixing both | Full | Surface is detected per file, aliases per workspace `tsconfig` |
| Other languages | Not supported in 1.0 | The orchestration is language-agnostic, the sweeps and the rules pack are not. Project sweeps in `.audit-code/sweeps.md` can run any shell command, but no language pack ships yet |

## Compared to other review skills

As of 2026-10-14, from [skills.sh](https://skills.sh) and each project's docs.

| | audit-code | mattpocock `code-review` | `improve-codebase-architecture` | alibaba `open-code-review` | `caveman-review` |
| --- | --- | --- | --- | --- | --- |
| Scope | branch delta, or codebase on `main` | branch delta | whole codebase | PR diff | PR diff |
| Finds | refactors against your written rules | standards + spec, Fowler smells | architecture redesigns | defects (NPE, XSS, SQLi) | whatever, one line each |
| Deterministic sweeps | yes, editable per project | no | no | yes, built-in rules | no |
| Verifies each finding | **executed counter-check per row** | no («a hypothesis, not evidence») | no | LLM reflection pass | no |
| Separates pre-existing debt | yes | no | n/a | no | no |
| Lists discarded false positives | yes | no | no | no | no |
| Applies | class `A` on request | no | no | no | no |
| Languages | JS/TS | any | any | 10+ | any |

The others are language-agnostic because they are prompts: nothing runs, so nothing is tied to a language. The price of executing sweeps and reading manifests is a language. 1.0 pays it for JS/TS.

## Numbers

Every number here comes from a run you can reproduce. Full write-ups in [`docs/runs/`](./docs/runs/).

| run | delta | sweeps | candidates | survive | discarded | out of scope | reviewers | verifier |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [excalidraw](./docs/runs/2026-10-14-excalidraw.md) · React/TS, last 8 commits | 34 files · 2 726 lines | 7/10 in 14 s | 90 (40 pre-existing) | **7** | 73 | 10 | 3 agents · 5 min 30 s | 9 min 07 s |
| [nestjs/nest](./docs/runs/2026-10-14-nest.md) · Node/TS, last 25 commits | 15 files · 293 lines | 3/10 in 4 s | 31 (10 pre-existing) | **1** | 26 | 4 | 2 agents · 5 min 59 s | 6 min 03 s |
| [fixture](./skills/audit-code/references/example-report.md) · `tests/smoke.sh` | 5 files · 25 lines | 14/15 | 12 (2 pre-existing) | 4 | 4 | 4 | none | hand-verified |

The three mechanical rows from excalidraw are a [draft PR upstream](https://github.com/excalidraw/excalidraw/pull/12298), one commit each, type-check and tests green. What survived is what the README promises: dead exports after a refactor, a duplicated 11-line block, a cast the code already proves, a parameter type four call sites narrow. What was discarded is the reason the verifier exists: 58 rows of debt the branch only touched, 20 of moved code, 6 «convention» claims the repo contradicts, 5 regex hits inside JSDoc prose (fixed in 1.0.1). Agents ran on Claude Sonnet, 80K–213K tokens per reviewer and 100K–172K per verifier.

Two internal runs on a React/React Native monorepo before publishing (7 and 24 files) had 0 survivors each, with ~20 rows correctly discarded as pre-existing: zero survivors on a disciplined repo is the honest result.

## Project files

```
.audit-code/
  config.env     thresholds, code/UI extensions, exclusions
  rules.md       your normative docs, one path per line
  register.md    work already planned — listed apart, never a finding
  sweeps.md      your conventions as sweeps (format in references/sweeps.md)
```

## Development

```bash
tests/smoke.sh              # builds a fixture, runs both modes, asserts the planted hits
python3 tests/validate-skill.py
```

CI runs both plus `shellcheck` on every push. Runs on public repos are written up in `docs/runs/`.

## License

MIT © Nandi Legorreta
