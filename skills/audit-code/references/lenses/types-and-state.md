# Lens — types and state

How types, state, effects and memoisation behave in the files in scope. The bar is zero behaviour delta: this lens proposes what makes the same code say the same thing more plainly, and sends every real bug to **Out of scope — behaviour** instead of fixing it.

Read `rules-pack.md` first. Every candidate goes out in the fixed shape (`id | lens | class | files | change | rule violated | proposed counter-check`). Nothing in `register.md` is a candidate.

Sections 1–2 apply to every code file. Sections 3–5 apply only when the scope has UI files (the header says `surface: ui`); on a backend scope, skip them and list them under `Skipped lens items`.

## 1. Type safety (judgement over sweep 1's hits)

Sweep 1 lists the added lines with `any`, casts, non-null assertions and `@ts-` directives. This lens decides, per hit:

- The type is already proven by the code (a guard above, a `satisfies`, a return the compiler infers): class `A`, the change is the narrowed type.
- The cast papers over a real mismatch between what the code has and what it claims: **Out of scope — behaviour**, with the two types named. Removing it is not a cleanup.
- An exported function with no return type whose inference is a long union: class `A` when the explicit type is what the compiler already infers; nothing otherwise.
- `@ts-expect-error` with a reason that is still true: not a candidate. With a reason that is false (the upstream type was fixed): class `A`.
- A non-null assertion where the code above already narrows (an early return, an `if`): class `A`. One that asserts what nothing proves: **Out of scope**.

Counter-check: «Stub or wrapper with a "looser" signature» (read the real `.d.ts`), «A warning or smell that looks new» (`git show <base>:<path>` — moved code carries its casts).

## 2. Types and contracts

- Two optional fields that only make sense together (`label?` + `onPress?`, `cursor?` + `limit?`) allow invalid states; the fix is a discriminated union or a single optional object. Class `B` — the callers change, the result does not.
- A type declared in a view, handler or service file that the pack places in `*.types.ts`. Class `A`.
- Naming conventions the pack declares for types (`Props`, `Params`, `Dto`, `Entity`): class `A`. Counter-check: «"Does not follow the convention"» — count the precedent before calling it a violation.
- A wider type than the value it holds (`string` for a union the code switches over, `Record<string, unknown>` for a known shape the code already destructures). Class `A` when the narrower type is what the code proves.

## 3. Effects (UI only)

- An effect whose whole body derives a value from props or state and stores it (`useEffect(() => setTotal(items.length), [items])`) is a derivation: compute it in render, or memoise it when a consumer depends on identity. Class `B`. Counter-check: «Simplify this to the canonical equivalent» — prove the derived value is identical on every render path, including the first.
- A timer effect, a watch-and-persist pair, or a debounce written by hand when the project's shared hooks (named in the pack) already have it. Class `B`. Counter-check: «Duplication».
- `useEffect` with no dependency array, a dependency array missing a value the effect reads, a subscription or fetch without cleanup or `AbortController`, an effect that sets state unconditionally: **Out of scope — behaviour**. Fixing any of them changes when code runs. `exhaustive-deps` warnings on added lines are already sweep 4's; do not duplicate them.

## 4. Memoisation (UI only)

Every `useMemo` / `useCallback` must name the consumer that depends on the value's identity: an effect dependency, a memoised child, a context value. When nothing depends on identity, or the inputs change on every render anyway, it is a candidate (sweep 7 lists them; the lens greps the memoised name in the file and its consumers). A `.find()` result is already identity-stable when its array is. Class `A`. Counter-check: «Simplify this to the canonical equivalent».

## 5. Hooks and copy (UI only)

- A logic hook never receives or returns copy: no `t` / `lang` / `labels` parameters, no returned `get*(labels)`. It returns keys or decisions; the component resolves copy through the project's translation hook. Applies only when the pack carries the rule.
- A hook that returns a component or JSX is a component.

Class `B`. Counter-check: «Architecture or boundary rule».

## Out of scope — behaviour

Missing effect dependencies, missing cleanup, state set unconditionally, a cast hiding a real mismatch, a stale closure, an assertion nothing proves. Listed with the line and the evidence, never with a `Change`.
