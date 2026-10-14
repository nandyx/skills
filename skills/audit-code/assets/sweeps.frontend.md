# Project sweeps — frontend conventions

Each sweep is a heading `## P<n> · <name> · class <A|B|C> · scope <files|lines>`,
an optional `counter-check:` line (the verifier's mandatory check), a `change:`
line (the exact edit) and one ```bash block that prints hits as `path:line:text`.
Inside the block: `each_file <cmd>` runs over code files, `each_ui_file` over UI
files, `$LINES` is the added-lines file (`path:line:text`), `ui_lines` filters it
to UI files. Delete what your project does not enforce; a sweep nobody can cite
from a normative doc produces candidates the verifier will discard.

## P1 · private props type is named Props · class A · scope files
counter-check: "Does not follow the convention" — read the file's exports; a non-exported main component type is `Props`
change: rename the private props type to `Props`
```bash
each_file grep -EHn "^(interface|type) [A-Za-z]+Props\b"
```

## P2 · class strings in constants · class A · scope files
counter-check: `git show <base>:<path>` — moved code carries its debt
change: inline the class string or move it into a `cva` variant
```bash
each_file grep -EHn "(const|export const) _?[A-Z_]+_CLASS\b"
```

## P3 · logic inside a component file · class B · scope files
counter-check: read the hit — prop wiring stays, state, effects and data shaping move to a sibling hook
change: move state, effects and data shaping to a sibling `use*` hook
```bash
each_ui_file grep -EHn "\b(useState|useReducer|useEffect)\(|\.(filter|reduce|sort)\("
```

## P4 · copy inside logic hooks · class B · scope files
counter-check: Architecture or boundary rule — quote the hook rule from the normative docs
change: return keys or decisions; the component resolves copy through the translation hook
```bash
each_file grep -EHn "\b(t|lang|labels)\b *[:,)]" | grep "/hooks/"
```

## P5 · child imported from its file instead of the folder barrel · class A · scope lines
counter-check: Architecture or boundary rule — exception: a sibling of the same barrel keeps the folder path
change: import from `./components` / `./hooks`
```bash
grep -En "from ['\"]\.{1,2}(/\.\.)*/(components|hooks)/[^'\"]+['\"]" "$LINES" | cut -d: -f2-
```
