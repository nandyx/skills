# Counter-checks

No candidate is reported without its counter-check. The first pass of an audit finds symbols by searching for `import`; that method fails whenever the consumer is a peer dependency, a config file, an upstream signature or a documented contract. The verifier runs this table over every candidate — the row for the candidate's kind, not only the check the reviewer proposed — and, in branch mode, `git show <base>:<path>` for anything claimed new. A candidate with no executable counter-check is discarded as «not verifiable».

## Mandatory counter-check by kind of finding

| Kind of finding | Mandatory counter-check |
| --- | --- |
| Unused dependency | `peerDependencies` of every installed package (no `peerDependenciesMeta` = mandatory), root and workspace scripts, configs (bundler, jest, eslint, babel, storybook), README |
| Export with no consumer | grep the **symbol**, not the import; and if a doc or spec declares it public, it is API, not dead code |
| Stub or wrapper with a "looser" signature | read upstream's real `.d.ts` before claiming it diverges |
| "Does not follow the convention" | `find` the pattern across the whole repo before calling it a violation; thirty precedents make the pattern the convention |
| Two docs state the rule differently | grep the rule across every normative doc the pack lists; report the contradiction itself as a docs finding and ask which one wins — never pick one silently |
| A lint rule not receiving an option | read the rule's real schema and the option's default — and whether the option is shared across rules |
| Duplication | `diff` the two blocks; nearly identical ≠ identical, enumerate the lines that differ |
| Doc that does not match the code | `ls` the cited path; a doc naming a deleted file is stale, not a code bug |
| A warning or smell that looks new | `git show <base>:<path>` — moved code carries its warnings with it and is not this branch's debt (branch mode only) |
| "Simplify this to the canonical equivalent" | prove the two compute the same value on the target platform before proposing it |
| A behavior the user called wrong | reproduce it against the real contract; a runtime error does not prove which side is at fault |
| Hardcoded user-facing string | grep the proposed key in **every** locale file; class `A` only when the key exists everywhere with that exact copy — otherwise `Apply: no`, the project's translation workflow owns it |
| Alias-able import | resolve the relative path and the alias against the workspace's `tsconfig.json` `paths`; both must land on the same file, and the alias must be one the bundler config (metro, vite, webpack, jest `moduleNameMapper`) also knows |
| DS wrapper bypass | the wrapper (`rules-pack.md`) must export the same symbol — grep its barrel; a symbol the wrapper does not re-export is a wrapper gap, reported with `Apply: no` |
| Architecture or boundary rule | quote the rule's line from the normative doc; a rule nobody wrote down is a preference, and the candidate is discarded |
| Several components in one file | count with sweep 8's regex **and** read the file: a second component close to the parent's size is a hit, a five-line private helper is not |

Every finding carries an **Evidence** line with the command and its result. No evidence, no report.

---

# Worked examples

Real candidates that a first-pass audit reported and that did **not** survive verification. Each one is a template: the same shape of mistake recurs.

The unifying lesson: **an import search answers "who imports this", not "who needs this".** Those are different questions whenever the consumer is a package manifest, a config file, an upstream type declaration, or a document that promised the symbol would exist.

---

## Unused dependency

**Candidate.** A bottom-sheet library is in `devDependencies` with zero importers; the project's own bottom sheet is hand-rolled. Remove it.

**Counter-check.**

```bash
node -e "const d=require('./node_modules/<storybook-ui-package>/package.json');
console.log(d.peerDependencies, d.peerDependenciesMeta)"
grep -rl "<library>" node_modules/<storybook-ui-package>/dist
```

**Result.** It is a peer of the on-device Storybook UI, the manifest declares **no** `peerDependenciesMeta`, so the peer is mandatory, and `dist/index.js` imports it at module load. Removing it breaks the component catalog on both platforms. It was already documented in the app README.

**Rule.** A dependency has three more possible consumers before it is dead: a peer of something installed, a script in the root or workspace manifest, and a config file. Check the README too — a previous engineer may have already written down why it is there.

---

## Stub or wrapper with a "looser" signature

**Candidate.** A test stub declares `notificationAsync(_type?: FeedbackType)` while the real API requires the argument. Tighten it.

**Counter-check.**

```bash
grep -n "notificationAsync" node_modules/<haptics-package>/build/Haptics.d.ts
```

**Result.** `export declare function notificationAsync(type?: FeedbackType): Promise<void>` — optional upstream. The stub matched its subject exactly.

**Rule.** Never infer an upstream signature from how the codebase calls it. Read the `.d.ts`.

---

## Export with no consumer

**Candidate A.** `IS_ANDROID` is exported from the platform constants and nothing reads it.
**Candidate B.** `EXPIRY_BUFFER_MS` is exported from a feature barrel and only its own domain module uses it.

**Counter-check.**

