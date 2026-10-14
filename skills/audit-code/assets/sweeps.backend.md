# Project sweeps — backend conventions

Same format as the frontend file (see its header). Delete what your project
does not enforce.

## P11 · console output in source · class A · scope lines
counter-check: grep the project's logger in the normative docs; a `console.*` the docs allow (CLI entry points) is not a hit
change: use the project logger
```bash
grep -En "\bconsole\.(log|info|warn|error)\(" "$LINES" | cut -d: -f2-
```

## P12 · environment read outside the config module · class B · scope lines
counter-check: Architecture or boundary rule — quote the config rule; count the precedent with `grep -rn "process.env" src`
change: read the value from the config module
```bash
grep -En "process\.env\." "$LINES" | grep -vE "/(config|env)[^/]*\.(ts|js)" | cut -d: -f2-
```

## P13 · another module's internals imported directly · class B · scope lines
counter-check: Architecture or boundary rule — the module's public barrel must export the symbol
change: import from the module's public entry point
```bash
grep -En "from ['\"]\.\./[a-z-]+/(infra|internal|private)/" "$LINES" | cut -d: -f2-
```

## P14 · default export in a service or repository · class A · scope lines
counter-check: "Does not follow the convention" — count the precedent across the repo before calling it a violation
change: named export
```bash
grep -En "^export default" "$LINES" | grep -E "\.(service|repository|controller)\." | cut -d: -f2-
```
