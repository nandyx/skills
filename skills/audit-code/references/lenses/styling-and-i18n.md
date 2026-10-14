# Lens — styling and i18n

Styles, design-system usage and copy in the UI files in scope. The bar is zero visual delta: a class swap that compiles to the same CSS is a candidate, a class swap that moves a pixel is not. When in doubt the verifier proves the computed value («canonical equivalent» in `counter-checks.md`); this lens proposes.

This lens is dispatched only when the header says `surface: ui`. Read `rules-pack.md` first: the canonical DS package and its wrapper alias, the forbidden libraries, the token registry, the icon library and the i18n hook come from there. A section whose rule the pack does not carry is skipped, not guessed, and listed under `Skipped lens items`. Nothing in `register.md` is a candidate.

## 1. Design-system imports

- **Wrapper bypass** — importing the canonical DS package when the pack mandates the wrapper alias (sweep 6 lists the lines). Class `A`: the specifier changes, the component is the same one. Counter-check: «DS wrapper bypass» — the wrapper must re-export the symbol.
- **Deep relative import an alias covers** (sweep 5). Class `A`. Counter-check: «Alias-able import».
- **Forbidden libraries** (whatever the pack lists). Reported with `Apply: no`: replacing a library is a migration with a visual delta of its own, never a refactor row.

## 2. Classes and tokens

- `[var(--x)]` for a project-owned variable when the registry has the utility (sweep 10). Class `A`. When the utility does not exist, the candidate is a new utility: `Apply: no`, it touches the styles package.
- Inline `style={{ … }}` with static values a class compiles to identically (sweep 9). Class `A` only after the verifier proves the computed CSS on the target platform; dynamic values are not candidates.
- A single hardcoded `className` string over 150 characters outside a variants helper (`cva`, `tv`, `cn`): extract to a variant. Class `B` (the rendered class list is identical; the structure changes).
- Class strings in constants, when the pack bans them (project sweep). Class `A`.
- The same arbitrary value (`w-[37px]`, `text-[13px]`) in three or more files in scope is a token candidate: `Apply: no`, with the files named, because registering it touches the styles package.

## 3. Elements and icons

- A raw element (`<button>`, `<input>`, `<select>`, `<textarea>`, `<dialog>`, an `<a>` styled as a button) when the pack's DS catalog has the counterpart. Reported with `Apply: no`: the DS component carries its own markup and focus styles, so the swap is a visual change for a human to validate. Semantic wrappers (`<nav>`, `<header>`, `<main>`, `<section>`) are not candidates.
- An emoji, an inline `<svg>` or a second icon library where the pack mandates one. `Apply: no` unless the mandated library has the same glyph at the same size — then class `A`, and the verifier names the glyph.

## 4. Copy

- A user-facing literal in JSX text or a visible attribute (`title`, `placeholder`, `aria-label`, `alt`, `accessibilityLabel`) that bypasses the project's translation hook. Ignore tests, stories, `data-*` and `console.*`. Class `A` **only** when the key already exists in every locale with that exact copy (counter-check «Hardcoded user-facing string»); otherwise `Apply: no`, and the row names the project's translation workflow as the owner.
- A translation call in a file the pack forbids it in (`*.constants.ts`): class `B`, the copy resolves one level up.
- A key whose namespace does not match the feature that owns it, when the pack defines a namespace convention: class `A`, locale files and call site change together.

## Out of scope — behaviour

A token class that no registry defines (silent `var()` fallback, worst on focus states), a foreign token from another design system, a `t('key')` whose key no locale has, a key present in one locale and missing in another, an orphan key nobody references. Listed with the line, the registry grep and its empty result — never with a `Change`. They are bugs for the project's reviewers, not refactor rows.