```bash
grep -rn "\bIS_ANDROID\b" --include="*.ts" --include="*.tsx" --include="*.md" src packages docs
```

**Result.** Both appear in the project's specs as declared deliverables of work already shipped: the platform trio is deliberate surface, and the buffer is part of a token contract promoted into the package on purpose. Deleting either contradicts a closed decision.

**Rule.** Grep the symbol across `docs/` as well as code. Surface a spec promised is API, not dead code. If it genuinely should go, that is a spec amendment, not a cleanup.

---

## "Does not follow the convention"

**Candidate.** Two new modules are named `*.store.ts`, but the normative doc reserves `store` for the business domain.

**Counter-check.**

```bash
find src packages -name "*.store.ts" -not -path "*/node_modules/*"
grep -rln "from 'zustand'" --include="*.ts" src packages
```

**Result.** The only two `*.store.ts` files are the branch's own, and 25 state modules across the repo use `*.state.ts`. The convention claim held — but it held *because it was measured*. Had the search returned thirty pre-existing `*.store.ts`, the finding would have been a style preference, not a violation.

**Rule.** Count the precedent before calling something a violation. A pattern the repo uses everywhere is the convention, whatever a doc says.

---

## A lint rule not receiving an option

**Candidate.** The shared Tailwind lint config passes `variables` only to `no-restricted-classes`, so class-string constants escape `no-unknown-classes`.

**Counter-check.**

```bash
node -e "for (const n of ['no-unknown-classes','enforce-canonical-classes','no-restricted-classes']) {
  const m = require('./node_modules/eslint-plugin-better-tailwindcss/lib/rules/'+n+'.js');
  const r = m[Object.keys(m)[0]];
  console.log(n, Object.keys(r.rule.meta.schema[0].properties), 'default:', r.options.variables);
}"
```

**Result.** All three accept `variables`, `additionalProperties: false`, and the default is `undefined`. The gap is real.

**Rule.** Read the rule's schema and the option's **default** before claiming a gap. An option that defaults to something sensible is not a gap, and an option the rule does not accept would crash the lint instead of silently under-reporting.

---

## Duplication

**Candidate.** Two animation hooks are "the same machine"; extract one shared hook.

**Counter-check.** Read both in full and enumerate the differences.

**Result.** The transitions were identical line for line, but the clocks were not: one advances a bar per step with a standard bezier and exits on the last step, the other runs a single 2500 ms bar with a polynomial ease and a hold. Extracting the whole hook would have changed behavior; extracting only the transitions did not.

**Rule.** `diff` the two files and list the differing lines in the finding. "Nearly identical" is the interesting part — it tells you where the seam actually is.

---

## Doc that does not match the code

**Candidate.** A patterns doc enumerates the legitimate uses of an arbitrary Tailwind value; one entry does not exist.

**Counter-check.**

```bash
ls src/screens/login/components/CredentialsForm/
```

**Result.** The branch deleted that file, and added a new component the list does not mention. The enumeration was stale in both directions.

**Rule.** A doc that names a deleted file is a stale doc, not a code bug. Consider proposing the enumeration be deleted: a hand-maintained list of call sites rots on every branch, and the enforceable half is the lint rule it points at.

---

## A warning or smell that looks new

**Candidate.** The branch adds nine type-assertion warnings in a domain rules file.

**Counter-check.**

```bash
git show <base>:src/services/auth/auth.service.ts | grep -c " as "
```

**Result.** Seven of them are a verbatim move from a service that already existed on the base. The branch introduced exactly one new warning, in a story file.

**Rule.** Before attributing a warning to the branch, look for the code on the base. Promoting code between packages relocates its debt without creating it, and asking the branch to pay it is scope creep.

---

## "Simplify this to the canonical equivalent"

**Candidate.** Replace arbitrary Tailwind values with the canonical classes that look equivalent.

**Counter-check.** Measure what the canonical class actually compiles to on the target platform.

**Result.** In this React Native setup the CSS compiler uses a root font size of 14, not 16, so `rounded-lg` is 7px and `size-6` is 21px. The "simplification" would have moved pixels on every screen. The project's standing decision is to tokenize the arbitrary value at its current number instead.

**Rule.** Two expressions that look equivalent in one runtime may not be in another. Prove the computed value before proposing the swap, and remember that a rule written for the web half of a monorepo may invert on the native half.

---

## A behavior the user called wrong

**Candidate.** An endpoint returns 500 when a parameter is sent, so the parameter is not part of the contract.

**Counter-check.** Read the legacy client and the backend spec before changing the call.

**Result.** The endpoint was simply not deployed yet. A runtime error tells you something is broken; it does not tell you which side is at fault.

**Rule.** Reproduce against the real contract. Infer from documentation and from the code that already worked, not from a single failing response.
