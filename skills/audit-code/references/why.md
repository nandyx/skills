# Why each kind of finding matters

The report carries one line per kind present, under `## Why these matter`, so a reader who never ran the audit understands why a row is worth a commit. Copy the line; do not invent a new one. A kind not listed here gets no line.

| Kind | Why it matters |
| --- | --- |
| Redundant type assertion (`as`, `!`) | An assertion switches the compiler off at that point. When the type is already proven it adds nothing today, and if the type changes tomorrow it hides the error the compiler would have reported. |
| `any` or a double cast (`as unknown as`) | Every value that crosses it loses its type, so mistakes downstream compile. |
| Export with no consumer | Surface someone has to read, keep compiling and keep compatible, for nobody. |
| Dead parameter, prop or branch | Callers pass things that do nothing; readers assume they matter. |
| Duplicated block | Two copies drift: the next fix lands in one of them. |
| Import cycle | Works by load order; a reordered import or a test that loads one file first breaks it. |
| `useMemo` / `useCallback` with no identity consumer | Costs a comparison per render and tells the reader identity matters when it does not. |
| Derivation stored by an effect | An extra render with stale state between the two; the value can be computed where it is used. |
| Several components in one file | Harder to find, test and reuse; the file grows by accretion. |
| Logic inside a view file | The rendering file stops being readable and the logic cannot be tested without rendering. |
| Paired optional props | The type allows combinations the component cannot handle. |
| Deep relative import an alias covers | Breaks when either file moves; the alias is the project's declared path. |
| Design-system wrapper bypass | Skips the fixes and theming the project put in its wrapper. |
| Static inline style or arbitrary `var(--)` | Bypasses the project's tokens, so a theme change misses it. |
| Hardcoded user-facing copy | Cannot be translated, and drifts from the copy the rest of the product uses. |
| New lint warning | The project chose the rule; the warning is the project telling you, not the audit. |
| Convention the repo declares | Consistency is what makes the next file predictable; the rule is written, the row only applies it. |
