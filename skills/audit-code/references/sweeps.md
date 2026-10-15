# Deterministic sweeps

`scripts/audit-sweeps.sh` runs every sweep in one command, writes each hit to `candidates.md` as a row and prints how many sweeps ran. This file documents what each one looks for, so the lead and the verifier can read a hit. The commands are the script's, kept here for reading, never for typing one by one: agents skim and miss naming drift, a regex does not.

A hit is a **candidate**, never a finding. Every row carries the sweep as its rule and the counter-check `counter-checks.md` mandates for its kind, and the verifier runs that counter-check before anything is reported.

## Scope

- **Branch mode** — the ten generic sweeps and the project's sweeps read **added lines of code files only** (`added_lines.txt`, `path:line:text`). A file that entered the delta for one import is never blamed for the lines it already had. File-level sweeps (7, 8 and project sweeps with `scope files`) read whole files, so their rows carry `pre-existing on base` when the line is not one the branch added, and `whole file` when the hit has no single line.
- **Codebase mode** — on `main` with a clean tree, or with `--scope <path>`, every line of every code file in scope is in `added_lines.txt`. No `pre-existing` marks: all of it is debt by definition.
- Code files are `ts|tsx|js|jsx|mjs|cjs|vue|svelte` minus tests, stories, mocks and `.d.ts` (`.audit-code/config.env`). UI files are `tsx|jsx|vue|svelte`; sweeps 7–10 run only when the scope has at least one.

A skipped sweep is not a failure, it is a fact the header carries with its reason: `Sweeps: 12/15 · skipped: 6 (no DS_CANONICAL/FORBIDDEN in rules-pack.env)`.

## Generic sweeps

1. **Type safety** (`A`, lines). `: any`, `as any`, `as unknown as`, a cast `as SomeType`, a non-null assertion (`x!.`, `x!;`, `x!)`), `@ts-ignore` / `@ts-expect-error`; comment lines are excluded (measured: five JSDoc sentences matched on nestjs/nest). Class `A` when the fix is a type the code already proves (`satisfies`, a narrowed guard, the real return type); a cast that hides a real mismatch is a behaviour question and goes to `Out of scope` — the `types-and-state` lens decides per hit.

   ```bash
   grep -En ":[[:space:]]*any\b|\bas any\b|as unknown as|\bas [A-Z]\w*|[]A-Za-z_)]![[:space:]]*[.;),]|@ts-(ignore|expect-error)" added_lines.txt
   ```

2. **Duplication** (`B`, files). Identical blocks of 4+ lines across two or more files in scope, via `jscpd` ad hoc through `npx` — never added to a manifest. Only clones whose **both** files are in scope become rows, and in branch mode only when at least one of the two blocks contains an added line (measured on tailwindcss: 114 clones between big files on the base, none touched by the branch). The row points at the clone's first **added** line, so a clone that starts on an old line is not mislabelled `pre-existing` (measured on TanStack Query: five clones lost that way). Counter-check: «Duplication» — `diff` the two blocks; nearly identical ≠ identical.

   ```bash
   npx --yes jscpd --min-lines 4 --min-tokens 40 --reporters json --format "typescript,tsx,javascript,jsx" <dirs in scope>
   ```

3. **Import cycles** (`B`, files). `madge --circular` over the directories in scope; a cycle whose every file is in scope is a row (the usual fix is moving a type or a constant to its own file). A cycle that only partly touches the scope is `Apply: no` with the files named.

   ```bash
   npx --yes madge --circular --basedir . --extensions ts,tsx,js,jsx <dirs in scope>
   ```

4. **Lint warnings on added lines** (`A`, lines). The project's own eslint (`npx --no-install eslint --format json`, run from the nearest directory with an eslint config) intersected with the added lines. Every warning on a line the branch wrote is a candidate; the verifier still runs `git show <base>:<path>` before blaming it, because moved code carries its warnings with it. Skipped, with the reason in the header, when the project has no eslint config or `node_modules/.bin/eslint` is missing (projects on oxlint, biome or `vp lint` fall here).

5. **Alias-able import** (`A`, lines). `../../` or deeper when the alias registry of `rules-pack.md` has an entry that resolves to the same file. Runs only when some `tsconfig` declares `paths`; the change is the import line alone.

   ```bash
   grep -En "from ['\"](\.\./){2,}" added_lines.txt
   ```

6. **Design-system wrapper bypass and forbidden imports** (`A`, lines). An import from the canonical DS package when the project mandates a wrapper, and any import from the forbidden list. Both come from `rules-pack.env` (`DS_CANONICAL`, `DS_WRAPPER`, `FORBIDDEN`, `DS_EXEMPT`); when the pack names nothing the sweep is skipped, never guessed. Wrapper bypass is `A` (swap the specifier; the counter-check proves the wrapper re-exports the symbol). A forbidden library is `Apply: no`: replacing it is a migration, not a refactor.

7. **Memo without a consumer** (`A`, UI files). Every `useMemo` / `useCallback` must name the consumer that depends on the value's identity: an effect dependency, a memoised child, a context value. The sweep lists them (import and comment lines excluded); the lens greps the memoised name in its consumers and keeps only the ones nothing depends on.

8. **Several components in one file** (`B`, UI files). More than two top-level component declarations (`function Foo(`, `const Foo = (`) in one UI file. The row is `whole file`; the lens reads it, because a second component close to the parent's size is a hit and a five-line private helper is not.

9. **Static inline style with a utility-class equivalent** (`A`, UI lines). `style={{ textAlign: 'center' }}` — static values a class compiles to identically. Dynamic values (`${n}px`, a prop) are not candidates. Runs only when the project uses Tailwind (`TAILWIND=yes` in `rules-pack.env`); the verifier proves the computed CSS on the target platform before the row survives.

   ```bash
   grep -En "style=\{\{[^}]*:[[:space:]]*['\"][^'\"]+['\"]" added_lines.txt
   ```

10. **Arbitrary `[var(--x)]` for a project-owned variable** (`A`, UI lines). `bg-[var(--brand)]` when the styles register `@utility bg-brand`. Arbitrary syntax is legitimate for runtime variables the project does not own (`--radix-*`, `--reka-*`, `--rn-*`). Runs only when the project declares utilities (`UTILITIES > 0`). When the utility does not exist the candidate is a **new utility** and goes to `Apply: no`.

## Project sweeps

Conventions are the project's, not the skill's: props naming, class-string constants, where logic lives, barrel imports, logger over `console`, where `process.env` may be read. They live in `.audit-code/sweeps.md`, one heading per sweep, and run after the generic ten with `P<n>` ids:

```markdown
## P1 · private props type is named Props · class A · scope files
counter-check: "Does not follow the convention" — read the file's exports
change: rename the private props type to `Props`
```bash
each_file grep -EHn "^(interface|type) [A-Za-z]+Props\b"
```
```

Inside the block, `each_file <cmd>` runs over code files, `each_ui_file` over UI files, `$LINES` is the added-lines file and `ui_lines` filters it to UI files. A block prints hits as `path:line:text`. `scripts/audit-init.sh --surface frontend|backend|both` writes a starter file from `assets/`; delete every sweep your normative docs cannot back, because the verifier discards a candidate whose rule nobody wrote down.
