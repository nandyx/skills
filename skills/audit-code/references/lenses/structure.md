# Lens — structure

Where code lives and what it is allowed to touch. Read `rules-pack.md` first: every item below applies only when the pack carries the rule it names. A rule the project never wrote down is a preference, and a preference is not a candidate.

Every candidate goes out in the fixed shape (`id | lens | class | files | change | rule violated | proposed counter-check`), with the rule cited by document and section. Nothing in `register.md` is a candidate: it is already planned.

Applies to UI and backend code alike.

## 1. Explicit architecture rules

From the pack's **architecture ruleset** only — layer folders, what each may import, what is forbidden («components never call the API directly», «repositories return the raw response», «shared packages never touch `window` or `localStorage`», «no timers in domain models», «controllers never query the database»).

- A forbidden import in a layer (`fetch`/`axios` in `domain/`; `window`/`document` under a shared package; a database client inside a controller or a component).
- A cross-layer shortcut (`components/` importing `infra/repositories/` when the rule routes through `queries/`; a route handler importing another module's repository directly).
- A file that escapes its declared responsibility: helpers, constants or business logic inside a view file when the pack says they live in `services/`, `utils/`, `domain/`, `*.constants.ts` or `*.types.ts`.
- Transport rules: a repository transforming the response when the adapter must, a hardcoded URL where the project's URL builder is mandatory.

Class `B` (the code moves, nothing it computes changes). Rule violated: the normative doc's line, quoted. Counter-check: «Architecture or boundary rule».

## 2. Dependency boundaries

- A module importing another feature's internals (`features/foo/infra/...` from outside `features/foo/`) instead of the feature's public barrel declared in the pack.
- An API the pack lists as deprecated or banned.
- Barrel rules the pack declares (a parent imports children from `./components` / `./hooks`, a module exposes one `index.ts`). Project sweeps find the regex hits; this lens judges the ones a regex cannot (re-exports, type-only imports, barrels with side effects).

Class `A` for an import path change, `B` when a barrel has to be created. Counter-check: «Architecture or boundary rule»; «Alias-able import» when the fix is an alias.

## 3. Cohesion and responsibility

- Logic inside a view file: state, form watching, effects, data shaping (`filter`/`reduce`/`sort` over props or query data) belong in a sibling hook or service when the pack says so; the view renders. Plain prop wiring stays.
- A utility defined inside a file and used only there is fine; the same helper in two files in scope, or a helper the pack places in `utils/`, is a candidate.
- Several components in one UI file (sweep 8 counts; this lens reads the count-2 files and decides whether the second one is «small»). Each extra component moves to its own file with a barrel, when the pack has that rule.
- A hook, service or handler that owns two unrelated concerns (a form and a subscription, a derivation and an analytics call, validation and persistence) is two units.

Class `B` (markup and logic move verbatim; zero behaviour delta is the bar — an effect that now runs in a different component, or a middleware that now runs in a different order, is out of scope, not a judgement call). Counter-check: «Several components in one file», «Duplication» when the split dedupes.

## 4. Dead code

- An export the scope added or kept with no consumer — grep the **symbol**, not the import; a spec or README that declares it public makes it API.
- An orphan file (no incoming import) the scope created.
- A dependency the scope added with no importer — a peer, a script or a config may still need it.
- Dead props and dead parameters: destructured and never read, or never passed by any caller.

Class `A`. Counter-check: «Export with no consumer», «Unused dependency». Both have worked examples in `counter-checks.md` where the first pass was wrong; read them before proposing a deletion.

## Out of scope — behaviour

Report under that heading, with evidence and without a `Change`: a layer violation whose fix changes what runs (a fetch moved from render to a query changes when it fires), a circular import that currently works by load order, a side effect at module scope, a middleware whose order matters.
